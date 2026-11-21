import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academic_os/core/academic/academic_assistant_action_executor.dart';
import 'package:academic_os/data/database/database_helper.dart';
import 'package:academic_os/domain/entities/course_entity.dart';
import 'package:academic_os/domain/entities/task_entity.dart';
import 'package:academic_os/data/models/student_profile_model.dart';
import 'package:academic_os/domain/repositories/course_repository.dart';
import 'package:academic_os/domain/repositories/task_repository.dart';
import 'package:academic_os/domain/usecases/course_use_cases.dart';
import 'package:academic_os/domain/usecases/task_use_cases.dart';

void main() {
  late _FakeCourseRepository courseRepository;
  late _FakeTaskRepository taskRepository;
  late AcademicAssistantActionExecutor executor;

  setUp(() {
    courseRepository = _FakeCourseRepository();
    taskRepository = _FakeTaskRepository();
    executor = AcademicAssistantActionExecutor(
      courseUseCases: _courseUseCases(courseRepository),
      taskUseCases: _taskUseCases(taskRepository),
    );
  });

  group('AcademicAssistantCommandParser', () {
    test('parses material, task and report commands', () {
      const parser = AcademicAssistantCommandParser();
      expect(parser.parse('أضف مادة أمن الشبكات')?.name, 'create_material');
      expect(parser.parse('أنشئ مهمة مراجعة التشفير')?.name, 'create_task');
      final task = parser.parse('أنشئ مهمة لمراجعة مادة الشبكات غداً');
      expect(task?.arguments['title'], 'مراجعة الشبكات');
      expect(task?.arguments['course_name'], 'الشبكات');
      final timeTask = parser.parse(
        'أنشئ مهمة مراجعة الشبكات غداً الساعة 6 مساءً',
      );
      expect(timeTask?.arguments['end_date_time'], isNotNull);
      expect(parser.parse('احذف مادة الشبكات')?.name, 'delete_material');
      expect(parser.parse('احذف محاضرة 44')?.arguments['schedule_id'], 44);
      expect(
        parser.parse('أعطني التقرير الأسبوعي')?.arguments['period'],
        'weekly',
      );
    });
  });

  group('AcademicAssistantActionExecutor', () {
    test(
      'updates the academic profile without clearing unspecified fields',
      () async {
        SharedPreferences.setMockInitialValues({
          StudentProfile.storageKey: jsonEncode({
            'fullName': 'طالب',
            'university': 'جامعة الاختبار',
            'major': 'شبكات',
            'department': 'تقنية المعلومات',
            'semester': 'الأول',
            'academicLevel': 'الثالث',
            'targetGpa': '',
            'avatar': 'student',
          }),
        });

        final result = await executor.execute(
          const AcademicAssistantToolCall(
            name: 'update_profile',
            arguments: {'semester': 'الثاني', 'department': 'الأمن السيبراني'},
          ),
        );
        final profile = await StudentProfile.load();

        expect(result.changedData, isTrue);
        expect(result.succeeded, isTrue);
        expect(profile.fullName, 'طالب');
        expect(profile.university, 'جامعة الاختبار');
        expect(profile.semester, 'الثاني');
        expect(profile.department, 'الأمن السيبراني');
      },
    );

    test(
      'creates a material with an automatic code and prevents duplicates',
      () async {
        final first = await executor.execute(
          const AcademicAssistantToolCall(
            name: 'create_material',
            arguments: {'name': 'أمن الشبكات'},
          ),
        );
        final duplicate = await executor.execute(
          const AcademicAssistantToolCall(
            name: 'create_material',
            arguments: {'name': 'أمن الشبكات'},
          ),
        );

        expect(first.changedData, isTrue);
        expect(courseRepository.courses, hasLength(1));
        expect(courseRepository.courses.single.code, startsWith('AUTO-'));
        expect(duplicate.changedData, isFalse);
        expect(duplicate.message, contains('موجودة مسبقاً'));
      },
    );

    test(
      'creates a task linked to the material and records automatic start time',
      () async {
        courseRepository.courses.add(
          const CourseEntity(
            id: 7,
            name: 'أمن الشبكات',
            instructor: 'غير محدد',
            code: 'NET-101',
          ),
        );
        final before = DateTime.now();
        final result = await executor.execute(
          const AcademicAssistantToolCall(
            name: 'create_task',
            arguments: {
              'title': 'مراجعة المحاضرة الأولى',
              'course_name': 'أمن الشبكات',
            },
          ),
        );

        expect(result.changedData, isTrue);
        expect(taskRepository.tasks, hasLength(1));
        expect(taskRepository.tasks.single.courseId, 7);
        expect(taskRepository.tasks.single.courseName, 'أمن الشبكات');
        expect(taskRepository.tasks.single.startDateTime, isNotNull);
        expect(
          taskRepository.tasks.single.startDateTime!.isBefore(before),
          isFalse,
        );
      },
    );

    test(
      'rejects unsupported file types before saving to a material',
      () async {
        courseRepository.courses.add(
          const CourseEntity(
            id: 55,
            name: 'أمن الشبكات',
            instructor: 'غير محدد',
            code: 'SEC-55',
          ),
        );
        final result = await executor.execute(
          AcademicAssistantToolCall(
            name: 'add_material_file',
            arguments: {
              'course_name': 'أمن الشبكات',
              'file_name': 'payload.exe',
              'file_type': 'exe',
              'file_bytes': Uint8List.fromList([1, 2, 3]),
            },
          ),
        );

        expect(result.changedData, isFalse);
        expect(result.message, contains('غير مدعوم'));
      },
    );

    test('updates an existing material by its stable ID', () async {
      courseRepository.courses.add(
        const CourseEntity(
          id: 31,
          name: 'الشبكات',
          instructor: 'محاضر',
          code: 'NET-31',
        ),
      );
      final result = await executor.execute(
        const AcademicAssistantToolCall(
          name: 'update_material',
          arguments: {
            'course_id': 31,
            'name': 'أمن الشبكات المتقدم',
            'credits': 3,
          },
        ),
      );

      expect(result.changedData, isTrue);
      expect(courseRepository.courses.single.name, 'أمن الشبكات المتقدم');
      expect(courseRepository.courses.single.credits, 3);
    });

    test(
      'requires confirmation before deleting a material and its related data',
      () async {
        courseRepository.courses.add(
          const CourseEntity(
            id: 21,
            name: 'الشبكات',
            instructor: 'غير محدد',
            code: 'NET-21',
          ),
        );
        final result = await executor.execute(
          const AcademicAssistantToolCall(
            name: 'delete_material',
            arguments: {'course_name': 'الشبكات'},
          ),
        );

        expect(result.requiresConfirmation, isTrue);
        expect(result.confirmationPrompt, contains('ملفاتها'));
        expect(courseRepository.courses, hasLength(1));
      },
    );

    test('manages exams in the database and confirms deletion', () async {
      final database = DatabaseHelper.instance;
      await database.close();
      int? createdExamId;
      try {
        courseRepository.courses.add(
          const CourseEntity(
            id: 77,
            name: 'أمن الشبكات',
            instructor: 'محاضر',
            code: 'NET-77',
          ),
        );

        final created = await executor.execute(
          const AcademicAssistantToolCall(
            name: 'create_exam',
            arguments: {
              'title': 'اختبار الشبكات',
              'exam_date': '2027-02-15T09:30:00.000',
              'course_name': 'أمن الشبكات',
            },
          ),
        );
        expect(created.changedData, isTrue);
        final saved = (await database.getExams())
            .singleWhere((exam) => exam.title == 'اختبار الشبكات');
        createdExamId = saved.id;
        expect(saved.courseId, 77);

        final updated = await executor.execute(
          AcademicAssistantToolCall(
            name: 'update_exam',
            arguments: {
              'exam_id': saved.id,
              'title': 'اختبار الشبكات النهائي',
              'exam_date': '2027-02-16T10:00:00.000',
            },
          ),
        );
        expect(updated.changedData, isTrue);
        expect(
          (await database.getExamById(saved.id!))?.title,
          'اختبار الشبكات النهائي',
        );

        final pendingDelete = await executor.execute(
          AcademicAssistantToolCall(
            name: 'delete_exam',
            arguments: {'exam_id': saved.id},
          ),
        );
        expect(pendingDelete.requiresConfirmation, isTrue);
        expect(await database.getExamById(saved.id!), isNotNull);

        final deleted = await executor.execute(
          AcademicAssistantToolCall(
            name: 'delete_exam',
            arguments: {'exam_id': saved.id},
          ),
          confirmed: true,
        );
        expect(deleted.changedData, isTrue);
        expect(await database.getExamById(saved.id!), isNull);
        createdExamId = null;
      } finally {
        if (createdExamId != null) {
          await database.deleteExam(createdExamId);
        }
        await database.close();
      }
    });

    test('requires confirmation before deleting a task', () async {
      taskRepository.tasks.add(
        const TaskEntity(id: 12, title: 'مراجعة التشفير', description: ''),
      );
      final result = await executor.execute(
        const AcademicAssistantToolCall(
          name: 'delete_task',
          arguments: {'task_id': 12},
        ),
      );

      expect(result.requiresConfirmation, isTrue);
      expect(result.confirmationPrompt, contains('مراجعة التشفير'));
      expect(taskRepository.tasks, hasLength(1));
    });
  });
}

