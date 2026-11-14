import 'auth_secure_storage_service.dart';
import 'local_auth_service.dart';

class AppLockService {
  final AuthSecureStorageService _secureStorageService;
  final LocalAuthService _localAuthService;

  AppLockService(this._secureStorageService, this._localAuthService);

  Future<bool> isPinSet() async {
    final pinHash = await _secureStorageService.getAppLockPinHash();
    return pinHash != null && pinHash.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final verifier = await _secureStorageService.createPasswordVerifier(pin);
    await _secureStorageService.saveAppLockPinHash(verifier);
    await _secureStorageService.resetAppLockPinAttempts();
  }

  Future<Duration?> getPinLockoutRemaining() {
    return _secureStorageService.getAppLockPinLockoutRemaining();
  }

  Future<bool> verifyPin(String pin) async {
    final lockout = await getPinLockoutRemaining();
    if (lockout != null && lockout > Duration.zero) return false;

    final storedHash = await _secureStorageService.getAppLockPinHash();
    if (storedHash == null || storedHash.isEmpty) return false;

    var verified = false;
    if (storedHash.startsWith('argon2id' + r'

  Future<void> removePin() async {
    await _secureStorageService.deleteAppLockPin();
    await _secureStorageService.saveAppLockBiometricEnabled(false);
  }

  Future<bool> isBiometricAvailable() {
    return _localAuthService.isBiometricAvailable();
  }

  Future<bool> authenticateBiometric() {
    return _localAuthService.authenticate();
  }

  Future<void> updateLastActive() async {
    await _secureStorageService.saveAppLockLastActiveAt(DateTime.now());
  }

  Future<DateTime?> getLastActiveAt() async {
    final raw = await _secureStorageService.getAppLockLastActiveAt();
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<bool> shouldLockApp() async {
    if (!await isPinSet()) {
      return false;
    }
    final lastActive = await getLastActiveAt();
    if (lastActive == null) {
      return true;
    }
    final timeoutMinutes = await getLockTimeout();
    final elapsed = DateTime.now().difference(lastActive);
    return elapsed.inMinutes >= timeoutMinutes;
  }

  Future<void> enableBiometric(bool enabled) async {
    await _secureStorageService.saveAppLockBiometricEnabled(enabled);
  }

  Future<bool> isBiometricEnabled() async {
    return _secureStorageService.isAppLockBiometricEnabled();
  }

  Future<int> getLockTimeout() {
    return _secureStorageService.getAppLockTimeout();
  }

  Future<void> setLockTimeout(int minutes) {
    return _secureStorageService.saveAppLockTimeout(minutes);
  }
}
)) {
      verified = await _secureStorageService.verifyPasswordVerifier(
        pin,
        storedHash,
      );
    } else {
      final legacySalt = await _secureStorageService.getAppLockPinSalt();
      if (legacySalt != null) {
        final legacyHash =
            _secureStorageService.hashPassword(pin, legacySalt);
        verified = _secureStorageService.constantTimeEquals(
          legacyHash,
          storedHash,
        );
        if (verified) {
          // Upgrade the legacy PIN verifier before granting access.
          final upgraded =
              await _secureStorageService.createPasswordVerifier(pin);
          await _secureStorageService.saveAppLockPinHash(upgraded);
        }
      }
    }

    if (verified) {
      await _secureStorageService.resetAppLockPinAttempts();
      return true;
    }

    await _secureStorageService.recordFailedAppLockPinAttempt();
    return false;
  }

  Future<void> removePin() async {
    await _secureStorageService.deleteAppLockPin();
    await _secureStorageService.saveAppLockBiometricEnabled(false);
  }

  Future<bool> isBiometricAvailable() {
    return _localAuthService.isBiometricAvailable();
  }

  Future<bool> authenticateBiometric() {
    return _localAuthService.authenticate();
  }

  Future<void> updateLastActive() async {
    await _secureStorageService.saveAppLockLastActiveAt(DateTime.now());
  }

  Future<DateTime?> getLastActiveAt() async {
    final raw = await _secureStorageService.getAppLockLastActiveAt();
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<bool> shouldLockApp() async {
    if (!await isPinSet()) {
      return false;
    }
    final lastActive = await getLastActiveAt();
    if (lastActive == null) {
      return true;
    }
    final timeoutMinutes = await getLockTimeout();
    final elapsed = DateTime.now().difference(lastActive);
    return elapsed.inMinutes >= timeoutMinutes;
  }

  Future<void> enableBiometric(bool enabled) async {
    await _secureStorageService.saveAppLockBiometricEnabled(enabled);
  }

  Future<bool> isBiometricEnabled() async {
    return _secureStorageService.isAppLockBiometricEnabled();
  }

  Future<int> getLockTimeout() {
    return _secureStorageService.getAppLockTimeout();
  }

  Future<void> setLockTimeout(int minutes) {
    return _secureStorageService.saveAppLockTimeout(minutes);
  }
}
