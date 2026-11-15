import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class LoginWithUsernameUseCase {
  final AuthRepository repository;
  LoginWithUsernameUseCase(this.repository);
  Future<bool> call(String username, String password) =>
      repository.loginWithUsername(username, password);
}

class LoginWithEmailUseCase {
  final AuthRepository repository;
  LoginWithEmailUseCase(this.repository);
  Future<bool> call(String email, String password) =>
      repository.loginWithEmail(email, password);
}

class RegisterLocalUserUseCase {
  final AuthRepository repository;
  RegisterLocalUserUseCase(this.repository);
  Future<bool> call(String username, String password,
          {String? email, String? displayName}) =>
      repository.registerLocalUser(username, password,
          email: email, displayName: displayName);
}

class RegisterCloudUserUseCase {
  final AuthRepository repository;
  RegisterCloudUserUseCase(this.repository);
  Future<bool> call({
    required String name,
    required String email,
    required String password,
  }) =>
      repository.registerCloudUser(
          name: name, email: email, password: password);
}

class VerifyEmailOtpUseCase {
  final AuthRepository repository;
  VerifyEmailOtpUseCase(this.repository);
  Future<bool> call({required String email, required String otp}) =>
      repository.verifyEmailOtp(email: email, otp: otp);
}

class ResendEmailVerificationOtpUseCase {
  final AuthRepository repository;
  ResendEmailVerificationOtpUseCase(this.repository);
  Future<void> call(String email) =>
      repository.resendEmailVerificationOtp(email);
}

class GetCloudAccessTokenUseCase {
  final AuthRepository repository;
  GetCloudAccessTokenUseCase(this.repository);
  Future<String?> call() => repository.getCloudAccessToken();
}

class LoginWithGoogleUseCase {
  final AuthRepository repository;
  LoginWithGoogleUseCase(this.repository);
  Future<bool> call() => repository.loginWithGoogle();
}

class LoginWithCachedGoogleAccountUseCase {
  final AuthRepository repository;
  LoginWithCachedGoogleAccountUseCase(this.repository);
  Future<bool> call() => repository.loginWithCachedGoogleAccount();
}

class IsLoggedInUseCase {
  final AuthRepository repository;
  IsLoggedInUseCase(this.repository);
  Future<bool> call() => repository.isLoggedIn();
}

class GetCurrentUserUseCase {
  final AuthRepository repository;
  GetCurrentUserUseCase(this.repository);
  Future<UserEntity?> call() => repository.getCurrentUser();
}

class LogoutUseCase {
  final AuthRepository repository;
  LogoutUseCase(this.repository);
  Future<void> call() => repository.logout();
}

class AuthUseCases {
  final LoginWithUsernameUseCase loginWithUsername;
  final LoginWithEmailUseCase loginWithEmail;
  final RegisterLocalUserUseCase registerLocalUser;
  final RegisterCloudUserUseCase registerCloudUser;
  final VerifyEmailOtpUseCase verifyEmailOtp;
  final ResendEmailVerificationOtpUseCase resendEmailVerificationOtp;
  final GetCloudAccessTokenUseCase getCloudAccessToken;
  final LoginWithGoogleUseCase loginWithGoogle;
  final LoginWithCachedGoogleAccountUseCase loginWithCachedGoogleAccount;
  final IsLoggedInUseCase isLoggedIn;
  final GetCurrentUserUseCase getCurrentUser;
  final LogoutUseCase logout;

  const AuthUseCases({
    required this.loginWithUsername,
    required this.loginWithEmail,
    required this.registerLocalUser,
    required this.registerCloudUser,
    required this.verifyEmailOtp,
    required this.resendEmailVerificationOtp,
    required this.getCloudAccessToken,
    required this.loginWithGoogle,
    required this.loginWithCachedGoogleAccount,
    required this.isLoggedIn,
    required this.getCurrentUser,
    required this.logout,
  });
}
