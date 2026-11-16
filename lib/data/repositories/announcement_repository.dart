import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/edunivora_api_config.dart';
import '../../core/network/platform_http_client.dart';
import '../models/announcement.dart';

typedef AnnouncementGet = Future<String> Function(Uri uri);
typedef AnnouncementPost = Future<void> Function(Uri uri);
typedef AnnouncementAuthenticatedPost = Future<void> Function(
  Uri uri,
  String accessToken,
);

class AnnouncementRepository {
  static const String _cacheKey = 'edunivora_public_announcements_v1';
  static const String _guestDeliveredIdsKey =
      'edunivora_guest_delivered_ids_v1';
  static const int _maxRememberedGuestDeliveries = 500;

  final AnnouncementGet _get;
  final AnnouncementPost _post;
  final AnnouncementAuthenticatedPost _authenticatedPost;
  final Future<String?> Function()? _getAccessToken;
  final String _baseUrl;
  final String _guestMetricsBaseUrl;
  final Set<String> _deliveredInSession = <String>{};

  AnnouncementRepository({
    AnnouncementGet? get,
    AnnouncementPost? post,
    AnnouncementAuthenticatedPost? authenticatedPost,
    Future<String?> Function()? getAccessToken,
    String baseUrl = EdunivoraApiConfig.noticesBaseUrl,
    String guestMetricsBaseUrl = EdunivoraApiConfig.guestMetricsProxyBaseUrl,
  })  : _get = get ?? platformGet,
        _post = post ?? platformPost,
        _authenticatedPost = authenticatedPost ?? _platformAuthenticatedPost,
        _getAccessToken = getAccessToken,
        _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _guestMetricsBaseUrl =
            guestMetricsBaseUrl.replaceFirst(RegExp(r'/+$'), '');

  Uri _endpoint(String path) => Uri.parse('$_baseUrl$path');

  Uri? _guestMetricsEndpoint(String path) {
    if (_guestMetricsBaseUrl.isEmpty) return null;
    return Uri.parse('$_guestMetricsBaseUrl$path');
  }

  static Future<void> _platformAuthenticatedPost(
    Uri uri,
    String accessToken,
  ) async {
    final response = await platformRequest(
      uri,
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      withCredentials: false,
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Announcement acknowledgement failed.');
    }
  }

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
      await _recordDeliveries(announcements);
      return announcements;
    } catch (_) {
      final cached = await _readCache();
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<void> recordOpened(String announcementId) async {
    String? accessToken;
    try {
      accessToken = await _getAccessToken?.call();
    } catch (_) {
      return;
    }

    if (accessToken != null && accessToken.isNotEmpty) {
      await _authenticatedPost(
        _endpoint('/v1/announcements/$announcementId/read'),
        accessToken,
      ).timeout(const Duration(seconds: 12));
      return;
    }

    // Guest metric writes are disabled unless the dedicated Cloudflare
    // proxy is configured. Never fall back to the public Neon Function URL.
    final metricEndpoint = _guestMetricsEndpoint(
      '/v1/announcements/$announcementId/guest-view',
    );
    if (metricEndpoint == null) return;
    await _post(metricEndpoint).timeout(const Duration(seconds: 12));
  }

  Future<void> _recordDeliveries(
    List<Announcement> announcements,
  ) async {
    String? accessToken;
    try {
      accessToken = await _getAccessToken?.call();
    } catch (_) {
      return;
    }

    if (accessToken != null && accessToken.isNotEmpty) {
      for (final announcement in announcements) {
        unawaited(_sendRegisteredDelivery(announcement, accessToken));
      }
      return;
    }

    await _recordGuestDeliveries(announcements);
  }

  Future<void> _sendRegisteredDelivery(
    Announcement announcement,
    String accessToken,
  ) async {
    try {
      await _authenticatedPost(
        _endpoint('/v1/announcements/${announcement.id}/delivered'),
        accessToken,
      ).timeout(const Duration(seconds: 12));
    } catch (_) {
      // The API endpoint is idempotent; the next feed fetch retries.
    }
  }

  Future<void> _recordGuestDeliveries(
    List<Announcement> announcements,
  ) async {
    // Missing proxy configuration is a deliberate no-op, not a direct Neon
    // fallback. Feed reading and local caching are independent of metrics.
    if (_guestMetricsBaseUrl.isEmpty) return;

    Set<String> persistedIds;
    try {
      final preferences = await SharedPreferences.getInstance();
      persistedIds = (preferences.getStringList(_guestDeliveredIdsKey) ??
              const <String>[])
          .toSet();
    } catch (_) {
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
      final metricEndpoint = _guestMetricsEndpoint(
        '/v1/announcements/${announcement.id}/guest-delivered',
      );
      if (metricEndpoint == null) return;
      await _post(metricEndpoint).timeout(const Duration(seconds: 12));
    } catch (_) {
      _deliveredInSession.remove(announcement.id);
      return;
    }

    persistedIds.add(announcement.id);
    try {
      final preferences = await SharedPreferences.getInstance();
      final retained = persistedIds.toList(growable: false);
      final bounded = retained.length > _maxRememberedGuestDeliveries
          ? retained.sublist(retained.length - _maxRememberedGuestDeliveries)
          : retained;
      await preferences.setStringList(_guestDeliveredIdsKey, bounded);
    } catch (_) {
      // Keep the in-memory marker even if durable preference storage fails.
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
