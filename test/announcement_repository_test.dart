import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academic_os/data/repositories/announcement_repository.dart';

const _payload = {
  'items': [
    {
      'id': 'f7d0b52a-4a36-4fd9-9ad5-8cbbece8f3d1',
      'title': 'Welcome',
      'body': 'Welcome to EduNivora.',
      'published_at': '2026-11-15T10:30:00.000Z',
    }
  ]
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('fetches public announcements and caches the result', () async {
    final posts = <Uri>[];
    final repository = AnnouncementRepository(
      get: (_) async => jsonEncode(_payload),
      post: (uri) async => posts.add(uri),
      baseUrl: 'https://api.example.test',
    );

    final items = await repository.fetchAnnouncements();
    await Future<void>.delayed(Duration.zero);

    expect(items, hasLength(1));
    expect(items.single.title, 'Welcome');
    expect(posts, hasLength(1));
    expect(posts.single.path, endsWith('/guest-delivered'));
  });

  test('returns the last cached feed when the network is unavailable', () async {
    final first = AnnouncementRepository(
      get: (_) async => jsonEncode(_payload),
      post: (_) async {},
      baseUrl: 'https://api.example.test',
    );
    final initial = await first.fetchAnnouncements();

    final offline = AnnouncementRepository(
      get: (_) async => throw Exception('offline'),
      post: (_) async {},
      baseUrl: 'https://api.example.test',
    );
    final cached = await offline.fetchAnnouncements();

    expect(cached, hasLength(1));
    expect(cached.single.id, initial.single.id);
  });

  test('rejects an unexpected API response when no cache exists', () async {
    final repository = AnnouncementRepository(
      get: (_) async => '{"unexpected":true}',
      post: (_) async {},
      baseUrl: 'https://api.example.test',
    );

    await expectLater(repository.fetchAnnouncements(), throwsFormatException);
  });
}
