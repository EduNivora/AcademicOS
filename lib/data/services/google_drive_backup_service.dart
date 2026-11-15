import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Minimal Google Drive v3 client for student-owned encrypted backup archives.
///
/// The caller is responsible for obtaining a short-lived OAuth access token
/// with the `drive.file` scope. This service never receives a password or
/// plaintext academic payload; callers must pass an already encrypted archive.
class GoogleDriveBackupService {
  GoogleDriveBackupService({
    required Future<String?> Function() accessTokenProvider,
    http.Client? client,
  })  : _accessTokenProvider = accessTokenProvider,
        _client = client ?? http.Client();

  static const String driveFileScope =
      'https://www.googleapis.com/auth/drive.file';
  static const String _apiBase = 'https://www.googleapis.com/drive/v3';
  static const String _uploadBase = 'https://www.googleapis.com/upload/drive/v3';
  static const String _folderMimeType = 'application/vnd.google-apps.folder';
  static const int _chunkSize = 8 * 1024 * 1024;
  static const int _maxArchiveBytes = 80 * 1024 * 1024;

  final Future<String?> Function() _accessTokenProvider;
  final http.Client _client;

  void close() => _client.close();

  Future<String> ensureBackupFolder() async {
    final token = await _requireToken();
    final query = "name = 'EduNivora' and mimeType = '$_folderMimeType' and trashed = false";
    final listUri = Uri.parse('$_apiBase/files').replace(queryParameters: {
      'q': query,
      'spaces': 'drive',
      'pageSize': '100',
      'fields': 'files(id,name,mimeType,createdTime)',
      'orderBy': 'createdTime',
    });
    final response = await _client.get(
      listUri,
      headers: _headers(token),
    );
    _expectStatus(response, const {200}, 'تعذر البحث عن مجلد النسخ في Google Drive');
    final body = _decodeObject(response.body);
    final files = body['files'];
    if (files is List) {
      for (final item in files) {
        if (item is Map && item['id'] is String && item['name'] == 'EduNivora') {
          return item['id'] as String;
        }
      }
    }

    final createResponse = await _client.post(
      Uri.parse('$_apiBase/files').replace(queryParameters: {
        'fields': 'id,name,mimeType,createdTime',
      }),
      headers: {
        ..._headers(token),
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'name': 'EduNivora',
        'mimeType': _folderMimeType,
      }),
    );
    _expectStatus(
      createResponse,
      const {200},
      'تعذر إنشاء مجلد EduNivora في Google Drive',
    );
    final created = _decodeObject(createResponse.body);
    final id = created['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('استجابة Google Drive لا تحتوي معرف المجلد.');
    }
    return id;
  }

  Future<String> uploadEncryptedArchive({
    required Uint8List archive,
    required String fileName,
    required String folderId,
  }) async {
    if (archive.isEmpty || archive.length > _maxArchiveBytes) {
      throw const FormatException('حجم النسخة المشفرة غير صالح أو يتجاوز 80 MB.');
    }
    if (fileName.trim().isEmpty || fileName.contains('/') || fileName.contains(r'\')) {
      throw const FormatException('اسم ملف النسخة غير صالح.');
    }
    if (folderId.trim().isEmpty) {
      throw const FormatException('معرف مجلد Google Drive مطلوب.');
    }

    final token = await _requireToken();
    final metadata = jsonEncode({
      'name': fileName,
      'mimeType': 'application/octet-stream',
      'parents': [folderId],
      'appProperties': {
        'edunivoraBackup': 'true',
        'backupFormat': 'edunivora_encrypted_backup_v1',
      },
    });
    final sessionResponse = await _client.post(
      Uri.parse('$_uploadBase/files').replace(queryParameters: {
        'uploadType': 'resumable',
        'fields': 'id,name,size,mimeType,createdTime,parents',
      }),
      headers: {
        ..._headers(token),
        'Content-Type': 'application/json; charset=utf-8',
        'X-Upload-Content-Type': 'application/octet-stream',
        'X-Upload-Content-Length': archive.length.toString(),
      },
      body: metadata,
    );
    _expectStatus(
      sessionResponse,
      const {200, 201},
      'تعذر بدء الرفع المتدرج إلى Google Drive',
    );
    final location = sessionResponse.headers['location'];
    if (location == null || location.isEmpty) {
      throw const FormatException('لم يُرجع Google Drive رابط جلسة الرفع.');
    }
    final sessionUri = Uri.tryParse(location);
    if (sessionUri == null ||
        (sessionUri.scheme != 'https' || sessionUri.host != 'www.googleapis.com')) {
      throw const FormatException('رابط جلسة الرفع من Google Drive غير موثوق.');
    }

    var offset = 0;
    while (offset < archive.length) {
      final endExclusive = (offset + _chunkSize < archive.length)
          ? offset + _chunkSize
          : archive.length;
      final chunk = archive.sublist(offset, endExclusive);
      final response = await _client.put(
        sessionUri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/octet-stream',
          'Content-Length': chunk.length.toString(),
          'Content-Range': 'bytes $offset-${endExclusive - 1}/${archive.length}',
        },
        body: chunk,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = _decodeObject(response.body);
        final id = result['id'];
        if (id is! String || id.isEmpty) {
          throw const FormatException('اكتمل الرفع دون إرجاع معرف الملف.');
        }
        return id;
      }
      if (response.statusCode != 308) {
        _throwDriveError(response, 'فشل رفع النسخة المشفرة');
      }

      final acceptedRange = response.headers['range'];
      if (acceptedRange == null) {
        throw const FormatException(
          'لم يؤكد Google Drive أي بايتات مستلمة؛ أوقفنا الرفع لتجنب إعادة إرسال غير محدودة.',
        );
      }
      final match = RegExp(r'^bytes=0-(\d+)
      if (offset > archive.length) {
        throw const FormatException('تجاوز تقدم الرفع حجم ملف النسخة.');
      }
    }
    throw const FormatException('انتهى الرفع دون تأكيد اكتمال الملف.');
  }

  Future<Uint8List> downloadArchive(String fileId) async {
    if (fileId.trim().isEmpty) {
      throw const FormatException('معرف ملف النسخة مطلوب.');
    }
    final token = await _requireToken();
    final uri = Uri.parse('$_apiBase/files/${Uri.encodeComponent(fileId)}')
        .replace(queryParameters: {'alt': 'media'});
    final response = await _client.get(uri, headers: _headers(token));
    _expectStatus(response, const {200}, 'تعذر تنزيل النسخة من Google Drive');
    if (response.bodyBytes.isEmpty || response.bodyBytes.length > _maxArchiveBytes) {
      throw const FormatException('حجم ملف النسخة المسترجعة غير صالح.');
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  Future<List<Map<String, dynamic>>> listBackups(String folderId) async {
    if (folderId.trim().isEmpty) {
      throw const FormatException('معرف مجلد النسخ مطلوب.');
    }
    final token = await _requireToken();
    final query = "'${folderId.replaceAll("'", r"\'")}' in parents and trashed = false";
    final uri = Uri.parse('$_apiBase/files').replace(queryParameters: {
      'q': query,
      'spaces': 'drive',
      'pageSize': '100',
      'orderBy': 'createdTime desc',
      'fields': 'files(id,name,mimeType,size,createdTime,appProperties)',
    });
    final response = await _client.get(uri, headers: _headers(token));
    _expectStatus(response, const {200}, 'تعذر جلب قائمة النسخ من Google Drive');
    final files = _decodeObject(response.body)['files'];
    if (files is! List) return const [];
    return files
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) =>
            item['id'] is String &&
            item['name'] is String &&
            (item['name'] as String).endsWith('.edunivora'))
        .toList(growable: false);
  }

  Future<String> _requireToken() async {
    final token = await _accessTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const GoogleDriveAuthorizationException(
        'يلزم ربط حساب Google ومنح صلاحية drive.file للنسخ الاحتياطي.',
      );
    }
    return token;
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('استجابة Google Drive غير صالحة.');
    }
    return decoded;
  }

  void _expectStatus(
    http.Response response,
    Set<int> accepted,
    String message,
  ) {
    if (!accepted.contains(response.statusCode)) {
      _throwDriveError(response, message);
    }
  }

  Never _throwDriveError(http.Response response, String message) {
    var detail = '';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is Map) {
        final error = decoded['error'] as Map;
        detail = error['message'] is String ? error['message'] as String : '';
      }
    } catch (_) {
      // Do not surface arbitrary response bodies or credentials.
    }
    throw GoogleDriveApiException(
      '$message (HTTP ${response.statusCode})${detail.isEmpty ? '' : ': $detail'}',
      response.statusCode,
    );
  }
}

