import 'package:google_sign_in/google_sign_in.dart';

class GoogleIdTokenProvider {
  GoogleIdTokenProvider({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              serverClientId: const String.fromEnvironment(
                'GOOGLE_SERVER_CLIENT_ID',
                defaultValue: '',
              ).isEmpty
                  ? null
                  : const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
            );

  final GoogleSignIn _googleSignIn;

  Future<String> requireIdToken() async {
    final account = await _googleSignIn.signInSilently();
    if (account == null) {
      throw StateError(
        'يتطلب استخدام المساعد تسجيل الدخول بحساب Google موثّق. '
        'تسجيل الدخول المحلي وحده لا يثبت الهوية للخادم.',
      );
    }
    final authentication = await account.authentication;
    final token = authentication.idToken;
    if (token == null || token.isEmpty) {
      throw StateError(
        'تعذر الحصول على رمز هوية Google. تحقق من إعداد Web OAuth Client ID.',
      );
    }
    return token;
  }
}