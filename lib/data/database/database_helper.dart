import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
// Use sqflite's platform factory on Android/iOS. FFI factories are
// selected explicitly only for desktop and Web.
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWeb;
import '../models/academic_term_model.dart';
import '../models/course_material_model.dart';
import '../models/course_model.dart';
import '../models/exam_model.dart';
import '../models/task_model.dart';

/// مساعد قاعدة البيانات المسؤول عن إنشاء قاعدة البيانات والتعامل
/// مع عمليات CRUD الخاصة بالمهام والمواد.
class DatabaseHelper {
  DatabaseHelper._();

  static bool _shouldUseNativeFactory() {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  static bool _initializeWebFactory() {
    databaseFactory = databaseFactoryFfiWeb;
    debugPrint('SQLite FFI web factory initialized once.');
    return true;
  }

  static bool _initializeNativeFactory() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    debugPrint('SQLite FFI native factory initialized once.');
    return true;
  }

  static final DatabaseHelper instance = DatabaseHelper._();
  static bool _webFactoryInitialized = false;
  static bool _nativeFactoryInitialized = false;

  static const String _databaseName = 'academic_os.db';
  static const int _databaseVersion = 12;
  static const String _materialsTable = 'course_materials';
  static const String _taskTable = 'tasks';
  static const String _courseTable = 'courses';
  static const String _examTable = 'exams';
  static const String scheduleTable = 'schedule';

  Database? _database;
  Future<Database>? _openingDatabase;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    final inFlight = _openingDatabase;
    if (inFlight != null) return inFlight;

