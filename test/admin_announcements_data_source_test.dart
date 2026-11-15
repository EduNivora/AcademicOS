import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/network/platform_http_client.dart';
import 'package:academic_os/data/datasources/admin_announcements_data_source.dart';

void main() {
  test('lists announcements using the authenticated admin endpoint', () async {
    Uri? requestedUri;
    Map<String, String>? requestedHeaders;
    final source = AdminAnnouncementsDataSource(
      baseUrl: 'https://api.example.test',
      request: (uri, {
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
          body: '{"items":[{"id":"notice-1","title":"Exam","body":"Exam notice","status":"draft"}]}',
        );
      },
    );

    final items = await source.list(accessToken: 'admin-jwt', status: 'draft');

    expect(requestedUri?.path, '/v1/admin/announcements');
    expect(requestedUri?.queryParameters['status'], 'draft');
    expect(requestedHeaders?['Authorization'], 'Bearer admin-jwt');
    expect(items.single['id'], 'notice-1');
  });

  test('surfaces forbidden responses without pretending to authorize client',
      () async {
    final source = AdminAnnouncementsDataSource(
      baseUrl: 'https://api.example.test',
      request: (_, {
        required String method,
        required Map<String, String> headers,
        String? body,
        required bool withCredentials,
      }) async => const PlatformHttpResponse(
        statusCode: 403,
        body: '{"error":{"code":"forbidden","message":"Administrator access is required."}}',
      ),
    );

    await expectLater(
      source.list(accessToken: 'ordinary-user-jwt'),
      throwsA(isA<AdminAnnouncementsException>()
          .having((error) => error.statusCode, 'statusCode', 403)),
    );
  });
}
