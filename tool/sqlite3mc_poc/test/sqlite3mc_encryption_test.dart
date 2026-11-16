import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3mc_poc/sqlite3mc_probe.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('encrypts pages, rejects a wrong key, and reopens with the right key',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('edunivora-sqlite3mc-host-');
    try {
      await runSqlite3McProof(directoryPath: directory.path);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
