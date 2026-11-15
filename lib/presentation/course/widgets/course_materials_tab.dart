import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
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

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    final rows =
        await DatabaseHelper.instance.getMaterialsByCourseId(widget.courseId);
    setState(() {
      _materials = rows.map(CourseMaterialModel.fromMap).toList();
      _isLoading = false;
    });
  }

  Future<void> _pickAndSave() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      withData: true,
    );
    if (result == null) return;
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
    if (!{'pdf', 'doc', 'docx', 'txt'}.contains(ext)) {
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
    if (material.fileBytes == null || material.fileBytes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('محتوى هذا المرفق غير متاح أو لم تتم استعادته. أعد إرفاق الملف الأصلي.')),
      );
      return;
    }
    if (material.fileType == 'pdf') {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DocumentViewerScreen(
                filePath: material.filePath, title: material.title, fileBytes: material.fileBytes)),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(material.title),
          content: const Text(
              'معاينة هذا النوع من الملفات غير مدعومة داخل التطبيق حالياً.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق')),
          ],
        ),
      );
    }
  }

  Future<void> _deleteMaterial(int id) async {
    await DatabaseHelper.instance.deleteMaterial(id);
    await _loadMaterials();
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
                          trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteMaterial(m.id!)),
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
