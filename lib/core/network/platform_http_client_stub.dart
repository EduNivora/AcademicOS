import 'platform_http_types.dart';

Future<String> platformGet(Uri uri) {
  throw UnsupportedError('HTTP is not supported on this platform.');
}

Future<void> platformPost(Uri uri) {
  throw UnsupportedError('HTTP is not supported on this platform.');
}

Future<PlatformHttpResponse> platformRequest(
  Uri uri, {
  required String method,
  required Map<String, String> headers,
  String? body,
  required bool withCredentials,
}) {
  throw UnsupportedError('HTTP is not supported on this platform.');
}
