import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/ai_gateway_data_source.dart';
import '../data/datasources/google_id_token_provider.dart';
import '../data/repositories/ai_chat_repository_impl.dart';
import '../domain/repositories/ai_chat_repository.dart';

final aiChatRepositoryProvider = Provider<AIChatRepository>((ref) {
  final dataSource = AIGatewayDataSource(
    tokenProvider: GoogleIdTokenProvider(),
  );
  ref.onDispose(dataSource.dispose);
  return AIChatRepositoryImpl(dataSource);
});