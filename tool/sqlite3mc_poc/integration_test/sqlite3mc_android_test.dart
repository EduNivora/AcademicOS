import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sqlite3mc_poc/sqlite3mc_probe.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  testWidgets(
    'SQLite3MC FFI works alongside the Android sqflite and secure-storage plugins',
    (tester) async {
      final directory = await Directory.systemTemp.createTemp(
        'edunivora-sqlite3mc-android-',
      );
      const secureStorageKeyName = 'edunivora_sqlite3mc_poc_key';
      const secureStorage = FlutterSecureStorage();

      try {
        final generatedKey = base64UrlEncode(
          List<int>.generate(32, (_) => Random.secure().nextInt(256)),
        );
        await secureStorage.write(
          key: secureStorageKeyName,
          value: generatedKey,
        );
        final storedKey = await secureStorage.read(
          key: secureStorageKeyName,
        );
        expect(storedKey, generatedKey);

        // Exercise the same Android sqflite platform plugin currently used by
        // the production app, in the same process as the candidate FFI engine.
        final platformDatabasePath = p.join(
          directory.path,
          'platform-sqflite.db',
        );
        final platformDatabase = await sqflite.openDatabase(
          platformDatabasePath,
          version: 1,
          onCreate: (database, version) async {
            await database.execute(
              'CREATE TABLE plugin_probe (id INTEGER PRIMARY KEY, value TEXT NOT NULL)',
            );
          },
        );
        try {
          await platformDatabase.insert('plugin_probe', {'value': 'plugin-ok'});
          final rows = await platformDatabase.query('plugin_probe');
          expect(rows.single['value'], 'plugin-ok');
        } finally {
          await platformDatabase.close();
        }

        // Feed the value retrieved from Android secure storage into the FFI
        // SQLite3MC proof. The probe still checks ciphertext and wrong-key
        // rejection at sqlite_master before accepting the correct-key reopen.
        await runSqlite3McProof(
          directoryPath: directory.path,
          correctKey: storedKey!,
        );

        // Reopen the platform sqflite database after the FFI engine has been
        // used, proving the two native SQLite paths remain operational.
        final reopenedPlatformDatabase = await sqflite.openDatabase(
          platformDatabasePath,
        );
        try {
          final rows = await reopenedPlatformDatabase.query('plugin_probe');
          expect(rows.single['value'], 'plugin-ok');
        } finally {
          await reopenedPlatformDatabase.close();
        }
      } finally {
        await secureStorage.delete(key: secureStorageKeyName);
        await directory.delete(recursive: true);
      }
    },
  );
}