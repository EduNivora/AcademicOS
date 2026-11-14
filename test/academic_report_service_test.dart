import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/academic/academic_report_service.dart';
import 'package:academic_os/data/models/course_material_model.dart';
import 'package:academic_os/data/models/course_model.dart';
import 'package:academic_os/data/models/exam_model.dart';
import 'package:academic_os/data/models/task_model.dart';

void main() {
  group('AcademicReportService', () {
    test('builds a valid backup payload structure', () {
      final service = AcademicReportService();

      final payload = service.buildBackupPayload(
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
        tasks: [
          const TaskModel(
            id: 1,
            title: 'Finish homework',
            description: 'Submit assignment',
            dueDate: null,
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
        materials: [
          CourseMaterialModel(
            id: 7,
            courseId: 1,
            title: 'Lecture notes',
            filePath: '/student/files/notes.pdf',
            fileType: 'pdf',
          ).toMap(),
        ],
      );

      expect(payload['schema'], 'academic_os_backup_v2');
      expect(payload['courses'], isA<List>());
      expect(payload['tasks'], hasLength(1));
      expect(payload['exams'], hasLength(1));
      expect(payload['schedule'], hasLength(1));
      expect(payload['materials'], hasLength(1));
      expect(payload['materials'].first['title'], 'Lecture notes');
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

      expect(report, contains('Academic OS'));
      expect(report, contains('GPA Breakdown'));
      expect(report, contains('Math'));
    });
  });
}
