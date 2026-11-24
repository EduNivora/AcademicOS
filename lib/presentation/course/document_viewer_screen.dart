import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/documents/document_summary_service.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String filePath;
  final String title;
  final bool deleteFileOnClose;

  const DocumentViewerScreen({
    super.key,
    required this.filePath,
    required this.title,
    this.deleteFileOnClose = true,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late final Future<PdfDocument> _documentFuture;
  late final PdfControllerPinch _controller;
  final DocumentSummaryService _summaryService = DocumentSummaryService();

  PdfDocument? _loadedDocument;
  bool _isLoading = true;
  bool _isSummarizing = false;
  bool _isDisposing = false;
  int _currentPage = 1;
  int? _pageCount;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _documentFuture = PdfDocument.openFile(widget.filePath);
    _controller = PdfControllerPinch(document: _documentFuture);
  }

  @override
  void dispose() {
    _isDisposing = true;
    _controller.dispose();
    unawaited(_releaseDocumentAndFile());
    super.dispose();
  }

  Future<void> _releaseDocumentAndFile() async {
    try {
      final document = _loadedDocument ?? await _documentFuture;
      if (!document.isClosed) await document.close();
    } catch (_) {
      // A failed or cancelled document open has no live native handle to close.
    }

    if (widget.deleteFileOnClose) {
      try {
        final file = File(widget.filePath);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // A later stale-file sweep removes abandoned temporary files.
      }
    }
  }

  void _onDocumentLoaded(PdfDocument document) {
    if (_isDisposing || !mounted) {
      unawaited(_closeDocument(document));
      return;
    }
    _loadedDocument = document;
    setState(() {
      _isLoading = false;
      _pageCount = document.pagesCount;
      _currentPage = _controller.page;
    });
  }

  Future<void> _closeDocument(PdfDocument document) async {
    try {
      if (!document.isClosed) await document.close();
    } catch (_) {
      // Native resource cleanup is best-effort during route teardown.
    }
  }

  void _onDocumentError(Object error) {
    if (!mounted || _isDisposing) return;
    String message = 'تعذر فتح ملف PDF. قد يكون الملف تالفاً أو غير مدعوم.';
    try {
      final file = File(widget.filePath);
      if (!file.existsSync()) {
        message = 'ملف PDF غير موجود في مساحة التخزين المؤقتة.';
      } else if (file.lengthSync() == 0) {
        message = 'ملف PDF فارغ ولا يحتوي على صفحات.';
      }
    } catch (_) {
      // Keep the generic recovery message.
    }
    setState(() {
      _isLoading = false;
      _loadError = message;
    });
  }

  Future<void> _goToPreviousPage() async {
    if (_isLoading || _currentPage <= 1) return;
    await _controller.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _goToNextPage() async {
    final count = _pageCount;
    if (_isLoading || count == null || _currentPage >= count) return;
    await _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _changeZoom(double multiplier) {
    if (_isLoading) return;
    final current = _controller.zoomRatio;
    if (current <= 0) return;
    final target = (current * multiplier).clamp(1.0, 5.0);
    final factor = target / current;
    _controller.value = _controller.value.clone()..scale(factor);
  }

  Future<void> _summarizePdf() async {
    if (_isLoading || _isSummarizing) return;
    setState(() => _isSummarizing = true);
    try {
      final result = await _summaryService.summarizePdf(widget.filePath);
      if (!mounted) return;
      if (!result.isSuccess) {
        final message = switch (result.status) {
          DocumentSummaryStatus.fileMissing => 'تعذر العثور على ملف PDF.',
          DocumentSummaryStatus.emptyFile => 'ملف PDF فارغ.',
          DocumentSummaryStatus.unsupportedFormat => 'صيغة المستند غير مدعومة للتلخيص.',
          DocumentSummaryStatus.tooLarge => 'الملف كبير جداً لاستخراج النص منه.',
          DocumentSummaryStatus.noExtractableText =>
            'لم يُعثر على نص قابل للاستخراج. قد يكون الملف ممسوحاً ضوئياً؛ OCR غير متاح حالياً.',
          DocumentSummaryStatus.failed =>
            'فشل استخراج النص من المستند. لم يتم إرسال الملف إلى أي خدمة خارجية.',
          DocumentSummaryStatus.success => 'تعذر تجهيز الملخص.',
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      final summary = result.summary!;
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
                          'ملخص المستند محلياً',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                      ),
                      IconButton(
                        tooltip: 'نسخ الملخص',
                        onPressed: () async {
                          final value = summary.quickSummary + '\n\n' + summary.keyPoints.join('\n');
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
                  Text(summary.quickSummary),
                  if (summary.keyPoints.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('النقاط الأساسية', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...summary.keyPoints.map(
                      (point) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('• ' + point),
                      ),
                    ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'تلخيص PDF محلياً',
            onPressed: _isLoading || _isSummarizing ? null : _summarizePdf,
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
        child: _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.picture_as_pdf_outlined, size: 48),
                      const SizedBox(height: 12),
                      Text(_loadError!, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: DocumentViewerControls(
                      currentPage: _currentPage,
                      pageCount: _pageCount,
                      enabled: !_isLoading,
                      onPrevious: _goToPreviousPage,
                      onNext: _goToNextPage,
                      onZoomIn: () => _changeZoom(1.2),
                      onZoomOut: () => _changeZoom(1 / 1.2),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        PdfViewPinch(
                          controller: _controller,
                          minScale: 1,
                          maxScale: 5,
                          padding: 8,
                          onDocumentLoaded: _onDocumentLoaded,
                          onDocumentError: _onDocumentError,
                          onPageChanged: (page) {
                            if (mounted && !_isDisposing) {
                              setState(() => _currentPage = page);
                            }
                          },
                        ),
                        if (_isLoading)
                          const Positioned.fill(
                            child: IgnorePointer(
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class DocumentViewerControls extends StatelessWidget {
  final int currentPage;
  final int? pageCount;
  final bool enabled;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const DocumentViewerControls({
    super.key,
    required this.currentPage,
    required this.pageCount,
    required this.enabled,
    required this.onPrevious,
    required this.onNext,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    final count = pageCount;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            IconButton(
              key: const Key('pdf-previous-page'),
              tooltip: 'الصفحة السابقة',
              onPressed: enabled && currentPage > 1 ? onPrevious : null,
              icon: const Icon(Icons.chevron_right),
            ),
            Text(
              currentPage.toString() + ' / ' + (count?.toString() ?? '—'),
              key: const Key('pdf-page-counter'),
            ),
            IconButton(
              key: const Key('pdf-next-page'),
              tooltip: 'الصفحة التالية',
              onPressed: enabled && count != null && currentPage < count ? onNext : null,
              icon: const Icon(Icons.chevron_left),
            ),
            const Spacer(),
            IconButton(
              key: const Key('pdf-zoom-out'),
              tooltip: 'تصغير',
              onPressed: enabled ? onZoomOut : null,
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              key: const Key('pdf-zoom-in'),
              tooltip: 'تكبير',
              onPressed: enabled ? onZoomIn : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
