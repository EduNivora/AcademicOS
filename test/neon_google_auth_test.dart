import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:academic_os/core/network/platform_http_client.dart';
import 'package:academic_os/core/security/auth_secure_storage_service.dart';
import 'package:academic_os/data/datasources/auth_google_data_source.dart';
import 'package:academic_os/data/datasources/auth_local_data_source.dart';
import 'package:academic_os/data/datasources/neon_auth_data_source.dart';
import 'package:academic_os/data/datasources/oauth_browser_channel.dart';
import 'package:academic_os/data/datasources/oauth_loopback_server_io.dart';
import 'package:academic_os/data/repositories/auth_repository_impl.dart';

class _MemorySessionStore implements NeonAuthSessionStore {
  String? cookie;

  @override
  Future<String?> readCookie() async => cookie;

  @override
  Future<void> writeCookie(String value) async {
    cookie = value;
  }

  @override
  Future<void> clearCookie() async {
    cookie = null;
  }
}

class _FakeBrowserLauncher implements OAuthBrowserLauncher {
  final Future<void> Function(
    Uri authorizationUrl,
    _FakeBrowserLauncher launcher,
  ) onLaunch;

  void Function(Uri deepLink)? _onDeepLink;
  void Function()? _onCustomTabClosed;
  Uri? lastLaunchedUrl;

  _FakeBrowserLauncher({required this.onLaunch});

  @override
  void setCallbacks({
    required void Function(Uri deepLink) onDeepLink,
    required void Function() onCustomTabClosed,
  }) {
    _onDeepLink = onDeepLink;
    _onCustomTabClosed = onCustomTabClosed;
  }

  @override
  Future<void> launchCustomTab(Uri authorizationUrl) async {
    lastLaunchedUrl = authorizationUrl;
    await onLaunch(authorizationUrl, this);
  }

  @override
  Future<Uri?> consumeInitialDeepLink() async => null;

  @override
  void clearCallbacks() {
    _onDeepLink = null;
    _onCustomTabClosed = null;
  }

  void simulateDeepLink(Uri uri) => _onDeepLink?.call(uri);
  void simulateCustomTabClosed() => _onCustomTabClosed?.call();
}

