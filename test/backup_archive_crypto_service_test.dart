import 'dart:convert';

import 'package:academic_os/data/services/backup_archive_crypto_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const crypto = BackupArchiveCryptoService();
  const password = 'Correct horse battery staple 2026';

  test('encrypts and decrypts a backup with the supplied password', () async {
    final plaintext = utf8.encode(
      '{"schema":"academic_os_backup_v3","courses":[{"id":1}]}',
    );

    final archive = await crypto.encrypt(
      plaintext: plaintext,
      password: password,
    );

    expect(utf8.decode(archive), contains('edunivora_encrypted_backup'));
    expect(utf8.decode(archive), isNot(contains('academic_os_backup_v3')));

    final restored = await crypto.decrypt(
      archive: archive,
      password: password,
    );

    expect(restored, orderedEquals(plaintext));
  });

  test('rejects an incorrect password and a modified archive', () async {
    final archive = await crypto.encrypt(
      plaintext: utf8.encode('private academic backup'),
      password: password,
    );

    await expectLater(
      crypto.decrypt(
        archive: archive,
        password: 'Incorrect horse battery staple 2026',
      ),
      throwsA(isA<FormatException>()),
    );

    final envelope = jsonDecode(utf8.decode(archive)) as Map<String, dynamic>;
    final cipher = Map<String, dynamic>.from(
      envelope['cipher'] as Map<String, dynamic>,
    );
    final payload = cipher['payload'] as String;
    cipher['payload'] =
        '${payload.startsWith('A') ? 'B' : 'A'}${payload.substring(1)}';
    envelope['cipher'] = cipher;
    final tampered = utf8.encode(jsonEncode(envelope));

    await expectLater(
      crypto.decrypt(archive: tampered, password: password),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects weak passwords and empty plaintext', () async {
    await expectLater(
      crypto.encrypt(plaintext: [1], password: 'short'),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      crypto.encrypt(plaintext: [], password: password),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects malformed and unsupported encrypted archive metadata', () async {
    await expectLater(
      crypto.decrypt(archive: utf8.encode('not-json'), password: password),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      crypto.decrypt(
        archive: utf8.encode('{"format":"other","version":1}'),
        password: password,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
