import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/academic/academic_report_service.dart';
import 'package:academic_os/data/models/course_model.dart';
import 'package:academic_os/data/models/exam_model.dart';
import 'package:academic_os/data/models/task_model.dart';

void main() {
  group('AcademicReportService', () {
    test('empty academic data produces explicit no-data report sections', () {
      final report = AcademicReportService().generatePeriodReport(
        period: AcademicReportPeriod.finalReport,
        generatedAt: DateTime(2026, 11, 24, 12),
        courses: const [],
        tasks: const [],
        exams: const [],
        schedule: const [],
      );

      expect(report, contains('عدد المواد المسجلة: 0'));
      expect(report, contains('لا توجد مهام غير مكتملة'));
      expect(report, contains('لا توجد اختبارات قادمة'));
      expect(report, contains('لا توجد محاضرات مدرجة'));
    });

    test('excludes past exams from the upcoming exam section', () {
      final service = AcademicReportService();
      final now = DateTime.now();
      final report = service.generateAcademicReport(
        courses: const [],
        tasks: const [],
        exams: [
          ExamModel(
            id: 1,
            title: 'Past Exam',
            examDate: now.subtract(const Duration(days: 1)),
          ),
          ExamModel(
            id: 2,
            title: 'Future Exam',
            examDate: now.add(const Duration(days: 1)),
          ),
        ],
        schedule: const [],
      );

      expect(report, contains('Future Exam'));
      expect(report, isNot(contains('Past Exam')));
    });

    test('generates a readable academic report', () {
      final service = AcademicReportService();

      final report = service.generateAcademicReport(
        courses: [
          const CourseModel(
            id: 1,
            name: 'Math',
            instructor: 'Dr. Ali',
            code: 'MTH101',
            creditHours: 3,
            midGrade: 80,
            practicalGrade: 85,
            finalGrade: 90,
          ),
        ],
        tasks: const [
          TaskModel(
            id: 1,
            title: 'Homework',
            description: 'Solve 5 questions',
            dueDate: null,
            isCompleted: false,
          ),
        ],
        exams: [
          ExamModel(
            id: 1,
            title: 'Midterm',
            examDate: DateTime(2026, 10, 20),
            courseName: 'Math',
          ),
        ],
        schedule: [
          {
            'day_of_week': 'Monday',
            'start_time': '09:00',
            'location': 'Room 1'
          },
        ],
      );

      expect(report, contains('EduNivora'));
      expect(report, contains('المهام المتبقية'));
      expect(report, contains('عدد المواد المسجلة: 1'));
      expect(report, isNot(contains('GPA')));
    });

    test('daily report includes only tasks completed on the selected day', () {
      final service = AcademicReportService();
      final generatedAt = DateTime(2026, 11, 20, 18);
      final report = service.generatePeriodReport(
        period: AcademicReportPeriod.daily,
        generatedAt: generatedAt,
        courses: const [],
        tasks: [
          TaskModel(
            id: 1,
            title: 'Completed today',
            description: '',
            isCompleted: true,
            completedAt: DateTime(2026, 11, 20, 10),
          ),
          TaskModel(
            id: 2,
            title: 'Completed yesterday',
            description: '',
            isCompleted: true,
            completedAt: DateTime(2026, 11, 19, 10),
          ),
          TaskModel(
            id: 3,
            title: 'Due today',
            description: '',
            dueDate: DateTime(2026, 11, 20, 21),
            isCompleted: false,
          ),
        ],
        exams: const [],
        schedule: const [],
      );

      expect(report, contains('Completed today'));
      expect(report, isNot(contains('Completed yesterday')));
      expect(report, contains('Due today'));
      expect(report, contains('لا يثبت الحضور'));
      expect(report, isNot(contains('GPA')));
    });

    test('final report separates legacy completed tasks without timestamps', () {
      final report = AcademicReportService().generatePeriodReport(
        period: AcademicReportPeriod.finalReport,
        generatedAt: DateTime(2026, 11, 20),
        courses: const [],
        tasks: const [
          TaskModel(
            id: 1,
            title: 'Legacy completed',
            description: '',
            isCompleted: true,
          ),
        ],
        exams: const [],
        schedule: const [],
      );

      expect(report, contains('دون تاريخ إنجاز محفوظ'));
      expect(report, isNot(contains('Legacy completed — 2026')));
    });

    test('weekly and monthly reports respect their local period boundaries', () {
      final service = AcademicReportService();
      final tasks = [
        TaskModel(
          id: 1,
          title: 'Inside week',
          description: '',
          isCompleted: true,
          completedAt: DateTime(2026, 11, 16, 9),
        ),
        TaskModel(
          id: 2,
          title: 'Outside week',
          description: '',
          isCompleted: true,
          completedAt: DateTime(2026, 11, 15, 9),
        ),
        TaskModel(
          id: 3,
          title: 'Inside month',
          description: '',
          isCompleted: true,
          completedAt: DateTime(2026, 11, 1, 9),
        ),
        TaskModel(
          id: 4,
          title: 'Outside month',
          description: '',
          isCompleted: true,
          completedAt: DateTime(2026, 10, 31, 9),
        ),
      ];
      final common = {
        'courses': const <CourseModel>[],
        'tasks': tasks,
        'exams': const <ExamModel>[],
        'schedule': const <Map<String, dynamic>>[],
        'generatedAt': DateTime(2026, 11, 20, 18),
      };

      final weekly = service.generatePeriodReport(
        period: AcademicReportPeriod.weekly,
        courses: common['courses'] as List<CourseModel>,
        tasks: common['tasks'] as List<TaskModel>,
        exams: common['exams'] as List<ExamModel>,
        schedule: common['schedule'] as List<Map<String, dynamic>>,
        generatedAt: common['generatedAt'] as DateTime,
      );
      final monthly = service.generatePeriodReport(
        period: AcademicReportPeriod.monthly,
        courses: const [],
        tasks: tasks,
        exams: const [],
        schedule: const [],
        generatedAt: DateTime(2026, 11, 20, 18),
      );

      expect(weekly, contains('Inside week'));
      expect(weekly, isNot(contains('Outside week')));
      expect(monthly, contains('Inside month'));
      expect(monthly, isNot(contains('Outside month')));
    });
  });
}
