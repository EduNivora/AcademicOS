import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/ai/ai_chat_event.dart';
import 'google_id_token_provider.dart';

class AIGatewayDataSource {
  AIGatewayDataSource({
    required GoogleIdTokenProvider tokenProvider,
    http.Client? client,
    String? baseUrl,
  })  : _tokenProvider = tokenProvider,
        _client = client ?? http.Client(),
        _baseUrl = (baseUrl ??
                const String.fromEnvironment('EDUNIVORA_AI_BASE_URL'))
            .replaceFirst(RegExp(r'/+$'), '');

  final GoogleIdTokenProvider _tokenProvider;
  final http.Client _client;
  final String _baseUrl;

  Stream<AIChatEvent> streamMessage({
    required String message,
    String? conversationId,
  }) async* {
    if (_baseUrl.isEmpty) {
      throw StateError(
        'خدمة EduNivora AI غير مهيأة. أضف EDUNIVORA_AI_BASE_URL عند البناء.',
      );
    }

    final token = await _tokenProvider.requireIdToken();
    final request = http.Request(
      'POST',
      Uri.parse('$_baseUrl/v1/chat/stream'),
    )
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      })
      ..body = jsonEncode({
        'message': message,
        if (conversationId != null) 'conversationId': conversationId,
      });

    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      var messageText = 'تعذر الاتصال بالمساعد (HTTP ${response.statusCode}).';
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['message'] is String) {
          messageText = decoded['message'] as String;
        }
      } catch (_) {
        // Keep the safe, user-facing fallback.
      }
      throw Exception(messageText);
    }

    String eventName = 'message';
    final dataLines = <String>[];
    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (dataLines.isNotEmpty) {
          final payload = jsonDecode(dataLines.join('\n'));
          if (payload is Map<String, dynamic>) {
            switch (eventName) {
              case 'meta':
                yield AIChatEvent(
                  type: AIChatEventType.meta,
                  conversationId: payload['conversationId'] as String?,
                );
                break;
              case 'delta':
                yield AIChatEvent(
                  type: AIChatEventType.delta,
                  text: payload['text'] as String? ?? '',
                );
                break;
              case 'done':
                yield AIChatEvent(
                  type: AIChatEventType.done,
                  conversationId: payload['conversationId'] as String?,
                );
                break;
              case 'error':
                yield AIChatEvent(
                  type: AIChatEventType.error,
                  message: payload['message'] as String? ?? 'حدث خطأ أثناء التوليد.',
                );
                break;
            }
          }
        }
        eventName = 'message';
        dataLines.clear();
      } else if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
  }

  void dispose() => _client.close();
}