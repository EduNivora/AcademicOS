import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:academic_os/data/database/database_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android native SQLite creates schema and persists a row after reopen',
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
      } finally {
        if (insertedId != null) {
          try {
            final db = await helper.database;
            await db.delete('tasks', where: 'id = ?', whereArgs: [insertedId]);
          } finally {
            await helper.close();
          }
        }
      }
    },
  );
}
