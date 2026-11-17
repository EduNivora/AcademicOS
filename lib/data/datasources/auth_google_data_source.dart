import 'dart:async';
import 'dart:math';

import '../../core/config/edunivora_api_config.dart';
import 'neon_auth_data_source.dart';
import 'oauth_browser_channel.dart';
import 'oauth_loopback_server.dart';

enum GoogleOAuthStatus {
  verifierReceived,
  cancelled,
  failed,
}

class GoogleOAuthResult {
  final GoogleOAuthStatus status;
  final String? verifier;
  final String? challengeCookieHeader;
  final String? origin;
  final String? errorCode;
  final String? errorMessage;

  const GoogleOAuthResult._({
    required this.status,
    this.verifier,
    this.challengeCookieHeader,
    this.origin,
    this.errorCode,
    this.errorMessage,
  });

  const GoogleOAuthResult.verifierReceived({
    required String verifier,
    required String challengeCookieHeader,
    required String origin,
  }) : this._(
          status: GoogleOAuthStatus.verifierReceived,
          verifier: verifier,
          challengeCookieHeader: challengeCookieHeader,
          origin: origin,
        );

  const GoogleOAuthResult.cancelled()
      : this._(status: GoogleOAuthStatus.cancelled);

  const GoogleOAuthResult.failed({
    required String errorCode,
    String? errorMessage,
  }) : this._(
          status: GoogleOAuthStatus.failed,
          errorCode: errorCode,
          errorMessage: errorMessage,
        );
}

abstract class AuthGoogleDataSource {
  Future<GoogleOAuthResult> authenticateWithNeon(
    NeonAuthDataSource neonAuthDataSource,
  );
  Future<void> cancelPendingAuth();
  Future<void> signOut();
}

typedef OAuthLoopbackServerFactory = OAuthLoopbackServer Function();

class AuthGoogleDataSourceImpl implements AuthGoogleDataSource {
  final OAuthBrowserLauncher _browserLauncher;
  final OAuthLoopbackServerFactory _loopbackServerFactory;
  final Duration _authTimeout;
  final Duration _cancelGraceDuration;
  final String Function() _nonceGenerator;

  final Set<String> _consumedNonces = <String>{};
  final Set<String> _consumedVerifiers = <String>{};

  Completer<GoogleOAuthResult>? _activeCompleter;
  OAuthLoopbackServer? _activeServer;
  Timer? _timeoutTimer;
  Timer? _cancelGraceTimer;
  String? _activeNonce;

  AuthGoogleDataSourceImpl({
    OAuthBrowserLauncher? browserLauncher,
    OAuthLoopbackServerFactory? loopbackServerFactory,
    Duration authTimeout = const Duration(minutes: 5),
    Duration cancelGraceDuration = const Duration(milliseconds: 1500),
    String Function()? nonceGenerator,
  })  : _browserLauncher =
            browserLauncher ?? MethodChannelOAuthBrowserLauncher(),
        _loopbackServerFactory =
            loopbackServerFactory ?? createOAuthLoopbackServer,
        _authTimeout = authTimeout,
        _cancelGraceDuration = cancelGraceDuration,
        _nonceGenerator = nonceGenerator ?? _generateSecureNonce;

  static String _generateSecureNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Uri _buildDeepLink({
    required String status,
    String? nonce,
  }) {
    return Uri(
      scheme: EdunivoraApiConfig.oauthDeepLinkScheme,
      host: EdunivoraApiConfig.oauthDeepLinkHost,
      path: EdunivoraApiConfig.oauthDeepLinkCallbackPath,
      queryParameters: {
        'status': status,
        if (nonce != null && nonce.isNotEmpty) 'nonce': nonce,
      },
    );
  }

  String _buildReturnHtml(Uri deepLink, {required String title, required String message}) {
    final safeHref = deepLink.toString();
    return '<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<meta http-equiv="refresh" content="0;url=$safeHref">'
        '<title>$title</title>'
        '<style>body{font-family:sans-serif;background:#0f172a;color:#f8fafc;'
        'display:flex;align-items:center;justify-content:center;min-height:100vh;'
        'margin:0;padding:24px;text-align:center}.card{background:#1e293b;'
        'border-radius:16px;padding:24px;max-width:360px;width:100%}a.btn{'
        'display:inline-block;margin-top:16px;padding:12px 20px;border-radius:10px;'
        'background:#2563eb;color:#fff;text-decoration:none;font-weight:700}</style>'
        '</head><body><div class="card"><h3>$title</h3><p>$message</p>'
        '<a class="btn" href="$safeHref">العودة إلى التطبيق</a>'
        '</div><script>window.location.replace("$safeHref");</script></body></html>';
  }

