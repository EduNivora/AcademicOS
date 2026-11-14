import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:academic_os/core/security/app_lock_service.dart';
import 'package:academic_os/core/security/auth_secure_storage_service.dart';
import 'package:academic_os/core/security/local_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLockService PIN verification', () {
    late AuthSecureStorageService storage;
    late AppLockService service;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      storage = AuthSecureStorageService();
      service = AppLockService(storage, LocalAuthService());
    });

    test('accepts the configured PIN', () async {
      await service.setPin('4826');
      expect(await service.verifyPin('4826'), isTrue);
    });

    test('rejects an incorrect PIN', () async {
      await service.setPin('4826');
      expect(await service.verifyPin('1111'), isFalse);
    });

    test('stores new PINs as Argon2id verifiers', () async {
      await service.setPin('4826');
      final hash = await storage.getAppLockPinHash();
      expect(hash, startsWith('argon2id'));
    });

    test('upgrades legacy SHA-256 PINs after successful verification', () async {
      const pin = '4826';
      final salt = storage.generateSalt();
      await storage.saveAppLockPinSalt(salt);
      await storage.saveAppLockPinHash(storage.hashPassword(pin, salt));

      expect(await service.verifyPin(pin), isTrue);
      expect(await storage.getAppLockPinHash(), startsWith('argon2id'));
    });
  });
}
