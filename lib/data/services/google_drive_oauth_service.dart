import 'package:google_sign_in/google_sign_in.dart';

import 'google_drive_backup_service.dart';

/// Obtains short-lived Google OAuth tokens for the user's own Drive.
///
/// The Drive scope is requested only when the student explicitly starts a
/// Drive backup/restore flow; it is not added to the app's ordinary sign-in.
class GoogleDriveOAuthService {
  GoogleDriveOAuthService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(scopes: const [GoogleDriveBackupService.driveFileScope]);

  final GoogleSignIn _googleSignIn;

  Future<String?> authorizeAndGetAccessToken() async {
    var account = await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();
    if (account == null) return null;

    final scope = GoogleDriveBackupService.driveFileScope;
    var hasScope = await _googleSignIn.canAccessScopes([scope]);
    if (!hasScope) {
      hasScope = await _googleSignIn.requestScopes([scope]);
    }
    if (!hasScope) return null;

    final authentication = await account.authentication;
    final token = authentication.accessToken;
    if (token == null || token.isEmpty) return null;
    return token;
  }

  Future<void> signOut() => _googleSignIn.signOut();
}
