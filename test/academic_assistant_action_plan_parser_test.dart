import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/academic/academic_assistant_action_plan_parser.dart';

void main() {
  const parser = AcademicAssistantActionPlanParser();

  test('accepts a known action with bounded plan length', () {
    final result = parser.parse(
      jsonEncode({
        'reply': 'سأضيف المهمة.',
        'actions': [
          {
            'name': 'create_task',
            'arguments': {'title': 'مراجعة الفصل'},
          },
        ],
      }),
    );

    expect(result, isNotNull);
    expect(result!['reply'], 'سأضيف المهمة.');
    expect(result['actions'], hasLength(1));
  });

  test('accepts an attachment action supported by the executor', () {
    final result = parser.parse(
      jsonEncode({
        'actions': [
          {
            'name': 'add_material_file',
            'arguments': {
              'course_name': 'أمن الشبكات',
              'file_name': 'lecture.pdf',
              'file_type': 'pdf',
              'file_bytes': [37, 80, 68, 70],
            },
          },
        ],
      }),
    );

    expect(result, isNotNull);
    expect(result!['actions'], hasLength(1));
    expect(result['actions'].single['name'], 'add_material_file');
  });

  test('rejects malformed JSON without producing an action plan', () {
    expect(parser.parse('{"actions": ['), isNull);
  });

  test('rejects the entire plan when it contains an unknown action', () {
    final result = parser.parse(
      jsonEncode({
        'actions': [
          {
            'name': 'create_task',
            'arguments': {'title': 'مراجعة'},
          },
          {
            'name': 'run_sql',
            'arguments': {'query': 'DROP TABLE tasks'},
          },
        ],
      }),
    );

    expect(result, isNull);
  });

  test('rejects malformed action entries and non-map arguments', () {
    expect(
      parser.parse(
        jsonEncode({
          'actions': ['create_task'],
        }),
      ),
      isNull,
    );
    expect(
      parser.parse(
        jsonEncode({
          'actions': [
            {'name': 'create_task', 'arguments': 'title=مراجعة'},
          ],
        }),
      ),
      isNull,
    );
  });

  test('rejects plans containing more than ten actions', () {
    final actions = List.generate(
      11,
      (_) => {
        'name': 'generate_report',
        'arguments': {'period': 'weekly'},
      },
    );
    expect(parser.parse(jsonEncode({'actions': actions})), isNull);
  });

  test('accepts an empty action list as a clarification-only response', () {
    final result = parser.parse(
      jsonEncode({'reply': 'ما تاريخ المهمة؟', 'actions': []}),
    );
    expect(result, isNotNull);
    expect(result!['actions'], isEmpty);
  });
}
