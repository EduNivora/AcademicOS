import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfx/pdfx.dart';

import 'package:academic_os/core/documents/pdf_text_extraction_service.dart';
import 'package:academic_os/core/documents/course_material_file_service.dart';
import 'package:academic_os/presentation/course/document_viewer_screen.dart';

List<int> _minimalTextPdf() {
  const stream =
      'BT /F1 18 Tf 72 720 Td (AcademicOS PDF integration test) Tj ET\n';
  final objects = <String>[
    '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
    '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
    '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n',
    '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n',
    '5 0 obj\n<< /Length ' +
        stream.length.toString() +
        ' >>\nstream\n' +
        stream +
        'endstream\nendobj\n',
  ];
  final output = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (final object in objects) {
    offsets.add(output.length);
    output.write(object);
  }
  final xrefOffset = output.length;
  output.write('xref\n0 6\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    output.write(offset.toString().padLeft(10, '0') + ' 00000 n \n');
  }
  output.write('trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n');
  output.write(xrefOffset.toString());
  output.write('\n%%EOF\n');
  return utf8.encode(output.toString());
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android PDF opens in-app, exposes pages, extracts text, and cleans up',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      final file = File(
        Directory.systemTemp.path +
            '/edunivora_pdf_integration_' +
            DateTime.now().microsecondsSinceEpoch.toString() +
            '.pdf',
      );
      await file.writeAsBytes(_minimalTextPdf(), flush: true);

      final document = await PdfDocument.openFile(file.path);
      expect(document.pagesCount, 1);
      await document.close();

      final extraction = await PdfTextExtractionService().extract(file.path);
      expect(extraction.status, PdfTextExtractionStatus.success);
      expect(extraction.text, contains('AcademicOS PDF integration test'));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const Key('open-pdf-integration'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DocumentViewerScreen(
                          filePath: file.path,
                          title: 'integration.pdf',
                        ),
                      ),
                    );
                  },
                  child: const Text('Open PDF'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open-pdf-integration')));
      await tester.pump();
      for (var attempt = 0; attempt < 40; attempt++) {
        await tester.pump(const Duration(milliseconds: 250));
        if (find.text('1 / 1').evaluate().isNotEmpty) break;
      }
      expect(find.text('1 / 1'), findsOneWidget);

      Navigator.of(tester.element(find.byType(DocumentViewerScreen))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      for (var attempt = 0; attempt < 50 && await file.exists(); attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(await file.exists(), isFalse);
    },
  );

  testWidgets(
    'Android Office handoff returns a typed status and preserves launched file',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      final bytes = Uint8List.fromList([0x50, 0x4b, 0x03, 0x04]);
      // Exercise the production cache path exposed by Android FileProvider,
      // rather than injecting a test-only temporary directory.
      final title =
          'intent-check-${DateTime.now().microsecondsSinceEpoch}.docx';
      final service = CourseMaterialFileService(loadBytes: (_) async => bytes);
      final status = await service.openOfficeExternally(
        materialId: 22,
        title: title,
        fileType: 'docx',
      );
      expect(
        status,
        anyOf(
          ExternalMaterialOpenStatus.opened,
          ExternalMaterialOpenStatus.noApp,
        ),
      );
      final files = Directory(
        '${Directory.systemTemp.parent.path}/cache/edunivora_materials',
      );
      final matchingFiles = files
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('_$title'))
          .toList();
      if (status == ExternalMaterialOpenStatus.opened) {
        expect(matchingFiles, hasLength(1));
        expect(await matchingFiles.single.exists(), isTrue);
      } else {
        expect(matchingFiles, isEmpty);
      }
      for (final file in matchingFiles) {
        await file.delete();
      }
    },
  );
}
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../data/database/database_helper.dart';

enum ExternalMaterialOpenStatus { opened, noApp, unsupportedPlatform, failed }

class MaterialFileUnavailableException implements Exception {
  final String message;
  const MaterialFileUnavailableException(this.message);
  @override
  String toString() => message;
}

class UnsupportedMaterialFormatException implements Exception {
  final String message;
  const UnsupportedMaterialFormatException(this.message);
  @override
  String toString() => message;
}

class PreparedMaterialFile {
  final File file;
  bool _deleted = false;
  PreparedMaterialFile(this.file);

  Future<void> delete() async {
    if (_deleted) return;
    _deleted = true;
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // The stale-file sweep is the fallback cleanup path.
    }
  }
}

typedef MaterialBytesLoader = Future<Uint8List?> Function(int materialId);
typedef TemporaryDirectoryProvider = Future<Directory> Function();
typedef ExternalMaterialOpener =
    Future<ExternalMaterialOpenStatus> Function(String path);

class CourseMaterialFileService {
  static const int defaultMaxFileBytes = 50 * 1024 * 1024;
  static const Duration externalFileRetention = Duration(days: 7);

  final MaterialBytesLoader _loadBytes;
  final TemporaryDirectoryProvider _temporaryDirectory;
  final ExternalMaterialOpener _openExternal;
  final int maxFileBytes;
  final DateTime Function() _now;

  CourseMaterialFileService({
    MaterialBytesLoader? loadBytes,
    TemporaryDirectoryProvider? temporaryDirectory,
    ExternalMaterialOpener? openExternal,
    this.maxFileBytes = defaultMaxFileBytes,
    DateTime Function()? now,
  }) : _loadBytes = loadBytes ?? DatabaseHelper.instance.getMaterialFileBytes,
       _temporaryDirectory = temporaryDirectory ?? _defaultTemporaryDirectory,
       _openExternal = openExternal ?? _openWithPlatform,
       _now = now ?? DateTime.now;

  static Future<Directory> _defaultTemporaryDirectory() async {
    // Android's systemTemp resolves to code_cache, which is not included in
    // the FileProvider paths. Use the sibling app cache directory instead.
    if (Platform.isAndroid) {
      return Directory(p.join(Directory.systemTemp.parent.path, 'cache'));
    }
    return Directory.systemTemp;
  }

