import 'dart:convert';

import '../../core/config/edunivora_api_config.dart';
import '../../core/network/platform_http_client.dart';

class AdminAnnouncementsException implements Exception {
  final int statusCode;
  final String message;

  const AdminAnnouncementsException(this.statusCode, this.message);

  @override
  String toString() => 'AdminAnnouncementsException($statusCode): $message';
}

class AdminAnnouncementsDataSource {
  final PlatformHttpRequest _request;
  final String _baseUrl;

  AdminAnnouncementsDataSource({
    PlatformHttpRequest? request,
    String baseUrl = EdunivoraApiConfig.noticesBaseUrl,
  })  : _request = request ?? platformRequest,
        _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  Future<Map<String, dynamic>> _call(
    String path, {
    required String method,
    required String accessToken,
    Map<String, dynamic>? body,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    if (body != null) headers['Content-Type'] = 'application/json';
    final response = await _request(
      Uri.parse('$_baseUrl$path'),
      method: method,
      headers: headers,
      body: body == null ? null : jsonEncode(body),
      withCredentials: false,
    ).timeout(const Duration(seconds: 15));

    Object? decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      throw const FormatException('Invalid response from announcements API.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'The announcements request failed.';
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          message = error['message'] as String;
        } else if (decoded['message'] is String) {
          message = decoded['message'] as String;
        }
      }
      throw AdminAnnouncementsException(response.statusCode, message);
    }
    if (decoded == null) return <String, dynamic>{};
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected announcements API response.');
    }
    return decoded;
  }

  Future<List<Map<String, dynamic>>> list({
    required String accessToken,
    String? status,
  }) async {
    final query = status == null ? '' : '?status=$status';
    final response = await _call(
      '/v1/admin/announcements$query',
      method: 'GET',
      accessToken: accessToken,
    );
    final items = response['items'];
    if (items is! List) {
      throw const FormatException('Unexpected admin announcements list.');
    }
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> create({
    required String accessToken,
    required String title,
    required String body,
  }) async {
    final response = await _call(
      '/v1/admin/announcements',
      method: 'POST',
      accessToken: accessToken,
      body: {'title': title, 'body': body},
    );
    return Map<String, dynamic>.from(response['item'] as Map);
  }

  Future<Map<String, dynamic>> update({
    required String accessToken,
    required String id,
    required String title,
    required String body,
  }) async {
    final response = await _call(
      '/v1/admin/announcements/$id',
      method: 'PATCH',
      accessToken: accessToken,
      body: {'title': title, 'body': body},
    );
    return Map<String, dynamic>.from(response['item'] as Map);
  }

  Future<void> publish({
    required String accessToken,
    required String id,
  }) async {
    await _call(
      '/v1/admin/announcements/$id/publish',
      method: 'POST',
      accessToken: accessToken,
      body: const <String, dynamic>{},
    );
  }

  Future<void> archive({
    required String accessToken,
    required String id,
  }) async {
    await _call(
      '/v1/admin/announcements/$id/archive',
      method: 'POST',
      accessToken: accessToken,
      body: const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> report({
    required String accessToken,
    required String id,
  }) async {
    final response = await _call(
      '/v1/admin/announcements/$id/report',
      method: 'GET',
      accessToken: accessToken,
    );
    return Map<String, dynamic>.from(response['report'] as Map);
  }
}
