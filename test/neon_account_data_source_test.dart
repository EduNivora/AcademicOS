import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/network/platform_http_client.dart';
import 'package:academic_os/data/datasources/neon_account_data_source.dart';

void main() {
  test('loads server-owned role using a bearer token', () async {
    Uri? requestedUri;
    Map<String, String>? requestedHeaders;

    Future<PlatformHttpResponse> request(
      Uri uri, {
      required String method,
      required Map<String, String> headers,
      String? body,
      required bool withCredentials,
    }) async {
      requestedUri = uri;
      requestedHeaders = headers;
      expect(method, 'GET');
      expect(withCredentials, isFalse);
      return const PlatformHttpResponse(
        statusCode: 200,
        body: '{"user":{"id":"profile-1","displayName":"Admin","email":"admin@example.com","role":"admin"}}',
      );
    }

    final source = NeonAccountDataSource(
      request: request,
      baseUrl: 'https://api.example.test',
    );
    final profile = await source.getProfile('jwt-token');

    expect(requestedUri?.path, '/v1/me');
    expect(requestedHeaders?['Authorization'], 'Bearer jwt-token');
    expect(profile['role'], 'admin');
  });

  test('rejects unauthenticated profile requests', () async {
    final source = NeonAccountDataSource(
      request: (_, {
        required String method,
        required Map<String, String> headers,
        String? body,
        required bool withCredentials,
      }) async => const PlatformHttpResponse(
        statusCode: 401,
        body: '{"error":{"code":"unauthorized","message":"Sign-in is required."}}',
      ),
      baseUrl: 'https://api.example.test',
    );

    await expectLater(
      source.getProfile('expired-token'),
      throwsA(isA<NeonAccountException>()
          .having((error) => error.statusCode, 'statusCode', 401)),
    );
  });
}
