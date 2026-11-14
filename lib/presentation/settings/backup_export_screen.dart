import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/academic/academic_report_service.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/course_material_model.dart';
import '../../data/models/course_model.dart';
import '../../data/models/exam_model.dart';
import '../../data/models/task_model.dart';

class BackupExportScreen extends StatefulWidget {
  const BackupExportScreen({super.key});

  @override
  State<BackupExportScreen> createState() => _BackupExportScreenState();
}

class _BackupExportScreenState extends State<BackupExportScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final AcademicReportService _academicReportService =
      const AcademicReportService();
  final TextEditingController _restoreController = TextEditingController();
  final TextEditingController _reportController = TextEditingController();

  bool _isBusy = false;
  String? _lastBackupPath;
  String _reportText = '';

  @override
  void dispose() {
    _restoreController.dispose();
    _reportController.dispose();
    super.dispose();
  }

  Future<void> _exportBackup() async {
    setState(() => _isBusy = true);
    try {
      final courses = await _databaseHelper.getCourses();
      final tasks = await _databaseHelper.getTasks();
      final exams = await _databaseHelper.getExams();
      final schedule = await _databaseHelper.getSchedules();
      final materials = await _databaseHelper.getAllMaterials();

      final payload = _academicReportService.buildBackupPayload(
        courses: courses,
        tasks: tasks,
        exams: exams,
        schedule: List<Map<String, dynamic>>.from(schedule),
        materials: materials,
      );

      final encodedBackup = _academicReportService.encodeBackupJson(payload);
      final boxed = <String, dynamic>{
        'format': 'academic_os_backup',
        'payload': encodedBackup,
      };
      final jsonBackupText = const JsonEncoder.withIndent('  ').convert(boxed);

      final tempDir = Directory.systemTemp;
      final backupFile = File(
        '${tempDir.path}/academic_os_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await backupFile.writeAsString(jsonBackupText, flush: true);

      _lastBackupPath = backupFile.path;
      _restoreController.text = jsonBackupText;

      if (!mounted) return;
      await _showShareOptions(jsonBackupText, backupFile.path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('تم حفظ النسخة الاحتياطية في ${backupFile.path}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء النسخة الاحتياطية: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _restoreBackup() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final rawText = _restoreController.text.trim();
      if (rawText.isEmpty) {
        throw const FormatException('النسخة الاحتياطية فارغة.');
      }

      final decoded = await _decodeBackup(rawText);
      if (decoded == null) {
        throw const FormatException('صيغة النسخة الاحتياطية غير صالحة.');
      }

      // Validate and deserialize every row before touching the live database.
      final schema = decoded['schema'];
      if (schema != null &&
          schema != 'academic_os_backup_v1' &&
          schema != 'academic_os_backup_v2') {
        throw const FormatException(
          'إصدار النسخة الاحتياطية غير مدعوم.',
        );
      }

      final rawCourses = decoded['courses'];
      final rawTasks = decoded['tasks'];
      final rawExams = decoded['exams'];
      final rawSchedule = decoded['schedule'];
      final rawMaterials = decoded['materials'];
      if (rawCourses is! List ||
          rawTasks is! List ||
          rawExams is! List ||
          rawSchedule is! List ||
          (schema == 'academic_os_backup_v2' && rawMaterials is! List) ||
          (rawMaterials != null && rawMaterials is! List)) {
        throw const FormatException(
          'النسخة الاحتياطية لا تحتوي على أقسام البيانات المطلوبة أو أن بنيتها غير صالحة.',
        );
      }

      final courses = rawCourses
          .map((item) => CourseModel.fromMap(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false);
      final tasks = rawTasks
          .map((item) => TaskModel.fromMap(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false);
      final exams = rawExams
          .map((item) => ExamModel.fromMap(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false);
      final schedule = rawSchedule
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);
      final materials = rawMaterials is List
          ? rawMaterials
              .map((item) => CourseMaterialModel.fromMap(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .toList(growable: false)
          : null;

      await _databaseHelper.replaceAcademicData(
        courses: courses,
        tasks: tasks,
        exams: exams,
        schedules: schedule,
        materials: materials,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت استعادة البيانات بنجاح: ${courses.length} مادة، '
            '${tasks.length} مهمة، ${exams.length} اختبار، '
            '${schedule.length} حصة.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل الاستعادة. لم تُعتمد أي تغييرات جزئية، '
            'وتم الاحتفاظ بالبيانات السابقة إن فشلت المعاملة: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _decodeBackup(String rawText) async {
    try {
      final decoded = jsonDecode(rawText);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('payload') && decoded['payload'] is String) {
          if (decoded['format'] != 'academic_os_backup') return null;
          final payloadText =
              utf8.decode(base64.decode(decoded['payload'] as String));
          final payload = jsonDecode(payloadText);
          return payload is Map<String, dynamic> ? payload : null;
        }
        if (decoded.containsKey('courses') ||
            decoded.containsKey('tasks') ||
            decoded.containsKey('exams') ||
            decoded.containsKey('schedule')) {
          return decoded;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _generateAcademicReport() async {
    setState(() => _isBusy = true);
    try {
      final courses = await _databaseHelper.getCourses();
      final tasks = await _databaseHelper.getTasks();
      final exams = await _databaseHelper.getExams();
      final schedule = await _databaseHelper.getSchedules();

      _reportText = _academicReportService.generateAcademicReport(
        courses: courses,
        tasks: tasks,
        exams: exams,
        schedule: List<Map<String, dynamic>>.from(schedule),
      );
      _reportController.text = _reportText;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تجهيز التقرير الأكاديمي بنجاح.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء التقرير: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _saveReportFile() async {
    if (_reportText.trim().isEmpty) {
      await _generateAcademicReport();
    }

    final reportFile = File(
      '${Directory.systemTemp.path}/academic_os_report_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    await reportFile.writeAsString(_reportText, flush: true);
    await Clipboard.setData(ClipboardData(text: _reportText));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('تم حفظ تقريرك في ${reportFile.path} ونسخه إلى الحافظة.')),
    );
  }

  Future<void> _showShareOptions(String backupJson, String backupPath) async {
    final hasText = backupJson.trim().isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.save_alt_rounded),
                title: const Text('حفظ ملف النسخة الاحتياطية'),
                subtitle: Text(backupPath),
                onTap: () async {
                  Navigator.pop(context);
                  final file = File(backupPath);
                  if (await file.exists()) {
                    await Clipboard.setData(ClipboardData(text: backupJson));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('نسخ نص JSON إلى الحافظة'),
                onTap: () async {
                  Navigator.pop(context);
                  if (hasText) {
                    await Clipboard.setData(ClipboardData(text: backupJson));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('مشاركة عبر تطبيقات التواصل'),
                subtitle: const Text(
                    'اختر WhatsApp أو Telegram أو أي تطبيق بعد النسخ.'),
                onTap: () async {
                  Navigator.pop(context);
                  if (hasText) {
                    await Clipboard.setData(ClipboardData(text: backupJson));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Future<void> Function() onTap,
  ) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF1D4ED8)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي والتقارير'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildActionCard(
            'نسخ احتياطي فوري',
            'تصدير جميع المواد والمهام والاختبارات والجدول في ملف JSON واحد.',
            Icons.backup_rounded,
            _exportBackup,
          ),
          const SizedBox(height: 18),
          const Text(
            'استعادة النسخة الاحتياطية',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _restoreController,
            minLines: 6,
            maxLines: 10,
            decoration: InputDecoration(
              hintText:
                  'ألصق نص ملف backup.json هنا أو استخدم النسخة المحفوظة من الحافظة',
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isBusy ? null : _restoreBackup,
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('استرجاع البيانات'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () async {
                  final result = await Clipboard.getData('text/plain');
                  if (result?.text != null) {
                    _restoreController.text = result!.text!;
                  }
                },
                icon: const Icon(Icons.paste_rounded),
                tooltip: 'لصق من الحافظة',
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'تقرير أكاديمي سريع',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reportController,
            readOnly: true,
            minLines: 8,
            maxLines: 14,
            decoration: InputDecoration(
              hintText: 'سيظهر هنا تقريرك الأكاديمي',
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isBusy ? null : _generateAcademicReport,
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('إنشاء التقرير'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isBusy ? null : _saveReportFile,
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('حفظ/مشاركة'),
                ),
              ),
            ],
          ),
          if (_lastBackupPath != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF065F46)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'آخر ملف احتياطي: $_lastBackupPath',
                      style: const TextStyle(
                        color: Color(0xFF065F46),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
