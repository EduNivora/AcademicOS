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

      int? insertedTaskId;
      int? insertedCourseId;
      int? insertedMaterialId;
      final attachmentBytes = Uint8List.fromList([
        0x25,
        0x50,
        0x44,
        0x46,
        0x2D,
        0x31,
        0x2E,
        0x34,
        0x0A,
      ]);

      try {
        final firstOpen = await helper.database;
        expect(firstOpen.path, isNot(inMemoryDatabasePath));

        final tables = (await firstOpen.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        )).map((row) => row['name']).toSet();
        expect(
          tables,
          containsAll([
            'tasks',
            'courses',
            'exams',
            'schedule',
            'course_materials',
          ]),
        );

        final marker =
            'android-sqlite-${DateTime.now().microsecondsSinceEpoch}';
        insertedTaskId = await firstOpen.insert('tasks', {
          'title': marker,
          'description': 'Native Android SQLite persistence verification',
        });
        insertedCourseId = await firstOpen.insert('courses', {
          'name': '$marker course',
          'instructor': 'SQLite integration',
          'code': 'ANDROID-${DateTime.now().microsecondsSinceEpoch}',
        });
        insertedMaterialId = await firstOpen.insert('course_materials', {
          'course_id': insertedCourseId,
          'title': 'android-persistence.pdf',
          'file_path': 'dbblob://$marker',
          'file_type': 'pdf',
          'file_bytes': attachmentBytes,
        });

        final taskBeforeClose = await firstOpen.query(
          'tasks',
          where: 'id = ?',
          whereArgs: [insertedTaskId],
        );
        expect(taskBeforeClose, hasLength(1));
        expect(taskBeforeClose.single['title'], marker);

        final materialBeforeClose = await firstOpen.query(
          'course_materials',
          where: 'id = ?',
          whereArgs: [insertedMaterialId],
        );
        expect(materialBeforeClose, hasLength(1));
        expect(
          List<int>.from(
            materialBeforeClose.single['file_bytes'] as Uint8List,
          ),
          orderedEquals(attachmentBytes),
        );

        await helper.close();

        final reopened = await helper.database;
        expect(reopened.path, isNot(inMemoryDatabasePath));

        final taskAfterReopen = await reopened.query(
          'tasks',
          where: 'id = ?',
          whereArgs: [insertedTaskId],
        );
        expect(taskAfterReopen, hasLength(1));
        expect(taskAfterReopen.single['title'], marker);
        expect(
          taskAfterReopen.single['description'],
          'Native Android SQLite persistence verification',
        );

        final materialAfterReopen = await reopened.query(
          'course_materials',
          where: 'id = ?',
          whereArgs: [insertedMaterialId],
        );
        expect(materialAfterReopen, hasLength(1));
        final persistedBytes =
            materialAfterReopen.single['file_bytes'] as Uint8List;
        expect(persistedBytes, isNotEmpty);
        expect(List<int>.from(persistedBytes), orderedEquals(attachmentBytes));
      } finally {
        try {
          final db = await helper.database;
          if (insertedMaterialId != null) {
            await db.delete(
              'course_materials',
              where: 'id = ?',
              whereArgs: [insertedMaterialId],
            );
          }
          if (insertedCourseId != null) {
            await db.delete(
              'courses',
              where: 'id = ?',
              whereArgs: [insertedCourseId],
            );
          }
          if (insertedTaskId != null) {
            await db.delete(
              'tasks',
              where: 'id = ?',
              whereArgs: [insertedTaskId],
            );
          }
        } finally {
          await helper.close();
        }
      }
    },
  );
}
