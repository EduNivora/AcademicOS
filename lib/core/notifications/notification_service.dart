import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  static const MethodChannel _deviceTimeZoneChannel =
      MethodChannel('edunivora/device_timezone');

  bool _isInitialized = false;
  bool _notificationsPermissionGranted = false;

  bool get _canSchedule =>
      _isInitialized && _notificationsPermissionGranted;

  /// Configures the timezone calculations using Android's device IANA zone.
  /// Unknown identifiers are rejected so a reminder is never scheduled in UTC
  /// or an unrelated hard-coded timezone by accident.
  static bool configureLocalTimeZone(String identifier) {
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(identifier));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> initialize() async {
    _isInitialized = false;
    _notificationsPermissionGranted = false;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    try {
      final localTimeZone =
          await _deviceTimeZoneChannel.invokeMethod<String>('getLocalTimeZone');
      if (localTimeZone == null ||
          localTimeZone.isEmpty ||
          !configureLocalTimeZone(localTimeZone)) {
        throw StateError('Android did not provide a valid IANA timezone.');
      }

      const androidInitializationSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initializationSettings = InitializationSettings(
        android: androidInitializationSettings,
      );
      final initialized = await _plugin.initialize(initializationSettings);
      if (initialized == false) {
        throw StateError('The Android notification plugin did not initialize.');
      }

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin == null) {
        throw StateError('The Android notification platform is unavailable.');
      }

      const taskChannel = AndroidNotificationChannel(
        'academic_os_tasks',
        'Task reminders',
        description: 'Reminders for tasks and deadlines',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      const courseChannel = AndroidNotificationChannel(
        'academic_os_courses',
        'Lecture reminders',
        description: 'Reminders for lectures and course events',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await androidPlugin.createNotificationChannel(taskChannel);
      await androidPlugin.createNotificationChannel(courseChannel);

      final permissionGranted =
          await androidPlugin.requestNotificationsPermission();
      _notificationsPermissionGranted = permissionGranted ?? true;
      _isInitialized = true;
      return _notificationsPermissionGranted;
    } catch (error, stackTrace) {
      debugPrint('NotificationService.initialize error: $error\n$stackTrace');
      _isInitialized = false;
      _notificationsPermissionGranted = false;
      return false;
    }
  }

  static DateTime? resolveReminderDate({
    required bool reminderEnabled,
    required DateTime? dueDate,
    required DateTime? reminderDate,
    required int reminderOffsetMinutes,
  }) {
    if (!reminderEnabled || reminderOffsetMinutes < 0) {
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

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      final canScheduleExact =
          await androidPlugin?.canScheduleExactNotifications();
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

  static DateTime? resolveLectureReminderDate({
    required DateTime now,
    required String weekdayName,
    required String startTime,
    required int reminderOffsetMinutes,
  }) {
    final targetWeekday = _arabicWeekdayToDateTimeWeekday(weekdayName);
    if (targetWeekday == null ||
        reminderOffsetMinutes < 0 ||
        reminderOffsetMinutes > 10080) {
      return null;
    }

    final time = RegExp(r'^(\d{1,2}):(\d{2})

    final hour = int.parse(time.group(1)!);
    final minute = int.parse(time.group(2)!);
    if (hour > 23 || minute > 59) return null;

    var daysUntilLecture = (targetWeekday - now.weekday + 7) % 7;
    final lectureDate = DateTime(
      now.year,
      now.month,
      now.day + daysUntilLecture,
      hour,
      minute,
    );
    if (daysUntilLecture == 0 && !lectureDate.isAfter(now)) {
      daysUntilLecture = 7;
    }

    final nextLecture = DateTime(
      now.year,
      now.month,
      now.day + daysUntilLecture,
      hour,
      minute,
    );
    final reminder =
        nextLecture.subtract(Duration(minutes: reminderOffsetMinutes));
    return reminder.isBefore(now) ? null : reminder;
  }

  Future<bool> scheduleTaskReminder(TaskEntity task) async {
    if (kIsWeb || task.id == null) return false;
    if (!task.reminderEnabled) return cancelTaskReminder(task.id!);

    final scheduledAt = resolveReminderDate(
      reminderEnabled: task.reminderEnabled,
      dueDate: task.dueDate,
      reminderDate: task.reminderDate,
      reminderOffsetMinutes: task.reminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelTaskReminder(task.id!);
      return false;
    }
    if (!_canSchedule) return false;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleTaskReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> scheduleCourseReminder(CourseEntity course) async {
    if (kIsWeb || course.id == null) return false;
    if (!course.lectureReminderEnabled) {
      return cancelCourseReminder(course.id!);
    }

    final scheduledAt = resolveReminderDate(
      reminderEnabled: course.lectureReminderEnabled,
      dueDate: course.lectureDate,
      reminderDate: course.lectureDate,
      reminderOffsetMinutes: course.lectureReminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelCourseReminder(course.id!);
      return false;
    }
    if (!_canSchedule) return false;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleCourseReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelTaskReminder(int taskId) async {
    try {
      await _plugin.cancel(_taskNotificationId(taskId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelTaskReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelCourseReminder(int courseId) async {
    try {
      await _plugin.cancel(_courseNotificationId(courseId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelCourseReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> scheduleLectureReminder({
    required int id,
    required String title,
    required String weekdayName,
    required String startTime,
    required bool reminderEnabled,
    String? location,
    int reminderOffsetMinutes = 15,
  }) async {
    if (kIsWeb) return false;
    if (!reminderEnabled) return cancelLectureReminder(id);

    final scheduledAt = resolveLectureReminderDate(
      now: DateTime.now(),
      weekdayName: weekdayName,
      startTime: startTime,
      reminderOffsetMinutes: reminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelLectureReminder(id);
      return false;
    }
    if (!_canSchedule) return false;

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
            channelDescription: 'Reminders for lectures and course deadlines',
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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleLectureReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelLectureReminder(int scheduleId) async {
    try {
      await _plugin.cancel(_lectureNotificationId(scheduleId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelLectureReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> syncReminders({
    required List<TaskEntity> tasks,
    required List<CourseEntity> courses,
  }) async {
    if (kIsWeb) return false;

    var allRemindersHandled = true;
    for (final task in tasks) {
      if (task.id == null) continue;
      final success = task.reminderEnabled
          ? await scheduleTaskReminder(task)
          : await cancelTaskReminder(task.id!);
      allRemindersHandled = success && allRemindersHandled;
    }

    for (final course in courses) {
      if (course.id == null) continue;
      final success = course.lectureReminderEnabled
          ? await scheduleCourseReminder(course)
          : await cancelCourseReminder(course.id!);
      allRemindersHandled = success && allRemindersHandled;
    }

    return allRemindersHandled;
  }
}
)
        .firstMatch(startTime.trim());
    if (time == null) return null;

    final hour = int.parse(time.group(1)!);
    final minute = int.parse(time.group(2)!);
    if (hour > 23 || minute > 59) return null;

    var daysUntilLecture = (targetWeekday - now.weekday + 7) % 7;
    final lectureDate = DateTime(
      now.year,
      now.month,
      now.day + daysUntilLecture,
      hour,
      minute,
    );
    if (daysUntilLecture == 0 && !lectureDate.isAfter(now)) {
      daysUntilLecture = 7;
    }

    final nextLecture = DateTime(
      now.year,
      now.month,
      now.day + daysUntilLecture,
      hour,
      minute,
    );
    final reminder =
        nextLecture.subtract(Duration(minutes: reminderOffsetMinutes));
    return reminder.isBefore(now) ? null : reminder;
  }

  Future<bool> scheduleTaskReminder(TaskEntity task) async {
    if (kIsWeb || task.id == null) return false;
    if (!task.reminderEnabled) return cancelTaskReminder(task.id!);

    final scheduledAt = resolveReminderDate(
      reminderEnabled: task.reminderEnabled,
      dueDate: task.dueDate,
      reminderDate: task.reminderDate,
      reminderOffsetMinutes: task.reminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelTaskReminder(task.id!);
      return false;
    }
    if (!_canSchedule) return false;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleTaskReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> scheduleCourseReminder(CourseEntity course) async {
    if (kIsWeb || course.id == null) return false;
    if (!course.lectureReminderEnabled) {
      return cancelCourseReminder(course.id!);
    }

    final scheduledAt = resolveReminderDate(
      reminderEnabled: course.lectureReminderEnabled,
      dueDate: course.lectureDate,
      reminderDate: course.lectureDate,
      reminderOffsetMinutes: course.lectureReminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelCourseReminder(course.id!);
      return false;
    }
    if (!_canSchedule) return false;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleCourseReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelTaskReminder(int taskId) async {
    try {
      await _plugin.cancel(_taskNotificationId(taskId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelTaskReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelCourseReminder(int courseId) async {
    try {
      await _plugin.cancel(_courseNotificationId(courseId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelCourseReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> scheduleLectureReminder({
    required int id,
    required String title,
    required String weekdayName,
    required String startTime,
    required bool reminderEnabled,
    String? location,
    int reminderOffsetMinutes = 15,
  }) async {
    if (kIsWeb) return false;
    if (!reminderEnabled) return cancelLectureReminder(id);

    final scheduledAt = resolveLectureReminderDate(
      now: DateTime.now(),
      weekdayName: weekdayName,
      startTime: startTime,
      reminderOffsetMinutes: reminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelLectureReminder(id);
      return false;
    }
    if (!_canSchedule) return false;

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
            channelDescription: 'Reminders for lectures and course deadlines',
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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleLectureReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelLectureReminder(int scheduleId) async {
    try {
      await _plugin.cancel(_lectureNotificationId(scheduleId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelLectureReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> syncReminders({
    required List<TaskEntity> tasks,
    required List<CourseEntity> courses,
  }) async {
    if (kIsWeb) return false;

    var allRemindersHandled = true;
    for (final task in tasks) {
      if (task.id == null) continue;
      final success = task.reminderEnabled
          ? await scheduleTaskReminder(task)
          : await cancelTaskReminder(task.id!);
      allRemindersHandled = success && allRemindersHandled;
    }

    for (final course in courses) {
      if (course.id == null) continue;
      final success = course.lectureReminderEnabled
          ? await scheduleCourseReminder(course)
          : await cancelCourseReminder(course.id!);
      allRemindersHandled = success && allRemindersHandled;
    }

    return allRemindersHandled;
  }
}
).firstMatch(startTime.trim());
    if (time == null) return null;

    final hour = int.parse(time.group(1)!);
    final minute = int.parse(time.group(2)!);
    if (hour > 23 || minute > 59) return null;

    var daysUntilLecture = (targetWeekday - now.weekday + 7) % 7;
    final lectureDate = DateTime(
      now.year,
      now.month,
      now.day + daysUntilLecture,
      hour,
      minute,
    );
    if (daysUntilLecture == 0 && !lectureDate.isAfter(now)) {
      daysUntilLecture = 7;
    }

    final nextLecture = DateTime(
      now.year,
      now.month,
      now.day + daysUntilLecture,
      hour,
      minute,
    );
    final reminder =
        nextLecture.subtract(Duration(minutes: reminderOffsetMinutes));
    return reminder.isBefore(now) ? null : reminder;
  }

  Future<bool> scheduleTaskReminder(TaskEntity task) async {
    if (kIsWeb || task.id == null) return false;
    if (!task.reminderEnabled) return cancelTaskReminder(task.id!);

    final scheduledAt = resolveReminderDate(
      reminderEnabled: task.reminderEnabled,
      dueDate: task.dueDate,
      reminderDate: task.reminderDate,
      reminderOffsetMinutes: task.reminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelTaskReminder(task.id!);
      return false;
    }
    if (!_canSchedule) return false;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleTaskReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> scheduleCourseReminder(CourseEntity course) async {
    if (kIsWeb || course.id == null) return false;
    if (!course.lectureReminderEnabled) {
      return cancelCourseReminder(course.id!);
    }

    final scheduledAt = resolveReminderDate(
      reminderEnabled: course.lectureReminderEnabled,
      dueDate: course.lectureDate,
      reminderDate: course.lectureDate,
      reminderOffsetMinutes: course.lectureReminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelCourseReminder(course.id!);
      return false;
    }
    if (!_canSchedule) return false;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleCourseReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelTaskReminder(int taskId) async {
    try {
      await _plugin.cancel(_taskNotificationId(taskId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelTaskReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelCourseReminder(int courseId) async {
    try {
      await _plugin.cancel(_courseNotificationId(courseId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelCourseReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> scheduleLectureReminder({
    required int id,
    required String title,
    required String weekdayName,
    required String startTime,
    required bool reminderEnabled,
    String? location,
    int reminderOffsetMinutes = 15,
  }) async {
    if (kIsWeb) return false;
    if (!reminderEnabled) return cancelLectureReminder(id);

    final scheduledAt = resolveLectureReminderDate(
      now: DateTime.now(),
      weekdayName: weekdayName,
      startTime: startTime,
      reminderOffsetMinutes: reminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelLectureReminder(id);
      return false;
    }
    if (!_canSchedule) return false;

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
            channelDescription: 'Reminders for lectures and course deadlines',
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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleLectureReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelLectureReminder(int scheduleId) async {
    try {
      await _plugin.cancel(_lectureNotificationId(scheduleId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelLectureReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> syncReminders({
    required List<TaskEntity> tasks,
    required List<CourseEntity> courses,
  }) async {
    if (kIsWeb) return false;

    var allRemindersHandled = true;
    for (final task in tasks) {
      if (task.id == null) continue;
      final success = task.reminderEnabled
          ? await scheduleTaskReminder(task)
          : await cancelTaskReminder(task.id!);
      allRemindersHandled = success && allRemindersHandled;
    }

    for (final course in courses) {
      if (course.id == null) continue;
      final success = course.lectureReminderEnabled
          ? await scheduleCourseReminder(course)
          : await cancelCourseReminder(course.id!);
      allRemindersHandled = success && allRemindersHandled;
    }

    return allRemindersHandled;
  }
}
)
        .firstMatch(startTime.trim());
    if (time == null) return null;

    final hour = int.parse(time.group(1)!);
    final minute = int.parse(time.group(2)!);
    if (hour > 23 || minute > 59) return null;

    var daysUntilLecture = (targetWeekday - now.weekday + 7) % 7;
    final lectureDate = DateTime(
      now.year,
      now.month,
      now.day + daysUntilLecture,
      hour,
      minute,
    );
    if (daysUntilLecture == 0 && !lectureDate.isAfter(now)) {
      daysUntilLecture = 7;
    }

    final nextLecture = DateTime(
      now.year,
      now.month,
      now.day + daysUntilLecture,
      hour,
      minute,
    );
    final reminder =
        nextLecture.subtract(Duration(minutes: reminderOffsetMinutes));
    return reminder.isBefore(now) ? null : reminder;
  }

  Future<bool> scheduleTaskReminder(TaskEntity task) async {
    if (kIsWeb || task.id == null) return false;
    if (!task.reminderEnabled) return cancelTaskReminder(task.id!);

    final scheduledAt = resolveReminderDate(
      reminderEnabled: task.reminderEnabled,
      dueDate: task.dueDate,
      reminderDate: task.reminderDate,
      reminderOffsetMinutes: task.reminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelTaskReminder(task.id!);
      return false;
    }
    if (!_canSchedule) return false;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleTaskReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> scheduleCourseReminder(CourseEntity course) async {
    if (kIsWeb || course.id == null) return false;
    if (!course.lectureReminderEnabled) {
      return cancelCourseReminder(course.id!);
    }

    final scheduledAt = resolveReminderDate(
      reminderEnabled: course.lectureReminderEnabled,
      dueDate: course.lectureDate,
      reminderDate: course.lectureDate,
      reminderOffsetMinutes: course.lectureReminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelCourseReminder(course.id!);
      return false;
    }
    if (!_canSchedule) return false;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleCourseReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelTaskReminder(int taskId) async {
    try {
      await _plugin.cancel(_taskNotificationId(taskId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelTaskReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelCourseReminder(int courseId) async {
    try {
      await _plugin.cancel(_courseNotificationId(courseId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelCourseReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> scheduleLectureReminder({
    required int id,
    required String title,
    required String weekdayName,
    required String startTime,
    required bool reminderEnabled,
    String? location,
    int reminderOffsetMinutes = 15,
  }) async {
    if (kIsWeb) return false;
    if (!reminderEnabled) return cancelLectureReminder(id);

    final scheduledAt = resolveLectureReminderDate(
      now: DateTime.now(),
      weekdayName: weekdayName,
      startTime: startTime,
      reminderOffsetMinutes: reminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelLectureReminder(id);
      return false;
    }
    if (!_canSchedule) return false;

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
            channelDescription: 'Reminders for lectures and course deadlines',
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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleLectureReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelLectureReminder(int scheduleId) async {
    try {
      await _plugin.cancel(_lectureNotificationId(scheduleId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelLectureReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> syncReminders({
    required List<TaskEntity> tasks,
    required List<CourseEntity> courses,
  }) async {
    if (kIsWeb) return false;

    var allRemindersHandled = true;
    for (final task in tasks) {
      if (task.id == null) continue;
      final success = task.reminderEnabled
          ? await scheduleTaskReminder(task)
          : await cancelTaskReminder(task.id!);
      allRemindersHandled = success && allRemindersHandled;
    }

    for (final course in courses) {
      if (course.id == null) continue;
      final success = course.lectureReminderEnabled
          ? await scheduleCourseReminder(course)
          : await cancelCourseReminder(course.id!);
      allRemindersHandled = success && allRemindersHandled;
    }

    return allRemindersHandled;
  }
}
).firstMatch(startTime.trim());
    if (time == null) return null;

    final hour = int.parse(time.group(1)!);
    final minute = int.parse(time.group(2)!);
    if (hour > 23 || minute > 59) return null;

    var daysUntilLecture = (targetWeekday - now.weekday + 7) % 7;
    final lectureDate = DateTime(
      now.year,
      now.month,
      now.day + daysUntilLecture,
      hour,
      minute,
    );
    if (daysUntilLecture == 0 && !lectureDate.isAfter(now)) {
      daysUntilLecture = 7;
    }

    final nextLecture = DateTime(
      now.year,
      now.month,
      now.day + daysUntilLecture,
      hour,
      minute,
    );
    final reminder =
        nextLecture.subtract(Duration(minutes: reminderOffsetMinutes));
    return reminder.isBefore(now) ? null : reminder;
  }

  Future<bool> scheduleTaskReminder(TaskEntity task) async {
    if (kIsWeb || task.id == null) return false;
    if (!task.reminderEnabled) return cancelTaskReminder(task.id!);

    final scheduledAt = resolveReminderDate(
      reminderEnabled: task.reminderEnabled,
      dueDate: task.dueDate,
      reminderDate: task.reminderDate,
      reminderOffsetMinutes: task.reminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelTaskReminder(task.id!);
      return false;
    }
    if (!_canSchedule) return false;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleTaskReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> scheduleCourseReminder(CourseEntity course) async {
    if (kIsWeb || course.id == null) return false;
    if (!course.lectureReminderEnabled) {
      return cancelCourseReminder(course.id!);
    }

    final scheduledAt = resolveReminderDate(
      reminderEnabled: course.lectureReminderEnabled,
      dueDate: course.lectureDate,
      reminderDate: course.lectureDate,
      reminderOffsetMinutes: course.lectureReminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelCourseReminder(course.id!);
      return false;
    }
    if (!_canSchedule) return false;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleCourseReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelTaskReminder(int taskId) async {
    try {
      await _plugin.cancel(_taskNotificationId(taskId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelTaskReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelCourseReminder(int courseId) async {
    try {
      await _plugin.cancel(_courseNotificationId(courseId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelCourseReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> scheduleLectureReminder({
    required int id,
    required String title,
    required String weekdayName,
    required String startTime,
    required bool reminderEnabled,
    String? location,
    int reminderOffsetMinutes = 15,
  }) async {
    if (kIsWeb) return false;
    if (!reminderEnabled) return cancelLectureReminder(id);

    final scheduledAt = resolveLectureReminderDate(
      now: DateTime.now(),
      weekdayName: weekdayName,
      startTime: startTime,
      reminderOffsetMinutes: reminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelLectureReminder(id);
      return false;
    }
    if (!_canSchedule) return false;

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
            channelDescription: 'Reminders for lectures and course deadlines',
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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleLectureReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelLectureReminder(int scheduleId) async {
    try {
      await _plugin.cancel(_lectureNotificationId(scheduleId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelLectureReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> syncReminders({
    required List<TaskEntity> tasks,
    required List<CourseEntity> courses,
  }) async {
    if (kIsWeb) return false;

    var allRemindersHandled = true;
    for (final task in tasks) {
      if (task.id == null) continue;
      final success = task.reminderEnabled
          ? await scheduleTaskReminder(task)
          : await cancelTaskReminder(task.id!);
      allRemindersHandled = success && allRemindersHandled;
    }

    for (final course in courses) {
      if (course.id == null) continue;
      final success = course.lectureReminderEnabled
          ? await scheduleCourseReminder(course)
          : await cancelCourseReminder(course.id!);
      allRemindersHandled = success && allRemindersHandled;
    }

    return allRemindersHandled;
  }
}
)
        .firstMatch(startTime.trim());
    if (time == null) return null;

    final hour = int.parse(time.group(1)!);
    final minute = int.parse(time.group(2)!);
    if (hour > 23 || minute > 59) return null;

    var daysUntilLecture = (targetWeekday - now.weekday + 7) % 7;
    final lectureDate = DateTime(
      now.year,
      now.month,
      now.day + daysUntilLecture,
      hour,
      minute,
    );
    if (daysUntilLecture == 0 && !lectureDate.isAfter(now)) {
      daysUntilLecture = 7;
    }

    final nextLecture = DateTime(
      now.year,
      now.month,
      now.day + daysUntilLecture,
      hour,
      minute,
    );
    final reminder =
        nextLecture.subtract(Duration(minutes: reminderOffsetMinutes));
    return reminder.isBefore(now) ? null : reminder;
  }

  Future<bool> scheduleTaskReminder(TaskEntity task) async {
    if (kIsWeb || task.id == null) return false;
    if (!task.reminderEnabled) return cancelTaskReminder(task.id!);

    final scheduledAt = resolveReminderDate(
      reminderEnabled: task.reminderEnabled,
      dueDate: task.dueDate,
      reminderDate: task.reminderDate,
      reminderOffsetMinutes: task.reminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelTaskReminder(task.id!);
      return false;
    }
    if (!_canSchedule) return false;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleTaskReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> scheduleCourseReminder(CourseEntity course) async {
    if (kIsWeb || course.id == null) return false;
    if (!course.lectureReminderEnabled) {
      return cancelCourseReminder(course.id!);
    }

    final scheduledAt = resolveReminderDate(
      reminderEnabled: course.lectureReminderEnabled,
      dueDate: course.lectureDate,
      reminderDate: course.lectureDate,
      reminderOffsetMinutes: course.lectureReminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelCourseReminder(course.id!);
      return false;
    }
    if (!_canSchedule) return false;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleCourseReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelTaskReminder(int taskId) async {
    try {
      await _plugin.cancel(_taskNotificationId(taskId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelTaskReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelCourseReminder(int courseId) async {
    try {
      await _plugin.cancel(_courseNotificationId(courseId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelCourseReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> scheduleLectureReminder({
    required int id,
    required String title,
    required String weekdayName,
    required String startTime,
    required bool reminderEnabled,
    String? location,
    int reminderOffsetMinutes = 15,
  }) async {
    if (kIsWeb) return false;
    if (!reminderEnabled) return cancelLectureReminder(id);

    final scheduledAt = resolveLectureReminderDate(
      now: DateTime.now(),
      weekdayName: weekdayName,
      startTime: startTime,
      reminderOffsetMinutes: reminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelLectureReminder(id);
      return false;
    }
    if (!_canSchedule) return false;

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
            channelDescription: 'Reminders for lectures and course deadlines',
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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleLectureReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelLectureReminder(int scheduleId) async {
    try {
      await _plugin.cancel(_lectureNotificationId(scheduleId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelLectureReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> syncReminders({
    required List<TaskEntity> tasks,
    required List<CourseEntity> courses,
  }) async {
    if (kIsWeb) return false;

    var allRemindersHandled = true;
    for (final task in tasks) {
      if (task.id == null) continue;
      final success = task.reminderEnabled
          ? await scheduleTaskReminder(task)
          : await cancelTaskReminder(task.id!);
      allRemindersHandled = success && allRemindersHandled;
    }

    for (final course in courses) {
      if (course.id == null) continue;
      final success = course.lectureReminderEnabled
          ? await scheduleCourseReminder(course)
          : await cancelCourseReminder(course.id!);
      allRemindersHandled = success && allRemindersHandled;
    }

    return allRemindersHandled;
  }
}
).firstMatch(startTime.trim());
    if (time == null) return null;

    final hour = int.parse(time.group(1)!);
    final minute = int.parse(time.group(2)!);
    if (hour > 23 || minute > 59) return null;

    var daysUntilLecture = (targetWeekday - now.weekday + 7) % 7;
    final lectureDate = DateTime(
      now.year,
      now.month,
      now.day + daysUntilLecture,
      hour,
      minute,
    );
    if (daysUntilLecture == 0 && !lectureDate.isAfter(now)) {
      daysUntilLecture = 7;
    }

    final nextLecture = DateTime(
      now.year,
      now.month,
      now.day + daysUntilLecture,
      hour,
      minute,
    );
    final reminder =
        nextLecture.subtract(Duration(minutes: reminderOffsetMinutes));
    return reminder.isBefore(now) ? null : reminder;
  }

  Future<bool> scheduleTaskReminder(TaskEntity task) async {
    if (kIsWeb || task.id == null) return false;
    if (!task.reminderEnabled) return cancelTaskReminder(task.id!);

    final scheduledAt = resolveReminderDate(
      reminderEnabled: task.reminderEnabled,
      dueDate: task.dueDate,
      reminderDate: task.reminderDate,
      reminderOffsetMinutes: task.reminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelTaskReminder(task.id!);
      return false;
    }
    if (!_canSchedule) return false;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleTaskReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> scheduleCourseReminder(CourseEntity course) async {
    if (kIsWeb || course.id == null) return false;
    if (!course.lectureReminderEnabled) {
      return cancelCourseReminder(course.id!);
    }

    final scheduledAt = resolveReminderDate(
      reminderEnabled: course.lectureReminderEnabled,
      dueDate: course.lectureDate,
      reminderDate: course.lectureDate,
      reminderOffsetMinutes: course.lectureReminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelCourseReminder(course.id!);
      return false;
    }
    if (!_canSchedule) return false;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleCourseReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelTaskReminder(int taskId) async {
    try {
      await _plugin.cancel(_taskNotificationId(taskId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelTaskReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelCourseReminder(int courseId) async {
    try {
      await _plugin.cancel(_courseNotificationId(courseId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelCourseReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> scheduleLectureReminder({
    required int id,
    required String title,
    required String weekdayName,
    required String startTime,
    required bool reminderEnabled,
    String? location,
    int reminderOffsetMinutes = 15,
  }) async {
    if (kIsWeb) return false;
    if (!reminderEnabled) return cancelLectureReminder(id);

    final scheduledAt = resolveLectureReminderDate(
      now: DateTime.now(),
      weekdayName: weekdayName,
      startTime: startTime,
      reminderOffsetMinutes: reminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelLectureReminder(id);
      return false;
    }
    if (!_canSchedule) return false;

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
            channelDescription: 'Reminders for lectures and course deadlines',
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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleLectureReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelLectureReminder(int scheduleId) async {
    try {
      await _plugin.cancel(_lectureNotificationId(scheduleId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelLectureReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> syncReminders({
    required List<TaskEntity> tasks,
    required List<CourseEntity> courses,
  }) async {
    if (kIsWeb) return false;

    var allRemindersHandled = true;
    for (final task in tasks) {
      if (task.id == null) continue;
      final success = task.reminderEnabled
          ? await scheduleTaskReminder(task)
          : await cancelTaskReminder(task.id!);
      allRemindersHandled = success && allRemindersHandled;
    }

    for (final course in courses) {
      if (course.id == null) continue;
      final success = course.lectureReminderEnabled
          ? await scheduleCourseReminder(course)
          : await cancelCourseReminder(course.id!);
      allRemindersHandled = success && allRemindersHandled;
    }

    return allRemindersHandled;
  }
}
)
        .firstMatch(startTime.trim());
    if (time == null) return null;

    final hour = int.parse(time.group(1)!);
    final minute = int.parse(time.group(2)!);
    if (hour > 23 || minute > 59) return null;

    var daysUntilLecture = (targetWeekday - now.weekday + 7) % 7;
    final lectureDate = DateTime(
      now.year,
      now.month,
      now.day + daysUntilLecture,
      hour,
      minute,
    );
    if (daysUntilLecture == 0 && !lectureDate.isAfter(now)) {
      daysUntilLecture = 7;
    }

    final nextLecture = DateTime(
      now.year,
      now.month,
      now.day + daysUntilLecture,
      hour,
      minute,
    );
    final reminder =
        nextLecture.subtract(Duration(minutes: reminderOffsetMinutes));
    return reminder.isBefore(now) ? null : reminder;
  }

  Future<bool> scheduleTaskReminder(TaskEntity task) async {
    if (kIsWeb || task.id == null) return false;
    if (!task.reminderEnabled) return cancelTaskReminder(task.id!);

    final scheduledAt = resolveReminderDate(
      reminderEnabled: task.reminderEnabled,
      dueDate: task.dueDate,
      reminderDate: task.reminderDate,
      reminderOffsetMinutes: task.reminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelTaskReminder(task.id!);
      return false;
    }
    if (!_canSchedule) return false;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleTaskReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> scheduleCourseReminder(CourseEntity course) async {
    if (kIsWeb || course.id == null) return false;
    if (!course.lectureReminderEnabled) {
      return cancelCourseReminder(course.id!);
    }

    final scheduledAt = resolveReminderDate(
      reminderEnabled: course.lectureReminderEnabled,
      dueDate: course.lectureDate,
      reminderDate: course.lectureDate,
      reminderOffsetMinutes: course.lectureReminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelCourseReminder(course.id!);
      return false;
    }
    if (!_canSchedule) return false;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleCourseReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelTaskReminder(int taskId) async {
    try {
      await _plugin.cancel(_taskNotificationId(taskId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelTaskReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelCourseReminder(int courseId) async {
    try {
      await _plugin.cancel(_courseNotificationId(courseId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelCourseReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> scheduleLectureReminder({
    required int id,
    required String title,
    required String weekdayName,
    required String startTime,
    required bool reminderEnabled,
    String? location,
    int reminderOffsetMinutes = 15,
  }) async {
    if (kIsWeb) return false;
    if (!reminderEnabled) return cancelLectureReminder(id);

    final scheduledAt = resolveLectureReminderDate(
      now: DateTime.now(),
      weekdayName: weekdayName,
      startTime: startTime,
      reminderOffsetMinutes: reminderOffsetMinutes,
    );
    if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
      await cancelLectureReminder(id);
      return false;
    }
    if (!_canSchedule) return false;

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
            channelDescription: 'Reminders for lectures and course deadlines',
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
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.scheduleLectureReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> cancelLectureReminder(int scheduleId) async {
    try {
      await _plugin.cancel(_lectureNotificationId(scheduleId));
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService.cancelLectureReminder error: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> syncReminders({
    required List<TaskEntity> tasks,
    required List<CourseEntity> courses,
  }) async {
    if (kIsWeb) return false;

    var allRemindersHandled = true;
    for (final task in tasks) {
      if (task.id == null) continue;
      final success = task.reminderEnabled
          ? await scheduleTaskReminder(task)
          : await cancelTaskReminder(task.id!);
      allRemindersHandled = success && allRemindersHandled;
    }

    for (final course in courses) {
      if (course.id == null) continue;
      final success = course.lectureReminderEnabled
          ? await scheduleCourseReminder(course)
          : await cancelCourseReminder(course.id!);
      allRemindersHandled = success && allRemindersHandled;
    }

    return allRemindersHandled;
  }
}
