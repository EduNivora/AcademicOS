import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../../core/documents/course_material_file_service.dart';
import '../../../data/database/database_helper.dart';
import '../../../data/models/course_material_model.dart';
import '../document_viewer_screen.dart';

class CourseMaterialsTab extends StatefulWidget {
  final int courseId;
  const CourseMaterialsTab({super.key, required this.courseId});

  @override
  State<CourseMaterialsTab> createState() => _CourseMaterialsTabState();
}

class _CourseMaterialsTabState extends State<CourseMaterialsTab> {
  List<CourseMaterialModel> _materials = [];
  bool _isLoading = true;
  final Set<int> _openingMaterialIds = <int>{};
  final CourseMaterialFileService _fileService = CourseMaterialFileService();

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    final rows =
        await DatabaseHelper.instance.getMaterialsByCourseId(widget.courseId);
    if (!mounted) return;
    setState(() {
      _materials = rows.map(CourseMaterialModel.fromMap).toList();
      _isLoading = false;
    });
  }

  Future<void> _pickAndSave() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt'],
      withData: true,
    );
    if (result == null || !mounted) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر قراءة محتوى الملف المحدد.')),
      );
      return;
    }

    if (bytes.length > 50 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حجم الملف يتجاوز الحد المسموح (50 MB).')),
      );
      return;
    }

    final fileName = p.basename(file.name);
    final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
    if (!{'pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt'}.contains(ext)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نوع الملف غير مدعوم.')),
      );
      return;
    }

    try {
      final model = CourseMaterialModel(
        courseId: widget.courseId,
        title: fileName,
        filePath: 'dbblob://${DateTime.now().microsecondsSinceEpoch}',
        fileType: ext,
        fileBytes: bytes,
      );
      await DatabaseHelper.instance.insertMaterial(model.toMap());
      await _loadMaterials();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الملف داخل مساحة التطبيق.')),
      );
    } catch (e) {
      debugPrint('Failed to persist material: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل حفظ الملف. لم يتم تسجيله كمرفق.')),
      );
    }
  }

  Future<void> _openMaterial(CourseMaterialModel material) async {
    final materialId = material.id;
    if (materialId == null || _openingMaterialIds.contains(materialId)) return;
    setState(() => _openingMaterialIds.add(materialId));

    PreparedMaterialFile? preparedPdf;
    try {
      final extension = material.fileType.toLowerCase().replaceFirst('.', '');
      var bytes = await _fileService.loadMaterialBytes(materialId);
      if (!mounted) return;

      if (extension == 'txt') {
        final text = utf8.decode(bytes, allowMalformed: true);
        bytes = null;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(material.title),
            content: SizedBox(
              width: 520,
              height: 420,
              child: SingleChildScrollView(child: SelectableText(text)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
        return;
      }

      if (extension == 'pdf') {
        preparedPdf = await _fileService.preparePdfForViewing(
          materialId: materialId,
          title: material.title,
          fileType: material.fileType,
          bytes: bytes,
        );
        bytes = null;
        if (!mounted) {
          await preparedPdf.delete();
          preparedPdf = null;
          return;
        }
        try {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentViewerScreen(
                filePath: preparedPdf!.file.path,
                title: material.title,
              ),
            ),
          );
          // The viewer owns cleanup after the PDF native handle is closed.
          preparedPdf = null;
        } catch (_) {
          await preparedPdf?.delete();
          preparedPdf = null;
          rethrow;
        }
        return;
      }

      if (const {'doc', 'docx', 'ppt', 'pptx'}.contains(extension)) {
        final status = await _fileService.openOfficeExternally(
          materialId: materialId,
          title: material.title,
          fileType: material.fileType,
          bytes: bytes,
        );
        bytes = null;
        if (!mounted) return;
        final message = switch (status) {
          ExternalMaterialOpenStatus.opened =>
            'تم إرسال الملف إلى التطبيق الخارجي. سيبقى الملف المؤقت متاحاً لفترة آمنة.',
          ExternalMaterialOpenStatus.noApp =>
            'لا يوجد تطبيق مثبت يستطيع فتح هذا النوع من الملفات.',
          ExternalMaterialOpenStatus.unsupportedPlatform =>
            'فتح ملفات Office خارجياً غير متاح على هذه المنصة.',
          ExternalMaterialOpenStatus.failed =>
            'تعذر فتح الملف خارجياً. تحقق من صلاحيات التطبيق وحاول مجدداً.',
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نوع الملف غير مدعوم للعرض.')),
      );
    } on MaterialFileUnavailableException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on UnsupportedMaterialFormatException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      debugPrint('Opening course material failed: $error');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تجهيز الملف للعرض. لم يتم تعديل المرفق الأصلي.')),
      );
    } finally {
      await preparedPdf?.delete();
      if (mounted) setState(() => _openingMaterialIds.remove(materialId));
    }
  }

  Future<void> _deleteMaterial(int id) async {
    final matching = _materials.where((material) => material.id == id);
    if (matching.isEmpty) return;
    final material = matching.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المرفق؟'),
        content: Text(
          'سيتم حذف «' + material.title + '» وبيانات الملف المحفوظة على هذا الجهاز.',
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
    if (confirmed != true || !mounted) return;

    try {
      await DatabaseHelper.instance.deleteMaterial(id);
      await _loadMaterials();
    } catch (error, stackTrace) {
      debugPrint('Deleting course attachment failed: $error\\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حذف المرفق: ' + error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                  child: Text('المحاضرات والمرفقات',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              ElevatedButton.icon(
                  onPressed: _pickAndSave,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('إضافة محاضرة / ملف')),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _materials.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('لا توجد محاضرات مضافة بعد.'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                              onPressed: _pickAndSave,
                              icon: const Icon(Icons.add),
                              label: const Text('إضافة محاضرة')),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _materials.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final m = _materials[index];
                        return ListTile(
                          leading: _fileBadge(m.fileType),
                          title: Text(m.title),
                          subtitle: Text(m.fileType.toUpperCase()),
                          trailing: _openingMaterialIds.contains(m.id)
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteMaterial(m.id!),
                                ),
                          onTap: () => _openMaterial(m),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _fileBadge(String type) {
    final t = type.toLowerCase();
    IconData icon;
    Color color;
    switch (t) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'ppt':
      case 'pptx':
        icon = Icons.slideshow;
        color = Colors.orange;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        color = Colors.blue;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }
    return CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color));
  }
}