class GoogleDriveAuthorizationException implements Exception {
  const GoogleDriveAuthorizationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class GoogleDriveApiException implements Exception {
  const GoogleDriveApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
).firstMatch(acceptedRange);
        if (match == null) {
          throw const FormatException('أرسل Google Drive نطاق رفع غير صالح.');
        }
        offset = int.parse(match.group(1)!) + 1;
      }
      if (offset > archive.length) {
        throw const FormatException('تجاوز تقدم الرفع حجم ملف النسخة.');
      }
    }
    throw const FormatException('انتهى الرفع دون تأكيد اكتمال الملف.');
  }

  Future<Uint8List> downloadArchive(String fileId) async {
    if (fileId.trim().isEmpty) {
      throw const FormatException('معرف ملف النسخة مطلوب.');
    }
    final token = await _requireToken();
    final uri = Uri.parse('$_apiBase/files/${Uri.encodeComponent(fileId)}')
        .replace(queryParameters: {'alt': 'media'});
    final response = await _client.get(uri, headers: _headers(token));
    _expectStatus(response, const {200}, 'تعذر تنزيل النسخة من Google Drive');
    if (response.bodyBytes.isEmpty || response.bodyBytes.length > _maxArchiveBytes) {
      throw const FormatException('حجم ملف النسخة المسترجعة غير صالح.');
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  Future<List<Map<String, dynamic>>> listBackups(String folderId) async {
    if (folderId.trim().isEmpty) {
      throw const FormatException('معرف مجلد النسخ مطلوب.');
    }
    final token = await _requireToken();
    final query = "'${folderId.replaceAll("'", r"\\'")}' in parents and trashed = false";
    final uri = Uri.parse('$_apiBase/files').replace(queryParameters: {
      'q': query,
      'spaces': 'drive',
      'pageSize': '100',
      'orderBy': 'createdTime desc',
      'fields': 'files(id,name,mimeType,size,createdTime,appProperties)',
    });
    final response = await _client.get(uri, headers: _headers(token));
    _expectStatus(response, const {200}, 'تعذر جلب قائمة النسخ من Google Drive');
    final files = _decodeObject(response.body)['files'];
    if (files is! List) return const [];
    return files
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) =>
            item['id'] is String &&
            item['name'] is String &&
            (item['name'] as String).endsWith('.edunivora'))
        .toList(growable: false);
  }

  Future<String> _requireToken() async {
    final token = await _accessTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const GoogleDriveAuthorizationException(
        'يلزم ربط حساب Google ومنح صلاحية drive.file للنسخ الاحتياطي.',
      );
    }
    return token;
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('استجابة Google Drive غير صالحة.');
    }
    return decoded;
  }

  void _expectStatus(
    http.Response response,
    Set<int> accepted,
    String message,
  ) {
    if (!accepted.contains(response.statusCode)) {
      _throwDriveError(response, message);
    }
  }

  Never _throwDriveError(http.Response response, String message) {
    var detail = '';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is Map) {
        final error = decoded['error'] as Map;
        detail = error['message'] is String ? error['message'] as String : '';
      }
    } catch (_) {
      // Do not surface arbitrary response bodies or credentials.
    }
    throw GoogleDriveApiException(
      '$message (HTTP ${response.statusCode})${detail.isEmpty ? '' : ': $detail'}',
      response.statusCode,
    );
  }
}

