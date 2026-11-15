import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/academic/academic_report_service.dart';
import '../../data/database/database_helper.dart';
import '../../data/services/backup_payload_validator.dart';
import '../../data/services/backup_archive_crypto_service.dart';

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
  final TextEditingController _backupPasswordController = TextEditingController();
  final TextEditingController _backupPasswordConfirmController = TextEditingController();
  final TextEditingController _restorePasswordController = TextEditingController();
  final BackupArchiveCryptoService _backupCrypto =
      const BackupArchiveCryptoService();

  bool _isBusy = false;
  String? _lastBackupPath;
  String _reportText = '';

  @override
  void dispose() {
    _restoreController.dispose();
    _reportController.dispose();
    _backupPasswordController.dispose();
    _backupPasswordConfirmController.dispose();
    _restorePasswordController.dispose();
    super.dispose();
  }

  Future<void> _exportBackup() async {
    setState(() => _isBusy = true);
    try {
      if (_backupPasswordController.text !=
          _backupPasswordConfirmController.text) {
        throw const FormatException('كلمتا مرور النسخة غير متطابقتين.');
      }
      final courses = await _databaseHelper.getCourses();
      final tasks = await _databaseHelper.getTasks();
      final exams = await _databaseHelper.getExams();
      final schedule = await _databaseHelper.getSchedules();
      final materials = await _databaseHelper.getAllMaterials();

      final missingAttachments = materials.where((row) {
        final bytes = row['file_bytes'];
        return bytes is! List<int> || bytes.isEmpty;
      }).length;
      if (missingAttachments > 0) {
        throw StateError(
          'تعذر إنشاء نسخة كاملة: يوجد $missingAttachments مرفق قديم بلا محتوى محفوظ. أعد إرفاق الملفات المفقودة أولاً.',
        );
      }

      final backupMaterials = materials.map((row) {
        final copy = Map<String, dynamic>.from(row);
        final bytes = copy.remove('file_bytes');
        if (bytes is List<int>) {
          copy['file_bytes_base64'] = base64.encode(bytes);
        }
        return copy;
      }).toList(growable: false);

      final payload = _academicReportService.buildBackupPayload(
        courses: courses,
        tasks: tasks,
        exams: exams,
        schedule: List<Map<String, dynamic>>.from(schedule),
        materials: backupMaterials,
      );

      final encodedBackup = _academicReportService.encodeBackupJson(payload);
      final boxed = <String, dynamic>{
        'format': 'academic_os_backup',
        'payload': encodedBackup,
      };
      final jsonBackupText = const JsonEncoder.withIndent('  ').convert(boxed);
      final encryptedBytes = await _backupCrypto.encrypt(
        plaintext: utf8.encode(jsonBackupText),
        password: _backupPasswordController.text,
      );
      final encryptedArchiveText = utf8.decode(encryptedBytes);

      final fileName =
          'edunivora_backup_${DateTime.now().millisecondsSinceEpoch}.edunivora';
      final savedPath = await FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: encryptedBytes,
        type: FileType.custom,
        allowedExtensions: const ['edunivora'],
        dialogTitle: 'حفظ النسخة الاحتياطية المشفرة',
      );
      if (savedPath == null && !kIsWeb) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء حفظ النسخة الاحتياطية.')),
        );
        return;
      }

      _lastBackupPath = savedPath ?? fileName;
      _restoreController.text = encryptedArchiveText;

      if (!mounted) return;
      await _showShareOptions(encryptedArchiveText, _lastBackupPath!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'تم إرسال النسخة الاحتياطية إلى تنزيلات المتصفح.'
                : 'تم حفظ النسخة الاحتياطية في $savedPath',
          ),
        ),
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

  Future<void> _pickBackupFile() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['edunivora', 'json'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.single.bytes;
      if (bytes == null) {
        throw const FormatException(
          'تعذر قراءة محتوى الملف. اختر نسخة EduNivora أو JSON قديمة صالحة.',
        );
      }
      if (bytes.length > 80 * 1024 * 1024) {
        throw const FormatException(
          'حجم النسخة الاحتياطية يتجاوز الحد المسموح (80 MB).',
        );
      }

      _restoreController.text = utf8.decode(bytes, allowMalformed: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحميل ملف النسخة. راجعه ثم اضغط استرجاع البيانات.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح ملف النسخة: $error')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
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

      final decoded = await _decodeBackup(
        rawText,
        password: _restorePasswordController.text,
      );
      if (decoded == null) {
        throw const FormatException('صيغة النسخة الاحتياطية غير صالحة.');
      }

      // Validate and deserialize every section before touching live storage.
      final validated = const BackupPayloadValidator().validate(decoded);

      await _databaseHelper.replaceAcademicData(
        courses: validated.courses,
        tasks: validated.tasks,
        exams: validated.exams,
        schedules: validated.schedule,
        materials: validated.materials,
      );

      if (!mounted) return;
      final materialsSummary = validated.materials == null
          ? 'لم تتغير بيانات المرفقات'
          : '${validated.materials!.length} مرفقاً';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت استعادة البيانات بنجاح: ${validated.courses.length} مادة، '
            '${validated.tasks.length} مهمة، ${validated.exams.length} اختبار، '
            '${validated.schedule.length} حصة، $materialsSummary.',
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

  Future<Map<String, dynamic>?> _decodeBackup(
    String rawText, {
    required String password,
  }) async {
    try {
      final initial = jsonDecode(rawText);
      if (initial is Map<String, dynamic> &&
          initial['format'] == 'edunivora_encrypted_backup') {
        final plaintext = await _backupCrypto.decrypt(
          archive: utf8.encode(rawText),
          password: password,
        );
        return _decodePlainBackup(utf8.decode(plaintext, allowMalformed: false));
      }
      return _decodePlainBackup(rawText);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'تعذر فك تشفير النسخة. تحقق من كلمة المرور وسلامة الملف.',
      );
    }
  }

  Map<String, dynamic>? _decodePlainBackup(String rawText) {
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
            decoded.containsKey('schedule') ||
            decoded.containsKey('materials')) {
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

    if (_reportText.trim().isEmpty) return;
    final fileName =
        'academic_os_report_${DateTime.now().millisecondsSinceEpoch}.txt';
    final savedPath = await FilePicker.platform.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(_reportText)),
      type: FileType.custom,
      allowedExtensions: const ['txt'],
      dialogTitle: 'حفظ التقرير الأكاديمي',
    );
    await Clipboard.setData(ClipboardData(text: _reportText));

    if (!mounted) return;
    final saveMessage = savedPath == null
        ? (kIsWeb
            ? 'تم إرسال التقرير إلى تنزيلات المتصفح ونسخه إلى الحافظة.'
            : 'تم إلغاء حفظ الملف؛ نُسخ التقرير إلى الحافظة.')
        : 'تم حفظ التقرير في $savedPath ونسخه إلى الحافظة.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(saveMessage)),
    );
  }

  Future<void> _showShareOptions(
    String backupJson,
    String backupPath,
  ) async {
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
                leading: const Icon(Icons.copy_rounded),
                title: const Text('نسخ نص JSON إلى الحافظة'),
                onTap: () async {
                  Navigator.pop(context);
                  await Clipboard.setData(ClipboardData(text: backupJson));
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_all_rounded),
                title: const Text('نسخ مسار ملف النسخة'),
                subtitle: Text(backupPath),
                onTap: () async {
                  Navigator.pop(context);
                  await Clipboard.setData(ClipboardData(text: backupPath));
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
        onTap: _isBusy ? null : onTap,
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
          const Text(
            'كلمة مرور النسخة الاحتياطية',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _backupPasswordController,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
              hintText: '12 حرفاً على الأقل',
              helperText: 'فقدان كلمة المرور يعني تعذر استعادة النسخة.',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _backupPasswordConfirmController,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_reset),
              hintText: 'أعد كتابة كلمة المرور للتأكيد',
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            'إنشاء نسخة مشفرة',
            'تشفير بياناتك الأكاديمية ومحتوى المرفقات بكلمة مرور قبل حفظ ملف EduNivora.',
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
            controller: _restorePasswordController,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key),
              hintText: 'كلمة مرور النسخة المشفرة',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _restoreController,
            minLines: 6,
            maxLines: 10,
            decoration: InputDecoration(
              hintText:
                  'ألصق نص ملف النسخة المشفرة هنا أو استخدم النسخة المحفوظة من الحافظة',
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
                onPressed: _isBusy ? null : _pickBackupFile,
                icon: const Icon(Icons.folder_open_rounded),
                tooltip: 'اختيار ملف نسخة احتياطية',
              ),
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