  Future<Uint8List> loadMaterialBytes(int materialId) async {
    if (materialId <= 0) {
      throw const MaterialFileUnavailableException('معرّف المرفق غير صالح.');
    }
    final bytes = await _loadBytes(materialId);
    if (bytes == null || bytes.isEmpty) {
      throw const MaterialFileUnavailableException(
        'محتوى الملف غير موجود في التخزين المحلي.',
      );
    }
    if (bytes.length > maxFileBytes) {
      throw const MaterialFileUnavailableException(
        'حجم الملف يتجاوز الحد المسموح (50 MB).',
      );
    }
    return bytes;
  }

  Future<PreparedMaterialFile> preparePdfForViewing({
    required int materialId,
    required String title,
    required String fileType,
    Uint8List? bytes,
  }) async {
    final extension = _validatedExtension(title, fileType, const {'pdf'});
    final payload = bytes ?? await loadMaterialBytes(materialId);
    _validatePayload(payload);
    if (!_containsPdfHeader(payload)) {
      throw const MaterialFileUnavailableException(
        'الملف لا يحتوي على ترويسة PDF صالحة أو أنه تالف.',
      );
    }
    final file = await _writePrivateTemporaryFile(
      materialId: materialId,
      title: title,
      extension: extension,
      bytes: payload,
    );
    return PreparedMaterialFile(file);
  }

  Future<ExternalMaterialOpenStatus> openOfficeExternally({
    required int materialId,
    required String title,
    required String fileType,
    Uint8List? bytes,
  }) async {
    final extension = _validatedExtension(title, fileType, const {
      'doc',
      'docx',
      'ppt',
      'pptx',
    });
    final payload = bytes ?? await loadMaterialBytes(materialId);
    _validatePayload(payload);
    final file = await _writePrivateTemporaryFile(
      materialId: materialId,
      title: title,
      extension: extension,
      bytes: payload,
    );
    final prepared = PreparedMaterialFile(file);
    try {
      final status = await _openExternal(file.path);
      if (status != ExternalMaterialOpenStatus.opened) await prepared.delete();
      return status;
    } catch (_) {
      await prepared.delete();
      rethrow;
    }
  }

  String _validatedExtension(
    String title,
    String fileType,
    Set<String> allowed,
  ) {
    final extension = p.extension(title).replaceFirst('.', '').toLowerCase();
    final declared = fileType.replaceFirst(RegExp(r'^\.'), '').toLowerCase();
    if (extension.isEmpty ||
        extension != declared ||
        !allowed.contains(extension)) {
      throw const UnsupportedMaterialFormatException(
        'صيغة الملف غير مدعومة أو لا تطابق نوع المرفق المسجل.',
      );
    }
    return extension;
  }

  void _validatePayload(Uint8List bytes) {
    if (bytes.isEmpty)
      throw const MaterialFileUnavailableException('الملف فارغ.');
    if (bytes.length > maxFileBytes) {
      throw const MaterialFileUnavailableException(
        'حجم الملف يتجاوز الحد المسموح (50 MB).',
      );
    }
  }

  bool _containsPdfHeader(Uint8List bytes) {
    final length = bytes.length < 1024 ? bytes.length : 1024;
    return String.fromCharCodes(bytes.take(length)).contains('%PDF-');
  }

  Future<File> _writePrivateTemporaryFile({
    required int materialId,
    required String title,
    required String extension,
    required Uint8List bytes,
  }) async {
    final root = await _temporaryDirectory();
    final directory = Directory(p.join(root.path, 'edunivora_materials'));
    await directory.create(recursive: true);
    await _cleanupExpiredExternalFiles(directory);

    final safeName = p
        .basename(title)
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final timestamp = _now().microsecondsSinceEpoch;
    final fileName =
        'material_' +
        materialId.toString() +
        '_' +
        timestamp.toString() +
        '_' +
        safeName;
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _cleanupExpiredExternalFiles(Directory directory) async {
    final cutoff = _now().subtract(externalFileRetention);
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !p.basename(entity.path).startsWith('material_'))
          continue;
        try {
          if ((await entity.lastModified()).isBefore(cutoff))
            await entity.delete();
        } on FileSystemException {
          // External applications may still hold a file open.
        }
      }
    } on FileSystemException {
      // A later file creation will retry cleanup.
    }
  }

  static Future<ExternalMaterialOpenStatus> _openWithPlatform(
    String path,
  ) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return ExternalMaterialOpenStatus.unsupportedPlatform;
    }
    final result = await OpenFilex.open(path);
    return switch (result.type) {
      ResultType.done => ExternalMaterialOpenStatus.opened,
      ResultType.noAppToOpen => ExternalMaterialOpenStatus.noApp,
      ResultType.fileNotFound => ExternalMaterialOpenStatus.failed,
      ResultType.permissionDenied => ExternalMaterialOpenStatus.failed,
      ResultType.error => ExternalMaterialOpenStatus.failed,
    };
  }
}
import '../services/local_summarizer_service.dart';
import 'pdf_text_extraction_service.dart';

enum DocumentSummaryStatus {
  success,
  fileMissing,
  emptyFile,
  unsupportedFormat,
  tooLarge,
  noExtractableText,
  failed,
}

class DocumentSummaryResult {
  final DocumentSummaryStatus status;
  final Summary? summary;
  const DocumentSummaryResult({required this.status, this.summary});
  bool get isSuccess =>
      status == DocumentSummaryStatus.success && summary != null;
}

class DocumentSummaryService {
  final PdfTextExtractionService _extractor;
  final LocalSummarizerService _summarizer;

  DocumentSummaryService({
    PdfTextExtractionService? extractor,
    LocalSummarizerService? summarizer,
  }) : _extractor = extractor ?? PdfTextExtractionService(),
       _summarizer = summarizer ?? LocalSummarizerService.instance;

