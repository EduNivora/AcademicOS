import '../../core/security/auth_secure_storage_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_google_data_source.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/neon_auth_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthLocalDataSource _localDataSource;
  final AuthGoogleDataSource _googleDataSource;
  final AuthSecureStorageService _secureStorageService;
  final NeonAuthDataSource _neonAuthDataSource;

  AuthRepositoryImpl(
    this._localDataSource,
    this._googleDataSource,
    this._secureStorageService, {
    NeonAuthDataSource? neonAuthDataSource,
  }) : _neonAuthDataSource = neonAuthDataSource ??
            NeonAuthDataSource(
              sessionStore:
                  SecureStorageNeonAuthSessionStore(_secureStorageService),
            );

  @override
  Future<UserEntity?> getCurrentUser() async {
    try {
      final session = await _neonAuthDataSource.getSession();
      final user = session?['user'];
      if (user is Map) return _mapNeonUser(Map<String, dynamic>.from(user));
    } catch (_) {
      // The local-first workspace remains available when Auth is offline.
    }
    return _localDataSource.getCachedUser();
  }

  @override
  Future<bool> isLoggedIn() async {
    try {
      final session = await _neonAuthDataSource.getSession();
      final user = session?['user'];
      if (user is Map &&
          user['emailVerified'] == true &&
          user['banned'] != true) {
        final email = user['email'];
        if (email is String && email.isNotEmpty) {
          await _secureStorageService.saveAuthUsername(email);
        }
        await _secureStorageService.saveAuthSessionActive(true);
        return true;
      }
      await _secureStorageService.clearNeonAuthCookie();
    } catch (_) {
      // Do not block guest mode when the remote identity service is offline.
    }
    return _localDataSource.isSessionActive();
  }

  @override
  Future<void> logout() async {
    try {
      await _neonAuthDataSource.signOut();
    } catch (_) {
      // Local logout still clears the persisted cookie and active identity.
    }
    try {
      await _googleDataSource.signOut();
    } catch (_) {
      // Ignore provider sign-out failures; local logout must still complete.
    }
    await _localDataSource.clearSession();
  }

  @override
  Future<bool> loginWithEmail(String email, String password) async {
    final result = await _neonAuthDataSource.signIn(
      email: email,
      password: password,
    );
    final user = result['user'];
    if (user is! Map || user['emailVerified'] != true || user['banned'] == true) {
      return false;
    }
    await _secureStorageService.saveAuthUsername(email.trim().toLowerCase());
    await _secureStorageService.saveAuthSessionActive(true);
    return true;
  }

  @override
  Future<bool> loginWithGoogle() async {
    final account = await _googleDataSource.signIn();
    if (account == null) return false;
    await _secureStorageService.saveGoogleAccountData(
      id: account.id,
      email: account.email,
      name: account.displayName ?? account.email,
    );
    await _secureStorageService.saveAuthUsername(account.email);
    await _secureStorageService.saveAuthSessionActive(true);
    return true;
  }

  @override
  Future<bool> loginWithCachedGoogleAccount() async {
    final cached = await _secureStorageService.getGoogleAccountData();
    final email = cached['email'];
    final id = cached['id'];
    if (email == null || id == null) return false;
    await _secureStorageService.saveAuthUsername(email);
    await _secureStorageService.saveAuthSessionActive(true);
    return true;
  }

  @override
  Future<bool> loginWithUsername(String username, String password) {
    return _localDataSource.verifyCredentials(username, password);
  }

  @override
  Future<bool> registerLocalUser(
    String username,
    String password, {
    String? email,
    String? displayName,
  }) async {
    await _localDataSource.persistLocalUser(
      username,
      password,
      email: email,
      displayName: displayName,
    );
    return true;
  }

  @override
  Future<bool> registerCloudUser({
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await _neonAuthDataSource.signUp(
      name: name,
      email: email,
      password: password,
    );
    final user = result['user'];
    return user is Map && user['id'] is String;
  }

  @override
  Future<bool> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    final result = await _neonAuthDataSource.verifyEmailOtp(
      email: email,
      otp: otp,
    );
    final user = result['user'];
    if (result['status'] != true ||
        user is! Map ||
        user['emailVerified'] != true) {
      return false;
    }
    await _secureStorageService.saveAuthUsername(email.trim().toLowerCase());
    await _secureStorageService.saveAuthSessionActive(true);
    return true;
  }

  @override
  Future<void> resendEmailVerificationOtp(String email) async {
    await _neonAuthDataSource.sendEmailVerificationOtp(email);
  }

  @override
  Future<String?> getCloudAccessToken() =>
      _neonAuthDataSource.getAccessToken();

  UserEntity _mapNeonUser(Map<String, dynamic> user) {
    final email = user['email'] is String ? user['email'] as String : '';
    final name = user['name'] is String ? user['name'] as String : email;
    final createdAt = DateTime.tryParse(user['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return UserEntity(
      id: user['id']?.toString() ?? email,
      username: email,
      email: email,
      displayName: name,
      isGoogleLinked: false,
      isBiometricEnabled: false,
      createdAt: createdAt,
    );
  }
}
