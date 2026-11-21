import 'package:flutter/material.dart';

import '../../core/config/edunivora_identity.dart';
import '../../core/security/app_lock_service.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/widgets/edunivora_ui.dart';
import '../../data/database/database_helper.dart';
import '../about/about_app_screen.dart';
import '../about/about_screen.dart';
import '../about/contact_screen.dart';
import '../about/help_center_screen.dart';
import '../about/privacy_terms_screen.dart';
import '../auth/app_lock_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final bool? isArabic;
  final ValueChanged<bool>? onLanguageChanged;
  final AppLockService? appLockService;
  final Future<void> Function()? onDataCleared;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    this.isArabic,
    this.onLanguageChanged,
    this.appLockService,
    this.onDataCleared,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isProcessing = false;
  late bool _isDarkMode;
  bool? _isArabic;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _isArabic = widget.isArabic;
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      _isDarkMode = widget.isDarkMode;
    }
    if (oldWidget.isArabic != widget.isArabic) {
      _isArabic = widget.isArabic;
    }
  }

  bool _resolveIsArabic(BuildContext context) {
    if (_isArabic != null) return _isArabic!;
    return isArabicLocale(context);
  }

  Future<void> _clearAllData(bool isAr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isAr ? 'حذف البيانات الأكاديمية المحلية؟' : 'Delete local academic data?',
        ),
        content: Text(
          isAr
              ? 'سيتم حذف المواد والمهام والاختبارات والجدول والمرفقات من هذا الجهاز. '
                    'لا يمكن التراجع عن هذا الإجراء.'
              : 'Subjects, tasks, exams, schedules, and attachments stored on this device will be permanently removed. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(isAr ? 'حذف البيانات' : 'Delete data'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        // Delete dependent records before their parent courses.
        await txn.delete('course_materials');
        await txn.delete('schedule');
        await txn.delete('exams');
        await txn.delete('tasks');
        await txn.delete('courses');
        await txn.delete('academic_terms');
      });

      final notificationsCancelled =
          await NotificationService.instance.cancelAllNotifications();
      try {
        await widget.onDataCleared?.call();
      } catch (refreshError, refreshStackTrace) {
        debugPrint('Refreshing home after data clear failed: $refreshError\\n$refreshStackTrace');
      }

      if (!mounted) return;
      final successMessage = isAr
          ? (notificationsCancelled
              ? 'تم حذف البيانات الأكاديمية وإلغاء التذكيرات المحلية.'
              : 'تم حذف البيانات الأكاديمية، لكن تعذر إلغاء بعض التذكيرات.')
          : (notificationsCancelled
              ? 'Academic data deleted and local reminders cancelled.'
              : 'Academic data deleted, but some reminders could not be cancelled.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error, stackTrace) {
      debugPrint('Clearing local academic data failed: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'تعذر حذف البيانات: $error' : 'Failed to clear data: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildNavTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: primary, size: 22),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAr = _resolveIsArabic(context);

    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'الإعدادات' : 'Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Appearance & Preferences ────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'المظهر والتفضيلات' : 'Appearance & Preferences',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isDarkMode
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    value: _isDarkMode,
                    onChanged: (value) {
                      setState(() => _isDarkMode = value);
                      widget.onThemeChanged(value);
                    },
                    title: Text(isAr ? 'الوضع الداكن' : 'Dark Mode'),
                    subtitle: Text(
                      isAr
                          ? 'التبديل بين المظهر الفاتح والداكن'
                          : 'Switch between light and dark themes',
                    ),
                  ),
                  if (widget.onLanguageChanged != null) ...[
                    const Divider(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.language_rounded,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      value: isAr,
                      onChanged: (value) {
                        setState(() => _isArabic = value);
                        widget.onLanguageChanged!(value);
                      },
                      title: Text(isAr ? 'اللغة العربية' : 'Arabic Language'),
                      subtitle: Text(
                        isAr ? 'العربية / English' : 'English / العربية',
                      ),
                    ),
                  ],
                  if (widget.appLockService != null) ...[
                    const Divider(height: 16),
                    _buildNavTile(
                      context: context,
                      icon: Icons.lock_outline_rounded,
                      title: isAr
                          ? 'قفل التطبيق والأمان'
                          : 'App Lock & Security',
                      subtitle: isAr
                          ? 'إعداد رمز PIN والمصادقة البيومترية'
                          : 'Configure PIN and biometric lock',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppLockSettingsScreen(
                            appLockService: widget.appLockService!,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ── About & Support section ─────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'معلومات التطبيق والدعم' : 'App Info & Support',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildNavTile(
                    context: context,
                    icon: Icons.info_outline_rounded,
                    title: isAr ? 'عن التطبيق' : 'About EduNivora',
                    subtitle: isAr
                        ? '${EdunivoraIdentity.appName} - الإصدار ${EdunivoraIdentity.versionDisplay}'
                        : '${EdunivoraIdentity.appName} - Version ${EdunivoraIdentity.versionDisplay}',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutAppScreen()),
                    ),
                  ),
                  const Divider(height: 8),
                  _buildNavTile(
                    context: context,
                    icon: Icons.people_outline_rounded,
                    title: isAr ? 'الفريق والمؤسسون' : 'Team & Founders',
                    subtitle: isAr
                        ? 'فريق تطوير المنظومة'
                        : 'EduNivora Development Team',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                  ),
                  const Divider(height: 8),
                  _buildNavTile(
                    context: context,
                    icon: Icons.help_outline_rounded,
                    title: isAr ? 'مركز المساعدة' : 'Help Center',
                    subtitle: isAr
                        ? 'الأسئلة الشائعة والدليل'
                        : 'FAQs and usage guide',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HelpCenterScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 8),
                  _buildNavTile(
                    context: context,
                    icon: Icons.contact_support_outlined,
                    title: isAr ? 'تواصل معنا' : 'Contact Us',
                    subtitle: isAr
                        ? 'الدعم والاقتراحات'
                        : 'Support and feedback',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ContactScreen()),
                    ),
                  ),
                  const Divider(height: 8),
                  _buildNavTile(
                    context: context,
                    icon: Icons.privacy_tip_outlined,
                    title: isAr ? 'الخصوصية والشروط' : 'Privacy & Terms',
                    subtitle: isAr
                        ? 'سياسة الخصوصية وشروط الاستخدام'
                        : 'Privacy policy and terms of use',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyTermsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ── Local Data Management (Danger Zone) ─────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'إدارة البيانات المحلية' : 'Local Data Management',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _clearAllData(isAr),
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: Text(
                        isAr
                            ? 'حذف جميع البيانات المحلية'
                            : 'Delete all local data',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const EduBrandFooter(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