  Future<DocumentSummaryResult> summarizePdf(String filePath) async {
    final extraction = await _extractor.extract(filePath);
    if (!extraction.isSuccess) {
      return DocumentSummaryResult(
        status: switch (extraction.status) {
          PdfTextExtractionStatus.fileMissing =>
            DocumentSummaryStatus.fileMissing,
          PdfTextExtractionStatus.emptyFile => DocumentSummaryStatus.emptyFile,
          PdfTextExtractionStatus.unsupportedFormat =>
            DocumentSummaryStatus.unsupportedFormat,
          PdfTextExtractionStatus.tooLarge => DocumentSummaryStatus.tooLarge,
          PdfTextExtractionStatus.noExtractableText =>
            DocumentSummaryStatus.noExtractableText,
          PdfTextExtractionStatus.failed => DocumentSummaryStatus.failed,
          PdfTextExtractionStatus.success => DocumentSummaryStatus.failed,
        },
      );
    }
    try {
      final summary = await _summarizer.summarize(extraction.text);
      if (summary.quickSummary.trim().isEmpty) {
        return const DocumentSummaryResult(
          status: DocumentSummaryStatus.noExtractableText,
        );
      }
      return DocumentSummaryResult(
        status: DocumentSummaryStatus.success,
        summary: summary,
      );
    } catch (_) {
      return const DocumentSummaryResult(status: DocumentSummaryStatus.failed);
    }
  }
}
import 'dart:io';

import 'package:flutter_pdf_text/flutter_pdf_text.dart';
import 'package:path/path.dart' as p;

enum PdfTextExtractionStatus {
  success,
  fileMissing,
  emptyFile,
  unsupportedFormat,
  tooLarge,
  noExtractableText,
  failed,
}

class PdfTextExtractionResult {
  final PdfTextExtractionStatus status;
  final String text;
  const PdfTextExtractionResult({required this.status, this.text = ''});
  bool get isSuccess => status == PdfTextExtractionStatus.success;
}

typedef PdfPageTextReader =
    Future<String> Function(File file, {required int maxCharacters});

class PdfTextExtractionService {
  static const int defaultMaxFileBytes = 50 * 1024 * 1024;
  static const int defaultMaxCharacters = 200000;

  final PdfPageTextReader _reader;
  final int maxFileBytes;
  final int maxCharacters;
  final Directory Function() _temporaryDirectory;
  final DateTime Function() _now;

  PdfTextExtractionService({
    PdfPageTextReader? reader,
    this.maxFileBytes = defaultMaxFileBytes,
    this.maxCharacters = defaultMaxCharacters,
    Directory Function()? temporaryDirectory,
    DateTime Function()? now,
  }) : _reader = reader ?? _readPdfPages,
       _temporaryDirectory = temporaryDirectory ?? (() => Directory.systemTemp),
       _now = now ?? DateTime.now;

  Future<PdfTextExtractionResult> extract(String filePath) async {
    final source = File(filePath);
    if (p.extension(filePath).toLowerCase() != '.pdf') {
      return const PdfTextExtractionResult(
        status: PdfTextExtractionStatus.unsupportedFormat,
      );
    }
    try {
      if (!await source.exists()) {
        return const PdfTextExtractionResult(
          status: PdfTextExtractionStatus.fileMissing,
        );
      }
      final size = await source.length();
      if (size == 0)
        return const PdfTextExtractionResult(
          status: PdfTextExtractionStatus.emptyFile,
        );
      if (size > maxFileBytes)
        return const PdfTextExtractionResult(
          status: PdfTextExtractionStatus.tooLarge,
        );

      final directory = _temporaryDirectory();
      await directory.create(recursive: true);
      final copy = File(
        p.join(
          directory.path,
          'edunivora_summary_' +
              _now().microsecondsSinceEpoch.toString() +
              '.pdf',
        ),
      );
      try {
        await source.copy(copy.path);
        final text = (await _reader(copy, maxCharacters: maxCharacters)).trim();
        if (text.isEmpty) {
          return const PdfTextExtractionResult(
            status: PdfTextExtractionStatus.noExtractableText,
          );
        }
        return PdfTextExtractionResult(
          status: PdfTextExtractionStatus.success,
          text: text,
        );
      } finally {
        try {
          if (await copy.exists()) await copy.delete();
        } on FileSystemException {
          // The source document is never deleted here.
        }
      }
    } on FileSystemException {
      return const PdfTextExtractionResult(
        status: PdfTextExtractionStatus.failed,
      );
    } catch (_) {
      return const PdfTextExtractionResult(
        status: PdfTextExtractionStatus.failed,
      );
    }
  }

