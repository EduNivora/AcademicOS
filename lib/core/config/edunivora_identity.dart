class LocalizedCopy {
  final String ar;
  final String en;

  const LocalizedCopy({required this.ar, required this.en});

  String resolve(bool isArabic) => isArabic ? ar : en;
}

enum FounderLinkKind {
  github,
  website,
  linkedin,
  credly,
  orcid,
  instagram,
  tiktok,
  email,
}

class FounderLink {
  final String id;
  final FounderLinkKind kind;
  final String labelAr;
  final String labelEn;
  final String url;
  final String displayValue;

  const FounderLink({
    required this.id,
    required this.kind,
    required this.labelAr,
    required this.labelEn,
    required this.url,
    required this.displayValue,
  });

  String label(bool isArabic) => isArabic ? labelAr : labelEn;
}

class FounderProfile {
  final String id;
  final String initials;
  final String arabicName;
  final String englishName;
  final String roleAr;
  final String roleEn;
  final String? brand;
  final List<String> titles;
  final String bioAr;
  final String bioEn;
  final String? publicEmail;
  final String websiteUrl;
  final List<FounderLink> links;

  const FounderProfile({
    required this.id,
    required this.initials,
    required this.arabicName,
    required this.englishName,
    required this.roleAr,
    required this.roleEn,
    required this.titles,
    required this.bioAr,
    required this.bioEn,
    required this.websiteUrl,
    required this.links,
    this.brand,
    this.publicEmail,
  });

  String role(bool isArabic) => isArabic ? roleAr : roleEn;

  String bio(bool isArabic) => isArabic ? bioAr : bioEn;

  String primaryName(bool isArabic) => isArabic ? arabicName : englishName;

  String secondaryName(bool isArabic) => isArabic ? englishName : arabicName;
}

class EduContactConfig {
  final String? officialSupportEmail;
  final String? officialWebsite;
  final List<FounderLink> officialSocialLinks;
  final String verifiedFounderSupportEmail;

  const EduContactConfig({
    required this.officialSupportEmail,
    required this.officialWebsite,
    required this.officialSocialLinks,
    required this.verifiedFounderSupportEmail,
  });
}

class EdunivoraIdentity {
  EdunivoraIdentity._();

  static const String appName = 'EduNivora';
  static const String officialTagline = 'The Intelligent Academic Ecosystem';
  static const String appVersion = '1.0.0';
  static const String appBuild = '2';
  static const String versionDisplay = '$appVersion+$appBuild';

  static const String attribution =
      'EduNivora\nFounded & Developed by\nMohammed Ghaleb Alaosimi & Arfat Alkamly';

  static const String attributionSingleLine =
      'EduNivora — Founded & Developed by Mohammed Ghaleb Alaosimi & Arfat Alkamly';

  static const String founderRoleAr = 'مؤسس ومشارك في التأسيس';
  static const String founderRoleEn = 'Founder & Co-Founder';

  static const LocalizedCopy copyright = LocalizedCopy(
    ar: '© 2025 EduNivora — محمد غالب العصيمي وعرفات الكاملي',
    en: '© 2025 EduNivora — Mohammed Ghaleb Alaosimi & Arfat Alkamly',
  );

  static const LocalizedCopy developingOrganization = LocalizedCopy(
    ar: 'الجهة المطورة لـ EduNivora',
    en: 'EduNivora Development Team',
  );

  static const LocalizedCopy tagline = LocalizedCopy(
    ar: 'المنظومة الأكاديمية الذكية — The Intelligent Academic Ecosystem',
    en: 'The Intelligent Academic Ecosystem',
  );