    final openFuture = _initDatabase();
    _openingDatabase = openFuture;
    try {
      final db = await openFuture;
      _database = db;
      return db;
    } finally {
      if (identical(_openingDatabase, openFuture)) {
        _openingDatabase = null;
      }
    }
  }

  Future<Database> _initDatabase() async {
    try {
      if (kIsWeb && !_webFactoryInitialized) {
        databaseFactory = databaseFactoryFfiWeb;
        _webFactoryInitialized = true;
        debugPrint('[SQLite] Web database factory initialized.');
      } else if (!kIsWeb &&
          _shouldUseNativeFactory() &&
          !_nativeFactoryInitialized) {
        _initializeNativeFactory();
        _nativeFactoryInitialized = true;
      }

      final platform = kIsWeb ? 'web' : Platform.operatingSystem;
      debugPrint(
        '[SQLite] platform=$platform factory=${databaseFactory.runtimeType}',
      );

      final dbPath = await getDatabasesPath();
      debugPrint('[SQLite] databasesPath=$dbPath');

      if (!kIsWeb) {
        final directory = Directory(dbPath);
        await directory.create(recursive: true);

        // Verify the app-owned database directory is writable before opening
        // the real database. The probe is a temporary empty directory and
        // never touches the user's database or academic records.
        final writeProbe = await directory.createTemp(
          '.edunivora_sqlite_write_probe_',
        );
        await writeProbe.delete();
        debugPrint('[SQLite] database directory writable=true');
      }

      final path = join(dbPath, _databaseName);
      debugPrint('[SQLite] persistent database path=$path');

      // Never replace persistent storage with an in-memory database. A failed
      // open must be surfaced to startup so the user is not led to believe
      // that writes are durable when they can disappear on refresh.
      final db = await openDatabase(
        path,
        version: _databaseVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreateDatabase,
        onUpgrade: _onUpgradeDatabase,
        onOpen: _migrateLegacyMaterialFiles,
      );
      debugPrint(
        '[SQLite] persistent database opened; inMemory=${db.path == inMemoryDatabasePath}',
      );
      return db;
    } catch (error, stackTrace) {
      debugPrint(
        '[SQLite] initialization failed: ${error.runtimeType}: $error',
      );
      debugPrint('[SQLite] original stack trace:\n$stackTrace');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _migrateLegacyMaterialFiles(Database db) async {
    if (kIsWeb) return;

    final legacyRoot = Directory(
      join(Directory.systemTemp.path, 'academic_os_materials'),
    );
    if (!await legacyRoot.exists()) return;

    String canonicalRoot;
    try {
      canonicalRoot = await legacyRoot.resolveSymbolicLinks();
    } catch (error) {
      debugPrint('Legacy attachment migration skipped: $error');
      return;
    }

    final rows = await db.query(
      _materialsTable,
      columns: ['id', 'file_path', 'file_bytes'],
      where: 'file_bytes IS NULL',
    );
    for (final row in rows) {
      final id = row['id'];
      final storedPath = row['file_path'];
      if (id is! int || storedPath is! String || storedPath.trim().isEmpty) {
        continue;
      }

      try {
        final source = File(storedPath);
        if (!await source.exists()) continue;
        final canonicalFile = await source.resolveSymbolicLinks();
        if (!isWithin(canonicalRoot, canonicalFile) ||
            canonicalFile == canonicalRoot) {
          debugPrint(
            'Rejected legacy attachment outside owned temporary root: $id',
          );
          continue;
        }

        final bytes = await source.readAsBytes();
        if (bytes.isEmpty || bytes.length > 50 * 1024 * 1024) continue;
        final migrated = await db.update(
          _materialsTable,
          {'file_bytes': bytes, 'file_path': 'dbblob://legacy-$id'},
          where: 'id = ? AND file_bytes IS NULL',
          whereArgs: [id],
        );
        if (migrated == 1) {
          await source.delete();
        }
      } catch (error) {
        // Preserve the source file and legacy row on any failed migration.
        debugPrint('Legacy attachment $id could not be migrated: $error');
      }
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    // PRAGMA journal_mode = WAL returns a result row. On Android's native
    // SQLiteDatabase.execSQL (used by sqflite's execute()), any statement that
    // returns rows throws SQLiteException. Use rawQuery() and guard gracefully
    // so devices or storage modes that restrict WAL in onConfigure stay usable.
    try {
      await db.rawQuery('PRAGMA journal_mode = WAL');
    } catch (error) {
      debugPrint('SQLite WAL journal mode could not be enabled: $error');
    }
  }

  @visibleForTesting
  Future<void> configureDatabaseForTest(Database db) => _onConfigure(db);

  @visibleForTesting
  Future<void> upgradeDatabaseForTest(
    Database db,
    int oldVersion,
    int newVersion,
  ) => _onUpgradeDatabase(db, oldVersion, newVersion);

  Future<void> _ensureColumn(
    Database db,
    String tableName,
    String columnName,
    String columnDefinition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final exists = columns.any((column) => column['name'] == columnName);
    if (!exists) {
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN $columnName $columnDefinition',
      );
    }
  }

  Future<void> _onCreateDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_taskTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'other',
        due_date TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        course_id INTEGER,
        course_name TEXT,
        priority TEXT NOT NULL DEFAULT 'medium',
        recurrence TEXT NOT NULL DEFAULT 'once',
        start_date_time TEXT,
        end_date_time TEXT,
        notes TEXT NOT NULL DEFAULT '',
        reminder_enabled INTEGER NOT NULL DEFAULT 0,
        reminder_date TEXT,
        reminder_offset_minutes INTEGER NOT NULL DEFAULT 30
      )
    ''');

    await db.execute('''
      CREATE TABLE $_courseTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        instructor TEXT NOT NULL,
        code TEXT NOT NULL,
        credits INTEGER NOT NULL DEFAULT 0,
        semester TEXT NOT NULL DEFAULT '',
        notes TEXT,
        color_hex TEXT NOT NULL DEFAULT '#2196F3',
        lecture_reminder_enabled INTEGER NOT NULL DEFAULT 0,
        lecture_date TEXT,
        lecture_reminder_offset_minutes INTEGER NOT NULL DEFAULT 30,
        mid_grade REAL DEFAULT 0,
        practical_grade REAL DEFAULT 0,
        final_grade REAL DEFAULT 0,
        credit_hours INTEGER DEFAULT 3
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_course_id ON $_taskTable (course_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_reminder_enabled ON $_taskTable (reminder_enabled)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_courses_lecture_reminder_enabled ON $_courseTable (lecture_reminder_enabled)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_examTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_id INTEGER,
        title TEXT NOT NULL,
        exam_date TEXT NOT NULL,
        location TEXT,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $scheduleTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_id INTEGER,
        day_of_week TEXT,
        start_time TEXT,
        end_time TEXT,
        location TEXT,
        reminder_enabled INTEGER DEFAULT 1,
        reminder_offset_minutes INTEGER NOT NULL DEFAULT 15
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_materialsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_type TEXT NOT NULL,
        file_bytes BLOB,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS academic_terms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        CHECK (length(trim(name)) BETWEEN 1 AND 80),
        CHECK (start_date <= end_date)
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_academic_terms_name '
      'ON academic_terms(name COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_academic_terms_single_active '
      'ON academic_terms(is_active) WHERE is_active = 1',
    );
  }

  Future<void> _onUpgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _ensureColumn(
        db,
        _taskTable,
        'type',
        "TEXT NOT NULL DEFAULT 'other'",
      );
      await _ensureColumn(db, _taskTable, 'due_date', 'TEXT');
      await _ensureColumn(
        db,
        _taskTable,
        'is_completed',
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_courseTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          instructor TEXT NOT NULL,
          code TEXT NOT NULL,
          credits INTEGER NOT NULL DEFAULT 0,
          semester TEXT NOT NULL DEFAULT '',
          notes TEXT,
          color_hex TEXT NOT NULL DEFAULT '#2196F3'
        )
      ''');
    }
    if (oldVersion < 4) {
      await _ensureColumn(db, _taskTable, 'course_id', 'INTEGER');
      await _ensureColumn(db, _taskTable, 'course_name', 'TEXT');
    }
    if (oldVersion < 5) {
      await _ensureColumn(
        db,
        _taskTable,
        'reminder_enabled',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _ensureColumn(db, _taskTable, 'reminder_date', 'TEXT');
      await _ensureColumn(
        db,
        _taskTable,
        'reminder_offset_minutes',
        'INTEGER NOT NULL DEFAULT 30',
      );
      await _ensureColumn(
        db,
        _courseTable,
        'lecture_reminder_enabled',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _ensureColumn(db, _courseTable, 'lecture_date', 'TEXT');
      await _ensureColumn(
        db,
        _courseTable,
        'lecture_reminder_offset_minutes',
        'INTEGER NOT NULL DEFAULT 30',
      );
    }
    if (oldVersion < 6) {
      await _ensureColumn(
        db,
        _taskTable,
        'priority',
        "TEXT NOT NULL DEFAULT 'medium'",
      );
      await _ensureColumn(
        db,
        _taskTable,
        'recurrence',
        "TEXT NOT NULL DEFAULT 'once'",
      );
      await _ensureColumn(db, _taskTable, 'start_date_time', 'TEXT');
      await _ensureColumn(db, _taskTable, 'end_date_time', 'TEXT');
      await _ensureColumn(db, _taskTable, 'notes', "TEXT NOT NULL DEFAULT ''");
    }
    if (oldVersion < 7) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tasks_course_id ON $_taskTable (course_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tasks_reminder_enabled ON $_taskTable (reminder_enabled)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_courses_lecture_reminder_enabled ON $_courseTable (lecture_reminder_enabled)',
      );
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_examTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          course_id INTEGER,
          title TEXT NOT NULL,
          exam_date TEXT NOT NULL,
          location TEXT,
          notes TEXT
        )
      ''');
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $scheduleTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          course_id INTEGER,
          day_of_week TEXT,
          start_time TEXT,
          end_time TEXT,
          location TEXT,
          reminder_enabled INTEGER DEFAULT 1
        )
      ''');
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_materialsTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          course_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          file_path TEXT NOT NULL,
          file_type TEXT NOT NULL,
          created_at TEXT
        )
      ''');
    }
    if (oldVersion < 11) {
      await _ensureColumn(db, _materialsTable, 'file_bytes', 'BLOB');
    }
    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS academic_terms (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          start_date TEXT NOT NULL,
          end_date TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          CHECK (length(trim(name)) BETWEEN 1 AND 80),
          CHECK (start_date <= end_date)
        )
      ''');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_academic_terms_name '
        'ON academic_terms(name COLLATE NOCASE)',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_academic_terms_single_active '
        'ON academic_terms(is_active) WHERE is_active = 1',
      );
    }

    await _ensureColumn(
      db,
      scheduleTable,
      'reminder_offset_minutes',
      'INTEGER NOT NULL DEFAULT 15',
    );

    await _ensureColumn(db, _courseTable, 'mid_grade', 'REAL DEFAULT 0');
    await _ensureColumn(db, _courseTable, 'practical_grade', 'REAL DEFAULT 0');
    await _ensureColumn(db, _courseTable, 'final_grade', 'REAL DEFAULT 0');
    await _ensureColumn(db, _courseTable, 'credit_hours', 'INTEGER DEFAULT 3');
  }

  /// Replaces all student academic records as one atomic database operation.
  ///
  /// Every model is parsed before this method is called. If any delete or
  /// insert fails, SQLite rolls the whole transaction back and the previous
  /// academic data remains intact.
  Future<void> replaceAcademicData({
    required List<CourseModel> courses,
    required List<TaskModel> tasks,
    required List<ExamModel> exams,
    required List<Map<String, dynamic>> schedules,
    List<CourseMaterialModel>? materials,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // A legacy v1 backup has no material metadata. Preserve current
      // materials only when their course references remain valid.
      if (materials == null) {
        final currentMaterials = await txn.query(_materialsTable);
        final incomingCourseIds = courses
            .map((course) => course.id)
            .whereType<int>()
            .toSet();
        final hasOrphanedMaterial = currentMaterials.any((material) {
          final courseId = material['course_id'];
          return courseId is! int || !incomingCourseIds.contains(courseId);
        });
        if (hasOrphanedMaterial) {
          throw StateError(
            'This legacy backup omits course materials and would orphan '
            'existing attachments. Restore a v2 backup instead.',
          );
        }
      }

      if (materials != null &&
          materials.any((material) => material.fileBytes == null)) {
        final existingRows = await txn.query(
          _materialsTable,
          columns: ['file_bytes'],
        );
        final wouldDiscardStoredBytes = existingRows.any(
          (row) =>
              row['file_bytes'] is List<int> &&
              (row['file_bytes'] as List<int>).isNotEmpty,
        );
        if (wouldDiscardStoredBytes) {
          throw StateError(
            'This metadata-only backup does not contain attachment bytes and '
            'cannot replace the current workspace without losing stored files. '
            'Use a complete v3 backup.',
          );
        }
      }

      // Delete dependent records before their parent courses.
      if (materials != null) {
        await txn.delete(_materialsTable);
      }
      await txn.delete(scheduleTable);
      await txn.delete(_examTable);
      await txn.delete(_taskTable);
      await txn.delete(_courseTable);

      for (final course in courses) {
        await txn.insert(
          _courseTable,
          course.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final task in tasks) {
        await txn.insert(
          _taskTable,
          task.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final exam in exams) {
        await txn.insert(
          _examTable,
          exam.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final schedule in schedules) {
        await txn.insert(
          scheduleTable,
          schedule,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (materials != null) {
        for (final material in materials) {
          await txn.insert(
            _materialsTable,
            material.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getAllMaterials() async {
    final db = await database;
    return db.query(_materialsTable, orderBy: 'created_at DESC');
  }

  /// Returns all student-defined academic terms in chronological order.
  Future<List<AcademicTermModel>> getAcademicTerms() async {
    final db = await database;
    final rows = await db.query(
      'academic_terms',
      orderBy: 'start_date DESC, id DESC',
    );
    return rows.map(AcademicTermModel.fromMap).toList(growable: false);
  }

  Future<AcademicTermModel?> getActiveAcademicTerm() async {
    final db = await database;
    final rows = await db.query(
      'academic_terms',
      where: 'is_active = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AcademicTermModel.fromMap(rows.single);
  }

  Future<int> insertAcademicTerm(AcademicTermModel term) async {
    term.validate();
    final db = await database;
    return db.transaction((txn) async {
      if (term.isActive) {
        await txn.update('academic_terms', {'is_active': 0});
      }
      return txn.insert('academic_terms', term.toMap());
    });
  }

  Future<int> updateAcademicTerm(AcademicTermModel term) async {
    term.validate();
    final id = term.id;
    if (id == null) {
      throw ArgumentError('An academic term ID is required for updates.');
    }
    final db = await database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        'academic_terms',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isEmpty) {
        throw StateError('The academic term no longer exists.');
      }

      final previousName = existing.single['name'] as String;
      if (previousName != term.name.trim()) {
        // Course.semester is the existing relationship field. Keep that
        // relationship intact when a student renames a term.
        await txn.update(
          _courseTable,
          {'semester': term.name.trim()},
          where: 'semester = ?',
          whereArgs: [previousName],
        );
      }
      if (term.isActive) {
        await txn.update(
          'academic_terms',
          {'is_active': 0},
          where: 'id != ?',
          whereArgs: [id],
        );
      }
      return txn.update(
        'academic_terms',
        term.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> setActiveAcademicTerm(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('academic_terms', {'is_active': 0});
      final selected = await txn.update(
        'academic_terms',
        {'is_active': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (selected != 1) {
        throw StateError('The selected academic term does not exist.');
      }
    });
  }

  Future<int> deleteAcademicTerm(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'academic_terms',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return 0;

      final name = rows.single['name'] as String;
      final linkedCourses = await txn.query(
        _courseTable,
        columns: ['id'],
        where: 'semester = ?',
        whereArgs: [name],
        limit: 1,
      );
      if (linkedCourses.isNotEmpty) {
        throw StateError(
          'لا يمكن حذف هذا الفصل لأنه مرتبط بمقررات. انقل المقررات إلى فصل آخر أولاً.',
        );
      }
      return txn.delete('academic_terms', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> close() async {
    _openingDatabase = null;
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  Future<int> insertTask(TaskModel task) async {
    final db = await database;
    return await db.insert(
      _taskTable,
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TaskModel>> getTasks() async {
    final db = await database;
    final rows = await db.query(_taskTable, orderBy: 'id DESC');
    return rows.map(TaskModel.fromMap).toList();
  }

  Future<TaskModel?> getTaskById(int id) async {
    final db = await database;
    final rows = await db.query(_taskTable, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return TaskModel.fromMap(rows.first);
  }

  Future<int> updateTask(TaskModel task) async {
    if (task.id == null) {
      throw ArgumentError('Task id is required to update a task.');
    }
    final db = await database;
    return await db.update(
      _taskTable,
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete(_taskTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertCourse(CourseModel course) async {
    final db = await database;
    return await db.insert(
      _courseTable,
      course.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CourseModel>> getCourses() async {
    final db = await database;
    final rows = await db.query(_courseTable, orderBy: 'name ASC');
    return rows.map(CourseModel.fromMap).toList();
  }

  Future<CourseModel?> getCourseById(int id) async {
    final db = await database;
    final rows = await db.query(_courseTable, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return CourseModel.fromMap(rows.first);
  }

  Future<int> updateCourse(CourseModel course) async {
    if (course.id == null) {
      throw ArgumentError('Course id is required to update a course.');
    }
    final db = await database;
    return await db.update(
      _courseTable,
      course.toMap(),
      where: 'id = ?',
      whereArgs: [course.id],
    );
  }

  Future<int> deleteCourse(int id) async {
    final db = await database;
    return await db.delete(_courseTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateCourseGrades(
    int courseId, {
    double midGrade = 0,
    double practicalGrade = 0,
    double finalGrade = 0,
    int creditHours = 3,
  }) async {
    final db = await database;
    return await db.update(
      _courseTable,
      {
        'mid_grade': midGrade,
        'practical_grade': practicalGrade,
        'final_grade': finalGrade,
        'credit_hours': creditHours,
      },
      where: 'id = ?',
      whereArgs: [courseId],
    );
  }

  Future<int> insertExam(ExamModel exam) async {
    final db = await database;
    return await db.insert(
      _examTable,
      exam.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ExamModel>> getExams() async {
    final db = await database;
    final rows = await db.query(_examTable, orderBy: 'exam_date ASC');
    return rows.map(ExamModel.fromMap).toList();
  }

  Future<ExamModel?> getExamById(int id) async {
    final db = await database;
    final rows = await db.query(_examTable, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ExamModel.fromMap(rows.first);
  }

  Future<int> updateExam(ExamModel exam) async {
    if (exam.id == null) {
      throw ArgumentError('Exam id is required to update an exam.');
    }
    final db = await database;
    return await db.update(
      _examTable,
      exam.toMap(),
      where: 'id = ?',
      whereArgs: [exam.id],
    );
  }

  Future<int> deleteExam(int id) async {
    final db = await database;
    return await db.delete(_examTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertSchedule(Map<String, dynamic> schedule) async {
    final db = await database;
    return await db.insert(
      scheduleTable,
      schedule,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getSchedules() async {
    final db = await database;
    return await db.query(scheduleTable, orderBy: 'start_time ASC');
  }

  Future<int> updateSchedule(Map<String, dynamic> schedule) async {
    if (schedule['id'] == null) {
      throw ArgumentError('Schedule id is required to update a schedule item.');
    }
    final db = await database;
    return await db.update(
      scheduleTable,
      schedule,
      where: 'id = ?',
      whereArgs: [schedule['id']],
    );
  }

  Future<int> deleteSchedule(int id) async {
    final db = await database;
    return await db.delete(scheduleTable, where: 'id = ?', whereArgs: [id]);
  }

  // Course materials CRUD
  Future<int> insertMaterial(Map<String, dynamic> material) async {
    final db = await database;
    return await db.insert(
      _materialsTable,
      material,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getMaterialsByCourseId(
    int courseId,
  ) async {
    final db = await database;
    return await db.query(
      _materialsTable,
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> deleteMaterial(int id) async {
    final db = await database;
    return await db.delete(_materialsTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getMaterialById(int id) async {
    final db = await database;
    final rows = await db.query(
      _materialsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }
}
