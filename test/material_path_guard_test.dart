import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:academic_os/core/security/material_path_guard.dart';

void main() {
  late Directory temporaryDirectory;
  late Directory ownedDirectory;
  late MaterialPathGuard guard;

  setUp(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('edunivora-material-guard-');
    ownedDirectory =
        Directory(p.join(temporaryDirectory.path, 'academic_os_materials'));
    await ownedDirectory.create(recursive: true);
    guard = MaterialPathGuard(rootDirectory: ownedDirectory);
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('resolves an existing file inside the owned materials directory',
      () async {
    final file = File(p.join(ownedDirectory.path, 'lecture.pdf'));
    await file.writeAsString('owned document');

    final resolved = await guard.resolveOwnedFilePath(file.path);

    expect(resolved, await file.resolveSymbolicLinks());
  });

  test('rejects an absolute path outside the owned materials directory',
      () async {
    final externalFile =
        File(p.join(temporaryDirectory.path, 'private-document.pdf'));
    await externalFile.writeAsString('not an app attachment');

    expect(await guard.resolveOwnedFilePath(externalFile.path), isNull);
  });

  test('rejects parent-directory traversal from the owned directory',
      () async {
    final externalFile =
        File(p.join(temporaryDirectory.path, 'outside.pdf'));
    await externalFile.writeAsString('outside');
    final traversalPath =
        p.join(ownedDirectory.path, '..', p.basename(externalFile.path));

    expect(await guard.resolveOwnedFilePath(traversalPath), isNull);
  });

  test('rejects a symlink inside the owned directory that escapes its root',
      () async {
    final externalFile =
        File(p.join(temporaryDirectory.path, 'external.pdf'));
    await externalFile.writeAsString('external');
    final escapeLink = Link(p.join(ownedDirectory.path, 'escape.pdf'));
    await escapeLink.create(externalFile.path);

    expect(await guard.resolveOwnedFilePath(escapeLink.path), isNull);
  });

  test('rejects missing and blank paths', () async {
    expect(await guard.resolveOwnedFilePath('   '), isNull);
    expect(
      await guard.resolveOwnedFilePath(
        p.join(ownedDirectory.path, 'missing.pdf'),
      ),
      isNull,
    );
  });
}
