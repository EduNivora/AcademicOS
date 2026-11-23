import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:academic_os/data/database/database_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android native SQLite persists academic rows and attachment BLOBs after reopen',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      debugPrint(
        '[SQLite integration] Android=${Platform.operatingSystemVersion}',
      );
      debugPrint(
        '[SQLite integration] factory=${databaseFactory.runtimeType}',
      );

      final helper = DatabaseHelper.instance;
      await helper.close();

      int? insertedId;
      int? insertedCourseId;
      int? insertedMaterialId;
      final attachmentBytes = Uint8List.fromList([37, 80, 68, 70, 45, 49, 46, 52]);
      try {
        final firstOpen = await helper.database;
        expect(firstOpen.path, isNot(inMemoryDatabasePath));

        final tables = (await firstOpen.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        )).map((row) => row['name']).toSet();
        expect(
          tables,
          containsAll(['tasks', 'courses', 'exams', 'schedule', 'course_materials']),
        );

        final marker = 'android-sqlite-${DateTime.now().microsecondsSinceEpoch}';
        insertedId = await firstOpen.insert('tasks', {
          'title': marker,
          'description': 'Native Android SQLite persistence verification',
        });

        final beforeClose = await firstOpen.query(
          'tasks',
          where: 'id = ?',
          whereArgs: [insertedId],
        );
        expect(beforeClose, hasLength(1));
        expect(beforeClose.single['title'], marker);

        insertedCourseId = await firstOpen.insert('courses', {
          'name': 'Android attachment persistence',
          'instructor': 'Integration test',
          'code': 'ANDROID-BLOB-${DateTime.now().microsecondsSinceEpoch}',
          'credits': 3,
        });
        insertedMaterialId = await firstOpen.insert('course_materials', {
          'course_id': insertedCourseId,
          'title': 'android-persistence.pdf',
          'file_path': 'dbblob://android-persistence',
          'file_type': 'pdf',
          'file_bytes': attachmentBytes,
          'created_at': DateTime.now().toIso8601String(),
        });
        final materialBeforeClose = await firstOpen.query(
          'course_materials',
          where: 'id = ?',
          whereArgs: [insertedMaterialId],
        );
        expect(materialBeforeClose, hasLength(1));
        expect(
          List<int>.from(materialBeforeClose.single['file_bytes'] as Uint8List),
          orderedEquals(attachmentBytes),
        );

        await helper.close();

        final reopened = await helper.database;
        expect(reopened.path, isNot(inMemoryDatabasePath));
        final afterReopen = await reopened.query(
          'tasks',
          where: 'id = ?',
          whereArgs: [insertedId],
        );
        expect(afterReopen, hasLength(1));
        expect(afterReopen.single['title'], marker);
        expect(
          afterReopen.single['description'],
          'Native Android SQLite persistence verification',
        );
        final materialAfterReopen = await reopened.query(
          'course_materials',
          where: 'id = ?',
          whereArgs: [insertedMaterialId],
        );
        expect(materialAfterReopen, hasLength(1));
        expect(
          List<int>.from(materialAfterReopen.single['file_bytes'] as Uint8List),
          orderedEquals(attachmentBytes),
        );
      } finally {
        try {
          final db = await helper.database;
          if (insertedMaterialId != null) {
            await db.delete('course_materials', where: 'id = ?', whereArgs: [insertedMaterialId]);
          }
          if (insertedCourseId != null) {
            await db.delete('courses', where: 'id = ?', whereArgs: [insertedCourseId]);
          }
          if (insertedId != null) {
            await db.delete('tasks', where: 'id = ?', whereArgs: [insertedId]);
          }
        } finally {
          await helper.close();
        }
      }
    },
  );
}
