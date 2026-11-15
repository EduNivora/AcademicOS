import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:academic_os/data/database/database_helper.dart';
import 'package:academic_os/data/models/course_material_model.dart';
import 'package:academic_os/data/models/course_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Database schema', () {
    test('failed backup restore rolls back and preserves existing data',
        () async {
      final helper = DatabaseHelper.instance;
      await helper.close();

      const existingCourseId = 987654;
      const existingMaterialId = 987659;
      await helper.deleteMaterial(existingMaterialId);
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
        await helper.insertMaterial({
          'id': existingMaterialId,
          'course_id': existingCourseId,
          'title': 'Existing notes',
          'file_path': '/tmp/existing-notes.pdf',
          'file_type': 'pdf',
        });

        await expectLater(
          helper.replaceAcademicData(
            courses: const [],
            tasks: const [],
            exams: const [],
            schedules: const [
              {'column_that_does_not_exist': 'force transaction failure'},
            ],
            materials: const [],
          ),
          throwsA(isA<Exception>()),
        );

        final preservedCourse = await helper.getCourseById(existingCourseId);
        expect(preservedCourse, isNotNull);
        expect(preservedCourse!.name, 'Existing course');
        expect(
          (await helper.getAllMaterials()).any(
            (material) =>
                material['id'] == existingMaterialId &&
                material['title'] == 'Existing notes',
          ),
          isTrue,
        );
      } finally {
        await helper.deleteMaterial(existingMaterialId);
        await helper.deleteCourse(existingCourseId);
        await helper.close();
      }
    });

    test('successful backup restore replaces academic records completely',
        () async {
      final helper = DatabaseHelper.instance;
      await helper.close();

      const oldCourseId = 987653;
      const restoredCourseId = 987655;
      const restoredMaterialId = 987656;
      await helper.deleteCourse(oldCourseId);
      await helper.deleteCourse(restoredCourseId);
      await helper.deleteMaterial(restoredMaterialId);

      try {
        await helper.insertCourse(
          const CourseModel(
            id: oldCourseId,
            name: 'Old course',
            instructor: 'Old instructor',
            code: 'OLD-1',
            credits: 3,
          ),
        );

        await helper.replaceAcademicData(
          courses: const [
            CourseModel(
              id: restoredCourseId,
              name: 'Restored course',
              instructor: 'New instructor',
              code: 'NEW-1',
              credits: 4,
            ),
          ],
          tasks: const [],
          exams: const [],
          schedules: const [],
          materials: [
            CourseMaterialModel(
              id: restoredMaterialId,
              courseId: restoredCourseId,
              title: 'Restored notes',
              filePath: 'dbblob://restored-notes',
              fileType: 'pdf',
              fileBytes: Uint8List.fromList([37, 80, 68, 70, 45, 49]),
            ),
          ],
        );

        expect(await helper.getCourseById(oldCourseId), isNull);
        expect(
          (await helper.getCourseById(restoredCourseId))?.name,
          'Restored course',
        );
        final restoredMaterials = await helper.getAllMaterials();
        expect(
          restoredMaterials.any(
            (material) => material['id'] == restoredMaterialId &&
                material['title'] == 'Restored notes',
          ),
          isTrue,
        );
      } finally {
        await helper.deleteMaterial(restoredMaterialId);
        await helper.deleteCourse(oldCourseId);
        await helper.deleteCourse(restoredCourseId);
        await helper.close();
      }
    });

    test('legacy restore refuses to orphan existing course materials',
        () async {
      final helper = DatabaseHelper.instance;
      await helper.close();

      const courseId = 987657;
      const materialId = 987658;
      await helper.deleteMaterial(materialId);
      await helper.deleteCourse(courseId);

      try {
        await helper.insertCourse(
          const CourseModel(
            id: courseId,
            name: 'Course with attachment',
            instructor: 'Instructor',
            code: 'MAT-1',
            credits: 3,
          ),
        );
        await helper.insertMaterial({
          'id': materialId,
          'course_id': courseId,
          'title': 'Existing attachment',
          'file_path': '/tmp/existing.pdf',
          'file_type': 'pdf',
        });

        await expectLater(
          helper.replaceAcademicData(
            courses: const [],
            tasks: const [],
            exams: const [],
            schedules: const [],
          ),
          throwsA(isA<StateError>()),
        );

        expect(await helper.getCourseById(courseId), isNotNull);
        expect(
          (await helper.getAllMaterials())
              .any((material) => material['id'] == materialId),
          isTrue,
        );
      } finally {
        await helper.deleteMaterial(materialId);
        await helper.deleteCourse(courseId);
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

    test('course material attachment bytes persist in SQLite', () async {
      final helper = DatabaseHelper.instance;
      await helper.close();
      const courseId = 987661;
      const materialId = 987662;
      await helper.deleteMaterial(materialId);
      await helper.deleteCourse(courseId);
      final bytes = Uint8List.fromList([37, 80, 68, 70, 45, 49, 46, 52]);
      try {
        await helper.insertCourse(
          const CourseModel(
            id: courseId,
            name: 'Attachment persistence',
            instructor: 'Instructor',
            code: 'ATT-1',
            credits: 3,
          ),
        );
        await helper.insertMaterial({
          'id': materialId,
          'course_id': courseId,
          'title': 'sample.pdf',
          'file_path': 'dbblob://sample',
          'file_type': 'pdf',
          'file_bytes': bytes,
        });
        final row = await helper.getMaterialById(materialId);
        expect(row, isNotNull);
        expect(row!['file_bytes'], isA<Uint8List>());
        expect(List<int>.from(row['file_bytes'] as Uint8List), orderedEquals(bytes));
        await helper.deleteMaterial(materialId);
        expect(await helper.getMaterialById(materialId), isNull);
      } finally {
        await helper.deleteMaterial(materialId);
        await helper.deleteCourse(courseId);
        await helper.close();
      }
    });


    test('metadata-only backup cannot discard existing attachment bytes', () async {
      final helper = DatabaseHelper.instance;
      await helper.close();
      const courseId = 987663;
      const materialId = 987664;
      await helper.deleteMaterial(materialId);
      await helper.deleteCourse(courseId);
      final bytes = Uint8List.fromList([37, 80, 68, 70]);
      try {
        await helper.insertCourse(
          const CourseModel(
            id: courseId,
            name: 'Protected attachment',
            instructor: 'Instructor',
            code: 'SAFE-1',
            credits: 3,
          ),
        );
        await helper.insertMaterial({
          'id': materialId,
          'course_id': courseId,
          'title': 'protected.pdf',
          'file_path': 'dbblob://protected',
          'file_type': 'pdf',
          'file_bytes': bytes,
        });

        await expectLater(
          helper.replaceAcademicData(
            courses: const [
              CourseModel(
                id: courseId,
                name: 'Protected attachment',
                instructor: 'Instructor',
                code: 'SAFE-1',
                credits: 3,
              ),
            ],
            tasks: const [],
            exams: const [],
            schedules: const [],
            materials: [
              CourseMaterialModel(
                id: materialId,
                courseId: courseId,
                title: 'protected.pdf',
                filePath: '/legacy/metadata-only.pdf',
                fileType: 'pdf',
              ),
            ],
          ),
          throwsA(isA<StateError>()),
        );

        final row = await helper.getMaterialById(materialId);
        expect(List<int>.from(row?['file_bytes'] as Uint8List), orderedEquals(bytes));
      } finally {
        await helper.deleteMaterial(materialId);
        await helper.deleteCourse(courseId);
        await helper.close();
      }
    });

}
