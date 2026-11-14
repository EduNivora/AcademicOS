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

    test('locks PIN verification after five failed attempts', () async {
      await service.setPin('4826');
      for (var attempt = 0; attempt < 5; attempt++) {
        expect(await service.verifyPin('1111'), isFalse);
      }

      final remaining = await service.getPinLockoutRemaining();
      expect(remaining, isNotNull);
      expect(remaining!.inSeconds, greaterThan(0));
      expect(await service.verifyPin('4826'), isFalse);
    });

    test('persists lockout across service recreation and clears it on PIN reset', () async {
      await service.setPin('4826');
      for (var attempt = 0; attempt < 5; attempt++) {
        await service.verifyPin('1111');
      }

      final recreated = AppLockService(storage, LocalAuthService());
      expect(await recreated.getPinLockoutRemaining(), isNotNull);
      await recreated.setPin('7391');
      expect(await recreated.getPinLockoutRemaining(), isNull);
      expect(await recreated.verifyPin('7391'), isTrue);
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
