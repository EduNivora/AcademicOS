import 'dart:convert';

import '../../data/models/course_model.dart';
import '../../data/models/exam_model.dart';
import '../../data/models/task_model.dart';

enum AcademicReportPeriod { daily, weekly, monthly, finalReport }

extension AcademicReportPeriodX on AcademicReportPeriod {
  String get arabicLabel => switch (this) {
    AcademicReportPeriod.daily => 'اليومي',
    AcademicReportPeriod.weekly => 'الأسبوعي',
    AcademicReportPeriod.monthly => 'الشهري',
    AcademicReportPeriod.finalReport => 'النهائي',
  };
}

class AcademicReportService {
  const AcademicReportService();

  Map<String, dynamic> buildBackupPayload({
    required List<CourseModel> courses,
    required List<TaskModel> tasks,
    required List<ExamModel> exams,
    required List<Map<String, dynamic>> schedule,
    List<Map<String, dynamic>> materials = const [],
    String schema = 'academic_os_backup_v3',
  }) {
    final payload = <String, dynamic>{
      'schema': schema,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'courses': courses.map((course) => course.toMap()).toList(),
      'tasks': tasks.map((task) => task.toMap()).toList(),
      'exams': exams.map((exam) => exam.toMap()).toList(),
      'schedule': schedule,
      'materials': materials,
    };
    return payload;
  }

  String encodeBackupJson(Map<String, dynamic> payload) {
    final compactJson = const JsonEncoder.withIndent('  ').convert(payload);
    return base64.encode(utf8.encode(compactJson));
  }

