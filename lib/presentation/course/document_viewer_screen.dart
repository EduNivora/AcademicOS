import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offline_document_viewer/offline_document_viewer.dart';
import 'package:flutter_pdf_text/flutter_pdf_text.dart' as pdf_text;
import 'package:path/path.dart' as p;

import '../../core/services/local_summarizer_service.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String filePath;
  final String title;
  final Uint8List? fileBytes;

  const DocumentViewerScreen({
    super.key,
    required this.filePath,
    required this.title,
    this.fileBytes,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late final DocumentViewController _controller;
  bool _isSummarizing = false;
  String? _pdfPath;
  bool _isPreparingPdfText = true;

  bool get _isPdf => p.extension(widget.title).toLowerCase() == '.pdf';

  @override
  void initState() {
    super.initState();
    _controller = DocumentViewController();
    _preparePdfTextSource();
  }

  @override
  void dispose() {
    _controller.dispose();
    final path = _pdfPath;
    if (path != null) {
      unawaited(File(path).delete().then<void>((_) {}, onError: (Object _) {}));
    }
    super.dispose();
  }

  Future<void> _preparePdfTextSource() async {
    if (!_isPdf || widget.fileBytes == null) {
      if (mounted) setState(() => _isPreparingPdfText = false);
      return;
    }
    try {
      final directory = Directory('${Directory.systemTemp.path}/edunivora_pdf');
      await directory.create(recursive: true);
      final file = File(
        '${directory.path}/${DateTime.now().microsecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(widget.fileBytes!, flush: true);
      _pdfPath = file.path;
    } catch (error) {
      debugPrint('Unable to prepare PDF text source: $error');
    } finally {
      if (mounted) setState(() => _isPreparingPdfText = false);
    }
  }

  DocumentSource _documentSource() {
    final bytes = widget.fileBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return DocumentSource.bytes(bytes, name: widget.title);
    }
    return DocumentSource.file(widget.filePath, name: widget.title);
  }

  Future<String> _extractPdfText() async {
    final path = _pdfPath ?? widget.filePath;
    try {
      if (!File(path).existsSync()) return '';
      final document = await pdf_text.PDFDoc.fromFile(File(path));
      return await document.text;
    } catch (error) {
      debugPrint('PDF text extraction failed: $error');
      return '';
    }
  }

  Future<void> _summarizePdf() async {
    if (!_isPdf || _isSummarizing || _isPreparingPdfText) return;
    setState(() => _isSummarizing = true);
    try {
      final text = await _extractPdfText();
      if (!mounted) return;
      if (text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم أتمكن من استخراج نص من ملف PDF.')),
        );
        return;
      }
      final summary = await LocalSummarizerService.instance.summarize(text);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ملخص المحاضرة (محلي)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                      ),
                      IconButton(
                        tooltip: 'نسخ الملخص',
                        onPressed: () async {
                          final value = '${summary.quickSummary}\n\n${summary.keyPoints.join('\n')}';
                          await Clipboard.setData(ClipboardData(text: value));
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم نسخ الملخص')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(summary.quickSummary.isEmpty ? 'لا يتوفر ملخص سريع.' : summary.quickSummary),
                  if (summary.keyPoints.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('النقاط الأساسية', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...summary.keyPoints.map((point) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('• $point'),
                    )),
                  ],
                  if (summary.coreConcepts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('المفاهيم الأساسية', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: summary.coreConcepts.map((item) => Chip(label: Text(item))).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSummarizing = false);
    }
  }

  String _failureMessage(DocumentFailure failure) => switch (failure) {
        EncryptedDocumentFailure() => 'هذا الملف محمي بكلمة مرور ولا يمكن فتحه حالياً.',
        TooLargeFailure() => 'حجم الملف كبير جداً للمعاينة داخل التطبيق.',
        UnsupportedFormatFailure() => 'صيغة الملف غير مدعومة للمعاينة.',
        CorruptDocumentFailure() => 'الملف تالف أو غير مكتمل.',
        SuspiciousArchiveFailure() => 'تم رفض الملف لأسباب تتعلق بسلامة المحتوى.',
        _ => 'تعذر فتح الملف. حاول إرفاق نسخة أخرى.',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_isPdf)
            IconButton(
              tooltip: 'تلخيص ملف PDF محلياً',
              onPressed: _isSummarizing || _isPreparingPdfText ? null : _summarizePdf,
              icon: _isSummarizing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.article_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: DocumentView(
          source: _documentSource(),
          controller: _controller,
          backgroundColor: Theme.of(context).colorScheme.surface,
          placeholderBuilder: (_) => const Center(child: CircularProgressIndicator()),
          errorBuilder: (context, failure) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text(_failureMessage(failure), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