  static Future<String> _readPdfPages(
    File file, {
    required int maxCharacters,
  }) async {
    final document = await PDFDoc.fromFile(file);
    try {
      final output = StringBuffer();
      for (
        var pageNumber = 1;
        pageNumber <= document.length && output.length < maxCharacters;
        pageNumber++
      ) {
        final pageText = await document.pageAt(pageNumber).text;
        final remaining = maxCharacters - output.length;
        output.write(
          pageText.length > remaining
              ? pageText.substring(0, remaining)
              : pageText,
        );
        output.write('\n');
      }
      return output.toString();
    } finally {
      document.deleteFile();
    }
  }
}
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
  Future<PdfDocument>? _documentFuture;
  PdfControllerPinch? _controller;
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
    // Defer native PDF initialization until this route has entered the frame.
    // Other screens never construct this route or initialize the PDF engine.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_initializeDocument());
    });
  }

  Future<void> _initializeDocument() async {
    try {
      final future = PdfDocument.openFile(widget.filePath);
      _documentFuture = future;
      final controller = PdfControllerPinch(document: future);
      if (!mounted || _isDisposing) {
        controller.dispose();
        final document = await future;
        if (!document.isClosed) await document.close();
        return;
      }
      setState(() => _controller = controller);
    } catch (error) {
      await _onDocumentError(error);
    }
  }

  @override
  void dispose() {
    _isDisposing = true;
    _controller?.dispose();
    unawaited(_releaseDocumentAndFile());
    super.dispose();
  }

  Future<void> _releaseDocumentAndFile() async {
    try {
      final future = _documentFuture;
      if (future != null) {
        final document = _loadedDocument ?? await future;
        if (!document.isClosed) await document.close();
      }
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
    if (_isDisposing || !mounted) return;
    _loadedDocument = document;
    setState(() {
      _isLoading = false;
      _pageCount = document.pagesCount;
      _currentPage = _controller?.page ?? 1;
    });
  }

  Future<void> _onDocumentError(Object error) async {
    if (!mounted || _isDisposing) return;
    var message = 'تعذر فتح ملف PDF. قد يكون الملف تالفاً أو غير مدعوم.';
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        message = 'ملف PDF غير موجود في مساحة التخزين المؤقتة.';
      } else if (await file.length() == 0) {
        message = 'ملف PDF فارغ ولا يحتوي على صفحات.';
      }
    } catch (_) {
      // Keep the generic recovery message.
    }
    if (!mounted || _isDisposing) return;
    setState(() {
      _isLoading = false;
      _loadError = message;
    });
  }

  Future<void> _goToPreviousPage() async {
    if (_isLoading || _currentPage <= 1) return;
    final controller = _controller;
    if (controller == null) return;
    await controller.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _goToNextPage() async {
    final count = _pageCount;
    if (_isLoading || count == null || _currentPage >= count) return;
    final controller = _controller;
    if (controller == null) return;
    await controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _changeZoom(double multiplier) {
    if (_isLoading) return;
    final controller = _controller;
    if (controller == null) return;
    final current = controller.zoomRatio;
    if (current <= 0) return;
    final target = (current * multiplier).clamp(1.0, 5.0);
    final factor = target / current;
    controller.value = controller.value.clone()..scale(factor);
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
          DocumentSummaryStatus.unsupportedFormat =>
            'صيغة المستند غير مدعومة للتلخيص.',
          DocumentSummaryStatus.tooLarge =>
            'الملف كبير جداً لاستخراج النص منه.',
          DocumentSummaryStatus.noExtractableText =>
            'لم يُعثر على نص قابل للاستخراج. قد يكون الملف ممسوحاً ضوئياً؛ OCR غير متاح حالياً.',
          DocumentSummaryStatus.failed =>
            'فشل استخراج النص من المستند. لم يتم إرسال الملف إلى أي خدمة خارجية.',
          DocumentSummaryStatus.success => 'تعذر تجهيز الملخص.',
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'نسخ الملخص',
                        onPressed: () async {
                          final value =
                              summary.quickSummary +
                              '\n\n' +
                              summary.keyPoints.join('\n');
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
                    const Text(
                      'النقاط الأساسية',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                    const Text(
                      'المفاهيم الأساسية',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: summary.coreConcepts
                          .map((item) => Chip(label: Text(item)))
                          .toList(),
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
                        if (_controller != null)
                          PdfViewPinch(
                            controller: _controller!,
                            minScale: 1,
                            maxScale: 5,
                            padding: 8,
                            onDocumentLoaded: _onDocumentLoaded,
                            onDocumentError: (error) =>
                                unawaited(_onDocumentError(error)),
                            onPageChanged: (page) {
                              if (mounted && !_isDisposing) {
                                setState(() => _currentPage = page);
                              }
                            },
                          )
                        else
                          const Center(child: CircularProgressIndicator()),
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
              onPressed: enabled && count != null && currentPage < count
                  ? onNext
                  : null,
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
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../../core/documents/course_material_file_service.dart';
import '../../../core/documents/document_summary_service.dart';
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
  final Set<int> _summarizingMaterialIds = <int>{};
  final CourseMaterialFileService _fileService = CourseMaterialFileService();

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    final rows = await DatabaseHelper.instance.getMaterialsByCourseId(
      widget.courseId,
    );
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
      withData: kIsWeb,
    );
    if (result == null || !mounted) return;
    final file = result.files.first;
    const maxFileBytes = 50 * 1024 * 1024;
    if (file.size > maxFileBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حجم الملف يتجاوز الحد المسموح (50 MB).')),
      );
      return;
    }

    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      try {
        final source = File(file.path!);
        if (await source.exists()) {
          final length = await source.length();
          if (length > maxFileBytes) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('حجم الملف يتجاوز الحد المسموح (50 MB).'),
                ),
              );
            }
            return;
          }
          if (length > 0) bytes = await source.readAsBytes();
        }
      } on FileSystemException {
        // Fall through to the common unavailable-file message.
      }
    }
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر قراءة محتوى الملف المحدد.')),
      );
      return;
    }

    final fileName = p.basename(file.name);
    final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
    if (!{'pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt'}.contains(ext)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('نوع الملف غير مدعوم.')));
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
    if (materialId == null ||
        _openingMaterialIds.contains(materialId) ||
        _summarizingMaterialIds.contains(materialId)) {
      return;
    }
    setState(() => _openingMaterialIds.add(materialId));

    PreparedMaterialFile? preparedPdf;
    try {
      final extension = material.fileType.toLowerCase().replaceFirst('.', '');
      Uint8List? bytes = await _fileService.loadMaterialBytes(materialId);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نوع الملف غير مدعوم للعرض.')),
      );
    } on MaterialFileUnavailableException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } on UnsupportedMaterialFormatException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      debugPrint('Opening course material failed: $error');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تجهيز الملف للعرض. لم يتم تعديل المرفق الأصلي.',
            ),
          ),
        );
    } finally {
      await preparedPdf?.delete();
      if (mounted) setState(() => _openingMaterialIds.remove(materialId));
    }
  }

  Future<void> _summarizeMaterial(CourseMaterialModel material) async {
    final materialId = material.id;
    if (materialId == null ||
        _summarizingMaterialIds.contains(materialId) ||
        _openingMaterialIds.contains(materialId)) {
      return;
    }
    final extension = material.fileType.toLowerCase().replaceFirst('.', '');
    if (extension != 'pdf') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تلخيص المستند متاح حالياً لملفات PDF النصية فقط.'),
        ),
      );
      return;
    }

    setState(() => _summarizingMaterialIds.add(materialId));
    PreparedMaterialFile? prepared;
    try {
      prepared = await _fileService.preparePdfForViewing(
        materialId: materialId,
        title: material.title,
        fileType: material.fileType,
      );
      if (!mounted) return;
      final result = await DocumentSummaryService().summarizePdf(
        prepared.file.path,
      );
      if (!mounted) return;
      if (!result.isSuccess) {
        final message = switch (result.status) {
          DocumentSummaryStatus.fileMissing => 'تعذر العثور على ملف PDF.',
          DocumentSummaryStatus.emptyFile => 'ملف PDF فارغ.',
          DocumentSummaryStatus.unsupportedFormat =>
            'صيغة المستند غير مدعومة للتلخيص.',
          DocumentSummaryStatus.tooLarge =>
            'الملف كبير جداً لاستخراج النص منه.',
          DocumentSummaryStatus.noExtractableText =>
            'لم يُعثر على نص قابل للاستخراج. قد يكون الملف ممسوحاً ضوئياً؛ OCR غير متاح حالياً.',
          DocumentSummaryStatus.failed =>
            'فشل استخراج النص من المستند. لم يتم إرسال الملف إلى أي خدمة خارجية.',
          DocumentSummaryStatus.success => 'تعذر تجهيز الملخص.',
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
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
                  const Text(
                    'ملخص المستند محلياً',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 12),
                  Text(summary.quickSummary),
                  if (summary.keyPoints.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'النقاط الأساسية',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...summary.keyPoints.map(
                      (point) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('• $point'),
                      ),
                    ),
                  ],
                  if (summary.coreConcepts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'المفاهيم الأساسية',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: summary.coreConcepts
                          .map((item) => Chip(label: Text(item)))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    } on MaterialFileUnavailableException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } on UnsupportedMaterialFormatException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      debugPrint('Summarizing course material failed: $error');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تلخيص المستند. لم يتم تعديل الملف الأصلي.'),
          ),
        );
    } finally {
      await prepared?.delete();
      if (mounted) setState(() => _summarizingMaterialIds.remove(materialId));
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
          'سيتم حذف «' +
              material.title +
              '» وبيانات الملف المحفوظة على هذا الجهاز.',
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
                child: Text(
                  'المحاضرات والمرفقات',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _pickAndSave,
                icon: const Icon(Icons.attach_file),
                label: const Text('إضافة محاضرة / ملف'),
              ),
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
                        label: const Text('إضافة محاضرة'),
                      ),
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (m.fileType.toLowerCase().replaceFirst('.', '') ==
                              'pdf')
                            _summarizingMaterialIds.contains(m.id)
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : IconButton(
                                    tooltip: 'تلخيص PDF دون فتح العارض',
                                    icon: const Icon(Icons.summarize_outlined),
                                    onPressed:
                                        _openingMaterialIds.contains(m.id)
                                        ? null
                                        : () => _summarizeMaterial(m),
                                  ),
                          _openingMaterialIds.contains(m.id)
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteMaterial(m.id!),
                                ),
                        ],
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
      child: Icon(icon, color: color),
    );
  }
}
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/documents/course_material_file_service.dart';