  static const FounderProfile mohammed = FounderProfile(
    id: 'mohammed_ghaleb_alaosimi',
    initials: 'M.GH',
    arabicName: 'محمد غالب العصيمي',
    englishName: 'Mohammed Ghaleb Alaosimi',
    roleAr: founderRoleAr,
    roleEn: founderRoleEn,
    brand: 'M.GH.AL',
    titles: <String>[
      'Full-Stack Developer',
      'Software Engineer',
      'Information Technology Student',
    ],
    bioAr:
        'مؤسس ومشارك في تأسيس EduNivora، ومطور برمجيات متكامل وطالب تقنية معلومات. '
        'يركّز على هندسة الحلول البرمجية العملية وبناء تجربة أكاديمية حديثة تساعد الطلاب على التنظيم والإنجاز.',
    bioEn:
        'Founder & Co-Founder of EduNivora, Full-Stack Developer, Software Engineer, '
        'and Information Technology Student focused on building reliable academic productivity software.',
    publicEmail: null,
    websiteUrl: 'https://mghalaosimi-web.vercel.app/',
    links: <FounderLink>[
      FounderLink(
        id: 'mohammed_github',
        kind: FounderLinkKind.github,
        labelAr: 'GitHub',
        labelEn: 'GitHub',
        url: 'https://github.com/mghalaosimi-web',
        displayValue: 'github.com/mghalaosimi-web',
      ),
      FounderLink(
        id: 'mohammed_website',
        kind: FounderLinkKind.website,
        labelAr: 'الموقع الشخصي',
        labelEn: 'Website',
        url: 'https://mghalaosimi-web.vercel.app/',
        displayValue: 'mghalaosimi-web.vercel.app',
      ),
      FounderLink(
        id: 'mohammed_credly',
        kind: FounderLinkKind.credly,
        labelAr: 'Credly',
        labelEn: 'Credly',
        url: 'https://www.credly.com/users/mohammed-ghaleb-al-aosimi',
        displayValue: 'credly.com/users/mohammed-ghaleb-al-aosimi',
      ),
      FounderLink(
        id: 'mohammed_orcid',
        kind: FounderLinkKind.orcid,
        labelAr: 'ORCID',
        labelEn: 'ORCID',
        url: 'https://orcid.org/0009-0000-6007-3170',
        displayValue: '0009-0000-6007-3170',
      ),
      FounderLink(
        id: 'mohammed_linkedin',
        kind: FounderLinkKind.linkedin,
        labelAr: 'LinkedIn',
        labelEn: 'LinkedIn',
        url: 'https://www.linkedin.com/in/mohammed-alaosimi-038155443/',
        displayValue: 'linkedin.com/in/mohammed-alaosimi-038155443',
      ),
      FounderLink(
        id: 'mohammed_instagram',
        kind: FounderLinkKind.instagram,
        labelAr: 'Instagram',
        labelEn: 'Instagram',
        url: 'https://www.instagram.com/m.gh.al/',
        displayValue: '@m.gh.al',
      ),
      FounderLink(
        id: 'mohammed_tiktok',
        kind: FounderLinkKind.tiktok,
        labelAr: 'TikTok',
        labelEn: 'TikTok',
        url: 'https://www.tiktok.com/@m.gh.al1',
        displayValue: '@m.gh.al1',
      ),
    ],
  );

  static const FounderProfile arfat = FounderProfile(
    id: 'arfat_alkamly',
    initials: 'AK',
    arabicName: 'عرفات الكاملي',
    englishName: 'Arfat Alkamly',
    roleAr: founderRoleAr,
    roleEn: founderRoleEn,
    titles: <String>['Software Engineer', 'Cybersecurity & Software Developer'],
    bioAr:
        'مؤسس ومشارك في تأسيس EduNivora، ومهندس ومطور برمجيات متخصص في الأمن السيبراني. '
        'يهتم ببناء أنظمة ذكية وآمنة وسريعة الاستجابة تمنح الطالب تحكماً كاملاً في رحلته الدراسية.',
    bioEn:
        'Founder & Co-Founder of EduNivora, Software Engineer, and Cybersecurity & Software Developer '
        'dedicated to crafting secure, fast, and dependable student productivity tools.',
    publicEmail: 'alkamlyrfat@gmail.com',
    websiteUrl: 'https://arfat-phi.vercel.app',
    links: <FounderLink>[
      FounderLink(
        id: 'arfat_email',
        kind: FounderLinkKind.email,
        labelAr: 'البريد الإلكتروني',
        labelEn: 'Email',
        url: 'mailto:alkamlyrfat@gmail.com',
        displayValue: 'alkamlyrfat@gmail.com',
      ),
      FounderLink(
        id: 'arfat_github',
        kind: FounderLinkKind.github,
        labelAr: 'GitHub',
        labelEn: 'GitHub',
        url: 'https://github.com/arfat-alkamly',
        displayValue: 'github.com/arfat-alkamly',
      ),
      FounderLink(
        id: 'arfat_website',
        kind: FounderLinkKind.website,
        labelAr: 'الموقع الشخصي',
        labelEn: 'Website',
        url: 'https://arfat-phi.vercel.app',
        displayValue: 'arfat-phi.vercel.app',
      ),
    ],
  );

