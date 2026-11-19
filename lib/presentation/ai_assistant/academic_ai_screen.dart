import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/academic/academic_assistant_service.dart';
import '../../data/datasources/academic_ai_remote_data_source.dart';
import '../../data/models/exam_model.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/usecases/auth_use_cases.dart';

class AcademicAiScreen extends StatefulWidget {
  final List<CourseEntity> courses;
  final List<TaskEntity> tasks;
  final List<ExamModel> exams;
  final AuthUseCases? authUseCases;

  const AcademicAiScreen({
    super.key,
    this.courses = const [],
    this.tasks = const [],
    this.exams = const [],
    this.authUseCases,
  });

  @override
  State<AcademicAiScreen> createState() => _AcademicAiScreenState();
}

class _AcademicAiScreenState extends State<AcademicAiScreen> {
  final TextEditingController _messageController = TextEditingController();
  final AcademicAiRemoteDataSource _remote = AcademicAiRemoteDataSource();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: 'مرحباً، أنا المساعد الأكاديمي في EduNivora. أستطيع مساعدتك في فهم المواد وتنظيم المهام والاستعداد للاختبارات.',
      isUser: false,
    ),
  ];

  final List<String> _suggestedPrompts = [
    'كم باقي على أول اختبار وماذا أحتاج للمذاكرة؟',
    'احسب متوسط درجاتي الحالية',
    'وزع لي خطة مذاكرة لمادة التشفير خلال 3 أيام',
    'ما أهم مهمة يجب أن أبدأ بها اليوم؟',
  ];

  bool _isSending = false;
  bool _isCheckingSession = true;
  bool _hasCloudSession = false;
  bool _isGeminiReady = false;

  @override
  void initState() {
    super.initState();
    _refreshSessionState();
  }

  Future<void> _refreshSessionState() async {
    try {
      final token = await widget.authUseCases?.getCloudAccessToken.call();
      final hasSession = token != null && token.isNotEmpty;
      final configured = hasSession && await _remote.isConfigured();
      if (!mounted) return;
      setState(() {
        _hasCloudSession = hasSession;
        _isGeminiReady = configured;
        _isCheckingSession = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasCloudSession = false;
        _isGeminiReady = false;
        _isCheckingSession = false;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage(text: trimmed, isUser: true));
      _isSending = true;
    });
    _messageController.clear();

    String reply;
    try {
      final token = await widget.authUseCases?.getCloudAccessToken.call();
      if (token == null || token.isEmpty) {
        if (mounted) setState(() {
          _hasCloudSession = false;
          _isGeminiReady = false;
        });
        reply = _buildLocalAssistantReply(trimmed);
      } else {
        final configured = await _remote.isConfigured();
        if (mounted) setState(() {
          _hasCloudSession = true;
          _isGeminiReady = configured;
        });
        if (!configured) {
          reply = 'حسابك متصل، لكن مفتاح Gemini لم يُضف إلى الخادم بعد. هذه إجابة محلية مؤقتة:\\n\\n${_buildLocalAssistantReply(trimmed)}';
        } else {
          reply = await _remote.sendMessage(
            accessToken: token,
            message: trimmed,
            context: _buildAcademicContext(),
          );
        }
      }
    } on AcademicAiRemoteException catch (error) {
      reply = error.message;
      if (error.statusCode == 401 && mounted) {
        setState(() {
          _hasCloudSession = false;
          _isGeminiReady = false;
        });
      }
      if (error.code == 'ai_not_configured' && mounted) {
        setState(() => _isGeminiReady = false);
      }
    } catch (_) {
      reply = 'تعذر الاتصال بالمساعد السحابي حاليًا. تحقق من اتصال الإنترنت ثم حاول مجددًا.';
    }

    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(text: reply, isUser: false));
      _isSending = false;
    });
  }

  String _buildLocalAssistantReply(String input) {
    final result = const AcademicAssistantService().buildResponse(
      input: input,
      courses: widget.courses,
      tasks: widget.tasks,
      exams: widget.exams,
    );
    if (result.needsFollowUp && result.followUpQuestion != null) {
      return '${result.response}\n\n${result.followUpQuestion}';
    }
    return result.response;
  }

  String _buildAcademicContext() {
    final context = {
      'currentDate': DateTime.now().toIso8601String(),
      'courses': widget.courses.take(40).map((course) => {
        'name': course.name,
        'code': course.code,
        'credits': course.credits,
        'midGrade': course.midGrade,
        'practicalGrade': course.practicalGrade,
        'finalGrade': course.finalGrade,
      }).toList(),
      'tasks': widget.tasks.take(40).map((task) => {
        'title': task.title,
        'type': task.type.name,
        'priority': task.priority.name,
        'dueDate': task.dueDate?.toIso8601String(),
        'completed': task.isCompleted,
        'courseName': task.courseName,
      }).toList(),
      'exams': widget.exams.take(30).map((exam) => {
        'title': exam.title,
        'courseName': exam.courseName,
        'examDate': exam.examDate.toIso8601String(),
      }).toList(),
    };
    return jsonEncode(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _isGeminiReady
        ? Colors.green
        : _hasCloudSession
            ? Colors.orange
            : Colors.blueGrey;
    final statusText = _isCheckingSession
        ? 'جارٍ التحقق من الاتصال...'
        : _isGeminiReady
            ? 'Gemini 3.8 Flash جاهز'
            : _hasCloudSession
                ? 'الحساب متصل — خدمة Gemini بانتظار المفتاح'
                : 'المساعد المحلي يعمل';

    return Scaffold(
      appBar: AppBar(
        title: const Text('المساعد الأكاديمي الذكي'),
        actions: [
          TextButton.icon(
            onPressed: _isSending ? null : () => setState(() => _messages.clear()),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: statusColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
          ),
          if (_isGeminiReady)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 7, 18, 0),
              child: Text(
                'عند إرسال السؤال، يُرسل ملخصك الأكاديمي إلى خدمة Gemini لتوليد الإجابة.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _suggestedPrompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final prompt = _suggestedPrompts[index];
                return ActionChip(
                  label: Text(prompt, style: const TextStyle(fontSize: 12)),
                  onPressed: _isSending ? null : () => _sendPrompt(prompt),
                  backgroundColor: Colors.indigo.shade50,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                    decoration: BoxDecoration(
                      color: message.isUser
                          ? Colors.blue.shade600
                          : (isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: message.isUser ? Colors.blue.shade500 : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser ? Colors.white : Theme.of(context).colorScheme.onSurface,
                        height: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isSending)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
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
                    readOnly: _isSending,
                    decoration: InputDecoration(
                      hintText: 'اكتب طلبك أو سؤالك...',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: _sendPrompt,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: _isSending ? null : () => _sendPrompt(_messageController.text),
                  child: const Icon(Icons.send_rounded),
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
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}
