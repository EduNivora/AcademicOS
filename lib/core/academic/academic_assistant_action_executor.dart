import '../../data/database/database_helper.dart';
import '../../data/models/course_material_model.dart';
import '../../data/models/exam_model.dart';
import 'dart:typed_data';
import '../../data/models/student_profile_model.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/usecases/course_use_cases.dart';
import '../../domain/usecases/task_use_cases.dart';
import '../notifications/notification_service.dart';
import 'schedule_conflict_validator.dart';
import 'academic_report_service.dart';

class AcademicAssistantToolCall {
  final String name;
  final Map<String, dynamic> arguments;

  const AcademicAssistantToolCall({
    required this.name,
    required this.arguments,
  });

  factory AcademicAssistantToolCall.fromJson(Map<String, dynamic> json) {
    final arguments = json['arguments'];
    return AcademicAssistantToolCall(
      name: json['name']?.toString() ?? '',
      arguments: arguments is Map
          ? Map<String, dynamic>.from(arguments)
          : const <String, dynamic>{},
    );
  }
}

class AcademicAssistantToolResult {
  final String message;
  final bool succeeded;
  final bool changedData;
  final bool requiresConfirmation;
  final String? confirmationPrompt;
  final int? affectedRecordId;

  const AcademicAssistantToolResult({
    required this.message,
    this.succeeded = false,
    this.changedData = false,
    this.requiresConfirmation = false,
    this.confirmationPrompt,
    this.affectedRecordId,
  });
}

class AcademicAssistantCommandParser {
  const AcademicAssistantCommandParser();

  AcademicAssistantToolCall? parse(String input) {
    final value = input.trim();
    final addMaterial = RegExp(
      r'^(?:أضف|اضف|أنشئ|انشئ)\s+مادة\s+(.+)$',
    ).firstMatch(value);
    if (addMaterial != null) {
      return AcademicAssistantToolCall(
        name: 'create_material',
        arguments: {'name': addMaterial.group(1)!.trim()},
      );
    }

    final createTask = RegExp(
      r'^(?:أنشئ|انشئ|أضف|اضف)\s+مهمة\s+(.+)$',
    ).firstMatch(value);
    if (createTask != null) {
      final rawTitle = createTask.group(1)!.trim();
      final materialMatch = RegExp(
        r'(?:لمادة|مادة)\s+(.+?)(?:\s+(?:غداً|غدا|اليوم|بكرة|الساعة).*)?$',
      ).firstMatch(rawTitle);
      final courseName = materialMatch?.group(1)?.trim();
      var title = materialMatch == null
          ? rawTitle
          : rawTitle.substring(0, materialMatch.start).trim();
      if (materialMatch == null) {
        title = title.replaceFirst(
          RegExp(r'\s+(?:غداً|غدا|بكرة|اليوم|الساعة)\b.*$'),
          '',
        );
      }
      title = title
          .replaceFirst(RegExp(r'^(?:لمراجعة|مراجعة|بخصوص)\s*'), '')
          .trim();
      if (title.isEmpty && courseName != null && courseName.isNotEmpty) {
        title = 'مراجعة $courseName';
      }
      final endDateTime = _parseArabicEndDateTime(rawTitle);
      return AcademicAssistantToolCall(
        name: 'create_task',
        arguments: {
          'title': title.isEmpty ? rawTitle : title,
          if (courseName != null && courseName.isNotEmpty)
            'course_name': courseName,
          if (endDateTime != null)
            'end_date_time': endDateTime.toIso8601String(),
        },
      );
    }

    final deleteLecture = RegExp(
      r'^(?:احذف|حذف)\s+محاضرة\s+(\d+)$',
    ).firstMatch(value);
    if (deleteLecture != null) {
      return AcademicAssistantToolCall(
        name: 'delete_lecture',
        arguments: {'schedule_id': int.parse(deleteLecture.group(1)!)},
      );
    }

    final deleteMaterial = RegExp(
      r'^(?:احذف|حذف)\s+مادة\s+(.+)$',
    ).firstMatch(value);
    if (deleteMaterial != null) {
      return AcademicAssistantToolCall(
        name: 'delete_material',
        arguments: {'course_name': deleteMaterial.group(1)!.trim()},
      );
    }

    final completeTask = RegExp(
      r'^(?:أكمل|اكمل)\s+مهمة\s+(.+)$',
    ).firstMatch(value);
    if (completeTask != null) {
      return AcademicAssistantToolCall(
        name: 'complete_task',
        arguments: {'task_title': completeTask.group(1)!.trim()},
      );
    }

    final deleteTask = RegExp(
      r'^(?:احذف|حذف)\s+مهمة\s+(.+)$',
    ).firstMatch(value);
    if (deleteTask != null) {
      return AcademicAssistantToolCall(
        name: 'delete_task',
        arguments: {'task_title': deleteTask.group(1)!.trim()},
      );
    }

    final normalized = value.toLowerCase();
    final period = normalized.contains('أسبوع') || normalized.contains('اسبوع')
        ? 'weekly'
        : normalized.contains('شهر')
        ? 'monthly'
        : normalized.contains('نهائي')
        ? 'final'
        : 'daily';
    if (normalized.contains('تقرير') || normalized.contains('التقرير')) {
      return AcademicAssistantToolCall(
        name: 'generate_report',
        arguments: {'period': period},
      );
    }
    return null;
  }

  DateTime? _parseArabicEndDateTime(String value) {
    final normalized = value
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');
    final match = RegExp(
      r'(?:الساعة\s*)?(\d{1,2})(?::(\d{2}))?\s*(صباحاً|صباحا|مساءً|مساء|ص|م)?',
    ).firstMatch(normalized);
    if (match == null || !normalized.contains('الساعة')) return null;
    var hour = int.tryParse(match.group(1) ?? '') ?? -1;
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    if (hour < 0 || hour > 23 || minute > 59) return null;
    final suffix = match.group(3) ?? '';
    if ((suffix.startsWith('م') || suffix.startsWith('مساء')) && hour < 12) {
      hour += 12;
    } else if ((suffix.startsWith('ص') || suffix.startsWith('صباح')) &&
        hour == 12) {
      hour = 0;
    }
    final now = DateTime.now();
    final isTomorrow =
        normalized.contains('غداً') ||
        normalized.contains('غدا') ||
        normalized.contains('بكرة');
    final base = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: isTomorrow ? 1 : 0));
    return DateTime(base.year, base.month, base.day, hour, minute);
  }
}

class AcademicAssistantActionExecutor {
  static const Set<String> _confirmationRequiredActions = {
    'update_profile',
    'update_material',
    'update_task',
    'update_lecture',
    'update_exam',
  };

