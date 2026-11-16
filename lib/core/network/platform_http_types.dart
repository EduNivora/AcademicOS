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
  required Map<String, String> headers,
  String? body,
  required bool withCredentials,
});