  @override
  Future<GoogleOAuthResult> authenticateWithNeon(
    NeonAuthDataSource neonAuthDataSource,
  ) async {
    // Cleanly cancel any previous in-flight attempt before starting a retry.
    await cancelPendingAuth();

    final nonce = _nonceGenerator();
    final server = _loopbackServerFactory();
    final completer = Completer<GoogleOAuthResult>();

    _activeNonce = nonce;
    _activeServer = server;
    _activeCompleter = completer;

    String? challengeCookieHeader;
    String? origin;

    void resolveOnce(GoogleOAuthResult result) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }

    try {
      await server.start(
        onRequest: (Uri requestUri) async {
          final path = requestUri.path;
          final query = requestUri.queryParameters;
          final incomingNonce = query['nonce'];

          // Reject unknown or stale nonces (CSRF & replay protection).
          if (incomingNonce == null || incomingNonce != _activeNonce) {
            final deepLink = _buildDeepLink(status: 'ignored');
            return OAuthLoopbackResponse(
              statusCode: 400,
              htmlBody: _buildReturnHtml(
                deepLink,
                title: 'رابط مصادقة غير صالح',
                message: 'هذا الطلب منتهي الصلاحية أو غير مطابق للجلسة الحالية.',
              ),
            );
          }

          // Idempotent protection against duplicate/replayed callbacks.
          if (completer.isCompleted || _consumedNonces.contains(incomingNonce)) {
            final deepLink = _buildDeepLink(
              status: 'already_handled',
              nonce: incomingNonce,
            );
            return OAuthLoopbackResponse(
              statusCode: 302,
              redirectLocation: deepLink.toString(),
              htmlBody: _buildReturnHtml(
                deepLink,
                title: 'تمت معالجة تسجيل الدخول مسبقاً',
                message: 'جارٍ إعادتك إلى تطبيق EduNivora...',
              ),
            );
          }

          if (path == EdunivoraApiConfig.oauthErrorPath ||
              query.containsKey('error')) {
            _consumedNonces.add(incomingNonce);
            final errorCode = (query['error'] ?? 'oauth_error').trim();
            final errorDesc = query['error_description']?.trim();
            final lowerCode = errorCode.toLowerCase();
            final outcome = (lowerCode == 'access_denied' ||
                    lowerCode == 'cancelled' ||
                    lowerCode == 'user_cancelled')
                ? const GoogleOAuthResult.cancelled()
                : GoogleOAuthResult.failed(
                    errorCode: errorCode,
                    errorMessage: errorDesc,
                  );
            final deepLink = _buildDeepLink(
              status: 'error',
              nonce: incomingNonce,
            );
            return OAuthLoopbackResponse(
              statusCode: 302,
              redirectLocation: deepLink.toString(),
              htmlBody: _buildReturnHtml(
                deepLink,
                title: 'لم يكتمل تسجيل الدخول',
                message: 'جارٍ إعادتك إلى التطبيق...',
              ),
              onSent: () => resolveOnce(outcome),
            );
          }

          if (path == EdunivoraApiConfig.oauthCallbackPath) {
            final verifier = query['neon_auth_session_verifier']?.trim();
            if (verifier == null || verifier.isEmpty) {
              _consumedNonces.add(incomingNonce);
              final deepLink = _buildDeepLink(
                status: 'error',
                nonce: incomingNonce,
              );
              return OAuthLoopbackResponse(
                statusCode: 302,
                redirectLocation: deepLink.toString(),
                htmlBody: _buildReturnHtml(
                  deepLink,
                  title: 'تعذّر التحقق من الجلسة',
                  message: 'جارٍ إعادتك إلى التطبيق...',
                ),
                onSent: () => resolveOnce(
                  const GoogleOAuthResult.failed(
                    errorCode: 'missing_session_verifier',
                    errorMessage:
                        'OAuth callback did not include neon_auth_session_verifier.',
                  ),
                ),
              );
            }

            if (_consumedVerifiers.contains(verifier)) {
              final deepLink = _buildDeepLink(
                status: 'already_handled',
                nonce: incomingNonce,
              );
              return OAuthLoopbackResponse(
                statusCode: 302,
                redirectLocation: deepLink.toString(),
                htmlBody: _buildReturnHtml(
                  deepLink,
                  title: 'تمت معالجة الطلب مسبقاً',
                  message: 'جارٍ إعادتك إلى التطبيق...',
                ),
              );
            }

            _consumedNonces.add(incomingNonce);
            _consumedVerifiers.add(verifier);
            _cancelGraceTimer?.cancel();

            final outcome = GoogleOAuthResult.verifierReceived(
              verifier: verifier,
              challengeCookieHeader: challengeCookieHeader ?? '',
              origin: origin ?? server.origin,
            );

            final deepLink = _buildDeepLink(
              status: 'ok',
              nonce: incomingNonce,
            );
            return OAuthLoopbackResponse(
              statusCode: 302,
              redirectLocation: deepLink.toString(),
              htmlBody: _buildReturnHtml(
                deepLink,
                title: 'تم تأكيد الحساب بنجاح',
                message: 'جارٍ إعادتك إلى تطبيق EduNivora لإكمال التحقق...',
              ),
              onSent: () => resolveOnce(outcome),
            );
          }

          final deepLink = _buildDeepLink(status: 'ignored');
          return OAuthLoopbackResponse(
            statusCode: 404,
            htmlBody: _buildReturnHtml(
              deepLink,
              title: 'مسار غير معروف',
              message: 'يمكنك إغلاق هذه الصفحة والعودة إلى التطبيق.',
            ),
          );
        },
      );

      origin = server.origin;
      final callbackUrl = Uri.parse(server.callbackUrl).replace(
        queryParameters: {'nonce': nonce},
      ).toString();
      final errorCallbackUrl = Uri.parse(server.errorCallbackUrl).replace(
        queryParameters: {'nonce': nonce},
      ).toString();

      final startResult = await neonAuthDataSource.startGoogleOAuth(
        callbackUrl: callbackUrl,
        errorCallbackUrl: errorCallbackUrl,
        origin: origin,
      );
      challengeCookieHeader = startResult.challengeCookieHeader;

      // Drain any stale cold-start deep link before registering active listeners.
      await _browserLauncher.consumeInitialDeepLink();

      _browserLauncher.setCallbacks(
        onDeepLink: (Uri deepLink) {
          if (completer.isCompleted) return;
          if (deepLink.scheme.toLowerCase() !=
                  EdunivoraApiConfig.oauthDeepLinkScheme ||
              deepLink.host.toLowerCase() !=
                  EdunivoraApiConfig.oauthDeepLinkHost) {
            return;
          }
          final query = deepLink.queryParameters;
          final incomingNonce = query['nonce'];
          if (incomingNonce != null && incomingNonce != _activeNonce) {
            return;
          }

          // Support direct deep link carrying a verifier (e.g. App Link / bounce page).
          final directVerifier = query['neon_auth_session_verifier']?.trim();
          if (directVerifier != null && directVerifier.isNotEmpty) {
            if (_consumedVerifiers.contains(directVerifier)) return;
            if (incomingNonce != null) {
              if (_consumedNonces.contains(incomingNonce)) return;
              _consumedNonces.add(incomingNonce);
            }
            _consumedVerifiers.add(directVerifier);
            _cancelGraceTimer?.cancel();
            resolveOnce(
              GoogleOAuthResult.verifierReceived(
                verifier: directVerifier,
                challengeCookieHeader: challengeCookieHeader ?? '',
                origin: origin ?? server.origin,
              ),
            );
            return;
          }

          // Deep link status=error from browser redirect if loopback did not resolve yet.
          final status = query['status']?.toLowerCase();
          if (status == 'cancelled') {
            _cancelGraceTimer?.cancel();
            resolveOnce(const GoogleOAuthResult.cancelled());
          } else if (status == 'error') {
            _cancelGraceTimer?.cancel();
            resolveOnce(
              GoogleOAuthResult.failed(
                errorCode: query['error'] ?? 'oauth_callback_error',
                errorMessage: query['error_description'],
              ),
            );
          }
        },
        onCustomTabClosed: () {
          if (completer.isCompleted) return;
          _cancelGraceTimer?.cancel();
          _cancelGraceTimer = Timer(_cancelGraceDuration, () {
            resolveOnce(const GoogleOAuthResult.cancelled());
          });
        },
      );

      _timeoutTimer = Timer(_authTimeout, () {
        resolveOnce(
          const GoogleOAuthResult.failed(
            errorCode: 'oauth_timeout',
            errorMessage: 'Google sign-in timed out before completing.',
          ),
        );
      });

      await _browserLauncher.launchCustomTab(startResult.authorizationUrl);

      return await completer.future;
    } finally {
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
      _cancelGraceTimer?.cancel();
      _cancelGraceTimer = null;
      _browserLauncher.clearCallbacks();
      if (identical(_activeServer, server)) {
        _activeServer = null;
      }
      if (identical(_activeCompleter, completer)) {
        _activeCompleter = null;
      }
      if (_activeNonce == nonce) {
        _activeNonce = null;
      }
      await server.close();
    }
  }

  @override
  Future<void> cancelPendingAuth() async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _cancelGraceTimer?.cancel();
    _cancelGraceTimer = null;
    _browserLauncher.clearCallbacks();

    final completer = _activeCompleter;
    _activeCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(const GoogleOAuthResult.cancelled());
    }

    final server = _activeServer;
    _activeServer = null;
    if (server != null) {
      await server.close();
    }
    _activeNonce = null;
  }

  @override
  Future<void> signOut() async {
    await cancelPendingAuth();
  }
}
