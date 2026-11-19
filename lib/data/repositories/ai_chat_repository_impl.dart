import '../../domain/ai/ai_chat_event.dart';
import '../../domain/repositories/ai_chat_repository.dart';
import '../datasources/ai_gateway_data_source.dart';

class AIChatRepositoryImpl implements AIChatRepository {
  const AIChatRepositoryImpl(this._dataSource);

  final AIGatewayDataSource _dataSource;

  @override
  Stream<AIChatEvent> sendMessage({
    required String message,
    String? conversationId,
  }) {
    return _dataSource.streamMessage(
      message: message,
      conversationId: conversationId,
    );
  }
}