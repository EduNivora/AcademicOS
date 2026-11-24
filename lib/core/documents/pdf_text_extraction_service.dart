import 'dart:io';

import 'package:flutter_pdf_text/flutter_pdf_text.dart';
import 'package:path/path.dart' as p;

enum PdfTextExtractionStatus {
  success, fileMissing, emptyFile, unsupportedFormat, tooLarge, noExtractableText, failed,
}

class PdfTextExtractionResult {
  final PdfTextExtractionStatus status;
  final String text;
  const PdfTextExtractionResult({required this.status, this.text = ''});
  bool get isSuccess => status == PdfTextExtractionStatus.success;
}

typedef PdfPageTextReader = Future<String> Function(File file, {required int maxCharacters});

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
  })  : _reader = reader ?? _readPdfPages,
        _temporaryDirectory = temporaryDirectory ?? (() => Directory.systemTemp),
        _now = now ?? DateTime.now;

  Future<PdfTextExtractionResult> extract(String filePath) async {
    final source = File(filePath);
    if (p.extension(filePath).toLowerCase() != '.pdf') {
      return const PdfTextExtractionResult(status: PdfTextExtractionStatus.unsupportedFormat);
    }
    try {
      if (!await source.exists()) {
        return const PdfTextExtractionResult(status: PdfTextExtractionStatus.fileMissing);
      }
      final size = await source.length();
      if (size == 0) return const PdfTextExtractionResult(status: PdfTextExtractionStatus.emptyFile);
      if (size > maxFileBytes) return const PdfTextExtractionResult(status: PdfTextExtractionStatus.tooLarge);

      final directory = _temporaryDirectory();
      await directory.create(recursive: true);
      final copy = File(p.join(
        directory.path,
        'edunivora_summary_' + _now().microsecondsSinceEpoch.toString() + '.pdf',
      ));
      try {
        await source.copy(copy.path);
        final text = (await _reader(copy, maxCharacters: maxCharacters)).trim();
        if (text.isEmpty) {
          return const PdfTextExtractionResult(status: PdfTextExtractionStatus.noExtractableText);
        }
        return PdfTextExtractionResult(status: PdfTextExtractionStatus.success, text: text);
      } finally {
        try {
          if (await copy.exists()) await copy.delete();
        } on FileSystemException {
          // The source document is never deleted here.
        }
      }
    } on FileSystemException {
      return const PdfTextExtractionResult(status: PdfTextExtractionStatus.failed);
    } catch (_) {
      return const PdfTextExtractionResult(status: PdfTextExtractionStatus.failed);
    }
  }

  static Future<String> _readPdfPages(File file, {required int maxCharacters}) async {
    final document = await PDFDoc.fromFile(file);
    try {
      final output = StringBuffer();
      for (var pageNumber = 1;
          pageNumber <= document.length && output.length < maxCharacters;
          pageNumber++) {
        final pageText = await document.pageAt(pageNumber).text;
        final remaining = maxCharacters - output.length;
        output.write(pageText.length > remaining ? pageText.substring(0, remaining) : pageText);
        output.write('\n');
      }
      return output.toString();
    } finally {
      document.deleteFile();
    }
  }
}
