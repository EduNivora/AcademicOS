import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/notifications/notification_service.dart';

void main() {
  group('NotificationService reminder date resolution', () {
    test('disabled reminders never produce a scheduled date', () {
      expect(
        NotificationService.resolveReminderDate(
          reminderEnabled: false,
          dueDate: DateTime(2026, 11, 23, 10),
          reminderDate: null,
          reminderOffsetMinutes: 15,
        ),
        isNull,
      );
    });

    test('explicit reminder date takes precedence over due-date offset', () {
      final explicit = DateTime(2026, 11, 23, 8, 30);
      expect(
        NotificationService.resolveReminderDate(
          reminderEnabled: true,
          dueDate: DateTime(2026, 11, 23, 10),
          reminderDate: explicit,
          reminderOffsetMinutes: 15,
        ),
        explicit,
      );
    });

    test('due date is shifted by the configured reminder offset', () {
      expect(
        NotificationService.resolveReminderDate(
          reminderEnabled: true,
          dueDate: DateTime(2026, 11, 23, 10),
          reminderDate: null,
          reminderOffsetMinutes: 30,
        ),
        DateTime(2026, 11, 23, 9, 30),
      );
    });

    test('missing due date does not schedule a reminder', () {
      expect(
        NotificationService.resolveReminderDate(
          reminderEnabled: true,
          dueDate: null,
          reminderDate: null,
          reminderOffsetMinutes: 15,
        ),
        isNull,
      );
    });

    test('lecture reminder resolves the next matching weekday and offset', () {
      // 23 November 2026 is Monday; reminder is 15 minutes before 09:00.
      expect(
        NotificationService.resolveLectureReminderDate(
          now: DateTime(2026, 11, 23, 8),
          weekdayName: 'الاثنين',
          startTime: '09:00',
          reminderOffsetMinutes: 15,
        ),
        DateTime(2026, 11, 23, 8, 45),
      );
    });

    test('past lecture time rolls forward by one week', () {
      expect(
        NotificationService.resolveLectureReminderDate(
          now: DateTime(2026, 11, 23, 10),
          weekdayName: 'الاثنين',
          startTime: '09:00',
          reminderOffsetMinutes: 15,
        ),
        DateTime(2026, 11, 30, 8, 45),
      );
    });

    test('unknown Arabic weekday is rejected', () {
      expect(
        NotificationService.resolveLectureReminderDate(
          now: DateTime(2026, 11, 23, 8),
          weekdayName: 'يوم غير معروف',
          startTime: '09:00',
          reminderOffsetMinutes: 15,
        ),
        isNull,
      );
    });
  });
}
