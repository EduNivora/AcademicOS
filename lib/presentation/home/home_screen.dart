// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/academic/academic_dashboard_service.dart';
import '../../core/security/auth_secure_storage_service.dart';
import '../../core/security/app_lock_service.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/security/secure_storage_service.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/auth_use_cases.dart';
import '../../domain/usecases/course_use_cases.dart';
import '../../domain/usecases/task_use_cases.dart';
import '../../providers/task_providers.dart';
import '../auth/auth_gate_screen.dart';
import '../auth/pin_lock_screen.dart';
import '../ai_assistant/academic_ai_screen.dart';
import '../about/about_app_screen.dart';
import '../about/about_screen.dart';
import '../about/help_center_screen.dart';
import '../settings/settings_screen.dart';
import '../course/add_edit_course_screen.dart';
import '../course/course_detail_screen.dart';
import '../course/course_list_screen.dart';
import '../../core/notifications/notification_service.dart';
import '../notifications/communications_screen.dart';
import '../about/contact_screen.dart';
import '../admin/admin_announcements_screen.dart';
import '../schedule/weekly_schedule_screen.dart';
import '../focus/focus_timer_screen.dart';
import '../reports/academic_reports_screen.dart';
import '../study_plan/study_planner_screen.dart';
import '../task/add_edit_task_screen.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/exam_model.dart';
import '../../data/models/student_profile_model.dart';

enum TaskSortMode {
  none,
  dueDateAsc,
  dueDateDesc,
  taskType,
  priorityAsc,
  priorityDesc,
  recurrence,
}

enum TaskSearchStatus { all, completed, pending, overdue }

extension TaskSortModeX on TaskSortMode {
  String get label {
    switch (this) {
      case TaskSortMode.dueDateAsc:
        return 'أقرب استحقاق';
      case TaskSortMode.dueDateDesc:
        return 'أبعد استحقاق';
      case TaskSortMode.taskType:
        return 'حسب النوع';
      case TaskSortMode.priorityAsc:
        return 'أولوية تصاعدي';
      case TaskSortMode.priorityDesc:
        return 'أولوية تنازلي';
      case TaskSortMode.recurrence:
        return 'حسب التكرار';
      case TaskSortMode.none:
        return 'بدون فرز';
    }
  }
}

extension TaskSearchStatusX on TaskSearchStatus {
  String get label {
    switch (this) {
      case TaskSearchStatus.completed:
        return 'مكتملة';
      case TaskSearchStatus.pending:
        return 'معلقة';
      case TaskSearchStatus.overdue:
        return 'متأخرة';
      case TaskSearchStatus.all:
        return 'الكل';
    }
  }
}

class HomeScreen extends ConsumerWidget {
  final TaskUseCases taskUseCases;
  final CourseUseCases courseUseCases;
  final AuthUseCases authUseCases;
  final bool isDarkMode;
  final bool isArabic;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<bool> onLanguageChanged;

  const HomeScreen({
    super.key,
    required this.taskUseCases,
    required this.courseUseCases,
    required this.authUseCases,
    required this.isDarkMode,
    required this.isArabic,
    required this.onThemeChanged,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskListProvider);
    final taskNotifier = ref.read(taskListProvider.notifier);

    return _HomeScreenContent(
      taskUseCases: taskUseCases,
      courseUseCases: courseUseCases,
      authUseCases: authUseCases,
      isDarkMode: isDarkMode,
      isArabic: isArabic,
      onThemeChanged: onThemeChanged,
      onLanguageChanged: onLanguageChanged,
      taskState: taskState,
      onRefresh: taskNotifier.loadTasks,
      onToggleCompletion: taskNotifier.toggleCompletion,
      onDeleteTask: taskNotifier.deleteTask,
      onAddTask: taskNotifier.addTask,
    );
  }
}

class _HomeScreenContent extends StatefulWidget {
  final TaskUseCases taskUseCases;
  final CourseUseCases courseUseCases;
  final AuthUseCases authUseCases;
  final bool isDarkMode;
  final bool isArabic;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<bool> onLanguageChanged;
  final TaskListState taskState;
  final Future<void> Function() onRefresh;
  final Future<void> Function(TaskEntity task) onToggleCompletion;
  final Future<void> Function(int id) onDeleteTask;
  final Future<void> Function(TaskEntity task) onAddTask;

  const _HomeScreenContent({
    required this.taskUseCases,
    required this.courseUseCases,
    required this.authUseCases,
    required this.isDarkMode,
    required this.isArabic,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.taskState,
    required this.onRefresh,
    required this.onToggleCompletion,
    required this.onDeleteTask,
    required this.onAddTask,
  });

