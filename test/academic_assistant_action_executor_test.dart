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

  group('AcademicAssistantActionExecutor plan preflight', () {
    test('rejects a later missing reference before any earlier create action runs', () async {
      final result = await executor.preflightPlan([
        const AcademicAssistantToolCall(
          name: 'create_material',
          arguments: {'name': 'أمن الشبكات'},
        ),
        const AcademicAssistantToolCall(
          name: 'add_lecture',
          arguments: {
            'course_name': 'مادة غير موجودة',
            'day': 'الأحد',
            'start_time': '08:00',
            'end_time': '09:00',
          },
        ),
      ]);

      expect(result.succeeded, isFalse);
      expect(result.message, contains('لم تُنفذ أي خطوة'));
      expect(courseRepository.courses, isEmpty);
    });


    test('rejects malformed and mismatched course and task identifiers', () async {
      taskRepository.tasks.add(
        const TaskEntity(id: 1, title: 'عنوان صحيح', description: ''),
      );
      final malformedCourse = await executor.preflightPlan([
        const AcademicAssistantToolCall(
          name: 'create_task',
          arguments: {'title': 'مراجعة', 'course_id': 'invalid'},
        ),
      ]);
      expect(malformedCourse.succeeded, isFalse);
      expect(malformedCourse.message, contains('معرّف المادة'));

      final mismatchedTask = await executor.preflightPlan([
        const AcademicAssistantToolCall(
          name: 'complete_task',
          arguments: {'task_id': 1, 'task_title': 'عنوان غير مطابق'},
        ),
      ]);
      expect(mismatchedTask.succeeded, isFalse);
      expect(mismatchedTask.message, contains('معرّف المهمة'));
    });

    test('allows later actions to reference a course created earlier in the same plan', () async {
      final result = await executor.preflightPlan([
        const AcademicAssistantToolCall(
          name: 'create_material',
          arguments: {'name': 'الشبكات'},
        ),
        const AcademicAssistantToolCall(
          name: 'create_task',
          arguments: {
            'title': 'مراجعة أساسيات الشبكات',
            'course_name': 'الشبكات',
          },
        ),
        const AcademicAssistantToolCall(
          name: 'add_lecture',
          arguments: {
            'course_name': 'الشبكات',
            'day': 'الأحد',
            'start_time': '08:00',
            'end_time': '09:00',
          },
        ),
      ]);

      expect(result.succeeded, isTrue);
      expect(courseRepository.courses, isEmpty);
      expect(taskRepository.tasks, isEmpty);
    });


    test('rejects invalid lecture reminder options during preflight', () async {
      courseRepository.courses.add(
        const CourseEntity(
          id: 1,
          name: 'الشبكات',
          instructor: 'محاضر',
          code: 'NET101',
        ),
      );
      final invalidToggle = await executor.preflightPlan([
        const AcademicAssistantToolCall(
          name: 'add_lecture',
          arguments: {
            'course_name': 'الشبكات',
            'day': 'الأحد',
            'start_time': '08:00',
            'end_time': '09:00',
            'reminder_enabled': 'false',
          },
        ),
      ]);
      expect(invalidToggle.succeeded, isFalse);
      expect(invalidToggle.message, contains('تذكير المحاضرة'));

      final invalidOffset = await executor.preflightPlan([
        const AcademicAssistantToolCall(
          name: 'add_lecture',
          arguments: {
            'course_name': 'الشبكات',
            'day': 'الأحد',
            'start_time': '08:00',
            'end_time': '09:00',
            'reminder_offset_minutes': 'later',
          },
        ),
      ]);
      expect(invalidOffset.succeeded, isFalse);
      expect(invalidOffset.message, contains('مدة التنبيه'));
    });

    test('detects conflicts between two proposed lectures before the first write', () async {
      final result = await executor.preflightPlan([
        const AcademicAssistantToolCall(
          name: 'create_material',
          arguments: {'name': 'قواعد البيانات'},
        ),
        const AcademicAssistantToolCall(
          name: 'add_lecture',
          arguments: {
            'course_name': 'قواعد البيانات',
            'day': 'الأحد',
            'start_time': '08:00',
            'end_time': '09:00',
          },
        ),
        const AcademicAssistantToolCall(
          name: 'add_lecture',
          arguments: {
            'course_name': 'قواعد البيانات',
            'day': 'الأحد',
            'start_time': '08:30',
            'end_time': '09:30',
          },
        ),
      ]);

      expect(result.succeeded, isFalse);
      expect(result.message, contains('تعارض'));
      expect(courseRepository.courses, isEmpty);
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
        expect(
          await executor.verifyPostcondition(
            const AcademicAssistantToolCall(
              name: 'update_profile',
              arguments: {'semester': 'الثاني', 'department': 'الأمن السيبراني'},
            ),
            result,
          ),
          isTrue,
        );
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
        expect(
          await executor.verifyPostcondition(
            const AcademicAssistantToolCall(
              name: 'create_material',
              arguments: {'name': 'أمن الشبكات'},
            ),
            first,
          ),
          isTrue,
        );
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
        const createTaskCall = AcademicAssistantToolCall(
          name: 'create_task',
          arguments: {
            'title': 'مراجعة المحاضرة الأولى',
            'course_name': 'أمن الشبكات',
          },
        );
        expect(await executor.verifyPostcondition(createTaskCall, result), isTrue);
        expect(taskRepository.tasks.single.courseId, 7);
        expect(taskRepository.tasks.single.courseName, 'أمن الشبكات');
        expect(taskRepository.tasks.single.type, TaskType.other);
        expect(taskRepository.tasks.single.priority, TaskPriority.medium);
        taskRepository.tasks[0] = taskRepository.tasks.single.copyWith(
          courseId: 999,
          courseName: 'مادة أخرى',
        );
        expect(await executor.verifyPostcondition(createTaskCall, result), isFalse);
        taskRepository.tasks[0] = taskRepository.tasks.single.copyWith(
          courseId: 7,
          courseName: 'أمن الشبكات',
          title: 'قيمة لم تُحفظ',
        );
        expect(await executor.verifyPostcondition(createTaskCall, result), isFalse);
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

    test('verifies attachment bytes after a database write', () async {
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
        final call = AcademicAssistantToolCall(
          name: 'add_material_file',
          arguments: {
            'course_name': 'أمن الشبكات',
            'file_name': 'lecture.pdf',
            'file_type': 'pdf',
            'file_bytes': Uint8List.fromList([37, 80, 68, 70, 1, 2, 3]),
          },
        );
        final result = await executor.execute(call);
        materialId = result.affectedRecordId;

        expect(result.succeeded, isTrue);
        expect(materialId, isNotNull);
        expect(await executor.verifyPostcondition(call, result), isTrue);

        // A same-length but corrupted BLOB must not pass postcondition checks.
        final db = await database.database;
        await db.update(
          'course_materials',
          {'file_bytes': Uint8List.fromList([37, 80, 68, 70, 1, 2, 4])},
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
    });

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

        const createExamCall = AcademicAssistantToolCall(
          name: 'create_exam',
          arguments: {
            'title': 'اختبار الشبكات',
            'exam_date': '2027-02-15T09:30:00.000',
            'course_name': 'أمن الشبكات',
          },
        );
        final created = await executor.execute(createExamCall);
        expect(created.changedData, isTrue);
        expect(await executor.verifyPostcondition(createExamCall, created), isTrue);
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
          await executor.verifyPostcondition(
            AcademicAssistantToolCall(
              name: 'update_exam',
              arguments: {
                'exam_id': saved.id,
                'title': 'اختبار الشبكات النهائي',
                'exam_date': '2027-02-16T10:00:00.000',
              },
            ),
            updated,
          ),
          isTrue,
        );
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
        expect(
          await executor.verifyPostcondition(
            AcademicAssistantToolCall(
              name: 'delete_exam',
              arguments: {'exam_id': saved.id},
            ),
            deleted,
          ),
          isTrue,
        );
        expect(await database.getExamById(saved.id!), isNull);
        createdExamId = null;
      } finally {
        if (createdExamId != null) {
          await database.deleteExam(createdExamId);
        }
        await database.close();
      }
    });

    test('verifies course updates against the repository state', () async {
      courseRepository.courses.add(
        const CourseEntity(
          id: 31,
          name: 'الشبكات',
          instructor: 'محاضر',
          code: 'NET-31',
          credits: 2,
        ),
      );
      const call = AcademicAssistantToolCall(
        name: 'update_material',
        arguments: {
          'course_id': 31,
          'name': 'أمن الشبكات المتقدم',
          'instructor': 'د. أحمد',
          'credits': 99,
        },
      );

      final result = await executor.execute(call);
      expect(result.succeeded, isTrue);
      expect(result.changedData, isTrue);
      expect(result.affectedRecordId, 31);
      expect(courseRepository.courses.single.credits, 30);
      expect(await executor.verifyPostcondition(call, result), isTrue);

      courseRepository.courses[0] = courseRepository.courses.single.copyWith(
        credits: 2,
      );
      expect(await executor.verifyPostcondition(call, result), isFalse);
    });

    test('verifies task updates and rejects stale persisted values', () async {
      taskRepository.tasks.add(
        TaskEntity(
          id: 10,
          title: 'مراجعة أولية',
          description: 'الوصف القديم',
          startDateTime: DateTime(2026, 11, 1),
        ),
      );
      const call = AcademicAssistantToolCall(
        name: 'update_task',
        arguments: {
          'task_id': 10,
          'title': 'مراجعة نهائية',
          'description': 'الوصف المعتمد',
          'priority': 'urgent',
          'end_date_time': '2027-02-15T09:30:00.000',
        },
      );

      final result = await executor.execute(call);
      expect(result.succeeded, isTrue);
      expect(result.changedData, isTrue);
      expect(await executor.verifyPostcondition(call, result), isTrue);

      taskRepository.tasks[0] = taskRepository.tasks.single.copyWith(
        title: 'قيمة قديمة',
      );
      expect(await executor.verifyPostcondition(call, result), isFalse);
    });

    test('verifies task completion and deletion after persistence', () async {
      taskRepository.tasks.add(
        const TaskEntity(id: 12, title: 'مراجعة التشفير', description: ''),
      );
      const completeCall = AcademicAssistantToolCall(
        name: 'complete_task',
        arguments: {'task_id': 12},
      );

      final completed = await executor.execute(completeCall);
      expect(completed.succeeded, isTrue);
      expect(completed.changedData, isTrue);
      expect(await executor.verifyPostcondition(completeCall, completed), isTrue);

      taskRepository.tasks[0] = taskRepository.tasks.single.copyWith(
        isCompleted: false,
      );
      expect(await executor.verifyPostcondition(completeCall, completed), isFalse);

      taskRepository.tasks[0] = taskRepository.tasks.single.copyWith(
        isCompleted: true,
      );
      const deleteCall = AcademicAssistantToolCall(
        name: 'delete_task',
        arguments: {'task_id': 12},
      );
      final deleted = await executor.execute(deleteCall, confirmed: true);
      expect(deleted.succeeded, isTrue);
      expect(deleted.changedData, isTrue);
      expect(await executor.verifyPostcondition(deleteCall, deleted), isTrue);
    });

    test('verifies lecture course link and normalized reminder offset', () async {
      final database = DatabaseHelper.instance;
      await database.close();
      int? scheduleId;
      try {
        courseRepository.courses.add(
          const CourseEntity(
            id: 88,
            name: 'هندسة البرمجيات',
            instructor: 'محاضر',
            code: 'SWE-88',
          ),
        );
        const call = AcademicAssistantToolCall(
          name: 'add_lecture',
          arguments: {
            'course_name': 'هندسة البرمجيات',
            'day': 'السبت',
            'start_time': '23:00',
            'end_time': '23:30',
            'location': 'قاعة الاختبار',
            'reminder_enabled': false,
            'reminder_offset_minutes': 2000,
          },
        );

        final result = await executor.execute(call);
        scheduleId = result.affectedRecordId;
        expect(result.succeeded, isTrue);
        expect(scheduleId, isNotNull);
        expect(await executor.verifyPostcondition(call, result), isTrue);

        final db = await database.database;
        final rows = await db.query(
          'schedule',
          where: 'id = ?',
          whereArgs: [scheduleId],
        );
        expect(rows, hasLength(1));
        expect(rows.single['reminder_offset_minutes'], 1440);

        final updateCall = AcademicAssistantToolCall(
          name: 'update_lecture',
          arguments: {
            'schedule_id': scheduleId,
            'course_id': 88,
            'day': 'السبت',
            'start_time': '23:15',
            'end_time': '23:45',
            'location': 'قاعة أخرى',
            'reminder_enabled': false,
            'reminder_offset_minutes': 2000,
          },
        );
        final updated = await executor.execute(updateCall);
        expect(updated.succeeded, isTrue);
        expect(updated.changedData, isTrue);
        expect(await executor.verifyPostcondition(updateCall, updated), isTrue);

        await db.update(
          'schedule',
          {'course_id': 999},
          where: 'id = ?',
          whereArgs: [scheduleId],
        );
        expect(await executor.verifyPostcondition(updateCall, updated), isFalse);
        await db.update(
          'schedule',
          {'course_id': 88},
          where: 'id = ?',
          whereArgs: [scheduleId],
        );

        const deleteCallName = 'delete_lecture';
        final deleteCall = AcademicAssistantToolCall(
          name: deleteCallName,
          arguments: {'schedule_id': scheduleId},
        );
        final confirmation = await executor.execute(deleteCall);
        expect(confirmation.requiresConfirmation, isTrue);
        expect(confirmation.confirmationPrompt, contains('هندسة البرمجيات'));

        final deleted = await executor.execute(deleteCall, confirmed: true);
        expect(deleted.succeeded, isTrue);
        expect(deleted.changedData, isTrue);
        expect(await executor.verifyPostcondition(deleteCall, deleted), isTrue);
        scheduleId = null;
      } finally {
        if (scheduleId != null) await database.deleteSchedule(scheduleId);
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
