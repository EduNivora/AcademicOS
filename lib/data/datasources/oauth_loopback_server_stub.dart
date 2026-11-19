import '../../core/config/edunivora_api_config.dart';
import 'oauth_loopback_server_types.dart';

class StubOAuthLoopbackServer implements OAuthLoopbackServer {
  final int _port;
  final String _callbackPath;
  final String _errorPath;

  StubOAuthLoopbackServer({
    int port = EdunivoraApiConfig.oauthLoopbackPort,
    String callbackPath = EdunivoraApiConfig.oauthCallbackPath,
    String errorPath = EdunivoraApiConfig.oauthErrorPath,
  })  : _port = port,
        _callbackPath = callbackPath,
        _errorPath = errorPath;

  @override
  int get port => _port;

  @override
  String get origin => 'http://localhost:$_port';

  @override
  String get callbackUrl => '$origin$_callbackPath';

  @override
  String get errorCallbackUrl => '$origin$_errorPath';

  @override
  Future<void> start({
    required Future<OAuthLoopbackResponse> Function(Uri requestUri) onRequest,
  }) async {
    throw UnsupportedError(
      'Native loopback OAuth server is not supported on this platform.',
    );
  }

  @override
  Future<void> close() async {}
}

OAuthLoopbackServer createOAuthLoopbackServer({
  int port = EdunivoraApiConfig.oauthLoopbackPort,
  String callbackPath = EdunivoraApiConfig.oauthCallbackPath,
  String errorPath = EdunivoraApiConfig.oauthErrorPath,
}) {
  return StubOAuthLoopbackServer(
    port: port,
    callbackPath: callbackPath,
    errorPath: errorPath,
  );
}
