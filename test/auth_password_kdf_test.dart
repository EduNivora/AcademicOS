import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:academic_os/core/security/auth_secure_storage_service.dart';
import 'package:academic_os/data/datasources/auth_local_data_source.dart';

class _FailingMigrationStorage extends AuthSecureStorageService {
  @override
  Future<void> savePasswordHash(String hash) async {
    throw StateError('simulated secure-storage write failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Argon2id password verifier', () {
    test('creates unique versioned verifiers and verifies passwords', () async {
      final service = AuthSecureStorageService();
      final first = await service.createPasswordVerifier('correct horse');
      final second = await service.createPasswordVerifier('correct horse');

      expect(first, isNot(second));
      expect(first.split(r'$'), hasLength(5));
      expect(first, startsWith('argon2id' + r'$'));
      expect(await service.verifyPasswordVerifier('correct horse', first), isTrue);
      expect(await service.verifyPasswordVerifier('wrong password', first), isFalse);
    });

    test('rejects unsupported or malformed verifier parameters', () async {
      final service = AuthSecureStorageService();
      expect(
        await service.verifyPasswordVerifier('password', 'argon2id' + r'$v=9$m=1,t=1,p=1$salt$hash'),
        isFalse,
      );
      expect(
        await service.verifyPasswordVerifier('password', 'not-a-verifier'),
        isFalse,
      );
    });

    test('upgrades a legacy SHA-256 verifier after successful login', () async {
      final service = AuthSecureStorageService();
      const username = 'legacy-student';
      const password = 'legacy-password';
      final salt = service.generateSalt();
      await service.saveAuthUsername(username);
      await service.savePasswordSalt(salt);
      await service.savePasswordHash(service.hashPassword(password, salt));
      await service.saveAuthSessionActive(false);

      final source = AuthLocalDataSourceImpl(service);
      expect(await source.verifyCredentials(username, password), isTrue);
      final upgraded = await service.getPasswordHash();
      expect(upgraded, startsWith('argon2id' + r'$'));
      expect(await service.isAuthSessionActive(), isTrue);
      expect(await source.verifyCredentials(username, 'wrong'), isFalse);
    });

    test('registration stores credentials without activating a session', () async {
      final service = AuthSecureStorageService();
      final source = AuthLocalDataSourceImpl(service);

      await source.persistLocalUser('new-student', 'strong-password');

      expect(await service.getPasswordHash(), startsWith('argon2id'));
      expect(await service.isAuthSessionActive(), isFalse);
      expect(
        await source.verifyCredentials('new-student', 'strong-password'),
        isTrue,
      );
      expect(await service.isAuthSessionActive(), isTrue);
    });

    test('local credentials remain usable after logout and require explicit login', () async {
      final service = AuthSecureStorageService();
      final source = AuthLocalDataSourceImpl(service);
      await source.persistLocalUser('student-after-logout', 'password-123');
      expect(await source.verifyCredentials('student-after-logout', 'password-123'), isTrue);

      await source.clearSession();
      expect(await service.getAuthUsername(), 'student-after-logout');
      expect(await service.getPasswordHash(), startsWith('argon2id'));
      expect(await service.isAuthSessionActive(), isFalse);
      expect(await service.isAuthLogoutRequired(), isTrue);

      expect(await source.isSessionActive(), isFalse);
      expect(await source.verifyCredentials('student-after-logout', 'wrong'), isFalse);
      expect(await service.isAuthSessionActive(), isFalse);
      expect(await source.verifyCredentials('student-after-logout', 'password-123'), isTrue);
      expect(await service.isAuthLogoutRequired(), isFalse);
    });

    test('does not activate a session if legacy migration persistence fails', () async {
      final service = AuthSecureStorageService();
      const username = 'legacy-student';
      const password = 'legacy-password';
      final salt = service.generateSalt();
      await service.saveAuthUsername(username);
      await service.savePasswordSalt(salt);
      await service.savePasswordHash(service.hashPassword(password, salt));
      await service.saveAuthSessionActive(false);

      final source = AuthLocalDataSourceImpl(_FailingMigrationStorage());
      await expectLater(
        source.verifyCredentials(username, password),
        throwsA(isA<StateError>()),
      );
      expect(await service.isAuthSessionActive(), isFalse);
      expect(await service.getPasswordHash(), service.hashPassword(password, salt));
    });
  });
}
