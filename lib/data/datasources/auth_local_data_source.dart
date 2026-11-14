import '../../core/security/auth_secure_storage_service.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthLocalDataSource {
  Future<bool> verifyCredentials(String username, String password);
  Future<void> persistLocalUser(
    String username,
    String password, {
    String? email,
    String? displayName,
  });
  Future<bool> isSessionActive();
  Future<UserEntity?> getCachedUser();
  Future<void> clearSession();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final AuthSecureStorageService _secureStorageService;

  AuthLocalDataSourceImpl(this._secureStorageService);

  @override
  Future<bool> verifyCredentials(String username, String password) async {
    final storedUsername = await _secureStorageService.getAuthUsername();
    final storedHash = await _secureStorageService.getPasswordHash();
    if (storedUsername == null || storedHash == null ||
        storedUsername != username) {
      return false;
    }

    var success = false;
    if (storedHash.startsWith('argon2id' + r'$')) {
      success = await _secureStorageService.verifyPasswordVerifier(
        password,
        storedHash,
      );
    } else {
      final legacySalt = await _secureStorageService.getPasswordSalt();
      if (legacySalt == null) return false;
      final legacyHash =
          _secureStorageService.hashPassword(password, legacySalt);
      success = _secureStorageService.constantTimeEquals(
        legacyHash,
        storedHash,
      );
      if (success) {
        // Upgrade before activating the session. If persistence fails, the
        // legacy verifier remains stored and no authenticated session starts.
        final upgraded =
            await _secureStorageService.createPasswordVerifier(password);
        await _secureStorageService.savePasswordHash(upgraded);
      }
    }

    if (success) {
      await _secureStorageService.saveAuthSessionActive(true);
    }
    return success;
  }

  @override
  Future<void> persistLocalUser(
    String username,
    String password, {
    String? email,
    String? displayName,
  }) async {
    final verifier = await _secureStorageService.createPasswordVerifier(password);
    // Close any existing session before changing identity credentials.
    // A partial secure-storage write must never leave a previous session live.
    await _secureStorageService.saveAuthSessionActive(false);
    await _secureStorageService.saveAuthUsername(username);
    await _secureStorageService.savePasswordHash(verifier);
  }

  @override
  Future<bool> isSessionActive() {
    return _secureStorageService.isAuthSessionActive();
  }

  @override
  Future<UserEntity?> getCachedUser() async {
    final username = await _secureStorageService.getAuthUsername();
    if (username == null) return null;
    final googleData = await _secureStorageService.getGoogleAccountData();
    return UserEntity(
      id: username,
      username: username,
      email: googleData['email'],
      displayName: googleData['name'] ?? username,
      isGoogleLinked: googleData['id'] != null,
      isBiometricEnabled:
          await _secureStorageService.isAppLockBiometricEnabled(),
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> clearSession() async {
    await _secureStorageService.clearSessionData();
  }
}