  String generatePeriodReport({
    required AcademicReportPeriod period,
    required List<CourseModel> courses,
    required List<TaskModel> tasks,
    required List<ExamModel> exams,
    required List<Map<String, dynamic>> schedule,
    DateTime? generatedAt,
  }) {
    final now = (generatedAt ?? DateTime.now()).toLocal();
    final coursesById = {
      for (final course in courses)
        if (course.id != null) course.id!: course,
    };
    String materialName(int? materialId, String? legacyName) {
      if (materialId != null) {
        final material = coursesById[materialId];
        if (material != null) return material.name;
      }
      return legacyName?.trim().isNotEmpty == true
          ? legacyName!.trim()
          : 'مادة غير محددة';
    }

    final today = DateTime(now.year, now.month, now.day);
    final DateTime? start;
    final DateTime? end;
    switch (period) {
      case AcademicReportPeriod.daily:
        start = today;
        end = today.add(const Duration(days: 1));
      case AcademicReportPeriod.weekly:
        start = today.subtract(Duration(days: today.weekday - 1));
        end = start.add(const Duration(days: 7));
      case AcademicReportPeriod.monthly:
        start = DateTime(today.year, today.month);
        end = DateTime(today.year, today.month + 1);
      case AcademicReportPeriod.finalReport:
        start = null;
        end = null;
    }

    bool inPeriod(DateTime value) {
      final local = value.toLocal();
      if (start == null || end == null) return true;
      return !local.isBefore(start) && local.isBefore(end);
    }

    final completed = tasks.where((task) {
      return task.isCompleted &&
          task.completedAt != null &&
          inPeriod(task.completedAt!);
    }).toList()..sort((a, b) => a.completedAt!.compareTo(b.completedAt!));
    final completedWithoutTimestamp = tasks
        .where((task) => task.isCompleted && task.completedAt == null)
        .toList();
    final pending = tasks.where((task) => !task.isCompleted).toList()
      ..sort((a, b) {
        final aDue = a.endDateTime ?? a.dueDate ?? DateTime(9999);
        final bDue = b.endDateTime ?? b.dueDate ?? DateTime(9999);
        return aDue.compareTo(bDue);
      });
    final pendingDueInPeriod = pending.where((task) {
      final due = task.endDateTime ?? task.dueDate;
      return due != null && inPeriod(due);
    }).length;
    final pendingWithoutDue = pending
        .where((task) => task.endDateTime == null && task.dueDate == null)
        .toList();

    final dayName = _arabicDayName(today.weekday);
    final weeklySchedule = [...schedule]
      ..sort((a, b) {
        final dayCompare = _weekdayOrder(
          a['day_of_week']?.toString(),
        ).compareTo(_weekdayOrder(b['day_of_week']?.toString()));
        if (dayCompare != 0) return dayCompare;
        return (a['start_time']?.toString() ?? '').compareTo(
          b['start_time']?.toString() ?? '',
        );
      });
    final scheduledForPeriod = period == AcademicReportPeriod.daily
        ? weeklySchedule
              .where((item) => item['day_of_week']?.toString() == dayName)
              .toList()
        : weeklySchedule;

    final upcomingExams = exams.where((exam) {
      return !exam.examDate.isBefore(today) && inPeriod(exam.examDate);
    }).toList()..sort((a, b) => a.examDate.compareTo(b.examDate));

    final lines = <String>[
      'EduNivora — التقرير الأكاديمي ${period.arabicLabel}',
      'تاريخ الإنشاء: ${_formatDateTime(now)}',
      if (start != null && end != null)
        'الفترة: ${_formatDate(start)} إلى ${_formatDate(end.subtract(const Duration(days: 1)))}',
      '',
      'الإنجاز الفعلي:',
      '• المهام المكتملة خلال الفترة: ${completed.length}',
    ];

    if (completed.isEmpty) {
      lines.add('• لا توجد مهام مسجلة كمكتملة خلال هذه الفترة.');
    } else {
      for (final task in completed) {
        final courseLabel = materialName(task.courseId, task.courseName);
        final course = courseLabel == 'مادة غير محددة' ? '' : ' — $courseLabel';
        lines.add(
          '• ${task.title}$course — ${_formatDateTime(task.completedAt!.toLocal())}',
        );
      }
    }

    lines.add('');
    lines.add('المهام المتبقية غير المكتملة: ${pending.length}');
    lines.add('• المستحقة خلال الفترة المحددة: $pendingDueInPeriod');
    if (pending.isEmpty) {
      lines.add('• لا توجد مهام غير مكتملة مستحقة ضمن هذه الفترة.');
    } else {
      for (final task in pending) {
        final due = task.endDateTime ?? task.dueDate;
        final dueText = due == null
            ? 'دون موعد محدد'
            : _formatDateTime(due.toLocal());
        lines.add('• ${task.title} — $dueText');
      }
    }
    if (pendingWithoutDue.isNotEmpty) {
      lines.add('مهام غير مكتملة دون تاريخ استحقاق:');
      for (final task in pendingWithoutDue) {
        lines.add('• ${task.title}');
      }
    }

    lines.add('');
    lines.add(
      period == AcademicReportPeriod.daily
          ? 'المحاضرات المجدولة اليوم: ${scheduledForPeriod.length}'
          : 'بنود الجدول الأسبوعي المرجعي: ${scheduledForPeriod.length}',
    );
    if (scheduledForPeriod.isEmpty) {
      lines.add('• لا توجد محاضرات مدرجة في الجدول لهذه الفترة.');
    } else {
      for (final item in scheduledForPeriod) {
        final rawCourseId = item['course_id'];
        final courseId = rawCourseId is int
            ? rawCourseId
            : int.tryParse(rawCourseId?.toString() ?? '');
        final name = materialName(courseId, item['course_name']?.toString());
        final day = item['day_of_week']?.toString() ?? '';
        final startTime = item['start_time']?.toString() ?? '';
        final endTime = item['end_time']?.toString() ?? '';
        lines.add('• $name — $day — $startTime إلى $endTime');
      }
    }
    lines.add(
      'ملاحظة: الجدول يثبت أن المحاضرة مجدولة فقط، ولا يثبت الحضور أو المذاكرة.',
    );

    lines.add('');
    lines.add('الاختبارات القادمة ضمن الفترة: ${upcomingExams.length}');
    if (upcomingExams.isEmpty) {
      lines.add('• لا توجد اختبارات قادمة مسجلة ضمن هذه الفترة.');
    } else {
      for (final exam in upcomingExams) {
        lines.add(
          '• ${exam.title} — ${_formatDateTime(exam.examDate.toLocal())} — ${materialName(exam.courseId, exam.courseName)}',
        );
      }
    }

    if (period == AcademicReportPeriod.finalReport &&
        completedWithoutTimestamp.isNotEmpty) {
      lines.add('');
      lines.add(
        'مهام قديمة معلّمة كمكتملة دون تاريخ إنجاز محفوظ: ${completedWithoutTimestamp.length}. لم تُنسب إلى فترة زمنية محددة.',
      );
    }
    lines.add('');
    lines.add('عدد المواد المسجلة: ${courses.length}');
    lines.add('');
    lines.add('تم احتساب هذا التقرير من السجلات المحفوظة فعلياً داخل التطبيق.');
    return lines.join('\n');
  }

  /// Backward-compatible final report entry point; no GPA or inferred grades.
  String generateAcademicReport({
    required List<CourseModel> courses,
    required List<TaskModel> tasks,
    required List<ExamModel> exams,
    required List<Map<String, dynamic>> schedule,
  }) => generatePeriodReport(
    period: AcademicReportPeriod.finalReport,
    courses: courses,
    tasks: tasks,
    exams: exams,
    schedule: schedule,
  );

  static String _arabicDayName(int weekday) => switch (weekday) {
    DateTime.monday => 'الاثنين',
    DateTime.tuesday => 'الثلاثاء',
    DateTime.wednesday => 'الأربعاء',
    DateTime.thursday => 'الخميس',
    DateTime.friday => 'الجمعة',
    DateTime.saturday => 'السبت',
    _ => 'الأحد',
  };

  static int _weekdayOrder(String? day) => switch (day) {
    'السبت' => 0,
    'الأحد' => 1,
    'الاثنين' => 2,
    'الثلاثاء' => 3,
    'الأربعاء' => 4,
    'الخميس' => 5,
    'الجمعة' => 6,
    _ => 7,
  };

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _formatDateTime(DateTime date) =>
      '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
