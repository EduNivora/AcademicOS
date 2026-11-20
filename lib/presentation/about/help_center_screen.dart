import 'package:flutter/material.dart';
import '../../core/config/edunivora_identity.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/edunivora_ui.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static const List<_HelpCategoryData> _categories = <_HelpCategoryData>[
    _HelpCategoryData(
      id: 'getting_started',
      icon: Icons.rocket_launch_rounded,
      color: AppTheme.primary,
      title: LocalizedCopy(ar: 'البداية مع EduNivora', en: 'Getting Started'),
      subtitle: LocalizedCopy(
        ar: 'تعرّف على التطبيق وطريقة البدء السريع',
        en: 'Learn the basics and start organizing quickly',
      ),
      items: <_HelpFaqItem>[
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'ما هو EduNivora؟',
            en: 'What is EduNivora?',
          ),
          answer: LocalizedCopy(
            ar: 'EduNivora هو تطبيق أكاديمي يعمل بنهج الأولوية للعمل دون اتصال (Offline-First) لإدارة المهام الدراسية، المقررات، ملفات PDF، الجدول الأسبوعي، خطط الاختبارات، المعدل التراكمي، مؤقت التركيز، والتقارير الأكاديمية.',
            en: 'EduNivora is an offline-first academic app for managing study tasks, courses and PDFs, weekly schedules, exam plans, GPA simulation, focus timers, and academic reports.',
          ),
        ),
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'كيف أبدأ الاستخدام؟',
            en: 'How do I get started?',
          ),
          answer: LocalizedCopy(
            ar: 'من بوابة الدخول يمكنك إنشاء حساب سحابي أو محلي، أو تسجيل الدخول عبر Google، أو اختيار الدخول كضيف للاستخدام المحلي الفوري وإضافة مقرراتك ومهامك مباشرةً.',
            en: 'From the sign-in screen you can create an account, sign in with Google, or continue as a guest to immediately use local features and add your courses and tasks.',
          ),
        ),
      ],
    ),
    _HelpCategoryData(
      id: 'account_auth',
      icon: Icons.verified_user_rounded,
      color: AppTheme.primaryStrong,
      title: LocalizedCopy(
        ar: 'الحساب والمصادقة',
        en: 'Account & Authentication',
      ),
      subtitle: LocalizedCopy(
        ar: 'إنشاء الحساب، تسجيل الدخول، OTP، وملاحظة استعادة كلمة المرور',
        en: 'Registration, Email/Username & Google sign-in, OTP, and password note',
      ),
      items: <_HelpFaqItem>[
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'كيف أنشئ حساباً جديداً؟',
            en: 'How do I create a new account?',
          ),
          answer: LocalizedCopy(
            ar: 'افتح شاشة إنشاء الحساب من بوابة الدخول، ثم أدخل بياناتك المطلوبة وبريدك الإلكتروني وكلمة المرور وتأكيدها. للحسابات السحابية عبر Neon Auth ستُرسل رسالة تحتوي على رمز تحقق (OTP) إلى بريدك الإلكتروني.',
            en: 'Open the registration screen from the sign-in gate and enter your details, email, and matching password. For Neon Auth cloud accounts, an email verification OTP will be sent to your inbox.',
          ),
        ),
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'كيف أسجل الدخول بالبريد الإلكتروني أو اسم المستخدم أو Google؟',
            en: 'How do Email/Username and Google Sign-In work?',
          ),
          answer: LocalizedCopy(
            ar: 'يمكنك تسجيل الدخول بإدخال البريد الإلكتروني (للحساب السحابي) أو اسم المستخدم (للحساب المحلي) مع كلمة المرور، أو الضغط على خيار تسجيل الدخول عبر Google لإتمام المصادقة الآمنة.',
            en: 'Sign in using your email (cloud account) or username (local account) with your password, or choose Google Sign-In for quick OAuth authentication.',
          ),
        ),
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'كيف أتحقق من البريد الإلكتروني (OTP)؟',
            en: 'How does Email OTP verification work?',
          ),
          answer: LocalizedCopy(
            ar: 'بعد إنشاء الحساب السحابي، افتح صندوق الوارد (أو مجلد الرسائل غير المرغوب فيها Spam) وأدخل رمز التحقق في شاشة التحقق من البريد. يمكنك أيضاً طلب إعادة إرسال الرمز من نفس الشاشة.',
            en: 'After creating a cloud account, check your inbox (or spam folder) and enter the verification code on the Email Verification screen. You can also request a resend from the same screen.',
          ),
        ),
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'ملاحظة حول استعادة كلمة المرور',
            en: 'Password recovery note',
          ),
          answer: LocalizedCopy(
            ar: 'في الإصدار الحالي v1.0.0+2 لا تتوفر شاشة استعادة كلمة مرور آلية داخل التطبيق. للحسابات المرتبطة بـ Google تتم إدارة كلمة المرور عبر إعدادات حساب Google الخاص بك، أما للحسابات المحلية فبياناتك محفوظة على جهازك ويمكنك التواصل عبر صفحة "تواصل معنا" عند الحاجة للمساعدة.',
            en: 'In v1.0.0+2, an automated in-app password reset flow is not yet implemented. For Google-linked accounts, manage your password via your Google Account settings; for local accounts, data remains stored on your device and you can reach out via Contact Us if you need guidance.',
          ),
        ),
      ],
    ),
    _HelpCategoryData(
      id: 'profile',
      icon: Icons.person_outline_rounded,
      color: Colors.teal,
      title: LocalizedCopy(
        ar: 'إدارة الملف الشخصي والمظهر',
        en: 'Profile & Preferences',
      ),
      subtitle: LocalizedCopy(
        ar: 'بيانات الطالب، اللغة، والوضع الفاتح والداكن',
        en: 'Student info, Arabic/English language, and Light/Dark themes',
      ),
      items: <_HelpFaqItem>[
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'كيف أعدل بيانات الملف الشخصي؟',
            en: 'How do I edit my student profile?',
          ),
          answer: LocalizedCopy(
            ar: 'من الشاشة الرئيسية أو القائمة الجانبية يمكنك تحديث اسم الطالب وبياناته الأكاديمية المحفوظة محلياً على جهازك.',
            en: 'From the Home screen or navigation drawer, you can update your student display name and academic profile details saved locally on your device.',
          ),
        ),
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'كيف أبدّل اللغة أو الوضع الداكن؟',
            en: 'How do I switch language or Dark Mode?',
          ),
          answer: LocalizedCopy(
            ar: 'يمكنك التبديل بين اللغة العربية والإنجليزية وبين الوضع الفاتح والوضع الداكن من شاشة الإعدادات أو القائمة الجانبية.',
            en: 'Switch between Arabic and English as well as Light and Dark themes from Settings or the navigation drawer.',
          ),
        ),
      ],
    ),
    _HelpCategoryData(
      id: 'modules',
      icon: Icons.apps_rounded,
      color: AppTheme.success,
      title: LocalizedCopy(ar: 'وحدات التطبيق', en: 'App Modules'),
      subtitle: LocalizedCopy(
        ar: 'المهام، المقررات، الجدول، الاختبارات، المعدل، التركيز، المساعد، التقارير، والإعلانات',
        en: 'Tasks, Courses, Schedule, Exams, GPA, Focus, Local AI, Reports & Notices',
      ),
      items: <_HelpFaqItem>[
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'المهام والتذكيرات (Tasks)',
            en: 'Tasks & Reminders',
          ),
          answer: LocalizedCopy(
            ar: 'أضف واجباتك ومشاريعك مع الأولوية وتاريخ التسليم والتذكيرات المحلية، وتابع حالتها وإنجازها من الشاشة الرئيسية.',
            en: 'Create assignments and projects with priority, due dates, and local notifications, and track completion from Home.',
          ),
        ),
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'المقررات والملفات وعارض PDF (Courses)',
            en: 'Courses, Materials & PDF Viewer',
          ),
          answer: LocalizedCopy(
            ar: 'أنشئ مقرراتك الدراسية واربط بها الفصول الأكاديمية والمهام وملفات المذاكرة مع إمكانية فتح ملفات PDF داخل التطبيق.',
            en: 'Organize courses by academic term, link tasks and study attachments, and open lecture PDFs with the built-in viewer.',
          ),
        ),
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'الجدول الأسبوعي (Weekly Schedule)',
            en: 'Weekly Schedule',
          ),
          answer: LocalizedCopy(
            ar: 'رتّب أوقات محاضراتك ومعاملك على أيام الأسبوع لمراجعة جدولك اليومي بسهولة.',
            en: 'Organize lectures and labs across weekdays to keep your daily schedule clear.',
          ),
        ),
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'خطط الاختبارات ومخطط الدراسة (Exams & Study Planner)',
            en: 'Exams & Study Planner',
          ),
          answer: LocalizedCopy(
            ar: 'أنشئ خطط مراجعة لاختباراتك القادمة ووزّع مهام المذاكرة قبل موعد كل امتحان.',
            en: 'Build revision plans for upcoming exams and break study goals into actionable sessions.',
          ),
        ),
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'حاسبة المعدل ومحاكاة توزيع الدرجات (GPA & Grade Simulator)',
            en: 'GPA Calculator & Grade Simulator',
          ),
          answer: LocalizedCopy(
            ar: 'احسب معدلك الفصلي والتراكمي وجرّب توزيع درجات أعمال السنة والاختبار النهائي لكل مقرر.',
            en: 'Calculate semester and cumulative GPA and simulate course grade distributions.',
          ),
        ),
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'مؤقت التركيز (Focus Timer)',
            en: 'Focus Timer',
          ),
          answer: LocalizedCopy(
            ar: 'استخدم جلسات التركيز المنظمة مع فترات الراحة لتحسين إنتاجيتك أثناء المذاكرة.',
            en: 'Run timed study and break intervals to stay focused during study sessions.',
          ),
        ),
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'المساعد الأكاديمي المحلي (Local AI Assistant)',
            en: 'Local AI Assistant',
          ),
          answer: LocalizedCopy(
            ar: 'مساعد محلي داخل التطبيق يقدم إرشادات سريعة لتنظيم الدراسة والمهام دون الحاجة لإرسال بياناتك لخادم خارجي.',
            en: 'An on-device academic helper providing study organization tips without sending your personal study data to an external AI server.',
          ),
        ),
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'التقارير الأكاديمية والإعلانات (Reports & Announcements)',
            en: 'Academic Reports & Announcements',
          ),
          answer: LocalizedCopy(
            ar: 'استعرض ملخصات إنجازك الأكاديمي وتقاريرك الدراسية، وتابع الإعلانات السحابية عند توفر اتصال بالإنترنت.',
            en: 'Review visual summaries of task completion and academic progress, and check cloud announcements when online.',
          ),
        ),
      ],
    ),
    _HelpCategoryData(
      id: 'navigation',
      icon: Icons.explore_outlined,
      color: Colors.indigo,
      title: LocalizedCopy(
        ar: 'دليل التنقل في التطبيق',
        en: 'Navigation Guide',
      ),
      subtitle: LocalizedCopy(
        ar: 'كيف تصل بسرعة إلى الشاشات والأدوات',
        en: 'How to move quickly across screens and tools',
      ),
      items: <_HelpFaqItem>[
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'أين أجد الوحدات والإعدادات؟',
            en: 'Where do I find modules and settings?',
          ),
          answer: LocalizedCopy(
            ar: 'استخدم القائمة الجانبية (Drawer) في الشاشة الرئيسية للوصول إلى المقررات، الجدول، مؤقت التركيز، التقارير، المساعد المحلي، والإعدادات. ومن شاشة الإعدادات يمكنك الوصول إلى قفل التطبيق، عن التطبيق، الفريق والمؤسسين، مركز المساعدة، تواصل معنا، والخصوصية والشروط.',
            en: 'Use the Home screen navigation drawer to open Courses, Schedule, Focus Timer, Reports, Local AI, and Settings. Inside Settings you can access App Lock, About App, Team & Founders, Help Center, Contact Us, and Privacy & Terms.',
          ),
        ),
      ],
    ),
    _HelpCategoryData(
      id: 'security',
      icon: Icons.lock_outline_rounded,
      color: AppTheme.warning,
      title: LocalizedCopy(
        ar: 'الأمان وقفل التطبيق',
        en: 'Security & App Lock',
      ),
      subtitle: LocalizedCopy(
        ar: 'رمز PIN، البصمة، والعمل دون اتصال',
        en: 'PIN lock, Biometrics, and offline data storage',
      ),
      items: <_HelpFaqItem>[
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'كيف أفعّل قفل التطبيق برمز PIN أو البصمة؟',
            en: 'How do I enable PIN or Biometric App Lock?',
          ),
          answer: LocalizedCopy(
            ar: 'انتقل إلى الإعدادات ثم إعدادات قفل التطبيق لتعيين رمز PIN وتفعيل المصادقة الحيوية (البصمة/الوجه) على الأجهزة المدعومة.',
            en: 'Open Settings and go to App Lock Settings to configure a PIN and enable biometric unlock on supported devices.',
          ),
        ),
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'هل البيانات محفوظة على الجهاز وهل يعمل التطبيق بدون إنترنت؟',
            en: 'Is data stored locally and does the app work offline?',
          ),
          answer: LocalizedCopy(
            ar: 'نعم، تُحفظ المهام والمقررات والجدول وحسابات المعدل محلياً في SQLite وتعمل الوظائف الأساسية بالكامل دون إنترنت. يلزم الإنترنت فقط للمصادقة السحابية (Neon Auth / Google) وتحميل الإعلانات السحابية.',
            en: 'Yes. Tasks, courses, schedules, and GPA data are stored locally in SQLite and core features work offline. Internet is only needed for optional cloud auth (Neon Auth / Google) and cloud announcements.',
          ),
        ),
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'كيف أسجل خروجاً من حسابي؟',
            en: 'How do I sign out?',
          ),
          answer: LocalizedCopy(
            ar: 'من شاشة الإعدادات اختر "تسجيل الخروج" وأكّد العملية لإنهاء الجلسة الحالية بأمان.',
            en: 'Open Settings, tap Sign Out, and confirm to safely end your current session.',
          ),
        ),
      ],
    ),
    _HelpCategoryData(
      id: 'troubleshooting',
      icon: Icons.build_circle_outlined,
      color: AppTheme.danger,
      title: LocalizedCopy(ar: 'استكشاف الأخطاء', en: 'Troubleshooting'),
      subtitle: LocalizedCopy(
        ar: 'حلول عملية للمشكلات الشائعة',
        en: 'Quick fixes for common issues',
      ),
      items: <_HelpFaqItem>[
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'لم يصل رمز التحقق (OTP) أو فشل تسجيل الدخول السحابي؟',
            en: 'Did not receive OTP or cloud sign-in failed?',
          ),
          answer: LocalizedCopy(
            ar: 'تأكد من اتصال الإنترنت وصحة البريد الإلكتروني وافحص مجلد الرسائل غير المرغوب فيها (Spam)، ثم جرّب إعادة إرسال الرمز أو تسجيل الدخول مرة أخرى.',
            en: 'Verify your internet connection and email address, check your Spam folder, and try resending the verification code.',
          ),
        ),
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'البصمة لا تعمل عند فتح التطبيق؟',
            en: 'Biometric unlock is not prompting?',
          ),
          answer: LocalizedCopy(
            ar: 'تأكد من تفعيل البصمة في إعدادات أمان جهازك نفسه، واستخدم رمز PIN كبديل فوري لفتح التطبيق.',
            en: 'Ensure biometrics are enrolled in your device system security settings, and use your configured PIN as an immediate fallback.',
          ),
        ),
        _HelpFaqItem(
          question: LocalizedCopy(
            ar: 'الروابط الخارجية لا تفتح متصفحاً على جهازي؟',
            en: 'External links do not open in a browser?',
          ),
          answer: LocalizedCopy(
            ar: 'في حال عدم توفر متصفح أو تطبيق بريد متوافق، ينسخ EduNivora الرابط تلقائياً إلى الحافظة ويعرض لك إشعاراً لتتمكن من لصقه مباشرةً.',
            en: 'If no compatible browser or email client is available, EduNivora automatically copies the link to your clipboard and notifies you.',
          ),
        ),
      ],
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_HelpCategoryData> _filteredCategories(bool isArabic) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _categories;

    final matched = <_HelpCategoryData>[];
    for (final category in _categories) {
      final titleMatches =
          category.title.ar.toLowerCase().contains(q) ||
          category.title.en.toLowerCase().contains(q);
      if (titleMatches) {
        matched.add(category);
        continue;
      }

      final matchingItems = category.items.where((item) {
        return item.question.ar.toLowerCase().contains(q) ||
            item.question.en.toLowerCase().contains(q) ||
            item.answer.ar.toLowerCase().contains(q) ||
            item.answer.en.toLowerCase().contains(q);
      }).toList();

      if (matchingItems.isNotEmpty) {
        matched.add(
          _HelpCategoryData(
            id: category.id,
            icon: category.icon,
            color: category.color,
            title: category.title,
            subtitle: category.subtitle,
            items: matchingItems,
          ),
        );
      }
    }
    return matched;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = isArabicLocale(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filteredCategories(isArabic);

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'مركز المساعدة' : 'Help Center'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1D4ED8),
                  Color(0xFF0EA5E9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.24),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.help_center_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                const SizedBox(height: 10),
                Text(
                  isArabic
                      ? 'دليل استخدام ${EdunivoraIdentity.appName}'
                      : '${EdunivoraIdentity.appName} Help Guide',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isArabic
                      ? 'ابحث في الأسئلة الشائعة ودليل الميزات الفعلية المتوفرة في التطبيق.'
                      : 'Search FAQs and guides covering the actual features implemented in the app.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: isArabic
                  ? 'ابحث في المساعدة والأسئلة الشائعة...'
                  : 'Search help topics and FAQs...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                      tooltip: isArabic ? 'مسح البحث' : 'Clear search',
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            EduEmptyState(
              icon: Icons.search_off_rounded,
              title: isArabic
                  ? 'لا توجد نتائج مطابقة'
                  : 'No matching help topics',
              description: isArabic
                  ? 'جرّب كلمات مفتاحية أخرى مثل: المهام، المقررات، PIN، أو Google.'
                  : 'Try another keyword such as tasks, courses, PIN, or Google.',
              actionLabel: isArabic ? 'إظهار جميع المواضيع' : 'Show all topics',
              onAction: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            )
          else
            ...filtered.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == filtered.length - 1 ? 0 : 12,
                ),
                child: _HelpCategoryCard(
                  category: category,
                  isArabic: isArabic,
                  isDark: isDark,
                  initiallyExpanded: _query.trim().isNotEmpty || index == 0,
                ),
              );
            }),
          const SizedBox(height: 20),
          const EduBrandFooter(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _HelpFaqItem {
  final LocalizedCopy question;
  final LocalizedCopy answer;

  const _HelpFaqItem({required this.question, required this.answer});
}

class _HelpCategoryData {
  final String id;
  final IconData icon;
  final Color color;
  final LocalizedCopy title;
  final LocalizedCopy subtitle;
  final List<_HelpFaqItem> items;

  const _HelpCategoryData({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.items,
  });
}

class _HelpCategoryCard extends StatelessWidget {
  final _HelpCategoryData category;
  final bool isArabic;
  final bool isDark;
  final bool initiallyExpanded;

  const _HelpCategoryCard({
    required this.category,
    required this.isArabic,
    required this.isDark,
    required this.initiallyExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isDark
        ? const Color(0xFF1E293B)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.7);
    final innerSurface = isDark
        ? const Color(0xFF0F172A)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
    final mutedText = isDark ? AppTheme.textMuted : const Color(0xFF64748B);
    final answerColor = isDark
        ? AppTheme.textSecondary
        : const Color(0xFF475569);

    return EduSurfaceCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>(
            '${category.id}_${initiallyExpanded ? 'open' : 'closed'}',
          ),
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(category.icon, color: category.color, size: 22),
          ),
          title: Text(
            category.title.resolve(isArabic),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 15.5,
            ),
          ),
          subtitle: Text(
            category.subtitle.resolve(isArabic),
            style: theme.textTheme.bodySmall?.copyWith(
              color: mutedText,
              fontSize: 12.5,
            ),
          ),
          children: [
            Divider(color: borderColor, height: 18),
            ...category.items.asMap().entries.map((entry) {
              final itemIndex = entry.key;
              final item = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: itemIndex == category.items.length - 1 ? 0 : 10,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: innerSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.question.resolve(isArabic),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.answer.resolve(isArabic),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: answerColor,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
