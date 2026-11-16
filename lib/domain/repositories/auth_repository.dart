import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<bool> loginWithUsername(String username, String password);
  Future<bool> loginWithEmail(String email, String password);
  Future<bool> registerLocalUser(
    String username,
    String password, {
    String? email,
    String? displayName,
  });
  Future<bool> registerCloudUser({
    required String name,
    required String email,
    required String password,
  });
  Future<bool> verifyEmailOtp({
    required String email,
    required String otp,
  });
  Future<void> resendEmailVerificationOtp(String email);
  Future<String?> getCloudAccessToken();
  Future<bool> loginWithGoogle();
  Future<bool> loginWithCachedGoogleAccount();
  Future<bool> isLoggedIn();
  Future<UserEntity?> getCurrentUser();
  Future<void> logout();
}