  static const List<FounderProfile> founders = <FounderProfile>[
    mohammed,
    arfat,
  ];

  static const EduContactConfig contactConfig = EduContactConfig(
    officialSupportEmail: null,
    officialWebsite: null,
    officialSocialLinks: <FounderLink>[],
    verifiedFounderSupportEmail: 'alkamlyrfat@gmail.com',
  );

  static const LocalizedCopy overview = LocalizedCopy(
    ar:
        'EduNivora هو تطبيق أكاديمي يعمل بنهج الأولوية للعمل دون اتصال (Offline-First)، '
        'صُمّم لجمع مهام الطالب الجامعي ومقرراته الدراسية وجدوله الأسبوعي وخطط اختباراته '
        'وحساب المعدل ومؤقت التركيز والتقارير الأكاديمية في بيئة موحدة سريعة وواضحة.',
    en:
        'EduNivora is an offline-first academic companion that unifies student tasks, '
        'courses and study materials, weekly schedules, exam study planning, GPA simulation, '
        'focus sessions, and academic reports in one fast, structured experience.',
  );

  static const List<LocalizedCopy> problemsSolved = <LocalizedCopy>[
    LocalizedCopy(
      ar: 'تشتت المهام والواجبات والمواعيد النهائية بين تطبيقات وملاحظات متفرقة.',
      en: 'Fragmented assignments, deadlines, and notes spread across disconnected apps.',
    ),
    LocalizedCopy(
      ar: 'صعوبة متابعة تقدم المقررات والملفات الدراسية وربطها بخطة الاختبارات.',
      en: 'Difficulty tracking courses, lecture PDFs, and exam preparation in one place.',
    ),
    LocalizedCopy(
      ar: 'غياب رؤية واضحة لتأثير الدرجات المتوقعة على المعدل الفصلي والتراكمي.',
      en: 'Lack of clear visibility into how individual grades impact semester and cumulative GPA.',
    ),
    LocalizedCopy(
      ar: 'الاعتماد الكامل على الإنترنت في أدوات التنظيم اليومية أثناء التواجد في القاعات.',
      en: 'Dependence on constant internet connectivity for everyday study organization.',
    ),
  ];

  static const List<LocalizedCopy> targetAudience = <LocalizedCopy>[
    LocalizedCopy(
      ar: 'طلاب الجامعات والكليات في مختلف التخصصات الأكاديمية.',
      en: 'University and college students across all academic disciplines.',
    ),
    LocalizedCopy(
      ar: 'طلاب الدراسات العليا والباحثون عن تنظيم واضح للمواد والمواعيد.',
      en: 'Graduate learners seeking structured tracking for coursework and milestones.',
    ),
    LocalizedCopy(
      ar: 'المتعلمون الذاتيون الراغبون في ضبط جلسات التركيز وقياس الإنجاز الدراسي.',
      en: 'Self-directed learners who want disciplined focus timers and study reports.',
    ),
  ];

