import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/academic/academic_assistant_action_plan.dart';

void main() {
  const parser = AcademicAssistantActionPlanParser();

  String encode(List<Object?> actions, {String reply = 'سأنفذ المطلوب.'}) =>
      jsonEncode({'reply': reply, 'actions': actions});

  Map<String, Object?> action(String name, Map<String, Object?> arguments) =>
      {'name': name, 'arguments': arguments};

  group('AcademicAssistantActionPlanParser', () {
    test('parses a valid multi-step plan without changing its order', () {
      final plan = parser.parse(encode([
        action('create_task', {'title': 'مراجعة الشبكات'}),
        action('create_exam', {
          'title': 'اختبار الشبكات',
          'exam_date': '2027-02-15T09:00:00',
        }),
      ]));

      expect(plan, isNotNull);
      expect(plan!.actions.map((item) => item.name), [
        'create_task',
        'create_exam',
      ]);
      expect(plan.reply, 'سأنفذ المطلوب.');
    });

    test('rejects plans larger than the execution limit', () {
      final actions = List.generate(
        AcademicAssistantActionPlanParser.maxActions + 1,
        (_) => action('create_task', {'title': 'مهمة'}),
      );
      expect(parser.parse(encode(actions)), isNull);
    });

    test('rejects an unsupported action instead of silently dropping it', () {
      expect(
        parser.parse(encode([
          action('publish_university_announcement', {'title': 'تعميم'}),
        ])),
        isNull,
      );
    });

    test('rejects malformed action objects and argument payloads', () {
      expect(parser.parse(encode([null])), isNull);
      expect(
        parser.parse(encode([
          {'name': 'create_task', 'arguments': 'not-an-object'},
        ])),
        isNull,
      );
    });

    test('rejects actions with missing required arguments before execution', () {
      expect(
        parser.parse(encode([
          action('create_exam', {'title': 'اختبار بلا تاريخ'}),
        ])),
        isNull,
      );
      expect(
        parser.parse(encode([
          action('add_lecture', {
            'course_name': 'الشبكات',
            'day': 'الأحد',
            'start_time': '08:00',
          }),
        ])),
        isNull,
      );
    });

    test('accepts supported material attachment actions with bounded bytes', () {
      final plan = parser.parse(encode([
        action('add_material_file', {
          'course_name': 'الشبكات',
          'file_name': 'lecture.pdf',
          'file_type': 'pdf',
          'file_bytes': [37, 80, 68, 70],
        }),
      ]));
      expect(plan, isNotNull);
      expect(plan!.actions.single.name, 'add_material_file');
    });

    test('rejects material attachments with invalid bytes or file type', () {
      expect(
        parser.parse(encode([
          action('add_material_file', {
            'course_name': 'الشبكات',
            'file_name': 'lecture.exe',
            'file_type': 'exe',
            'file_bytes': [1, 2, 3],
          }),
        ])),
        isNull,
      );
      expect(
        parser.parse(encode([
          action('add_material_file', {
            'course_name': 'الشبكات',
            'file_name': 'lecture.pdf',
            'file_type': 'pdf',
            'file_bytes': [256],
          }),
        ])),
        isNull,
      );
    });

    test('accepts profile updates with at least one supplied field', () {
      final plan = parser.parse(encode([
        action('update_profile', {'university': 'جامعة صنعاء'}),
      ]));
      expect(plan, isNotNull);
      expect(plan!.actions, hasLength(1));
    });


    test('accepts dot-prefixed material file extensions', () {
      final plan = parser.parse(encode([
        action('add_material_file', {
          'course_name': 'الشبكات',
          'file_name': 'lecture.pdf',
          'file_type': '.pdf',
          'file_bytes': [37, 80, 68, 70],
        }),
      ]));
      expect(plan, isNotNull);
    });

    test('accepts task reminder-only updates', () {
      final plan = parser.parse(encode([
        action('update_task', {
          'task_id': 12,
          'reminder_enabled': false,
        }),
      ]));
      expect(plan, isNotNull);
    });

    test('rejects exam and lecture updates without any changed fields', () {
      expect(
        parser.parse(encode([
          action('update_exam', {'exam_id': 3}),
        ])),
        isNull,
      );
      expect(
        parser.parse(encode([
          action('update_lecture', {'schedule_id': 8}),
        ])),
        isNull,
      );
    });

    test('rejects malformed JSON', () {
      expect(parser.parse('{not-json'), isNull);
    });
  });
}
