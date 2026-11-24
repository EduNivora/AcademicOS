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
      service().preparePdfForViewing(materialId: 1, title: 'lecture.docx', fileType: 'docx'),
      throwsA(isA<UnsupportedMaterialFormatException>()),
    );
    await expectLater(
      service().openOfficeExternally(materialId: 1, title: 'lecture.exe', fileType: 'exe'),
      throwsA(isA<UnsupportedMaterialFormatException>()),
    );
  });

  test('rejects missing, empty, oversized and invalid PDF bytes', () async {
    final missing = CourseMaterialFileService(
      loadBytes: (_) async => null,
      temporaryDirectory: () async => root,
    );
    await expectLater(missing.loadMaterialBytes(1), throwsA(isA<MaterialFileUnavailableException>()));
    await expectLater(
      service(bytes: Uint8List(0)).loadMaterialBytes(1),
      throwsA(isA<MaterialFileUnavailableException>()),
    );
    await expectLater(
      service(bytes: Uint8List(1025)).loadMaterialBytes(1),
      throwsA(isA<MaterialFileUnavailableException>()),
    );
    await expectLater(
      service(bytes: Uint8List.fromList([1, 2, 3])).preparePdfForViewing(
        materialId: 1, title: 'bad.pdf', fileType: 'pdf',
      ),
      throwsA(isA<MaterialFileUnavailableException>()),
    );
  });

  test('keeps Office files available after the external activity is launched', () async {
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
      materialId: 9, title: 'lecture.docx', fileType: 'docx',
    );
    expect(status, ExternalMaterialOpenStatus.opened);
    expect(openedPath, isNotNull);
    expect(await File(openedPath!).exists(), isTrue);
  });

  test('removes a temporary Office file when no compatible application exists', () async {
    String? openedPath;
    final fileService = service(
      bytes: Uint8List.fromList([0x50, 0x4b, 0x03, 0x04]),
      opener: (path) async {
        openedPath = path;
        return ExternalMaterialOpenStatus.noApp;
      },
    );
    final status = await fileService.openOfficeExternally(
      materialId: 10, title: 'slides.pptx', fileType: 'pptx',
    );
    expect(status, ExternalMaterialOpenStatus.noApp);
    expect(await File(openedPath!).exists(), isFalse);
  });
}
