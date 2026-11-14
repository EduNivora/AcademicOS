import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:academic_os/core/security/app_lock_service.dart';
import 'package:academic_os/core/security/auth_secure_storage_service.dart';
import 'package:academic_os/core/security/local_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('AppLockService PIN verification', () {
    late AppLockService service;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      service = AppLockService(
        AuthSecureStorageService(),
        LocalAuthService(),
      );
    });

    test('accepts the configured PIN', () async {
      await service.setPin('4826');
      expect(await service.verifyPin('4826'), isTrue);
    });

    test('rejects an incorrect PIN', () async {
      await service.setPin('4826');
      expect(await service.verifyPin('1111'), isFalse);
    });
  });
}