  static const Map<String, Set<String>> _allowedArgumentKeys = {
    'create_material': {'name', 'instructor', 'code', 'credits'},
    'add_material_file': {
      'course_id',
      'course_name',
      'file_bytes',
      'file_name',
      'file_type',
    },
    'update_profile': {
      'full_name',
      'university',
      'major',
      'department',
      'semester',
      'academic_level',
    },
    'update_material': {
      'course_id',
      'course_name',
      'name',
      'instructor',
      'code',
      'credits',
    },
    'delete_material': {'course_id', 'course_name'},
    'create_task': {
      'title',
      'description',
      'type',
      'priority',
      'course_id',
      'course_name',
      'end_date_time',
      'reminder_enabled',
      'reminder_offset_minutes',
    },
    'complete_task': {'task_id', 'task_title'},
    'update_task': {
      'task_id',
      'task_title',
      'title',
      'description',
      'type',
      'priority',
      'course_id',
      'course_name',
      'end_date_time',
      'reminder_enabled',
      'reminder_offset_minutes',
    },
    'delete_task': {'task_id', 'task_title'},
    'add_lecture': {
      'course_id',
      'course_name',
      'day',
      'start_time',
      'end_time',
      'location',
      'reminder_enabled',
      'reminder_offset_minutes',
    },
    'update_lecture': {
      'schedule_id',
      'course_id',
      'course_name',
      'day',
      'start_time',
      'end_time',
      'location',
      'reminder_enabled',
      'reminder_offset_minutes',
    },
    'delete_lecture': {'schedule_id'},
    'create_exam': {
      'title',
      'exam_date',
      'course_id',
      'course_name',
      'location',
      'notes',
    },
    'update_exam': {
      'exam_id',
      'title',
      'exam_date',
      'course_id',
      'course_name',
      'location',
      'notes',
    },
    'delete_exam': {'exam_id'},
    'generate_report': {'period'},
  };

  final CourseUseCases courseUseCases;
  final TaskUseCases taskUseCases;
  final DatabaseHelper database;

  AcademicAssistantActionExecutor({
    required this.courseUseCases,
    required this.taskUseCases,
    DatabaseHelper? database,
  }) : database = database ?? DatabaseHelper.instance;

