import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/config/edunivora_api_config.dart';
import '../../core/network/platform_http_client.dart';
import '../../core/security/auth_secure_storage_service.dart';

abstract class NeonAuthSessionStore {
  Future<String?> readCookie();
  Future<void> writeCookie(String cookie);
  Future<void> clearCookie();
}

class SecureStorageNeonAuthSessionStore implements NeonAuthSessionStore {
  final AuthSecureStorageService _storage;

  SecureStorageNeonAuthSessionStore(this._storage);

  @override
  Future<String?> readCookie() => _storage.getNeonAuthCookie();

  @override
  Future<void> writeCookie(String cookie) =>
      _storage.saveNeonAuthCookie(cookie);

  @override
  Future<void> clearCookie() => _storage.clearNeonAuthCookie();
}

class NeonAuthException implements Exception {
  final int statusCode;
  final String message;

  const NeonAuthException(this.statusCode, this.message);

  @override
  String toString() => 'NeonAuthException($statusCode): $message';
}

class NeonOAuthStartResult {
  final Uri authorizationUrl;
  final String challengeCookieHeader;

  const NeonOAuthStartResult({
    required this.authorizationUrl,
    required this.challengeCookieHeader,
  });
}

class NeonAuthDataSource {
  final PlatformHttpRequest _request;
  final NeonAuthSessionStore _sessionStore;
  final String _baseUrl;
  final bool _webMode;

