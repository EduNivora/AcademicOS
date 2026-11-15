import 'dart:convert';
import 'dart:typed_data';

import 'package:academic_os/data/services/google_drive_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GoogleDriveBackupService', () {
    test('reuses the existing visible EduNivora folder', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers['authorization'], 'Bearer test-token');
        expect(request.url.path, '/drive/v3/files');
        expect(request.url.queryParameters['q'], contains("name = 'EduNivora'"));
        return http.Response(
          jsonEncode({
            'files': [
              {
                'id': 'folder-123',
                'name': 'EduNivora',
                'mimeType': 'application/vnd.google-apps.folder',
              }
            ]
          }),
          200,
        );
      });
      final service = GoogleDriveBackupService(
        accessTokenProvider: () async => 'test-token',
        client: client,
      );

      expect(await service.ensureBackupFolder(), 'folder-123');
      service.close();
    });

    test('creates the visible EduNivora folder when it does not exist', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) return http.Response('{"files":[]}', 200);
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['name'], 'EduNivora');
        expect(body['mimeType'], 'application/vnd.google-apps.folder');
        return http.Response('{"id":"new-folder"}', 200);
      });
      final service = GoogleDriveBackupService(
        accessTokenProvider: () async => 'test-token',
        client: client,
      );

      expect(await service.ensureBackupFolder(), 'new-folder');
      expect(calls, 2);
      service.close();
    });

    test('uploads an encrypted archive using a resumable session', () async {
      final archive = Uint8List.fromList(List<int>.generate(1024, (i) => i % 256));
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) {
          expect(request.method, 'POST');
          expect(request.url.queryParameters['uploadType'], 'resumable');
          expect(request.headers['x-upload-content-length'], '1024');
          final metadata = jsonDecode(request.body) as Map<String, dynamic>;
          expect(metadata['parents'], ['folder-1']);
          expect(metadata['name'], 'backup.edunivora');
          return http.Response(
            '',
            200,
            headers: {'location': 'https://www.googleapis.com/upload/session-1'},
          );
        }
        expect(request.method, 'PUT');
        expect(request.headers['content-range'], 'bytes 0-1023/1024');
        expect(request.bodyBytes, archive);
        return http.Response('{"id":"file-1"}', 200);
      });
      final service = GoogleDriveBackupService(
        accessTokenProvider: () async => 'test-token',
        client: client,
      );

      expect(
        await service.uploadEncryptedArchive(
          archive: archive,
          fileName: 'backup.edunivora',
          folderId: 'folder-1',
        ),
        'file-1',
      );
      expect(calls, 2);
      service.close();
    });

    test('continues a resumable upload from the acknowledged byte range', () async {
      final archive = Uint8List(8 * 1024 * 1024 + 512);
      var putCount = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            '',
            200,
            headers: {'location': 'https://www.googleapis.com/upload/session-2'},
          );
        }
        putCount++;
        if (putCount == 1) {
          expect(request.headers['content-range'], 'bytes 0-8388607/8389120');
          return http.Response('', 308, headers: {'range': 'bytes=0-8388607'});
        }
        expect(request.headers['content-range'], 'bytes 8388608-8389119/8389120');
        return http.Response('{"id":"resumed-file"}', 200);
      });
      final service = GoogleDriveBackupService(
        accessTokenProvider: () async => 'test-token',
        client: client,
      );

      expect(
        await service.uploadEncryptedArchive(
          archive: archive,
          fileName: 'large-backup.edunivora',
          folderId: 'folder-1',
        ),
        'resumed-file',
      );
      expect(putCount, 2);
      service.close();
    });

    test('rejects a resumable session URL outside the Google API host', () async {
      final client = MockClient((request) async => http.Response(
            '',
            200,
            headers: {'location': 'https://attacker.example/upload/session'},
          ));
      final service = GoogleDriveBackupService(
        accessTokenProvider: () async => 'test-token',
        client: client,
      );

      await expectLater(
        service.uploadEncryptedArchive(
          archive: Uint8List.fromList([1]),
          fileName: 'backup.edunivora',
          folderId: 'folder-1',
        ),
        throwsFormatException,
      );
      service.close();
    });

    test('downloads archive bytes without decoding or modifying them', () async {
      final expected = Uint8List.fromList([0, 1, 2, 255, 17]);
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.queryParameters['alt'], 'media');
        expect(request.headers['authorization'], 'Bearer test-token');
        return http.Response.bytes(expected, 200);
      });
      final service = GoogleDriveBackupService(
        accessTokenProvider: () async => 'test-token',
        client: client,
      );

      expect(await service.downloadArchive('file-123'), expected);
      service.close();
    });

    test('lists only EduNivora encrypted archive files', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['q'], contains("'folder-1' in parents"));
        return http.Response(
          jsonEncode({
            'files': [
              {'id': 'a', 'name': 'backup-a.edunivora'},
              {'id': 'b', 'name': 'notes.txt'},
              {'id': 'c', 'name': 'backup-c.edunivora'},
            ]
          }),
          200,
        );
      });
      final service = GoogleDriveBackupService(
        accessTokenProvider: () async => 'test-token',
        client: client,
      );

      final backups = await service.listBackups('folder-1');
      expect(backups.map((item) => item['id']).toList(), ['a', 'c']);
      service.close();
    });

    test('rejects Drive calls when OAuth authorization is unavailable', () async {
      final service = GoogleDriveBackupService(
        accessTokenProvider: () async => null,
        client: MockClient((_) async => http.Response('', 500)),
      );

      await expectLater(
        service.ensureBackupFolder(),
        throwsA(isA<GoogleDriveAuthorizationException>()),
      );
      service.close();
    });

    test('rejects unsafe archive names and invalid sizes before network calls', () async {
      final service = GoogleDriveBackupService(
        accessTokenProvider: () async => 'test-token',
        client: MockClient((_) async => fail('Unexpected network call')),
      );

      await expectLater(
        service.uploadEncryptedArchive(
          archive: Uint8List.fromList([1]),
          fileName: '../backup.edunivora',
          folderId: 'folder-1',
        ),
        throwsFormatException,
      );
      await expectLater(
        service.uploadEncryptedArchive(
          archive: Uint8List(0),
          fileName: 'backup.edunivora',
          folderId: 'folder-1',
        ),
        throwsFormatException,
      );
      service.close();
    });
  });
}
