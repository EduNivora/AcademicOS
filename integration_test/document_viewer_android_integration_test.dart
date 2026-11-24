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
          home: DocumentViewerScreen(
            filePath: file.path,
            title: 'integration.pdf',
          ),
        ),
      );
      for (var attempt = 0; attempt < 40; attempt++) {
        await tester.pump(const Duration(milliseconds: 250));
        if (find.text('1 / 1').evaluate().isNotEmpty) break;
      }
      expect(find.text('1 / 1'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle(const Duration(milliseconds: 250));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await file.exists(), isFalse);
    },
  );

  testWidgets(
    'Android Office handoff returns a typed status and preserves launched file',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      final bytes = Uint8List.fromList([0x50, 0x4b, 0x03, 0x04]);
      final root = await Directory.systemTemp.createTemp(
        'edunivora-office-intent-',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final service = CourseMaterialFileService(
        loadBytes: (_) async => bytes,
        temporaryDirectory: () async => root,
      );
      final status = await service.openOfficeExternally(
        materialId: 22,
        title: 'intent-check.docx',
        fileType: 'docx',
      );
      expect(
        status,
        anyOf(
          ExternalMaterialOpenStatus.opened,
          ExternalMaterialOpenStatus.noApp,
        ),
      );
      final files = Directory(root.path + '/edunivora_materials');
      if (status == ExternalMaterialOpenStatus.opened) {
        expect(files.listSync().whereType<File>(), isNotEmpty);
      } else {
        expect(files.listSync().whereType<File>(), isEmpty);
      }
    },
  );
}
