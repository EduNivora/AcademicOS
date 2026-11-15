import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/announcement.dart';
import '../../data/repositories/announcement_repository.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  static final AnnouncementRepository _repository = AnnouncementRepository();

  late Future<List<Announcement>> _announcementsFuture;

  bool get _isArabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

  @override
  void initState() {
    super.initState();
    _announcementsFuture = _repository.fetchAnnouncements();
  }

  Future<void> _refresh() async {
    final future = _repository.fetchAnnouncements();
    setState(() => _announcementsFuture = future);
    try {
      await future;
    } catch (_) {
      // FutureBuilder renders the error state.
    }
  }

  void _openAnnouncement(Announcement announcement) {
    unawaited(
      _repository.recordGuestView(announcement.id).catchError((_) {}),
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(announcement.title),
        content: SingleChildScrollView(
          child: SelectableText(announcement.body),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_isArabic ? 'إغلاق' : 'Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _isArabic;
    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'التعميمات والإعلانات' : 'Announcements'),
        actions: [
          IconButton(
            tooltip: isArabic ? 'تحديث' : 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Announcement>>(
        future: _announcementsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError && !snapshot.hasData) {
            return _MessageState(
              icon: Icons.cloud_off_rounded,
              message: isArabic
                  ? 'تعذر تحميل التعميمات. تحقق من اتصال الإنترنت ثم أعد المحاولة.'
                  : 'Could not load announcements. Check your connection and retry.',
              actionLabel: isArabic ? 'إعادة المحاولة' : 'Retry',
              onAction: _refresh,
            );
          }

          final items = snapshot.data ?? const <Announcement>[];
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 140),
                  Icon(
                    Icons.campaign_outlined,
                    size: 54,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      isArabic ? 'لا توجد تعميمات حالياً' : 'No announcements yet',
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.campaign_rounded,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            MaterialLocalizations.of(context)
                                .formatMediumDate(item.publishedAt),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => _openAnnouncement(item),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _MessageState({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
