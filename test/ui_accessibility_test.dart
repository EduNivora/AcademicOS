import 'package:academic_os/core/theme/app_theme.dart';
import 'package:academic_os/core/widgets/edunivora_ui.dart';
import 'package:academic_os/domain/entities/course_entity.dart';
import 'package:academic_os/domain/entities/task_entity.dart';
import 'package:academic_os/domain/entities/user_entity.dart';
import 'package:academic_os/domain/repositories/course_repository.dart';
import 'package:academic_os/domain/repositories/task_repository.dart';
import 'package:academic_os/domain/usecases/course_use_cases.dart';
import 'package:academic_os/domain/usecases/task_use_cases.dart';
import 'package:academic_os/presentation/ai_assistant/academic_ai_screen.dart';
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
}


class _AccessibilityTaskRepository implements TaskRepository {
  @override
  Future<int> addTask(TaskEntity task) async => 1;
  @override
  Future<int> deleteTask(int id) async => 1;
  @override
  Future<List<TaskEntity>> fetchTasks() async => [];
  @override
  Future<TaskEntity?> fetchTaskById(int id) async => null;
  @override
  Future<int> updateTask(TaskEntity task) async => 1;
}

class _AccessibilityCourseRepository implements CourseRepository {
  @override
  Future<int> addCourse(CourseEntity course) async => 1;
  @override
  Future<int> deleteCourse(int id) async => 1;
  @override
  Future<List<CourseEntity>> fetchCourses() async => [];
  @override
  Future<CourseEntity?> fetchCourseById(int id) async => null;
  @override
  Future<int> updateCourse(CourseEntity course) async => 1;
}

CourseUseCases _courseUseCases() {
  final repository = _AccessibilityCourseRepository();
  return CourseUseCases(
    getCourses: GetCoursesUseCase(repository),
    getCourseById: GetCourseByIdUseCase(repository),
    addCourse: AddCourseUseCase(repository),
    updateCourse: UpdateCourseUseCase(repository),
    deleteCourse: DeleteCourseUseCase(repository),
  );
}

TaskUseCases _taskUseCases() {
  final repository = _AccessibilityTaskRepository();
  return TaskUseCases(
    getTasks: GetTasksUseCase(repository),
    getTaskById: GetTaskByIdUseCase(repository),
    addTask: AddTaskUseCase(repository),
    updateTask: UpdateTaskUseCase(repository),
    deleteTask: DeleteTaskUseCase(repository),
  );
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
    theme: AppTheme.lightTheme(),
    darkTheme: AppTheme.darkTheme(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Directionality(textDirection: TextDirection.rtl, child: home),
  );
}

void main() {

  test('semantic theme text and action colors meet WCAG AA contrast', () {
    double contrast(Color foreground, Color background) {
      final foregroundLuminance = foreground.computeLuminance();
      final backgroundLuminance = background.computeLuminance();
      final lighter = foregroundLuminance > backgroundLuminance
          ? foregroundLuminance
          : backgroundLuminance;
      final darker = foregroundLuminance > backgroundLuminance
          ? backgroundLuminance
          : foregroundLuminance;
      return (lighter + 0.05) / (darker + 0.05);
    }

    const lightSurface = Color(0xFFF5F7FF);
    const darkSurface = Color(0xFF020817);
    expect(contrast(AppTheme.primaryAction, Colors.white), greaterThanOrEqualTo(4.5));
    expect(contrast(Colors.white, AppTheme.primaryAction), greaterThanOrEqualTo(4.5));
    expect(contrast(AppTheme.mutedTextLight, lightSurface), greaterThanOrEqualTo(4.5));
    expect(contrast(AppTheme.primaryTextLight, lightSurface), greaterThanOrEqualTo(4.5));
    expect(contrast(AppTheme.primaryTextDark, darkSurface), greaterThanOrEqualTo(4.5));
    expect(contrast(AppTheme.textMuted, darkSurface), greaterThanOrEqualTo(4.5));
  });

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

    final passwordField = find.descendant(
      of: find.byType(TextFormField).at(1),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(passwordField).obscureText, isTrue);
    await tester.tap(find.byTooltip('إظهار كلمة المرور'));
    await tester.pump();
    expect(tester.widget<TextField>(passwordField).obscureText, isFalse);

    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل بريدك الإلكتروني أو اسم المستخدم'), findsOneWidget);
    expect(find.text('أدخل كلمة المرور'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
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


  for (final dark in [false, true]) {
    testWidgets('primary controls meet contrast and touch targets (dark=$dark)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Primary action'),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Secondary action'),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Text action'),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Outlined action'),
                  ),
                  const TextField(
                    decoration: InputDecoration(labelText: 'Search'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }


  testWidgets('assistant composer has accessible label and send action tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        dark: false,
        home: AcademicAiScreen(
          courseUseCases: _courseUseCases(),
          taskUseCases: _taskUseCases(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('رسالتك للمساعد الذكي'), findsOneWidget);
    expect(find.byTooltip('إرفاق ملف بالمادة'), findsOneWidget);
    expect(find.byTooltip('إرسال الرسالة'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).maxLines, 4);

    await tester.enterText(find.byType(TextField), 'مرحباً');
    await tester.tap(find.byTooltip('إرسال الرسالة'));
    await tester.pumpAndSettle();

    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });

}
