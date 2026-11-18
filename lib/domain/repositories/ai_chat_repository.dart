import '../ai/ai_chat_event.dart';

abstract class AIChatRepository {
  Stream<AIChatEvent> sendMessage({
    required String message,
    String? conversationId,
  });
}