void main() {
  late Directory root;
  late Uint8List pdfBytes;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('academicos-material-test-');
    pdfBytes = Uint8List.fromList('%PDF-1.7\nfixture'.codeUnits);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  CourseMaterialFileService service({
    Uint8List? bytes,
    ExternalMaterialOpener? opener,
    int maxBytes = 1024,
  }) {
    return CourseMaterialFileService(
      loadBytes: (_) async => bytes ?? pdfBytes,
      temporaryDirectory: () async => root,
      openExternal: opener,
      maxFileBytes: maxBytes,
    );
  }

  test('prepares a private PDF file only when viewing is requested', () async {
    final prepared = await service().preparePdfForViewing(
      materialId: 7,
      title: '../../lecture.pdf',
      fileType: 'pdf',
    );
    expect(await prepared.file.exists(), isTrue);
    expect(await prepared.file.readAsBytes(), orderedEquals(pdfBytes));
    expect(prepared.file.parent.path, contains('edunivora_materials'));
    expect(prepared.file.path, isNot(contains('../')));
    await prepared.delete();
    expect(await prepared.file.exists(), isFalse);
  });

  test('rejects unsupported or mismatched document extensions', () async {
    await expectLater(
      service().preparePdfForViewing(
        materialId: 1,
        title: 'lecture.docx',
        fileType: 'docx',
      ),
      throwsA(isA<UnsupportedMaterialFormatException>()),
    );
    await expectLater(
      service().openOfficeExternally(
        materialId: 1,
        title: 'lecture.exe',
        fileType: 'exe',
      ),
      throwsA(isA<UnsupportedMaterialFormatException>()),
    );
  });

  test('rejects missing, empty, oversized and invalid PDF bytes', () async {
    final missing = CourseMaterialFileService(
      loadBytes: (_) async => null,
      temporaryDirectory: () async => root,
    );
    await expectLater(
      missing.loadMaterialBytes(1),
      throwsA(isA<MaterialFileUnavailableException>()),
    );
    await expectLater(
      service(bytes: Uint8List(0)).loadMaterialBytes(1),
      throwsA(isA<MaterialFileUnavailableException>()),
    );
    await expectLater(
      service(bytes: Uint8List(1025)).loadMaterialBytes(1),
      throwsA(isA<MaterialFileUnavailableException>()),
    );
    await expectLater(
      service(
        bytes: Uint8List.fromList([1, 2, 3]),
      ).preparePdfForViewing(materialId: 1, title: 'bad.pdf', fileType: 'pdf'),
      throwsA(isA<MaterialFileUnavailableException>()),
    );
  });

  test(
    'keeps Office files available after the external activity is launched',
    () async {
      String? openedPath;
      final fileService = service(
        bytes: Uint8List.fromList([0x50, 0x4b, 0x03, 0x04]),
        opener: (path) async {
          openedPath = path;
          expect(await File(path).exists(), isTrue);
          return ExternalMaterialOpenStatus.opened;
        },
      );
      final status = await fileService.openOfficeExternally(
        materialId: 9,
        title: 'lecture.docx',
        fileType: 'docx',
      );
      expect(status, ExternalMaterialOpenStatus.opened);
      expect(openedPath, isNotNull);
      expect(await File(openedPath!).exists(), isTrue);
    },
  );

  test(
    'surfaces temporary-directory creation failures instead of opening an unsafe path',
    () async {
      final fileService = CourseMaterialFileService(
        loadBytes: (_) async => pdfBytes,
        temporaryDirectory: () async =>
            throw const FileSystemException('cache unavailable'),
      );
      await expectLater(
        fileService.preparePdfForViewing(
          materialId: 12,
          title: 'lecture.pdf',
          fileType: 'pdf',
        ),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test(
    'removes a temporary Office file when no compatible application exists',
    () async {
      String? openedPath;
      final fileService = service(
        bytes: Uint8List.fromList([0x50, 0x4b, 0x03, 0x04]),
        opener: (path) async {
          openedPath = path;
          return ExternalMaterialOpenStatus.noApp;
        },
      );
      final status = await fileService.openOfficeExternally(
        materialId: 10,
        title: 'slides.pptx',
        fileType: 'pptx',
      );
      expect(status, ExternalMaterialOpenStatus.noApp);
      expect(await File(openedPath!).exists(), isFalse);
    },
  );
}
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:academic_os/data/database/database_helper.dart';
import 'package:academic_os/data/models/course_model.dart';
import 'package:academic_os/data/models/task_model.dart';
import 'package:academic_os/data/models/exam_model.dart';
import 'package:academic_os/data/models/academic_term_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Database schema', () {
    test(
      'course cascade deletion removes related tasks, exams, schedules and files atomically',
      () async {
        final helper = DatabaseHelper.instance;
        await helper.close();
        final courseId = await helper.insertCourse(
          CourseModel(
            name: 'Cascade test material',
            instructor: 'Test',
            code: 'CASCADE-${DateTime.now().microsecondsSinceEpoch}',
          ),
        );
        final taskId = await helper.insertTask(
          TaskModel(
            title: 'Cascade task',
            description: '',
            courseId: courseId,
            courseName: 'Cascade test material',
          ),
        );
        final examId = await helper.insertExam(
          ExamModel(
            title: 'Cascade exam',
            examDate: DateTime(2027, 1, 1),
            courseId: courseId,
            courseName: 'Cascade test material',
          ),
        );
        final scheduleId = await helper.insertSchedule({
          'course_id': courseId,
          'day_of_week': 'الأحد',
          'start_time': '08:00',
          'end_time': '09:00',
          'location': 'Cascade room',
          'reminder_enabled': 1,
        });
        final materialId = await helper.insertMaterial({
          'course_id': courseId,
          'title': 'Cascade file',
          'file_path': 'memory://cascade',
          'file_type': 'pdf',
          'file_bytes': Uint8List.fromList([1, 2, 3]),
          'created_at': DateTime.now().toIso8601String(),
        });

        final result = await helper.deleteCourseCascade(courseId);
        expect(result.deletedCourses, 1);
        expect(result.taskIds, contains(taskId));
        expect(result.scheduleIds, contains(scheduleId));
        expect(await helper.getCourseById(courseId), isNull);
        expect(
          (await helper.getTasks()).where((task) => task.id == taskId),
          isEmpty,
        );
        expect(
          (await helper.getExams()).where((exam) => exam.id == examId),
          isEmpty,
        );
        expect(
          await helper.getSchedules().then(
            (rows) => rows.where((row) => row['id'] == scheduleId),
          ),
          isEmpty,
        );
        expect(await helper.getMaterialsByCourseId(courseId), isEmpty);
        expect(materialId, greaterThan(0));
        await helper.close();
      },
    );

    test('bulk schedule insertion is atomic', () async {
      final helper = DatabaseHelper.instance;
      await helper.close();
      final before = await helper.getSchedules();
      final initialIds = before.map((row) => row['id']).toSet();

      try {
        final ids = await helper.insertSchedules([
          {
            'course_id': null,
            'day_of_week': 'الأحد',
            'start_time': '23:51',
            'end_time': '23:52',
            'location': 'Atomic test A',
            'reminder_enabled': 0,
          },
          {
            'course_id': null,
            'day_of_week': 'الأحد',
            'start_time': '23:53',
            'end_time': '23:54',
            'location': 'Atomic test B',
            'reminder_enabled': 0,
          },
        ]);
        expect(ids, hasLength(2));
        final after = await helper.getSchedules();
        expect(after.where((row) => ids.contains(row['id'])), hasLength(2));
      } finally {
        final after = await helper.getSchedules();
        for (final row in after) {
          final id = row['id'];
          if (id is int &&
              !initialIds.contains(id) &&
              (row['location'] == 'Atomic test A' ||
                  row['location'] == 'Atomic test B')) {
            await helper.deleteSchedule(id);
          }
        }
        await helper.close();
      }
    });
    test(
      'initial database creation should not add duplicate course grade columns',
      () async {
        final helper = DatabaseHelper.instance;
        await helper.close();

        final db = await helper.database;
        final result = await db.rawQuery("PRAGMA table_info(courses)");

        final columnNames = result
            .map((row) => row['name'].toString())
            .toList();
        expect(columnNames, contains('mid_grade'));
        expect(columnNames, contains('practical_grade'));
        expect(columnNames, contains('final_grade'));
        expect(columnNames, contains('credit_hours'));

        final duplicates = <String, int>{};
        for (final column in columnNames) {
          duplicates[column] = (duplicates[column] ?? 0) + 1;
        }

        for (final entry in duplicates.entries) {
          expect(
            entry.value,
            1,
            reason: 'Duplicate column detected: ${entry.key}',
          );
        }

        await helper.close();
      },
    );
  });

  test('course material attachment bytes persist in SQLite', () async {
    final helper = DatabaseHelper.instance;
    await helper.close();
    const courseId = 987661;
    const materialId = 987662;
    await helper.deleteMaterial(materialId);
    await helper.deleteCourse(courseId);
    final bytes = Uint8List.fromList([37, 80, 68, 70, 45, 49, 46, 52]);
    try {
      await helper.insertCourse(
        const CourseModel(
          id: courseId,
          name: 'Attachment persistence',
          instructor: 'Instructor',
          code: 'ATT-1',
          credits: 3,
        ),
      );
      await helper.insertMaterial({
        'id': materialId,
        'course_id': courseId,
        'title': 'sample.pdf',
        'file_path': 'dbblob://sample',
        'file_type': 'pdf',
        'file_bytes': bytes,
      });
      final row = await helper.getMaterialById(materialId);
      expect(row, isNotNull);
      expect(row!['file_bytes'], isA<Uint8List>());
      expect(
        List<int>.from(row['file_bytes'] as Uint8List),
        orderedEquals(bytes),
      );
      await helper.deleteMaterial(materialId);
      expect(await helper.getMaterialById(materialId), isNull);
    } finally {
      await helper.deleteMaterial(materialId);
      await helper.deleteCourse(courseId);
      await helper.close();
    }
  });

  test(
    'material lists load metadata only and fetch attachment bytes on demand',
    () async {
      final helper = DatabaseHelper.instance;
      await helper.close();
      final courseId = await helper.insertCourse(
        CourseModel(
          name: 'Lazy attachment test',
          instructor: 'Instructor',
          code: 'LAZY-' + DateTime.now().microsecondsSinceEpoch.toString(),
        ),
      );
      final bytes = Uint8List.fromList([37, 80, 68, 70, 45, 49, 46, 55]);
      final materialId = await helper.insertMaterial({
        'course_id': courseId,
        'title': 'lazy.pdf',
        'file_path': 'dbblob://lazy',
        'file_type': 'pdf',
        'file_bytes': bytes,
        'created_at': DateTime.now().toIso8601String(),
      });
      try {
        final courseRows = await helper.getMaterialsByCourseId(courseId);
        final allRows = await helper.getAllMaterials();
        final courseRow = courseRows.singleWhere(
          (row) => row['id'] == materialId,
        );
        final allRow = allRows.singleWhere((row) => row['id'] == materialId);
        expect(courseRow.containsKey('file_bytes'), isFalse);
        expect(allRow.containsKey('file_bytes'), isFalse);
        expect(
          await helper.getMaterialFileBytes(materialId),
          orderedEquals(bytes),
        );
      } finally {
        await helper.deleteMaterial(materialId);
        await helper.deleteCourse(courseId);
        await helper.close();
      }
    },
  );

  test(
    'academic terms enforce uniqueness, active selection, rename links and delete protection',
    () async {
      final helper = DatabaseHelper.instance;
      await helper.close();

      final startDate = DateTime(2026, 9, 1);
      final endDate = DateTime(2026, 12, 20);
      const firstName = '__db_term_integration_first__';
      const secondName = '__db_term_integration_second__';
      const courseId = 987671;

      await helper.deleteCourse(courseId);
      final existing = await helper.getAcademicTerms();
      for (final term in existing.where(
        (term) =>
            term.name == firstName ||
            term.name == secondName ||
            term.name == 'Renamed integration term',
      )) {
        await helper.deleteAcademicTerm(term.id!);
      }
      final previousActive = await helper.getActiveAcademicTerm();

      int? firstId;
      int? secondId;
      try {
        firstId = await helper.insertAcademicTerm(
          AcademicTermModel(
            name: firstName,
            startDate: startDate,
            endDate: endDate,
            isActive: true,
          ),
        );
        secondId = await helper.insertAcademicTerm(
          AcademicTermModel(
            name: secondName,
            startDate: startDate,
            endDate: endDate,
            isActive: true,
          ),
        );

        expect((await helper.getActiveAcademicTerm())?.id, secondId);
        final termsAfterActivation = await helper.getAcademicTerms();
        expect(
          termsAfterActivation
              .singleWhere((term) => term.id == firstId)
              .isActive,
          isFalse,
        );

        await expectLater(
          helper.insertAcademicTerm(
            AcademicTermModel(
              name: secondName.toUpperCase(),
              startDate: startDate,
              endDate: endDate,
            ),
          ),
          throwsA(isA<Exception>()),
        );

        await helper.insertCourse(
          const CourseModel(
            id: courseId,
            name: 'Term relationship test',
            instructor: 'Instructor',
            code: 'TERM-DB-1',
            credits: 3,
            semester: secondName,
          ),
        );

        await helper.updateAcademicTerm(
          AcademicTermModel(
            id: secondId,
            name: 'Renamed integration term',
            startDate: startDate,
            endDate: endDate,
            isActive: true,
          ),
        );
        expect(
          (await helper.getCourseById(courseId))?.semester,
          'Renamed integration term',
        );

        await expectLater(
          helper.deleteAcademicTerm(secondId),
          throwsA(isA<StateError>()),
        );

        await helper.deleteCourse(courseId);
        expect(await helper.deleteAcademicTerm(secondId), 1);
        expect(await helper.deleteAcademicTerm(firstId), 1);

        final db = await helper.database;
        final columns = await db.rawQuery('PRAGMA table_info(academic_terms)');
        final columnNames = columns.map((row) => row['name']).toSet();
        expect(
          columnNames,
          containsAll([
            'name',
            'start_date',
            'end_date',
            'is_active',
            'created_at',
          ]),
        );
        final indexes = await db.rawQuery('PRAGMA index_list(academic_terms)');
        final indexNames = indexes.map((row) => row['name']).toSet();
        expect(indexNames, contains('idx_academic_terms_name'));
        expect(indexNames, contains('idx_academic_terms_single_active'));
      } finally {
        await helper.deleteCourse(courseId);
        for (final id in [secondId, firstId]) {
          if (id != null) {
            await helper.deleteAcademicTerm(id);
          }
        }
        if (previousActive?.id != null) {
          await helper.setActiveAcademicTerm(previousActive!.id!);
        }
        await helper.close();
      }
    },
  );

  test(
    'schema v11 upgrades to v13 and adds completion timestamps without losing course data',
    () async {
      final helper = DatabaseHelper.instance;
      await helper.close();
      const courseId = 987672;
      await helper.deleteCourse(courseId);
      await helper.insertCourse(
        const CourseModel(
          id: courseId,
          name: 'Migration preservation',
          instructor: 'Instructor',
          code: 'MIG-12',
          credits: 3,
        ),
      );

      try {
        final db = await helper.database;
        await db.execute('DROP TABLE IF EXISTS academic_terms');
        await db.execute('PRAGMA user_version = 11');
        await helper.close();

        final upgradedDb = await helper.database;
        final version = await upgradedDb.rawQuery('PRAGMA user_version');
        expect(version.single['user_version'], 13);

        final termColumns = await upgradedDb.rawQuery(
          'PRAGMA table_info(academic_terms)',
        );
        expect(
          termColumns.map((row) => row['name']),
          containsAll(['name', 'start_date', 'end_date', 'is_active']),
        );
        final taskColumns = await upgradedDb.rawQuery(
          'PRAGMA table_info(tasks)',
        );
        expect(taskColumns.map((row) => row['name']), contains('completed_at'));
        final indexes = await upgradedDb.rawQuery(
          'PRAGMA index_list(academic_terms)',
        );
        expect(
          indexes.map((row) => row['name']),
          containsAll([
            'idx_academic_terms_name',
            'idx_academic_terms_single_active',
          ]),
        );
        expect(
          (await helper.getCourseById(courseId))?.name,
          'Migration preservation',
        );
      } finally {
        await helper.deleteCourse(courseId);
        await helper.close();
      }
    },
  );
}
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/documents/document_summary_service.dart';
import 'package:academic_os/core/documents/pdf_text_extraction_service.dart';

void main() {
  late Directory root;
  late File source;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('academicos-summary-test-');
    source = File(root.path + '/lecture.pdf');
    await source.writeAsString('%PDF-1.7\nfixture');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'summarizes extracted text locally without requiring the viewer',
    () async {
      final service = DocumentSummaryService(
        extractor: PdfTextExtractionService(
          temporaryDirectory: () => root,
          reader: (_, {required maxCharacters}) async =>
              'الشبكات الحاسوبية تتكون من عقد مترابطة. '
              'تستخدم الشبكات بروتوكولات لتنظيم الاتصال وتبادل البيانات. '
              'يساعد التشفير على حماية البيانات أثناء النقل.',
        ),
      );
      final result = await service.summarizePdf(source.path);
      expect(result.status, DocumentSummaryStatus.success);
      expect(result.summary, isNotNull);
      expect(result.summary!.quickSummary, isNotEmpty);
      expect(await source.exists(), isTrue);
    },
  );

  test(
    'does not fabricate a summary when the PDF has no extractable text',
    () async {
      final service = DocumentSummaryService(
        extractor: PdfTextExtractionService(
          temporaryDirectory: () => root,
          reader: (_, {required maxCharacters}) async => '',
        ),
      );
      final result = await service.summarizePdf(source.path);
      expect(result.status, DocumentSummaryStatus.noExtractableText);
      expect(result.summary, isNull);
    },
  );
}
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/presentation/course/document_viewer_screen.dart';

