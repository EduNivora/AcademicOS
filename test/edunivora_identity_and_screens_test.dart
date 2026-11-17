import 'package:academic_os/core/config/edunivora_identity.dart';
import 'package:academic_os/core/services/external_link_service.dart';
import 'package:academic_os/core/theme/app_theme.dart';
import 'package:academic_os/core/widgets/edunivora_ui.dart';
import 'package:academic_os/domain/entities/user_entity.dart';
import 'package:academic_os/domain/repositories/auth_repository.dart';
import 'package:academic_os/domain/usecases/auth_use_cases.dart';
import 'package:academic_os/presentation/about/about_app_screen.dart';
import 'package:academic_os/presentation/about/about_screen.dart';
import 'package:academic_os/presentation/about/contact_screen.dart';
import 'package:academic_os/presentation/about/help_center_screen.dart';
import 'package:academic_os/presentation/about/privacy_terms_screen.dart';
import 'package:academic_os/presentation/auth/login_screen.dart';
import 'package:academic_os/presentation/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestApp({
  required Widget home,
  bool isArabic = true,
  bool isDark = false,
}) {
  return MaterialApp(
    locale: isArabic ? const Locale('ar') : const Locale('en'),
    supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AppTheme.lightTheme(),
    darkTheme: AppTheme.darkTheme(),
    themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) {
      return Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      );
    },
    home: home,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EdunivoraIdentity integrity', () {
    test('contains official branding, version, and exact attribution', () {
      expect(EdunivoraIdentity.appName, 'EduNivora');
      expect(
        EdunivoraIdentity.officialTagline,
        'The Intelligent Academic Ecosystem',
      );
      expect(EdunivoraIdentity.appVersion, '1.0.0');
      expect(EdunivoraIdentity.appBuild, '2');
      expect(EdunivoraIdentity.versionDisplay, '1.0.0+2');
      expect(
        EdunivoraIdentity.attribution,
        'EduNivora\nFounded & Developed by\nMohammed Ghaleb Alaosimi & Arfat Alkamly',
      );
      expect(
        EdunivoraIdentity.developingOrganization.ar,
        'الجهة المطورة لـ EduNivora',
      );
      expect(
        EdunivoraIdentity.developingOrganization.en,
        'EduNivora Development Team',
      );
    });

    test('gives both co-founders equal status and verified links', () {
      expect(EdunivoraIdentity.founders, hasLength(2));

      final mohammed = EdunivoraIdentity.founders[0];
      final arfat = EdunivoraIdentity.founders[1];

      expect(mohammed.arabicName, 'محمد غالب العصيمي');
      expect(mohammed.englishName, 'Mohammed Ghaleb Alaosimi');
      expect(mohammed.initials, 'M.GH');
      expect(mohammed.brand, 'M.GH.AL');
      expect(mohammed.roleAr, 'مؤسس ومشارك في التأسيس');
      expect(mohammed.roleEn, 'Founder & Co-Founder');
      expect(
        mohammed.titles,
        containsAll(<String>[
          'Full-Stack Developer',
          'Software Engineer',
          'Information Technology Student',
        ]),
      );

      expect(arfat.arabicName, 'عرفات الكاملي');
      expect(arfat.englishName, 'Arfat Alkamly');
      expect(arfat.initials, 'AK');
      expect(arfat.roleAr, mohammed.roleAr);
      expect(arfat.roleEn, mohammed.roleEn);
      expect(arfat.publicEmail, 'alkamlyrfat@gmail.com');

      // Verified links for Mohammed
      expect(
        mohammed.links.map((l) => l.url),
        containsAll(<String>[
          'https://github.com/mghalaosimi-web',
          'https://mghalaosimi-web.vercel.app/',
          'https://www.credly.com/users/mohammed-ghaleb-al-aosimi',
          'https://orcid.org/0009-0000-6007-3170',
          'https://www.linkedin.com/in/mohammed-alaosimi-038155443/',
          'https://www.instagram.com/m.gh.al/',
          'https://www.tiktok.com/@m.gh.al1',
        ]),
      );

      // Verified links for Arfat
      expect(
        arfat.links.map((l) => l.url),
        containsAll(<String>[
          'mailto:alkamlyrfat@gmail.com',
          'https://github.com/arfat-alkamly',
          'https://arfat-phi.vercel.app',
        ]),
      );

      // Every configured link must be safe
      for (final founder in EdunivoraIdentity.founders) {
        expect(
          ExternalLinkService.isSafeExternalUri(
            Uri.tryParse(founder.websiteUrl),
          ),
          isTrue,
        );
        for (final link in founder.links) {
          expect(
            ExternalLinkService.isSafeExternalUri(Uri.tryParse(link.url)),
            isTrue,
            reason: 'Link ${link.id} must be safe',
          );
        }
      }
    });

    test(
      'never exposes Mohammed private email and keeps official channels pending',
      () {
        final mohammed = EdunivoraIdentity.mohammed;
        final emailPattern = RegExp(
          r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
        );
        expect(mohammed.publicEmail, isNull);
        expect(emailPattern.hasMatch(mohammed.bioAr), isFalse);
        expect(emailPattern.hasMatch(mohammed.bioEn), isFalse);
        for (final link in mohammed.links) {
          expect(link.kind, isNot(FounderLinkKind.email));
          expect(link.url.toLowerCase().contains('mailto:'), isFalse);
          expect(link.url.toLowerCase().contains('gmail.com'), isFalse);
          expect(emailPattern.hasMatch(link.url), isFalse);
          expect(emailPattern.hasMatch(link.displayValue), isFalse);
        }

        expect(EdunivoraIdentity.contactConfig.officialSupportEmail, isNull);
        expect(EdunivoraIdentity.contactConfig.officialWebsite, isNull);
        expect(EdunivoraIdentity.contactConfig.officialSocialLinks, isEmpty);
        expect(
          EdunivoraIdentity.contactConfig.verifiedFounderSupportEmail,
          'alkamlyrfat@gmail.com',
        );
      },
    );
  });

  group('ExternalLinkService', () {
    test(
      'isSafeExternalUri allows only https and mailto with valid targets',
      () {
        expect(
          ExternalLinkService.isSafeExternalUri(
            Uri.parse('https://github.com/mghalaosimi-web'),
          ),
          isTrue,
        );
        expect(
          ExternalLinkService.isSafeExternalUri(
            Uri.parse('https://arfat-phi.vercel.app/'),
          ),
          isTrue,
        );
        expect(
          ExternalLinkService.isSafeExternalUri(
            Uri.parse('mailto:alkamlyrfat@gmail.com'),
          ),
          isTrue,
        );
        expect(
          ExternalLinkService.isSafeExternalUri(
            Uri.parse('mailto:alkamlyrfat@gmail.com?subject=Hello'),
          ),
          isTrue,
        );

        // Rejected schemes and malformed URIs
        expect(ExternalLinkService.isSafeExternalUri(null), isFalse);
        expect(
          ExternalLinkService.isSafeExternalUri(
            Uri.parse('http://example.com'),
          ),
          isFalse,
        );
        expect(
          ExternalLinkService.isSafeExternalUri(
            Uri.parse('javascript:alert(1)'),
          ),
          isFalse,
        );
        expect(
          ExternalLinkService.isSafeExternalUri(
            Uri.parse('file:///etc/passwd'),
          ),
          isFalse,
        );
        expect(
          ExternalLinkService.isSafeExternalUri(Uri.parse('ftp://example.com')),
          isFalse,
        );
        expect(
          ExternalLinkService.isSafeExternalUri(Uri.parse('tel:+1234567890')),
          isFalse,
        );
        expect(
          ExternalLinkService.isSafeExternalUri(Uri.parse('https://')),
          isFalse,
        );
        expect(
          ExternalLinkService.isSafeExternalUri(Uri.parse('mailto:')),
          isFalse,
        );
        expect(ExternalLinkService.parseSafeExternalUri('   '), isNull);
        expect(
          ExternalLinkService.parseSafeExternalUri('http://insecure.test'),
          isNull,
        );
      },
    );

    test(
      'openUrlTestable opens valid URI and falls back to clipboard on failure',
      () async {
        final openedUris = <Uri>[];
        final copiedValues = <String>[];

        final ok = await ExternalLinkService.openUrlTestable(
          'https://mghalaosimi-web.vercel.app/',
          urlOpener: (uri) async {
            openedUris.add(uri);
            return true;
          },
          clipboardWriter: (text) async => copiedValues.add(text),
        );
        expect(ok, isTrue);
        expect(openedUris, hasLength(1));
        expect(copiedValues, isEmpty);

        final fallback = await ExternalLinkService.openUrlTestable(
          'mailto:alkamlyrfat@gmail.com',
          urlOpener: (_) async => false,
          clipboardWriter: (text) async => copiedValues.add(text),
        );
        expect(fallback, isFalse);
        expect(copiedValues, <String>['alkamlyrfat@gmail.com']);

        final thrownFallback = await ExternalLinkService.openUrlTestable(
          'https://github.com/arfat-alkamly',
          urlOpener: (_) async => throw Exception('No browser'),
          clipboardWriter: (text) async => copiedValues.add(text),
        );
        expect(thrownFallback, isFalse);
        expect(copiedValues.last, 'https://github.com/arfat-alkamly');

        // Unsafe URI never calls opener or clipboard
        var openerCalled = false;
        var clipboardCalled = false;
        final unsafe = await ExternalLinkService.openUrlTestable(
          'javascript:alert(1)',
          urlOpener: (_) async {
            openerCalled = true;
            return true;
          },
          clipboardWriter: (_) async {
            clipboardCalled = true;
          },
        );
        expect(unsafe, isFalse);
        expect(openerCalled, isFalse);
        expect(clipboardCalled, isFalse);
      },
    );
  });

  group('AboutScreen widget tests', () {
    testWidgets('renders both co-founders equally in Arabic RTL Light theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(home: const AboutScreen(), isArabic: true, isDark: false),
      );

      expect(find.text('الفريق والمؤسسون'), findsWidgets);
      expect(find.text('محمد غالب العصيمي'), findsOneWidget);
      expect(find.text('Mohammed Ghaleb Alaosimi'), findsOneWidget);
      expect(find.text('M.GH'), findsOneWidget);
      expect(find.text('M.GH.AL'), findsOneWidget);

      // Scroll down to render Arfat's card and footer
      await tester.scrollUntilVisible(
        find.text('عرفات الكاملي'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('عرفات الكاملي'), findsOneWidget);
      expect(find.text('Arfat Alkamly'), findsOneWidget);
      expect(find.text('AK'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byType(EduBrandFooter),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(EdunivoraIdentity.attribution), findsOneWidget);

      // Verify no email belonging to Mohammed is rendered anywhere
      final allTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ');
      expect(allTexts.toLowerCase().contains('alaosimi@'), isFalse);
    });

    testWidgets(
      'renders in English LTR Dark theme with both Visit Website buttons',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            home: const AboutScreen(),
            isArabic: false,
            isDark: true,
          ),
        );

        expect(find.text('Team & Founders'), findsWidgets);
        expect(find.text('Mohammed Ghaleb Alaosimi'), findsOneWidget);
        expect(find.text('Visit Website'), findsAtLeastNWidgets(1));

        await tester.scrollUntilVisible(
          find.text('Arfat Alkamly'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Arfat Alkamly'), findsOneWidget);
        expect(
          find.text('مؤسس ومشارك في التأسيس / Founder & Co-Founder'),
          findsAtLeastNWidgets(1),
        );
      },
    );
  });

  group('AboutAppScreen widget tests', () {
    testWidgets(
      'renders EduNivora sections and navigates to AboutScreen in Arabic RTL Dark',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            home: const AboutAppScreen(),
            isArabic: true,
            isDark: true,
          ),
        );

        expect(find.text('عن التطبيق'), findsOneWidget);
        expect(find.text('EduNivora'), findsWidgets);
        expect(find.text('نظرة عامة على المنتج'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('تعرّف على الفريق والمؤسسين'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('تعرّف على الفريق والمؤسسين'), findsOneWidget);

        await tester.tap(find.text('تعرّف على الفريق والمؤسسين'));
        await tester.pumpAndSettle();

        expect(find.byType(AboutScreen), findsOneWidget);
      },
    );

    testWidgets(
      'renders English LTR Light theme with capabilities, roadmap, and footer',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            home: const AboutAppScreen(),
            isArabic: false,
            isDark: false,
          ),
        );

        expect(find.text('About App'), findsOneWidget);
        expect(find.text('Product Overview'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Planned Future Development'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Planned Future Development'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.byType(EduBrandFooter),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(EdunivoraIdentity.attribution), findsOneWidget);
      },
    );
  });

  group('HelpCenterScreen widget tests', () {
    testWidgets(
      'expands FAQ categories and filters with empty state in Arabic RTL Light',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            home: const HelpCenterScreen(),
            isArabic: true,
            isDark: false,
          ),
        );

        expect(find.text('مركز المساعدة'), findsOneWidget);
        // First category is expanded by default
        expect(find.text('ما هو EduNivora؟'), findsOneWidget);

        // Scroll to Security category and tap to expand
        await tester.scrollUntilVisible(
          find.text('الأمان وقفل التطبيق'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('الأمان وقفل التطبيق'));
        await tester.pumpAndSettle();

        expect(
          find.text('كيف أفعّل قفل التطبيق برمز PIN أو البصمة؟'),
          findsOneWidget,
        );

        // Scroll back to search field and filter
        await tester.scrollUntilVisible(
          find.byType(TextField),
          -300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(find.byType(TextField), 'PIN');
        await tester.pumpAndSettle();

        expect(
          find.text('كيف أفعّل قفل التطبيق برمز PIN أو البصمة؟'),
          findsOneWidget,
        );

        // Search with no matches shows EduEmptyState
        await tester.enterText(find.byType(TextField), 'zzzz_no_match_999');
        await tester.pumpAndSettle();

        expect(find.byType(EduEmptyState), findsOneWidget);
        expect(find.text('لا توجد نتائج مطابقة'), findsOneWidget);

        // Tap reset button on empty state
        await tester.tap(find.text('إظهار جميع المواضيع'));
        await tester.pumpAndSettle();

        expect(find.byType(EduEmptyState), findsNothing);
        expect(find.text('ما هو EduNivora؟'), findsOneWidget);
      },
    );

    testWidgets('renders and searches in English LTR Dark theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: const HelpCenterScreen(),
          isArabic: false,
          isDark: true,
        ),
      );

      expect(find.text('Help Center'), findsOneWidget);
      expect(find.text('Getting Started'), findsOneWidget);
      expect(find.text('What is EduNivora?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'OTP');
      await tester.pumpAndSettle();

      expect(
        find.text('How does Email OTP verification work?'),
        findsOneWidget,
      );
    });
  });

  group('ContactScreen widget tests', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              return null;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets(
      'shows pending channels, founders, and validates form without fake submission in Arabic RTL',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            home: const ContactScreen(),
            isArabic: true,
            isDark: false,
          ),
        );

        expect(find.text('تواصل معنا'), findsOneWidget);
        expect(find.text('بانتظار اعتماد المالك'), findsNWidgets(3));

        // Scroll to form copy button and trigger empty validation
        await tester.scrollUntilVisible(
          find.text('نسخ التقرير للحافظة'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('نسخ التقرير للحافظة'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('نسخ التقرير للحافظة'));
        await tester.pumpAndSettle();

        expect(find.text('يرجى إدخال عنوان واضح للرسالة.'), findsOneWidget);
        expect(
          find.text('يرجى كتابة تفاصيل المشكلة أو الاقتراح.'),
          findsOneWidget,
        );

        // Fill valid inputs and copy structured report
        final fields = find.byType(TextFormField);
        await tester.ensureVisible(fields.at(1));
        await tester.enterText(fields.at(1), 'مشكلة اختبارية');
        await tester.ensureVisible(fields.at(2));
        await tester.enterText(
          fields.at(2),
          'هذا وصف تفصيلي كافٍ للتأكد من عمل التحقق ونسخ التقرير محلياً.',
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('نسخ التقرير للحافظة'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('نسخ التقرير للحافظة'));
        await tester.pumpAndSettle();

        expect(find.text('يرجى إدخال عنوان واضح للرسالة.'), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining('لا يوجد إرسال تلقائي للخادم'),
          findsOneWidget,
        );
      },
    );

    testWidgets('validates form in English LTR Dark theme', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: const ContactScreen(),
          isArabic: false,
          isDark: true,
        ),
      );

      expect(find.text('Contact Us'), findsOneWidget);
      expect(find.text('Pending owner approval'), findsNWidgets(3));

      await tester.scrollUntilVisible(
        find.text('Open Email Draft'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Open Email Draft'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Email Draft'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a subject.'), findsOneWidget);
      expect(find.text('Please enter your message details.'), findsOneWidget);
    });
  });

  group('PrivacyTermsScreen widget tests', () {
    testWidgets('displays draft banner and both tabs in Arabic RTL Dark theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: const PrivacyTermsScreen(),
          isArabic: true,
          isDark: true,
        ),
      );

      expect(find.text('الخصوصية والشروط'), findsOneWidget);
      expect(find.text('سياسة الخصوصية'), findsOneWidget);
      expect(find.text('شروط الاستخدام'), findsOneWidget);
      expect(find.byType(EduDraftBanner), findsOneWidget);
      expect(
        find.text(
          'مسودة — تتطلب مراجعة واعتماد المالك/الشؤون القانونية قبل النشر الرسمي',
        ),
        findsOneWidget,
      );
      expect(find.text('1. التخزين المحلي للبيانات (SQLite)'), findsOneWidget);

      // Switch to Terms of Use tab
      await tester.tap(find.text('شروط الاستخدام'));
      await tester.pumpAndSettle();

      expect(find.byType(EduDraftBanner), findsOneWidget);
      expect(find.text('1. نطاق الاستخدام'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byType(EduBrandFooter),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(EdunivoraIdentity.attribution), findsOneWidget);
    });

    testWidgets('displays English LTR Light theme tabs and draft banner', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: const PrivacyTermsScreen(),
          isArabic: false,
          isDark: false,
        ),
      );

      expect(find.text('Privacy & Terms'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Use'), findsOneWidget);
      expect(
        find.text(
          'Draft — Requires owner/legal review and approval before official publication',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Terms of Use'));
      await tester.pumpAndSettle();

      expect(find.text('1. Scope of Use'), findsOneWidget);
    });
  });

  group('SettingsScreen widget & navigation tests', () {
    testWidgets(
      'renders all 5 App Info & Support links and navigates to every screen',
      (tester) async {
        bool? lastTheme;
        bool? lastLang;

        await tester.pumpWidget(
          _buildTestApp(
            home: SettingsScreen(
              isDarkMode: false,
              onThemeChanged: (v) => lastTheme = v,
              isArabic: true,
              onLanguageChanged: (v) => lastLang = v,
            ),
            isArabic: true,
            isDark: false,
          ),
        );

        expect(find.text('الإعدادات'), findsOneWidget);
        expect(find.text('معلومات التطبيق والدعم'), findsOneWidget);

        // Toggle dark mode and language callbacks
        await tester.tap(find.text('الوضع الداكن'));
        await tester.pumpAndSettle();
        expect(lastTheme, isTrue);

        await tester.tap(find.text('اللغة العربية'));
        await tester.pumpAndSettle();
        expect(lastLang, isFalse);

        // Toggle back to Arabic so Arabic labels are active for navigation checks
        await tester.tap(find.text('Arabic Language'));
        await tester.pumpAndSettle();
        expect(lastLang, isTrue);

        final targets = <String, Type>{
          'عن التطبيق': AboutAppScreen,
          'الفريق والمؤسسون': AboutScreen,
          'مركز المساعدة': HelpCenterScreen,
          'تواصل معنا': ContactScreen,
          'الخصوصية والشروط': PrivacyTermsScreen,
        };

        for (final entry in targets.entries) {
          await tester.scrollUntilVisible(
            find.text(entry.key),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(find.text(entry.key));
          await tester.pumpAndSettle();
          expect(find.text(entry.key), findsOneWidget);

          await tester.tap(find.text(entry.key));
          await tester.pumpAndSettle();

          expect(find.byType(entry.value), findsOneWidget);

          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
        }

        // Verify footer present at bottom of SettingsScreen
        await tester.scrollUntilVisible(
          find.byType(EduBrandFooter),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(EdunivoraIdentity.attribution), findsOneWidget);
      },
    );

    testWidgets('renders English LTR Dark theme labels', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: SettingsScreen(
            isDarkMode: true,
            onThemeChanged: (_) {},
            isArabic: false,
          ),
          isArabic: false,
          isDark: true,
        ),
      );

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('App Info & Support'), findsOneWidget);
      expect(find.text('About EduNivora'), findsOneWidget);
      expect(find.text('Team & Founders'), findsOneWidget);
      expect(find.text('Help Center'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Privacy & Terms'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Contact Us'), findsOneWidget);
      expect(find.text('Privacy & Terms'), findsOneWidget);
    });
  });

  group('LoginScreen branding & guest flow', () {
    testWidgets(
      'displays EduNivora branding and official tagline instead of AcademicOS',
      (tester) async {
        final repo = _StubAuthRepository();
        final authUseCases = AuthUseCases(
          loginWithUsername: LoginWithUsernameUseCase(repo),
          loginWithEmail: LoginWithEmailUseCase(repo),
          registerLocalUser: RegisterLocalUserUseCase(repo),
          registerCloudUser: RegisterCloudUserUseCase(repo),
          verifyEmailOtp: VerifyEmailOtpUseCase(repo),
          resendEmailVerificationOtp: ResendEmailVerificationOtpUseCase(repo),
          getCloudAccessToken: GetCloudAccessTokenUseCase(repo),
          loginWithGoogle: LoginWithGoogleUseCase(repo),
          loginWithCachedGoogleAccount: LoginWithCachedGoogleAccountUseCase(
            repo,
          ),
          isLoggedIn: IsLoggedInUseCase(repo),
          getCurrentUser: GetCurrentUserUseCase(repo),
          logout: LogoutUseCase(repo),
        );

        var guestTapped = false;
        await tester.pumpWidget(
          _buildTestApp(
            home: LoginScreen(
              authUseCases: authUseCases,
              onLoginSuccess: () async {},
              onContinueAsGuest: () async {
                guestTapped = true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('EduNivora'), findsOneWidget);
        expect(find.text('The Intelligent Academic Ecosystem'), findsOneWidget);
        expect(find.text('AcademicOS'), findsNothing);
        expect(find.text('Academic OS'), findsNothing);

        final guestButton = find.text('المتابعة كزائر');
        await tester.scrollUntilVisible(
          guestButton,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(guestButton);
        await tester.pumpAndSettle();
        expect(guestTapped, isTrue);
      },
    );
  });
}

class _StubAuthRepository implements AuthRepository {
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
  Future<bool> loginWithUsername(String username, String password) async =>
      true;

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
