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
  Map<String, String> headers = const <String, String>{},
  String? body,
  bool withCredentials = false,
}) {
  throw UnsupportedError('HTTP is not supported on this platform.');
}
