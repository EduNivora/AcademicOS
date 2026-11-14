import 'package:flutter_test/flutter_test.dart';

import 'package:academic_os/data/database/database_helper.dart';
import 'package:academic_os/data/models/course_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Database schema', () {
    test('failed backup restore rolls back and preserves existing courses',
        () async {
      final helper = DatabaseHelper.instance;
      await helper.close();

      const existingCourseId = 987654;
      await helper.deleteCourse(existingCourseId);
      try {
        await helper.insertCourse(
          const CourseModel(
            id: existingCourseId,
            name: 'Existing course',
            instructor: 'Existing instructor',
            code: 'EXIST-1',
            credits: 3,
          ),
        );

        await expectLater(
          helper.replaceAcademicData(
            courses: const [],
            tasks: const [],
            exams: const [],
            schedules: const [
              {'column_that_does_not_exist': 'force transaction failure'},
            ],
          ),
          throwsA(isA<Exception>()),
        );

        final preservedCourse = await helper.getCourseById(existingCourseId);
        expect(preservedCourse, isNotNull);
        expect(preservedCourse!.name, 'Existing course');
      } finally {
        await helper.deleteCourse(existingCourseId);
        await helper.close();
      }
    });

    test(
        'initial database creation should not add duplicate course grade columns',
        () async {
      final helper = DatabaseHelper.instance;
      await helper.close();

      final db = await helper.database;
      final result = await db.rawQuery(
        "PRAGMA table_info(courses)",
      );

      final columnNames = result.map((row) => row['name'].toString()).toList();
      expect(columnNames, contains('mid_grade'));
      expect(columnNames, contains('practical_grade'));
      expect(columnNames, contains('final_grade'));
      expect(columnNames, contains('credit_hours'));

      final duplicates = <String, int>{};
      for (final column in columnNames) {
        duplicates[column] = (duplicates[column] ?? 0) + 1;
      }

      for (final entry in duplicates.entries) {
        expect(entry.value, 1,
            reason: 'Duplicate column detected: ${entry.key}');
      }

      await helper.close();
    });
  });
}
