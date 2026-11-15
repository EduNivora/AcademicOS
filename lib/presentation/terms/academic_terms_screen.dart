import 'package:flutter/material.dart';

import '../../data/database/database_helper.dart';
import '../../data/models/academic_term_model.dart';

class AcademicTermsScreen extends StatefulWidget {
  const AcademicTermsScreen({super.key});

  @override
  State<AcademicTermsScreen> createState() => _AcademicTermsScreenState();
}

class _AcademicTermsScreenState extends State<AcademicTermsScreen> {
  final DatabaseHelper _database = DatabaseHelper.instance;
  List<AcademicTermModel> _terms = const [];
  bool _isLoading = true;
  String? _loadError;

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    try {
      final terms = await _database.getAcademicTerms();
      if (!mounted) return;
      setState(() {
        _terms = terms;
        _loadError = null;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Loading academic terms failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openEditor({AcademicTermModel? existing}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing?.name ?? '');
    var startDate = existing?.startDate ?? DateTime(DateTime.now().year, 1, 1);
    var endDate = existing?.endDate ?? DateTime(DateTime.now().year, 12, 31);
    var isActive = existing?.isActive ?? _terms.isEmpty;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة فصل دراسي' : 'تعديل الفصل الدراسي'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'اسم الفصل الدراسي',
                        hintText: 'مثال: الفصل الأول 2026/2027',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'أدخل اسم الفصل الدراسي.';
                        }
                        if (value.trim().length > 80) {
                          return 'الحد الأقصى 80 حرفاً.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('تاريخ بداية الفصل'),
                      subtitle: Text(_formatDate(startDate)),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => startDate = picked);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: const Text('تاريخ نهاية الفصل'),
                      subtitle: Text(_formatDate(endDate)),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => endDate = picked);
                        }
                      },
                    ),
                    if (endDate.isBefore(DateTime(startDate.year, startDate.month, startDate.day)))
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'تاريخ النهاية يجب ألا يسبق تاريخ البداية.',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: isActive,
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                      title: const Text('تعيين كالفصل النشط'),
                      subtitle: const Text(
                        'يمكن أن يكون هناك فصل نشط واحد فقط.',
                      ),
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
                if (!formKey.currentState!.validate()) return;
                if (endDate.isBefore(
                  DateTime(startDate.year, startDate.month, startDate.day),
                )) {
                  setDialogState(() {});
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      try {
        final term = AcademicTermModel(
          id: existing?.id,
          name: nameController.text.trim(),
          startDate: startDate,
          endDate: endDate,
          isActive: isActive,
          createdAt: existing?.createdAt,
        );
        if (existing == null) {
          await _database.insertAcademicTerm(term);
        } else {
          await _database.updateAcademicTerm(term);
        }
        await _loadTerms();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الفصل الدراسي.')),
        );
      } catch (error, stackTrace) {
        debugPrint('Saving academic term failed: $error\n$stackTrace');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ الفصل الدراسي: $error')),
        );
      }
    }
    nameController.dispose();
  }

  Future<void> _activate(AcademicTermModel term) async {
    final id = term.id;
    if (id == null) return;
    try {
      await _database.setActiveAcademicTerm(id);
      await _loadTerms();
    } catch (error, stackTrace) {
      debugPrint('Activating academic term failed: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تفعيل الفصل: $error')),
      );
    }
  }

  Future<void> _delete(AcademicTermModel term) async {
    final id = term.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الفصل الدراسي؟'),
        content: Text(
          'سيتم حذف «${term.name}». لا يمكن حذف فصل ما زالت هناك مقررات مرتبطة باسمه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _database.deleteAcademicTerm(id);
      await _loadTerms();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الفصل الدراسي.')),
      );
    } catch (error, stackTrace) {
      debugPrint('Deleting academic term failed: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الفصول الدراسية')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة فصل'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 42),
                        const SizedBox(height: 12),
                        Text('تعذر تحميل الفصول الدراسية: $_loadError'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _loadTerms,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : _terms.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 52),
                            const SizedBox(height: 14),
                            const Text(
                              'لم تضف فصولاً دراسية بعد',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'أنشئ الفصول لتنظيم مقرراتك والانتقال بينها مع الاحتفاظ بسجلك الدراسي.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => _openEditor(),
                              icon: const Icon(Icons.add),
                              label: const Text('إضافة أول فصل'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadTerms,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _terms.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final term = _terms[index];
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                child: Icon(
                                  term.isActive
                                      ? Icons.check_circle
                                      : Icons.calendar_month_outlined,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      term.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (term.isActive)
                                    const Chip(
                                      label: Text('نشط'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                '${_formatDate(term.startDate)} — ${_formatDate(term.endDate)}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) {
                                  switch (action) {
                                    case 'edit':
                                      _openEditor(existing: term);
                                      break;
                                    case 'activate':
                                      _activate(term);
                                      break;
                                    case 'delete':
                                      _delete(term);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('تعديل'),
                                  ),
                                  if (!term.isActive)
                                    const PopupMenuItem(
                                      value: 'activate',
                                      child: Text('تعيين كفصل نشط'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('حذف'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
