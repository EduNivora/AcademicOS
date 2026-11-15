import 'dart:convert';
import 'dart:io';

import 'platform_http_types.dart';

Future<String> platformGet(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  try {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 15));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'HTTP ${response.statusCode} while requesting EduNivora notices.',
        uri: uri,
      );
    }
    return body;
  } finally {
    client.close(force: true);
  }
}

Future<void> platformPost(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  try {
    final request = await client.postUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 15));
    await response.drain<void>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'HTTP ${response.statusCode} while submitting EduNivora notice metric.',
        uri: uri,
      );
    }
  } finally {
    client.close(force: true);
  }
}

Future<PlatformHttpResponse> platformRequest(
  Uri uri, {
  required String method,
  required Map<String, String> headers,
  String? body,
  required bool withCredentials,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  try {
    final request = await client.openUrl(method, uri);
    headers.forEach((name, value) => request.headers.set(name, value));
    if (body != null) request.write(body);
    final response = await request.close().timeout(const Duration(seconds: 15));
    final responseBody = await response.transform(utf8.decoder).join();
    final responseHeaders = <String, List<String>>{};
    response.headers.forEach((name, values) {
      responseHeaders[name.toLowerCase()] = List<String>.unmodifiable(values);
    });
    return PlatformHttpResponse(
      statusCode: response.statusCode,
      body: responseBody,
      headers: responseHeaders,
    );
  } finally {
    client.close(force: true);
  }
}
