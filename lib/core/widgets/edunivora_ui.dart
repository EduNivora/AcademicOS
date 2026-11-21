import 'package:flutter/material.dart';
import '../config/edunivora_identity.dart';
import '../theme/app_theme.dart';

bool isArabicLocale(BuildContext context) {
  final locale = Localizations.maybeLocaleOf(context);
  if (locale?.languageCode.toLowerCase() == 'ar') {
    return true;
  }
  return Directionality.of(context) == TextDirection.rtl;
}

class EduSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;
  final Widget? trailing;

  const EduSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? theme.colorScheme.primary;
    final mutedColor = theme.brightness == Brightness.dark
        ? AppTheme.textMuted
        : AppTheme.mutedTextLight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16.5,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: mutedColor,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class EduSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderRadius;

  const EduSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor =
        theme.cardTheme.color ??
        (isDark ? const Color(0xFF111827) : theme.colorScheme.surface);
    final effectiveBorder =
        borderColor ??
        (isDark
            ? const Color(0xFF1E293B)
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.7));

    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: effectiveBorder),
      ),
      child: child,
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      ),
    );
  }
}

class EduEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EduEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppTheme.textMuted
        : const Color(0xFF64748B);

    return EduSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: muted,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class EduErrorState extends StatelessWidget {
  final String title;
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;

  const EduErrorState({
    super.key,
    required this.title,
    required this.message,
    this.retryLabel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppTheme.textSecondary
        : AppTheme.mutedTextLight;

    return EduSurfaceCard(
      borderColor: AppTheme.danger.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.danger,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: muted,
              height: 1.5,
            ),
          ),
          if (retryLabel != null && onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(retryLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class EduDraftBanner extends StatelessWidget {
  final String message;
  final String? title;

  const EduDraftBanner({super.key, required this.message, this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foreground = isDark
        ? const Color(0xFFFCD34D)
        : const Color(0xFFB45309);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.warning.withValues(alpha: isDark ? 0.5 : 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: foreground, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title!.isNotEmpty) ...[
                  Text(
                    title!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EduBrandMark extends StatelessWidget {
  final double size;
  final double borderRadius;

  const EduBrandMark({super.key, this.size = 64, this.borderRadius = 18});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        'assets/branding/edunivora_app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Icon(
            Icons.school_rounded,
            color: Colors.white,
            size: size * 0.52,
          ),
        ),
      ),
    );
  }
}

class EduBrandFooter extends StatelessWidget {
  final bool showVersion;

  const EduBrandFooter({super.key, this.showVersion = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isArabic = isArabicLocale(context);
    final muted = isDark ? AppTheme.textMuted : AppTheme.mutedTextLight;

    return EduSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      borderRadius: 18,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const EduBrandMark(size: 24, borderRadius: 6),
              const SizedBox(width: 8),
              Text(
                showVersion
                    ? '${EdunivoraIdentity.appName} v${EdunivoraIdentity.versionDisplay}'
                    : EdunivoraIdentity.appName,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isDark ? AppTheme.primaryTextDark : AppTheme.primaryTextLight,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            EdunivoraIdentity.officialTagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            EdunivoraIdentity.attribution,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
              fontSize: 12.5,
              height: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            EdunivoraIdentity.copyright.resolve(isArabic),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted.withValues(alpha: 0.85),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
