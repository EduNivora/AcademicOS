import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/academic/schedule_conflict_validator.dart';
import '../../core/notifications/notification_service.dart';
import '../../data/database/database_helper.dart';
import '../../data/datasources/academic_ai_remote_data_source.dart';
import '../../domain/usecases/auth_use_cases.dart';
import '../../data/models/course_model.dart';

class ScheduleScreen extends StatefulWidget {
  final AuthUseCases authUseCases;

  const ScheduleScreen({super.key, required this.authUseCases});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final List<String> _days = const [
    'السبت',
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
  ];

  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final AcademicAiRemoteDataSource _aiRemote = AcademicAiRemoteDataSource();
  final List<Map<String, dynamic>> _lectures = [];
  final List<CourseModel> _courses = [];
  bool _isLoading = true;
  bool _isImportingSchedule = false;

  String _selectedDay = 'السبت';

  Color _parseColor(String? hex) {
    final safeHex = (hex ?? '#3B82F6').replaceFirst('#', '');
    final normalized = safeHex.length == 6 ? 'FF$safeHex' : safeHex;
    return Color(int.tryParse('0x$normalized') ?? 0xFF3B82F6);
  }

  Future<void> _loadLectures() async {
    try {
      final schedules = await _databaseHelper.getSchedules();
      final courses = await _databaseHelper.getCourses();
      final courseMap = {
        for (final course in courses) course.id!: course,
      };

      final mappedLectures = schedules.map((row) {
        final courseId = row['course_id'] is int
            ? row['course_id'] as int
            : int.tryParse(row['course_id']?.toString() ?? '');
        final course = courseId != null ? courseMap[courseId] : null;

        return {
          'id': row['id'],
          'day': row['day_of_week']?.toString() ?? 'السبت',
          'courseTitle': course?.name ?? 'محاضرة',
          'instructor': course?.instructor ?? '',
          'color': _parseColor(course?.colorHex),
          'start': row['start_time']?.toString() ?? '08:00',
          'end': row['end_time']?.toString() ?? '09:00',
          'location': row['location']?.toString() ?? 'غير محدد',
          'reminder':
              row['reminder_enabled'] == 1 || row['reminder_enabled'] == true,
          'reminderOffsetMinutes': row['reminder_offset_minutes'] is int
              ? row['reminder_offset_minutes'] as int
              : 15,
          'course_id': courseId,
        };
      }).toList();

      mappedLectures.sort((a, b) {
        final aTime = (a['start'] ?? '00:00').toString();
        final bTime = (b['start'] ?? '00:00').toString();
        return aTime.compareTo(bTime);
      });

      if (!mounted) return;
      setState(() {
        _courses
          ..clear()
          ..addAll(courses);
        _lectures
          ..clear()
          ..addAll(mappedLectures);
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('ScheduleScreen._loadLectures error: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importScheduleImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    if (result == null || !mounted) return;

    final file = result.files.single;
    final extension = (file.extension ?? '').toLowerCase();
    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
    final bytes = file.bytes;
    if (mimeType == null || bytes == null || bytes.isEmpty ||
        bytes.length > 8 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر صورة JPG أو PNG أو WebP لا يتجاوز حجمها 8 ميجابايت.'),
        ),
      );
      return;
    }

    final consent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تحليل صورة الجدول'),
        content: const Text(
          'سيتم إرسال صورة الجدول إلى خدمة Gemini لاستخراج أسماء المواد والأيام والأوقات. لن تُحفظ الصورة في سجل المحادثة. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;

    setState(() => _isImportingSchedule = true);
    try {
      final accessToken = await widget.authUseCases.getCloudAccessToken.call();
      if (accessToken == null || accessToken.trim().isEmpty) {
        throw const AcademicAiRemoteException(
          401,
          'unauthorized',
          'استيراد الجدول من الصورة يحتاج إلى تسجيل الدخول بحساب سحابي. يمكنك إدخال الجدول يدوياً دون ذلك.',
        );
      }

      final extracted = await _aiRemote.parseScheduleImage(
        accessToken: accessToken,
        imageBytes: bytes,
        mimeType: mimeType,
      );
      if (extracted.isEmpty) {
        throw const AcademicAiRemoteException(
          422,
          'empty_schedule',
          'لم أتعرف على محاضرات واضحة في الصورة. جرّب صورة أوضح أو أدخل الجدول يدوياً.',
        );
      }

      String normalize(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final matchedEntries = <Map<String, dynamic>>[];
      final unmatchedNames = <String>{};
      for (final entry in extracted) {
        final courseName = entry['course_name']?.toString() ?? '';
        final course = _courses.where((item) => normalize(item.name) == normalize(courseName)).firstOrNull;
        if (course?.id == null) {
          unmatchedNames.add(courseName);
          continue;
        }
        matchedEntries.add({
          'day_of_week': entry['day'],
          'course_id': course!.id,
          'course_name': course.name,
          'start_time': entry['start_time'],
          'end_time': entry['end_time'],
          'location': entry['location']?.toString() ?? '',
        });
      }

      if (unmatchedNames.isNotEmpty) {
        throw AcademicAiRemoteException(
          422,
          'unmatched_subjects',
          'هذه المواد غير موجودة في قائمة المواد: ${unmatchedNames.join('، ')}. أضفها أولاً ثم أعد استيراد الجدول.',
        );
      }
      if (matchedEntries.isEmpty) {
        throw const AcademicAiRemoteException(
          422,
          'empty_schedule',
          'لم يتم استخراج محاضرات مرتبطة بموادك.',
        );
      }

      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('مراجعة الجدول المستخرج (${matchedEntries.length})'),
          content: SizedBox(
            width: 480,
            height: 360,
            child: ListView.separated(
              itemCount: matchedEntries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = matchedEntries[index];
                return ListTile(
                  dense: true,
                  title: Text('${entry['course_name']} — ${entry['day_of_week']}'),
                  subtitle: Text('${entry['start_time']} - ${entry['end_time']}  •  ${entry['location']}'),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('مراجعة لاحقاً'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('اعتماد الجدول'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;

      final existingSchedules = await _databaseHelper.getSchedules();
      final toSave = <Map<String, dynamic>>[];
      for (final entry in matchedEntries) {
        final isDuplicate = existingSchedules.any((row) =>
            row['course_id'] == entry['course_id'] &&
            row['day_of_week'] == entry['day_of_week'] &&
            row['start_time'] == entry['start_time'] &&
            row['end_time'] == entry['end_time']);
        if (isDuplicate) continue;

        final validation = ScheduleConflictValidator.validate(
          day: entry['day_of_week'] as String,
          startTime: entry['start_time'] as String,
          endTime: entry['end_time'] as String,
          existingSchedules: [...existingSchedules, ...toSave],
        );
        if (!validation.isValid) {
          throw const AcademicAiRemoteException(
            409,
            'schedule_conflict',
            'الجدول المستخرج يحتوي على أوقات متعارضة مع جدولك الحالي. لم يتم حفظ أي محاضرة جديدة.',
          );
        }
        toSave.add({
          ...entry,
          'reminder_enabled': 1,
          'reminder_offset_minutes': 15,
        });
      }

      if (toSave.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('كل المحاضرات المستخرجة موجودة مسبقاً في جدولك.')),
        );
        return;
      }

      final savedIds = await _databaseHelper.insertSchedules(toSave);
      for (var index = 0; index < toSave.length; index++) {
        final entry = toSave[index];
        await NotificationService.instance.scheduleLectureReminder(
          id: savedIds[index],
          title: entry['course_name'] as String,
          weekdayName: entry['day_of_week'] as String,
          startTime: entry['start_time'] as String,
          reminderEnabled: true,
          location: entry['location'] as String,
          reminderOffsetMinutes: 15,
        );
      }
      await _loadLectures();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم استيراد ${toSave.length} محاضرة وربطها بموادك.')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is AcademicAiRemoteException
          ? error.message
          : 'تعذر استيراد الجدول. حاول مرة أخرى أو أدخله يدوياً.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isImportingSchedule = false);
    }
  }

  Future<void> _showLectureDialog({Map<String, dynamic>? lecture}) async {
    final locationController = TextEditingController(
      text: lecture != null ? lecture['location']?.toString() ?? '' : '',
    );
    String selectedDay = lecture != null
        ? lecture['day']?.toString() ?? _selectedDay
        : _selectedDay;
    String selectedStart =
        lecture != null ? lecture['start']?.toString() ?? '08:00' : '08:00';
    String selectedEnd =
        lecture != null ? lecture['end']?.toString() ?? '09:30' : '09:30';
    bool reminderEnabled = lecture != null ? lecture['reminder'] == true : true;
    int? selectedCourseId = lecture != null
        ? (lecture['course_id'] is int ? lecture['course_id'] as int : null)
        : (_courses.isNotEmpty ? _courses.first.id : null);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(lecture == null ? 'إضافة محاضرة' : 'تعديل المحاضرة'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedDay,
                        decoration: const InputDecoration(labelText: 'اليوم'),
                        items: _days
                            .map(
                              (day) => DropdownMenuItem<String>(
                                value: day,
                                child: Text(day),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setStateDialog(() => selectedDay = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_courses.isEmpty)
                        const Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text('أضف مادة أولاً حتى تربط بها المحاضرة.'),
                        )
                      else
                        DropdownButtonFormField<int>(
                          value: selectedCourseId,
                          decoration: const InputDecoration(
                            labelText: 'المادة المرتبطة',
                          ),
                          items: _courses
                              .where((course) => course.id != null)
                              .map(
                                (course) => DropdownMenuItem<int>(
                                  value: course.id!,
                                  child: Text(course.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setStateDialog(
                            () => selectedCourseId = value,
                          ),
                          validator: (value) => value == null
                              ? 'اختر المادة المرتبطة بالمحاضرة.'
                              : null,
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () async {
                                final time = await _pickTime(selectedStart);
                                if (time != null) {
                                  setStateDialog(() => selectedStart = time);
                                }
                              },
                              icon: const Icon(Icons.access_time),
                              label: Text(selectedStart),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () async {
                                final time = await _pickTime(selectedEnd);
                                if (time != null) {
                                  setStateDialog(() => selectedEnd = time);
                                }
                              },
                              icon: const Icon(Icons.access_time_filled),
                              label: Text(selectedEnd),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: locationController,
                        decoration: const InputDecoration(labelText: 'الموقع'),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: reminderEnabled,
                        onChanged: (value) =>
                            setStateDialog(() => reminderEnabled = value),
                        title: const Text('تذكير'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;
    if (selectedCourseId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إضافة مادة واختيارها قبل حفظ المحاضرة.')),
      );
      return;
    }

    final scheduleEntry = {
      'day_of_week': selectedDay,
      'course_id': selectedCourseId,
      'start_time': selectedStart,
      'end_time': selectedEnd,
      'location': locationController.text.trim().isEmpty
          ? 'غير محدد'
          : locationController.text.trim(),
      'reminder_enabled': reminderEnabled ? 1 : 0,
      'reminder_offset_minutes': 15,
    };

    try {
      final existingSchedules = await _databaseHelper.getSchedules();
      final currentId = lecture?['id'];
      final validation = ScheduleConflictValidator.validate(
        day: selectedDay,
        startTime: selectedStart,
        endTime: selectedEnd,
        existingSchedules: existingSchedules,
        excludingScheduleId: currentId is int ? currentId : null,
      );
      if (!validation.isValid) {
        final message = switch (validation.issue) {
          ScheduleValidationIssue.invalidTimeFormat =>
            'صيغة الوقت غير صحيحة. اختر وقتاً صالحاً.',
          ScheduleValidationIssue.invalidTimeRange =>
            'يجب أن يكون وقت النهاية بعد وقت البداية.',
          ScheduleValidationIssue.invalidStoredEntry =>
            'يوجد موعد محفوظ بوقت غير صالح في اليوم نفسه. صححه قبل إضافة موعد آخر.',
          ScheduleValidationIssue.overlap =>
            'هذا الموعد يتداخل مع موعد آخر في اليوم نفسه.',
          null => 'تعذر التحقق من تعارض المواعيد.',
        };
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
        return;
      }

      int? savedId;
      if (lecture == null) {
        savedId = await _databaseHelper.insertSchedule(scheduleEntry);
      } else {
        final id = lecture['id'];
        if (id != null) {
          savedId = id as int;
          await _databaseHelper.updateSchedule({
            ...scheduleEntry,
            'id': id,
          });
        }
      }

      if (savedId != null && reminderEnabled) {
        await NotificationService.instance.scheduleLectureReminder(
          id: savedId,
          title: selectedCourseId != null
              ? (_courses
                  .firstWhere(
                    (course) => course.id == selectedCourseId,
                    orElse: () => const CourseModel(
                      id: null,
                      name: 'محاضرة',
                      instructor: '',
                      code: 'GENERAL',
                    ),
                  )
                  .name)
              : 'محاضرة',
          weekdayName: selectedDay,
          startTime: selectedStart,
          reminderEnabled: true,
          location: locationController.text.trim().isEmpty
              ? 'غير محدد'
              : locationController.text.trim(),
          reminderOffsetMinutes: 15,
        );
      } else if (savedId != null) {
        await NotificationService.instance.cancelLectureReminder(savedId);
      }

      await _loadLectures();
    } catch (error, stackTrace) {
      debugPrint(
          'ScheduleScreen._showLectureDialog save error: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ المحاضرة.')),
        );
      }
    }
  }

  Future<String?> _pickTime(String initialValue) async {
    try {
      final parts = initialValue.split(':');
      final hour = int.tryParse(parts.first) ?? 8;
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: hour, minute: minute),
      );

      if (picked == null) return null;
      return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    } catch (e, st) {
      debugPrint('ScheduleScreen._pickTime parse error: $e\n$st');
      return null;
    }
  }

  List<Map<String, dynamic>> _dayLectures(String day) {
    try {
      final list =
          _lectures.where((lecture) => (lecture['day'] ?? '') == day).toList();
      list.sort((a, b) {
        final aTime = (a['start'] ?? '00:00').toString();
        final bTime = (b['start'] ?? '00:00').toString();
        return aTime.compareTo(bTime);
      });
      return list;
    } catch (e, st) {
      debugPrint('ScheduleScreen._dayLectures error: $e\n$st');
      return <Map<String, dynamic>>[];
    }
  }

  String _currentArabicDay() {
    // DateTime.weekday: Monday=1 ... Sunday=7
    final wd = DateTime.now().weekday;
    switch (wd) {
      case 6:
        return 'السبت';
      case 7:
        return 'الأحد';
      case 1:
        return 'الاثنين';
      case 2:
        return 'الثلاثاء';
      case 3:
        return 'الأربعاء';
      case 4:
        return 'الخميس';
      case 5:
        return 'الجمعة';
      default:
        return 'السبت';
    }
  }

  @override
  void initState() {
    super.initState();
    try {
      _selectedDay = _currentArabicDay();
    } catch (e, st) {
      debugPrint('ScheduleScreen.initState fallback: $e\n$st');
      _selectedDay = 'السبت';
    }
    _loadLectures();
  }

  @override
  Widget build(BuildContext context) {
    final selectedLectures = _dayLectures(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الجدول الدراسي'),
        actions: [
          IconButton(
            tooltip: 'استيراد الجدول من صورة',
            onPressed: _isImportingSchedule ? null : _importScheduleImage,
            icon: _isImportingSchedule
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_search_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: Column(
              children: [
                SizedBox(
                  height: 62,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _days.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final day = _days[index];
                      final selected = day == _selectedDay;
                      return ChoiceChip(
                        label: Text(day),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedDay = day),
                        selectedColor: Theme.of(context).colorScheme.primary,
                        labelStyle: TextStyle(
                          color: selected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : selectedLectures.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.event_busy_outlined,
                                        size: 52, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'لا توجد محاضرات لهذا اليوم',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'أضف محاضرة جديدة من الزر في الأسفل.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                      onPressed: () => _showLectureDialog(),
                                      icon: const Icon(Icons.add),
                                      label: const Text('إضافة محاضرة'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: selectedLectures.length,
                              itemBuilder: (context, index) {
                                final lecture = selectedLectures[index];
                                final color = lecture['color'] is Color
                                    ? lecture['color'] as Color
                                    : Theme.of(context).colorScheme.primary;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  color: Theme.of(context).cardColor,
                                  child: ListTile(
                                    leading: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    title: Text(
                                        lecture['courseTitle'] ?? 'محاضرة'),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time,
                                                size: 16),
                                            const SizedBox(width: 6),
                                            Text(
                                                '${lecture['start'] ?? '--:--'} - ${lecture['end'] ?? '--:--'}'),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                                Icons.location_on_outlined,
                                                size: 16),
                                            const SizedBox(width: 6),
                                            Expanded(
                                                child: Text(
                                                    lecture['location'] ??
                                                        'غير محدد')),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          lecture['instructor'] ?? '',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (lecture['reminder'] == true)
                                          const Icon(
                                              Icons
                                                  .notifications_active_outlined,
                                              color: Colors.orange),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () => _showLectureDialog(
                                              lecture: lecture),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.red),
                                          onPressed: () async {
                                            final id = lecture['id'];
                                            if (id != null) {
                                              final scheduleId = id as int;
                                              await _databaseHelper
                                                  .deleteSchedule(scheduleId);
                                              await NotificationService.instance
                                                  .cancelLectureReminder(
                                                      scheduleId);
                                              await _loadLectures();
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLectureDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة محاضرة'),
      ),
    );
  }
}
