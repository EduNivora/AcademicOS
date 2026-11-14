import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/security/auth_secure_storage_service.dart';

void main() {
  group('Password verifier comparison', () {
    final service = AuthSecureStorageService();

    test('accepts identical verifier strings', () {
      expect(
        service.constantTimeEquals(
          'f'.padRight(64, 'a'),
          'f'.padRight(64, 'a'),
        ),
        isTrue,
      );
    });

    test('rejects a mismatch at the first character', () {
      expect(
        service.constantTimeEquals(
          'a'.padRight(64, '0'),
          'b'.padRight(64, '0'),
        ),
        isFalse,
      );
    });

    test('rejects a mismatch at the last character', () {
      expect(
        service.constantTimeEquals(
          '${'a' * 63}b',
          '${'a' * 63}c',
        ),
        isFalse,
      );
    });

    test('rejects values with different lengths', () {
      expect(service.constantTimeEquals('abc', 'abcd'), isFalse);
    });
  });
}