class GoogleDriveAuthorizationException implements Exception {
  const GoogleDriveAuthorizationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class GoogleDriveApiException implements Exception {
  const GoogleDriveApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
).firstMatch(acceptedRange);
      if (match == null) {
        throw const FormatException('أرسل Google Drive نطاق رفع غير صالح.');
      }
      offset = int.parse(match.group(1)!) + 1;
      if (offset > archive.length) {
        throw const FormatException('تجاوز تقدم الرفع حجم ملف النسخة.');
      }
    }
    throw const FormatException('انتهى الرفع دون تأكيد اكتمال الملف.');
  }

  Future<Uint8List> downloadArchive(String fileId) async {
    if (fileId.trim().isEmpty) {
      throw const FormatException('معرف ملف النسخة مطلوب.');
    }
    final token = await _requireToken();
    final uri = Uri.parse('$_apiBase/files/${Uri.encodeComponent(fileId)}')
        .replace(queryParameters: {'alt': 'media'});
    final response = await _client.get(uri, headers: _headers(token));
    _expectStatus(response, const {200}, 'تعذر تنزيل النسخة من Google Drive');
    if (response.bodyBytes.isEmpty || response.bodyBytes.length > _maxArchiveBytes) {
      throw const FormatException('حجم ملف النسخة المسترجعة غير صالح.');
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  Future<List<Map<String, dynamic>>> listBackups(String folderId) async {
    if (folderId.trim().isEmpty) {
      throw const FormatException('معرف مجلد النسخ مطلوب.');
    }
    final token = await _requireToken();
    final query = "'${folderId.replaceAll("'", r"\'")}' in parents and trashed = false";
    final uri = Uri.parse('$_apiBase/files').replace(queryParameters: {
      'q': query,
      'spaces': 'drive',
      'pageSize': '100',
      'orderBy': 'createdTime desc',
      'fields': 'files(id,name,mimeType,size,createdTime,appProperties)',
    });
    final response = await _client.get(uri, headers: _headers(token));
    _expectStatus(response, const {200}, 'تعذر جلب قائمة النسخ من Google Drive');
    final files = _decodeObject(response.body)['files'];
    if (files is! List) return const [];
    return files
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) =>
            item['id'] is String &&
            item['name'] is String &&
            (item['name'] as String).endsWith('.edunivora'))
        .toList(growable: false);
  }

  Future<String> _requireToken() async {
    final token = await _accessTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const GoogleDriveAuthorizationException(
        'يلزم ربط حساب Google ومنح صلاحية drive.file للنسخ الاحتياطي.',
      );
    }
    return token;
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('استجابة Google Drive غير صالحة.');
    }
    return decoded;
  }

  void _expectStatus(
    http.Response response,
    Set<int> accepted,
    String message,
  ) {
    if (!accepted.contains(response.statusCode)) {
      _throwDriveError(response, message);
    }
  }

  Never _throwDriveError(http.Response response, String message) {
    var detail = '';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is Map) {
        final error = decoded['error'] as Map;
        detail = error['message'] is String ? error['message'] as String : '';
      }
    } catch (_) {
      // Do not surface arbitrary response bodies or credentials.
    }
    throw GoogleDriveApiException(
      '$message (HTTP ${response.statusCode})${detail.isEmpty ? '' : ': $detail'}',
      response.statusCode,
    );
  }
}

