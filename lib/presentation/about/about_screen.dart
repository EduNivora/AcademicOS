import 'package:flutter/material.dart';
import '../../core/config/edunivora_identity.dart';
import '../../core/services/external_link_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/edunivora_ui.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  IconData _iconForLinkKind(FounderLinkKind kind) {
    switch (kind) {
      case FounderLinkKind.github:
        return Icons.code_rounded;
      case FounderLinkKind.website:
        return Icons.language_rounded;
      case FounderLinkKind.linkedin:
        return Icons.work_outline_rounded;
      case FounderLinkKind.credly:
        return Icons.verified_rounded;
      case FounderLinkKind.orcid:
        return Icons.science_rounded;
      case FounderLinkKind.instagram:
        return Icons.camera_alt_outlined;
      case FounderLinkKind.tiktok:
        return Icons.music_note_rounded;
      case FounderLinkKind.email:
        return Icons.email_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = isArabicLocale(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'الفريق والمؤسسون' : 'Team & Founders'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E1B4B),
                  Color(0xFF312E81),
                  Color(0xFF0EA5E9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.people_alt_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isArabic ? 'الفريق والمؤسسون' : 'Team & Founders',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 21,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isArabic
                      ? 'مؤسسان شريكان بمسؤولية ورؤية واحدة لبناء منصة ${EdunivoraIdentity.appName} الأكاديمية'
                      : 'Two equal co-founders building the ${EdunivoraIdentity.appName} academic platform together',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...EdunivoraIdentity.founders.asMap().entries.map((entry) {
            final index = entry.key;
            final founder = entry.value;
            final gradientColors = index == 0
                ? const <Color>[
                    Color(0xFF1E1B4B),
                    Color(0xFF312E81),
                    Color(0xFF0EA5E9),
                  ]
                : const <Color>[
                    Color(0xFF064E3B),
                    Color(0xFF065F46),
                    Color(0xFF059669),
                  ];
            final accentColor = index == 0
                ? AppTheme.primary
                : AppTheme.success;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == EdunivoraIdentity.founders.length - 1 ? 0 : 18,
              ),
              child: _FounderProfileCard(
                founder: founder,
                isArabic: isArabic,
                gradientColors: gradientColors,
                accentColor: accentColor,
                iconResolver: _iconForLinkKind,
              ),
            );
          }),
          const SizedBox(height: 22),
          const EduBrandFooter(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FounderProfileCard extends StatelessWidget {
  final FounderProfile founder;
  final bool isArabic;
  final List<Color> gradientColors;
  final Color accentColor;
  final IconData Function(FounderLinkKind kind) iconResolver;

  const _FounderProfileCard({
    required this.founder,
    required this.isArabic,
    required this.gradientColors,
    required this.accentColor,
    required this.iconResolver,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedText = isDark ? AppTheme.textMuted : const Color(0xFF64748B);
    final bodyText = isDark ? AppTheme.textSecondary : const Color(0xFF475569);
    final chipBg = isDark
        ? const Color(0xFF0F172A)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final borderColor = isDark
        ? const Color(0xFF1E293B)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.7);

    return EduSurfaceCard(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(23),
                topRight: Radius.circular(23),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      founder.initials,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        founder.primaryName(isArabic),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        founder.secondaryName(isArabic),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (founder.brand != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            founder.brand!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${founder.roleAr} / ${founder.roleEn}',
                    style: TextStyle(
                      color: isDark ? AppTheme.accentGlow : accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: founder.titles
                      .map(
                        (title) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            title,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: bodyText,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  founder.bio(isArabic),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: bodyText,
                    fontSize: 13.5,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => ExternalLinkService.openUrl(
                      context,
                      founder.websiteUrl,
                      label: isArabic ? 'الموقع الشخصي' : 'Personal Website',
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(
                      isArabic ? 'زيارة الموقع الشخصي' : 'Visit Website',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: borderColor),
                const SizedBox(height: 14),
                Text(
                  isArabic ? 'الروابط المهنية الموثّقة' : 'Verified Links',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: founder.links.map((link) {
                    return _FounderLinkChip(
                      icon: iconResolver(link.kind),
                      label: link.label(isArabic),
                      accentColor: accentColor,
                      chipBg: chipBg,
                      borderColor: borderColor,
                      onOpen: () => ExternalLinkService.openUrl(
                        context,
                        link.url,
                        label: link.label(isArabic),
                      ),
                      onCopy: () => ExternalLinkService.copyToClipboard(
                        context,
                        link.kind == FounderLinkKind.email
                            ? link.displayValue
                            : link.url,
                        feedbackMessage: isArabic
                            ? 'تم نسخ ${link.labelAr}'
                            : 'Copied ${link.labelEn}',
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FounderLinkChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final Color chipBg;
  final Color borderColor;
  final VoidCallback onOpen;
  final VoidCallback onCopy;

  const _FounderLinkChip({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.chipBg,
    required this.borderColor,
    required this.onOpen,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? AppTheme.textPrimary : accentColor;

    return Material(
      color: chipBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpen,
        onLongPress: onCopy,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: onCopy,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
