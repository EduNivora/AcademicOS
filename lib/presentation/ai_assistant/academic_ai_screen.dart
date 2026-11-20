import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/academic/academic_assistant_service.dart';
import '../../data/datasources/academic_ai_remote_data_source.dart';
import '../../data/models/exam_model.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/task_entity.dart';
import '../../core/academic/schedule_conflict_validator.dart';
import '../../core/notifications/notification_service.dart';
import '../../data/database/database_helper.dart';
import '../../domain/usecases/task_use_cases.dart';
import '../../domain/usecases/auth_use_cases.dart';

class AcademicAiScreen extends StatefulWidget {
  final List<CourseEntity> courses;
  final List<TaskEntity> tasks;
  final List<ExamModel> exams;
  final AuthUseCases? authUseCases;
  final TaskUseCases? taskUseCases;
  final Future<void> Function()? onTasksChanged;

  const AcademicAiScreen({
    super.key,
    this.courses = const [],
    this.tasks = const [],
    this.exams = const [],
    this.authUseCases,
    this.taskUseCases,
    this.onTasksChanged,
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

    final actionReply = await _tryHandleAction(trimmed);
    if (actionReply != null) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: actionReply, isUser: false));
        _isSending = false;
      });
      return;
    }

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


  bool _isTaskCreationCommand(String input) {
    final value = input.trim().toLowerCase();
    if (RegExp(r'^(كيف|ما هي طريقة|طريقة|كيف أقدر|كيف اقدر)').hasMatch(value)) return false;
    return RegExp(r'(أضف|اضف|أنشئ|انشئ|إضافة|اضافة|إنشاء|انشاء|أريد|اريد|أبغى|ابغى|أحتاج|احتاج|سجل|سجّل|اعمل|سوّي|create|add).*(مهمة|واجب|تذكير|task)|(?:مهمة|واجب|تذكير).*(أضف|اضف|أنشئ|انشئ|إضافة|اضافة|إنشاء|انشاء|create|add)').hasMatch(value);
  }

  bool _isScheduleCreationCommand(String input) {
    final value = input.trim().toLowerCase();
    if (RegExp(r'^(كيف|ما هي طريقة|طريقة|كيف أقدر|كيف اقدر)').hasMatch(value)) return false;
    return RegExp(r'(أضف|اضف|أنشئ|انشئ|إضافة|اضافة|أريد|اريد|أبغى|ابغى|أحتاج|احتاج|جدول|جدولة|سجل|سجّل|add|schedule).*(محاضرة|حصة|موعد|lecture)|(?:محاضرة|حصة|موعد).*(أضف|اضف|أنشئ|انشئ|جدول|جدولة|add|schedule)').hasMatch(value);
  }

  String _suggestedTaskTitle(String input) {
    return input.replaceFirst(
      RegExp(r'^\s*(?:(?:من فضلك|أريد|اريد|أبغى|ابغى|أحتاج|احتاج)\s*)?(?:(?:أن\s*)?(?:أضف|اضف|أضيف|اضيف|أنشئ|انشئ|إضافة|اضافة|إنشاء|انشاء|سجل|سجّل|اعمل|create|add)\s*)?(?:لي\s*)?(?:مهمة|واجب|تذكير|task)?\s*(?:بعنوان|باسم|اسمها|عنوانها|:|-)?\s*', caseSensitive: false),
      '',
    ).trim();
  }

  Future<String?> _tryHandleAction(String input) async {
    if (_isTaskCreationCommand(input)) {
      if (widget.taskUseCases == null) {
        return 'خدمة المهام غير موصولة بالمساعد، لذلك لم يتم حفظ شيء.';
      }
      return _createTaskFromAssistant(input);
    }
    if (_isScheduleCreationCommand(input)) return _createScheduleFromAssistant(input);
    return null;
  }

  Future<String> _createTaskFromAssistant(String input) async {
    final titleController = TextEditingController(text: _suggestedTaskTitle(input));
    DateTime? dueDate;
    int? selectedCourseId;
    var priority = input.contains('عاجل') ? TaskPriority.urgent : TaskPriority.medium;
    var reminderEnabled = false;
    final matchingCourses = widget.courses.where((course) => input.toLowerCase().contains(course.name.toLowerCase()));
    if (matchingCourses.isNotEmpty) selectedCourseId = matchingCourses.first.id;
    if (input.contains('غدا') || input.contains('غداً')) {
      final now = DateTime.now();
      dueDate = DateTime(now.year, now.month, now.day + 1, 23, 59);
    }

    try {
      final task = await showDialog<TaskEntity>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('إنشاء مهمة من المساعد'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(labelText: 'عنوان المهمة', hintText: 'مثال: حل واجب الخوارزميات'),
                ),
                const SizedBox(height: 12),
                if (widget.courses.isNotEmpty)
                  DropdownButtonFormField<int?>(
                    value: selectedCourseId,
                    decoration: const InputDecoration(labelText: 'المادة'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('بدون مادة')),
                      ...widget.courses.where((course) => course.id != null).map((course) =>
                        DropdownMenuItem<int?>(value: course.id, child: Text(course.name))),
                    ],
                    onChanged: (value) => setDialogState(() => selectedCourseId = value),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TaskPriority>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'الأولوية'),
                  items: TaskPriority.values.map((value) => DropdownMenuItem(value: value, child: Text(value.label))).toList(),
                  onChanged: (value) { if (value != null) setDialogState(() => priority = value); },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(dueDate == null
                    ? 'موعد التسليم: غير محدد'
                    : 'موعد التسليم: ' + dueDate!.day.toString() + '/' + dueDate!.month.toString() + '/' + dueDate!.year.toString()),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dueDate ?? DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setDialogState(() => dueDate = DateTime(picked.year, picked.month, picked.day, 23, 59));
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تذكير قبل موعد التسليم'),
                  value: reminderEnabled,
                  onChanged: (value) => setDialogState(() => reminderEnabled = value),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton(
                onPressed: titleController.text.trim().isEmpty ? null : () {
                  CourseEntity? course;
                  for (final candidate in widget.courses) {
                    if (candidate.id == selectedCourseId) { course = candidate; break; }
                  }
                  Navigator.pop(dialogContext, TaskEntity(
                    title: titleController.text.trim(),
                    description: '',
                    type: input.contains('واجب') ? TaskType.homework : TaskType.other,
                    priority: priority,
                    dueDate: dueDate,
                    courseId: selectedCourseId,
                    courseName: course?.name,
                    reminderEnabled: reminderEnabled && dueDate != null,
                    reminderOffsetMinutes: 30,
                  ));
                },
                child: const Text('حفظ المهمة'),
              ),
            ],
          ),
        ),
      );
      if (task == null) return 'تم إلغاء إنشاء المهمة؛ لم يتم حفظ أي شيء.';
      final id = await widget.taskUseCases!.addTask(task);
      final savedTask = task.copyWith(id: id);
      if (savedTask.reminderEnabled) await NotificationService.instance.scheduleTaskReminder(savedTask);
      await widget.onTasksChanged?.call();
      var message = 'تم إنشاء المهمة "' + savedTask.title + '" وحفظها في قائمتك';
      if (savedTask.courseName != null) message += ' لمادة ' + savedTask.courseName!;
      if (savedTask.dueDate != null) message += ' بتاريخ ' + savedTask.dueDate!.day.toString() + '/' + savedTask.dueDate!.month.toString() + '/' + savedTask.dueDate!.year.toString();
      return message + '.';
    } catch (error) {
      return 'تعذر حفظ المهمة: ' + error.toString() + '. لم أؤكد نجاح العملية.';
    } finally {
      titleController.dispose();
    }
  }

  Future<String> _createScheduleFromAssistant(String input) async {
    const days = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];
    final aliases = <String, String>{
      'السبت': 'السبت', 'الأحد': 'الأحد', 'الاحد': 'الأحد',
      'الاثنين': 'الاثنين', 'الإثنين': 'الاثنين', 'الثلاثاء': 'الثلاثاء',
      'الأربعاء': 'الأربعاء', 'الخميس': 'الخميس', 'الجمعة': 'الجمعة',
    };
    var selectedDay = days[(DateTime.now().weekday + 1) % 7];
    for (final entry in aliases.entries) {
      if (input.contains(entry.key)) { selectedDay = entry.value; break; }
    }
    int? selectedCourseId;
    for (final course in widget.courses) {
      if (input.toLowerCase().contains(course.name.toLowerCase())) { selectedCourseId = course.id; break; }
    }
    final timeMatch = RegExp(r'([01]?\d|2[0-3]):([0-5]\d)').firstMatch(input);
    var start = timeMatch == null ? '08:00' : timeMatch.group(1)!.padLeft(2, '0') + ':' + timeMatch.group(2)!;
    var end = '09:00';
    if (timeMatch != null) {
      final total = int.parse(timeMatch.group(1)!) * 60 + int.parse(timeMatch.group(2)!) + 60;
      end = (total ~/ 60).toString().padLeft(2, '0') + ':' + (total % 60).toString().padLeft(2, '0');
    }
    final locationController = TextEditingController();
    var reminderEnabled = true;
    try {
      final confirmed = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('إضافة محاضرة إلى الجدول'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  value: selectedDay,
                  decoration: const InputDecoration(labelText: 'اليوم'),
                  items: days.map((day) => DropdownMenuItem(value: day, child: Text(day))).toList(),
                  onChanged: (value) { if (value != null) setDialogState(() => selectedDay = value); },
                ),
                if (widget.courses.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: selectedCourseId,
                    decoration: const InputDecoration(labelText: 'المادة'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('محاضرة عامة')),
                      ...widget.courses.where((course) => course.id != null).map((course) =>
                        DropdownMenuItem<int?>(value: course.id, child: Text(course.name))),
                    ],
                    onChanged: (value) => setDialogState(() => selectedCourseId = value),
                  ),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () async { final value = await _pickAssistantTime(start); if (value != null) setDialogState(() => start = value); },
                    child: Text('البداية ' + start),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(
                    onPressed: () async { final value = await _pickAssistantTime(end); if (value != null) setDialogState(() => end = value); },
                    child: Text('النهاية ' + end),
                  )),
                ]),
                const SizedBox(height: 12),
                TextField(controller: locationController, decoration: const InputDecoration(labelText: 'الموقع (اختياري)')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تذكير قبل المحاضرة'),
                  value: reminderEnabled,
                  onChanged: (value) => setDialogState(() => reminderEnabled = value),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, {
                'day': selectedDay, 'courseId': selectedCourseId,
                'start': start, 'end': end, 'location': locationController.text.trim(),
                'reminder': reminderEnabled,
              }), child: const Text('حفظ المحاضرة')),
            ],
          ),
        ),
      );
      if (confirmed == null) return 'تم إلغاء إضافة المحاضرة؛ لم يتم حفظ أي شيء.';
      final existing = await DatabaseHelper.instance.getSchedules();
      final validation = ScheduleConflictValidator.validate(
        day: confirmed['day'] as String,
        startTime: confirmed['start'] as String,
        endTime: confirmed['end'] as String,
        existingSchedules: existing,
      );
      if (!validation.isValid) {
        switch (validation.issue) {
          case ScheduleValidationIssue.invalidTimeFormat: return 'لم أحفظ المحاضرة: صيغة الوقت غير صحيحة.';
          case ScheduleValidationIssue.invalidTimeRange: return 'لم أحفظ المحاضرة: وقت النهاية يجب أن يكون بعد البداية.';
          case ScheduleValidationIssue.invalidStoredEntry: return 'لم أحفظ المحاضرة: يوجد موعد محفوظ غير صالح، صححه أولاً.';
          case ScheduleValidationIssue.overlap: return 'لم أحفظ المحاضرة: الوقت يتعارض مع محاضرة أخرى في اليوم نفسه.';
          case null: return 'لم أحفظ المحاضرة: تعذر التحقق من التعارض.';
        }
      }
      final location = (confirmed['location'] as String).isEmpty ? 'غير محدد' : confirmed['location'] as String;
      final schedule = <String, dynamic>{
        'day_of_week': confirmed['day'],
        'course_id': confirmed['courseId'],
        'start_time': confirmed['start'],
        'end_time': confirmed['end'],
        'location': location,
        'reminder_enabled': confirmed['reminder'] == true ? 1 : 0,
        'reminder_offset_minutes': 15,
      };
      final id = await DatabaseHelper.instance.insertSchedule(schedule);
      CourseEntity? selectedCourse;
      for (final course in widget.courses) {
        if (course.id == confirmed['courseId']) { selectedCourse = course; break; }
      }
      if (confirmed['reminder'] == true) {
        await NotificationService.instance.scheduleLectureReminder(
          id: id, title: selectedCourse?.name ?? 'محاضرة',
          weekdayName: confirmed['day'] as String,
          startTime: confirmed['start'] as String,
          reminderEnabled: true, location: location, reminderOffsetMinutes: 15,
        );
      }
      return 'تمت إضافة ' + (selectedCourse?.name ?? 'المحاضرة') + ' إلى جدول ' +
          (confirmed['day'] as String) + ' من ' + (confirmed['start'] as String) +
          ' إلى ' + (confirmed['end'] as String) + '.';
    } catch (error) {
      return 'تعذر حفظ المحاضرة: ' + error.toString() + '. لم أؤكد نجاح العملية.';
    } finally {
      locationController.dispose();
    }
  }

  Future<String?> _pickAssistantTime(String initialValue) async {
    final parts = initialValue.split(':');
    final hour = int.tryParse(parts.first) ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (picked == null) return null;
    return picked.hour.toString().padLeft(2, '0') + ':' + picked.minute.toString().padLeft(2, '0');
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
