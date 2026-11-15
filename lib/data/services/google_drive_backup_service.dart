import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Google Drive v3 client. Only encrypted archive bytes may be passed here.
class GoogleDriveBackupService {
  GoogleDriveBackupService({required Future<String?> Function() accessTokenProvider, http.Client? client})
      : _accessTokenProvider = accessTokenProvider, _client = client ?? http.Client();

  static const String driveFileScope = 'https://www.googleapis.com/auth/drive.file';
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
    const query = "name = 'EduNivora' and mimeType = '$_folderMimeType' and trashed = false";
    final uri = Uri.parse('$_apiBase/files').replace(queryParameters: {
      'q': query, 'spaces': 'drive', 'pageSize': '100',
      'fields': 'files(id,name,mimeType,createdTime)', 'orderBy': 'createdTime',
    });
    final response = await _client.get(uri, headers: _headers(token));
    _expectStatus(response, const {200}, 'تعذر البحث عن مجلد النسخ في Google Drive');
    final files = _decodeObject(response.body)['files'];
    if (files is List) {
      for (final item in files.whereType<Map>()) {
        if (item['id'] is String && item['name'] == 'EduNivora') return item['id'] as String;
      }
    }
    final createdResponse = await _client.post(
      Uri.parse('$_apiBase/files').replace(queryParameters: {'fields': 'id,name,mimeType,createdTime'}),
      headers: {..._headers(token), 'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'name': 'EduNivora', 'mimeType': _folderMimeType}),
    );
    _expectStatus(createdResponse, const {200, 201}, 'تعذر إنشاء مجلد EduNivora في Google Drive');
    final id = _decodeObject(createdResponse.body)['id'];
    if (id is! String || id.isEmpty) throw const FormatException('استجابة Google Drive لا تحتوي معرف المجلد.');
    return id;
  }

  Future<String> uploadEncryptedArchive({required Uint8List archive, required String fileName, required String folderId}) async {
    if (archive.isEmpty || archive.length > _maxArchiveBytes) throw const FormatException('حجم النسخة المشفرة غير صالح أو يتجاوز 80 MB.');
    if (fileName.trim().isEmpty || fileName.contains('/') || fileName.contains(r'\') || !fileName.endsWith('.edunivora')) {
      throw const FormatException('اسم ملف النسخة غير صالح.');
    }
    if (folderId.trim().isEmpty) throw const FormatException('معرف مجلد Google Drive مطلوب.');
    final token = await _requireToken();
    final sessionResponse = await _client.post(
      Uri.parse('$_uploadBase/files').replace(queryParameters: {'uploadType': 'resumable', 'fields': 'id,name,size,mimeType,createdTime,parents'}),
      headers: {
        ..._headers(token), 'Content-Type': 'application/json; charset=utf-8',
        'X-Upload-Content-Type': 'application/octet-stream',
        'X-Upload-Content-Length': archive.length.toString(),
      },
      body: jsonEncode({
        'name': fileName, 'mimeType': 'application/octet-stream', 'parents': [folderId],
        'appProperties': {'edunivoraBackup': 'true', 'backupFormat': 'edunivora_encrypted_backup_v1'},
      }),
    );
    _expectStatus(sessionResponse, const {200, 201}, 'تعذر بدء الرفع المتدرج إلى Google Drive');
    final location = sessionResponse.headers['location'];
    final sessionUri = location == null ? null : Uri.tryParse(location);
    if (sessionUri == null || sessionUri.scheme != 'https' || sessionUri.host != 'www.googleapis.com') {
      throw const FormatException('رابط جلسة الرفع من Google Drive غير موثوق.');
    }

    var offset = 0;
    while (offset < archive.length) {
      final endExclusive = (offset + _chunkSize < archive.length) ? offset + _chunkSize : archive.length;
      final chunk = archive.sublist(offset, endExclusive);
      final response = await _client.put(sessionUri, headers: {
        'Authorization': 'Bearer ' + token, 'Content-Type': 'application/octet-stream',
        'Content-Length': chunk.length.toString(),
        'Content-Range': 'bytes ' + offset.toString() + '-' + (endExclusive - 1).toString() + '/' + archive.length.toString(),
      }, body: chunk);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final id = _decodeObject(response.body)['id'];
        if (id is! String || id.isEmpty) throw const FormatException('اكتمل الرفع دون إرجاع معرف الملف.');
        return id;
      }
      if (response.statusCode != 308) _throwDriveError(response, 'فشل رفع النسخة المشفرة');
      final acceptedRange = response.headers['range'];
      if (acceptedRange == null) throw const FormatException('لم يؤكد Google Drive أي بايتات مستلمة؛ أوقفنا الرفع بأمان.');
      final match = RegExp(r'^bytes=0-(\d+)$').firstMatch(acceptedRange);
      if (match == null) throw const FormatException('أرسل Google Drive نطاق رفع غير صالح.');
      final nextOffset = int.parse(match.group(1)!) + 1;
      if (nextOffset <= offset || nextOffset > archive.length) throw const FormatException('أرسل Google Drive تقدماً غير صالح للرفع.');
      offset = nextOffset;
    }
    throw const FormatException('انتهى الرفع دون تأكيد اكتمال الملف.');
  }

