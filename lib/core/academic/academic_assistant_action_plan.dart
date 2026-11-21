import 'dart:convert';

import 'academic_assistant_action_executor.dart';

class AcademicAssistantActionPlan {
  final String reply;
  final List<AcademicAssistantToolCall> actions;

  const AcademicAssistantActionPlan({
    required this.reply,
    required this.actions,
  });
}

class AcademicAssistantActionPlanParser {
  const AcademicAssistantActionPlanParser();

  static const int maxActions = 10;

  static const Set<String> allowedActions = {
    'update_profile',
    'create_material',
    'update_material',
    'delete_material',
    'create_task',
    'complete_task',
    'update_task',
    'delete_task',
    'add_lecture',
    'update_lecture',
    'delete_lecture',
    'create_exam',
    'update_exam',
    'delete_exam',
    'generate_report',
  };

  AcademicAssistantActionPlan? parse(String response) {
    try {
      final cleaned = response
          .replaceFirst(RegExp(r'^\x60\x60\x60(?:json)?\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\s*\x60\x60\x60$'), '')
          .trim();
      final decoded = jsonDecode(cleaned);
      if (decoded is! Map || decoded['actions'] is! List) return null;

      final rawActions = decoded['actions'] as List;
      if (rawActions.length > maxActions) return null;

      final actions = <AcademicAssistantToolCall>[];
      for (final raw in rawActions) {
        if (raw is! Map) return null;
        final name = raw['name'];
        final rawArguments = raw['arguments'];
        if (name is! String || !allowedActions.contains(name) || rawArguments is! Map) {
          return null;
        }
        final arguments = Map<String, dynamic>.from(rawArguments);
        if (!_hasRequiredArguments(name, arguments)) return null;
        actions.add(AcademicAssistantToolCall(name: name, arguments: arguments));
      }

      final reply = decoded['reply'];
      return AcademicAssistantActionPlan(
        reply: reply is String ? reply : '',
        actions: actions,
      );
    } catch (_) {
      return null;
    }
  }

  bool _hasRequiredArguments(String name, Map<String, dynamic> args) {
    bool hasValue(String key) {
      final value = args[key];
      if (value == null) return false;
      if (value is String) return value.trim().isNotEmpty;
      return true;
    }

    bool hasPositiveId(String key) {
      final value = args[key];
      final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
      return parsed != null && parsed > 0;
    }

    bool hasCourse() => hasPositiveId('course_id') || hasValue('course_name');
    bool hasTask() => hasPositiveId('task_id') || hasValue('task_title');
    bool hasSchedule() => hasPositiveId('schedule_id');
    bool hasExam() => hasPositiveId('exam_id');

    switch (name) {
      case 'update_profile':
        return [
          'full_name',
          'university',
          'major',
          'department',
          'semester',
          'academic_level',
        ].any(hasValue);
      case 'create_material':
        return hasValue('name');
      case 'update_material':
        return hasCourse() &&
            ['name', 'instructor', 'code', 'credits'].any(hasValue);
      case 'delete_material':
        return hasCourse();
      case 'create_task':
        return hasValue('title');
      case 'complete_task':
      case 'delete_task':
        return hasTask();
      case 'update_task':
        return hasTask() &&
            ['title', 'description', 'priority', 'end_date_time'].any(hasValue);
      case 'add_lecture':
        return hasCourse() &&
            hasValue('day') &&
            hasValue('start_time') &&
            hasValue('end_time');
      case 'update_lecture':
      case 'delete_lecture':
        return hasSchedule();
      case 'create_exam':
        return hasValue('title') && hasValue('exam_date');
      case 'update_exam':
      case 'delete_exam':
        return hasExam();
      case 'generate_report':
        return const {'daily', 'weekly', 'monthly', 'final'}
            .contains(args['period']);
      default:
        return false;
    }
  }
}
