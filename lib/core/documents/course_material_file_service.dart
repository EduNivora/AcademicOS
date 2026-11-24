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
typedef ExternalMaterialOpener = Future<ExternalMaterialOpenStatus> Function(String path);

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
  })  : _loadBytes = loadBytes ?? DatabaseHelper.instance.getMaterialFileBytes,
        _temporaryDirectory = temporaryDirectory ?? _defaultTemporaryDirectory,
        _openExternal = openExternal ?? _openWithPlatform,
        _now = now ?? DateTime.now;

  static Future<Directory> _defaultTemporaryDirectory() async => Directory.systemTemp;

  Future<Uint8List> loadMaterialBytes(int materialId) async {
    if (materialId <= 0) {
      throw const MaterialFileUnavailableException('معرّف المرفق غير صالح.');
    }
    final bytes = await _loadBytes(materialId);
    if (bytes == null || bytes.isEmpty) {
      throw const MaterialFileUnavailableException('محتوى الملف غير موجود في التخزين المحلي.');
    }
    if (bytes.length > maxFileBytes) {
      throw const MaterialFileUnavailableException('حجم الملف يتجاوز الحد المسموح (50 MB).');
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
      throw const MaterialFileUnavailableException('الملف لا يحتوي على ترويسة PDF صالحة أو أنه تالف.');
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
    final extension = _validatedExtension(title, fileType, const {'doc', 'docx', 'ppt', 'pptx'});
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

  String _validatedExtension(String title, String fileType, Set<String> allowed) {
    final extension = p.extension(title).replaceFirst('.', '').toLowerCase();
    final declared = fileType.replaceFirst(RegExp(r'^\.'), '').toLowerCase();
    if (extension.isEmpty || extension != declared || !allowed.contains(extension)) {
      throw const UnsupportedMaterialFormatException('صيغة الملف غير مدعومة أو لا تطابق نوع المرفق المسجل.');
    }
    return extension;
  }

  void _validatePayload(Uint8List bytes) {
    if (bytes.isEmpty) throw const MaterialFileUnavailableException('الملف فارغ.');
    if (bytes.length > maxFileBytes) {
      throw const MaterialFileUnavailableException('حجم الملف يتجاوز الحد المسموح (50 MB).');
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

    final safeName = p.basename(title)
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final timestamp = _now().microsecondsSinceEpoch;
    final fileName = 'material_' + materialId.toString() + '_' +
        timestamp.toString() + '_' + safeName;
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _cleanupExpiredExternalFiles(Directory directory) async {
    final cutoff = _now().subtract(externalFileRetention);
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !p.basename(entity.path).startsWith('material_')) continue;
        try {
          if ((await entity.lastModified()).isBefore(cutoff)) await entity.delete();
        } on FileSystemException {
          // External applications may still hold a file open.
        }
      }
    } on FileSystemException {
      // A later file creation will retry cleanup.
    }
  }

  static Future<ExternalMaterialOpenStatus> _openWithPlatform(String path) async {
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