  static const LocalizedCopy vision = LocalizedCopy(
    ar: 'تمكين كل طالب من امتلاك نظام أكاديمي موثوق وذكي يعزز الانضباط الدراسي ويحترم الخصوصية.',
    en: 'Empower every student with a trustworthy, intelligent academic system that fosters focus while respecting privacy.',
  );

  static const LocalizedCopy mission = LocalizedCopy(
    ar: 'تقديم أدوات عملية متكاملة لإدارة الدراسة والوقت والدرجات بتجربة عربية وإنجليزية متقنة وتعمل بسلاسة محلياً.',
    en: 'Deliver practical, cohesive tools for study management, scheduling, and grade tracking with polished Arabic and English support.',
  );

  static const List<LocalizedCopy> coreObjectives = <LocalizedCopy>[
    LocalizedCopy(
      ar: 'توحيد سير العمل الأكاديمي اليومي في واجهة بسيطة وسريعة الاستجابة.',
      en: 'Unify daily academic workflows inside a clean, responsive interface.',
    ),
    LocalizedCopy(
      ar: 'دعم العمل المحلي السريع مع توفير خيارات مصادقة سحابية وإشعارات اختيارية.',
      en: 'Deliver reliable local-first storage alongside optional cloud authentication and notices.',
    ),
    LocalizedCopy(
      ar: 'رفع جودة التخطيط للاختبارات والتركيز الدراسي عبر تقارير واضحة وأدوات مساعدة عملية.',
      en: 'Improve exam planning and study focus through actionable reports and smart tools.',
    ),
  ];

  static const List<LocalizedCopy> productValues = <LocalizedCopy>[
    LocalizedCopy(
      ar: 'الوضوح والبساطة: تصميم يركز على ما يحتاجه الطالب دون تعقيد.',
      en: 'Clarity & Simplicity: Purposeful interfaces focused on student priorities.',
    ),
    LocalizedCopy(
      ar: 'العمل دون اتصال أولاً: بياناتك الدراسية جاهزة معك في أي وقت.',
      en: 'Offline-First Reliability: Your academic workspace stays accessible anytime.',
    ),
    LocalizedCopy(
      ar: 'الشفافية والخصوصية: توضيح صريح لكيفية تخزين البيانات وحماية الجلسة.',
      en: 'Transparency & Privacy: Clear communication about local storage and session security.',
    ),
    LocalizedCopy(
      ar: 'جودة هندسية مستدامة: بنية Clean Architecture قابلة للتطوير المستمر.',
      en: 'Engineering Quality: Maintainable Clean Architecture built for steady evolution.',
    ),
  ];

  static const List<LocalizedCopy> implementedCapabilities = <LocalizedCopy>[
    LocalizedCopy(
      ar: 'إدارة المهام والواجبات مع الأولويات والمواعيد والتذكيرات المحلية.',
      en: 'Task & assignment management with priorities, due dates, and local notifications.',
    ),
    LocalizedCopy(
      ar: 'إدارة المقررات الدراسية، الفصول الأكاديمية، والمواد والملفات مع عارض PDF مدمج.',
      en: 'Courses, academic terms, and course materials with a built-in PDF viewer.',
    ),
    LocalizedCopy(
      ar: 'الجدول الأسبوعي للمحاضرات والمعامل بتنظيم واضح لأيام الأسبوع.',
      en: 'Weekly class and lab schedule organized across study days.',
    ),
    LocalizedCopy(
      ar: 'خطط الاختبارات ومخطط الدراسة لمتابعة الاستعداد قبل مواعيد الامتحانات.',
      en: 'Exam plans and study planner to structure preparation ahead of exams.',
    ),
    LocalizedCopy(
      ar: 'حاسبة المعدل التراكمي ومحاكاة توزيع الدرجات لكل مقرر.',
      en: 'GPA calculator and per-course grade distribution simulator.',
    ),
    LocalizedCopy(
      ar: 'مؤقت التركيز (Focus Timer) لدعم جلسات المذاكرة المنتظمة.',
      en: 'Focus Timer to support structured study and break sessions.',
    ),
    LocalizedCopy(
      ar: 'المساعد الأكاديمي المحلي (Local AI Assistant) للتوجيه وتنظيم المذاكرة.',
      en: 'Local Academic AI Assistant for study guidance and planning.',
    ),
    LocalizedCopy(
      ar: 'التقارير الأكاديمية لمتابعة الإنجاز والأداء الدراسي.',
      en: 'Academic reports summarizing task completion and study progress.',
    ),
    LocalizedCopy(
      ar: 'تخزين محلي عبر قاعدة بيانات SQLite مع خيار الدخول كضيف.',
      en: 'Local SQLite database storage with guest-mode access.',
    ),
    LocalizedCopy(
      ar: 'مصادقة سحابية اختيارية عبر Neon Auth (البريد الإلكتروني مع رمز OTP وتسجيل الدخول بـ Google) وإعلانات سحابية.',
      en: 'Optional Neon Auth (Email/OTP verification & Google Sign-In) and cloud announcements.',
    ),
    LocalizedCopy(
      ar: 'قفل التطبيق برمز PIN أو البصمة الحيوية، مع دعم العربية والإنجليزية والوضع الفاتح والداكن.',
      en: 'PIN & Biometric app lock, full Arabic/English localization, and Light/Dark themes.',
    ),
  ];

