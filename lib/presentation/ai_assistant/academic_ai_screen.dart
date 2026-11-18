import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ai/ai_chat_event.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/task_entity.dart';
import '../../data/models/exam_model.dart';
import '../../providers/ai_chat_provider.dart';

class AcademicAiScreen extends ConsumerStatefulWidget {
  final List<CourseEntity> courses;
  final List<TaskEntity> tasks;
  final List<ExamModel> exams;

  const AcademicAiScreen({
    super.key,
    this.courses = const [],
    this.tasks = const [],
    this.exams = const [],
  });

  @override
  ConsumerState<AcademicAiScreen> createState() => _AcademicAiScreenState();
}

class _AcademicAiScreenState extends ConsumerState<AcademicAiScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: 'مرحباً! أنا EduNivora Academic AI. أرسل سؤالك وسأحاول مساعدتك بشرح أكاديمي واضح.',
      isUser: false,
    ),
  ];

  final List<String> _suggestedPrompts = [
    'اشرح لي مفهوم التشفير المتماثل مع مثال',
    'أنشئ اختباراً قصيراً عن أمن الشبكات',
    'لخص الفرق بين TCP و UDP',
    'ساعدني في وضع خطة مذاكرة لمدة ثلاثة أيام',
  ];

  StreamSubscription<AIChatEvent>? _subscription;
  String? _conversationId;
  bool _isGenerating = false;

  @override
  void dispose() {
    _subscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isGenerating) return;

    _messageController.clear();
    final assistantIndex = _messages.length + 1;
    setState(() {
      _messages.add(_ChatMessage(text: trimmed, isUser: true));
      _messages.add(_ChatMessage(text: '', isUser: false));
      _isGenerating = true;
    });
    _scrollToBottom();

    try {
      final stream = ref.read(aiChatRepositoryProvider).sendMessage(
            message: trimmed,
            conversationId: _conversationId,
          );
      _subscription = stream.listen(
        (event) {
          if (!mounted) return;
          setState(() {
            switch (event.type) {
              case AIChatEventType.meta:
                _conversationId = event.conversationId ?? _conversationId;
                break;
              case AIChatEventType.delta:
                _messages[assistantIndex].text += event.text ?? '';
                break;
              case AIChatEventType.done:
                _conversationId = event.conversationId ?? _conversationId;
                _isGenerating = false;
                break;
              case AIChatEventType.error:
                _messages[assistantIndex].text =
                    event.message ?? 'تعذر إكمال الإجابة. حاول مرة أخرى.';
                _isGenerating = false;
                break;
            }
          });
          _scrollToBottom();
        },
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _messages[assistantIndex].text =
                'تعذر الاتصال بالمساعد: ${error.toString().replaceFirst('Exception: ', '')}';
            _isGenerating = false;
          });
        },
        onDone: () {
          if (mounted && _isGenerating) {
            setState(() => _isGenerating = false);
          }
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages[assistantIndex].text =
            'تعذر بدء الاتصال بالمساعد: ${error.toString().replaceFirst('Exception: ', '')}';
        _isGenerating = false;
      });
    }
  }

  Future<void> _stopGeneration() async {
    await _subscription?.cancel();
    _subscription = null;
    if (mounted) setState(() => _isGenerating = false);
  }

  void _startNewConversation() {
    if (_isGenerating) return;
    setState(() {
      _conversationId = null;
      _messages
        ..clear()
        ..add(const _ChatMessage(
          text: 'بدأت محادثة جديدة. ما الموضوع الذي تريد دراسته؟',
          isUser: false,
        ));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المساعد الأكاديمي الذكي'),
        actions: [
          IconButton(
            tooltip: 'محادثة جديدة',
            onPressed: _startNewConversation,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Icon(
                  _isGenerating ? Icons.sync_rounded : Icons.shield_outlined,
                  color: Colors.blueGrey,
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isGenerating
                        ? 'يتم توليد الإجابة من خدمة الذكاء الاصطناعي...'
                        : 'تُرسل الرسائل إلى خدمة الذكاء الاصطناعي عند الطلب',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _suggestedPrompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final prompt = _suggestedPrompts[index];
                return ActionChip(
                  label: Text(prompt, style: const TextStyle(fontSize: 12)),
                  onPressed: _isGenerating ? null : () => _sendPrompt(prompt),
                  backgroundColor: Colors.indigo.shade50,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    decoration: BoxDecoration(
                      color: message.isUser
                          ? Colors.blue.shade600
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: message.isUser
                            ? Colors.blue.shade500
                            : Theme.of(context).dividerColor,
                      ),
                    ),
                    child: message.text.isEmpty && _isGenerating && index == _messages.length - 1
                        ? const SizedBox(
                            width: 34,
                            height: 22,
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : SelectableText(
                            message.text,
                            style: TextStyle(
                              color: message.isUser
                                  ? Colors.white
                                  : Theme.of(context).textTheme.bodyLarge?.color,
                              height: 1.55,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  offset: const Offset(0, -3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isGenerating,
                    minLines: 1,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'اكتب طلبك أو سؤالك...',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: _sendPrompt,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: 'academic-ai-send',
                  onPressed: _isGenerating
                      ? _stopGeneration
                      : () => _sendPrompt(_messageController.text),
                  child: Icon(_isGenerating ? Icons.stop_rounded : Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});

  const _ChatMessage.initial({required this.text, required this.isUser});
}
