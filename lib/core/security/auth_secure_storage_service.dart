
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' show Argon2id;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthSecureStorageService {
  static const String _dbPasswordKey = 'academic_os_db_password';
  static const String _authUsernameKey = 'academic_os_auth_username';
  static const String _authPasswordHashKey = 'academic_os_auth_password_hash';
  static const String _authPasswordSaltKey = 'academic_os_auth_password_salt';
  static const String _googleAccountIdKey = 'academic_os_google_account_id';
  static const String _googleAccountEmailKey = 'academic_os_google_account_email';
  static const String _googleAccountNameKey = 'academic_os_google_account_name';
  static const String _authSessionActiveKey = 'academic_os_auth_session_active';
  static const String _authLogoutRequiredKey =
      'academic_os_auth_logout_required';
  static const String _appLockPinHashKey = 'academic_os_app_lock_pin_hash';
  static const String _appLockPinSaltKey = 'academic_os_app_lock_pin_salt';
  static const String _appLockPinAttemptStateKey =
      'academic_os_app_lock_pin_attempt_state';
  static const String _appLockBiometricEnabledKey = 'academic_os_app_lock_biometric_enabled';
  static const String _appLockTimeoutKey = 'academic_os_app_lock_timeout';
  static const String _appLockLastActiveAtKey = 'academic_os_app_lock_last_active_at';

  static const int _argonMemoryKiB = 19456;
  static const int _argonIterations = 2;
  static const int _argonParallelism = 1;
  static const int _argonHashLength = 32;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<String> getDatabasePassword() async {
    final existingPassword = await _secureStorage.read(key: _dbPasswordKey);
    if (existingPassword != null && existingPassword.isNotEmpty) {
      return existingPassword;
    }
    final newPassword = _generateSecurePassword();
    await _secureStorage.write(key: _dbPasswordKey, value: newPassword);
    return newPassword;
  }

  Future<void> deleteDatabasePassword() async {
    await _secureStorage.delete(key: _dbPasswordKey);
  }

  Future<void> saveAuthUsername(String username) async {
    await _secureStorage.write(key: _authUsernameKey, value: username);
  }

  Future<String?> getAuthUsername() async =>
      _secureStorage.read(key: _authUsernameKey);

  Future<void> savePasswordHash(String hash) async {
    await _secureStorage.write(key: _authPasswordHashKey, value: hash);
  }

  Future<String?> getPasswordHash() async =>
      _secureStorage.read(key: _authPasswordHashKey);

  Future<void> savePasswordSalt(String salt) async {
    await _secureStorage.write(key: _authPasswordSaltKey, value: salt);
  }

  Future<String?> getPasswordSalt() async =>
      _secureStorage.read(key: _authPasswordSaltKey);

  Future<void> saveGoogleAccountData({
    required String id,
    required String email,
    required String name,
  }) async {
    await _secureStorage.write(key: _googleAccountIdKey, value: id);
    await _secureStorage.write(key: _googleAccountEmailKey, value: email);
    await _secureStorage.write(key: _googleAccountNameKey, value: name);
  }

  Future<void> clearGoogleAccountData() async {
    await _secureStorage.delete(key: _googleAccountIdKey);
    await _secureStorage.delete(key: _googleAccountEmailKey);
    await _secureStorage.delete(key: _googleAccountNameKey);
  }

  Future<Map<String, String?>> getGoogleAccountData() async {
    final id = await _secureStorage.read(key: _googleAccountIdKey);
    final email = await _secureStorage.read(key: _googleAccountEmailKey);
    final name = await _secureStorage.read(key: _googleAccountNameKey);
    return {'id': id, 'email': email, 'name': name};
  }

  Future<void> saveAuthSessionActive(bool isActive) async {
    await _secureStorage.write(
      key: _authSessionActiveKey,
      value: isActive ? 'true' : 'false',
    );
    if (isActive) {
      await clearAuthLogoutRequired();
    }
  }

  Future<void> clearSessionData() async {
    // Persist logout intent before clearing cached identity state. Local
    // credentials remain available for an explicit username/password login.
    await _secureStorage.write(key: _authLogoutRequiredKey, value: 'true');
    await saveAuthSessionActive(false);
    await clearGoogleAccountData();
  }

  /// Ends any previous session before allowing guest mode.
  Future<void> continueAsGuest() async {
    await clearSessionData();
    await clearAuthLogoutRequired();
  }

  Future<bool> isAuthLogoutRequired() async {
    final value = await _secureStorage.read(key: _authLogoutRequiredKey);
    return value == 'true';
  }

  Future<void> clearAuthLogoutRequired() async {
    await _secureStorage.delete(key: _authLogoutRequiredKey);
  }

  Future<bool> isAuthSessionActive() async {
    final value = await _secureStorage.read(key: _authSessionActiveKey);
    return value == 'true';
  }

  Future<void> saveAppLockPinHash(String pinHash) async {
    await _secureStorage.write(key: _appLockPinHashKey, value: pinHash);
  }

  Future<String?> getAppLockPinHash() async =>
      _secureStorage.read(key: _appLockPinHashKey);

  Future<void> saveAppLockPinSalt(String salt) async {
    await _secureStorage.write(key: _appLockPinSaltKey, value: salt);
  }

  Future<String?> getAppLockPinSalt() async =>
      _secureStorage.read(key: _appLockPinSaltKey);

  Future<void> deleteAppLockPin() async {
    await _secureStorage.delete(key: _appLockPinHashKey);
    await _secureStorage.delete(key: _appLockPinSaltKey);
    await resetAppLockPinAttempts();
  }

  Future<Duration?> getAppLockPinLockoutRemaining() async {
    final state = await _readAppLockPinAttemptState();
    final blockedUntil = state['blockedUntil'] as int;
    final remaining = blockedUntil - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? Duration(milliseconds: remaining) : null;
  }

  Future<void> recordFailedAppLockPinAttempt() async {
    final state = await _readAppLockPinAttemptState();
    final attempts = (state['attempts'] as int) + 1;
    final exponent = (attempts - 5).clamp(0, 5).toInt();
    final delaySeconds = attempts < 5
        ? 0
        : min(900, 30 * (1 << exponent)).toInt();
    final blockedUntil = delaySeconds == 0
        ? 0
        : DateTime.now()
            .add(Duration(seconds: delaySeconds))
            .millisecondsSinceEpoch;
    await _secureStorage.write(
      key: _appLockPinAttemptStateKey,
      value: jsonEncode({
        'attempts': attempts,
        'blockedUntil': blockedUntil,
      }),
    );
  }

  Future<void> resetAppLockPinAttempts() async {
    await _secureStorage.delete(key: _appLockPinAttemptStateKey);
  }

  Future<Map<String, int>> _readAppLockPinAttemptState() async {
    final raw = await _secureStorage.read(key: _appLockPinAttemptStateKey);
    if (raw == null) return {'attempts': 0, 'blockedUntil': 0};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map ||
          decoded['attempts'] is! int ||
          decoded['blockedUntil'] is! int ||
          decoded['attempts'] < 0 ||
          decoded['blockedUntil'] < 0) {
        throw const FormatException('Invalid PIN attempt state.');
      }
      return {
        'attempts': decoded['attempts'] as int,
        'blockedUntil': decoded['blockedUntil'] as int,
      };
    } on FormatException {
      // Corrupt lockout state must fail closed, not reset the attempt counter.
      throw StateError('App-lock PIN attempt state is corrupted.');
    }
  }

  Future<void> saveAppLockBiometricEnabled(bool enabled) async {
    await _secureStorage.write(
      key: _appLockBiometricEnabledKey,
      value: enabled ? 'true' : 'false',
    );
  }

  Future<bool> isAppLockBiometricEnabled() async {
    final value = await _secureStorage.read(key: _appLockBiometricEnabledKey);
    return value == 'true';
  }

  Future<void> saveAppLockTimeout(int minutes) async {
    await _secureStorage.write(
      key: _appLockTimeoutKey,
      value: minutes.toString(),
    );
  }

  Future<void> saveAppLockLastActiveAt(DateTime dateTime) async {
    await _secureStorage.write(
      key: _appLockLastActiveAtKey,
      value: dateTime.toIso8601String(),
    );
  }

  Future<String?> getAppLockLastActiveAt() async =>
      _secureStorage.read(key: _appLockLastActiveAtKey);

  Future<int> getAppLockTimeout() async {
    final value = await _secureStorage.read(key: _appLockTimeoutKey);
    return int.tryParse(value ?? '') ?? 5;
  }

  String _generateSecurePassword() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  Future<String> createPasswordVerifier(String password) async {
    final salt = generateSalt();
    final saltBytes = base64Url.decode(salt);
    final algorithm = Argon2id(
      memory: _argonMemoryKiB,
      iterations: _argonIterations,
      parallelism: _argonParallelism,
      hashLength: _argonHashLength,
    );
    final key = await algorithm.deriveKeyFromPassword(
      password: password,
      nonce: saltBytes,
    );
    final hash = base64UrlEncode(await key.extractBytes());
    return [
      'argon2id',
      'v=1',
      'm=$_argonMemoryKiB,t=$_argonIterations,p=$_argonParallelism',
      salt,
      hash,
    ].join(r'$');
  }

  Future<bool> verifyPasswordVerifier(
    String password,
    String verifier,
  ) async {
    try {
      final parts = verifier.split(r'$');
      if (parts.length != 5 ||
          parts[0] != 'argon2id' ||
          parts[1] != 'v=1' ||
          parts[2] !=
              'm=$_argonMemoryKiB,t=$_argonIterations,p=$_argonParallelism') {
        return false;
      }
      final salt = base64Url.decode(parts[3]);
      final expected = base64Url.decode(parts[4]);
      if (salt.length != 16 || expected.length != _argonHashLength) {
        return false;
      }
      final algorithm = Argon2id(
        memory: _argonMemoryKiB,
        iterations: _argonIterations,
        parallelism: _argonParallelism,
        hashLength: _argonHashLength,
      );
      final key = await algorithm.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );
      return _constantTimeBytesEqual(await key.extractBytes(), expected);
    } on FormatException {
      return false;
    }
  }

  bool _constantTimeBytesEqual(List<int> candidate, List<int> expected) {
    final length = max(candidate.length, expected.length);
    var difference = candidate.length ^ expected.length;
    for (var index = 0; index < length; index++) {
      final left = index < candidate.length ? candidate[index] : 0;
      final right = index < expected.length ? expected[index] : 0;
      difference |= left ^ right;
    }
    return difference == 0;
  }

  /// Legacy SHA-256 verifier retained only for PIN compatibility and migration.
  String hashPassword(String password, String salt) {
    final key = utf8.encode(password + salt);
    return sha256.convert(key).toString();
  }

  bool constantTimeEquals(String candidate, String expected) {
    final length = max(candidate.length, expected.length);
    var difference = candidate.length ^ expected.length;
    for (var index = 0; index < length; index++) {
      final left = index < candidate.length ? candidate.codeUnitAt(index) : 0;
      final right = index < expected.length ? expected.codeUnitAt(index) : 0;
      difference |= left ^ right;
    }
    return difference == 0;
  }

  String generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }
}
