import '../../core/security/auth_secure_storage_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_google_data_source.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/neon_auth_data_source.dart';
import '../datasources/neon_account_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthLocalDataSource _localDataSource;
  final AuthGoogleDataSource _googleDataSource;
  final AuthSecureStorageService _secureStorageService;
  final NeonAuthDataSource _neonAuthDataSource;
  final NeonAccountDataSource _neonAccountDataSource;

  AuthRepositoryImpl(
    this._localDataSource,
    this._googleDataSource,
    this._secureStorageService, {
    NeonAuthDataSource? neonAuthDataSource,
    NeonAccountDataSource? neonAccountDataSource,
  }) : _neonAccountDataSource = neonAccountDataSource ?? NeonAccountDataSource(),
       _neonAuthDataSource = neonAuthDataSource ??
            NeonAuthDataSource(
              sessionStore:
                  SecureStorageNeonAuthSessionStore(_secureStorageService),
            );

  @override
  Future<UserEntity?> getCurrentUser() async {
    if (await _secureStorageService.isNeonAuthSessionActive()) {
      try {
        final session = await _neonAuthDataSource.getSession();
        final user = session?['user'];
        if (user is Map) {
          var role = 'user';
          try {
            final token = await _neonAuthDataSource.getAccessToken();
            if (token != null) {
              final profile = await _neonAccountDataSource.getProfile(token);
              role = profile['role']?.toString() ?? 'user';
            }
          } catch (_) {
            // A profile lookup failure must never grant admin privileges.
          }
          return _mapNeonUser(
            Map<String, dynamic>.from(user),
            role: role,
          );
        }
      } catch (_) {
        // Do not substitute a different local identity for an offline cloud user.
      }
      return null;
    }
    return _localDataSource.getCachedUser();
  }

  @override
  Future<bool> isLoggedIn() async {
    final hasNeonSession = await _secureStorageService.isNeonAuthSessionActive();
    if (!hasNeonSession) return _localDataSource.isSessionActive();

    Map<String, dynamic>? session;
    try {
      session = await _neonAuthDataSource.getSession();
    } catch (_) {
      // Keep the cookie for a later retry, but never block guest academic access.
      return false;
    }

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
    await _secureStorageService.saveNeonAuthSessionActive(false);
    await _secureStorageService.saveAuthSessionActive(false);
    return false;
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
    if (user is! Map) return false;
    if (user['emailVerified'] != true) {
      throw StateError('email_not_verified');
    }
    if (user['banned'] == true) {
      throw StateError('account_unavailable');
    }
    await _secureStorageService.saveAuthUsername(email.trim().toLowerCase());
    await _secureStorageService.saveNeonAuthSessionActive(true);
    await _secureStorageService.saveAuthSessionActive(true);
    return true;
  }

  @override
  Future<bool> loginWithGoogle() async {
    final oauthResult =
        await _googleDataSource.authenticateWithNeon(_neonAuthDataSource);

    if (oauthResult.status == GoogleOAuthStatus.cancelled) {
      return false;
    }
    if (oauthResult.status != GoogleOAuthStatus.verifierReceived ||
        oauthResult.verifier == null ||
        oauthResult.verifier!.isEmpty) {
      throw StateError(oauthResult.errorCode ?? 'google_oauth_failed');
    }

    // Never treat the arrival of a callback/deep link as authentication.
    // Exchange the one-time verifier with Neon Auth and verify the resulting
    // session cookie before activating any local session state.
    final exchangeResult = await _neonAuthDataSource.completeOAuthSession(
      verifier: oauthResult.verifier!,
      challengeCookieHeader: oauthResult.challengeCookieHeader ?? '',
      origin: oauthResult.origin ?? '',
    );

    final persistedCookie = await _secureStorageService.getNeonAuthCookie();
    if (persistedCookie == null || persistedCookie.isEmpty) {
      await _secureStorageService.clearNeonAuthCookie();
      throw StateError('neon_session_cookie_missing');
    }

    final verifiedSession = await _neonAuthDataSource.getSession();
    final user = verifiedSession?['user'] ?? exchangeResult['user'];
    if (verifiedSession == null || user is! Map) {
      await _neonAuthDataSource.signOut();
      throw StateError('neon_session_verification_failed');
    }

    if (user['banned'] == true) {
      await _neonAuthDataSource.signOut();
      throw StateError('account_unavailable');
    }
    if (user['emailVerified'] != true) {
      await _neonAuthDataSource.signOut();
      throw StateError('google_email_not_verified');
    }

    // Resolve a real Neon access token immediately after OAuth. The session
    // cookie remains the refreshable credential; short-lived bearer tokens
    // are fetched on demand rather than persisted in local storage.
    final accessToken = await _neonAuthDataSource.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      await _neonAuthDataSource.signOut();
      throw StateError('neon_access_token_missing');
    }

    final email = (user['email']?.toString() ?? '').trim().toLowerCase();
    if (email.isEmpty) {
      await _neonAuthDataSource.signOut();
      throw StateError('google_email_missing');
    }
    final id = user['id']?.toString() ?? email;
    final name = (user['name']?.toString() ?? '').trim();

    await _secureStorageService.saveGoogleAccountData(
      id: id,
      email: email,
      name: name.isNotEmpty ? name : email.split('@').first,
    );
    await _secureStorageService.saveAuthUsername(email);
    await _secureStorageService.saveNeonAuthSessionActive(true);
    await _secureStorageService.saveAuthSessionActive(true);
    return true;
  }

  @override
  Future<bool> loginWithCachedGoogleAccount() async {
    // Active Neon Auth sessions are restored by isLoggedIn() from the verified
    // session cookie in secure storage. Do not trigger silent legacy Google
    // Sign-In outside Neon Auth.
    return false;
  }

  @override
  Future<bool> loginWithUsername(String username, String password) async {
    final authenticated =
        await _localDataSource.verifyCredentials(username, password);
    if (authenticated) {
      await _secureStorageService.clearNeonAuthCookie();
      await _secureStorageService.saveNeonAuthSessionActive(false);
    }
    return authenticated;
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
    await _secureStorageService.saveNeonAuthSessionActive(true);
    await _secureStorageService.saveAuthSessionActive(true);
    return true;
  }

  @override
  Future<void> resendEmailVerificationOtp(String email) async {
    await _neonAuthDataSource.sendEmailVerificationOtp(email);
  }

  @override
  Future<String?> getCloudAccessToken() async {
    if (!await _secureStorageService.isNeonAuthSessionActive()) return null;
    try {
      final token = await _neonAuthDataSource.getAccessToken();
      if (token == null) {
        await _secureStorageService.clearNeonAuthCookie();
        await _secureStorageService.saveNeonAuthSessionActive(false);
        await _secureStorageService.saveAuthSessionActive(false);
      }
      return token;
    } on NeonAuthException catch (error) {
      if (error.statusCode == 401) {
        await _secureStorageService.clearNeonAuthCookie();
        await _secureStorageService.saveNeonAuthSessionActive(false);
        await _secureStorageService.saveAuthSessionActive(false);
        return null;
      }
      rethrow;
    }
  }

  Future<UserEntity> _mapNeonUser(
    Map<String, dynamic> user, {
    String role = 'user',
  }) async {
    final email = user['email'] is String ? user['email'] as String : '';
    final neonName = user['name'] is String
        ? (user['name'] as String).trim()
        : '';
    final googleAccount = await _secureStorageService.getGoogleAccountData();
    final cachedGoogleName = googleAccount['name']?.trim() ?? '';
    final emailName = email.contains('@') ? email.split('@').first : email;
    final name = neonName.isNotEmpty
        ? neonName
        : (cachedGoogleName.isNotEmpty ? cachedGoogleName : emailName);
    final createdAt = DateTime.tryParse(user['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return UserEntity(
      id: user['id']?.toString() ?? email,
      username: email,
      email: email,
      displayName: name,
      isGoogleLinked: googleAccount['id'] != null,
      isBiometricEnabled: false,
      role: role,
      createdAt: createdAt,
    );
  }
}
