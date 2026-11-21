import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/academic/academic_assistant_service.dart';
import '../../core/academic/academic_assistant_action_plan.dart';
import '../../core/academic/academic_assistant_action_executor.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/student_profile_model.dart';
import '../../data/datasources/academic_ai_remote_data_source.dart';
import '../../data/models/exam_model.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/usecases/auth_use_cases.dart';
import '../../domain/usecases/course_use_cases.dart';
import '../../domain/usecases/task_use_cases.dart';

class AcademicAiScreen extends StatefulWidget {
  final List<CourseEntity> courses;
  final List<TaskEntity> tasks;
  final List<ExamModel> exams;
  final AuthUseCases? authUseCases;
  final CourseUseCases courseUseCases;
  final TaskUseCases taskUseCases;
  final Future<void> Function()? onDataChanged;

  const AcademicAiScreen({
    super.key,
    this.courses = const [],
    this.tasks = const [],
    this.exams = const [],
    this.authUseCases,
    required this.courseUseCases,
    required this.taskUseCases,
    this.onDataChanged,
  });

  @override
  State<AcademicAiScreen> createState() => _AcademicAiScreenState();
}

class _AcademicAiScreenState extends State<AcademicAiScreen> {
  final TextEditingController _messageController = TextEditingController();
  final AcademicAiRemoteDataSource _remote = AcademicAiRemoteDataSource();
  late final AcademicAssistantActionExecutor _actionExecutor;
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text:
          'مرحباً، أنا المساعد الذكي في EduNivora. أستطيع مساعدتك في فهم المواد وتنظيم المهام والاستعداد للاختبارات.',
      isUser: false,
    ),
  ];

  final List<String> _suggestedPrompts = [
    'كم باقي على أول اختبار وماذا أحتاج للمذاكرة؟',
    'أنشئ لي مهمة لمراجعة مادة الشبكات غداً',
    'وزع لي خطة مذاكرة لمادة التشفير خلال 3 أيام',
    'ما أهم مهمة يجب أن أبدأ بها اليوم؟',
  ];

  bool _isSending = false;
  PlatformFile? _pendingAttachment;
  bool _isCheckingSession = true;
  bool _hasCloudSession = false;
  bool _isGeminiReady = false;
  late final Future<void> _ledgerRecovery;

  @override
  void initState() {
    super.initState();
    _actionExecutor = AcademicAssistantActionExecutor(
      courseUseCases: widget.courseUseCases,
      taskUseCases: widget.taskUseCases,
    );
    _ledgerRecovery = _recoverAssistantLedger();
    _refreshSessionState();
  }

  Future<void> _recoverAssistantLedger() async {
    try {
      await DatabaseHelper.instance.recoverInterruptedAssistantRuns();
    } catch (error) {
      debugPrint('Assistant execution ledger recovery failed: ${error.runtimeType}');
    }
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

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.single;
      if (file.bytes == null || file.bytes!.isEmpty) {
        _showMessage('تعذر قراءة الملف. جرّب اختيار الملف مرة أخرى.');
        return;
      }
      if (file.size > 50 * 1024 * 1024) {
        _showMessage('حجم الملف يتجاوز الحد المسموح وهو 50 MB.');
        return;
      }
      setState(() => _pendingAttachment = file);
    } catch (error) {
      if (mounted) _showMessage('تعذر إرفاق الملف: $error');
    }
  }

  Future<String> _savePendingAttachment(String instruction) async {
    final file = _pendingAttachment;
    if (file == null) return 'لا يوجد ملف مرفق.';
    if (!RegExp(r'(أضف|اضف|أرفق|ارفق|احفظ|حفظ)').hasMatch(instruction)) {
      return 'الملف «${file.name}» مرفق. اكتب مثلاً: أضف الملف إلى مادة أمن الشبكات.';
    }
    final match = RegExp(r'مادة\s+(.+)$').firstMatch(instruction);
    if (match == null) {
      return 'حدد المادة التي تريد ربط الملف بها، مثلاً: أضف الملف إلى مادة أمن الشبكات.';
    }
    final courseName = match
        .group(1)!
        .replaceFirst(RegExp(r'\s+(?:غداً|غدا|اليوم|في|من)\b.*$'), '')
        .replaceAll(RegExp(r'[،,.]+$'), '')
        .trim();
    if (courseName.isEmpty) return 'اكتب اسم المادة بوضوح.';
    final extension = (file.extension ?? file.name.split('.').last)
        .toLowerCase();
    final call = AcademicAssistantToolCall(
      name: 'add_material_file',
      arguments: {
        'course_name': courseName,
        'file_name': file.name,
        'file_type': extension,
        'file_bytes': file.bytes!,
      },
    );
    return _executeTrackedActions(
      [call],
      source: 'attachment',
      onSuccess: () async {
        if (mounted) setState(() => _pendingAttachment = null);
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      if (_pendingAttachment != null) {
        reply = await _savePendingAttachment(trimmed);
      } else {
        final token = await widget.authUseCases?.getCloudAccessToken.call();
        if (token == null || token.isEmpty) {
          if (mounted) {
            setState(() {
              _hasCloudSession = false;
              _isGeminiReady = false;
            });
          }
          reply =
              await _runLocalCommand(trimmed) ??
              _buildLocalAssistantReply(trimmed);
        } else {
          final configured = await _remote.isConfigured();
          if (mounted) {
            setState(() {
              _hasCloudSession = true;
              _isGeminiReady = configured;
            });
          }
          if (!configured) {
            reply =
                await _runLocalCommand(trimmed) ??
                'خدمة Gemini غير مهيأة على الخادم حالياً. يمكنني تنفيذ الأوامر المحلية المدعومة الآن:\n\n${_buildLocalAssistantReply(trimmed)}';
          } else if (_looksLikeActionRequest(trimmed)) {
            final planned = await _remote.sendMessage(
              accessToken: token,
              message: _buildActionPlanningPrompt(trimmed),
              context: await _buildAcademicContext(),
            );
            final plan = const AcademicAssistantActionPlanParser().parse(planned);
            if (plan == null) {
              reply = await _remote.sendMessage(
                accessToken: token,
                message: trimmed,
                context: await _buildAcademicContext(),
              );
            } else {
              reply = await _executeActionPlan(plan);
            }
          } else {
            reply = await _remote.sendMessage(
              accessToken: token,
              message: trimmed,
              context: await _buildAcademicContext(),
            );
          }
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
        reply = await _runLocalCommand(trimmed) ?? error.message;
      }
    } catch (error) {
      reply = 'تعذر تنفيذ الطلب: $error';
    }

    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(text: reply, isUser: false));
      _isSending = false;
    });
  }

  bool _looksLikeActionRequest(String value) => RegExp(
    r'(أضف|اضف|أنشئ|انشئ|احذف|حذف|عدّل|عدل|حدّث|حدث|أكمل|اكمل|ضع|أدرج|تقرير)',
  ).hasMatch(value);

  String _buildActionPlanningPrompt(String userMessage) {
    return '''أنت محرك تنفيذ داخل AcademicOS. حلل طلب المستخدم ثم أعد JSON صالحاً فقط دون Markdown بالشكل:
{"reply":"توضيح مختصر","actions":[{"name":"create_material","arguments":{"name":"اسم المادة"}}]}

الأدوات المسموحة فقط:
- update_profile: full_name, university, major, department, semester, academic_level
- create_material: name, instructor, code
- update_material: course_id أو course_name, name, instructor, code, credits
- delete_material: course_id أو course_name
- create_task: title, description, course_name, end_date_time بصيغة ISO-8601, priority (low|medium|high|urgent), type (homework|project|exam|review|attendance|academicActivity|other), reminder_enabled, reminder_offset_minutes
- complete_task: task_id أو task_title
- update_task: task_id أو task_title مع title أو description أو priority أو end_date_time
- delete_task: task_id أو task_title
- add_lecture: course_id أو course_name, day (اسم يوم عربي), start_time, end_time بصيغة HH:mm, location
- update_lecture: schedule_id, course_id أو course_name, day, start_time, end_time, location, reminder_enabled, reminder_offset_minutes
- delete_lecture: schedule_id
- create_exam: title, exam_date بصيغة ISO-8601, course_id أو course_name, location, notes
- update_exam: exam_id, title, exam_date بصيغة ISO-8601, course_id أو course_name, location, notes
- delete_exam: exam_id
- generate_report: period (daily|weekly|monthly|final)

قواعد إلزامية:
1. لا تخترع معرفات أو مواد غير موجودة في السياق.
2. استخدم course_id عند توفره، وإلا استخدم الاسم المطابق تماماً.
3. لا تنشئ مهمة أو محاضرة إذا كانت المعلومات الأساسية ناقصة؛ اترك actions فارغة واطلب توضيحاً في reply.
4. لا تنفذ الحذف بنفسك؛ أرسل إجراء الحذف المطلوب فقط، وسيطلب التطبيق تأكيد المستخدم قبل حذف أي سجل.
5. لا تدّعِ نجاح أي عملية؛ التطبيق سينفذ الأدوات ويتحقق من الحفظ.
6. يمكن إنشاء عدة مهام في actions عند طلب خطة، لكن لا تتجاوز 10 إجراءات.
7. لا تنشئ أي إجراء متعلق بتوزيع الدرجات أو المعدل؛ هذه الوظائف مؤجلة.

طلب المستخدم:
$userMessage''';
  }

  Future<String> _executeActionPlan(AcademicAssistantActionPlan plan) {
    return _executeTrackedActions(
      plan.actions,
      source: 'cloud_plan',
      lead: plan.reply,
    );
  }

  Future<String> _executeTrackedActions(
    List<AcademicAssistantToolCall> calls, {
    required String source,
    String lead = '',
    Future<void> Function()? onSuccess,
  }) async {
    if (calls.isEmpty) {
      return lead.trim().isEmpty
          ? 'لم ينتج المساعد إجراءً أو إجابة واضحة.'
          : lead.trim();
    }

    final ledger = DatabaseHelper.instance;
    int? runId;
    var currentStep = -1;
    try {
      await _ledgerRecovery;
      runId = await ledger.createAssistantActionRun(
        source: source,
        actionNames: calls.map((call) => call.name).toList(growable: false),
      );

      final preflight = await _actionExecutor.preflightPlan(calls);
      if (!preflight.succeeded) {
        await ledger.finalizePendingAssistantActionSteps(
          runId,
          status: 'skipped',
          failureCode: 'preflight_rejected',
        );
        await ledger.updateAssistantActionRun(
          runId: runId,
          status: 'rejected',
          failureCode: 'preflight_rejected',
        );
        return preflight.message;
      }

      const destructiveActions = {
        'delete_material',
        'delete_task',
        'delete_lecture',
        'delete_exam',
      };
      await ledger.updateAssistantActionRun(
        runId: runId,
        status: 'awaiting_confirmation',
      );
      final approvedDestructiveActions = <int>{};
      for (var index = 0; index < calls.length; index++) {
        final call = calls[index];
        if (!destructiveActions.contains(call.name)) continue;
        final preview = await _actionExecutor.execute(call);
        if (!preview.requiresConfirmation) {
          await ledger.finalizePendingAssistantActionSteps(
            runId,
            status: 'skipped',
            failureCode: 'confirmation_unavailable',
          );
          await ledger.updateAssistantActionRun(
            runId: runId,
            status: 'failed',
            failureStep: index,
            failureCode: 'confirmation_unavailable',
          );
          return preview.message;
        }
        final confirmed = await _showActionConfirmation(preview);
        if (confirmed != true) {
          await ledger.finalizePendingAssistantActionSteps(
            runId,
            status: 'cancelled',
            failureCode: 'user_cancelled',
          );
          await ledger.updateAssistantActionRun(
            runId: runId,
            status: 'cancelled',
            failureStep: index,
            failureCode: 'user_cancelled',
          );
          return 'تم إلغاء الخطة قبل التنفيذ. لم تُنفذ أي خطوة.';
        }
        approvedDestructiveActions.add(index);
      }

      await ledger.updateAssistantActionRun(runId: runId, status: 'running');
      final messages = <String>[];
      if (lead.trim().isNotEmpty) messages.add(lead.trim());
      var succeededCount = 0;

      for (var index = 0; index < calls.length; index++) {
        currentStep = index;
        await ledger.updateAssistantActionStep(
          runId: runId,
          stepIndex: index,
          status: 'running',
        );
        final result = await _executeTool(
          calls[index],
          confirmed: approvedDestructiveActions.contains(index),
        );
        messages.add(result.message);
        await ledger.updateAssistantActionStep(
          runId: runId,
          stepIndex: index,
          status: result.succeeded ? 'succeeded' : 'failed',
          changedData: result.changedData,
          failureCode: result.succeeded ? null : 'action_failed',
        );
        if (result.succeeded) {
          succeededCount++;
          if (result.changedData) await onSuccess?.call();
          continue;
        }

        final remaining = calls.length - index - 1;
        if (remaining > 0) {
          await ledger.finalizePendingAssistantActionSteps(
            runId,
            status: 'skipped',
            failureCode: 'previous_action_failed',
          );
          messages.add(
            'أوقفت بقية الخطة لأن الإجراء ${index + 1} لم يكتمل بنجاح. '
            'راجع النتيجة ثم اطلب متابعة الخطوات المتبقية.',
          );
        }
        await ledger.updateAssistantActionRun(
          runId: runId,
          status: succeededCount > 0 ? 'partial_failure' : 'failed',
          failureStep: index,
          failureCode: 'action_failed',
        );
        return messages.join('\\n\\n');
      }

      await ledger.updateAssistantActionRun(runId: runId, status: 'succeeded');
      return messages.isEmpty
          ? 'لم ينتج عن الطلب إجراء واضح. وضّح ما تريد تنفيذه.'
          : messages.join('\\n\\n');
    } catch (error) {
      if (runId != null) {
        try {
          if (currentStep >= 0) {
            await ledger.updateAssistantActionStep(
              runId: runId,
              stepIndex: currentStep,
              status: 'interrupted',
              failureCode: 'execution_interrupted',
            );
          }
          await ledger.finalizePendingAssistantActionSteps(
            runId,
            status: 'skipped',
            failureCode: 'execution_interrupted',
          );
          await ledger.updateAssistantActionRun(
            runId: runId,
            status: 'interrupted',
            failureCode: 'execution_interrupted',
          );
        } catch (ledgerError) {
          debugPrint(
            'Assistant ledger finalization failed: ${ledgerError.runtimeType}',
          );
        }
      }
      return 'توقفت الخطة بسبب خطأ أثناء التنفيذ أو تسجيل نتيجته. '
          'افحص سجل التنفيذ قبل إعادة الطلب لتجنب تكرار أي خطوة.';
    }
  }

  Future<String?> _runLocalCommand(String input) async {
    final call = const AcademicAssistantCommandParser().parse(input);
    if (call == null) return null;
    return _executeTrackedActions([call], source: 'local_command');
  }

  Future<bool?> _showActionConfirmation(
    AcademicAssistantToolResult result,
  ) {
    if (!mounted) return Future.value(null);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد العملية'),
        content: Text(result.confirmationPrompt ?? result.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }

  Future<AcademicAssistantToolResult> _executeTool(
    AcademicAssistantToolCall call, {
    bool confirmed = false,
  }) async {
    try {
      var result = await _actionExecutor.execute(call, confirmed: confirmed);
      if (result.requiresConfirmation) {
        if (!mounted) {
          return const AcademicAssistantToolResult(
            message: 'تعذر عرض تأكيد العملية.',
            succeeded: false,
          );
        }
        final confirmed = await _showActionConfirmation(result);
        if (confirmed != true) {
          return const AcademicAssistantToolResult(
            message: 'تم إلغاء العملية بناءً على اختيارك.',
            succeeded: false,
          );
        }
        result = await _actionExecutor.execute(call, confirmed: true);
      }
      if (result.succeeded && result.changedData) {
        await widget.onDataChanged?.call();
      }
      return result;
    } catch (error) {
      return AcademicAssistantToolResult(
        message: 'لم يتم تنفيذ «${call.name}»: $error',
        succeeded: false,
      );
    }
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

  Future<String> _buildAcademicContext() async {
    final courses = await widget.courseUseCases.getCourses();
    final tasks = await widget.taskUseCases.getTasks();
    final schedules = await DatabaseHelper.instance.getSchedules();
    final exams = await DatabaseHelper.instance.getExams();
    final materials = await DatabaseHelper.instance.getAllMaterials();
    final profile = await StudentProfile.load();
    final context = {
      'academicProfile': {
        'fullName': profile.fullName,
        'university': profile.university,
        'major': profile.major,
        'department': profile.department,
        'semester': profile.semester,
        'academicLevel': profile.academicLevel,
      },
      'currentDate': DateTime.now().toIso8601String(),
      'courses': courses
          .take(60)
          .map(
            (course) => {
              'id': course.id,
              'name': course.name,
              'code': course.code,
              'credits': course.credits,
            },
          )
          .toList(),
      'tasks': tasks
          .take(60)
          .map(
            (task) => {
              'id': task.id,
              'title': task.title,
              'type': task.type.name,
              'priority': task.priority.name,
              'dueDate': task.dueDate?.toIso8601String(),
              'endDateTime': task.endDateTime?.toIso8601String(),
              'completedAt': task.completedAt?.toIso8601String(),
              'completed': task.isCompleted,
              'courseId': task.courseId,
              'courseName': task.courseName,
            },
          )
          .toList(),
      'weeklySchedule': schedules.take(100).toList(),
      'materials': materials.take(100).map((item) => {
        'id': item['id'],
        'courseId': item['course_id'],
        'title': item['title'],
        'fileType': item['file_type'],
      }).toList(),
      'exams': exams
          .take(30)
          .map(
            (exam) => {
              'id': exam.id,
              'title': exam.title,
              'courseName': exam.courseName,
              'examDate': exam.examDate.toIso8601String(),
            },
          )
          .toList(),
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
        title: const Text('المساعد الذكي'),
        actions: [
          TextButton.icon(
            onPressed: _isSending
                ? null
                : () => setState(() => _messages.clear()),
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
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
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
                          : (isDark
                                ? Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest
                                : Colors.white),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: message.isUser
                            ? Colors.blue.shade500
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_pendingAttachment != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InputChip(
                        avatar: const Icon(Icons.attach_file_rounded, size: 18),
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            _pendingAttachment!.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onDeleted: _isSending
                            ? null
                            : () => setState(() => _pendingAttachment = null),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'إرفاق ملف بالمادة',
                      onPressed: _isSending ? null : _pickAttachment,
                      icon: const Icon(Icons.attach_file_rounded),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        readOnly: _isSending,
                        decoration: InputDecoration(
                          hintText: 'اكتب طلبك أو سؤالك...',
                          filled: true,
                          fillColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
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
                      onPressed: _isSending
                          ? null
                          : () => _sendPrompt(_messageController.text),
                      child: const Icon(Icons.send_rounded),
                    ),
                  ],
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