  Future<Uint8List> downloadArchive(String fileId) async {
    if (fileId.trim().isEmpty) throw const FormatException('معرف ملف النسخة مطلوب.');
    final token = await _requireToken();
    final uri = Uri.parse(_apiBase + '/files/' + Uri.encodeComponent(fileId)).replace(queryParameters: {'alt': 'media'});
    final response = await _client.get(uri, headers: _headers(token));
    _expectStatus(response, const {200}, 'تعذر تنزيل النسخة من Google Drive');
    if (response.bodyBytes.isEmpty || response.bodyBytes.length > _maxArchiveBytes) throw const FormatException('حجم ملف النسخة المسترجعة غير صالح.');
    return Uint8List.fromList(response.bodyBytes);
  }

  Future<List<Map<String, dynamic>>> listBackups(String folderId) async {
    if (folderId.trim().isEmpty) throw const FormatException('معرف مجلد النسخ مطلوب.');
    final token = await _requireToken();
    final escapedFolderId = folderId.replaceAll("'", r"\'");
    final query = "'" + escapedFolderId + "' in parents and trashed = false";
    final uri = Uri.parse('$_apiBase/files').replace(queryParameters: {
      'q': query, 'spaces': 'drive', 'pageSize': '100', 'orderBy': 'createdTime desc',
      'fields': 'files(id,name,mimeType,size,createdTime,appProperties)',
    });
    final response = await _client.get(uri, headers: _headers(token));
    _expectStatus(response, const {200}, 'تعذر جلب قائمة النسخ من Google Drive');
    final files = _decodeObject(response.body)['files'];
    if (files is! List) return const [];
    return files.whereType<Map>().map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['id'] is String && item['name'] is String && (item['name'] as String).endsWith('.edunivora'))
        .toList(growable: false);
  }

  Future<String> _requireToken() async {
    final token = await _accessTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const GoogleDriveAuthorizationException('يلزم ربط حساب Google ومنح صلاحية drive.file للنسخ الاحتياطي.');
    }
    return token;
  }

  Map<String, String> _headers(String token) => {'Authorization': 'Bearer ' + token, 'Accept': 'application/json'};

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) throw const FormatException('استجابة Google Drive غير صالحة.');
    return decoded;
  }

  void _expectStatus(http.Response response, Set<int> accepted, String message) {
    if (!accepted.contains(response.statusCode)) _throwDriveError(response, message);
  }

  Never _throwDriveError(http.Response response, String message) {
    var detail = '';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is Map) {
        final error = decoded['error'] as Map;
        detail = error['message'] is String ? error['message'] as String : '';
      }
    } catch (_) {}
    throw GoogleDriveApiException(message + ' (HTTP ' + response.statusCode.toString() + ')' + (detail.isEmpty ? '' : ': ' + detail), response.statusCode);
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