void main() {
  testWidgets('shows the current page count and enables valid navigation', (
    tester,
  ) async {
    var previous = 0;
    var next = 0;
    var zoomIn = 0;
    var zoomOut = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentViewerControls(
            currentPage: 2,
            pageCount: 8,
            enabled: true,
            onPrevious: () => previous++,
            onNext: () => next++,
            onZoomIn: () => zoomIn++,
            onZoomOut: () => zoomOut++,
          ),
        ),
      ),
    );
    expect(find.text('2 / 8'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pdf-previous-page')));
    await tester.tap(find.byKey(const Key('pdf-next-page')));
    await tester.tap(find.byKey(const Key('pdf-zoom-in')));
    await tester.tap(find.byKey(const Key('pdf-zoom-out')));
    expect(previous, 1);
    expect(next, 1);
    expect(zoomIn, 1);
    expect(zoomOut, 1);
  });

  testWidgets('disables previous and next controls at document boundaries', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentViewerControls(
            currentPage: 1,
            pageCount: 1,
            enabled: true,
            onPrevious: () {},
            onNext: () {},
            onZoomIn: () {},
            onZoomOut: () {},
          ),
        ),
      ),
    );
    final previous = tester.widget<IconButton>(
      find.byKey(const Key('pdf-previous-page')),
    );
    final next = tester.widget<IconButton>(
      find.byKey(const Key('pdf-next-page')),
    );
    expect(previous.onPressed, isNull);
    expect(next.onPressed, isNull);
  });
}
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/documents/pdf_text_extraction_service.dart';

