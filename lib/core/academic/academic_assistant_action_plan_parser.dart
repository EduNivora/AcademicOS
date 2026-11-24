import 'dart:convert';

/// Parses Gemini output as untrusted data. Unknown or malformed actions reject
/// the complete plan; they are never silently discarded or partially executed.
class AcademicAssistantActionPlanParser {
  const AcademicAssistantActionPlanParser();

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

  Map<String, dynamic>? parse(String response) {
    try {
      final cleaned = response
          .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
      final decoded = jsonDecode(cleaned);
      if (decoded is! Map<String, dynamic> || decoded['actions'] is! List) {
        return null;
      }
      final rawActions = decoded['actions'] as List;
      if (rawActions.length > 10) return null;
      final actions = <Map<String, dynamic>>[];
      for (final raw in rawActions) {
        if (raw is! Map) return null;
        final action = Map<String, dynamic>.from(raw);
        if (action['name'] is! String ||
            !allowedActions.contains(action['name']) ||
            action['arguments'] is! Map) {
          return null;
        }
        actions.add(action);
      }
      return {'reply': decoded['reply']?.toString() ?? '', 'actions': actions};
    } catch (_) {
      return null;
    }
  }
}
