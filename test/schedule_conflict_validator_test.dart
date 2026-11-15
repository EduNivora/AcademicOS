import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/academic/schedule_conflict_validator.dart';

void main() {
  group('ScheduleConflictValidator', () {
    const existing = <Map<String, dynamic>>[
      {
        'id': 10,
        'day_of_week': 'الأحد',
        'start_time': '09:00',
        'end_time': '10:30',
      },
    ];

    test('rejects malformed time values', () {
      final result = ScheduleConflictValidator.validate(
        day: 'الأحد',
        startTime: '9:00',
        endTime: '10:00',
        existingSchedules: existing,
      );

      expect(result.issue, ScheduleValidationIssue.invalidTimeFormat);
    });

    test('rejects zero-length or reversed time ranges', () {
      for (final range in [
        ('09:00', '09:00'),
        ('10:00', '09:00'),
      ]) {
        final result = ScheduleConflictValidator.validate(
          day: 'الأحد',
          startTime: range.$1,
          endTime: range.$2,
          existingSchedules: existing,
        );
        expect(result.issue, ScheduleValidationIssue.invalidTimeRange);
      }
    });

    test('detects overlapping entries on the same day', () {
      final result = ScheduleConflictValidator.validate(
        day: 'الأحد',
        startTime: '10:00',
        endTime: '11:00',
        existingSchedules: existing,
      );

      expect(result.issue, ScheduleValidationIssue.overlap);
      expect(result.conflictingScheduleId, 10);
    });

    test('allows adjacent entries without treating them as overlapping', () {
      final result = ScheduleConflictValidator.validate(
        day: 'الأحد',
        startTime: '10:30',
        endTime: '11:30',
        existingSchedules: existing,
      );

      expect(result.isValid, isTrue);
    });

    test('does not report an entry on another day as a conflict', () {
      final result = ScheduleConflictValidator.validate(
        day: 'الاثنين',
        startTime: '09:30',
        endTime: '10:00',
        existingSchedules: existing,
      );

      expect(result.isValid, isTrue);
    });

    test('ignores the entry currently being edited', () {
      final result = ScheduleConflictValidator.validate(
        day: 'الأحد',
        startTime: '09:15',
        endTime: '10:15',
        existingSchedules: existing,
        excludingScheduleId: 10,
      );

      expect(result.isValid, isTrue);
    });

    test('fails visibly when a same-day stored interval is malformed', () {
      final result = ScheduleConflictValidator.validate(
        day: 'الأحد',
        startTime: '11:00',
        endTime: '12:00',
        existingSchedules: const [
          {
            'id': 22,
            'day_of_week': 'الأحد',
            'start_time': 'bad',
            'end_time': '12:00',
          },
        ],
      );

      expect(result.issue, ScheduleValidationIssue.invalidStoredEntry);
      expect(result.conflictingScheduleId, 22);
    });
  });
}
