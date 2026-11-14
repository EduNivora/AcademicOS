import '../models/course_material_model.dart';
import '../models/course_model.dart';
import '../models/exam_model.dart';
import '../models/task_model.dart';

class ValidatedBackup {
  const ValidatedBackup({
    required this.courses,
    required this.tasks,
    required this.exams,
    required this.schedule,
    required this.materials,
  });

  final List<CourseModel> courses;
  final List<TaskModel> tasks;
  final List<ExamModel> exams;
  final List<Map<String, dynamic>> schedule;
  final List<CourseMaterialModel>? materials;
}

class BackupPayloadValidator {
  const BackupPayloadValidator();

  static const _schemas = {
    'academic_os_backup_v1',
    'academic_os_backup_v2',
  };
  static const _days = {
    'السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة',
  };

  ValidatedBackup validate(Map<String, dynamic> payload) {
    final schema = payload['schema'];
    if (schema != null && (schema is! String || !_schemas.contains(schema))) {
      throw const FormatException('Unsupported backup schema version.');
    }

    List<Map<String, dynamic>> rows(String key, {required bool isRequired}) {
      final value = payload[key];
      if (value == null && !isRequired) return <Map<String, dynamic>>[];
      if (value is! List) {
        throw FormatException('Backup section "$key" must be a list.');
      }
      return value.map((item) {
        if (item is! Map) {
          throw FormatException('Backup section "$key" contains a non-object row.');
        }
        try {
          return Map<String, dynamic>.from(item);
        } catch (_) {
          throw FormatException('Backup section "$key" contains invalid keys.');
        }
      }).toList(growable: false);
    }

    final courseRows = rows('courses', isRequired: true);
    final taskRows = rows('tasks', isRequired: true);
    final examRows = rows('exams', isRequired: true);
    final scheduleRows = rows('schedule', isRequired: true);
    final materialValue = payload['materials'];
    if (schema == 'academic_os_backup_v2' && materialValue is! List) {
      throw const FormatException('Backup v2 must contain materials as a list.');
    }
    if (materialValue != null && materialValue is! List) {
      throw const FormatException('Backup materials must be a list.');
    }
    final materialRows = materialValue == null
        ? null
        : rows('materials', isRequired: true);

    for (final row in courseRows) {
      _validateCourse(row);
    }
    for (final row in taskRows) {
      _validateTask(row);
    }
    for (final row in examRows) {
      _validateExam(row);
    }

    final courses = courseRows.map(CourseModel.fromMap).toList(growable: false);
    final tasks = taskRows.map(TaskModel.fromMap).toList(growable: false);
    final exams = examRows.map(ExamModel.fromMap).toList(growable: false);

    _validateIds(courseRows, 'courses');
    _validateIds(taskRows, 'tasks');
    _validateIds(examRows, 'exams');
    _validateIds(scheduleRows, 'schedule');
    if (materialRows != null) _validateIds(materialRows, 'materials');

    final courseIds = courses.map((item) => item.id!).toSet();
    for (final row in [...taskRows, ...examRows]) {
      _validateOptionalForeignKey(row['course_id'], courseIds, 'course_id');
    }

    final schedule = scheduleRows.map(_validateSchedule).toList(growable: false);
    for (final row in schedule) {
      _validateOptionalForeignKey(row['course_id'], courseIds, 'schedule.course_id');
    }
    final materials = materialRows
        ?.map(_validateMaterial)
        .toList(growable: false);

    if (materials != null) {
      for (final material in materials) {
        if (!courseIds.contains(material.courseId)) {
          throw const FormatException('A material references a missing course.');
        }
      }
    }

    return ValidatedBackup(
      courses: courses,
      tasks: tasks,
      exams: exams,
      schedule: schedule,
      materials: materials,
    );
  }

