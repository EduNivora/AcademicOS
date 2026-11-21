import 'package:academic_os/core/theme/app_theme.dart';
import 'package:academic_os/core/widgets/edunivora_ui.dart';
import 'package:academic_os/domain/entities/user_entity.dart';
import 'package:academic_os/domain/repositories/auth_repository.dart';
import 'package:academic_os/domain/usecases/auth_use_cases.dart';
import 'package:academic_os/presentation/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _AccessibilityAuthRepository implements AuthRepository {
  @override
  Future<String?> getCloudAccessToken() async => null;
  @override
  Future<UserEntity?> getCurrentUser() async => null;
  @override
  Future<bool> isLoggedIn() async => false;
  @override
  Future<bool> loginWithCachedGoogleAccount() async => false;
  @override
  Future<bool> loginWithEmail(String email, String password) async => true;
  @override
  Future<bool> loginWithGoogle() async => true;
  @override
  Future<bool> loginWithUsername(String username, String password) async => true;
  @override
  Future<void> logout() async {}
  @override
  Future<bool> registerCloudUser({
    required String name,
    required String email,
    required String password,
  }) async => true;
  @override
  Future<bool> registerLocalUser(
    String username,
    String password, {
    String? email,
    String? displayName,
  }) async => true;
  @override
  Future<void> resendEmailVerificationOtp(String email) async {}
  @override
  Future<bool> verifyEmailOtp({
    required String email,
    required String otp,
  }) async => true;
  for (final dark in [false, true]) {
    testWidgets('shared brand footer meets text contrast guidance (dark=$dark)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: EduBrandFooter(),
              ),
            ),
          ),
        ),
      );

      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }

}

AuthUseCases _authUseCases() {
  final repository = _AccessibilityAuthRepository();
  return AuthUseCases(
    loginWithUsername: LoginWithUsernameUseCase(repository),
    loginWithEmail: LoginWithEmailUseCase(repository),
    registerLocalUser: RegisterLocalUserUseCase(repository),
    registerCloudUser: RegisterCloudUserUseCase(repository),
    verifyEmailOtp: VerifyEmailOtpUseCase(repository),
    resendEmailVerificationOtp: ResendEmailVerificationOtpUseCase(repository),
    getCloudAccessToken: GetCloudAccessTokenUseCase(repository),
    loginWithGoogle: LoginWithGoogleUseCase(repository),
    loginWithCachedGoogleAccount:
        LoginWithCachedGoogleAccountUseCase(repository),
    isLoggedIn: IsLoggedInUseCase(repository),
    getCurrentUser: GetCurrentUserUseCase(repository),
    logout: LogoutUseCase(repository),
  );
}

Widget _testApp({required bool dark, required Widget home}) {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B6CFF)),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5B6CFF),
        brightness: Brightness.dark,
      ),
    ),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Directionality(textDirection: TextDirection.rtl, child: home),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final dark in [false, true]) {
    testWidgets(
      'Arabic login remains usable at 320px width and 1.5x text scale (dark=$dark)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _testApp(
            dark: dark,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.5),
              ),
              child: LoginScreen(
                authUseCases: _authUseCases(),
                onLoginSuccess: () async {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(find.text('تسجيل الدخول'), findsOneWidget);
        expect(find.text('البريد الإلكتروني أو اسم المستخدم'), findsOneWidget);
        expect(tester.takeException(), isNull);

        final semantics = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      },
    );
  }

  testWidgets('login controls expose a password visibility label', (tester) async {
    await tester.pumpWidget(
      _testApp(
        dark: false,
        home: LoginScreen(
          authUseCases: _authUseCases(),
          onLoginSuccess: () async {},
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    expect(find.byTooltip('إظهار كلمة المرور'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    semantics.dispose();
  });
}