void main() {
  late Directory root;
  late File source;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('academicos-pdf-text-test-');
    source = File(root.path + '/sample.pdf');
    await source.writeAsString('%PDF-1.7\nfixture');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'extracts through a bounded reader copy and never deletes the source',
    () async {
      var requestedLimit = 0;
      final extractor = PdfTextExtractionService(
        temporaryDirectory: () => root,
        maxCharacters: 120,
        reader: (file, {required maxCharacters}) async {
          requestedLimit = maxCharacters;
          expect(await file.exists(), isTrue);
          expect(file.path, isNot(source.path));
          return 'محتوى المحاضرة ومفاهيمها الأساسية.';
        },
      );
      final result = await extractor.extract(source.path);
      expect(result.status, PdfTextExtractionStatus.success);
      expect(result.text, contains('محتوى المحاضرة'));
      expect(requestedLimit, 120);
      expect(await source.exists(), isTrue);
      expect(
        root.listSync().where(
          (entity) => entity.path.contains('edunivora_summary_'),
        ),
        isEmpty,
      );
    },
  );

  test('reports missing, empty, unsupported and oversized files', () async {
    final extractor = PdfTextExtractionService(
      temporaryDirectory: () => root,
      maxFileBytes: 8,
      reader: (_, {required maxCharacters}) async => 'unused',
    );
    expect(
      (await extractor.extract(root.path + '/missing.pdf')).status,
      PdfTextExtractionStatus.fileMissing,
    );
    final empty = File(root.path + '/empty.pdf');
    await empty.create();
    expect(
      (await extractor.extract(empty.path)).status,
      PdfTextExtractionStatus.emptyFile,
    );
    expect(
      (await extractor.extract(
        source.path.replaceFirst('.pdf', '.docx'),
      )).status,
      PdfTextExtractionStatus.unsupportedFormat,
    );
    expect(
      (await extractor.extract(source.path)).status,
      PdfTextExtractionStatus.tooLarge,
    );
  });

  test(
    'reports scanned PDFs with no extractable text without claiming OCR',
    () async {
      final extractor = PdfTextExtractionService(
        temporaryDirectory: () => root,
        reader: (_, {required maxCharacters}) async => '',
      );
      final result = await extractor.extract(source.path);
      expect(result.status, PdfTextExtractionStatus.noExtractableText);
      expect(await source.exists(), isTrue);
    },
  );

  test('converts extraction failures into a safe failure status', () async {
    final extractor = PdfTextExtractionService(
      temporaryDirectory: () => root,
      reader: (_, {required maxCharacters}) async =>
          throw StateError('private failure'),
    );
    expect(
      (await extractor.extract(source.path)).status,
      PdfTextExtractionStatus.failed,
    );
    expect(await source.exists(), isTrue);
  });
}
Formatted 11 files (1 changed) in 0.08 seconds.