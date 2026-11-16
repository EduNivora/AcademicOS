import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/data/services/backup_archive_crypto_service.dart';

void main() {
  const service = BackupArchiveCryptoService();
  const password = 'Correct Horse Battery Staple 2026';
  final plaintext = Uint8List.fromList(
    utf8.encode('EduNivora private academic backup payload'),
  );

  late Uint8List archive;

  setUpAll(() async {
    archive = await service.encrypt(
      plaintext: plaintext,
      password: password,
    );
  });

  test('encrypts and decrypts payload with a wrapped data key', () async {
    final decoded = await service.decrypt(
      archive: archive,
      password: password,
    );
    expect(decoded, orderedEquals(plaintext));
  });

  test('encrypted envelope does not expose the plaintext payload', () {
    final archiveText = utf8.decode(archive);
    expect(archiveText, isNot(contains('private academic backup payload')));
    expect(archiveText, contains('argon2id'));
    expect(archiveText, contains('aes-256-gcm'));
  });

  test('rejects an incorrect password', () async {
    expect(
      () => service.decrypt(
        archive: archive,
        password: 'This Is A Different Password',
      ),
      throwsFormatException,
    );
  });

  test('rejects ciphertext tampering before returning plaintext', () async {
    final envelope = jsonDecode(utf8.decode(archive)) as Map<String, dynamic>;
    final cipher = Map<String, dynamic>.from(
      envelope['cipher'] as Map<String, dynamic>,
    );
    final payload = cipher['payload'] as String;
    final replacement = payload.startsWith('A') ? 'B' : 'A';
    cipher['payload'] = '$replacement${payload.substring(1)}';
    envelope['cipher'] = cipher;
    final tampered = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));

    expect(
      () => service.decrypt(archive: tampered, password: password),
      throwsFormatException,
    );
  });

  test('rejects passwords shorter than twelve characters', () async {
    expect(
      () => service.encrypt(plaintext: plaintext, password: 'short'),
      throwsFormatException,
    );
  });

  test('rejects unsupported archive versions', () async {
    final envelope = jsonDecode(utf8.decode(archive)) as Map<String, dynamic>;
    envelope['version'] = 999;
    final unsupported = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));

    expect(
      () => service.decrypt(archive: unsupported, password: password),
      throwsFormatException,
    );
  });
}
