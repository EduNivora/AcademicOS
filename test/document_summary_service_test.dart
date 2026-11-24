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

  test('summarizes extracted text locally without requiring the viewer', () async {
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
  });

  test('does not fabricate a summary when the PDF has no extractable text', () async {
    final service = DocumentSummaryService(
      extractor: PdfTextExtractionService(
        temporaryDirectory: () => root,
        reader: (_, {required maxCharacters}) async => '',
      ),
    );
    final result = await service.summarizePdf(source.path);
    expect(result.status, DocumentSummaryStatus.noExtractableText);
    expect(result.summary, isNull);
  });
}
