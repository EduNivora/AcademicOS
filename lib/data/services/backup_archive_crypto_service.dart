import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Password-protects a backup using a wrapped random data-encryption key.
class BackupArchiveCryptoService {
  const BackupArchiveCryptoService();

  static const int formatVersion = 1;
  static const int maxPlaintextBytes = 50 * 1024 * 1024;
  static const int minimumPasswordLength = 12;

  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _keyLength = 32;
  static const int _tagLength = 16;
  static const int _argonMemoryKiB = 19456;
  static const int _argonIterations = 2;
  static const int _argonParallelism = 1;
  static const String _format = 'edunivora_encrypted_backup';

  static final List<int> _wrapAad =
      utf8.encode('EduNivora|encrypted-backup|v1|wrapped-key');
  static final List<int> _payloadAad =
      utf8.encode('EduNivora|encrypted-backup|v1|payload');

  static final AesGcm _aesGcm = AesGcm.with256bits();

  Future<Uint8List> encrypt({
    required List<int> plaintext,
    required String password,
  }) async {
    _validatePassword(password);
    if (plaintext.isEmpty || plaintext.length > maxPlaintextBytes) {
      throw const FormatException(
        'Backup payload is empty or exceeds the 50 MB plaintext limit.',
      );
    }

    final random = Random.secure();
    final salt = _randomBytes(random, _saltLength);
    final wrappingNonce = _randomBytes(random, _nonceLength);
    final payloadNonce = _randomBytes(random, _nonceLength);
    final kdf = _newKdf();
    final wrappingKey = await kdf.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final dataKey = await _aesGcm.newSecretKey();
    final dataKeyBytes = await dataKey.extractBytes();

    final wrappedKey = await _aesGcm.encrypt(
      dataKeyBytes,
      secretKey: wrappingKey,
      nonce: wrappingNonce,
      aad: _wrapAad,
    );
    final encryptedPayload = await _aesGcm.encrypt(
      plaintext,
      secretKey: dataKey,
      nonce: payloadNonce,
      aad: _payloadAad,
    );

    final envelope = <String, Object>{
      'format': _format,
      'version': formatVersion,
      'kdf': <String, Object>{
        'algorithm': 'argon2id',
        'memory_kib': _argonMemoryKiB,
        'iterations': _argonIterations,
        'parallelism': _argonParallelism,
        'hash_length': _keyLength,
        'salt': base64.encode(salt),
      },
      'cipher': <String, Object>{
        'algorithm': 'aes-256-gcm',
        'wrapped_key': base64.encode(wrappedKey.cipherText),
        'wrapped_key_nonce': base64.encode(wrappedKey.nonce),
        'wrapped_key_tag': base64.encode(wrappedKey.mac.bytes),
        'payload': base64.encode(encryptedPayload.cipherText),
        'payload_nonce': base64.encode(encryptedPayload.nonce),
        'payload_tag': base64.encode(encryptedPayload.mac.bytes),
      },
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  Future<Uint8List> decrypt({
    required List<int> archive,
    required String password,
  }) async {
    _validatePassword(password);
    if (archive.isEmpty || archive.length > 80 * 1024 * 1024) {
      throw const FormatException('Encrypted backup size is invalid.');
    }

    final Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(utf8.decode(archive));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Encrypted backup envelope must be an object.');
      }
      envelope = decoded;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Encrypted backup envelope is malformed.');
    }

    if (envelope['format'] != _format || envelope['version'] != formatVersion) {
      throw const FormatException('Unsupported encrypted backup format.');
    }
    final kdfMetadata = envelope['kdf'];
    final cipherMetadata = envelope['cipher'];
    if (kdfMetadata is! Map<String, dynamic> ||
        cipherMetadata is! Map<String, dynamic>) {
      throw const FormatException('Encrypted backup metadata is incomplete.');
    }
    if (kdfMetadata['algorithm'] != 'argon2id' ||
        kdfMetadata['memory_kib'] != _argonMemoryKiB ||
        kdfMetadata['iterations'] != _argonIterations ||
        kdfMetadata['parallelism'] != _argonParallelism ||
        kdfMetadata['hash_length'] != _keyLength ||
        cipherMetadata['algorithm'] != 'aes-256-gcm') {
      throw const FormatException(
        'Encrypted backup algorithms or parameters are unsupported.',
      );
    }

    final salt = _decodeBase64(kdfMetadata['salt'], 'salt');
    final wrappedKeyBytes =
        _decodeBase64(cipherMetadata['wrapped_key'], 'wrapped key');
    final wrappedKeyNonce =
        _decodeBase64(cipherMetadata['wrapped_key_nonce'], 'wrapped key nonce');
    final wrappedKeyTag =
        _decodeBase64(cipherMetadata['wrapped_key_tag'], 'wrapped key tag');
    final payloadBytes = _decodeBase64(cipherMetadata['payload'], 'payload');
    final payloadNonce =
        _decodeBase64(cipherMetadata['payload_nonce'], 'payload nonce');
    final payloadTag =
        _decodeBase64(cipherMetadata['payload_tag'], 'payload tag');

    if (salt.length != _saltLength ||
        wrappedKeyBytes.length != _keyLength ||
        wrappedKeyNonce.length != _nonceLength ||
        wrappedKeyTag.length != _tagLength ||
        payloadBytes.isEmpty ||
        payloadBytes.length > maxPlaintextBytes ||
        payloadNonce.length != _nonceLength ||
        payloadTag.length != _tagLength) {
      throw const FormatException(
        'Encrypted backup contains invalid field lengths.',
      );
    }

    final wrappingKey = await _newKdf().deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    try {
      final dataKeyBytes = await _aesGcm.decrypt(
        SecretBox(
          wrappedKeyBytes,
          nonce: wrappedKeyNonce,
          mac: Mac(wrappedKeyTag),
        ),
        secretKey: wrappingKey,
        aad: _wrapAad,
      );
      if (dataKeyBytes.length != _keyLength) {
        throw const FormatException('Wrapped backup key has an invalid length.');
      }
      return Uint8List.fromList(
        await _aesGcm.decrypt(
          SecretBox(
            payloadBytes,
            nonce: payloadNonce,
            mac: Mac(payloadTag),
          ),
          secretKey: SecretKey(dataKeyBytes),
          aad: _payloadAad,
        ),
      );
    } catch (_) {
      throw const FormatException(
        'Backup password is incorrect or the encrypted archive was modified.',
      );
    }
  }

  Argon2id _newKdf() => Argon2id(
        memory: _argonMemoryKiB,
        parallelism: _argonParallelism,
        iterations: _argonIterations,
        hashLength: _keyLength,
      );

  void _validatePassword(String password) {
    if (password.length < minimumPasswordLength) {
      throw const FormatException(
        'Backup password must contain at least 12 characters.',
      );
    }
  }

  List<int> _randomBytes(Random random, int length) =>
      List<int>.generate(length, (_) => random.nextInt(256), growable: false);

  List<int> _decodeBase64(Object? value, String field) {
    if (value is! String || value.isEmpty) {
      throw FormatException('Encrypted backup $field is missing.');
    }
    try {
      return base64.decode(value);
    } on FormatException {
      throw FormatException('Encrypted backup $field is not valid base64.');
    }
  }
}
