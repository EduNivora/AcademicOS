import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:academic_os/core/security/secure_storage_service.dart';
import 'package:academic_os/data/database/database_helper.dart';
import 'package:academic_os/data/models/academic_term_model.dart';
import 'package:academic_os/data/models/course_model.dart';
import 'package:academic_os/data/models/exam_model.dart';
import 'package:academic_os/data/models/task_model.dart';

/// Mirrors Android's native SQLiteDatabase.execSQL behavior where any PRAGMA
/// returning a result row (like `PRAGMA journal_mode = WAL`) throws an
/// SQLiteException if executed via `execute()` instead of `rawQuery()`.
class _AndroidStrictPragmaDatabase implements Database {
  final List<String> executedSql = <String>[];
  final List<String> rawQueriedSql = <String>[];
  final bool failWalRawQuery;

  _AndroidStrictPragmaDatabase({this.failWalRawQuery = false});

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    if (sql.toUpperCase().contains('JOURNAL_MODE')) {
      throw StateError(
        'SQLiteException: Queries can be performed using SQLiteDatabase '
        'query or rawQuery methods only.',
      );
    }
    executedSql.add(sql);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    rawQueriedSql.add(sql);
    if (failWalRawQuery && sql.toUpperCase().contains('JOURNAL_MODE')) {
      throw StateError('WAL mode not supported on this storage mount');
    }
    return <Map<String, Object?>>[
      <String, Object?>{'journal_mode': 'wal'},
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> values = <String, String>{};
  PlatformException? readError;
  bool clearReadErrorAfterDelete = true;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (readError != null) {
      throw readError!;
    }
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
    if (clearReadErrorAfterDelete) {
      readError = null;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Android SQLite storage safety & lifecycle', () {
    test(
      'onConfigure uses rawQuery (never execute) for PRAGMA journal_mode = WAL',
      () async {
        final strictAndroidDb = _AndroidStrictPragmaDatabase();

        await DatabaseHelper.instance.configureDatabaseForTest(strictAndroidDb);

        expect(
          strictAndroidDb.executedSql,
          contains('PRAGMA foreign_keys = ON'),
        );
        expect(
          strictAndroidDb.rawQueriedSql,
          contains('PRAGMA journal_mode = WAL'),
        );
      },
    );

    test(
      'onConfigure degrades gracefully if WAL mode is unavailable on a device',
      () async {
        final restrictedDb = _AndroidStrictPragmaDatabase(
          failWalRawQuery: true,
        );

        await DatabaseHelper.instance.configureDatabaseForTest(restrictedDb);

        expect(restrictedDb.executedSql, contains('PRAGMA foreign_keys = ON'));
        expect(
          restrictedDb.rawQueriedSql,
          contains('PRAGMA journal_mode = WAL'),
        );
      },
    );

    test(
      'concurrent database opens share one healthy instance without race error',
      () async {
        final helper = DatabaseHelper.instance;
        await helper.close();

        final opened = await Future.wait<Database>(<Future<Database>>[
          helper.database,
          helper.database,
          helper.database,
        ]);

        expect(opened[0].isOpen, isTrue);
        expect(identical(opened[0], opened[1]), isTrue);
        expect(identical(opened[1], opened[2]), isTrue);
        await helper.close();
      },
    );

    test('CRUD records persist across database close and reopen', () async {
      final helper = DatabaseHelper.instance;
      await helper.close();

      const courseId = 995501;
      const taskId = 995502;
      const examId = 995503;
      const scheduleId = 995504;
      const termName = '__persistence_lifecycle_term__';
      int? termId;

      await helper.deleteSchedule(scheduleId);
      await helper.deleteExam(examId);
      await helper.deleteTask(taskId);
      await helper.deleteCourse(courseId);
      for (final term in await helper.getAcademicTerms()) {
        if (term.name == termName && term.id != null) {
          await helper.deleteAcademicTerm(term.id!);
        }
      }

      try {
        termId = await helper.insertAcademicTerm(
          AcademicTermModel(
            name: termName,
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 12, 31),
            isActive: false,
          ),
        );
        await helper.insertCourse(
          const CourseModel(
            id: courseId,
            name: 'Software Engineering',
            instructor: 'Dr. Test',
            code: 'SE-401',
            credits: 3,
            semester: termName,
          ),
        );
        await helper.insertTask(
          TaskModel(
            id: taskId,
            title: 'Submit architecture lab',
            description: 'Verify SQLite durability',
            courseId: courseId,
            courseName: 'Software Engineering',
            dueDate: DateTime(2026, 11, 20),
          ),
        );
        await helper.insertExam(
          ExamModel(
            id: examId,
            courseId: courseId,
            title: 'Midterm Exam',
            examDate: DateTime(2026, 11, 25),
            location: 'Hall A',
          ),
        );
        await helper.insertSchedule(<String, dynamic>{
          'id': scheduleId,
          'course_id': courseId,
          'day_of_week': 'الأحد',
          'start_time': '09:00',
          'end_time': '10:30',
          'location': 'Room 204',
          'reminder_enabled': 1,
          'reminder_offset_minutes': 15,
        });

        // Simulate full app restart by closing and reopening SQLite.
        await helper.close();

        final reloadedCourse = await helper.getCourseById(courseId);
        final reloadedTask = await helper.getTaskById(taskId);
        final reloadedExam = await helper.getExamById(examId);
        final reloadedSchedules = await helper.getSchedules();
        final reloadedTerms = await helper.getAcademicTerms();

        expect(reloadedCourse?.name, 'Software Engineering');
        expect(reloadedCourse?.semester, termName);
        expect(reloadedTask?.title, 'Submit architecture lab');
        expect(reloadedExam?.title, 'Midterm Exam');
        expect(reloadedSchedules.any((row) => row['id'] == scheduleId), isTrue);
        expect(reloadedTerms.any((term) => term.id == termId), isTrue);
      } finally {
        await helper.deleteSchedule(scheduleId);
        await helper.deleteExam(examId);
        await helper.deleteTask(taskId);
        await helper.deleteCourse(courseId);
        if (termId != null) {
          await helper.deleteAcademicTerm(termId);
        }
        await helper.close();
      }
    });

    test('course attachment bytes persist in SQLite across close and reopen', () async {
      final helper = DatabaseHelper.instance;
      await helper.close();

      const courseId = 995505;
      int? materialId;
      await helper.deleteCourse(courseId);

      try {
        await helper.insertCourse(
          const CourseModel(
            id: courseId,
            name: 'Attachment Persistence',
            instructor: 'Dr. Test',
            code: 'ATT-505',
            credits: 2,
            semester: '2026-Fall',
          ),
        );

        const expectedBytes = <int>[0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x37];
        materialId = await helper.insertMaterial(<String, Object?>{
          'course_id': courseId,
          'title': 'persistent-attachment.pdf',
          'file_path': 'dbblob://test-attachment',
          'file_type': 'pdf',
          'created_at': DateTime.utc(2026, 11, 23).toIso8601String(),
          'file_bytes': expectedBytes,
        });

        // Simulate an application restart; the bytes must live in persistent
        // SQLite storage, not in a temporary file or an in-memory cache.
        await helper.close();

        final restored = await helper.getMaterialById(materialId);
        expect(restored, isNotNull);
        expect(restored!['file_path'], 'dbblob://test-attachment');
        expect(
          List<int>.from(restored['file_bytes'] as List),
          expectedBytes,
        );
      } finally {
        if (materialId != null) await helper.deleteMaterial(materialId);
        await helper.deleteCourse(courseId);
        await helper.close();
      }
    });

    test(
      'upgrading legacy schema v1 directly to v12 preserves existing tasks and creates all tables',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'edunivora_v1_migration_',
        );
        final dbPath = p.join(tempDir.path, 'legacy_v1.db');
        Database? db;
        try {
          // Create a minimal v1 database containing only the initial tasks table.
          db = await databaseFactoryFfi.openDatabase(
            dbPath,
            options: OpenDatabaseOptions(
              version: 1,
              onCreate: (database, version) async {
                await database.execute('''
                  CREATE TABLE tasks (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    title TEXT NOT NULL,
                    description TEXT NOT NULL
                  )
                ''');
                await database.insert('tasks', <String, Object?>{
                  'title': 'Legacy v1 task',
                  'description': 'Must survive v1 -> v12 upgrade',
                });
              },
            ),
          );
          await db.close();

          // Reopen at v12 using DatabaseHelper's real configure & upgrade logic.
          db = await databaseFactoryFfi.openDatabase(
            dbPath,
            options: OpenDatabaseOptions(
              version: 12,
              onConfigure: DatabaseHelper.instance.configureDatabaseForTest,
              onUpgrade: DatabaseHelper.instance.upgradeDatabaseForTest,
            ),
          );

          final preservedTasks = await db.query('tasks');
          expect(preservedTasks, hasLength(1));
          expect(preservedTasks.single['title'], 'Legacy v1 task');
          expect(preservedTasks.single['priority'], 'medium');
          expect(preservedTasks.single['recurrence'], 'once');

          final tables = (await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'table'",
          )).map((row) => row['name'] as String).toSet();
          expect(
            tables,
            containsAll(<String>[
              'tasks',
              'courses',
              'exams',
              'schedule',
              'course_materials',
              'academic_terms',
            ]),
          );
        } finally {
          await db?.close();
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        }
      },
    );
  });

  group('SecureStorageService Android Keystore resilience', () {
    test(
      'recovers gracefully from Android BadPaddingException on database key',
      () async {
        final fakeStorage = _FakeSecureStorage()
          ..readError = PlatformException(
            code: 'Exception encountered',
            message: 'javax.crypto.BadPaddingException: Decryption failed',
          );

        final service = SecureStorageService(storage: fakeStorage);
        final regenerated = await service.getDatabasePassword();

        expect(regenerated, isNotEmpty);
        expect(await service.getDatabasePassword(), regenerated);
      },
    );

    test('propagates non-keystore secure storage failures', () async {
      final fakeStorage = _FakeSecureStorage()
        ..readError = PlatformException(
          code: 'STORAGE_UNAVAILABLE',
          message: 'Platform storage service unavailable',
        );

      final service = SecureStorageService(storage: fakeStorage);

      await expectLater(
        service.getDatabasePassword(),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
