import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/course_entity.dart';
import '../../domain/entities/task_entity.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (kIsWeb) return;

    try {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
      } catch (_) {
        // Fallback to local timezone if the region is unavailable.
      }

      const androidInitializationSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initializationSettings = InitializationSettings(
        android: androidInitializationSettings,
      );
      await _plugin.initialize(initializationSettings);

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();

      const taskChannel = AndroidNotificationChannel(
        'academic_os_tasks',
        'EduNivora — تذكيرات المهام',
        description: 'تذكيرات المهام والمواعيد النهائية في EduNivora',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      const courseChannel = AndroidNotificationChannel(
        'academic_os_courses',
        'EduNivora — تذكيرات المحاضرات',
        description: 'تذكيرات المحاضرات والمواد الدراسية في EduNivora',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      const reportChannel = AndroidNotificationChannel(
        'academic_os_reports',
        'EduNivora — التقارير الأكاديمية',
        description: 'إشعارات تجهيز التقارير الأكاديمية',
        importance: Importance.defaultImportance,
        playSound: true,
      );

      await androidPlugin?.createNotificationChannel(taskChannel);
      await androidPlugin?.createNotificationChannel(courseChannel);
      await androidPlugin?.createNotificationChannel(reportChannel);
    } catch (error, stackTrace) {
      debugPrint('NotificationService.initialize error: $error\n$stackTrace');
    }
  }

  static DateTime? resolveReminderDate({
    required bool reminderEnabled,
    required DateTime? dueDate,
    required DateTime? reminderDate,
    required int reminderOffsetMinutes,
  }) {
    if (!reminderEnabled) {
      return null;
    }

    if (reminderDate != null) {
      return reminderDate;
    }

    if (dueDate == null) {
      return null;
    }

    return dueDate.subtract(Duration(minutes: reminderOffsetMinutes));
  }

  int _taskNotificationId(int id) => id + 10000;

  int _courseNotificationId(int id) => id + 20000;

  int _lectureNotificationId(int id) => id + 30000;

  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      final canScheduleExact = await androidPlugin
          ?.canScheduleExactNotifications();
      if (canScheduleExact == true) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService exact-alarm permission check failed: $error\n$stackTrace',
      );
    }

    // Keep reminders working when Android exact-alarm access is unavailable.
    // Delivery may be delayed by Android battery optimizations.
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static int? _arabicWeekdayToDateTimeWeekday(String? weekdayName) {
    switch (weekdayName) {
      case 'السبت':
        return 6;
      case 'الأحد':
        return 7;
      case 'الاثنين':
        return 1;
      case 'الثلاثاء':
        return 2;
      case 'الأربعاء':
        return 3;
      case 'الخميس':
        return 4;
      case 'الجمعة':
        return 5;
      default:
        return null;
    }
  }

  static DateTime? resolveCourseReminderDate({
    required bool reminderEnabled,
    required DateTime? lectureDate,
    required int reminderOffsetMinutes,
  }) {
    return resolveReminderDate(
      reminderEnabled: reminderEnabled,
      dueDate: lectureDate,
      reminderDate: null,
      reminderOffsetMinutes: reminderOffsetMinutes,
    );
  }

  static DateTime? resolveLectureReminderDate({
    required DateTime now,
    required String weekdayName,
    required String startTime,
    required int reminderOffsetMinutes,
  }) {
    final targetWeekday = _arabicWeekdayToDateTimeWeekday(weekdayName);
    if (targetWeekday == null) return null;

    final timeParts = startTime.split(':');
    final hour = int.tryParse(timeParts.first) ?? 0;
    final minute = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;
    final lectureStart = DateTime(now.year, now.month, now.day, hour, minute);

    var diffDays = (targetWeekday - now.weekday + 7) % 7;
    if (diffDays == 0 && lectureStart.isBefore(now)) {
      diffDays = 7;
    }

    final nextLectureDate = now.add(Duration(days: diffDays));
    final reminder = DateTime(
      nextLectureDate.year,
      nextLectureDate.month,
      nextLectureDate.day,
      hour,
      minute,
    ).subtract(Duration(minutes: reminderOffsetMinutes));

    return reminder.isBefore(now)
        ? reminder.add(const Duration(days: 7))
        : reminder;
  }

  Future<void> showReportReadyNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'academic_os_reports',
            'Academic reports',
            channelDescription: 'Notifications when academic reports are ready',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            playSound: true,
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.showReportReadyNotification error: $error\n$stackTrace',
      );
    }
  }

  Future<void> scheduleTaskReminder(TaskEntity task) async {
    if (kIsWeb || task.id == null) {
      return;
    }

    final scheduledAt = resolveReminderDate(
      reminderEnabled: task.reminderEnabled,
      dueDate: task.dueDate,
      reminderDate: task.reminderDate,
      reminderOffsetMinutes: task.reminderOffsetMinutes,
    );

    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelTaskReminder(task.id!);
      return;
    }

    try {
      await _plugin.zonedSchedule(
        _taskNotificationId(task.id!),
        'تذكير: ${task.title}',
        task.description.isNotEmpty
            ? task.description
            : 'لا تنسَ المهمة التي أضفتها.',
        tz.TZDateTime.from(scheduledAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'academic_os_tasks',
            'Task reminders',
            channelDescription: 'Reminders for tasks and deadlines',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: await _resolveAndroidScheduleMode(),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleTaskReminder error: $error\n$stackTrace',
      );
    }
  }

  Future<void> scheduleCourseReminder(CourseEntity course) async {
    if (kIsWeb || course.id == null) {
      return;
    }

    final scheduledAt = resolveCourseReminderDate(
      reminderEnabled: course.lectureReminderEnabled,
      lectureDate: course.lectureDate,
      reminderOffsetMinutes: course.lectureReminderOffsetMinutes,
    );

    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelCourseReminder(course.id!);
      return;
    }

    try {
      await _plugin.zonedSchedule(
        _courseNotificationId(course.id!),
        'محاضرة قريبة: ${course.name}',
        course.notes?.isNotEmpty == true
            ? course.notes!
            : 'لا تنسَ موعد المحاضرة القادمة.',
        tz.TZDateTime.from(scheduledAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'academic_os_courses',
            'Lecture reminders',
            channelDescription: 'Reminders for lectures and course events',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: await _resolveAndroidScheduleMode(),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleCourseReminder error: $error\n$stackTrace',
      );
    }
  }

  Future<void> cancelTaskReminder(int taskId) async {
    try {
      await _plugin.cancel(_taskNotificationId(taskId));
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelTaskReminder error: $error\n$stackTrace',
      );
    }
  }

  Future<void> cancelCourseReminder(int courseId) async {
    try {
      await _plugin.cancel(_courseNotificationId(courseId));
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelCourseReminder error: $error\n$stackTrace',
      );
    }
  }

  Future<void> scheduleLectureReminder({
    required int id,
    required String title,
    required String weekdayName,
    required String startTime,
    required bool reminderEnabled,
    String? location,
    int reminderOffsetMinutes = 15,
  }) async {
    if (kIsWeb || !reminderEnabled) {
      await cancelLectureReminder(id);
      return;
    }

    final scheduledAt = resolveLectureReminderDate(
      now: DateTime.now(),
      weekdayName: weekdayName,
      startTime: startTime,
      reminderOffsetMinutes: reminderOffsetMinutes,
    );

    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelLectureReminder(id);
      return;
    }

    try {
      await _plugin.zonedSchedule(
        _lectureNotificationId(id),
        'محاضرة قريبة: $title',
        location != null && location.isNotEmpty
            ? 'الموقع: $location'
            : 'لا تنس موعد المحاضرة القادمة.',
        tz.TZDateTime.from(scheduledAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'academic_os_courses',
            'Lecture reminders',
            channelDescription: 'Reminders for lectures and course events',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: await _resolveAndroidScheduleMode(),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleLectureReminder error: $error\n$stackTrace',
      );
    }
  }

  Future<void> cancelLectureReminder(int scheduleId) async {
    try {
      await _plugin.cancel(_lectureNotificationId(scheduleId));
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelLectureReminder error: $error\n$stackTrace',
      );
    }
  }

  Future<void> syncLectureReminders({
    required List<Map<String, dynamic>> schedules,
    required List<CourseEntity> courses,
  }) async {
    if (kIsWeb) return;

    final coursesById = {
      for (final course in courses)
        if (course.id != null) course.id!: course,
    };
    final activeScheduleIds = <int>{};

    for (final schedule in schedules) {
      final rawId = schedule['id'];
      final scheduleId = rawId is int
          ? rawId
          : int.tryParse(rawId?.toString() ?? '');
      if (scheduleId == null) continue;
      activeScheduleIds.add(scheduleId);

      final enabled =
          schedule['reminder_enabled'] == 1 ||
          schedule['reminder_enabled'] == true;
      final rawCourseId = schedule['course_id'];
      final courseId = rawCourseId is int
          ? rawCourseId
          : int.tryParse(rawCourseId?.toString() ?? '');
      final course = courseId == null ? null : coursesById[courseId];
      if (!enabled || course == null) {
        await cancelLectureReminder(scheduleId);
        continue;
      }

      final offsetValue = schedule['reminder_offset_minutes'];
      final offset = offsetValue is int
          ? offsetValue
          : int.tryParse(offsetValue?.toString() ?? '') ?? 15;
      await scheduleLectureReminder(
        id: scheduleId,
        title: course.name,
        weekdayName: schedule['day_of_week']?.toString() ?? '',
        startTime: schedule['start_time']?.toString() ?? '',
        reminderEnabled: true,
        location: schedule['location']?.toString(),
        reminderOffsetMinutes: offset,
      );
    }

    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (request.id >= 30000 && request.id < 40000) {
          final scheduleId = request.id - 30000;
          if (!activeScheduleIds.contains(scheduleId)) {
            await _plugin.cancel(request.id);
          }
        }
      }
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.syncLectureReminders cleanup error: $error\n$stackTrace',
      );
    }
  }

  Future<bool> cancelAllNotifications() async {
    try {
      await _plugin.cancelAll();
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelAllNotifications error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<void> syncReminders({
    required List<TaskEntity> tasks,
    required List<CourseEntity> courses,
  }) async {
    if (kIsWeb) return;

    for (final task in tasks) {
      if (task.id == null) {
        continue;
      }
      if (task.reminderEnabled) {
        await scheduleTaskReminder(task);
      } else {
        await cancelTaskReminder(task.id!);
      }
    }

    // Legacy course-level lecture reminders are intentionally disabled.
    // Lecture reminders now come only from the weekly schedule records.
    for (final course in courses) {
      if (course.id != null) {
        await cancelCourseReminder(course.id!);
      }
    }
  }
}
