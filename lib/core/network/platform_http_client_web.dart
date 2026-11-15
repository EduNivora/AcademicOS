import 'dart:html' as html;

import 'platform_http_types.dart';

Future<String> platformGet(Uri uri) async {
  final request = await html.HttpRequest.request(
    uri.toString(),
    method: 'GET',
    requestHeaders: const {'Accept': 'application/json'},
  ).timeout(const Duration(seconds: 15));
  final status = request.status ?? 0;
  if (status < 200 || status >= 300) {
    throw Exception('HTTP $status while requesting EduNivora notices.');
  }
  return request.responseText ?? '';
}

Future<void> platformPost(Uri uri) async {
  final request = await html.HttpRequest.request(
    uri.toString(),
    method: 'POST',
    requestHeaders: const {'Accept': 'application/json'},
  ).timeout(const Duration(seconds: 15));
  final status = request.status ?? 0;
  if (status < 200 || status >= 300) {
    throw Exception('HTTP $status while submitting EduNivora notice metric.');
  }
}

Future<PlatformHttpResponse> platformRequest(
  Uri uri, {
  required String method,
  required Map<String, String> headers,
  String? body,
  required bool withCredentials,
}) async {
  final request = await html.HttpRequest.request(
    uri.toString(),
    method: method,
    sendData: body,
    requestHeaders: headers,
    withCredentials: withCredentials,
  ).timeout(const Duration(seconds: 15));
  final responseHeaders = <String, List<String>>{};
  for (final line in (request.getAllResponseHeaders() ?? '').split('\r\n')) {
    final separator = line.indexOf(':');
    if (separator <= 0) continue;
    final name = line.substring(0, separator).trim().toLowerCase();
    final value = line.substring(separator + 1).trim();
    responseHeaders.putIfAbsent(name, () => <String>[]).add(value);
  }
  return PlatformHttpResponse(
    statusCode: request.status ?? 0,
    body: request.responseText ?? '',
    headers: responseHeaders,
  );
}
