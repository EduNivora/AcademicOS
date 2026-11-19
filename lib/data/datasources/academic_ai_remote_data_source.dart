import 'dart:convert';

import '../../core/config/edunivora_api_config.dart';
import '../../core/network/platform_http_client.dart';

class AcademicAiRemoteException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const AcademicAiRemoteException(this.statusCode, this.code, this.message);

  @override
  String toString() => message;
}

class AcademicAiRemoteDataSource {
  final PlatformHttpRequest _request;
  final String _baseUrl;

  AcademicAiRemoteDataSource({
    PlatformHttpRequest? request,
    String baseUrl = EdunivoraApiConfig.aiBaseUrl,
  })  : _request = request ?? platformRequest,
        _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  Future<String> sendMessage({
    required String accessToken,
    required String message,
    String context = '',
  }) async {
    if (accessToken.trim().isEmpty) {
      throw const AcademicAiRemoteException(
        401,
        'unauthorized',
        'سجّل الدخول بحسابك لاستخدام المساعد السحابي.',
      );
    }

    final response = await _request(
      Uri.parse('$_baseUrl/v1/chat'),
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'message': message,
        if (context.isNotEmpty) 'context': context,
      }),
      withCredentials: false,
    );

    Map<String, dynamic> decoded;
    try {
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid AI response shape.');
      }
      decoded = value;
    } catch (_) {
      throw const AcademicAiRemoteException(
        502,
        'invalid_response',
        'وصل رد غير مفهوم من خدمة المساعد.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final code = error is Map ? error['code']?.toString() ?? 'ai_error' : 'ai_error';
      final message = error is Map
          ? error['message']?.toString() ?? 'تعذر تنفيذ الطلب.'
          : 'تعذر تنفيذ الطلب.';
      throw AcademicAiRemoteException(response.statusCode, code, message);
    }

    final answer = decoded['answer'];
    if (answer is! String || answer.trim().isEmpty) {
      throw const AcademicAiRemoteException(
        502,
        'empty_answer',
        'لم يُرجع المساعد إجابة صالحة.',
      );
    }
    return answer.trim();
  }
}
