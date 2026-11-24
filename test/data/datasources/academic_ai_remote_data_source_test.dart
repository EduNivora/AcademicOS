import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/network/platform_http_types.dart';
import 'package:academic_os/data/datasources/academic_ai_remote_data_source.dart';

void main() {
  group('AcademicAiRemoteDataSource', () {
    test(
      'sends the bearer token and academic context to the deployed API',
      () async {
        Uri? requestedUri;
        Map<String, String>? requestedHeaders;
        Map<String, dynamic>? requestedBody;
        bool? sentWithCredentials;

        final source = AcademicAiRemoteDataSource(
          baseUrl: 'https://ai.example.test/',
          request:
              (
                uri, {
                required method,
                required headers,
                body,
                required withCredentials,
              }) async {
                requestedUri = uri;
                requestedHeaders = headers;
                requestedBody = jsonDecode(body!) as Map<String, dynamic>;
                sentWithCredentials = withCredentials;
                expect(method, 'POST');
                return const PlatformHttpResponse(
                  statusCode: 200,
                  body: '{"answer":"شرح واضح"}',
                );
              },
        );

        final answer = await source.sendMessage(
          accessToken: 'neon-session-jwt',
          message: 'اشرح قواعد البيانات',
          context: '{"courses":[{"name":"Database"}]}',
        );

        expect(answer, 'شرح واضح');
        expect(requestedUri.toString(), 'https://ai.example.test/v1/chat');
        expect(requestedHeaders!['Authorization'], 'Bearer neon-session-jwt');
        expect(requestedHeaders!['Content-Type'], 'application/json');
        expect(requestedBody!['message'], 'اشرح قواعد البيانات');
        expect(requestedBody!['context'], contains('Database'));
        expect(sentWithCredentials, isFalse);
      },
    );

    test('maps server errors to a safe localized exception', () async {
      final source = AcademicAiRemoteDataSource(
        request:
            (
              _, {
              required method,
              required headers,
              body,
              required withCredentials,
            }) async => const PlatformHttpResponse(
              statusCode: 503,
              body:
                  '{"error":{"code":"ai_not_configured","message":"المفتاح غير مضبوط"}}',
            ),
      );

      await expectLater(
        source.sendMessage(
          accessToken: 'neon-session-jwt',
          message: 'اختبر الاتصال',
        ),
        throwsA(
          isA<AcademicAiRemoteException>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having((error) => error.code, 'code', 'ai_not_configured')
              .having((error) => error.message, 'message', 'المفتاح غير مضبوط'),
        ),
      );
    });

    test('preserves the server quota response and retry message', () async {
      final source = AcademicAiRemoteDataSource(
        request:
            (
              _, {
              required method,
              required headers,
              body,
              required withCredentials,
            }) async => const PlatformHttpResponse(
              statusCode: 429,
              body:
                  '{"error":{"code":"ai_quota_exceeded","message":"وصلت إلى الحد اليومي لاستخدام المساعد. حاول غدًا."}}',
            ),
      );

      await expectLater(
        source.sendMessage(accessToken: 'neon-session-jwt', message: 'سؤال'),
        throwsA(
          isA<AcademicAiRemoteException>()
              .having((error) => error.statusCode, 'statusCode', 429)
              .having((error) => error.code, 'code', 'ai_quota_exceeded')
              .having(
                (error) => error.message,
                'message',
                'وصلت إلى الحد اليومي لاستخدام المساعد. حاول غدًا.',
              ),
        ),
      );
    });

    test('rejects an empty access token without making a request', () async {
      var requestCalled = false;
      final source = AcademicAiRemoteDataSource(
        request:
            (
              _, {
              required method,
              required headers,
              body,
              required withCredentials,
            }) async {
              requestCalled = true;
              return const PlatformHttpResponse(
                statusCode: 200,
                body: '{"answer":"x"}',
              );
            },
      );

      await expectLater(
        source.sendMessage(accessToken: ' ', message: 'سؤال'),
        throwsA(
          isA<AcademicAiRemoteException>().having(
            (error) => error.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
      expect(requestCalled, isFalse);
    });

    test(
      'reports Gemini as ready only when the health endpoint is configured',
      () async {
        final source = AcademicAiRemoteDataSource(
          baseUrl: 'https://ai.example.test',
          request:
              (
                uri, {
                required method,
                required headers,
                body,
                required withCredentials,
              }) async {
                expect(uri.path, '/health');
                expect(method, 'GET');
                expect(withCredentials, isFalse);
                return const PlatformHttpResponse(
                  statusCode: 200,
                  body:
                      '{"ok":true,"service":"edunivora-ai","configured":true}',
                );
              },
        );

        expect(await source.isConfigured(), isTrue);
      },
    );

    test('reports Gemini as not ready when the server key is absent', () async {
      final source = AcademicAiRemoteDataSource(
        request:
            (
              _, {
              required method,
              required headers,
              body,
              required withCredentials,
            }) async => const PlatformHttpResponse(
              statusCode: 200,
              body: '{"ok":true,"service":"edunivora-ai","configured":false}',
            ),
      );

      expect(await source.isConfigured(), isFalse);
    });

    test(
      'uploads an authenticated image and returns parsed schedule rows',
      () async {
        Uri? requestedUri;
        Map<String, String>? requestedHeaders;
        Map<String, dynamic>? requestedBody;
        final source = AcademicAiRemoteDataSource(
          baseUrl: 'https://ai.example.test',
          request:
              (
                uri, {
                required method,
                required headers,
                body,
                required withCredentials,
              }) async {
                requestedUri = uri;
                requestedHeaders = headers;
                requestedBody = jsonDecode(body!) as Map<String, dynamic>;
                expect(method, 'POST');
                expect(withCredentials, isFalse);
                return const PlatformHttpResponse(
                  statusCode: 200,
                  body:
                      '{"entries":[{"day":"الأحد","course_name":"أمن الشبكات","start_time":"08:00","end_time":"09:30","location":"قاعة 2"}]}',
                );
              },
        );

        final entries = await source.parseScheduleImage(
          accessToken: 'neon-session-jwt',
          imageBytes: [1, 2, 3],
          mimeType: 'image/png',
        );

        expect(
          requestedUri.toString(),
          'https://ai.example.test/v1/schedule/parse',
        );
        expect(requestedHeaders!['Authorization'], 'Bearer neon-session-jwt');
        expect(requestedBody!['mimeType'], 'image/png');
        expect(requestedBody!['image'], base64Encode([1, 2, 3]));
        expect(entries.single['course_name'], 'أمن الشبكات');
      },
    );

    test(
      'rejects image parsing without authentication or a valid image',
      () async {
        var requestCalled = false;
        final source = AcademicAiRemoteDataSource(
          request:
              (
                _, {
                required method,
                required headers,
                body,
                required withCredentials,
              }) async {
                requestCalled = true;
                return const PlatformHttpResponse(
                  statusCode: 200,
                  body: '{"entries":[]}',
                );
              },
        );

        await expectLater(
          source.parseScheduleImage(
            accessToken: '',
            imageBytes: [1],
            mimeType: 'image/png',
          ),
          throwsA(isA<AcademicAiRemoteException>()),
        );
        await expectLater(
          source.parseScheduleImage(
            accessToken: 'neon-session-jwt',
            imageBytes: [1],
            mimeType: 'application/pdf',
          ),
          throwsA(isA<AcademicAiRemoteException>()),
        );
        expect(requestCalled, isFalse);
      },
    );
  });
}