  void _validateCourse(Map<String, dynamic> row) {
    for (final key in ['name', 'instructor', 'code']) {
      if (row[key] is! String) {
        throw FormatException('Course "$key" must be a string.');
      }
    }
    if ((row['name'] as String).trim().isEmpty ||
        (row['code'] as String).trim().isEmpty) {
      throw const FormatException('Course name and code are required.');
    }
    _validateOptionalDate(row['lecture_date'], 'course.lecture_date');
    _validateOptionalFlag(
      row,
      'lecture_reminder_enabled',
      'course.lecture_reminder_enabled',
    );
    _validateOptionalInteger(
      row,
      'credits',
      'course.credits',
      min: 0,
      max: 1000,
    );
    _validateOptionalInteger(
      row,
      'credit_hours',
      'course.credit_hours',
      min: 1,
      max: 1000,
    );
    _validateOptionalInteger(
      row,
      'lecture_reminder_offset_minutes',
      'course.lecture_reminder_offset_minutes',
      min: 0,
      max: 10080,
    );
    for (final key in ['semester', 'notes', 'color_hex']) {
      _validateOptionalString(row[key], 'course.$key');
    }
    for (final key in ['mid_grade', 'practical_grade', 'final_grade']) {
      final value = row[key];
      if (value != null &&
          (value is! num || !value.isFinite || value < 0)) {
        throw FormatException('Course "$key" must be a finite non-negative number.');
      }
    }
  }

  void _validateTask(Map<String, dynamic> row) {
    if (row['title'] is! String ||
        (row['title'] as String).trim().isEmpty ||
        row['description'] is! String) {
      throw const FormatException('Task title and description are required.');
    }
    if (row.containsKey('type')) {
      _validateEnum(row['type'], const {
        'homework', 'project', 'exam', 'review', 'attendance',
        'academicActivity', 'other',
      }, 'task.type');
    }
    if (row.containsKey('priority')) {
      _validateEnum(row['priority'], const {
        'low', 'medium', 'high', 'urgent',
      }, 'task.priority');
    }
    if (row.containsKey('recurrence')) {
      _validateEnum(row['recurrence'], const {
        'once', 'daily', 'weekly', 'monthly',
      }, 'task.recurrence');
    }
    _validateOptionalFlag(row, 'is_completed', 'task.is_completed');
    _validateOptionalFlag(row, 'reminder_enabled', 'task.reminder_enabled');
    for (final key in ['due_date', 'start_date_time', 'end_date_time', 'reminder_date']) {
      _validateOptionalDate(row[key], 'task.$key');
    }
    final start = row['start_date_time'];
    final end = row['end_date_time'];
    if (start != null && end != null &&
        DateTime.parse(end as String).isBefore(DateTime.parse(start as String))) {
      throw const FormatException('Task end_date_time precedes start_date_time.');
    }
    _validateOptionalInteger(
      row,
      'reminder_offset_minutes',
      'task.reminder_offset_minutes',
      min: 0,
      max: 10080,
    );
    _validateOptionalInteger(
      row,
      'course_id',
      'task.course_id',
      min: 1,
    );
    _validateOptionalString(row['course_name'], 'task.course_name');
    _validateOptionalString(row['notes'], 'task.notes');
  }

  void _validateExam(Map<String, dynamic> row) {
    if (row['title'] is! String || (row['title'] as String).trim().isEmpty) {
      throw const FormatException('Exam title is required.');
    }
    _validateOptionalDate(row['exam_date'], 'exam.exam_date', required: true);
    _validateOptionalInteger(row, 'course_id', 'exam.course_id', min: 1);
    for (final key in ['location', 'notes', 'course_name', 'color_hex']) {
      _validateOptionalString(row[key], 'exam.$key');
    }
  }

  void _validateOptionalString(Object? value, String field) {
    if (value != null && value is! String) {
      throw FormatException('"$field" must be a string or null.');
    }
  }

