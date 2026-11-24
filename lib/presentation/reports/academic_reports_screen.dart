import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/academic/academic_report_service.dart';
import '../../core/notifications/notification_service.dart';
import '../../data/database/database_helper.dart';

/// Release 1 academic reporting backed by the student's local academic records.
class AcademicReportsScreen extends StatefulWidget {
  const AcademicReportsScreen({super.key});

  @override
  State<AcademicReportsScreen> createState() => _AcademicReportsScreenState();
}

class _AcademicReportsScreenState extends State<AcademicReportsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final AcademicReportService _reportService = const AcademicReportService();
  final TextEditingController _reportController = TextEditingController();

  bool _isBusy = false;
  String _reportText = '';
  AcademicReportPeriod _selectedPeriod = AcademicReportPeriod.daily;

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  Future<void> _generateAcademicReport() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final courses = await _databaseHelper.getCourses();
      final tasks = await _databaseHelper.getTasks();
      final exams = await _databaseHelper.getExams();
      final schedule = await _databaseHelper.getSchedules();

      final report = _reportService.generatePeriodReport(
        period: _selectedPeriod,
        courses: courses,
        tasks: tasks,
        exams: exams,
        schedule: List<Map<String, dynamic>>.from(schedule),
      );

      if (!mounted) return;
      setState(() {
        _reportText = report;
        _reportController.text = report;
      });
      await NotificationService.instance.showReportReadyNotification(
        id: 41000 + _selectedPeriod.index,
        title: 'تم تجهيز التقرير ${_selectedPeriod.arabicLabel}',
        body: 'تقريرك الأكاديمي جاهز للمراجعة داخل AcademicOS.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تجهيز التقرير وإرسال إشعار به.')),
      );
    } catch (error, stackTrace) {
      debugPrint('Academic report generation failed: $error\\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء التقرير الأكاديمي: $error')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _saveReport() async {
    if (_reportText.trim().isEmpty) {
      await _generateAcademicReport();
    }
    if (!mounted || _reportText.trim().isEmpty) return;

    try {
      final fileName =
          'edunivora_academic_report_${DateTime.now().millisecondsSinceEpoch}.txt';
      final savedPath = await FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(_reportText)),
        type: FileType.custom,
        allowedExtensions: const ['txt'],
        dialogTitle: 'حفظ التقرير الأكاديمي',
      );
      await Clipboard.setData(ClipboardData(text: _reportText));
      if (!mounted) return;
      final message = savedPath == null
          ? 'تم نسخ التقرير إلى الحافظة. لم يتم حفظ ملف.'
          : 'تم حفظ التقرير في $savedPath ونسخه إلى الحافظة.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error, stackTrace) {
      debugPrint('Academic report export failed: $error\\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر حفظ التقرير: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير الأكاديمية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'تقارير أكاديمية مبنية على إنجازاتك المسجلة فعلياً',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'اختر الفترة المطلوبة. لا يُحتسب إنجاز إلا إذا سُجلت المهمة كمكتملة، والجدول يعرض المحاضرات المخططة ولا يدّعي الحضور. تُحفظ بيانات التقرير محلياً.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<AcademicReportPeriod>(
            initialValue: _selectedPeriod,
            decoration: const InputDecoration(labelText: 'نوع التقرير'),
            items: AcademicReportPeriod.values
                .map(
                  (period) => DropdownMenuItem(
                    value: period,
                    child: Text('التقرير ${period.arabicLabel}'),
                  ),
                )
                .toList(),
            onChanged: _isBusy
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _selectedPeriod = value;
                        _reportText = '';
                        _reportController.clear();
                      });
                    }
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reportController,
            readOnly: true,
            minLines: 12,
            maxLines: 20,
            decoration: InputDecoration(
              hintText: 'اختر نوع التقرير ثم اضغط «إنشاء التقرير». ',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isBusy ? null : _generateAcademicReport,
            icon: _isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.assessment_outlined),
            label: Text('إنشاء التقرير ${_selectedPeriod.arabicLabel}'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isBusy ? null : _saveReport,
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('حفظ التقرير ومشاركته'),
          ),
        ],
      ),
    );
  }
}