CourseUseCases _courseUseCases(CourseRepository repository) => CourseUseCases(
  getCourses: GetCoursesUseCase(repository),
  getCourseById: GetCourseByIdUseCase(repository),
  addCourse: AddCourseUseCase(repository),
  updateCourse: UpdateCourseUseCase(repository),
  deleteCourse: DeleteCourseUseCase(repository),
);

TaskUseCases _taskUseCases(TaskRepository repository) => TaskUseCases(
  getTasks: GetTasksUseCase(repository),
  getTaskById: GetTaskByIdUseCase(repository),
  addTask: AddTaskUseCase(repository),
  updateTask: UpdateTaskUseCase(repository),
  deleteTask: DeleteTaskUseCase(repository),
);

class _FakeCourseRepository implements CourseRepository {
  final List<CourseEntity> courses = [];
  int _nextId = 1;

  @override
  Future<int> addCourse(CourseEntity course) async {
    final id = _nextId++;
    courses.add(course.copyWith(id: id));
    return id;
  }

  @override
  Future<int> deleteCourse(int id) async {
    courses.removeWhere((course) => course.id == id);
    return 1;
  }

  @override
  Future<CourseEntity?> fetchCourseById(int id) async =>
      courses.where((course) => course.id == id).firstOrNull;

  @override
  Future<List<CourseEntity>> fetchCourses() async => List.of(courses);

  @override
  Future<int> updateCourse(CourseEntity course) async {
    final index = courses.indexWhere((item) => item.id == course.id);
    if (index >= 0) courses[index] = course;
    return index >= 0 ? 1 : 0;
  }
}

class _FakeTaskRepository implements TaskRepository {
  final List<TaskEntity> tasks = [];
  int _nextId = 1;

  @override
  Future<int> addTask(TaskEntity task) async {
    final id = _nextId++;
    tasks.add(task.copyWith(id: id));
    return id;
  }

  @override
  Future<int> deleteTask(int id) async {
    tasks.removeWhere((task) => task.id == id);
    return 1;
  }

  @override
  Future<TaskEntity?> fetchTaskById(int id) async =>
      tasks.where((task) => task.id == id).firstOrNull;

  @override
  Future<List<TaskEntity>> fetchTasks() async => List.of(tasks);

  @override
  Future<int> updateTask(TaskEntity task) async {
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index >= 0) tasks[index] = task;
    return index >= 0 ? 1 : 0;
  }
}
