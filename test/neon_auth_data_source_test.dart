import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/network/platform_http_client.dart';
import 'package:academic_os/data/datasources/neon_auth_data_source.dart';

class _MemorySessionStore implements NeonAuthSessionStore {
  String? cookie;

  @override
  Future<String?> readCookie() async => cookie;

  @override
  Future<void> writeCookie(String value) async { cookie = value; }

  @override
  Future<void> clearCookie() async { cookie = null; }
}

void main() {
  test('persists native session cookie and sends it when restoring session',
      () async {
    final store = _MemorySessionStore();
    final requests = <({Uri uri, Map<String, String> headers})>[];

    Future<PlatformHttpResponse> request(
      Uri uri, {
      required String method,
      required Map<String, String> headers,
      String? body,
      required bool withCredentials,
    }) async {
      requests.add((uri: uri, headers: Map.of(headers)));
      if (uri.path.endsWith('/sign-in/email')) {
        expect(jsonDecode(body!)['email'], 'student@example.com');
        return const PlatformHttpResponse(
          statusCode: 200,
          body: '{"redirect":false,"token":"session-token","user":{"id":"user-1","email":"student@example.com","name":"Student","emailVerified":true}}',
          headers: {
            'set-cookie': [
              '__Secure-neon-auth.session_token=opaque-session; Path=/; HttpOnly; Secure; SameSite=None'
            ],
          },
        );
      }
      return const PlatformHttpResponse(
        statusCode: 200,
        body: '{"session":{"id":"session-1"},"user":{"id":"user-1","email":"student@example.com","name":"Student","emailVerified":true}}',
      );
    }

    final auth = NeonAuthDataSource(
      request: request,
      sessionStore: store,
      baseUrl: 'https://auth.example.test/auth',
      webMode: false,
    );

    await auth.signIn(email: ' Student@Example.com ', password: 'correct horse');
    expect(store.cookie, '__Secure-neon-auth.session_token=opaque-session');

    final session = await auth.getSession();
    expect(session?['user']['id'], 'user-1');
    expect(requests.last.headers['Cookie'],
        '__Secure-neon-auth.session_token=opaque-session');
  });

  test('sends and verifies the configured email verification OTP', () async {
    final store = _MemorySessionStore();
    final requests = <({Uri uri, String? body})>[];

    Future<PlatformHttpResponse> request(
      Uri uri, {
      required String method,
      required Map<String, String> headers,
      String? body,
      required bool withCredentials,
    }) async {
      requests.add((uri: uri, body: body));
      return const PlatformHttpResponse(
        statusCode: 200,
        body: '{"success":true,"status":true,"user":{"id":"user-1"}}',
      );
    }

    final auth = NeonAuthDataSource(
      request: request,
      sessionStore: store,
      baseUrl: 'https://auth.example.test/auth',
      webMode: false,
    );

    await auth.sendEmailVerificationOtp('STUDENT@example.com');
    await auth.verifyEmailOtp(email: 'student@example.com', otp: '123456');

    expect(requests[0].uri.path, endsWith('/email-otp/send-verification-otp'));
    expect(jsonDecode(requests[0].body!)['type'], 'email-verification');
    expect(requests[1].uri.path, endsWith('/email-otp/verify-email'));
    expect(jsonDecode(requests[1].body!)['otp'], '123456');
  });

  test('uses browser-managed credential cookies on Web', () async {
    final store = _MemorySessionStore();
    var credentialsIncluded = false;
    var cookieHeaderSent = false;

    Future<PlatformHttpResponse> request(
      Uri uri, {
      required String method,
      required Map<String, String> headers,
      String? body,
      required bool withCredentials,
    }) async {
      credentialsIncluded = withCredentials;
      cookieHeaderSent = headers.containsKey('Cookie');
      if (uri.path.endsWith('/get-session')) {
        return const PlatformHttpResponse(
          statusCode: 200,
          body: '{"session":{"id":"session-1"},"user":{"id":"user-1","email":"student@example.com"}}',
        );
      }
      return const PlatformHttpResponse(
        statusCode: 200,
        body: '{"token":"jwt-token"}',
      );
    }

    final auth = NeonAuthDataSource(
      request: request,
      sessionStore: store,
      baseUrl: 'https://auth.example.test/auth',
      webMode: true,
    );

    expect(await auth.getAccessToken(), 'jwt-token');
    expect(credentialsIncluded, isTrue);
    expect(cookieHeaderSent, isFalse);
    expect(store.cookie, isNull);
  });

  test('surfaces safe Neon Auth error messages', () async {
    final auth = NeonAuthDataSource(
      request: (_, {
        required method,
        required Map<String, String> headers,
        body,
        required bool withCredentials,
      }) async => const PlatformHttpResponse(
        statusCode: 401,
        body: '{"message":"Invalid email or password"}',
      ),
      sessionStore: _MemorySessionStore(),
      baseUrl: 'https://auth.example.test/auth',
      webMode: false,
    );

    await expectLater(
      auth.signIn(email: 'student@example.com', password: 'wrong'),
      throwsA(
        isA<NeonAuthException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.message, 'message',
                'Invalid email or password'),
      ),
    );
  });

  test('returns no JWT for a guest without making a token request', () async {
    final store = _MemorySessionStore();
    final requestedPaths = <String>[];

    Future<PlatformHttpResponse> request(
      Uri uri, {
      required String method,
      required Map<String, String> headers,
      String? body,
      required bool withCredentials,
    }) async {
      requestedPaths.add(uri.path);
      return const PlatformHttpResponse(statusCode: 200, body: 'null');
    }

    final auth = NeonAuthDataSource(
      request: request,
      sessionStore: store,
      baseUrl: 'https://auth.example.test/auth',
      webMode: false,
    );

    expect(await auth.getAccessToken(), isNull);
    expect(requestedPaths, ['/auth/get-session']);
  });
}
