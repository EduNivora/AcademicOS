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

  group('AcademicAssistantActionExecutor preflight', () {
    test('rejects a later invalid action before any earlier write', () async {
      final result = await executor.preflightPlan(const [
        AcademicAssistantToolCall(
          name: 'create_material',
          arguments: {'name': 'خطة مادة جديدة'},
        ),
        AcademicAssistantToolCall(
          name: 'create_exam',
          arguments: {'title': 'اختبار غير صالح', 'exam_date': 'not-a-date'},
        ),
      ]);

      expect(result.succeeded, isFalse);
      expect(courseRepository.courses, isEmpty);
    });

    test(
      'rejects two mutations targeting the same task before writes',
      () async {
        taskRepository.tasks.add(
          const TaskEntity(id: 44, title: 'مراجعة الشبكات', description: ''),
        );
        final result = await executor.preflightPlan(const [
          AcademicAssistantToolCall(
            name: 'update_task',
            arguments: {'task_id': 44, 'title': 'مراجعة الشبكات الجديدة'},
          ),
          AcademicAssistantToolCall(
            name: 'delete_task',
            arguments: {'task_id': 44},
          ),
        ]);

        expect(result.succeeded, isFalse);
        expect(taskRepository.tasks, hasLength(1));
        expect(taskRepository.tasks.single.title, 'مراجعة الشبكات');
      },
    );

    test(
      'simulates planned lectures and rejects a schedule conflict',
      () async {
        courseRepository.courses.add(
          const CourseEntity(
            id: 3,
            name: 'الشبكات',
            instructor: 'مدرس',
            code: 'NET-3',
          ),
        );
        final result = await executor.preflightPlan(const [
          AcademicAssistantToolCall(
            name: 'add_lecture',
            arguments: {
              'course_id': 3,
              'day': 'الأحد',
              'start_time': '08:00',
              'end_time': '09:00',
            },
          ),
          AcademicAssistantToolCall(
            name: 'add_lecture',
            arguments: {
              'course_id': 3,
              'day': 'الأحد',
              'start_time': '08:30',
              'end_time': '09:30',
            },
          ),
        ]);

        expect(result.succeeded, isFalse);
        expect(courseRepository.courses, hasLength(1));
      },
    );

    test(
      'accepts null optional fields while validating required values',
      () async {
        final result = await executor.preflightPlan(const [
          AcademicAssistantToolCall(
            name: 'create_task',
            arguments: {
              'title': 'مراجعة اختيارية',
              'course_id': null,
              'course_name': null,
              'end_date_time': null,
              'reminder_enabled': null,
            },
          ),
          AcademicAssistantToolCall(
            name: 'create_exam',
            arguments: {
              'title': 'اختبار مؤكد التاريخ',
              'exam_date': '2030-01-15T09:00:00',
              'course_id': null,
              'course_name': null,
            },
          ),
        ]);

        expect(result.succeeded, isTrue);
        expect(taskRepository.tasks, isEmpty);
        expect(courseRepository.courses, isEmpty);
      },
    );

    test('accepts a valid multi-step plan without mutating records', () async {
      final result = await executor.preflightPlan(const [
        AcademicAssistantToolCall(
          name: 'create_task',
          arguments: {'title': 'مراجعة قبل الاختبار'},
        ),
        AcademicAssistantToolCall(
          name: 'create_exam',
          arguments: {
            'title': 'اختبار الشبكات',
            'exam_date': '2030-01-15T09:00:00',
          },
        ),
      ]);

      expect(result.succeeded, isTrue);
      expect(courseRepository.courses, isEmpty);
      expect(taskRepository.tasks, isEmpty);
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

        const updateCall = AcademicAssistantToolCall(
          name: 'update_profile',
          arguments: {'semester': 'الثاني', 'department': 'الأمن السيبراني'},
        );
        final pending = await executor.execute(updateCall);
        expect(pending.requiresConfirmation, isTrue);
        final result = await executor.execute(updateCall, confirmed: true);
        expect(await executor.verifyPostcondition(updateCall, result), isTrue);
        final profile = await StudentProfile.load();

        expect(result.changedData, isTrue);
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
      'rejects model-supplied identity and unknown fields before any write',
      () async {
        final result = await executor.execute(
          const AcademicAssistantToolCall(
            name: 'create_material',
            arguments: {
              'name': 'مادة غير مصرح بها',
              'user_id': 'another-account',
            },
          ),
        );
        expect(result.changedData, isFalse);
        expect(result.message, contains('حقول غير مسموح بها'));
        expect(courseRepository.courses, isEmpty);
      },
    );

    test(
      'verifies a created course by re-reading it and detects later drift',
      () async {
        const call = AcademicAssistantToolCall(
          name: 'create_material',
          arguments: {'name': 'أمن الشبكات', 'instructor': 'د. علي'},
        );
        final result = await executor.execute(call);
        expect(result.changedData, isTrue);
        expect(result.affectedRecordId, isNotNull);
        expect(await executor.verifyPostcondition(call, result), isTrue);

        courseRepository.courses[0] = courseRepository.courses.single.copyWith(
          name: 'قيمة مختلفة',
        );
        expect(await executor.verifyPostcondition(call, result), isFalse);
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
        const createTaskCall = AcademicAssistantToolCall(
          name: 'create_task',
          arguments: {
            'title': 'مراجعة المحاضرة الأولى',
            'course_name': 'أمن الشبكات',
          },
        );
        expect(result.affectedRecordId, taskRepository.tasks.single.id);
        expect(
          await executor.verifyPostcondition(createTaskCall, result),
          isTrue,
        );
        taskRepository.tasks[0] = taskRepository.tasks.single.copyWith(
          title: 'عنوان مختلف',
        );
        expect(
          await executor.verifyPostcondition(createTaskCall, result),
          isFalse,
        );
        taskRepository.tasks[0] = taskRepository.tasks.single.copyWith(
          title: 'مراجعة المحاضرة الأولى',
        );
        final retry = await executor.execute(createTaskCall);
        expect(retry.succeeded, isTrue);
        expect(retry.changedData, isFalse);
        expect(taskRepository.tasks, hasLength(1));
        expect(
          taskRepository.tasks.single.startDateTime!.isBefore(before),
          isFalse,
        );
      },
    );

    test(
      'persists requested lecture reminder settings and verifies the saved row',
      () async {
        final database = DatabaseHelper.instance;
        await database.close();
        courseRepository.courses.add(
          const CourseEntity(
            id: 902,
            name: 'اختبار إعدادات التذكير',
            instructor: 'محاضر',
            code: 'REM-902',
          ),
        );
        int? scheduleId;
        try {
          const call = AcademicAssistantToolCall(
            name: 'add_lecture',
            arguments: {
              'course_name': 'اختبار إعدادات التذكير',
              'day': 'السبت',
              'start_time': '23:00',
              'end_time': '23:59',
              'location': 'قاعة الاختبار',
              'reminder_enabled': false,
              'reminder_offset_minutes': 30,
            },
          );
          final result = await executor.execute(call);
          scheduleId = result.affectedRecordId;
          expect(result.succeeded, isTrue);
          expect(result.changedData, isTrue);
          expect(scheduleId, isNotNull);
          expect(await executor.verifyPostcondition(call, result), isTrue);

          final saved = (await database.getSchedules()).singleWhere(
            (row) => row['id'] == scheduleId,
          );
          expect(saved['reminder_enabled'], 0);
          expect(saved['reminder_offset_minutes'], 30);
        } finally {
          if (scheduleId != null) await database.deleteSchedule(scheduleId);
          await database.close();
        }
      },
    );

    test(
      'updates a task type and course link and verifies persisted values',
      () async {
        courseRepository.courses.addAll([
          const CourseEntity(
            id: 7,
            name: 'المادة القديمة',
            instructor: 'محاضر',
            code: 'OLD-7',
          ),
          const CourseEntity(
            id: 8,
            name: 'المادة الجديدة',
            instructor: 'محاضر',
            code: 'NEW-8',
          ),
        ]);
        taskRepository.tasks.add(
          const TaskEntity(
            id: 31,
            title: 'مشروع الفصل',
            description: 'وصف المشروع',
            type: TaskType.homework,
            courseId: 7,
            courseName: 'المادة القديمة',
          ),
        );
        const call = AcademicAssistantToolCall(
          name: 'update_task',
          arguments: {
            'task_id': 31,
            'type': 'project',
            'course_name': 'المادة الجديدة',
          },
        );
        final pending = await executor.execute(call);
        expect(pending.requiresConfirmation, isTrue);
        final result = await executor.execute(call, confirmed: true);

        expect(result.changedData, isTrue);
        expect(taskRepository.tasks.single.type, TaskType.project);
        expect(taskRepository.tasks.single.courseId, 8);
        expect(taskRepository.tasks.single.courseName, 'المادة الجديدة');
        expect(await executor.verifyPostcondition(call, result), isTrue);
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
      const updateCall = AcademicAssistantToolCall(
        name: 'update_material',
        arguments: {
          'course_id': 31,
          'name': 'أمن الشبكات المتقدم',
          'credits': 3,
        },
      );
      final pending = await executor.execute(updateCall);
      expect(pending.requiresConfirmation, isTrue);
      final result = await executor.execute(updateCall, confirmed: true);
      expect(await executor.verifyPostcondition(updateCall, result), isTrue);

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

    test(
      'verifies the persisted attachment row and exact BLOB bytes',
      () async {
        final database = DatabaseHelper.instance;
        await database.close();
        int? materialId;
        try {
          courseRepository.courses.add(
            const CourseEntity(
              id: 55,
              name: 'أمن الشبكات',
              instructor: 'محاضر',
              code: 'SEC-55',
            ),
          );
          final bytes = Uint8List.fromList([37, 80, 68, 70, 1, 2, 3]);
          final call = AcademicAssistantToolCall(
            name: 'add_material_file',
            arguments: {
              'course_name': 'أمن الشبكات',
              'file_name': 'lecture.pdf',
              'file_type': 'pdf',
              'file_bytes': bytes,
            },
          );
          final result = await executor.execute(call);
          materialId = result.affectedRecordId;
          expect(result.changedData, isTrue);
          expect(materialId, isNotNull);
          expect(await executor.verifyPostcondition(call, result), isTrue);
          final duplicate = await executor.execute(call);
          expect(duplicate.succeeded, isTrue);
          expect(duplicate.changedData, isFalse);

          final db = await database.database;
          await db.update(
            'course_materials',
            {
              'file_bytes': Uint8List.fromList([37, 80, 68, 70, 1, 2, 4]),
            },
            where: 'id = ?',
            whereArgs: [materialId],
          );
          expect(await executor.verifyPostcondition(call, result), isFalse);

          await database.deleteMaterial(materialId!);
          expect(await executor.verifyPostcondition(call, result), isFalse);
          materialId = null;
        } finally {
          if (materialId != null) await database.deleteMaterial(materialId);
          await database.close();
        }
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
        final saved = (await database.getExams()).singleWhere(
          (exam) => exam.title == 'اختبار الشبكات',
        );
        createdExamId = saved.id;
        expect(saved.courseId, 77);

        final updateExamCall = AcademicAssistantToolCall(
          name: 'update_exam',
          arguments: {
            'exam_id': saved.id,
            'title': 'اختبار الشبكات النهائي',
            'exam_date': '2027-02-16T10:00:00.000',
          },
        );
        final updateConfirmation = await executor.execute(updateExamCall);
        expect(updateConfirmation.requiresConfirmation, isTrue);
        final updated = await executor.execute(updateExamCall, confirmed: true);
        expect(
          await executor.verifyPostcondition(updateExamCall, updated),
          isTrue,
        );
        final invalidCourseCall = AcademicAssistantToolCall(
          name: 'update_exam',
          arguments: {
            'exam_id': saved.id,
            'title': 'اختبار الشبكات النهائي',
            'exam_date': '2027-02-16T10:00:00.000',
            'course_name': 'مادة غير موجودة',
          },
        );
        expect(
          await executor.verifyPostcondition(invalidCourseCall, updated),
          isFalse,
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

      final deleted = await executor.execute(
        const AcademicAssistantToolCall(
          name: 'delete_task',
          arguments: {'task_id': 12},
        ),
        confirmed: true,
      );
      expect(deleted.changedData, isTrue);
      expect(deleted.affectedRecordId, 12);
      expect(
        await executor.verifyPostcondition(
          const AcademicAssistantToolCall(
            name: 'delete_task',
            arguments: {'task_id': 12},
          ),
          deleted,
        ),
        isTrue,
      );
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