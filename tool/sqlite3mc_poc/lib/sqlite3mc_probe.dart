import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// These values are deliberately fixed test fixtures. They must never be reused
// as application credentials or copied into production key-management code.
const _correctTestKey = 'edunivora-sqlite3mc-proof-correct-key';
const _wrongTestKey = 'edunivora-sqlite3mc-proof-wrong-key';
const _plaintextCanary = 'EDUNIVORA_SQLITE3MC_PLAINTEXT_CANARY_9F0D';

Future<void> runSqlite3McProof({required String directoryPath}) async {
  final databasePath = p.join(directoryPath, 'sqlite3mc-proof.db');

  Future<Database> openWithKey(String key) {
    return databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        onConfigure: (database) async {
          await database.execute("PRAGMA key = '$key'");
        },
      ),
    );
  }

  final database = await openWithKey(_correctTestKey);
  try {
    await database.execute('''
      CREATE TABLE secret_payload (
        id INTEGER PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await database.insert('secret_payload', {'value': _plaintextCanary});
  } finally {
    await database.close();
  }

  final fileBytes = await File(databasePath).readAsBytes();
  if (fileBytes.length < 16) {
    throw StateError('Encrypted database file is unexpectedly short.');
  }

  final header = latin1.decode(fileBytes.take(16).toList(), allowInvalid: true);
  if (header == 'SQLite format 3\u0000') {
    throw StateError('Database still has the plaintext SQLite file header.');
  }

  final fileAsText = latin1.decode(fileBytes, allowInvalid: true);
  if (fileAsText.contains(_plaintextCanary)) {
    throw StateError('Database file exposes the plaintext canary.');
  }

  var wrongKeyRejected = false;
  try {
    final wrongDatabase = await openWithKey(_wrongTestKey);
    try {
      await wrongDatabase.rawQuery('SELECT name FROM sqlite_master');
    } finally {
      await wrongDatabase.close();
    }
  } on Object {
    wrongKeyRejected = true;
  }

  if (!wrongKeyRejected) {
    throw StateError(
      'The candidate engine accepted a wrong key when reading sqlite_master.',
    );
  }

  final reopened = await openWithKey(_correctTestKey);
  try {
    final rows = await reopened.query('secret_payload');
    if (rows.length != 1 || rows.single['value'] != _plaintextCanary) {
      throw StateError('Correct-key reopen did not recover the canary row.');
    }
  } finally {
    await reopened.close();
  }
}