  void _validateOptionalDate(
    Object? value,
    String field, {
    bool required = false,
  }) {
    if (value == null) {
      if (required) throw FormatException('"$field" is required.');
      return;
    }
    if (value is! String || DateTime.tryParse(value) == null) {
      throw FormatException('"$field" must be a valid ISO date string.');
    }
  }

  void _validateOptionalInteger(
    Map<String, dynamic> row,
    String key,
    String field, {
    int? min,
    int? max,
  }) {
    if (!row.containsKey(key) || row[key] == null) return;
    final value = row[key];
    if (value is! int ||
        (min != null && value < min) ||
        (max != null && value > max)) {
      throw FormatException('"$field" is outside its valid integer range.');
    }
  }

  void _validateOptionalFlag(
    Map<String, dynamic> row,
    String key,
    String field,
  ) {
    if (!row.containsKey(key)) return;
    _validateFlag(row[key], field);
  }

  void _validateIds(List<Map<String, dynamic>> rows, String section) {
    final seen = <int>{};
    for (final row in rows) {
      final id = row['id'];
      if (id is! int || id <= 0 || !seen.add(id)) {
        throw FormatException(
          'Section "$section" contains a missing, invalid, or duplicate id.',
        );
      }
    }
  }

  void _validateOptionalForeignKey(
    Object? value,
    Set<int> validIds,
    String field,
  ) {
    if (value == null) return;
    if (value is! int || value <= 0 || !validIds.contains(value)) {
      throw FormatException('Invalid or orphaned "$field" reference.');
    }
  }

  void _validateEnum(Object? value, Set<String> allowed, String field) {
    if (value is! String || !allowed.contains(value)) {
      throw FormatException('Invalid or missing enum value for "$field".');
    }
  }

  void _validateFlag(Object? value, String field) {
    if (value != 0 && value != 1 && value != false && value != true) {
      throw FormatException('Invalid boolean flag "$field".');
    }
  }

  Map<String, dynamic> _validateSchedule(Map<String, dynamic> row) {
    final day = row['day_of_week'];
    final start = row['start_time'];
    final end = row['end_time'];
    if (day is! String || !_days.contains(day)) {
      throw const FormatException('Schedule row has an invalid day_of_week.');
    }
    final startMinutes = _parseTime(start, 'start_time');
    final endMinutes = _parseTime(end, 'end_time');
    if (endMinutes <= startMinutes) {
      throw const FormatException('Schedule end_time must be after start_time.');
    }
    final location = row['location'];
    if (location != null && location is! String) {
      throw const FormatException('Schedule location must be a string.');
    }
    final reminder = row['reminder_enabled'];
    if (reminder != null && reminder != 0 && reminder != 1) {
      throw const FormatException('Schedule reminder_enabled must be 0 or 1.');
    }
    final offset = row['reminder_offset_minutes'];
    if (offset != null && (offset is! int || offset < 0 || offset > 10080)) {
      throw const FormatException('Schedule reminder offset is out of range.');
    }
    if (row['course_id'] != null && row['course_id'] is! int) {
      throw const FormatException('Schedule course_id must be an integer or null.');
    }
    return row;
  }

  int _parseTime(Object? value, String field) {
    if (value is! String || !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
      throw FormatException('Schedule "$field" must use HH:mm format.');
    }
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  CourseMaterialModel _validateMaterial(Map<String, dynamic> row) {
    final courseId = row['course_id'];
    final title = row['title'];
    final path = row['file_path'];
    final type = row['file_type'];
    final createdAt = row['created_at'];
    if (courseId is! int || courseId <= 0 ||
        title is! String || title.trim().isEmpty ||
        path is! String || path.trim().isEmpty ||
        type is! String || type.trim().isEmpty) {
      throw const FormatException('Material row has invalid required fields.');
    }
    if (createdAt != null &&
        (createdAt is! String || DateTime.tryParse(createdAt) == null)) {
      throw const FormatException('Material created_at is invalid.');
    }
    return CourseMaterialModel.fromMap(row);
  }
}
