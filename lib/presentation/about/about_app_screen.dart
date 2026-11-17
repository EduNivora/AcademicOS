import 'package:flutter/material.dart';
import '../../core/config/edunivora_identity.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/edunivora_ui.dart';
import 'about_screen.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = isArabicLocale(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bodyColor = isDark ? AppTheme.textSecondary : const Color(0xFF475569);

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'عن التطبيق' : 'About App'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // Hero identity banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1D4ED8),
                  Color(0xFF14B8A6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const EduBrandMark(size: 64, borderRadius: 18),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            EdunivoraIdentity.appName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isArabic
                                  ? 'الإصدار v${EdunivoraIdentity.versionDisplay} • Offline-First'
                                  : 'v${EdunivoraIdentity.versionDisplay} • Offline-First Edition',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  EdunivoraIdentity.tagline.resolve(isArabic),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Overview
          EduSectionHeader(
            icon: Icons.info_outline_rounded,
            title: isArabic ? 'نظرة عامة على المنتج' : 'Product Overview',
            accentColor: AppTheme.primary,
          ),
          const SizedBox(height: 10),
          EduSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  EdunivoraIdentity.overview.resolve(isArabic),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: bodyColor,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.groups_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${isArabic ? 'الجهة المطوّرة' : 'Developing Organization'}: '
                          '${EdunivoraIdentity.developingOrganization.resolve(isArabic)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Problems Solved & Target Audience
          EduSectionHeader(
            icon: Icons.psychology_alt_rounded,
            title: isArabic
                ? 'المشكلات التي يحلها التطبيق والفئة المستهدفة'
                : 'Problems Solved & Target Audience',
            accentColor: AppTheme.primaryStrong,
          ),
          const SizedBox(height: 10),
          EduSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'المشكلات التي يعالجها' : 'Problems Solved',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ...EdunivoraIdentity.problemsSolved.map(
                  (item) => _BulletRow(
                    text: item.resolve(isArabic),
                    icon: Icons.check_circle_outline_rounded,
                    color: AppTheme.primaryStrong,
                    bodyColor: bodyColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isArabic ? 'الفئة المستهدفة' : 'Target Audience',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ...EdunivoraIdentity.targetAudience.map(
                  (item) => _BulletRow(
                    text: item.resolve(isArabic),
                    icon: Icons.person_outline_rounded,
                    color: AppTheme.success,
                    bodyColor: bodyColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Vision, Mission, Objectives & Values
          EduSectionHeader(
            icon: Icons.flag_outlined,
            title: isArabic
                ? 'الرؤية والرسالة والأهداف والقيم'
                : 'Vision, Mission, Objectives & Values',
            accentColor: AppTheme.success,
          ),
          const SizedBox(height: 10),
          EduSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabeledBlock(
                  title: isArabic ? 'الرؤية' : 'Vision',
                  content: EdunivoraIdentity.vision.resolve(isArabic),
                  color: AppTheme.primary,
                  bodyColor: bodyColor,
                ),
                const SizedBox(height: 12),
                _LabeledBlock(
                  title: isArabic ? 'الرسالة' : 'Mission',
                  content: EdunivoraIdentity.mission.resolve(isArabic),
                  color: AppTheme.success,
                  bodyColor: bodyColor,
                ),
                const SizedBox(height: 14),
                Text(
                  isArabic ? 'الأهداف الرئيسية' : 'Core Objectives',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ...EdunivoraIdentity.coreObjectives.map(
                  (item) => _BulletRow(
                    text: item.resolve(isArabic),
                    icon: Icons.track_changes_rounded,
                    color: AppTheme.primary,
                    bodyColor: bodyColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isArabic ? 'القيم الأساسية' : 'Core Values',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ...EdunivoraIdentity.productValues.map(
                  (item) => _BulletRow(
                    text: item.resolve(isArabic),
                    icon: Icons.auto_awesome_rounded,
                    color: AppTheme.warning,
                    bodyColor: bodyColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Implemented Capabilities vs Planned Development
          EduSectionHeader(
            icon: Icons.widgets_outlined,
            title: isArabic
                ? 'القدرات المتوفرة حالياً'
                : 'Currently Implemented Capabilities',
            subtitle: isArabic
                ? 'الميزات الفعلية العاملة في هذا الإصدار'
                : 'Verified features implemented in this release',
            accentColor: AppTheme.success,
          ),
          const SizedBox(height: 10),
          EduSurfaceCard(
            child: Column(
              children: EdunivoraIdentity.implementedCapabilities
                  .map(
                    (cap) => _BulletRow(
                      text: cap.resolve(isArabic),
                      icon: Icons.verified_rounded,
                      color: AppTheme.success,
                      bodyColor: bodyColor,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),

          EduSectionHeader(
            icon: Icons.upcoming_outlined,
            title: isArabic
                ? 'التطوير المستقبلي المخطط له'
                : 'Planned Future Development',
            subtitle: isArabic
                ? 'ميزات مخططة وليست مفعّلة بعد في الإصدار الحالي'
                : 'Planned roadmap items — not yet active in this version',
            accentColor: AppTheme.warning,
          ),
          const SizedBox(height: 10),
          EduSurfaceCard(
            borderColor: AppTheme.warning.withValues(alpha: 0.4),
            child: Column(
              children: EdunivoraIdentity.plannedFutureDevelopment
                  .map(
                    (item) => _BulletRow(
                      text: item.resolve(isArabic),
                      icon: Icons.schedule_rounded,
                      color: AppTheme.warning,
                      bodyColor: bodyColor,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Release notes
          EduSectionHeader(
            icon: Icons.new_releases_outlined,
            title: isArabic
                ? 'ملاحظات الإصدار v${EdunivoraIdentity.versionDisplay}'
                : 'Release Notes v${EdunivoraIdentity.versionDisplay}',
            accentColor: AppTheme.primary,
          ),
          const SizedBox(height: 10),
          EduSurfaceCard(
            child: Column(
              children: EdunivoraIdentity.releaseNotes
                  .map(
                    (note) => _BulletRow(
                      text: note.resolve(isArabic),
                      icon: Icons.bolt_rounded,
                      color: AppTheme.primary,
                      bodyColor: bodyColor,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Tech stack
          EduSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'التقنيات المستخدمة' : 'Built With',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: EdunivoraIdentity.techStack
                      .map((chip) => Chip(label: Text(chip)))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Button to Team & Founders
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AboutScreen()));
              },
              icon: const Icon(Icons.people_outline_rounded),
              label: Text(
                isArabic
                    ? 'تعرّف على الفريق والمؤسسين'
                    : 'Meet the Team & Founders',
              ),
            ),
          ),
          const SizedBox(height: 20),
          const EduBrandFooter(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _LabeledBlock extends StatelessWidget {
  final String title;
  final String content;
  final Color color;
  final Color bodyColor;

  const _LabeledBlock({
    required this.title,
    required this.content,
    required this.color,
    required this.bodyColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(color: bodyColor, fontSize: 13.5, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final Color bodyColor;

  const _BulletRow({
    required this.text,
    required this.icon,
    required this.color,
    required this.bodyColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: bodyColor, fontSize: 13.5, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}