Future<({int statusCode, String? location, String body})> _httpGetNoRedirect(
  Uri uri,
) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    req.followRedirects = false;
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    return (
      statusCode: res.statusCode,
      location: res.headers.value(HttpHeaders.locationHeader),
      body: body,
    );
  } finally {
    client.close(force: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  HttpOverrides? previousHttpOverrides;

  setUpAll(() {
    previousHttpOverrides = HttpOverrides.current;
    // Allow real loopback HTTP requests to IoOAuthLoopbackServer on 127.0.0.1.
    HttpOverrides.global = null;
  });

  tearDownAll(() {
    HttpOverrides.global = previousHttpOverrides;
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('NeonAuthDataSource OAuth Redirect protocol', () {
    test(
      'startGoogleOAuth posts provider/callbackURL and captures challenge cookies without overwriting session store',
      () async {
        final store = _MemorySessionStore();
        final requests = <({Uri uri, Map<String, String> headers, String? body})>[];

        Future<PlatformHttpResponse> request(
          Uri uri, {
          required String method,
          required Map<String, String> headers,
          String? body,
          required bool withCredentials,
        }) async {
          requests.add((uri: uri, headers: Map.of(headers), body: body));
          return const PlatformHttpResponse(
            statusCode: 200,
            body:
                '{"url":"https://ep-dry-leaf-baac97v8.neonauth.c-8.eu-central-1.aws.neon.tech/edunivora/auth/sign-in/social/init?token=tok-1","redirect":true}',
            headers: {
              'set-cookie': [
                '__Secure-neon-auth.session_challenge=chal-abc; Max-Age=600; Path=/; HttpOnly; Secure; SameSite=None',
                '__Secure-neon-auth.session_challange=chal-abc; Max-Age=600; Path=/; HttpOnly; Secure; SameSite=None',
              ],
            },
          );
        }

        final auth = NeonAuthDataSource(
          request: request,
          sessionStore: store,
          baseUrl:
              'https://ep-dry-leaf-baac97v8.neonauth.c-8.eu-central-1.aws.neon.tech/edunivora/auth',
          webMode: false,
        );

        final start = await auth.startGoogleOAuth(
          callbackUrl: 'http://localhost:43821/auth/callback?nonce=n1',
          errorCallbackUrl: 'http://localhost:43821/auth/error?nonce=n1',
          origin: 'http://localhost:43821',
        );

        expect(requests.length, 1);
        expect(requests.first.uri.path, endsWith('/sign-in/social'));
        expect(requests.first.headers['Origin'], 'http://localhost:43821');
        final payload = jsonDecode(requests.first.body!) as Map<String, dynamic>;
        expect(payload['provider'], 'google');
        expect(
          payload['callbackURL'],
          'http://localhost:43821/auth/callback?nonce=n1',
        );
        expect(
          payload['errorCallbackURL'],
          'http://localhost:43821/auth/error?nonce=n1',
        );
        expect(start.authorizationUrl.scheme, 'https');
        expect(
          start.challengeCookieHeader,
          contains('__Secure-neon-auth.session_challenge=chal-abc'),
        );
        expect(
          start.challengeCookieHeader,
          contains('__Secure-neon-auth.session_challange=chal-abc'),
        );
        expect(store.cookie, isNull);
      },
    );

    test(
      'completeOAuthSession exchanges verifier + challenge cookie and persists session_token cookie',
      () async {
        final store = _MemorySessionStore();
        late Uri capturedUri;
        late Map<String, String> capturedHeaders;

        Future<PlatformHttpResponse> request(
          Uri uri, {
          required String method,
          required Map<String, String> headers,
          String? body,
          required bool withCredentials,
        }) async {
          capturedUri = uri;
          capturedHeaders = Map.of(headers);
          return const PlatformHttpResponse(
            statusCode: 200,
            body:
                '{"session":{"id":"sess-1"},"user":{"id":"u-1","email":"student@edunivora.com","name":"Student","emailVerified":true}}',
            headers: {
              'set-cookie': [
                '__Secure-neon-auth.session_token=live-session-cookie; Path=/; HttpOnly; Secure; SameSite=None',
              ],
            },
          );
        }

        final auth = NeonAuthDataSource(
          request: request,
          sessionStore: store,
          baseUrl:
              'https://ep-dry-leaf-baac97v8.neonauth.c-8.eu-central-1.aws.neon.tech/edunivora/auth',
          webMode: false,
        );

        final res = await auth.completeOAuthSession(
          verifier: 'ver-xyz',
          challengeCookieHeader: '__Secure-neon-auth.session_challenge=chal-abc',
          origin: 'http://localhost:43821',
        );

        expect(capturedUri.path, endsWith('/get-session'));
        expect(capturedUri.queryParameters['neon_auth_session_verifier'], 'ver-xyz');
        expect(
          capturedHeaders['Cookie'],
          '__Secure-neon-auth.session_challenge=chal-abc',
        );
        expect(capturedHeaders['Origin'], 'http://localhost:43821');
        expect(res['user']['email'], 'student@edunivora.com');
        expect(
          store.cookie,
          '__Secure-neon-auth.session_token=live-session-cookie',
        );
      },
    );
  });

  group('Chrome Custom Tabs + Loopback + Deep Link integration', () {
    test(
      'completes full OAuth redirect, returns Deep Link 302, verifies session with Neon Auth, and ignores duplicate callbacks',
      () async {
        final secureStorage = AuthSecureStorageService();
        final localDataSource = AuthLocalDataSourceImpl(secureStorage);
        final sessionStore = SecureStorageNeonAuthSessionStore(secureStorage);

        String? capturedCallbackUrl;
        int exchangeCallCount = 0;
        int verifySessionCallCount = 0;
        ({int statusCode, String? location, String body})? firstLoopbackResponse;
        ({int statusCode, String? location, String body})? badNonceResponse;

        Future<PlatformHttpResponse> neonTransport(
          Uri uri, {
          required String method,
          required Map<String, String> headers,
          String? body,
          required bool withCredentials,
        }) async {
          if (uri.path.endsWith('/sign-in/social')) {
            final parsed = jsonDecode(body!) as Map<String, dynamic>;
            capturedCallbackUrl = parsed['callbackURL'] as String;
            return const PlatformHttpResponse(
              statusCode: 200,
              body:
                  '{"url":"https://ep-dry-leaf-baac97v8.neonauth.c-8.eu-central-1.aws.neon.tech/edunivora/auth/sign-in/social/init?token=init-1","redirect":true}',
              headers: {
                'set-cookie': [
                  '__Secure-neon-auth.session_challenge=chal-1; Path=/; HttpOnly; Secure',
                ],
              },
            );
          }

          if (uri.path.endsWith('/get-session') &&
              uri.queryParameters.containsKey('neon_auth_session_verifier')) {
            exchangeCallCount++;
            expect(
              uri.queryParameters['neon_auth_session_verifier'],
              'verifier-999',
            );
            expect(
              headers['Cookie'],
              contains('__Secure-neon-auth.session_challenge=chal-1'),
            );
            return const PlatformHttpResponse(
              statusCode: 200,
              body:
                  '{"session":{"id":"sess-google-1"},"user":{"id":"google-u1","email":"ahmed@edunivora.com","name":"Ahmed","emailVerified":true,"banned":false}}',
              headers: {
                'set-cookie': [
                  '__Secure-neon-auth.session_token=verified-token-123; Path=/; HttpOnly; Secure',
                ],
              },
            );
          }

          if (uri.path.endsWith('/get-session')) {
            verifySessionCallCount++;
            expect(
              headers['Cookie'],
              '__Secure-neon-auth.session_token=verified-token-123',
            );
            return const PlatformHttpResponse(
              statusCode: 200,
              body:
                  '{"session":{"id":"sess-google-1"},"user":{"id":"google-u1","email":"ahmed@edunivora.com","name":"Ahmed","emailVerified":true,"banned":false}}',
              headers: {
                'set-auth-jwt': ['neon-access-token-123'],
              },
            );
          }

          throw StateError('Unexpected endpoint: $uri');
        }

        final neonAuth = NeonAuthDataSource(
          request: neonTransport,
          sessionStore: sessionStore,
          baseUrl:
              'https://ep-dry-leaf-baac97v8.neonauth.c-8.eu-central-1.aws.neon.tech/edunivora/auth',
          webMode: false,
        );

        final launcher = _FakeBrowserLauncher(
          onLaunch: (authorizationUrl, self) async {
            expect(authorizationUrl.scheme, 'https');
            final cb = Uri.parse(capturedCallbackUrl!);

            // 1. Forged CSRF nonce must be rejected with HTTP 400.
            badNonceResponse = await _httpGetNoRedirect(
              cb.replace(
                queryParameters: {
                  'nonce': 'forged-nonce',
                  'neon_auth_session_verifier': 'bad-verifier',
                },
              ),
            );

            // 2. Valid callback from Neon Auth -> 302 to Android Deep Link.
            final validUri = cb.replace(
              queryParameters: {
                ...cb.queryParameters,
                'neon_auth_session_verifier': 'verifier-999',
              },
            );
            firstLoopbackResponse = await _httpGetNoRedirect(validUri);

            // 3. Simulate duplicate deep link arrival carrying the same verifier.
            self.simulateDeepLink(
              Uri.parse(
                'edunivora://auth/callback?nonce=${cb.queryParameters['nonce']}&neon_auth_session_verifier=verifier-999',
              ),
            );
          },
        );

        final googleDataSource = AuthGoogleDataSourceImpl(
          browserLauncher: launcher,
          loopbackServerFactory: () => IoOAuthLoopbackServer(port: 0),
          cancelGraceDuration: const Duration(milliseconds: 50),
          nonceGenerator: () => 'fixed-nonce-1',
        );

        final repo = AuthRepositoryImpl(
          localDataSource,
          googleDataSource,
          secureStorage,
          neonAuthDataSource: neonAuth,
        );

        final loggedIn = await repo.loginWithGoogle();

        expect(loggedIn, isTrue);
        expect(badNonceResponse?.statusCode, 400);
        expect(firstLoopbackResponse?.statusCode, 302);
        expect(
          firstLoopbackResponse?.location,
          'edunivora://auth/callback?status=ok&nonce=fixed-nonce-1',
        );
        expect(exchangeCallCount, 1);
        expect(verifySessionCallCount, 1);
        expect(
          await secureStorage.getNeonAuthCookie(),
          '__Secure-neon-auth.session_token=verified-token-123',
        );
        expect(await secureStorage.isNeonAuthSessionActive(), isTrue);
        expect(await secureStorage.isAuthSessionActive(), isTrue);
        expect(await secureStorage.getAuthUsername(), 'ahmed@edunivora.com');
      },
    );

    test(
      'handles user cancelling Chrome Custom Tabs without activating a session and allows immediate retry',
      () async {
        final secureStorage = AuthSecureStorageService();
        final localDataSource = AuthLocalDataSourceImpl(secureStorage);
        final sessionStore = SecureStorageNeonAuthSessionStore(secureStorage);

        var attempt = 0;
        String? capturedCallbackUrl;

        Future<PlatformHttpResponse> neonTransport(
          Uri uri, {
          required String method,
          required Map<String, String> headers,
          String? body,
          required bool withCredentials,
        }) async {
          if (uri.path.endsWith('/sign-in/social')) {
            final parsed = jsonDecode(body!) as Map<String, dynamic>;
            capturedCallbackUrl = parsed['callbackURL'] as String;
            return const PlatformHttpResponse(
              statusCode: 200,
              body:
                  '{"url":"https://ep-dry-leaf-baac97v8.neonauth.c-8.eu-central-1.aws.neon.tech/edunivora/auth/sign-in/social/init?token=init-retry","redirect":true}',
              headers: {
                'set-cookie': [
                  '__Secure-neon-auth.session_challenge=chal-retry; Path=/; HttpOnly; Secure',
                ],
              },
            );
          }
          if (uri.path.endsWith('/get-session') &&
              uri.queryParameters.containsKey('neon_auth_session_verifier')) {
            return const PlatformHttpResponse(
              statusCode: 200,
              body:
                  '{"session":{"id":"sess-2"},"user":{"id":"u-2","email":"retry@edunivora.com","name":"Retry User","emailVerified":true}}',
              headers: {
                'set-cookie': [
                  '__Secure-neon-auth.session_token=retry-cookie; Path=/; HttpOnly; Secure',
                ],
              },
            );
          }
          return const PlatformHttpResponse(
            statusCode: 200,
            body:
                '{"session":{"id":"sess-2"},"user":{"id":"u-2","email":"retry@edunivora.com","name":"Retry User","emailVerified":true}}',
            headers: {
              'set-auth-jwt': ['neon-access-token-retry'],
            },
          );
        }

        final neonAuth = NeonAuthDataSource(
          request: neonTransport,
          sessionStore: sessionStore,
          baseUrl:
              'https://ep-dry-leaf-baac97v8.neonauth.c-8.eu-central-1.aws.neon.tech/edunivora/auth',
          webMode: false,
        );

        final launcher = _FakeBrowserLauncher(
          onLaunch: (_, self) async {
            attempt++;
            if (attempt == 1) {
              // User presses Back / closes Chrome Custom Tab.
              self.simulateCustomTabClosed();
              return;
            }
            // Second attempt (retry) succeeds.
            final cb = Uri.parse(capturedCallbackUrl!);
            await _httpGetNoRedirect(
              cb.replace(
                queryParameters: {
                  ...cb.queryParameters,
                  'neon_auth_session_verifier': 'retry-verifier',
                },
              ),
            );
          },
        );

        var nonceCounter = 0;
        final googleDataSource = AuthGoogleDataSourceImpl(
          browserLauncher: launcher,
          loopbackServerFactory: () => IoOAuthLoopbackServer(port: 0),
          cancelGraceDuration: const Duration(milliseconds: 30),
          nonceGenerator: () => 'nonce-${++nonceCounter}',
        );

        final repo = AuthRepositoryImpl(
          localDataSource,
          googleDataSource,
          secureStorage,
          neonAuthDataSource: neonAuth,
        );

        // Attempt 1: Cancelled cleanly.
        expect(await repo.loginWithGoogle(), isFalse);
        expect(await secureStorage.isNeonAuthSessionActive(), isFalse);
        expect(await secureStorage.getNeonAuthCookie(), isNull);

        // Attempt 2: Retry succeeds and persists verified session.
        expect(await repo.loginWithGoogle(), isTrue);
        expect(await secureStorage.isNeonAuthSessionActive(), isTrue);
        expect(
          await secureStorage.getNeonAuthCookie(),
          '__Secure-neon-auth.session_token=retry-cookie',
        );
      },
    );

    test(
      'rejects login if Neon Auth does not issue a session cookie or fails post-callback getSession verification',
      () async {
        final secureStorage = AuthSecureStorageService();
        final localDataSource = AuthLocalDataSourceImpl(secureStorage);
        final sessionStore = SecureStorageNeonAuthSessionStore(secureStorage);

        String? capturedCallbackUrl;

        Future<PlatformHttpResponse> neonTransport(
          Uri uri, {
          required String method,
          required Map<String, String> headers,
          String? body,
          required bool withCredentials,
        }) async {
          if (uri.path.endsWith('/sign-in/social')) {
            final parsed = jsonDecode(body!) as Map<String, dynamic>;
            capturedCallbackUrl = parsed['callbackURL'] as String;
            return const PlatformHttpResponse(
              statusCode: 200,
              body:
                  '{"url":"https://ep-dry-leaf-baac97v8.neonauth.c-8.eu-central-1.aws.neon.tech/edunivora/auth/sign-in/social/init?token=init-fail","redirect":true}',
              headers: {
                'set-cookie': [
                  '__Secure-neon-auth.session_challenge=chal-fail; Path=/; HttpOnly; Secure',
                ],
              },
            );
          }
          // Missing Set-Cookie session_token on verifier exchange!
          return const PlatformHttpResponse(
            statusCode: 200,
            body:
                '{"session":{"id":"sess-no-cookie"},"user":{"id":"u-3","email":"nocookie@edunivora.com","emailVerified":true}}',
          );
        }

        final neonAuth = NeonAuthDataSource(
          request: neonTransport,
          sessionStore: sessionStore,
          baseUrl:
              'https://ep-dry-leaf-baac97v8.neonauth.c-8.eu-central-1.aws.neon.tech/edunivora/auth',
          webMode: false,
        );

        final launcher = _FakeBrowserLauncher(
          onLaunch: (_, __) async {
            final cb = Uri.parse(capturedCallbackUrl!);
            await _httpGetNoRedirect(
              cb.replace(
                queryParameters: {
                  ...cb.queryParameters,
                  'neon_auth_session_verifier': 'verifier-no-cookie',
                },
              ),
            );
          },
        );

        final googleDataSource = AuthGoogleDataSourceImpl(
          browserLauncher: launcher,
          loopbackServerFactory: () => IoOAuthLoopbackServer(port: 0),
          nonceGenerator: () => 'nonce-no-cookie',
        );

        final repo = AuthRepositoryImpl(
          localDataSource,
          googleDataSource,
          secureStorage,
          neonAuthDataSource: neonAuth,
        );

        await expectLater(
          repo.loginWithGoogle(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'neon_session_cookie_missing',
            ),
          ),
        );
        expect(await secureStorage.isNeonAuthSessionActive(), isFalse);
        expect(await secureStorage.isAuthSessionActive(), isFalse);
      },
    );

    test(
      'handles OAuth error callbacks (access_denied as cancel, server_error and missing verifier as failures)',
      () async {
        final secureStorage = AuthSecureStorageService();
        final localDataSource = AuthLocalDataSourceImpl(secureStorage);
        final sessionStore = SecureStorageNeonAuthSessionStore(secureStorage);

        String? capturedCallbackUrl;
        String? capturedErrorUrl;
        var mode = 0;

        Future<PlatformHttpResponse> neonTransport(
          Uri uri, {
          required String method,
          required Map<String, String> headers,
          String? body,
          required bool withCredentials,
        }) async {
          final parsed = jsonDecode(body!) as Map<String, dynamic>;
          capturedCallbackUrl = parsed['callbackURL'] as String;
          capturedErrorUrl = parsed['errorCallbackURL'] as String;
          return const PlatformHttpResponse(
            statusCode: 200,
            body:
                '{"url":"https://ep-dry-leaf-baac97v8.neonauth.c-8.eu-central-1.aws.neon.tech/edunivora/auth/sign-in/social/init?token=init-err","redirect":true}',
            headers: {
              'set-cookie': [
                '__Secure-neon-auth.session_challenge=chal-err; Path=/; HttpOnly; Secure',
              ],
            },
          );
        }

        final neonAuth = NeonAuthDataSource(
          request: neonTransport,
          sessionStore: sessionStore,
          baseUrl:
              'https://ep-dry-leaf-baac97v8.neonauth.c-8.eu-central-1.aws.neon.tech/edunivora/auth',
          webMode: false,
        );

        final launcher = _FakeBrowserLauncher(
          onLaunch: (_, __) async {
            mode++;
            if (mode == 1) {
              final errUri = Uri.parse(capturedErrorUrl!);
              final res = await _httpGetNoRedirect(
                errUri.replace(
                  queryParameters: {
                    ...errUri.queryParameters,
                    'error': 'access_denied',
                  },
                ),
              );
              expect(res.statusCode, 302);
              expect(res.location, contains('edunivora://auth/callback?status=error'));
            } else if (mode == 2) {
              final errUri = Uri.parse(capturedErrorUrl!);
              await _httpGetNoRedirect(
                errUri.replace(
                  queryParameters: {
                    ...errUri.queryParameters,
                    'error': 'server_error',
                  },
                ),
              );
            } else {
              // Callback hits /auth/callback WITHOUT neon_auth_session_verifier.
              final cbUri = Uri.parse(capturedCallbackUrl!);
              await _httpGetNoRedirect(cbUri);
            }
          },
        );

        var counter = 0;
        final repo = AuthRepositoryImpl(
          localDataSource,
          AuthGoogleDataSourceImpl(
            browserLauncher: launcher,
            loopbackServerFactory: () => IoOAuthLoopbackServer(port: 0),
            nonceGenerator: () => 'err-nonce-${++counter}',
          ),
          secureStorage,
          neonAuthDataSource: neonAuth,
        );

        // 1. access_denied -> returns false (cancelled)
        expect(await repo.loginWithGoogle(), isFalse);
        expect(await secureStorage.isNeonAuthSessionActive(), isFalse);

        // 2. server_error -> throws StateError('server_error')
        await expectLater(
          repo.loginWithGoogle(),
          throwsA(
            isA<StateError>().having((e) => e.message, 'message', 'server_error'),
          ),
        );

        // 3. callback without verifier -> throws StateError('missing_session_verifier')
        await expectLater(
          repo.loginWithGoogle(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'missing_session_verifier',
            ),
          ),
        );
      },
    );

    test(
      'preserves email/password login and OTP verification flows',
      () async {
        final secureStorage = AuthSecureStorageService();
        final localDataSource = AuthLocalDataSourceImpl(secureStorage);
        final sessionStore = SecureStorageNeonAuthSessionStore(secureStorage);

        Future<PlatformHttpResponse> neonTransport(
          Uri uri, {
          required String method,
          required Map<String, String> headers,
          String? body,
          required bool withCredentials,
        }) async {
          if (uri.path.endsWith('/sign-in/email')) {
            return const PlatformHttpResponse(
              statusCode: 200,
              body:
                  '{"user":{"id":"u-email","email":"user@edunivora.com","emailVerified":true}}',
              headers: {
                'set-cookie': [
                  '__Secure-neon-auth.session_token=email-cookie; Path=/; HttpOnly; Secure',
                ],
              },
            );
          }
          if (uri.path.endsWith('/email-otp/verify-email')) {
            return const PlatformHttpResponse(
              statusCode: 200,
              body:
                  '{"status":true,"user":{"id":"u-otp","email":"otp@edunivora.com","emailVerified":true}}',
              headers: {
                'set-cookie': [
                  '__Secure-neon-auth.session_token=otp-cookie; Path=/; HttpOnly; Secure',
                ],
              },
            );
          }
          throw StateError('Unexpected request: $uri');
        }

        final neonAuth = NeonAuthDataSource(
          request: neonTransport,
          sessionStore: sessionStore,
          baseUrl:
              'https://ep-dry-leaf-baac97v8.neonauth.c-8.eu-central-1.aws.neon.tech/edunivora/auth',
          webMode: false,
        );

        final repo = AuthRepositoryImpl(
          localDataSource,
          AuthGoogleDataSourceImpl(
            browserLauncher: _FakeBrowserLauncher(onLaunch: (_, __) async {}),
          ),
          secureStorage,
          neonAuthDataSource: neonAuth,
        );

        expect(await repo.loginWithEmail('user@edunivora.com', 'pass123'), isTrue);
        expect(
          await secureStorage.getNeonAuthCookie(),
          '__Secure-neon-auth.session_token=email-cookie',
        );

        expect(
          await repo.verifyEmailOtp(email: 'otp@edunivora.com', otp: '123456'),
          isTrue,
        );
        expect(
          await secureStorage.getNeonAuthCookie(),
          '__Secure-neon-auth.session_token=otp-cookie',
        );
      },
    );
  });
}
