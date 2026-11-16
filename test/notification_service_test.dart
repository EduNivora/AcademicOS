import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/notifications/notification_service.dart';

void main() {
  group('Notification date resolution', () {
    test('uses the explicit reminder date when supplied', () {
      final explicitReminder = DateTime(2026, 11, 17, 8, 15);
      final resolved = NotificationService.resolveReminderDate(
        reminderEnabled: true,
        dueDate: DateTime(2026, 11, 17, 9),
        reminderDate: explicitReminder,
        reminderOffsetMinutes: 30,
      );

      expect(resolved, explicitReminder);
    });

    test('subtracts the configured offset from a due date', () {
      final resolved = NotificationService.resolveReminderDate(
        reminderEnabled: true,
        dueDate: DateTime(2026, 11, 17, 9),
        reminderDate: null,
        reminderOffsetMinutes: 30,
      );

      expect(resolved, DateTime(2026, 11, 17, 8, 30));
    });

    test('disabled or invalid reminders are not scheduled', () {
      expect(
        NotificationService.resolveReminderDate(
          reminderEnabled: false,
          dueDate: DateTime(2026, 11, 17, 9),
          reminderDate: null,
          reminderOffsetMinutes: 30,
        ),
        isNull,
      );
      expect(
        NotificationService.resolveReminderDate(
          reminderEnabled: true,
          dueDate: DateTime(2026, 11, 17, 9),
          reminderDate: null,
          reminderOffsetMinutes: -1,
        ),
        isNull,
      );
    });

    test('resolves a future lecture reminder in local calendar time', () {
      final resolved = NotificationService.resolveLectureReminderDate(
        now: DateTime(2026, 11, 16, 8),
        weekdayName: 'الثلاثاء',
        startTime: '09:00',
        reminderOffsetMinutes: 15,
      );

      expect(resolved, DateTime(2026, 11, 17, 8, 45));
    });

    test('moves a missed same-day lecture reminder to the next week', () {
      final resolved = NotificationService.resolveLectureReminderDate(
        now: DateTime(2026, 11, 16, 10),
        weekdayName: 'الاثنين',
        startTime: '09:00',
        reminderOffsetMinutes: 15,
      );

      expect(resolved, DateTime(2026, 11, 23, 8, 45));
    });

    test('rejects invalid weekdays and clock values', () {
      expect(
        NotificationService.resolveLectureReminderDate(
          now: DateTime(2026, 11, 16, 8),
          weekdayName: 'Not a weekday',
          startTime: '09:00',
          reminderOffsetMinutes: 15,
        ),
        isNull,
      );
      expect(
        NotificationService.resolveLectureReminderDate(
          now: DateTime(2026, 11, 16, 8),
          weekdayName: 'الثلاثاء',
          startTime: '25:99',
          reminderOffsetMinutes: 15,
        ),
        isNull,
      );
    });

    test('accepts an IANA device timezone and rejects an invalid identifier',
        () {
      expect(
        NotificationService.configureLocalTimeZone('Asia/Aden'),
        isTrue,
      );
      expect(
        NotificationService.configureLocalTimeZone('Invalid/TimeZone'),
        isFalse,
      );
      expect(
        NotificationService.configureLocalTimeZone('Asia/Aden'),
        isTrue,
      );
    });
  });
}
