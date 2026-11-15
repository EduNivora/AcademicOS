import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqlite3mc_poc/sqlite3mc_probe.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  testWidgets('SQLite3MC encrypts and rejects a wrong key on Android',
      (tester) async {
    final directory =
        await Directory.systemTemp.createTemp('edunivora-sqlite3mc-android-');
    try {
      await runSqlite3McProof(directoryPath: directory.path);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
