import '../../domain/entities/task_entity.dart';

class TaskModel extends TaskEntity {
  const TaskModel({
    super.id,
    required super.title,
    required super.description,
    super.type,
    super.priority,
    super.recurrence,
    super.dueDate,
    super.startDateTime,
    super.endDateTime,
    super.isCompleted,
    super.completedAt,
    super.courseId,
    super.courseName,
    super.notes,
    super.reminderEnabled,
    super.reminderDate,
    super.reminderOffsetMinutes,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    if (map['title'] is! String || (map['title'] as String).trim().isEmpty) {
      throw const FormatException('Invalid task backup: title is required.');
    }
    if (map['description'] is! String) {
      throw const FormatException('Invalid task backup: description must be a string.');
    }

    DateTime? parseOptionalDate(String key) {
      final value = map[key];
      if (value == null) return null;
      final parsed = DateTime.tryParse(value.toString());
      if (parsed == null) {
        throw FormatException('Invalid task backup: "$key" is not a valid date.');
      }
      return parsed;
    }

    final startDateTime = parseOptionalDate('start_date_time');
    final endDateTime = parseOptionalDate('end_date_time');
    if (startDateTime != null &&
        endDateTime != null &&
        endDateTime.isBefore(startDateTime)) {
      throw const FormatException('Invalid task backup: end_date_time precedes start_date_time.');
    }

    final idValue = map['id'];
    return TaskModel(
      id: idValue is int ? idValue : int.tryParse(idValue.toString()),
      title: map['title'] as String,
      description: map['description'] as String,
      type: TaskTypeX.fromName(map['type']?.toString()),
      priority: TaskPriorityX.fromName(map['priority']?.toString()),
      recurrence: TaskRecurrenceX.fromName(map['recurrence']?.toString()),
      dueDate: parseOptionalDate('due_date'),
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      isCompleted: map['is_completed'] == 1 || map['is_completed'] == true,
      completedAt: parseOptionalDate('completed_at'),
      courseId: map['course_id'] is int
          ? map['course_id'] as int
          : int.tryParse(map['course_id']?.toString() ?? ''),
      courseName: map['course_name']?.toString(),
      notes: map['notes']?.toString() ?? '',
      reminderEnabled:
          map['reminder_enabled'] == 1 || map['reminder_enabled'] == true,
      reminderDate: parseOptionalDate('reminder_date'),
      reminderOffsetMinutes: map['reminder_offset_minutes'] is int
          ? map['reminder_offset_minutes'] as int
          : int.tryParse(map['reminder_offset_minutes']?.toString() ?? '') ??
                30,
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'title': title,
      'description': description,
      'type': type.name,
      'priority': priority.name,
      'recurrence': recurrence.name,
      'due_date': dueDate?.toIso8601String(),
      'start_date_time': startDateTime?.toIso8601String(),
      'end_date_time': endDateTime?.toIso8601String(),
      'is_completed': isCompleted ? 1 : 0,
      'completed_at': completedAt?.toIso8601String(),
      'course_id': courseId,
      'course_name': courseName,
      'notes': notes,
      'reminder_enabled': reminderEnabled ? 1 : 0,
      'reminder_date': reminderDate?.toIso8601String(),
      'reminder_offset_minutes': reminderOffsetMinutes,
    };
    if (id != null) {
      data['id'] = id;
    }
    return data;
  }
}
