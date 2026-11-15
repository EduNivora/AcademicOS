import 'dart:html' as html;

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