  @override
  State<_HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<_HomeScreenContent>
    with WidgetsBindingObserver {
  static const List<String> _yemeniMotivationQuotes = [
    'من طلب العلا سهر الليالي.. شيد همتك يا بطل!',
    'خطوة بخطوة توصل لأعلى الدرجات.. شمر عن ساعديك!',
    'العلم نور.. وكل دقيقة مذاكرة تبني مستقبلك.',
    'قوة العزيمة أهم من الوقت.. ابدأ اليوم بثقة!',
    'كل جهد صغير اليوم يفتح باب نجاحك غداً.',
  ];

  final SecureStorageService _secureStorageService = SecureStorageService();
  final AuthSecureStorageService _authSecureStorageService =
      AuthSecureStorageService();
  final LocalAuthService _localAuthService = LocalAuthService();
  late final AppLockService _appLockService;
  final TextEditingController _searchController = TextEditingController();
  List<CourseEntity> _courses = [];
  List<ExamModel> _exams = [];
  bool _isAppLocked = false;
  bool _showMotivationCard = true;
  int _selectedBottomNav = 0;
  String _motivationQuote = _yemeniMotivationQuotes.first;
  String _searchQuery = '';
  String? _selectedCourseFilter;
  StudentProfile _studentProfile = StudentProfile.empty();
  late Future<UserEntity?> _currentUserFuture;
  TaskSearchStatus _statusFilter = TaskSearchStatus.all;
  TaskSortMode _sortMode = TaskSortMode.none;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _todayLectures = [];
  String _activeTermName = '';
  bool _showTaskControls = false;

  int get _completedTasksCount =>
      widget.taskState.tasks.where((task) => task.isCompleted).length;
  int get _pendingTasksCount =>
      widget.taskState.tasks.length - _completedTasksCount;

  double _percentageToGpa(double percent) {
    if (percent >= 95) return 4.0;
    if (percent >= 90) return 3.8;
    if (percent >= 85) return 3.6;
    if (percent >= 80) return 3.3;
    if (percent >= 75) return 3.0;
    if (percent >= 70) return 2.7;
    if (percent >= 65) return 2.3;
    if (percent >= 60) return 2.0;
    if (percent >= 50) return 1.5;
    return 1.0;
  }

  double get _estimatedGpa {
    if (_courses.isEmpty) return 0;

    var totalWeighted = 0.0;
    var totalCredits = 0;

    for (final course in _courses) {
      final credits = (course.creditHours ?? course.credits);
      final mid = course.midGrade ?? 0;
      final practical = course.practicalGrade ?? 0;
      final finalGrade = course.finalGrade ?? 0;
      final percent = ((mid * 0.3) + (practical * 0.3) + (finalGrade * 0.4))
          .clamp(0, 100)
          .toDouble();
      totalWeighted += _percentageToGpa(percent) * credits;
      totalCredits += credits;
    }

    if (totalCredits == 0) return 0;
    return (totalWeighted / totalCredits).clamp(0, 4.0);
  }

  Future<void> _showGlobalSearch() async {
    if (!mounted) return;
    final allTasks = widget.taskState.tasks;
    final matchCount = allTasks
        .where(
          (task) =>
              task.title.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .length;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          matchCount > 0
              ? 'تم العثور على $matchCount مهمة متطابقة مع البحث الحالي.'
              : 'لا توجد نتائج مطابقة في المهام الحالية.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUserFuture = widget.authUseCases.getCurrentUser.call();
    _appLockService = AppLockService(
      _authSecureStorageService,
      _localAuthService,
    );
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() => _searchQuery = _searchController.text);
    });
    _loadStudentProfile();
    _loadCourses();
    _loadSavedSettingsAndTasks();
    _loadScheduleAndTerm();
    _appLockService.updateLastActive();
  }

  String _getTodayArabicDay() {
    const arabicDays = {
      DateTime.saturday: 'السبت',
      DateTime.sunday: 'الأحد',
      DateTime.monday: 'الاثنين',
      DateTime.tuesday: 'الثلاثاء',
      DateTime.wednesday: 'الأربعاء',
      DateTime.thursday: 'الخميس',
      DateTime.friday: 'الجمعة',
    };
    return arabicDays[DateTime.now().weekday] ?? 'السبت';
  }

  Future<void> _loadScheduleAndTerm() async {
    try {
      final db = DatabaseHelper.instance;
      final schedules = await db.getSchedules();
      final courses = await db.getCourses();
      final exams = await db.getExams();
      final courseMap = {for (final c in courses) c.id!: c};
      final todayDay = _getTodayArabicDay();
      final todaySchedules =
          schedules
              .where(
                (row) => (row['day_of_week']?.toString() ?? '') == todayDay,
              )
              .map((row) {
                final courseId = row['course_id'] is int
                    ? row['course_id'] as int
                    : int.tryParse(row['course_id']?.toString() ?? '');
                final course = courseId != null ? courseMap[courseId] : null;
                return {
                  'id': row['id'],
                  'day': row['day_of_week']?.toString() ?? todayDay,
                  'courseTitle':
                      course?.name ?? (widget.isArabic ? 'محاضرة' : 'Lecture'),
                  'instructor': course?.instructor ?? '',
                  'start': row['start_time']?.toString() ?? '08:00',
                  'end': row['end_time']?.toString() ?? '09:00',
                  'location':
                      row['location']?.toString() ??
                      (widget.isArabic ? 'غير محدد' : 'TBD'),
                };
              })
              .toList()
            ..sort(
              (a, b) => (a['start'] as String).compareTo(b['start'] as String),
            );

      if (!mounted) return;
      setState(() {
        _activeTermName = _studentProfile.semester;
        _todayLectures = todaySchedules;
        _exams = exams;
      });
    } catch (e) {
      debugPrint('HomeScreen._loadScheduleAndTerm error: $e');
    }
  }

  String _formatRelativeDueDate(DateTime? date) {
    if (date == null) return widget.isArabic ? 'بدون موعد' : 'No date';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = widget.isArabic
        ? (date.hour >= 12 ? 'م' : 'ص')
        : (date.hour >= 12 ? 'PM' : 'AM');
    final timeStr = '$hour:$minute $amPm';

    if (diff == 0) {
      return widget.isArabic ? 'اليوم • $timeStr' : 'Today • $timeStr';
    } else if (diff == 1) {
      return widget.isArabic ? 'غداً • $timeStr' : 'Tomorrow • $timeStr';
    } else if (diff == -1) {
      return widget.isArabic ? 'أمس • $timeStr' : 'Yesterday • $timeStr';
    } else if (diff > 1 && diff <= 7) {
      const dayNames = {
        DateTime.saturday: 'السبت',
        DateTime.sunday: 'الأحد',
        DateTime.monday: 'الاثنين',
        DateTime.tuesday: 'الثلاثاء',
        DateTime.wednesday: 'الأربعاء',
        DateTime.thursday: 'الخميس',
        DateTime.friday: 'الجمعة',
      };
      final dayName = dayNames[date.weekday] ?? '';
      return '$dayName • $timeStr';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} • $timeStr';
    }
  }

  Color _getPriorityTextColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
      case TaskPriority.high:
        return const Color(0xFFE11D48);
      case TaskPriority.medium:
        return const Color(0xFFD97706);
      case TaskPriority.low:
        return const Color(0xFF16A34A);
    }
  }

  Color _getPriorityBgColor(TaskPriority priority, bool isDark) {
    if (isDark) {
      switch (priority) {
        case TaskPriority.urgent:
        case TaskPriority.high:
          return const Color(0xFFE11D48).withValues(alpha: 0.18);
        case TaskPriority.medium:
          return const Color(0xFFD97706).withValues(alpha: 0.18);
        case TaskPriority.low:
          return const Color(0xFF16A34A).withValues(alpha: 0.18);
      }
    } else {
      switch (priority) {
        case TaskPriority.urgent:
        case TaskPriority.high:
          return const Color(0xFFFFECEC);
        case TaskPriority.medium:
          return const Color(0xFFFFF8E1);
        case TaskPriority.low:
          return const Color(0xFFE8F5E9);
      }
    }
  }

  String _getPriorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
      case TaskPriority.high:
        return widget.isArabic ? 'عالية' : 'High';
      case TaskPriority.medium:
        return widget.isArabic ? 'متوسطة' : 'Medium';
      case TaskPriority.low:
        return widget.isArabic ? 'منخفضة' : 'Low';
    }
  }

  Future<void> _loadCourses() async {
    try {
      final courses = await widget.courseUseCases.getCourses();
      if (!mounted) return;
      setState(() => _courses = courses);
      _loadScheduleAndTerm();
    } catch (error, stackTrace) {
      debugPrint('HomeScreen._loadCourses error: $error\n$stackTrace');
    }
  }

  Future<void> _loadStudentProfile() async {
    final profile = await StudentProfile.load();
    if (!mounted) return;
    setState(() {
      _studentProfile = profile;
      _activeTermName = profile.semester;
    });
  }

  Future<void> _refreshAfterLocalDataClear() async {
    await _loadCourses();
    await _loadSavedSettingsAndTasks();
    await _loadScheduleAndTerm();
  }

  Future<void> _loadSavedSettingsAndTasks() async {
    _motivationQuote = _pickMotivationQuote();
    await _loadSavedSettings();
    await _loadTasks();
  }

  List<String> get _courseFilterOptions {
    final options =
        _courses
            .map((course) => course.name.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['الكل', ...options, 'بدون كورس'];
  }

  Future<void> _saveCourseFilter(String? value) async {
    final newValue = value == 'الكل' ? null : value;
    setState(() => _selectedCourseFilter = newValue);
    await _secureStorageService.saveTaskFilter(newValue);
  }

  Future<void> _saveSortMode(TaskSortMode mode) async {
    setState(() => _sortMode = mode);
    await _secureStorageService.saveTaskSortMode(mode.name);
  }

  Future<void> _saveStatusFilter(TaskSearchStatus status) async {
    setState(() => _statusFilter = status);
    await _secureStorageService.saveTaskStatusFilter(status.name);
  }

  String _pickMotivationQuote() {
    final now = DateTime.now();
    final index = (now.millisecondsSinceEpoch % _yemeniMotivationQuotes.length);
    return _yemeniMotivationQuotes[index];
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'صباح الهمة والنشاط';
    }
    return 'مساء الإنجاز';
  }

  void _showWarmSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleAppResume() async {
    final shouldLock = await _appLockService.shouldLockApp();
    if (!mounted || !shouldLock) {
      await _appLockService.updateLastActive();
      return;
    }
    setState(() {
      _isAppLocked = true;
    });
  }

  Future<void> _loadSavedSettings() async {
    try {
      final courseFilter = await _secureStorageService.getSavedTaskFilter();
      final sortModeName = await _secureStorageService.getSavedTaskSortMode();
      final statusName = await _secureStorageService.getSavedTaskStatusFilter();
      setState(() {
        _selectedCourseFilter = courseFilter;
        _sortMode = TaskSortMode.values.firstWhere(
          (mode) => mode.name == sortModeName,
          orElse: () => TaskSortMode.none,
        );
        _statusFilter = TaskSearchStatus.values.firstWhere(
          (status) => status.name == statusName,
          orElse: () => TaskSearchStatus.all,
        );
      });
    } catch (error, stackTrace) {
      debugPrint('HomeScreen._loadSavedSettings error: $error\n$stackTrace');
    }
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    await widget.onRefresh();
    _loadScheduleAndTerm();
    try {
      final tasks = widget.taskState.tasks;
      final courses = await widget.courseUseCases.getCourses();
      await NotificationService.instance.syncReminders(
        tasks: tasks,
        courses: courses,
      );
    } catch (error, stackTrace) {
      debugPrint('HomeScreen._loadTasks error: $error\n$stackTrace');
    }
  }

  Future<bool> _confirmDeleteDialog(TaskEntity task) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text('هل تريد حذف المهمة "${task.title}"؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteTask(TaskEntity task) async {
    if (task.id == null) return;

    final confirmed = await _confirmDeleteDialog(task);
    if (!confirmed) return;

    try {
      await widget.onDeleteTask(task.id!);
      await _loadTasks();
    } catch (error, stackTrace) {
      debugPrint('HomeScreen._deleteTask error: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء حذف المهمة.')),
      );
    }
  }

  Future<void> _toggleTaskCompletion(TaskEntity task) async {
    final willComplete = !task.isCompleted;
    try {
      await widget.onToggleCompletion(task);
      await _loadTasks();
      if (!mounted) return;
      _showWarmSnackBar(
        willComplete
            ? 'تم إكمال المهمة بنجاح.. الله يوفقك!'
            : 'تمت إعادة المهمة إلى قائمة الأعمال.. استمر!',
      );
    } catch (error, stackTrace) {
      debugPrint('HomeScreen._toggleTaskCompletion error: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذّر تحديث حالة المهمة.')));
    }
  }

  // ignore: unused_element
  void _showAboutDialog(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isAr = widget.isArabic;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: primary.withValues(alpha: 0.12),
                        child: Icon(Icons.school, size: 36, color: primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EduNivora',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isAr
                                    ? 'الإصدار 1.0.0+2 (Offline-First)'
                                    : 'Version 1.0.0+2 (Offline-First)',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isAr
                        ? 'EduNivora هي بيئة تشغيل وإنتاجية أكاديمية متكاملة مصممة خصيصاً لطلاب الجامعات لتنظيم وإدارة مسيرتهم الدراسية بكفاءة واحترافية، وجمع كافة الأدوات الأكاديمية في منصة واحدة تعمل دون اتصال بالإنترنت مع خصوصية تامة.'
                        : 'EduNivora is an all-in-one offline-first academic productivity platform crafted for university students to manage materials, tasks, schedules, reports, and focus sessions with full privacy.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('📚  ', style: TextStyle(fontSize: 18)),
                          Expanded(
                            child: Text(
                              isAr
                                  ? 'إدارة المقررات: متابعة تفاصيل المواد، المحاضرين، والساعات المعتمدة.'
                                  : 'Courses: track subjects, instructors, materials, and credits.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('📝  ', style: TextStyle(fontSize: 18)),
                          Expanded(
                            child: Text(
                              isAr
                                  ? 'إدارة المهام: تنظيم الواجبات والتكاليف ومواعيد التسليم حسب الأولوية.'
                                  : 'Tasks: organize assignments and deadlines by priority.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('📅  ', style: TextStyle(fontSize: 18)),
                          Expanded(
                            child: Text(
                              isAr
                                  ? 'الجدول الدراسي: تتبع أوقات المحاضرات، القاعات والمعامل، والمحاضرات النشطة.'
                                  : 'Weekly Schedule: track lecture times, rooms, and active sessions.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('⏱️  ', style: TextStyle(fontSize: 18)),
                          Expanded(
                            child: Text(
                              isAr
                                  ? 'أدوات الإنتاجية: جلسات التركيز والتقارير الأكاديمية المحلية.'
                                  : 'Productivity: focus sessions and local academic reports.',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAr
                              ? 'فريق تطوير EduNivora'
                              : 'EduNivora Development Team',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAr
                              ? 'المنظومة الأكاديمية الذكية — صُممت لتمكين الطالب الجامعي وتعزيز إنتاجيته وتنظيم مسيرته الدراسية.'
                              : 'The Intelligent Academic Ecosystem — Built for student productivity, focus, and academic success.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AboutAppScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.info_outline_rounded, size: 18),
                        label: Text(isAr ? 'عن التطبيق' : 'About App'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AboutScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.groups_rounded, size: 18),
                        label: Text(
                          isAr ? 'الفريق والمؤسسون' : 'Team & Founders',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(isAr ? 'إغلاق' : 'Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _navigateToAddEdit(TaskEntity? task) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditTaskScreen(
          useCases: widget.taskUseCases,
          courseUseCases: widget.courseUseCases,
          existingTask: task,
        ),
      ),
    );
    if (result == true) {
      await _loadTasks();
      _showWarmSnackBar('تم حفظ التعديلات بنجاح.. الله يوفقك!');
    }
  }

  Future<void> _openCourseDetailFromTask(TaskEntity task) async {
    if (task.courseId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذه المهمة غير مرتبطة بمقرر.')),
      );
      return;
    }

    try {
      final course = await widget.courseUseCases.getCourseById(task.courseId!);
      if (course == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على المقرر المرتبط.')),
        );
        return;
      }

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CourseDetailScreen(
            course: course,
            taskUseCases: widget.taskUseCases,
            courseUseCases: widget.courseUseCases,
          ),
        ),
      );
      if (result == true) await _loadTasks();
    } catch (error, stackTrace) {
      debugPrint(
        'HomeScreen._openCourseDetailFromTask error: $error\n$stackTrace',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذّر فتح تفاصيل المقرر.')));
    }
  }

  Widget _buildSmartAcademicCard(BuildContext context) {
    final dashboard = const AcademicDashboardService().analyze(
      courses: _courses,
      tasks: widget.taskState.tasks,
      exams: _exams,
    );

    final healthText = dashboard.studyHealthScore.round();
    final riskText = dashboard.atRiskCourses.isEmpty
        ? (widget.isArabic
              ? 'لا توجد مواد في خطر حاليًا.'
              : 'No courses currently at risk.')
        : (widget.isArabic
              ? 'مواد تحتاج عناية إضافية: ${dashboard.atRiskCourses.join(" • ")}'
              : 'Needs attention: ${dashboard.atRiskCourses.join(" • ")}');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.isArabic ? 'القلب الذكي' : 'Smart Academic Core',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$healthText%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            dashboard.focusMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            dashboard.nextPriorityAction,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.timeline_rounded, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dashboard.recommendedFocusBlock,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            riskText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFEEF2FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.indigo.shade100),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getGreeting(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _motivationQuote = _pickMotivationQuote());
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'اقرأ رسالة جديدة',
                  ),
                  IconButton(
                    onPressed: () =>
                        setState(() => _showMotivationCard = false),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _motivationQuote,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 70,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'لا يوجد شيء هنا بعد',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أضف أول مادة أو أول مهمة لبدء تنظيم دراستك',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddEditCourseScreen(
                          useCases: widget.courseUseCases,
                        ),
                      ),
                    );
                    await _loadTasks();
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('إضافة أول مادة'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _navigateToAddEdit(null),
                  icon: const Icon(Icons.add_task_outlined),
                  label: const Text('إضافة أول مهمة'),
                  style: ElevatedButton.styleFrom(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _appLockService.updateLastActive();
    }
    if (state == AppLifecycleState.resumed) {
      _handleAppResume();
    }
  }

  List<TaskEntity> _filteredTasks() {
    return widget.taskUseCases.filterAndSortTasks(
      widget.taskState.tasks,
      searchQuery: _searchController.text,
      courseFilter: _selectedCourseFilter,
      statusFilter: _statusFilter.name,
      sortMode: _sortMode.name,
    );
  }

  Map<String, List<TaskEntity>> _groupTasksByCourse() {
    final groups = <String, List<TaskEntity>>{};
    for (final task in _filteredTasks()) {
      final groupName =
          (task.courseName != null && task.courseName!.trim().isNotEmpty)
          ? task.courseName!
          : 'بدون كورس';
      groups.putIfAbsent(groupName, () => []).add(task);
    }
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == 'بدون كورس') return 1;
        if (b == 'بدون كورس') return -1;
        return a.compareTo(b);
      });
    return {for (final key in sortedKeys) key: groups[key]!};
  }

  String _avatarText(String avatar) {
    switch (avatar) {
      case 'laptop':
        return '💻';
      case 'book':
        return '📘';
      case 'rocket':
        return '🚀';
      case 'brain':
        return '🧠';
      case 'code':
        return '🧑‍💻';
      case 'graduation':
        return '🎓';
      default:
        return '🎓';
    }
  }

  Future<void> _showProfileEditor() async {
    final controllerName = TextEditingController(
      text: _studentProfile.fullName,
    );
    final controllerUniversity = TextEditingController(
      text: _studentProfile.university,
    );
    final controllerMajor = TextEditingController(text: _studentProfile.major);
    final controllerDepartment = TextEditingController(
      text: _studentProfile.department,
    );
    final controllerSemester = TextEditingController(
      text: _studentProfile.semester,
    );
    final controllerLevel = TextEditingController(
      text: _studentProfile.academicLevel,
    );
    String selectedAvatar = _studentProfile.avatar;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final avatarItems = [
              ('student', '🎓'),
              ('laptop', '💻'),
              ('book', '📘'),
              ('rocket', '🚀'),
              ('brain', '🧠'),
              ('code', '🧑‍💻'),
            ];

            return AlertDialog(
              title: const Text('تعديل الملف الأكاديمي'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controllerName,
                      decoration: const InputDecoration(
                        labelText: 'اسم الطالب',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controllerUniversity,
                      decoration: const InputDecoration(
                        labelText: 'الجامعة / الكلية',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controllerMajor,
                      decoration: const InputDecoration(
                        labelText: 'التخصص الدراسي',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controllerDepartment,
                      decoration: const InputDecoration(labelText: 'القسم'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controllerSemester,
                      decoration: const InputDecoration(
                        labelText: 'الفصل الدراسي',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controllerLevel,
                      decoration: const InputDecoration(
                        labelText: 'المستوى الدراسي',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const SizedBox(height: 14),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text('اختيار الصورة الرمزية'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: avatarItems.map((entry) {
                        final key = entry.$1;
                        final emoji = entry.$2;
                        final isSelected = selectedAvatar == key;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedAvatar = key),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFDBEAFE)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 26),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    void disposeControllers() {
      controllerName.dispose();
      controllerUniversity.dispose();
      controllerMajor.dispose();
      controllerDepartment.dispose();
      controllerSemester.dispose();
      controllerLevel.dispose();
    }

    if (result != true) {
      disposeControllers();
      return;
    }
    final profile = StudentProfile(
      fullName: controllerName.text.trim(),
      university: controllerUniversity.text.trim(),
      major: controllerMajor.text.trim(),
      department: controllerDepartment.text.trim(),
      semester: controllerSemester.text.trim(),
      academicLevel: controllerLevel.text.trim(),
      targetGpa: _studentProfile.targetGpa,
      avatar: selectedAvatar,
    );
    await StudentProfile.save(profile);
    disposeControllers();
    if (!mounted) return;
    setState(() {
      _studentProfile = profile;
      _activeTermName = profile.semester;
    });
    _showWarmSnackBar('تم تحديث الملف الأكاديمي بنجاح');
  }

  Widget _buildTaskItemRefCard(TaskEntity task, bool isDark) {
    final priorityColor = _getPriorityTextColor(task.priority);
    final priorityBg = _getPriorityBgColor(task.priority, isDark);
    final priorityLabel = _getPriorityLabel(task.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Dismissible(
        key: ValueKey(task.id ?? '${task.title}-${task.dueDate}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.shade500,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (_) => _confirmDeleteDialog(task),
        onDismissed: (_) => _deleteTask(task),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToAddEdit(task),
          onLongPress: () {
            if (task.courseId != null) {
              _openCourseDetailFromTask(task);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Checkbox circle
                GestureDetector(
                  onTap: () => _toggleTaskCompletion(task),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: task.isCompleted
                            ? const Color(0xFF10B981)
                            : const Color(0xFF94A3B8),
                        width: 2,
                      ),
                      color: task.isCompleted
                          ? const Color(0xFF10B981)
                          : Colors.transparent,
                    ),
                    child: task.isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                // Title and due date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 14,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatRelativeDueDate(task.dueDate),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Priority Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: priorityBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    priorityLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReferenceHeader(
    BuildContext context,
    UserEntity? currentUser,
    bool isDark,
  ) {
    final topPadding = MediaQuery.of(context).padding.top;
    final userName = _studentProfile.fullName.isNotEmpty
        ? _studentProfile.fullName
        : (currentUser?.displayName ?? (currentUser?.username ?? 'Mohammed'));
    final termText = _activeTermName.isNotEmpty
        ? 'الفصل الدراسي: $_activeTermName'
        : (_studentProfile.academicLevel.isNotEmpty
              ? 'الفصل الدراسي: ${_studentProfile.academicLevel}'
              : (widget.isArabic
                    ? 'الفصل الدراسي: الثاني 1447 هـ'
                    : 'Term: Second 1447 AH'));

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B2577), Color(0xFF1E5BF0)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x331E5BF0),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top status/brand row
          Row(
            textDirection: TextDirection.ltr,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left (in RTL): Notification bell with badge "2"
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunicationsScreen(
                        taskUseCases: widget.taskUseCases,
                        courseUseCases: widget.courseUseCases,
                        authUseCases: widget.authUseCases,
                      ),
                    ),
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              // Center: App Title & Subtitle
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'EduNivora',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Learn • Plan • Achieve',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              // Right: EduNivora Owl Mascot Logo
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/branding/edunivora_app_icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Greeting & Profile Row
          Row(
            textDirection: TextDirection.ltr,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isArabic
                          ? 'مرحباً بك مجدداً 👋'
                          : 'Welcome back 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      termText,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // User avatar with online indicator
              GestureDetector(
                onTap: _showProfileEditor,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        child: Text(
                          _avatarText(_studentProfile.avatar),
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      left: 2,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceStatsRow(
    BuildContext context,
    int completionRate,
    bool isDark,
  ) {
    final targetGpa = double.tryParse(_studentProfile.targetGpa) ?? 0;
    final gpaDisplay = targetGpa > 0
        ? '${(_estimatedGpa * 25).clamp(0, 100).round()}%'
        : (_courses.isEmpty
              ? '92%'
              : '${(_estimatedGpa * 25).clamp(0, 100).round()}%');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Expanded(
            child: _buildStatRefCard(
              icon: Icons.emoji_events_rounded,
              iconColor: const Color(0xFFF59E0B),
              value: gpaDisplay,
              label: widget.isArabic ? 'معدلك' : 'GPA',
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatRefCard(
              icon: Icons.menu_book_rounded,
              iconColor: const Color(0xFF2563EB),
              value: '${_courses.length}',
              label: widget.isArabic ? 'مقرراتك' : 'Courses',
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatRefCard(
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFF10B981),
              value: '$_pendingTasksCount',
              label: widget.isArabic ? 'مهام متبقية' : 'Pending',
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatRefCard(
              icon: Icons.trending_up_rounded,
              iconColor: const Color(0xFF6366F1),
              value: '$completionRate%',
              label: widget.isArabic ? 'إنجازك' : 'Progress',
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRefCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceScheduleSection(BuildContext context, bool isDark) {
    final hasLecture = _todayLectures.isNotEmpty;
    final lecture = hasLecture ? _todayLectures.first : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isArabic ? 'جدول اليوم' : "Today's Schedule",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ScheduleScreen(authUseCases: widget.authUseCases),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      widget.isArabic ? 'عرض الكل' : 'View all',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_back_rounded,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF1F5F9),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Blue vertical bar
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                // Lecture info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasLecture
                                ? '${lecture!['start']} - ${lecture['end']}'
                                : '10:00 ص - 11:30 ص',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasLecture
                            ? '${lecture!['courseTitle']}'
                            : (widget.isArabic
                                  ? 'محاضرة الذكاء الاصطناعي'
                                  : 'Artificial Intelligence Lecture'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasLecture
                            ? '${lecture!['location']}'
                            : (widget.isArabic ? 'قاعة A101' : 'Hall A101'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white60
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Blue icon container matching reference
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Color(0xFF2563EB),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceUpcomingTasksSection(
    BuildContext context,
    bool isDark,
  ) {
    final pending = widget.taskState.tasks
        .where((t) => !t.isCompleted)
        .toList();
    final displayTasks = pending.isNotEmpty
        ? pending.take(3).toList()
        : widget.taskState.tasks.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF2563EB),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.isArabic ? 'مهامي القادمة' : 'Upcoming Tasks',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _showTaskControls = !_showTaskControls);
                },
                child: Row(
                  children: [
                    Text(
                      _showTaskControls
                          ? (widget.isArabic ? 'إخفاء الكل' : 'Collapse')
                          : (widget.isArabic ? 'عرض الكل' : 'View all'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showTaskControls
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.arrow_back_rounded,
                      size: 16,
                      color: const Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (displayTasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                ),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 38,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isArabic
                          ? 'رائع! لا توجد مهام معلقة حالياً'
                          : 'Great! No pending tasks right now',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _navigateToAddEdit(null),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(widget.isArabic ? 'إضافة مهمة' : 'Add task'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...displayTasks.map((task) => _buildTaskItemRefCard(task, isDark)),
        ],
      ),
    );
  }

  Widget _buildReferenceQuickAccessSection(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                color: Color(0xFF2563EB),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                widget.isArabic ? 'الوصول السريع' : 'Quick Access',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickAccessRefCard(
                  icon: Icons.memory_rounded,
                  iconColor: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                  title: 'المساعد الذكي',
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AcademicAiScreen(
                          courses: _courses,
                          tasks: widget.taskState.tasks,
                          exams: _exams,
                          authUseCases: widget.authUseCases,
                          courseUseCases: widget.courseUseCases,
                          taskUseCases: widget.taskUseCases,
                          onDataChanged: () async {
                            await _loadTasks();
                            await _loadStudentProfile();
                          },
                        ),
                      ),
                    ).then((_) => _loadScheduleAndTerm());
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickAccessRefCard(
                  icon: Icons.school_rounded,
                  iconColor: const Color(0xFF1D4ED8),
                  bgColor: const Color(0xFFEFF6FF),
                  title: widget.isArabic ? 'المواد' : 'Materials',
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseListScreen(
                          courseUseCases: widget.courseUseCases,
                          taskUseCases: widget.taskUseCases,
                        ),
                      ),
                    ).then((res) {
                      if (res == true) _loadCourses();
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickAccessRefCard(
                  icon: Icons.psychology_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFF5F3FF),
                  title: widget.isArabic ? 'مخطط المذاكرة' : 'Study Plan',
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudyPlannerScreen(
                          courseUseCases: widget.courseUseCases,
                          taskUseCases: widget.taskUseCases,
                          onTasksChanged: widget.onRefresh,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessRefCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFF1F5F9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? iconColor.withValues(alpha: 0.16) : bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceDrawer(
    BuildContext context,
    UserEntity? currentUser,
    bool isDark,
    Color primary,
  ) {
    final userName = _studentProfile.fullName.isNotEmpty
        ? _studentProfile.fullName
        : (currentUser?.displayName ?? (currentUser?.username ?? 'Mohammed'));
    final userRole = _studentProfile.major.isNotEmpty
        ? _studentProfile.major
        : (widget.isArabic ? 'طالب جامعي' : 'University Student');

    return Drawer(
      width: 320,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        children: [
          // Drawer Header with gradient matching reference
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 16,
              16,
              20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B2577), Color(0xFF1E5BF0)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: Column(
              children: [
                // Mascot + Logo + Tagline
                Row(
                  textDirection: TextDirection.ltr,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/branding/edunivora_app_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'EduNivora',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Learn • Plan • Achieve',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // User avatar + info row
                Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                            child: Text(
                              _avatarText(_studentProfile.avatar),
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            userRole,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Drawer Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              children: [
                // Section 1: الأكاديمية
                _buildRefDrawerCategoryHeader(
                  title: widget.isArabic ? 'الأكاديمية' : 'Academic',
                  icon: Icons.school_rounded,
                  isDark: isDark,
                ),
                _buildRefDrawerTile(
                  icon: Icons.home_rounded,
                  title: widget.isArabic ? 'لوحة التحكم' : 'Dashboard',
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    if (_selectedBottomNav != 0) {
                      setState(() => _selectedBottomNav = 0);
                    }
                  },
                ),

                _buildRefDrawerTile(
                  icon: Icons.campaign_outlined,
                  title: widget.isArabic
                      ? 'التعميمات والإشعارات'
                      : 'Announcements & Notifications',
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommunicationsScreen(
                          taskUseCases: widget.taskUseCases,
                          courseUseCases: widget.courseUseCases,
                          authUseCases: widget.authUseCases,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Section 2: أدوات الإنتاجية
                _buildRefDrawerCategoryHeader(
                  title: widget.isArabic
                      ? 'أدوات الإنتاجية'
                      : 'Productivity Tools',
                  icon: Icons.build_rounded,
                  isDark: isDark,
                ),
                _buildRefDrawerTile(
                  icon: Icons.psychology_outlined,
                  title: widget.isArabic ? 'مخطط المذاكرة' : 'Study Planner',
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudyPlannerScreen(
                          courseUseCases: widget.courseUseCases,
                          taskUseCases: widget.taskUseCases,
                          onTasksChanged: widget.onRefresh,
                        ),
                      ),
                    );
                  },
                ),

                _buildRefDrawerTile(
                  icon: Icons.timer_outlined,
                  title: widget.isArabic ? 'وضع التركيز' : 'Focus Mode',
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FocusTimerScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),
                // Section 3: الحساب
                _buildRefDrawerCategoryHeader(
                  title: widget.isArabic ? 'الحساب' : 'Account',
                  icon: Icons.person_rounded,
                  isDark: isDark,
                ),
                _buildRefDrawerTile(
                  icon: Icons.person_outline_rounded,
                  title: widget.isArabic
                      ? 'الملف الأكاديمي'
                      : 'Academic Profile',
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    _showProfileEditor();
                  },
                ),

                const SizedBox(height: 12),
                // Section 4: التفضيلات والنظام
                _buildRefDrawerCategoryHeader(
                  title: widget.isArabic
                      ? 'التفضيلات والنظام'
                      : 'Preferences & System',
                  icon: Icons.nightlight_round,
                  isDark: isDark,
                ),
                // Dark mode toggle tile with Switch matching reference
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.dark_mode_outlined,
                              size: 20,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              widget.isArabic ? 'الوضع الداكن' : 'Dark Mode',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: widget.isDarkMode,
                        onChanged: widget.onThemeChanged,
                        activeThumbColor: const Color(0xFF2563EB),
                      ),
                    ],
                  ),
                ),
                _buildRefDrawerTile(
                  icon: Icons.settings_outlined,
                  title: widget.isArabic ? 'الإعدادات' : 'Settings',
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          isDarkMode: widget.isDarkMode,
                          onThemeChanged: widget.onThemeChanged,
                          isArabic: widget.isArabic,
                          onLanguageChanged: widget.onLanguageChanged,
                          appLockService: _appLockService,
                          onDataCleared: _refreshAfterLocalDataClear,
                        ),
                      ),
                    );
                  },
                ),
                if (currentUser?.isAdmin == true) ...[
                  const SizedBox(height: 10),
                  _buildRefDrawerCategoryHeader(
                    title: widget.isArabic ? 'الإدارة' : 'Administration',
                    icon: Icons.admin_panel_settings_outlined,
                    isDark: isDark,
                  ),
                  _buildRefDrawerTile(
                    icon: Icons.admin_panel_settings_outlined,
                    title: widget.isArabic
                        ? 'إدارة التعميمات'
                        : 'Manage Announcements',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminAnnouncementsScreen(
                            authUseCases: widget.authUseCases,
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 10),
                // Support & About App
                _buildRefDrawerTile(
                  icon: Icons.info_outline_rounded,
                  title: widget.isArabic
                      ? 'عن تطبيق EduNivora'
                      : 'About EduNivora',
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutAppScreen()),
                    );
                  },
                ),
                _buildRefDrawerTile(
                  icon: Icons.groups_rounded,
                  title: widget.isArabic
                      ? 'الفريق والمؤسسون'
                      : 'Team & Founders',
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    );
                  },
                ),
                _buildRefDrawerTile(
                  icon: Icons.contact_support_outlined,
                  title: widget.isArabic ? 'التواصل' : 'Contact',
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ContactScreen()),
                    );
                  },
                ),
                _buildRefDrawerTile(
                  icon: Icons.help_outline_rounded,
                  title: widget.isArabic ? 'مركز المساعدة' : 'Help Center',
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HelpCenterScreen(),
                      ),
                    );
                  },
                ),
                _buildRefDrawerTile(
                  icon: Icons.logout_rounded,
                  title: widget.isArabic ? 'تسجيل الخروج' : 'Logout',
                  isDark: isDark,
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await widget.authUseCases.logout.call();
                    } catch (error, stackTrace) {
                      debugPrint(
                        'HomeScreen.logout error: $error\n$stackTrace',
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'تعذّر تسجيل الخروج لأن التخزين الآمن غير متاح.',
                          ),
                        ),
                      );
                      return;
                    }
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => AuthGateScreen(
                          authUseCases: widget.authUseCases,
                          taskUseCases: widget.taskUseCases,
                          courseUseCases: widget.courseUseCases,
                          isDarkMode: widget.isDarkMode,
                          isArabic: widget.isArabic,
                          onThemeChanged: widget.onThemeChanged,
                          onLanguageChanged: widget.onLanguageChanged,
                        ),
                      ),
                      (route) => false,
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefDrawerCategoryHeader({
    required String title,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E40AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefDrawerTile({
    required IconData icon,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF2563EB)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                ),
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              size: 20,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceBottomNav(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              // 0: الرئيسية (Home)
              Expanded(
                child: _buildBottomNavItem(
                  index: 0,
                  icon: Icons.home_rounded,
                  unselectedIcon: Icons.home_outlined,
                  label: widget.isArabic ? 'الرئيسية' : 'Home',
                  isSelected: _selectedBottomNav == 0,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedBottomNav = 0),
                ),
              ),
              // 1: المهام (Tasks)
              Expanded(
                child: _buildBottomNavItem(
                  index: 1,
                  icon: Icons.check_circle_rounded,
                  unselectedIcon: Icons.check_circle_outline_rounded,
                  label: widget.isArabic ? 'المهام' : 'Tasks',
                  isSelected: _selectedBottomNav == 1,
                  isDark: isDark,
                  onTap: () {
                    setState(() {
                      _selectedBottomNav = 1;
                      _showTaskControls = true;
                    });
                  },
                ),
              ),
              // 2: الجدول (Schedule)
              Expanded(
                child: _buildBottomNavItem(
                  index: 2,
                  icon: Icons.calendar_month_rounded,
                  unselectedIcon: Icons.calendar_month_outlined,
                  label: widget.isArabic ? 'الجدول' : 'Schedule',
                  isSelected: _selectedBottomNav == 2,
                  isDark: isDark,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ScheduleScreen(authUseCases: widget.authUseCases),
                      ),
                    );
                    _loadScheduleAndTerm();
                  },
                ),
              ),
              // 3: التقارير (Reports)
              Expanded(
                child: _buildBottomNavItem(
                  index: 3,
                  icon: Icons.bar_chart_rounded,
                  unselectedIcon: Icons.poll_outlined,
                  label: widget.isArabic ? 'التقارير' : 'Reports',
                  isSelected: _selectedBottomNav == 3,
                  isDark: isDark,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AcademicReportsScreen(),
                      ),
                    );
                  },
                ),
              ),
              // 4: المزيد (More)
              Expanded(
                child: _buildBottomNavItem(
                  index: 4,
                  icon: Icons.grid_view_rounded,
                  unselectedIcon: Icons.grid_view_outlined,
                  label: widget.isArabic ? 'المزيد' : 'More',
                  isSelected: false,
                  isDark: isDark,
                  onTap: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required IconData icon,
    required IconData unselectedIcon,
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    const activeColor = Color(0xFF2563EB);
    final inactiveColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? icon : unselectedIcon,
            color: isSelected ? activeColor : inactiveColor,
            size: 24,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isAppLocked) {
      return PinLockScreen(
        appLockService: _appLockService,
        onVerified: () async {
          await _appLockService.updateLastActive();
          if (!mounted) return;
          setState(() {
            _isAppLocked = false;
          });
        },
      );
    }

    final isDark = widget.isDarkMode;

    final primary = Theme.of(context).colorScheme.primary;
    final completionRate = widget.taskState.tasks.isEmpty
        ? 0
        : ((_completedTasksCount / widget.taskState.tasks.length) * 100)
              .round();

    return FutureBuilder<UserEntity?>(
      future: _currentUserFuture,
      builder: (context, snapshot) {
        final currentUser = snapshot.data;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: isDark
              ? const Color(0xFF0F172A)
              : const Color(0xFFF6F8FD),
          drawer: _buildReferenceDrawer(context, currentUser, isDark, primary),
          bottomNavigationBar: _buildReferenceBottomNav(context, isDark),
          body: widget.taskState.errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.taskState.errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadTasks,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildReferenceHeader(context, currentUser, isDark),
                        const SizedBox(height: 14),
                        _buildReferenceStatsRow(
                          context,
                          completionRate,
                          isDark,
                        ),
                        const SizedBox(height: 18),
                        _buildReferenceScheduleSection(context, isDark),
                        const SizedBox(height: 18),
                        _buildReferenceUpcomingTasksSection(context, isDark),
                        const SizedBox(height: 18),
                        _buildReferenceQuickAccessSection(context, isDark),
                        const SizedBox(height: 18),
                        if (_showMotivationCard) _buildMotivationCard(),
                        const SizedBox(height: 12),
                        _buildSmartAcademicCard(context),
                        const SizedBox(height: 16),
                        if (_showTaskControls || _selectedBottomNav == 1) ...[
                          // Search field
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextFormField(
                              controller: _searchController,
                              onFieldSubmitted: (_) => _showGlobalSearch(),
                              decoration: InputDecoration(
                                prefixIcon: IconButton(
                                  icon: const Icon(Icons.search_outlined),
                                  onPressed: _showGlobalSearch,
                                ),
                                hintText: widget.isArabic
                                    ? 'ابحث عن مادة، مهمة، أو ملاحظة...'
                                    : 'Search tasks, subjects, or notes...',
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Status filter chips
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: TaskSearchStatus.values.map((status) {
                                  final isSelected = _statusFilter == status;
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: ChoiceChip(
                                      label: Text(status.label),
                                      selected: isSelected,
                                      onSelected: (_) async =>
                                          _saveStatusFilter(status),
                                      selectedColor: const Color(
                                        0xFF2563EB,
                                      ).withValues(alpha: 0.18),
                                      backgroundColor: isDark
                                          ? const Color(0xFF1E293B)
                                          : Colors.white,
                                      labelStyle: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF2563EB)
                                            : (isDark
                                                  ? Colors.white70
                                                  : Colors.black87),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Course filter dropdown & sort popup
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue:
                                        _selectedCourseFilter ?? 'الكل',
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: isDark
                                          ? const Color(0xFF1E293B)
                                          : Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                    ),
                                    items: _courseFilterOptions
                                        .map(
                                          (option) => DropdownMenuItem(
                                            value: option,
                                            child: Text(option),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) async {
                                      if (value == null) return;
                                      await _saveCourseFilter(value);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<TaskSortMode>(
                                  initialValue: _sortMode,
                                  tooltip: 'ترتيب المهام',
                                  icon: const Icon(Icons.sort_rounded),
                                  onSelected: (mode) async =>
                                      _saveSortMode(mode),
                                  itemBuilder: (context) => TaskSortMode.values
                                      .map(
                                        (mode) => PopupMenuItem(
                                          value: mode,
                                          child: Text(mode.label),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Grouped tasks list
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: widget.taskState.tasks.isEmpty
                                ? _buildEmptyState(context)
                                : Column(
                                    children: _groupTasksByCourse().entries.expand((
                                      entry,
                                    ) {
                                      final groupTitle = entry.key;
                                      final tasks = entry.value;
                                      return [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            16,
                                            16,
                                            6,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                groupTitle,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF0F172A),
                                                ),
                                              ),
                                              Text(
                                                widget.isArabic
                                                    ? (tasks.length == 1
                                                          ? 'مهمة واحدة'
                                                          : '${tasks.length} مهام')
                                                    : '${tasks.length} tasks',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark
                                                      ? Colors.white60
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ...tasks.map(
                                          (t) =>
                                              _buildTaskItemRefCard(t, isDark),
                                        ),
                                      ];
                                    }).toList(),
                                  ),
                          ),
                        ],
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