  static const List<LocalizedCopy> plannedFutureDevelopment = <LocalizedCopy>[
    LocalizedCopy(
      ar: 'تشفير قاعدة بيانات SQLite المحلية بالكامل في وضع السكون (SQLCipher).',
      en: 'Full at-rest encryption for the local SQLite database (SQLCipher).',
    ),
    LocalizedCopy(
      ar: 'تفعيل واجهة النسخ الاحتياطي والاستعادة الكاملة للبيانات في الإصدار الثاني (Release 2).',
      en: 'Full backup & restore workflow in Release 2.',
    ),
    LocalizedCopy(
      ar: 'توسيع المزامنة السحابية الاختيارية وتكامل التقويمات الأكاديمية في إصدارات قادمة.',
      en: 'Expanded optional cloud sync and calendar integrations in future releases.',
    ),
  ];

  static const List<LocalizedCopy> releaseNotes = <LocalizedCopy>[
    LocalizedCopy(
      ar: 'إصلاح السبب الجذري لعطل تهيئة قاعدة البيانات SQLite على Android (تفعيل WAL عبر rawQuery وإضافة حارس تزامن وترتيب الترحيلات).',
      en: 'Fixed Android SQLite startup failure (switched WAL PRAGMA to rawQuery, added open concurrency guard, and ordered migrations).',
    ),
    LocalizedCopy(
      ar: 'إطلاق أيقونة EduNivora الرسمية المتكيفة (Adaptive & Round Icons) وشاشة البداية الموحدة.',
      en: 'Introduced official EduNivora Adaptive & Round launcher icons and branded splash screen.',
    ),
    LocalizedCopy(
      ar: 'اعتماد الهوية الرسمية "EduNivora — The Intelligent Academic Ecosystem" وصفحة الفريق والمؤسسين وروابطهم المعتمدة.',
      en: 'Unified official identity "EduNivora — The Intelligent Academic Ecosystem" and verified co-founders profiles.',
    ),
    LocalizedCopy(
      ar: 'إضافة شاشات: عن التطبيق، الفريق والمؤسسون، مركز المساعدة، تواصل معنا، والخصوصية والشروط بدعم كامل للوضع الداكن وRTL/LTR.',
      en: 'Added About App, Team & Founders, Help Center, Contact Us, and Privacy & Terms screens with Dark Mode & RTL/LTR support.',
    ),
  ];

  static const List<String> techStack = <String>[
    'Flutter',
    'Dart',
    'Clean Architecture',
    'SQLite Local DB',
    'Riverpod',
    'Neon Auth',
  ];
}