class GoogleDriveAuthorizationException implements Exception {
  const GoogleDriveAuthorizationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class GoogleDriveApiException implements Exception {
  const GoogleDriveApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
).firstMatch(acceptedRange);
        if (match == null) {
          throw const FormatException('أرسل Google Drive نطاق رفع غير صالح.');
        }
        offset = int.parse(match.group(1)!) + 1;
      }
      if (offset > archive.length) {
        throw const FormatException('تجاوز تقدم الرفع حجم ملف النسخة.');
      }
    }
    throw const FormatException('انتهى الرفع دون تأكيد اكتمال الملف.');
  }

  Future<Uint8List> downloadArchive(String fileId) async {
    if (fileId.trim().isEmpty) {
      throw const FormatException('معرف ملف النسخة مطلوب.');
    }
    final token = await _requireToken();
    final uri = Uri.parse('$_apiBase/files/${Uri.encodeComponent(fileId)}')
        .replace(queryParameters: {'alt': 'media'});
    final response = await _client.get(uri, headers: _headers(token));
    _expectStatus(response, const {200}, 'تعذر تنزيل النسخة من Google Drive');
    if (response.bodyBytes.isEmpty || response.bodyBytes.length > _maxArchiveBytes) {
      throw const FormatException('حجم ملف النسخة المسترجعة غير صالح.');
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  Future<List<Map<String, dynamic>>> listBackups(String folderId) async {
    if (folderId.trim().isEmpty) {
      throw const FormatException('معرف مجلد النسخ مطلوب.');
    }
    final token = await _requireToken();
    final query = "'${folderId.replaceAll("'", r"\\'")}' in parents and trashed = false";
    final uri = Uri.parse('$_apiBase/files').replace(queryParameters: {
      'q': query,
      'spaces': 'drive',
      'pageSize': '100',
      'orderBy': 'createdTime desc',
      'fields': 'files(id,name,mimeType,size,createdTime,appProperties)',
    });
    final response = await _client.get(uri, headers: _headers(token));
    _expectStatus(response, const {200}, 'تعذر جلب قائمة النسخ من Google Drive');
    final files = _decodeObject(response.body)['files'];
    if (files is! List) return const [];
    return files
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) =>
            item['id'] is String &&
            item['name'] is String &&
            (item['name'] as String).endsWith('.edunivora'))
        .toList(growable: false);
  }

  Future<String> _requireToken() async {
    final token = await _accessTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const GoogleDriveAuthorizationException(
        'يلزم ربط حساب Google ومنح صلاحية drive.file للنسخ الاحتياطي.',
      );
    }
    return token;
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('استجابة Google Drive غير صالحة.');
    }
    return decoded;
  }

  void _expectStatus(
    http.Response response,
    Set<int> accepted,
    String message,
  ) {
    if (!accepted.contains(response.statusCode)) {
      _throwDriveError(response, message);
    }
  }

  Never _throwDriveError(http.Response response, String message) {
    var detail = '';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is Map) {
        final error = decoded['error'] as Map;
        detail = error['message'] is String ? error['message'] as String : '';
      }
    } catch (_) {
      // Do not surface arbitrary response bodies or credentials.
    }
    throw GoogleDriveApiException(
      '$message (HTTP ${response.statusCode})${detail.isEmpty ? '' : ': $detail'}',
      response.statusCode,
    );
  }
}

class GoogleDriveAuthorizationException implements Exception {
  const GoogleDriveAuthorizationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class GoogleDriveApiException implements Exception {
  const GoogleDriveApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