  NeonAuthDataSource({
    PlatformHttpRequest? request,
    required NeonAuthSessionStore sessionStore,
    String baseUrl = EdunivoraApiConfig.authBaseUrl,
    bool? webMode,
  })  : _request = request ?? platformRequest,
        _sessionStore = sessionStore,
        _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _webMode = webMode ?? kIsWeb;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<Map<String, dynamic>> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return _send('/sign-up/email', method: 'POST', body: {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
    });
  }

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) {
    return _send('/sign-in/email', method: 'POST', body: {
      'email': email.trim().toLowerCase(),
      'password': password,
      'rememberMe': true,
    });
  }

  /// Initiates Neon Auth's OAuth redirect flow for Google and returns the
  /// authorization URL along with the short-lived session challenge cookies
  /// required to exchange the callback verifier.
  Future<NeonOAuthStartResult> startGoogleOAuth({
    required String callbackUrl,
    required String errorCallbackUrl,
    required String origin,
  }) async {
    if (callbackUrl.trim().isEmpty || errorCallbackUrl.trim().isEmpty) {
      throw ArgumentError('OAuth callback URLs must not be empty.');
    }
    if (origin.trim().isEmpty) {
      throw ArgumentError('OAuth origin must not be empty.');
    }

    final challengeCookies = <String>[];
    final result = await _sendNullable(
      '/sign-in/social',
      method: 'POST',
      body: {
        'provider': 'google',
        'callbackURL': callbackUrl,
        'errorCallbackURL': errorCallbackUrl,
      },
      extraHeaders: {'Origin': origin},
      includeStoredCookie: false,
      onResponse: (response) {
        for (final header in response.headers['set-cookie'] ?? const <String>[]) {
          final pair = header.split(';').first.trim();
          final sep = pair.indexOf('=');
          if (sep <= 0) continue;
          final name = pair.substring(0, sep).trim().toLowerCase();
          if (name.contains('session_challenge') ||
              name.contains('session_challange')) {
            challengeCookies.add(pair);
          }
        }
      },
    );

    if (result == null) {
      throw const FormatException('Neon Auth returned an empty OAuth response.');
    }
    final rawUrl = result['url'];
    if (rawUrl is! String || rawUrl.trim().isEmpty) {
      throw StateError('Neon Auth did not return an OAuth authorization URL.');
    }
    final authorizationUrl = Uri.tryParse(rawUrl.trim());
    if (authorizationUrl == null || authorizationUrl.scheme != 'https') {
      throw StateError('Neon Auth returned an invalid OAuth authorization URL.');
    }
    if (!_webMode && challengeCookies.isEmpty) {
      throw StateError('Neon Auth did not issue a session challenge cookie.');
    }

    return NeonOAuthStartResult(
      authorizationUrl: authorizationUrl,
      challengeCookieHeader: challengeCookies.join('; '),
    );
  }

  /// Exchanges the one-time `neon_auth_session_verifier` returned to the OAuth
  /// callback together with the `session_challenge` cookies from `startGoogleOAuth`
  /// for a verified Neon Auth session cookie.
  Future<Map<String, dynamic>> completeOAuthSession({
    required String verifier,
    required String challengeCookieHeader,
    required String origin,
  }) async {
    final trimmedVerifier = verifier.trim();
    if (trimmedVerifier.isEmpty) {
      throw ArgumentError.value(verifier, 'verifier', 'Must not be empty.');
    }
    if (!_webMode && challengeCookieHeader.trim().isEmpty) {
      throw ArgumentError.value(
        challengeCookieHeader,
        'challengeCookieHeader',
        'Must not be empty.',
      );
    }

    final encoded = Uri.encodeQueryComponent(trimmedVerifier);
    final result = await _sendNullable(
      '/get-session?neon_auth_session_verifier=$encoded',
      method: 'GET',
      extraHeaders: {
        'Origin': origin,
        if (!_webMode) 'Cookie': challengeCookieHeader,
      },
      includeStoredCookie: false,
    );
    if (result == null || result['user'] is! Map) {
      throw StateError('Neon Auth did not establish a verified OAuth session.');
    }
    return result;
  }

  Future<Map<String, dynamic>> sendEmailVerificationOtp(String email) {
    return _send('/email-otp/send-verification-otp', method: 'POST', body: {
      'email': email.trim().toLowerCase(),
      'type': 'email-verification',
    });
  }

  Future<Map<String, dynamic>> verifyEmailOtp({
    required String email,
    required String otp,
  }) {
    return _send('/email-otp/verify-email', method: 'POST', body: {
      'email': email.trim().toLowerCase(),
      'otp': otp.trim(),
    });
  }

  Future<Map<String, dynamic>?> getSession() async {
    final result = await _sendNullable('/get-session', method: 'GET');
    if (result == null || result['user'] is! Map) return null;
    return result;
  }

  Future<String?> getAccessToken() async {
    String? responseJwt;
    try {
      final session = await _sendNullable(
        '/get-session',
        method: 'GET',
        onResponse: (response) {
          responseJwt = response.headers['set-auth-jwt']?.first;
        },
      );
      if (session == null || session['session'] is! Map) return null;

      final sessionData = session['session'] as Map;
      final bodyToken = sessionData['token'];
      if (bodyToken is String && bodyToken.isNotEmpty) return bodyToken;
      return responseJwt?.isNotEmpty == true ? responseJwt : null;
    } on NeonAuthException catch (error) {
      if (error.statusCode == 401) {
        await _sessionStore.clearCookie();
        return null;
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _send('/sign-out', method: 'POST', body: const <String, dynamic>{});
    } finally {
      await _sessionStore.clearCookie();
    }
  }

  Future<Map<String, dynamic>> _send(
    String path, {
    required String method,
    Map<String, dynamic>? body,
  }) async {
    final result = await _sendNullable(path, method: method, body: body);
    if (result == null) {
      throw const FormatException('Neon Auth returned an empty response.');
    }
    return result;
  }

  Future<Map<String, dynamic>?> _sendNullable(
    String path, {
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
    bool includeStoredCookie = true,
    void Function(PlatformHttpResponse response)? onResponse,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    if (!_webMode && includeStoredCookie) {
      final cookie = await _sessionStore.readCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    final response = await _request(
      _uri(path),
      method: method,
      headers: headers,
      body: body == null ? null : jsonEncode(body),
      withCredentials: _webMode,
    );

    if (!_webMode) {
      await _captureSessionCookie(response.headers['set-cookie'] ?? const []);
    }
    onResponse?.call(response);

    final decoded = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? (decoded['message'] ?? decoded['error'] ?? 'Authentication failed.')
          : 'Authentication failed.';
      throw NeonAuthException(response.statusCode, message.toString());
    }
    if (decoded == null) return null;
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected Neon Auth response shape.');
    }
    return decoded;
  }

  Future<void> _captureSessionCookie(List<String> setCookieHeaders) async {
    for (final header in setCookieHeaders) {
      final pair = header.split(';').first.trim();
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      final name = pair.substring(0, separator).trim();
      if (!name.contains('session_token')) continue;
      if (header.toLowerCase().contains('max-age=0') ||
          pair.substring(separator + 1).isEmpty) {
        await _sessionStore.clearCookie();
      } else {
        await _sessionStore.writeCookie(pair);
      }
    }
  }

  Object? _decodeBody(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const FormatException('Neon Auth returned invalid JSON.');
    }
  }
}
