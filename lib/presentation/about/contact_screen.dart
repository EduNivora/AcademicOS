import 'package:flutter/material.dart';
import '../../core/config/edunivora_identity.dart';
import '../../core/services/external_link_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/edunivora_ui.dart';

enum _InquiryType { bugReport, featureRequest }

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  _InquiryType _inquiryType = _InquiryType.bugReport;

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  String _subjectPrefix() {
    switch (_inquiryType) {
      case _InquiryType.bugReport:
        return 'EduNivora Bug Report';
      case _InquiryType.featureRequest:
        return 'EduNivora Feature Request';
    }
  }

  String _buildFullSubject() {
    final subject = _subjectController.text.trim();
    return '${_subjectPrefix()}: $subject';
  }

  String _buildFormattedBody(bool isArabic) {
    final name = _nameController.text.trim();
    final details = _detailsController.text.trim();
    final typeLabel = _inquiryType == _InquiryType.bugReport
        ? (isArabic ? 'الإبلاغ عن مشكلة' : 'Bug Report')
        : (isArabic ? 'اقتراح ميزة' : 'Feature Request');

    final buffer = StringBuffer()
      ..writeln(
        '${EdunivoraIdentity.appName} v${EdunivoraIdentity.versionDisplay}',
      )
      ..writeln('Type: $typeLabel');
    if (name.isNotEmpty) {
      buffer.writeln('From: $name');
    }
    buffer
      ..writeln('Subject: ${_subjectController.text.trim()}')
      ..writeln()
      ..writeln(details);
    return buffer.toString();
  }

  Future<void> _openEmailDraft(bool isArabic) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final recipient =
        EdunivoraIdentity.contactConfig.verifiedFounderSupportEmail;
    final uri = Uri(
      scheme: 'mailto',
      path: recipient,
      queryParameters: <String, String>{
        'subject': _buildFullSubject(),
        'body': _buildFormattedBody(isArabic),
      },
    );

    await ExternalLinkService.openUrl(
      context,
      uri.toString(),
      label: isArabic ? 'مسودة البريد الإلكتروني' : 'Email draft',
    );
  }

  Future<void> _copyStructuredReport(bool isArabic) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final recipient =
        EdunivoraIdentity.contactConfig.verifiedFounderSupportEmail;
    final report =
        'To: $recipient\n'
        'Subject: ${_buildFullSubject()}\n\n'
        '${_buildFormattedBody(isArabic)}';

    await ExternalLinkService.copyToClipboard(
      context,
      report,
      feedbackMessage: isArabic
          ? 'تم نسخ التقرير للحافظة (لا يوجد إرسال تلقائي للخادم — الصقه في تطبيق البريد إلى $recipient)'
          : 'Report copied to clipboard (no server auto-submission — paste it in your email app to $recipient)',
    );
  }

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
    final isDark = theme.brightness == Brightness.dark;
    final mutedText = isDark ? AppTheme.textMuted : const Color(0xFF64748B);
    final bodyText = isDark ? AppTheme.textSecondary : const Color(0xFF475569);
    final pendingLabel = isArabic
        ? 'بانتظار اعتماد المالك'
        : 'Pending owner approval';

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'تواصل معنا' : 'Contact Us'),
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
                  Color(0xFF1E1B4B),
                  Color(0xFF312E81),
                  Color(0xFF0EA5E9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.contact_support_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                const SizedBox(height: 10),
                Text(
                  isArabic
                      ? 'تواصل مع فريق ${EdunivoraIdentity.appName}'
                      : 'Contact the ${EdunivoraIdentity.appName} Team',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isArabic
                      ? 'يمكنك فتح روابط المؤسسين الموثّقة مباشرةً أو نسخها للحافظة، أو تجهيز مسودة بريد للإبلاغ عن مشكلة أو اقتراح ميزة.'
                      : 'Open or copy verified founder links directly, or draft a structured bug report / feature request email.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Official EduNivora Channels (pending owner approval — no fabricated channels)
          EduSectionHeader(
            icon: Icons.verified_outlined,
            title: isArabic
                ? 'القنوات الرسمية لـ ${EdunivoraIdentity.appName}'
                : 'Official ${EdunivoraIdentity.appName} Channels',
            subtitle: isArabic
                ? 'سيتم تفعيلها فور اعتمادها رسمياً من المالكين'
                : 'Will be activated once formally approved by the owners',
            accentColor: AppTheme.warning,
          ),
          const SizedBox(height: 10),
          EduSurfaceCard(
            borderColor: AppTheme.warning.withValues(alpha: 0.4),
            child: Column(
              children: [
                _PendingChannelRow(
                  icon: Icons.support_agent_rounded,
                  title: isArabic
                      ? 'البريد الرسمي للدعم'
                      : 'Official Support Email',
                  statusLabel:
                      EdunivoraIdentity.contactConfig.officialSupportEmail ??
                      pendingLabel,
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _PendingChannelRow(
                  icon: Icons.language_rounded,
                  title: isArabic ? 'الموقع الرسمي للمنصة' : 'Official Website',
                  statusLabel:
                      EdunivoraIdentity.contactConfig.officialWebsite ??
                      pendingLabel,
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _PendingChannelRow(
                  icon: Icons.public_rounded,
                  title: isArabic
                      ? 'قنوات التواصل الاجتماعي'
                      : 'Social Media Channels',
                  statusLabel:
                      EdunivoraIdentity
                          .contactConfig
                          .officialSocialLinks
                          .isEmpty
                      ? pendingLabel
                      : '${EdunivoraIdentity.contactConfig.officialSocialLinks.length}',
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Verified Founders Channels
          EduSectionHeader(
            icon: Icons.people_outline_rounded,
            title: isArabic
                ? 'قنوات المؤسسين الموثّقة'
                : 'Verified Founders Channels',
            subtitle: isArabic
                ? 'روابط عامة موثّقة ومباشرة للمؤسسين'
                : 'Verified public links for both co-founders',
            accentColor: AppTheme.primary,
          ),
          const SizedBox(height: 12),
          ...EdunivoraIdentity.founders.asMap().entries.map((entry) {
            final index = entry.key;
            final founder = entry.value;
            final accentColor = index == 0
                ? AppTheme.primary
                : AppTheme.success;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == EdunivoraIdentity.founders.length - 1 ? 0 : 14,
              ),
              child: _FounderContactCard(
                founder: founder,
                isArabic: isArabic,
                isDark: isDark,
                accentColor: accentColor,
                iconResolver: _iconForLinkKind,
              ),
            );
          }),
          const SizedBox(height: 22),

          // Validated Report Issue / Feature Request Form
          EduSectionHeader(
            icon: Icons.feedback_outlined,
            title: isArabic
                ? 'الإبلاغ عن مشكلة / اقتراح ميزة'
                : 'Report an Issue / Suggest a Feature',
            subtitle: isArabic
                ? 'يُجهّز مسودة بريد إلكتروني أو ينسخ التقرير محلياً دون إرسال خفي لخوادم'
                : 'Prepares an email draft or copies the report locally — no hidden backend submission',
            accentColor: AppTheme.primaryStrong,
          ),
          const SizedBox(height: 12),
          EduSurfaceCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        selected: _inquiryType == _InquiryType.bugReport,
                        avatar: const Icon(Icons.bug_report_outlined, size: 18),
                        label: Text(
                          isArabic ? 'الإبلاغ عن مشكلة' : 'Bug Report',
                        ),
                        onSelected: (_) => setState(
                          () => _inquiryType = _InquiryType.bugReport,
                        ),
                      ),
                      ChoiceChip(
                        selected: _inquiryType == _InquiryType.featureRequest,
                        avatar: const Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 18,
                        ),
                        label: Text(
                          isArabic ? 'اقتراح ميزة' : 'Feature Request',
                        ),
                        onSelected: (_) => setState(
                          () => _inquiryType = _InquiryType.featureRequest,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: isArabic
                          ? 'الاسم (اختياري)'
                          : 'Your Name (Optional)',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subjectController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'العنوان *' : 'Subject *',
                      hintText: _inquiryType == _InquiryType.bugReport
                          ? (isArabic
                                ? 'مثال: تعذر حفظ مهمة جديدة'
                                : 'e.g. Unable to save a new task')
                          : (isArabic
                                ? 'مثال: إضافة تذكير قبل الاختبار بيومين'
                                : 'e.g. Add 2-day exam reminder'),
                      prefixIcon: const Icon(Icons.title_rounded),
                    ),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return isArabic
                            ? 'يرجى إدخال عنوان واضح للرسالة.'
                            : 'Please enter a subject.';
                      }
                      if (trimmed.length < 3) {
                        return isArabic
                            ? 'يجب أن يكون العنوان 3 أحرف على الأقل.'
                            : 'Subject must be at least 3 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _detailsController,
                    minLines: 4,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'التفاصيل *' : 'Details *',
                      hintText: isArabic
                          ? 'اشرح خطوات المشكلة أو تفاصيل الميزة المقترحة...'
                          : 'Describe steps to reproduce or details of your suggestion...',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return isArabic
                            ? 'يرجى كتابة تفاصيل المشكلة أو الاقتراح.'
                            : 'Please enter your message details.';
                      }
                      if (trimmed.length < 10) {
                        return isArabic
                            ? 'يرجى كتابة 10 أحرف على الأقل لتوضيح التفاصيل.'
                            : 'Please enter at least 10 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isArabic
                        ? 'ملاحظة: لا يُرسل هذا النموذج بياناتك تلقائياً إلى خادم خلفي؛ بل يفتح مسودة بريد إلى ${EdunivoraIdentity.contactConfig.verifiedFounderSupportEmail} أو ينسخ التقرير للحافظة.'
                        : 'Note: This form does not submit to a backend server. It opens an email draft to ${EdunivoraIdentity.contactConfig.verifiedFounderSupportEmail} or copies the structured report to your clipboard.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: mutedText,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openEmailDraft(isArabic),
                      icon: const Icon(Icons.mail_outline_rounded, size: 18),
                      label: Text(
                        isArabic
                            ? 'فتح مسودة بريد إلكتروني'
                            : 'Open Email Draft',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _copyStructuredReport(isArabic),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(
                        isArabic
                            ? 'نسخ التقرير للحافظة'
                            : 'Copy Report to Clipboard',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        foregroundColor: bodyText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const EduBrandFooter(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PendingChannelRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String statusLabel;
  final bool isDark;

  const _PendingChannelRow({
    required this.icon,
    required this.title,
    required this.statusLabel,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeFg = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: badgeFg, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(
              color: badgeFg,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _FounderContactCard extends StatelessWidget {
  final FounderProfile founder;
  final bool isArabic;
  final bool isDark;
  final Color accentColor;
  final IconData Function(FounderLinkKind kind) iconResolver;

  const _FounderContactCard({
    required this.founder,
    required this.isArabic,
    required this.isDark,
    required this.accentColor,
    required this.iconResolver,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isDark
        ? const Color(0xFF1E293B)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.7);
    final tileBg = isDark
        ? const Color(0xFF0F172A)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
    final mutedText = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    return EduSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    founder.initials,
                    style: TextStyle(
                      color: isDark ? AppTheme.accentGlow : accentColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      founder.primaryName(isArabic),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      founder.secondaryName(isArabic),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedText,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${founder.roleAr} / ${founder.roleEn}',
              style: TextStyle(
                color: isDark ? AppTheme.accentGlow : accentColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...founder.links.asMap().entries.map((entry) {
            final index = entry.key;
            final link = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == founder.links.length - 1 ? 0 : 8,
              ),
              child: Material(
                color: tileBg,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => ExternalLinkService.openUrl(
                    context,
                    link.url,
                    label: link.label(isArabic),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          iconResolver(link.kind),
                          size: 18,
                          color: isDark ? AppTheme.accentGlow : accentColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                link.label(isArabic),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                link.displayValue,
                                textDirection: TextDirection.ltr,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: mutedText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => ExternalLinkService.copyToClipboard(
                            context,
                            link.kind == FounderLinkKind.email
                                ? link.displayValue
                                : link.url,
                            feedbackMessage: isArabic
                                ? 'تم نسخ ${link.labelAr}'
                                : 'Copied ${link.labelEn}',
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 17),
                          tooltip: isArabic ? 'نسخ' : 'Copy',
                          visualDensity: VisualDensity.compact,
                        ),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 16,
                          color: mutedText,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
