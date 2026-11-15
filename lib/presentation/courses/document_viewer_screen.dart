import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../../core/services/local_summarizer_service.dart';

// Extracts PDF text locally with flutter_pdf_text.
import 'package:flutter_pdf_text/flutter_pdf_text.dart' as pdf_text;

class DocumentViewerScreen extends StatefulWidget {
  final String filePath;
  final String title;
  final Uint8List? fileBytes;

  const DocumentViewerScreen(
      {super.key, required this.filePath, required this.title, this.fileBytes});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  bool _isSummarizing = false;
  String? _resolvedFilePath;
  bool _isPreparingPreview = true;

  @override
  void initState() {
    super.initState();
    _preparePreviewFile();
  }

  Future<void> _preparePreviewFile() async {
    try {
      if (widget.fileBytes != null) {
        final previewDirectory = Directory(
          '${Directory.systemTemp.path}/edunivora_pdf_previews',
        );
        await previewDirectory.create(recursive: true);
        final previewFile = File(
          '${previewDirectory.path}/${DateTime.now().microsecondsSinceEpoch}.pdf',
        );
        await previewFile.writeAsBytes(widget.fileBytes!, flush: true);
        _resolvedFilePath = previewFile.path;
      } else {
        _resolvedFilePath = widget.filePath;
      }
    } catch (error) {
      debugPrint('Unable to prepare local PDF preview: $error');
    } finally {
      if (mounted) setState(() => _isPreparingPreview = false);
    }
  }

  Future<String> _extractTextFromPdf() async {
    try {
      final file = File(_resolvedFilePath ?? widget.filePath);
      if (!file.existsSync()) return '';

      // Extract text locally without uploading the document.
      final doc = await pdf_text.PDFDoc.fromFile(file);
      return await doc.text;
    } catch (e) {
      // If extraction fails, return empty string so summarizer returns empty.
      debugPrint('PDF text extraction failed: $e');
      return '';
    }
  }

  Future<void> _onSummarizePressed() async {
    setState(() => _isSummarizing = true);
    try {
      final rawText = await _extractTextFromPdf();
      if (!mounted) return;
      if (rawText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم أتمكن من استخراج نص من الملف.')),
        );
        return;
      }

      final summary = await LocalSummarizerService.instance.summarize(rawText);
      if (!mounted) return;

      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              expand: false,
              builder: (_, controller) => SingleChildScrollView(
                controller: controller,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ملخص المحاضرة (محلي)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: () async {
                              final textToCopy = 'المفاهيم الأساسية:\n' +
                                  summary.coreConcepts.join(', ') +
                                  '\n\nالنقاط الجوهرية:\n' +
                                  summary.keyPoints.join('\n') +
                                  '\n\nملخص سريع:\n' +
                                  summary.quickSummary;
                              await Clipboard.setData(ClipboardData(text: textToCopy));
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الملخص')));
                            },
                            icon: const Icon(Icons.copy),
                            label: const Text('نسخ النص'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('المفاهيم الأساسية', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      if (summary.coreConcepts.isEmpty)
                        Text('لا توجد مفاهيم مكتشفة', style: TextStyle(color: Colors.grey.shade600))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: summary.coreConcepts.map((c) => Chip(label: Text(c))).toList(),
                        ),
                      const SizedBox(height: 12),
                      const Text('النقاط الجوهرية', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      if (summary.keyPoints.isEmpty)
                        Text('لا توجد نقاط جوهرية', style: TextStyle(color: Colors.grey.shade600))
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: summary.keyPoints.map((p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text('• ' + p),
                          )).toList(),
                        ),
                      const SizedBox(height: 12),
                      const Text('ملخص سريع', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(summary.quickSummary.isNotEmpty ? summary.quickSummary : 'لا يتوفر ملخص سريع'),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isSummarizing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: _isSummarizing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.article_outlined),
            tooltip: 'تلخيص المحاضرة (محلي)',
            onPressed: _isSummarizing ? null : _onSummarizePressed,
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(builder: (context) {
          if (_isPreparingPreview) {
            return const Center(child: CircularProgressIndicator());
          }
          final path = _resolvedFilePath;
          if (path == null || !File(path).existsSync()) {
            return const Center(child: Text('تعذر فتح الملف المحفوظ محلياً'));
          }
          return PDFView(
            filePath: path,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
          );
        }),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSummarizing ? null : _onSummarizePressed,
        label: _isSummarizing ? const Text('...') : const Text('تلخيص المحاضرة (محلي)'),
        icon: const Icon(Icons.lightbulb_outline),
      ),
    );
  }
}
