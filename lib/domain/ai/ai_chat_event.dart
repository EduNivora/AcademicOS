enum AIChatEventType { meta, delta, done, error }

class AIChatEvent {
  final AIChatEventType type;
  final String? text;
  final String? conversationId;
  final String? message;

  const AIChatEvent({
    required this.type,
    this.text,
    this.conversationId,
    this.message,
  });
}