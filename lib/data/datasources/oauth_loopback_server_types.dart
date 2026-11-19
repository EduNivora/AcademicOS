class OAuthLoopbackResponse {
  final int statusCode;
  final String? redirectLocation;
  final String htmlBody;
  final void Function()? onSent;

  const OAuthLoopbackResponse({
    required this.statusCode,
    this.redirectLocation,
    required this.htmlBody,
    this.onSent,
  });
}

abstract class OAuthLoopbackServer {
  int get port;
  String get origin;
  String get callbackUrl;
  String get errorCallbackUrl;

  Future<void> start({
    required Future<OAuthLoopbackResponse> Function(Uri requestUri) onRequest,
  });

  Future<void> close();
}
