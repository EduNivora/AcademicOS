import 'dart:convert';

import '../../core/config/edunivora_api_config.dart';
import '../../core/network/platform_http_client.dart';

class NeonAccountException implements Exception {
  final int statusCode;
  final String message;

  const NeonAccountException(this.statusCode, this.message);

  @override
  String toString() => 'NeonAccountException($statusCode): $message';
}

class NeonAccountDataSource {
  final PlatformHttpRequest _request;
  final String _baseUrl;

  NeonAccountDataSource({
    PlatformHttpRequest? request,
    String baseUrl = EdunivoraApiConfig.noticesBaseUrl,
  })  : _request = request ?? platformRequest,
        _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  Future<Map<String, dynamic>> getProfile(String accessToken) async {
    final response = await _request(
      Uri.parse('$_baseUrl/v1/me'),
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      withCredentials: false,
    ).timeout(const Duration(seconds: 12));

    Object? decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      throw const FormatException('Invalid profile response from EduNivora API.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? (decoded['message'] ?? decoded['error'] ?? 'Profile request failed.')
          : 'Profile request failed.';
      throw NeonAccountException(response.statusCode, message.toString());
    }

    if (decoded is! Map<String, dynamic> || decoded['user'] is! Map) {
      throw const FormatException('Unexpected profile response shape.');
    }
    return Map<String, dynamic>.from(decoded['user'] as Map);
  }
}
