import 'package:flutter/material.dart';
import '../../core/config/edunivora_identity.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/edunivora_ui.dart';

class PrivacyTermsScreen extends StatelessWidget {
  const PrivacyTermsScreen({super.key});

  static const LocalizedCopy _draftBannerCopy = LocalizedCopy(
    ar: 'مسودة — تتطلب مراجعة واعتماد المالك/الشؤون القانونية قبل النشر الرسمي',
    en: 'Draft — Requires owner/legal review and approval before official publication',
  );

  @override
  Widget build(BuildContext context) {
    final isArabic = isArabicLocale(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'الخصوصية والشروط' : 'Privacy & Terms'),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: AppTheme.accentGlow,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            tabs: [
              Tab(text: isArabic ? 'سياسة الخصوصية' : 'Privacy Policy'),
              Tab(text: isArabic ? 'شروط الاستخدام' : 'Terms of Use'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PrivacyTab(isArabic: isArabic),
            _TermsTab(isArabic: isArabic),
          ],
        ),
      ),
    );
  }
}

class _PrivacyTab extends StatelessWidget {
  final bool isArabic;

  const _PrivacyTab({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        EduDraftBanner(
          message: PrivacyTermsScreen._draftBannerCopy.resolve(isArabic),
        ),
        const SizedBox(height: 16),
        _LegalSectionCard(
          icon: Icons.storage_rounded,
          iconColor: AppTheme.success,
          title: isArabic
              ? '1. التخزين المحلي للبيانات (SQLite)'
              : '1. Local Data Storage (SQLite)',
          body: isArabic
              ? 'يحفظ EduNivora بياناتك الدراسية الأساسية (المهام، المقررات، الجدول الأسبوعي، خطط الاختبارات، وحسابات المعدل) محلياً على جهازك باستخدام قاعدة بيانات SQLite لتعمل دون اتصال بالإنترنت. ملاحظة شفافة: قاعدة بيانات SQLite المحلية غير مشفرة حالياً في وضع السكون، بينما تُحفظ بيانات الجلسة والإعدادات الحساسة عبر التخزين الآمن في النظام (Secure Storage).'
              : 'EduNivora stores your core study data (tasks, courses, weekly schedule, exam plans, and GPA records) locally on your device in SQLite for offline-first access. Transparency note: the local SQLite database file is not currently encrypted at rest, while sensitive auth tokens and security preferences use platform Secure Storage.',
        ),
        const SizedBox(height: 12),
        _LegalSectionCard(
          icon: Icons.cloud_outlined,
          iconColor: AppTheme.primary,
          title: isArabic
              ? '2. المصادقة السحابية الاختيارية والإعلانات'
              : '2. Optional Cloud Auth & Announcements',
          body: isArabic
              ? 'يمكنك استخدام التطبيق في وضع الضيف محلياً، أو اختيار إنشاء حساب سحابي عبر Neon Auth (البريد الإلكتروني مع رمز التحقق OTP أو تسجيل الدخول عبر Google) وتلقي الإعلانات السحابية. لا يبيع EduNivora بياناتك ولا يشاركها مع شبكات إعلانية أو أطراف ثالثة غير لازمة لخدمة المصادقة.'
              : 'You may use EduNivora locally as a guest, or optionally sign in with Neon Auth (email/OTP verification or Google Sign-In) and view cloud announcements. EduNivora does not sell your data or share it with advertising networks.',
        ),
        const SizedBox(height: 12),
        _LegalSectionCard(
          icon: Icons.manage_accounts_outlined,
          iconColor: AppTheme.primaryStrong,
          title: isArabic
              ? '3. تحكم المستخدم وحذف البيانات'
              : '3. User Control & Data Deletion',
          body: isArabic
              ? 'يمكنك تعديل أو حذف مهامك ومقرراتك في أي وقت من داخل التطبيق، كما يمكنك مسح البيانات المحلية من شاشة الإعدادات أو عبر إلغاء تثبيت التطبيق من جهازك.'
              : 'You can edit or delete your tasks and courses inside the app at any time, or clear local data from Settings or by uninstalling the app.',
        ),
        const SizedBox(height: 12),
        _LegalSectionCard(
          icon: Icons.security_rounded,
          iconColor: AppTheme.warning,
          title: isArabic
              ? '4. إرشادات أمان الحساب والجلسة'
              : '4. Account & Session Security Guidance',
          body: isArabic
              ? '• استخدم كلمة مرور قوية وفريدة ولا تشارك رموز التحقق (OTP) مع أي شخص.\n'
                    '• فعّل قفل التطبيق برمز PIN أو البصمة الحيوية من إعدادات الأمان لحماية بياناتك على الجهاز.\n'
                    '• احرص على تسجيل الخروج عند استخدام جهاز مشترك، وحافظ على تحديث نظام التشغيل والتطبيق.'
              : '• Use a strong, unique password and never share email OTP verification codes.\n'
                    '• Enable PIN or Biometric App Lock in Security Settings to protect on-device access.\n'
                    '• Sign out when using a shared device and keep your OS and app updated.',
        ),
        const SizedBox(height: 18),
        const EduBrandFooter(),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _TermsTab extends StatelessWidget {
  final bool isArabic;

  const _TermsTab({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        EduDraftBanner(
          message: PrivacyTermsScreen._draftBannerCopy.resolve(isArabic),
        ),
        const SizedBox(height: 16),
        _LegalSectionCard(
          icon: Icons.description_outlined,
          iconColor: AppTheme.primary,
          title: isArabic ? '1. نطاق الاستخدام' : '1. Scope of Use',
          body: isArabic
              ? 'تطبيق EduNivora مخصص للأغراض التعليمية والأكاديمية الشخصية لمساعدة الطلاب على تنظيم دراستهم ومقرراتهم ومواعيدهم. استخدامك للتطبيق يعني التزامك بهذه المسودة لحين اعتماد النسخة القانونية النهائية.'
              : 'EduNivora is provided for personal academic and educational organization. By using the app, you agree to abide by these draft terms until the finalized legal version is officially published.',
        ),
        const SizedBox(height: 12),
        _LegalSectionCard(
          icon: Icons.person_pin_outlined,
          iconColor: AppTheme.primaryStrong,
          title: isArabic
              ? '2. مسؤولية المستخدم وأمان الجلسة'
              : '2. User Responsibility & Session Safety',
          body: isArabic
              ? 'يتحمل المستخدم مسؤولية دقة البيانات والمواعيد المدخلة، وحفظ سرية بيانات حسابه ورمز PIN، والتحقق من مواعيد الاختبارات والتسليمات الرسمية لدى مؤسسته التعليمية.'
              : 'You are responsible for the accuracy of entered deadlines and grades, safeguarding your login credentials and PIN, and verifying official academic deadlines with your institution.',
        ),
        const SizedBox(height: 12),
        _LegalSectionCard(
          icon: Icons.copyright_rounded,
          iconColor: AppTheme.success,
          title: isArabic ? '3. الملكية الفكرية' : '3. Intellectual Property',
          body: isArabic
              ? 'جميع حقوق الاسم ${EdunivoraIdentity.appName} والتصميم والبرمجيات محفوظة للمؤسسين (محمد غالب العصيمي وعرفات الكاملي). لا يجوز إعادة التوزيع أو الاستغلال التجاري دون إذن مسبق.'
              : 'All rights to the ${EdunivoraIdentity.appName} name, design, and software belong to its co-founders (Mohammed Ghaleb Alaosimi & Arfat Alkamly). Unauthorized commercial redistribution is prohibited.',
        ),
        const SizedBox(height: 12),
        _LegalSectionCard(
          icon: Icons.shield_outlined,
          iconColor: AppTheme.warning,
          title: isArabic
              ? '4. حدود المسؤولية والنسخ الاحتياطي'
              : '4. Limitation of Liability & Backups',
          body: isArabic
              ? 'يُقدَّم التطبيق "كما هو" لدعم التنظيم الدراسي. نظراً لاعتماد التخزين المحلي في الإصدار v${EdunivoraIdentity.versionDisplay}، لا يتحمل المؤسسون مسؤولية فقدان البيانات عند حذف التطبيق أو تلف الجهاز.'
              : 'The app is provided "as is" for academic productivity. Because v${EdunivoraIdentity.versionDisplay} relies primarily on local device storage, the founders are not liable for data loss caused by app removal or device failure.',
        ),
        const SizedBox(height: 12),
        _LegalSectionCard(
          icon: Icons.update_rounded,
          iconColor: Colors.teal,
          title: isArabic
              ? '5. التحديثات والمراجعة القانونية'
              : '5. Updates & Legal Review',
          body: isArabic
              ? 'تخضع هذه المسودة للمراجعة والاعتماد قبل النشر الرسمي، وسيُحدَّث محتواها داخل التطبيق عند إصدار النسخة المعتمدة أو عند إضافة ميزات جديدة.'
              : 'This draft is subject to formal owner and legal review prior to official release. Updates will be reflected directly within this screen.',
        ),
        const SizedBox(height: 18),
        const EduBrandFooter(),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _LegalSectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  const _LegalSectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bodyColor = isDark ? AppTheme.textSecondary : const Color(0xFF475569);

    return EduSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: bodyColor,
              fontSize: 13.5,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}