  Future<AcademicAssistantToolResult> execute(
    AcademicAssistantToolCall call, {
    bool confirmed = false,
  }) async {
    final allowedKeys = _allowedArgumentKeys[call.name];
    if (allowedKeys == null) {
      return const AcademicAssistantToolResult(
        message: 'هذه العملية غير متاحة للمساعد حالياً.',
      );
    }
    final unexpectedKeys = call.arguments.keys
        .where((key) => !allowedKeys.contains(key))
        .toList(growable: false);
    if (unexpectedKeys.isNotEmpty) {
      return const AcademicAssistantToolResult(
        message: 'تحتوي العملية على حقول غير مسموح بها. لم يتم تنفيذ أي تغيير.',
      );
    }
    for (final entry in call.arguments.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key == 'file_bytes') {
        if (value is! List ||
            value.isEmpty ||
            value.length > 50 * 1024 * 1024 ||
            value.any((byte) => byte is! int || byte < 0 || byte > 255)) {
          return const AcademicAssistantToolResult(
            message: 'محتوى الملف غير صالح أو يتجاوز الحد المسموح.',
          );
        }
      } else if (key == 'reminder_enabled') {
        if (value is! bool) {
          return const AcademicAssistantToolResult(
            message: 'قيمة التذكير غير صالحة.',
          );
        }
      } else if ({
        'credits',
        'course_id',
        'task_id',
        'schedule_id',
        'exam_id',
        'reminder_offset_minutes',
      }.contains(key)) {
        if (value is! int && int.tryParse(value.toString()) == null) {
          return const AcademicAssistantToolResult(
            message: 'إحدى القيم الرقمية غير صالحة.',
          );
        }
      } else if ({'end_date_time', 'exam_date'}.contains(key)) {
        if (value is! String && value is! DateTime) {
          return const AcademicAssistantToolResult(
            message: 'صيغة التاريخ أو الوقت غير صالحة.',
          );
        }
        if (_date(value) == null) {
          return const AcademicAssistantToolResult(
            message: 'صيغة التاريخ أو الوقت غير صالحة.',
          );
        }
      } else if (value is! String || value.length > 2000) {
        return const AcademicAssistantToolResult(
          message: 'إحدى القيم النصية غير صالحة أو تتجاوز الحد المسموح.',
        );
      }
    }
    if (_confirmationRequiredActions.contains(call.name) && !confirmed) {
      final target = switch (call.name) {
        'update_profile' => 'ملفك الأكاديمي',
        'update_material' =>
          'المادة «${_string(call.arguments, 'course_name').isNotEmpty ? _string(call.arguments, 'course_name') : _string(call.arguments, 'course_id')}»',
        'update_task' =>
          'المهمة «${_string(call.arguments, 'task_title').isNotEmpty ? _string(call.arguments, 'task_title') : _string(call.arguments, 'task_id')}»',
        'update_lecture' =>
          'المحاضرة رقم ${_string(call.arguments, 'schedule_id')}',
        'update_exam' => 'الاختبار رقم ${_string(call.arguments, 'exam_id')}',
        _ => 'السجل الأكاديمي',
      };
      return AcademicAssistantToolResult(
        message: 'تعديل البيانات يتطلب تأكيدك.',
        requiresConfirmation: true,
        confirmationPrompt:
            'سيتم تعديل $target بالقيم التي حددتها. هل تؤكد تنفيذ التعديل؟',
      );
    }
    return switch (call.name) {
      'create_material' => _createMaterial(call.arguments),
      'add_material_file' => _addMaterialFile(call.arguments),
      'update_profile' => _updateProfile(call.arguments),
      'update_material' => _updateMaterial(call.arguments),
      'delete_material' => _deleteMaterial(
        call.arguments,
        confirmed: confirmed,
      ),
      'create_task' => _createTask(call.arguments),
      'complete_task' => _completeTask(call.arguments),
      'update_task' => _updateTask(call.arguments),
      'delete_task' => _deleteTask(call.arguments, confirmed: confirmed),
      'add_lecture' => _addLecture(call.arguments),
      'update_lecture' => _updateLecture(call.arguments),
      'delete_lecture' => _deleteLecture(call.arguments, confirmed: confirmed),
      'create_exam' => _createExam(call.arguments),
      'update_exam' => _updateExam(call.arguments),
      'delete_exam' => _deleteExam(call.arguments, confirmed: confirmed),
      'generate_report' => _generateReport(call.arguments),
      _ => const AcademicAssistantToolResult(
        message: 'هذه العملية غير متاحة للمساعد حالياً.',
      ),
    };
  }

  /// Re-reads the affected record after a write before reporting success.
  /// A successful SQL call alone is not treated as proof of persisted state.
  Future<bool> verifyPostcondition(
    AcademicAssistantToolCall call,
    AcademicAssistantToolResult result,
  ) async {
    if (!result.changedData) return true;
    final id = result.affectedRecordId;
    try {
      switch (call.name) {
        case 'create_material':
        case 'update_material':
          if (id == null) return false;
          final courses = await courseUseCases.getCourses();
          final course = courses.where((item) => item.id == id).firstOrNull;
          if (course == null) return false;
          final name = _string(call.arguments, 'name');
          final instructor = _string(call.arguments, 'instructor');
          final code = _string(call.arguments, 'code');
          final credits = _integer(call.arguments['credits']);
          return (name.isEmpty ||
                  _normalize(course.name) == _normalize(name)) &&
              (instructor.isEmpty || course.instructor == instructor) &&
              (code.isEmpty || course.code == code) &&
              (credits == null ||
                  course.credits == credits.clamp(0, 30).toInt());
        case 'delete_material':
          if (id == null) return false;
          final courses = await courseUseCases.getCourses();
          if (courses.any((item) => item.id == id)) return false;
          final db = await database.database;
          for (final table in [
            'tasks',
            'schedule',
            'exams',
            'course_materials',
          ]) {
            final rows = await db.query(
              table,
              columns: ['id'],
              where: 'course_id = ?',
              whereArgs: [id],
              limit: 1,
            );
            if (rows.isNotEmpty) return false;
          }
          return true;
        case 'add_material_file':
          if (id == null) return false;
          final row = await database.getMaterialById(id);
          final rawBytes = call.arguments['file_bytes'];
          final expectedBytes = rawBytes is List ? rawBytes : const <int>[];
          final storedBytes = row?['file_bytes'];
          final bytesMatch =
              storedBytes is List &&
              expectedBytes.isNotEmpty &&
              storedBytes.length == expectedBytes.length &&
              List<int>.generate(
                expectedBytes.length,
                (index) => storedBytes[index] as int,
              ).asMap().entries.every(
                (entry) => entry.value == expectedBytes[entry.key],
              );
          final courseResult = await _resolveCourse(call.arguments);
          return row != null &&
              courseResult.course?.id == row['course_id'] &&
              row['title'] == _string(call.arguments, 'file_name') &&
              bytesMatch;
        case 'create_task':
        case 'complete_task':
        case 'update_task':
          if (id == null) return false;
          final tasks = await taskUseCases.getTasks();
          final task = tasks.where((item) => item.id == id).firstOrNull;
          if (task == null) return false;
          if (call.name == 'complete_task') {
            return task.isCompleted && task.completedAt != null;
          }

          final args = call.arguments;
          final isCreate = call.name == 'create_task';
          final title = _string(args, 'title');
          final description = _string(args, 'description');
          final priority = _string(args, 'priority');
          final type = _string(args, 'type');
          final endDate = _date(args['end_date_time']);
          final rawReminderOffset = _integer(args['reminder_offset_minutes']);
          final expectedReminderOffset = rawReminderOffset == null
              ? (isCreate ? 15 : task.reminderOffsetMinutes)
              : rawReminderOffset.clamp(0, 1440).toInt();
          final courseSpecified =
              args.containsKey('course_id') ||
              _string(args, 'course_name').isNotEmpty;
          if (courseSpecified) {
            final courseResult = await _resolveCourse(args);
            if (courseResult.error != null || courseResult.course == null) {
              return false;
            }
            if (task.courseId != courseResult.course!.id ||
                task.courseName != courseResult.course!.name) {
              return false;
            }
          }
          final expectedReminderEnabled = isCreate
              ? endDate != null && args['reminder_enabled'] != false
              : args['reminder_enabled'] is bool
              ? args['reminder_enabled'] as bool
              : task.reminderEnabled;
          final effectiveEndDate = isCreate
              ? endDate
              : endDate ?? task.endDateTime;
          final expectedReminderDate =
              expectedReminderEnabled && effectiveEndDate != null
              ? effectiveEndDate.subtract(
                  Duration(minutes: expectedReminderOffset),
                )
              : null;

          return (isCreate
                  ? task.title == title
                  : title.isEmpty || task.title == title) &&
              (isCreate
                  ? task.description == description
                  : description.isEmpty || task.description == description) &&
              (!(isCreate || priority.isNotEmpty) ||
                  task.priority == TaskPriorityX.fromName(priority)) &&
              (isCreate
                  ? task.type == TaskTypeX.fromName(type)
                  : type.isEmpty || task.type == TaskTypeX.fromName(type)) &&
              (!isCreate || task.startDateTime != null) &&
              (isCreate
                  ? endDate == null
                        ? task.endDateTime == null
                        : task.endDateTime?.isAtSameMomentAs(endDate) == true
                  : endDate == null ||
                        task.endDateTime?.isAtSameMomentAs(endDate) == true) &&
              task.reminderOffsetMinutes == expectedReminderOffset &&
              task.reminderEnabled == expectedReminderEnabled &&
              task.reminderDate == expectedReminderDate;
        case 'delete_task':
          if (id == null) return false;
          final tasks = await taskUseCases.getTasks();
          return !tasks.any((item) => item.id == id);
        case 'add_lecture':
        case 'update_lecture':
          if (id == null) return false;
          final args = call.arguments;
          final isCreate = call.name == 'add_lecture';
          final schedules = await database.getSchedules();
          final row = schedules.where((item) => item['id'] == id).firstOrNull;
          if (row == null) return false;
          final day = _string(args, 'day');
          final start = _string(args, 'start_time');
          final end = _string(args, 'end_time');
          final location = _string(args, 'location');
          final rawReminderOffset = _integer(args['reminder_offset_minutes']);
          final reminderOffset = rawReminderOffset == null
              ? (isCreate ? 15 : null)
              : rawReminderOffset.clamp(0, 1440).toInt();
          final courseSpecified =
              args.containsKey('course_id') ||
              _string(args, 'course_name').isNotEmpty;
          final courseResult = courseSpecified
              ? await _resolveCourse(args)
              : null;
          if (courseSpecified &&
              (courseResult!.error != null || courseResult.course == null)) {
            return false;
          }
          final reminderValue = row['reminder_enabled'];
          final reminderEnabled = reminderValue == 1 || reminderValue == true;
          final expectedReminderEnabled = isCreate
              ? args['reminder_enabled'] is bool
                    ? args['reminder_enabled'] as bool
                    : true
              : args['reminder_enabled'] is bool
              ? args['reminder_enabled'] as bool
              : null;
          return (isCreate
                  ? row['day_of_week'] == day
                  : day.isEmpty || row['day_of_week'] == day) &&
              (isCreate
                  ? row['start_time'] == start
                  : start.isEmpty || row['start_time'] == start) &&
              (isCreate
                  ? row['end_time'] == end
                  : end.isEmpty || row['end_time'] == end) &&
              (isCreate || location.isEmpty || row['location'] == location) &&
              (!isCreate || row['location'] == location) &&
              (!courseSpecified ||
                  row['course_id'] == courseResult!.course!.id) &&
              (expectedReminderEnabled == null ||
                  reminderEnabled == expectedReminderEnabled) &&
              (reminderOffset == null ||
                  row['reminder_offset_minutes'] == reminderOffset);
        case 'delete_lecture':
          if (id == null) return false;
          final schedules = await database.getSchedules();
          return !schedules.any((item) => item['id'] == id);
        case 'create_exam':
        case 'update_exam':
          if (id == null) return false;
          final exam = await database.getExamById(id);
          if (exam == null) return false;
          final title = _string(call.arguments, 'title');
          final date = _date(call.arguments['exam_date']);
          final location = _string(call.arguments, 'location');
          final notes = _string(call.arguments, 'notes');
          final courseResult = await _resolveCourse(call.arguments);
          return (title.isEmpty || exam.title == title) &&
              (date == null || exam.examDate.isAtSameMomentAs(date)) &&
              (location.isEmpty || exam.location == location) &&
              (notes.isEmpty || exam.notes == notes) &&
              (courseResult.course == null ||
                  exam.courseId == courseResult.course!.id);
        case 'delete_exam':
          if (id == null) return false;
          return await database.getExamById(id) == null;
        case 'update_profile':
          final profile = await StudentProfile.load();
          final args = call.arguments;
          return (_string(args, 'full_name').isEmpty ||
                  profile.fullName == _string(args, 'full_name')) &&
              (_string(args, 'university').isEmpty ||
                  profile.university == _string(args, 'university')) &&
              (_string(args, 'major').isEmpty ||
                  profile.major == _string(args, 'major')) &&
              (_string(args, 'department').isEmpty ||
                  profile.department == _string(args, 'department')) &&
              (_string(args, 'semester').isEmpty ||
                  profile.semester == _string(args, 'semester')) &&
              (_string(args, 'academic_level').isEmpty ||
                  profile.academicLevel == _string(args, 'academic_level'));
        default:
          return false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<AcademicAssistantToolResult> _updateProfile(
    Map<String, dynamic> args,
  ) async {
    final current = await StudentProfile.load();
    final fullName = _string(args, 'full_name');
    final university = _string(args, 'university');
    final major = _string(args, 'major');
    final department = _string(args, 'department');
    final semester = _string(args, 'semester');
    final academicLevel = _string(args, 'academic_level');
    final hasChanges = [
      fullName,
      university,
      major,
      department,
      semester,
      academicLevel,
    ].any((value) => value.isNotEmpty);
    if (!hasChanges) {
      return const AcademicAssistantToolResult(
        message: 'حدد بيانات الملف الأكاديمي التي تريد تعديلها.',
      );
    }
    final updated = current.copyWith(
      fullName: fullName.isEmpty ? null : fullName,
      university: university.isEmpty ? null : university,
      major: major.isEmpty ? null : major,
      department: department.isEmpty ? null : department,
      semester: semester.isEmpty ? null : semester,
      academicLevel: academicLevel.isEmpty ? null : academicLevel,
    );
    await StudentProfile.save(updated);
    return const AcademicAssistantToolResult(
      message: 'تم تحديث الملف الأكاديمي وحفظ البيانات.',
      succeeded: true,
      changedData: true,
    );
  }

  Future<AcademicAssistantToolResult> _createMaterial(
    Map<String, dynamic> args,
  ) async {
    final name = _string(args, 'name');
    if (name.isEmpty) {
      return const AcademicAssistantToolResult(
        message: 'لم تحدد اسم المادة. اكتب اسم المادة أولاً.',
      );
    }
    final courses = await courseUseCases.getCourses();
    final existing = courses.where(
      (course) => _normalize(course.name) == _normalize(name),
    );
    if (existing.isNotEmpty) {
      return AcademicAssistantToolResult(
        message:
            'المادة «${existing.first.name}» موجودة مسبقاً، ولم أضف نسخة مكررة.',
        succeeded: true,
      );
    }
    final id = await courseUseCases.addCourse(
      CourseEntity(
        name: name,
        instructor: _string(args, 'instructor').isEmpty
            ? 'غير محدد'
            : _string(args, 'instructor'),
        code: _string(args, 'code').isEmpty
            ? 'AUTO-${DateTime.now().microsecondsSinceEpoch}'
            : _string(args, 'code'),
        credits: (_integer(args['credits']) ?? 0).clamp(0, 30).toInt(),
      ),
    );
    return AcademicAssistantToolResult(
      message: 'تمت إضافة المادة «$name» بنجاح. رقمها الداخلي: $id.',
      succeeded: true,
      changedData: true,
      affectedRecordId: id,
    );
  }

  Future<AcademicAssistantToolResult> _addMaterialFile(
    Map<String, dynamic> args,
  ) async {
    final resolved = await _resolveCourse(args);
    if (resolved.error != null) {
      return AcademicAssistantToolResult(message: resolved.error!);
    }
    final course = resolved.course;
    if (course == null || course.id == null) {
      return const AcademicAssistantToolResult(
        message: 'حدد المادة التي تريد إرفاق الملف بها.',
      );
    }
    final rawBytes = args['file_bytes'];
    final bytes = rawBytes is Uint8List
        ? rawBytes
        : rawBytes is List<int>
        ? Uint8List.fromList(rawBytes)
        : Uint8List(0);
    if (bytes.isEmpty) {
      return const AcademicAssistantToolResult(
        message: 'لم أستلم محتوى الملف. أعد إرفاقه.',
      );
    }
    if (bytes.length > 50 * 1024 * 1024) {
      return const AcademicAssistantToolResult(
        message: 'حجم الملف يتجاوز الحد المسموح (50 MB).',
      );
    }
    final fileName = _string(args, 'file_name');
    final fileType = _string(
      args,
      'file_type',
    ).toLowerCase().replaceFirst('.', '');
    if (fileName.isEmpty ||
        !{'pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt'}.contains(fileType)) {
      return const AcademicAssistantToolResult(
        message: 'اسم الملف أو صيغته غير مدعوم.',
      );
    }
    final db = await database.database;
    final possibleDuplicates = await db.query(
      'course_materials',
      columns: ['file_bytes'],
      where: 'course_id = ? AND title = ? AND file_type = ?',
      whereArgs: [course.id, fileName, fileType],
    );
    for (final row in possibleDuplicates) {
      final stored = row['file_bytes'];
      if (stored is List &&
          stored.length == bytes.length &&
          List<int>.generate(
            bytes.length,
            (index) => stored[index] as int,
          ).asMap().entries.every((entry) => entry.value == bytes[entry.key])) {
        return AcademicAssistantToolResult(
          message:
              'الملف «$fileName» محفوظ بالفعل في هذه المادة؛ لم أضف نسخة مكررة.',
          succeeded: true,
        );
      }
    }

    final material = CourseMaterialModel(
      courseId: course.id!,
      title: fileName,
      filePath: 'dbblob://${DateTime.now().microsecondsSinceEpoch}',
      fileType: fileType,
      fileBytes: bytes,
    );
    final materialId = await database.insertMaterial(material.toMap());
    return AcademicAssistantToolResult(
      message:
          'تم حفظ «$fileName» داخل مادة «${course.name}» وربطه بمعرّف المادة.',
      succeeded: true,
      changedData: true,
      affectedRecordId: materialId,
    );
  }

  Future<AcademicAssistantToolResult> _updateMaterial(
    Map<String, dynamic> args,
  ) async {
    final resolved = await _resolveCourse(args);
    if (resolved.error != null) {
      return AcademicAssistantToolResult(message: resolved.error!);
    }
    final course = resolved.course;
    if (course == null) {
      return const AcademicAssistantToolResult(
        message: 'حدد المادة التي تريد تعديلها.',
      );
    }
    final newName = _string(args, 'name');
    if (newName.isNotEmpty) {
      final courses = await courseUseCases.getCourses();
      final duplicate = courses.any(
        (item) =>
            item.id != course.id &&
            _normalize(item.name) == _normalize(newName),
      );
      if (duplicate) {
        return const AcademicAssistantToolResult(
          message: 'يوجد مادة أخرى بالاسم الجديد. لم أغيّر البيانات.',
        );
      }
    }
    final updated = course.copyWith(
      name: newName.isEmpty ? null : newName,
      instructor: _string(args, 'instructor').isEmpty
          ? null
          : _string(args, 'instructor'),
      code: _string(args, 'code').isEmpty ? null : _string(args, 'code'),
      credits: _integer(args['credits'])?.clamp(0, 30).toInt(),
    );
    await courseUseCases.updateCourse(updated);
    return AcademicAssistantToolResult(
      message: 'تم تحديث بيانات المادة «${updated.name}».',
      succeeded: true,
      changedData: true,
      affectedRecordId: updated.id,
    );
  }

  Future<AcademicAssistantToolResult> _deleteMaterial(
    Map<String, dynamic> args, {
    required bool confirmed,
  }) async {
    final resolved = await _resolveCourse(args);
    if (resolved.error != null) {
      return AcademicAssistantToolResult(message: resolved.error!);
    }
    final course = resolved.course;
    if (course == null || course.id == null) {
      return const AcademicAssistantToolResult(
        message: 'حدد المادة التي تريد حذفها.',
      );
    }
    if (!confirmed) {
      return AcademicAssistantToolResult(
        message: 'حذف المادة يتطلب تأكيدك.',
        requiresConfirmation: true,
        confirmationPrompt:
            'سيتم حذف المادة «${course.name}» مع مهامها ومحاضراتها واختباراتها وملفاتها المرتبطة. هل تؤكد الحذف؟',
      );
    }
    final result = await database.deleteCourseCascade(course.id!);
    if (result.deletedCourses == 0) {
      return const AcademicAssistantToolResult(
        message: 'لم يتم العثور على المادة، ولم يُحذف شيء.',
      );
    }
    await NotificationService.instance.cancelCourseReminder(course.id!);
    for (final taskId in result.taskIds) {
      await NotificationService.instance.cancelTaskReminder(taskId);
    }
    for (final scheduleId in result.scheduleIds) {
      await NotificationService.instance.cancelLectureReminder(scheduleId);
    }
    return AcademicAssistantToolResult(
      message:
          'تم حذف المادة «${course.name}» والبيانات التابعة لها بعد تأكيدك.',
      succeeded: true,
      changedData: true,
      affectedRecordId: course.id,
    );
  }

  Future<AcademicAssistantToolResult> _createTask(
    Map<String, dynamic> args,
  ) async {
    final title = _string(args, 'title');
    if (title.isEmpty) {
      return const AcademicAssistantToolResult(
        message: 'لم تحدد عنوان المهمة. ما اسم المهمة؟',
      );
    }
    final courseResult = await _resolveCourse(args);
    if (courseResult.error != null) {
      return AcademicAssistantToolResult(message: courseResult.error!);
    }
    final rawEndDateTime = args['end_date_time'];
    final endDateTime = _date(rawEndDateTime);
    if (rawEndDateTime != null && endDateTime == null) {
      return const AcademicAssistantToolResult(
        message:
            'صيغة وقت انتهاء المهمة غير صحيحة. استخدم تاريخاً ووقتاً واضحين.',
      );
    }
    final startDateTime = DateTime.now();
    if (endDateTime != null && !endDateTime.isAfter(startDateTime)) {
      return const AcademicAssistantToolResult(
        message:
            'وقت انتهاء المهمة يجب أن يكون في المستقبل بعد وقت البدء التلقائي.',
      );
    }
    final reminderOffset = (_integer(args['reminder_offset_minutes']) ?? 15)
        .clamp(0, 1440)
        .toInt();
    final reminderEnabled =
        endDateTime != null && args['reminder_enabled'] != false;
    final reminderDate = reminderEnabled
        ? endDateTime.subtract(Duration(minutes: reminderOffset))
        : null;
    if (reminderDate != null && !reminderDate.isAfter(startDateTime)) {
      return const AcademicAssistantToolResult(
        message:
            'موعد الانتهاء قريب جداً لإنشاء تنبيه قبل الموعد. اختر وقتاً أبعد أو عطّل التنبيه.',
      );
    }
    final existingTasks = await taskUseCases.getTasks();
    final duplicateTask = existingTasks
        .where(
          (existing) =>
              _normalize(existing.title) == _normalize(title) &&
              existing.courseId == courseResult.course?.id &&
              (existing.endDateTime == null
                  ? endDateTime == null
                  : endDateTime != null &&
                        existing.endDateTime!.isAtSameMomentAs(endDateTime)),
        )
        .firstOrNull;
    if (duplicateTask != null) {
      return AcademicAssistantToolResult(
        message:
            'المهمة «$title» موجودة مسبقاً بنفس المادة والموعد؛ لم أكررها.',
        succeeded: true,
      );
    }

    final task = TaskEntity(
      title: title,
      description: _string(args, 'description'),
      type: TaskTypeX.fromName(_string(args, 'type')),
      priority: TaskPriorityX.fromName(_string(args, 'priority')),
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      courseId: courseResult.course?.id,
      courseName: courseResult.course?.name,
      reminderEnabled: reminderEnabled,
      reminderDate: reminderDate,
      reminderOffsetMinutes: reminderOffset,
    );
    final id = await taskUseCases.addTask(task);
    if (reminderEnabled) {
      await NotificationService.instance.scheduleTaskReminder(
        task.copyWith(id: id),
      );
    }
    final materialText = courseResult.course == null
        ? ''
        : ' وربطتها بمادة ${courseResult.course!.name}';
    return AcademicAssistantToolResult(
      message: 'تم إنشاء المهمة «$title»$materialText وحفظها في النظام.',
      succeeded: true,
      changedData: true,
      affectedRecordId: id,
    );
  }

  Future<AcademicAssistantToolResult> _completeTask(
    Map<String, dynamic> args,
  ) async {
    final taskResult = await _resolveTask(args);
    if (taskResult.error != null) {
      return AcademicAssistantToolResult(message: taskResult.error!);
    }
    final task = taskResult.task!;
    if (task.isCompleted) {
      return AcademicAssistantToolResult(
        message: 'المهمة «${task.title}» مكتملة بالفعل.',
        succeeded: true,
      );
    }
    await taskUseCases.updateTask(
      task.copyWith(isCompleted: true, completedAt: DateTime.now()),
    );
    await NotificationService.instance.cancelTaskReminder(task.id!);
    return AcademicAssistantToolResult(
      message: 'تم تسجيل إنجاز المهمة «${task.title}» مع وقت الإنجاز الفعلي.',
      succeeded: true,
      changedData: true,
      affectedRecordId: task.id,
    );
  }

  Future<AcademicAssistantToolResult> _updateTask(
    Map<String, dynamic> args,
  ) async {
    final taskResult = await _resolveTask(args);
    if (taskResult.error != null) {
      return AcademicAssistantToolResult(message: taskResult.error!);
    }
    final task = taskResult.task!;
    final title = _string(args, 'title');
    final description = _string(args, 'description');
    final rawEndDateTime = args['end_date_time'];
    final newEndDateTime = _date(rawEndDateTime);
    if (rawEndDateTime != null && newEndDateTime == null) {
      return const AcademicAssistantToolResult(
        message: 'صيغة وقت الانتهاء الجديد غير صحيحة.',
      );
    }
    final effectiveEndDateTime = newEndDateTime ?? task.endDateTime;
    if (newEndDateTime != null &&
        !newEndDateTime.isAfter(task.startDateTime ?? DateTime.now())) {
      return const AcademicAssistantToolResult(
        message: 'وقت الانتهاء الجديد يجب أن يكون بعد وقت البدء المسجل.',
      );
    }
    final reminderEnabled = args['reminder_enabled'] is bool
        ? args['reminder_enabled'] as bool
        : task.reminderEnabled;
    final reminderOffset =
        (_integer(args['reminder_offset_minutes']) ??
                task.reminderOffsetMinutes)
            .clamp(0, 1440)
            .toInt();
    if (reminderEnabled && effectiveEndDateTime == null) {
      return const AcademicAssistantToolResult(
        message: 'حدد وقت انتهاء المهمة قبل تفعيل التنبيه.',
      );
    }
    final reminderDate = reminderEnabled && effectiveEndDateTime != null
        ? effectiveEndDateTime.subtract(Duration(minutes: reminderOffset))
        : null;
    if (reminderDate != null && !reminderDate.isAfter(DateTime.now())) {
      return const AcademicAssistantToolResult(
        message:
            'موعد التنبيه المحسوب أصبح في الماضي. اختر وقت انتهاء أبعد أو عطّل التنبيه.',
      );
    }
    final type = _string(args, 'type');
    final courseSpecified =
        args.containsKey('course_id') ||
        _string(args, 'course_name').isNotEmpty;
    final courseResult = courseSpecified ? await _resolveCourse(args) : null;
    if (courseResult?.error != null ||
        (courseSpecified && courseResult?.course == null)) {
      return AcademicAssistantToolResult(
        message: courseResult?.error ?? 'لم أتمكن من تحديد المادة المطلوبة.',
      );
    }
    final updated = task.copyWith(
      title: title.isEmpty ? null : title,
      description: description.isEmpty ? null : description,
      type: type.isEmpty ? null : TaskTypeX.fromName(type),
      priority: _string(args, 'priority').isEmpty
          ? null
          : TaskPriorityX.fromName(_string(args, 'priority')),
      courseId: courseResult?.course?.id,
      courseName: courseResult?.course?.name,
      endDateTime: newEndDateTime,
      reminderEnabled: reminderEnabled,
      reminderOffsetMinutes: reminderOffset,
      reminderDate: reminderDate,
      clearReminderDate: !reminderEnabled,
    );
    await taskUseCases.updateTask(updated);
    if (updated.reminderEnabled) {
      await NotificationService.instance.scheduleTaskReminder(updated);
    } else if (updated.id != null) {
      await NotificationService.instance.cancelTaskReminder(updated.id!);
    }
    return AcademicAssistantToolResult(
      message: 'تم تحديث المهمة «${updated.title}».',
      succeeded: true,
      changedData: true,
      affectedRecordId: updated.id,
    );
  }

  Future<AcademicAssistantToolResult> _deleteTask(
    Map<String, dynamic> args, {
    required bool confirmed,
  }) async {
    final taskResult = await _resolveTask(args);
    if (taskResult.error != null) {
      return AcademicAssistantToolResult(message: taskResult.error!);
    }
    final task = taskResult.task!;
    if (!confirmed) {
      return AcademicAssistantToolResult(
        message: 'تحتاج هذه العملية إلى تأكيدك.',
        requiresConfirmation: true,
        confirmationPrompt: 'هل تريد حذف المهمة «${task.title}» نهائياً؟',
      );
    }
    await taskUseCases.deleteTask(task.id!);
    await NotificationService.instance.cancelTaskReminder(task.id!);
    return AcademicAssistantToolResult(
      message: 'تم حذف المهمة «${task.title}».',
      succeeded: true,
      changedData: true,
      affectedRecordId: task.id,
    );
  }

  Future<AcademicAssistantToolResult> _addLecture(
    Map<String, dynamic> args,
  ) async {
    final courseResult = await _resolveCourse(args);
    if (courseResult.error != null) {
      return AcademicAssistantToolResult(message: courseResult.error!);
    }
    final course = courseResult.course;
    if (course == null) {
      return const AcademicAssistantToolResult(
        message: 'حدد اسم المادة التي ترتبط بها المحاضرة.',
      );
    }
    final day = _string(args, 'day');
    final startTime = _string(args, 'start_time');
    final endTime = _string(args, 'end_time');
    const days = {
      'السبت',
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
    };
    final timePattern = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');
    if (!days.contains(day) ||
        !timePattern.hasMatch(startTime) ||
        !timePattern.hasMatch(endTime) ||
        endTime.compareTo(startTime) <= 0) {
      return const AcademicAssistantToolResult(
        message: 'أحتاج اليوم ووقت البداية والنهاية بصيغة 24 ساعة صحيحة.',
      );
    }
    final existing = await database.getSchedules();
    final validation = ScheduleConflictValidator.validate(
      day: day,
      startTime: startTime,
      endTime: endTime,
      existingSchedules: existing,
    );
    if (!validation.isValid) {
      return const AcademicAssistantToolResult(
        message: 'يوجد تعارض زمني في هذا الموعد. لم أضف المحاضرة.',
      );
    }
    final location = _string(args, 'location');
    final reminderEnabled = args['reminder_enabled'] is bool
        ? args['reminder_enabled'] as bool
        : true;
    final reminderOffset = (_integer(args['reminder_offset_minutes']) ?? 15)
        .clamp(0, 1440)
        .toInt();
    final existingSchedules = await database.getSchedules();
    final duplicateSchedule = existingSchedules.any(
      (row) =>
          row['course_id'] == course.id &&
          row['day_of_week'] == day &&
          row['start_time'] == startTime &&
          row['end_time'] == endTime,
    );
    if (duplicateSchedule) {
      return AcademicAssistantToolResult(
        message: 'هذه المحاضرة موجودة بالفعل في الجدول؛ لم أكررها.',
        succeeded: true,
      );
    }
    final id = await database.insertSchedule({
      'course_id': course.id,
      'day_of_week': day,
      'start_time': startTime,
      'end_time': endTime,
      'location': location,
      'reminder_enabled': reminderEnabled ? 1 : 0,
      'reminder_offset_minutes': reminderOffset,
    });
    await NotificationService.instance.scheduleLectureReminder(
      id: id,
      title: course.name,
      weekdayName: day,
      startTime: startTime,
      reminderEnabled: reminderEnabled,
      location: location,
      reminderOffsetMinutes: reminderOffset,
    );
    return AcademicAssistantToolResult(
      message:
          'تمت إضافة محاضرة ${course.name} يوم $day من $startTime إلى $endTime وربطها بمعرّف المادة.',
      succeeded: true,
      changedData: true,
      affectedRecordId: id,
    );
  }

  Future<AcademicAssistantToolResult> _updateLecture(
    Map<String, dynamic> args,
  ) async {
    final scheduleId = _integer(args['schedule_id']);
    if (scheduleId == null) {
      return const AcademicAssistantToolResult(
        message: 'لم تحدد رقم المحاضرة المطلوب تعديلها.',
      );
    }
    final schedules = await database.getSchedules();
    final existing = schedules
        .where((item) => item['id'] == scheduleId)
        .firstOrNull;
    if (existing == null) {
      return const AcademicAssistantToolResult(
        message: 'لم أجد المحاضرة المطلوبة.',
      );
    }
    final courseResult = await _resolveCourse(args);
    if (courseResult.error != null) {
      return AcademicAssistantToolResult(message: courseResult.error!);
    }
    final rawCourseId = existing['course_id'];
    final oldCourseId = rawCourseId is int
        ? rawCourseId
        : int.tryParse(rawCourseId?.toString() ?? '');
    final courses = await courseUseCases.getCourses();
    final oldCourse = oldCourseId == null
        ? null
        : courses.where((course) => course.id == oldCourseId).firstOrNull;
    final course = courseResult.course ?? oldCourse;
    if (course == null || course.id == null) {
      return const AcademicAssistantToolResult(
        message: 'لم أتمكن من تحديد المادة المرتبطة بالمحاضرة.',
      );
    }
    final day = _string(args, 'day').isEmpty
        ? existing['day_of_week']?.toString() ?? ''
        : _string(args, 'day');
    final startTime = _string(args, 'start_time').isEmpty
        ? existing['start_time']?.toString() ?? ''
        : _string(args, 'start_time');
    final endTime = _string(args, 'end_time').isEmpty
        ? existing['end_time']?.toString() ?? ''
        : _string(args, 'end_time');
    final validation = ScheduleConflictValidator.validate(
      day: day,
      startTime: startTime,
      endTime: endTime,
      existingSchedules: schedules,
      excludingScheduleId: scheduleId,
    );
    if (!validation.isValid) {
      return const AcademicAssistantToolResult(
        message: 'التوقيت الجديد يتعارض مع محاضرة أخرى. لم أغيّر الجدول.',
      );
    }
    final location = _string(args, 'location').isEmpty
        ? existing['location']?.toString() ?? ''
        : _string(args, 'location');
    final reminderEnabled = args['reminder_enabled'] is bool
        ? args['reminder_enabled'] as bool
        : (existing['reminder_enabled'] == 1 ||
              existing['reminder_enabled'] == true);
    final offset =
        (_integer(args['reminder_offset_minutes']) ??
                _integer(existing['reminder_offset_minutes']) ??
                15)
            .clamp(0, 1440)
            .toInt();
    await database.updateSchedule({
      'id': scheduleId,
      'course_id': course.id,
      'day_of_week': day,
      'start_time': startTime,
      'end_time': endTime,
      'location': location,
      'reminder_enabled': reminderEnabled ? 1 : 0,
      'reminder_offset_minutes': offset,
    });
    await NotificationService.instance.scheduleLectureReminder(
      id: scheduleId,
      title: course.name,
      weekdayName: day,
      startTime: startTime,
      reminderEnabled: reminderEnabled,
      location: location,
      reminderOffsetMinutes: offset,
    );
    return AcademicAssistantToolResult(
      message: 'تم تحديث محاضرة ${course.name} في الجدول الأسبوعي.',
      succeeded: true,
      changedData: true,
      affectedRecordId: scheduleId,
    );
  }

  Future<AcademicAssistantToolResult> _deleteLecture(
    Map<String, dynamic> args, {
    required bool confirmed,
  }) async {
    final scheduleId = _integer(args['schedule_id']);
    if (scheduleId == null) {
      return const AcademicAssistantToolResult(
        message: 'لم تحدد رقم المحاضرة المطلوب حذفها.',
      );
    }
    final schedules = await database.getSchedules();
    final existing = schedules
        .where((item) => item['id'] == scheduleId)
        .firstOrNull;
    if (existing == null) {
      return const AcademicAssistantToolResult(
        message: 'المحاضرة غير موجودة في الجدول.',
      );
    }
    final rawCourseId = existing['course_id'];
    final courseId = rawCourseId is int
        ? rawCourseId
        : int.tryParse(rawCourseId?.toString() ?? '');
    final courses = await courseUseCases.getCourses();
    final courseName = courseId == null
        ? 'المادة'
        : courses.where((course) => course.id == courseId).firstOrNull?.name ??
              'المادة';
    if (!confirmed) {
      return AcademicAssistantToolResult(
        message: 'حذف المحاضرة يحتاج إلى تأكيدك.',
        requiresConfirmation: true,
        confirmationPrompt:
            'هل تريد حذف محاضرة $courseName من الجدول الأسبوعي؟',
      );
    }
    await database.deleteSchedule(scheduleId);
    await NotificationService.instance.cancelLectureReminder(scheduleId);
    return AcademicAssistantToolResult(
      message: 'تم حذف المحاضرة من الجدول وإلغاء تنبيهها.',
      succeeded: true,
      changedData: true,
      affectedRecordId: scheduleId,
    );
  }

  Future<AcademicAssistantToolResult> _createExam(
    Map<String, dynamic> args,
  ) async {
    final title = _string(args, 'title');
    final examDate = _date(args['exam_date']);
    if (title.isEmpty || examDate == null) {
      return const AcademicAssistantToolResult(
        message: 'لإنشاء الاختبار أحتاج عنوانه وتاريخه ووقته بصيغة ISO-8601.',
      );
    }
    final courseResult = await _resolveCourse(args);
    if (courseResult.error != null) {
      return AcademicAssistantToolResult(message: courseResult.error!);
    }
    final existingExams = await database.getExams();
    final duplicateExam = existingExams
        .where(
          (existing) =>
              _normalize(existing.title) == _normalize(title) &&
              existing.courseId == courseResult.course?.id &&
              existing.examDate.isAtSameMomentAs(examDate),
        )
        .firstOrNull;
    if (duplicateExam != null) {
      return AcademicAssistantToolResult(
        message:
            'الاختبار «$title» مسجل بالفعل في المادة والموعد نفسيهما؛ لم أكرر السجل.',
        succeeded: true,
      );
    }
    final exam = ExamModel(
      courseId: courseResult.course?.id,
      courseName: courseResult.course?.name,
      title: title,
      examDate: examDate,
      location: _string(args, 'location'),
      notes: _string(args, 'notes'),
    );
    final id = await database.insertExam(exam);
    return AcademicAssistantToolResult(
      message:
          'تم إنشاء الاختبار «$title» بتاريخ ${examDate.toLocal()}'
          '${courseResult.course == null ? '' : ' وربطه بمادة ${courseResult.course!.name}'} (رقم $id).',
      succeeded: true,
      changedData: true,
      affectedRecordId: id,
    );
  }

  Future<AcademicAssistantToolResult> _updateExam(
    Map<String, dynamic> args,
  ) async {
    final id = _integer(args['exam_id']);
    if (id == null) {
      return const AcademicAssistantToolResult(
        message: 'حدد رقم الاختبار الذي تريد تعديله.',
      );
    }
    final existing = await database.getExamById(id);
    if (existing == null) {
      return const AcademicAssistantToolResult(
        message: 'لم أجد الاختبار المطلوب.',
      );
    }
    final courseResult = await _resolveCourse(args);
    if (courseResult.error != null) {
      return AcademicAssistantToolResult(message: courseResult.error!);
    }
    final examDate = args.containsKey('exam_date')
        ? _date(args['exam_date'])
        : existing.examDate;
    if (examDate == null) {
      return const AcademicAssistantToolResult(
        message: 'تاريخ الاختبار الجديد غير صحيح.',
      );
    }
    final updated = ExamModel(
      id: id,
      courseId: courseResult.course?.id ?? existing.courseId,
      courseName: courseResult.course?.name ?? existing.courseName,
      title: _string(args, 'title').isEmpty
          ? existing.title
          : _string(args, 'title'),
      examDate: examDate,
      location: _string(args, 'location').isEmpty
          ? existing.location
          : _string(args, 'location'),
      notes: _string(args, 'notes').isEmpty
          ? existing.notes
          : _string(args, 'notes'),
      colorHex: existing.colorHex,
    );
    await database.updateExam(updated);
    return AcademicAssistantToolResult(
      message: 'تم تحديث الاختبار «${updated.title}».',
      succeeded: true,
      changedData: true,
      affectedRecordId: id,
    );
  }

  Future<AcademicAssistantToolResult> _deleteExam(
    Map<String, dynamic> args, {
    required bool confirmed,
  }) async {
    final id = _integer(args['exam_id']);
    if (id == null) {
      return const AcademicAssistantToolResult(
        message: 'حدد رقم الاختبار الذي تريد حذفه.',
      );
    }
    final exam = await database.getExamById(id);
    if (exam == null) {
      return const AcademicAssistantToolResult(message: 'الاختبار غير موجود.');
    }
    if (!confirmed) {
      return AcademicAssistantToolResult(
        message: 'حذف الاختبار يحتاج إلى تأكيدك.',
        requiresConfirmation: true,
        confirmationPrompt: 'هل تؤكد حذف الاختبار «${exam.title}»؟',
      );
    }
    await database.deleteExam(id);
    return AcademicAssistantToolResult(
      message: 'تم حذف الاختبار «${exam.title}» بعد تأكيدك.',
      succeeded: true,
      changedData: true,
      affectedRecordId: id,
    );
  }

  Future<AcademicAssistantToolResult> _generateReport(
    Map<String, dynamic> args,
  ) async {
    final periodName = _string(args, 'period');
    final period = switch (periodName) {
      'daily' => AcademicReportPeriod.daily,
      'weekly' => AcademicReportPeriod.weekly,
      'monthly' => AcademicReportPeriod.monthly,
      _ => AcademicReportPeriod.finalReport,
    };
    final courses = await database.getCourses();
    final tasks = await database.getTasks();
    final exams = await database.getExams();
    final schedule = await database.getSchedules();
    final report = const AcademicReportService().generatePeriodReport(
      period: period,
      courses: courses,
      tasks: tasks,
      exams: exams,
      schedule: schedule,
    );
    await NotificationService.instance.showReportReadyNotification(
      id: 41000 + period.index,
      title: 'تم تجهيز التقرير ${period.arabicLabel}',
      body: 'التقرير جاهز داخل AcademicOS.',
    );
    return AcademicAssistantToolResult(message: report, succeeded: true);
  }

  Future<_ResolvedCourse> _resolveCourse(Map<String, dynamic> args) async {
    final rawId = _integer(args['course_id']);
    final name = _string(args, 'course_name');
    final courses = await courseUseCases.getCourses();
    if (rawId != null) {
      final match = courses.where((course) => course.id == rawId).firstOrNull;
      return match == null
          ? const _ResolvedCourse(error: 'لم أجد المادة المطلوبة بهذا المعرّف.')
          : _ResolvedCourse(course: match);
    }
    if (name.isEmpty) return const _ResolvedCourse();
    final matches = courses
        .where((course) => _normalize(course.name) == _normalize(name))
        .toList();
    if (matches.length == 1) return _ResolvedCourse(course: matches.single);
    if (matches.length > 1)
      return const _ResolvedCourse(
        error: 'وجدت أكثر من مادة بالاسم نفسه. حدد المادة المطلوبة.',
      );
    return _ResolvedCourse(
      error: 'المادة «$name» غير موجودة. أضفها إلى قائمة المواد أولاً.',
    );
  }

  Future<_ResolvedTask> _resolveTask(Map<String, dynamic> args) async {
    final rawId = _integer(args['task_id']);
    final title = _string(args, 'task_title');
    final tasks = await taskUseCases.getTasks();
    if (rawId != null) {
      final match = tasks.where((task) => task.id == rawId).firstOrNull;
      return match == null
          ? const _ResolvedTask(error: 'لم أجد المهمة المطلوبة بهذا المعرّف.')
          : _ResolvedTask(task: match);
    }
    if (title.isEmpty)
      return const _ResolvedTask(error: 'حدد عنوان المهمة أو رقمها.');
    final matches = tasks
        .where((task) => _normalize(task.title) == _normalize(title))
        .toList();
    if (matches.length == 1) return _ResolvedTask(task: matches.single);
    if (matches.length > 1)
      return const _ResolvedTask(
        error: 'وجدت أكثر من مهمة بهذا الاسم. حدد المهمة المطلوبة.',
      );
    return _ResolvedTask(error: 'لم أجد المهمة «$title».');
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _string(Map<String, dynamic> args, String key) =>
      args[key]?.toString().trim() ?? '';

  static int? _integer(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');

  static DateTime? _date(dynamic value) =>
      value is DateTime ? value : DateTime.tryParse(value?.toString() ?? '');
}

class _ResolvedCourse {
  final CourseEntity? course;
  final String? error;
  const _ResolvedCourse({this.course, this.error});
}

class _ResolvedTask {
  final TaskEntity? task;
  final String? error;
  const _ResolvedTask({this.task, this.error});
}
