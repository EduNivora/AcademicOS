import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/data/services/backup_payload_validator.dart';

Map<String, dynamic> _validPayload() => {
  'schema': 'academic_os_backup_v2',
  'courses': [
    {'id': 1, 'name': 'Math', 'instructor': 'Dr A', 'code': 'M101'},
  ],
  'tasks': [
    {'id': 1, 'title': 'Homework', 'description': '', 'course_id': 1},
  ],
  'exams': [
    {'id': 1, 'title': 'Midterm', 'exam_date': '2026-12-01', 'course_id': 1},
  ],
  'schedule': [
    {'id': 1, 'course_id': 1, 'day_of_week': 'الأحد',
     'start_time': '08:00', 'end_time': '09:00',
     'location': 'Room 1', 'reminder_enabled': 1,
     'reminder_offset_minutes': 15},
  ],
  'materials': [
    {'id': 1, 'course_id': 1, 'title': 'Notes',
     'file_path': '/files/notes.pdf', 'file_type': 'pdf',
     'created_at': '2026-11-14T10:00:00.000'},
  ],
};

void main() {
  const validator = BackupPayloadValidator();

  test('accepts a valid v2 backup and validates all sections', () {
    final result = validator.validate(_validPayload());
    expect(result.courses, hasLength(1));
    expect(result.tasks, hasLength(1));
    expect(result.exams, hasLength(1));
    expect(result.schedule, hasLength(1));
    expect(result.materials, hasLength(1));
  });

  test('rejects duplicate primary keys in every section', () {
    final payload = _validPayload();
    payload['schedule'] = [
      ...(payload['schedule'] as List),
      (payload['schedule'] as List).first,
    ];
    expect(() => validator.validate(payload), throwsFormatException);
  });

  test('rejects malformed schedule fields and invalid time ranges', () {
    final payload = _validPayload();
    payload['schedule'] = [
      {'id': 1, 'day_of_week': 'Funday', 'start_time': '08:00',
       'end_time': '09:00'},
    ];
    expect(() => validator.validate(payload), throwsFormatException);

    payload['schedule'] = [
      {'id': 1, 'day_of_week': 'الأحد', 'start_time': '10:00',
       'end_time': '09:00'},
    ];
    expect(() => validator.validate(payload), throwsFormatException);
  });

  test('rejects malformed materials and orphaned course references', () {
    final payload = _validPayload();
    payload['materials'] = [
      {'id': 1, 'course_id': 1, 'title': '', 'file_path': '/a',
       'file_type': 'pdf'},
    ];
    expect(() => validator.validate(payload), throwsFormatException);

    payload['materials'] = [
      {'id': 1, 'course_id': 99, 'title': 'Notes', 'file_path': '/a',
       'file_type': 'pdf'},
    ];
    expect(() => validator.validate(payload), throwsFormatException);
  });

  test('rejects orphaned task, exam, and schedule course references', () {
    final payload = _validPayload();
    (payload['tasks'] as List).first['course_id'] = 99;
    expect(() => validator.validate(payload), throwsFormatException);
    (payload['tasks'] as List).first['course_id'] = 1;
    (payload['exams'] as List).first['course_id'] = 99;
    expect(() => validator.validate(payload), throwsFormatException);
    (payload['exams'] as List).first['course_id'] = 1;
    (payload['schedule'] as List).first['course_id'] = 99;
    expect(() => validator.validate(payload), throwsFormatException);
  });

  test('rejects duplicate course ids and non-object rows', () {
    final payload = _validPayload();
    payload['courses'] = [
      ...(payload['courses'] as List),
      (payload['courses'] as List).first,
    ];
    expect(() => validator.validate(payload), throwsFormatException);

    payload['courses'] = ['not-a-row'];
    expect(() => validator.validate(payload), throwsFormatException);
  });

  test('rejects invalid optional numeric fields and malformed dates', () {
    final payload = _validPayload();
    (payload['courses'] as List).first['credits'] = 'many';
    expect(() => validator.validate(payload), throwsFormatException);

    payload['courses'] = [
      {'id': 1, 'name': 'Math', 'instructor': 'Dr A', 'code': 'M101',
       'mid_grade': double.nan},
    ];
    expect(() => validator.validate(payload), throwsFormatException);

    payload['courses'] = [
      {'id': 1, 'name': 'Math', 'instructor': 'Dr A', 'code': 'M101'},
    ];
    (payload['tasks'] as List).first['due_date'] = 'not-a-date';
    expect(() => validator.validate(payload), throwsFormatException);
  });

  test('rejects malformed exam fields and task reminder offsets', () {
    final payload = _validPayload();
    (payload['exams'] as List).first['exam_date'] = 'not-a-date';
    expect(() => validator.validate(payload), throwsFormatException);

    payload['exams'] = [
      {'id': 1, 'title': 'Midterm', 'exam_date': '2026-12-01',
       'location': 42, 'course_id': 1},
    ];
    expect(() => validator.validate(payload), throwsFormatException);

    payload['exams'] = [
      {'id': 1, 'title': 'Midterm', 'exam_date': '2026-12-01',
       'course_id': 1},
    ];
    (payload['tasks'] as List).first['reminder_offset_minutes'] = -10;
    expect(() => validator.validate(payload), throwsFormatException);
  });

  test('accepts v1 backups without materials metadata', () {
    final payload = _validPayload()
      ..['schema'] = 'academic_os_backup_v1'
      ..remove('materials');
    expect(validator.validate(payload).materials, isNull);
  });
}
