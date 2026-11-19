import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/config/edunivora_api_config.dart';
import 'oauth_loopback_server_types.dart';

class IoOAuthLoopbackServer implements OAuthLoopbackServer {
  final int _requestedPort;
  final String _callbackPath;
  final String _errorPath;

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;

  IoOAuthLoopbackServer({
    int port = EdunivoraApiConfig.oauthLoopbackPort,
    String callbackPath = EdunivoraApiConfig.oauthCallbackPath,
    String errorPath = EdunivoraApiConfig.oauthErrorPath,
  })  : _requestedPort = port,
        _callbackPath = callbackPath,
        _errorPath = errorPath;

  @override
  int get port => _server?.port ?? _requestedPort;

  @override
  String get origin => 'http://localhost:$port';

  @override
  String get callbackUrl => '$origin$_callbackPath';

  @override
  String get errorCallbackUrl => '$origin$_errorPath';

  @override
  Future<void> start({
    required Future<OAuthLoopbackResponse> Function(Uri requestUri) onRequest,
  }) async {
    await close();
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      _requestedPort,
      shared: false,
    );
    _server = server;
    _subscription = server.listen((HttpRequest request) async {
      try {
        if (request.method != 'GET') {
          request.response
            ..statusCode = HttpStatus.methodNotAllowed
            ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
            ..write('Method not allowed');
          await request.response.close();
          return;
        }

        final result = await onRequest(request.uri);
        final response = request.response;
        response.statusCode = result.statusCode;
        response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
        response.headers.set('Referrer-Policy', 'no-referrer');
        response.headers.contentType = ContentType.html;
        if (result.redirectLocation != null &&
            result.redirectLocation!.isNotEmpty) {
          response.headers.set(
            HttpHeaders.locationHeader,
            result.redirectLocation!,
          );
        }
        response.add(utf8.encode(result.htmlBody));
        await response.close();
        result.onSent?.call();
      } catch (_) {
        try {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
            ..write('OAuth callback handling failed.');
          await request.response.close();
        } catch (_) {
          // Ignore socket errors if browser already disconnected.
        }
      }
    });
  }

  @override
  Future<void> close() async {
    final sub = _subscription;
    _subscription = null;
    if (sub != null) {
      await sub.cancel();
    }
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
  }
}

OAuthLoopbackServer createOAuthLoopbackServer({
  int port = EdunivoraApiConfig.oauthLoopbackPort,
  String callbackPath = EdunivoraApiConfig.oauthCallbackPath,
  String errorPath = EdunivoraApiConfig.oauthErrorPath,
}) {
  return IoOAuthLoopbackServer(
    port: port,
    callbackPath: callbackPath,
    errorPath: errorPath,
  );
}
