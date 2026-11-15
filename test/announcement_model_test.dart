import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/data/models/announcement.dart';

void main() {
  group('Announcement', () {
    test('parses a valid published announcement', () {
      final announcement = Announcement.fromJson({
        'id': 'f7d0b52a-4a36-4fd9-9ad5-8cbbece8f3d1',
        'title': 'Important notice',
        'body': 'The exam date has changed.',
        'published_at': '2026-11-15T10:30:00.000Z',
      });

      expect(announcement.title, 'Important notice');
      expect(announcement.body, 'The exam date has changed.');
      expect(announcement.publishedAt.isUtc, isFalse);
    });

    test('rejects missing or invalid required fields', () {
      expect(
        () => Announcement.fromJson({
          'id': 'id',
          'title': '',
          'body': 'Text',
          'published_at': 'not-a-date',
        }),
        throwsFormatException,
      );
    });

    test('serializes a cache-safe JSON representation', () {
      final announcement = Announcement(
        id: 'notice-1',
        title: 'Title',
        body: 'Body',
        publishedAt: DateTime.utc(2026, 11, 15),
      );

      expect(announcement.toJson()['published_at'], '2026-11-15T00:00:00.000Z');
    });
  });
}
