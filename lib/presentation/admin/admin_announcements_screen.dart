import 'package:flutter/material.dart';

import '../../data/datasources/admin_announcements_data_source.dart';
import '../../domain/usecases/auth_use_cases.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  final AuthUseCases authUseCases;

  const AdminAnnouncementsScreen({
    super.key,
    required this.authUseCases,
  });

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  final _source = AdminAnnouncementsDataSource();
  final _statuses = const <String, String>{
    'draft': 'مسودات',
    'published': 'منشورة',
    'archived': 'مؤرشفة',
  };

  String _status = 'draft';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String> _requireToken() async {
    final token = await widget.authUseCases.getCloudAccessToken.call();
    if (token == null || token.isEmpty) {
      throw const AdminAnnouncementsException(
        401,
        'انتهت جلسة الإدارة. سجّل الدخول مجدداً.',
      );
    }
    return token;
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final token = await _requireToken();
      final items = await _source.list(
        accessToken: token,
        status: _status,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on AdminAnnouncementsException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.statusCode == 403
            ? 'هذا الحساب لا يملك صلاحية إدارة التعميمات.'
            : error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل التعميمات. تحقق من الاتصال وحاول مجدداً.';
        _loading = false;
      });
    }
  }

  Future<void> _editAnnouncement({Map<String, dynamic>? item}) async {
    final titleController =
        TextEditingController(text: item?['title']?.toString() ?? '');
    final bodyController =
        TextEditingController(text: item?['body']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item == null ? 'تعميم جديد' : 'تعديل التعميم'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    maxLength: 180,
                    decoration: const InputDecoration(labelText: 'عنوان التعميم'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'أدخل عنوان التعميم'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: bodyController,
                    minLines: 5,
                    maxLines: 10,
                    maxLength: 10000,
                    decoration: const InputDecoration(
                      labelText: 'نص التعميم',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'أدخل نص التعميم'
                            : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('حفظ المسودة'),
          ),
        ],
      ),
    );
    final title = titleController.text.trim();
    final body = bodyController.text.trim();
    titleController.dispose();
    bodyController.dispose();
    if (shouldSave != true || !mounted) return;

    try {
      final token = await _requireToken();
      if (item == null) {
        await _source.create(accessToken: token, title: title, body: body);
      } else {
        await _source.update(
          accessToken: token,
          id: item['id'].toString(),
          title: title,
          body: body,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ المسودة.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  Future<void> _changeStatus(
    Map<String, dynamic> item, {
    required bool publish,
  }) async {
    try {
      final token = await _requireToken();
      final id = item['id'].toString();
      if (publish) {
        await _source.publish(accessToken: token, id: id);
      } else {
        await _source.archive(accessToken: token, id: id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(publish ? 'تم نشر التعميم.' : 'تمت أرشفة التعميم.'),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  Future<void> _showReport(Map<String, dynamic> item) async {
    try {
      final token = await _requireToken();
      final report = await _source.report(
        accessToken: token,
        id: item['id'].toString(),
      );
      if (!mounted) return;
      final rows = <({String label, String key})>[
        (label: 'تسليمات الحسابات المسجلة', key: 'registered_deliveries'),
        (label: 'إيصالات القراءة المسجلة', key: 'registered_reads'),
        (label: 'تسليمات الضيوف المجهولة', key: 'guest_deliveries'),
        (label: 'مشاهدات الضيوف المجهولة', key: 'guest_views'),
      ];
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text("تقرير: ${item['title']}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: rows
                .map(
                  (row) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(row.label),
                    trailing: Text(
                      (report[row.key] ?? 0).toString(),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  void _showError(Object error) {
    final message = error is AdminAnnouncementsException &&
            error.statusCode == 403
        ? 'هذا الحساب لا يملك صلاحية الإدارة.'
        : 'تعذّر تنفيذ العملية. تحقق من الصلاحيات والاتصال.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة التعميمات'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _editAnnouncement(),
        icon: const Icon(Icons.add),
        label: const Text('تعميم جديد'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<String>(
                segments: _statuses.entries
                    .map(
                      (entry) => ButtonSegment<String>(
                        value: entry.key,
                        label: Text(entry.value),
                      ),
                    )
                    .toList(),
                selected: {_status},
                onSelectionChanged: (selection) {
                  setState(() => _status = selection.first);
                  _load();
                },
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline, size: 42),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (!_loading && _items.isEmpty)
              const Expanded(
                child: Center(child: Text('لا توجد تعميمات في هذا التصنيف.')),
              )
            else if (_items.isNotEmpty)
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final isDraft = item['status'] == 'draft';
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title']?.toString() ?? '',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['body']?.toString() ?? '',
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (isDraft)
                                  TextButton.icon(
                                    onPressed: () =>
                                        _editAnnouncement(item: item),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('تعديل'),
                                  ),
                                if (isDraft)
                                  FilledButton.tonalIcon(
                                    onPressed: () => _changeStatus(
                                      item,
                                      publish: true,
                                    ),
                                    icon: const Icon(Icons.publish),
                                    label: const Text('نشر'),
                                  ),
                                if (item['status'] != 'archived')
                                  TextButton.icon(
                                    onPressed: () => _changeStatus(
                                      item,
                                      publish: false,
                                    ),
                                    icon: const Icon(Icons.archive_outlined),
                                    label: const Text('أرشفة'),
                                  ),
                                TextButton.icon(
                                  onPressed: () => _showReport(item),
                                  icon: const Icon(Icons.analytics_outlined),
                                  label: const Text('التقرير'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
