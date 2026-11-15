import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/edunivora_api_config.dart';
import '../../core/network/platform_http_client.dart';
import '../models/announcement.dart';

typedef AnnouncementGet = Future<String> Function(Uri uri);
typedef AnnouncementPost = Future<void> Function(Uri uri);

class AnnouncementRepository {
  static const String _cacheKey = 'edunivora_public_announcements_v1';
  static const String _guestDeliveredIdsKey =
      'edunivora_guest_delivered_ids_v1';
  static const int _maxRememberedGuestDeliveries = 500;

  final AnnouncementGet _get;
  final AnnouncementPost _post;
  final String _baseUrl;
  final Set<String> _deliveredInSession = <String>{};

  AnnouncementRepository({
    AnnouncementGet? get,
    AnnouncementPost? post,
    String baseUrl = EdunivoraApiConfig.noticesBaseUrl,
  })  : _get = get ?? platformGet,
        _post = post ?? platformPost,
        _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  Uri _endpoint(String path) => Uri.parse('$_baseUrl$path');

  Future<List<Announcement>> fetchAnnouncements() async {
    try {
      final raw = await _get(
        _endpoint('/v1/announcements?limit=50'),
      ).timeout(const Duration(seconds: 18));
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['items'] is! List) {
        throw const FormatException('Unexpected announcements response.');
      }

      final announcements = (decoded['items'] as List)
          .map(
            (item) => Announcement.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);

      await _writeCache(announcements);
      await _recordGuestDeliveries(announcements);
      return announcements;
    } catch (_) {
      final cached = await _readCache();
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<void> recordGuestView(String announcementId) async {
    await _post(
      _endpoint('/v1/announcements/$announcementId/guest-view'),
    ).timeout(const Duration(seconds: 12));
  }

  Future<void> _recordGuestDeliveries(
    List<Announcement> announcements,
  ) async {
    Set<String> persistedIds;
    try {
      final preferences = await SharedPreferences.getInstance();
      persistedIds = (preferences.getStringList(_guestDeliveredIdsKey) ??
              const <String>[])
          .toSet();
    } catch (_) {
      // Continue with in-memory deduplication if local preferences are unavailable.
      persistedIds = <String>{};
    }

    for (final announcement in announcements) {
      final id = announcement.id;
      if (persistedIds.contains(id) || !_deliveredInSession.add(id)) {
        continue;
      }
      unawaited(_sendGuestDelivery(announcement, persistedIds));
    }
  }

  Future<void> _sendGuestDelivery(
    Announcement announcement,
    Set<String> persistedIds,
  ) async {
    try {
      await _post(
        _endpoint(
          '/v1/announcements/${announcement.id}/guest-delivered',
        ),
      ).timeout(const Duration(seconds: 12));

      persistedIds.add(announcement.id);
      final preferences = await SharedPreferences.getInstance();
      final retained = persistedIds.toList(growable: false);
      final bounded = retained.length > _maxRememberedGuestDeliveries
          ? retained.sublist(retained.length - _maxRememberedGuestDeliveries)
          : retained;
      await preferences.setStringList(_guestDeliveredIdsKey, bounded);
    } catch (_) {
      // A failed acknowledgement remains eligible for retry on a later fetch.
      _deliveredInSession.remove(announcement.id);
    }
  }

  Future<void> _writeCache(List<Announcement> announcements) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _cacheKey,
        jsonEncode(announcements.map((item) => item.toJson()).toList()),
      );
    } catch (_) {
      // A cache write failure must not hide a successful network response.
    }
  }

  Future<List<Announcement>?> _readCache() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .map(
            (item) => Announcement.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }
}
