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
