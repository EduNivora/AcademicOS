import '../services/local_summarizer_service.dart';
import 'pdf_text_extraction_service.dart';

enum DocumentSummaryStatus {
  success, fileMissing, emptyFile, unsupportedFormat, tooLarge, noExtractableText, failed,
}

class DocumentSummaryResult {
  final DocumentSummaryStatus status;
  final Summary? summary;
  const DocumentSummaryResult({required this.status, this.summary});
  bool get isSuccess => status == DocumentSummaryStatus.success && summary != null;
}

class DocumentSummaryService {
  final PdfTextExtractionService _extractor;
  final LocalSummarizerService _summarizer;

  DocumentSummaryService({
    PdfTextExtractionService? extractor,
    LocalSummarizerService? summarizer,
  })  : _extractor = extractor ?? PdfTextExtractionService(),
        _summarizer = summarizer ?? LocalSummarizerService.instance;

  Future<DocumentSummaryResult> summarizePdf(String filePath) async {
    final extraction = await _extractor.extract(filePath);
    if (!extraction.isSuccess) {
      return DocumentSummaryResult(
        status: switch (extraction.status) {
          PdfTextExtractionStatus.fileMissing => DocumentSummaryStatus.fileMissing,
          PdfTextExtractionStatus.emptyFile => DocumentSummaryStatus.emptyFile,
          PdfTextExtractionStatus.unsupportedFormat => DocumentSummaryStatus.unsupportedFormat,
          PdfTextExtractionStatus.tooLarge => DocumentSummaryStatus.tooLarge,
          PdfTextExtractionStatus.noExtractableText => DocumentSummaryStatus.noExtractableText,
          PdfTextExtractionStatus.failed => DocumentSummaryStatus.failed,
          PdfTextExtractionStatus.success => DocumentSummaryStatus.failed,
        },
      );
    }
    try {
      final summary = await _summarizer.summarize(extraction.text);
      if (summary.quickSummary.trim().isEmpty) {
        return const DocumentSummaryResult(status: DocumentSummaryStatus.noExtractableText);
      }
      return DocumentSummaryResult(status: DocumentSummaryStatus.success, summary: summary);
    } catch (_) {
      return const DocumentSummaryResult(status: DocumentSummaryStatus.failed);
    }
  }
}
