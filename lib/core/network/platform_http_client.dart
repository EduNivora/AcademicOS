export 'platform_http_client_stub.dart'
    if (dart.library.io) 'platform_http_client_io.dart'
    if (dart.library.html) 'platform_http_client_web.dart';

class PlatformHttpResponse {
  final int statusCode;
  final String body;
  final Map<String, List<String>> headers;

  const PlatformHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const <String, List<String>>{},
  });
}

typedef PlatformHttpRequest = Future<PlatformHttpResponse> Function(
  Uri uri, {
  required String method,
  Map<String, String> headers,
  String? body,
  bool withCredentials,
});
