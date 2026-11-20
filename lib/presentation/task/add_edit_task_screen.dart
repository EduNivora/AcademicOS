import 'package:flutter/material.dart';
import '../../core/notifications/notification_service.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/usecases/course_use_cases.dart';
import '../../domain/usecases/task_use_cases.dart';

class AddEditTaskScreen extends StatefulWidget {
  final TaskUseCases useCases;
  final CourseUseCases courseUseCases;
  final TaskEntity? existingTask;
  final CourseEntity? initialCourse;

  const AddEditTaskScreen({
    super.key,
    required this.useCases,
    required this.courseUseCases,
    this.existingTask,
    this.initialCourse,
  });

  @override
  State<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends State<AddEditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;
  late TaskType _selectedType;
  late TaskPriority _selectedPriority;
  late TaskRecurrence _selectedRecurrence;
  DateTime? _dueDate;
  DateTime? _endDateTime;
  bool _isSaving = false;
  bool _isCompleted = false;
  bool _reminderEnabled = false;
  DateTime? _reminderDate;
  int _reminderOffsetMinutes = 30;
  List<CourseEntity> _availableCourses = [];
  CourseEntity? _selectedCourse;
  bool _isCourseLoading = true;
  String? _courseError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingTask?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.existingTask?.description ?? '',
    );
    _notesController = TextEditingController(
      text: widget.existingTask?.notes ?? '',
    );
    _selectedType = widget.existingTask?.type ?? TaskType.other;
    _selectedPriority = widget.existingTask?.priority ?? TaskPriority.medium;
    _selectedRecurrence =
        widget.existingTask?.recurrence ?? TaskRecurrence.once;
    _dueDate = widget.existingTask?.dueDate;
    _endDateTime = widget.existingTask?.endDateTime;
    _isCompleted = widget.existingTask?.isCompleted ?? false;
    _reminderEnabled = widget.existingTask?.reminderEnabled ?? false;
    _reminderDate = widget.existingTask?.reminderDate;
    _reminderOffsetMinutes = widget.existingTask?.reminderOffsetMinutes ?? 30;
    if (widget.existingTask != null) {
      _selectedCourse = widget.existingTask!.courseId != null
          ? CourseEntity(
              id: widget.existingTask!.courseId,
              name: widget.existingTask!.courseName ?? 'المادة المرتبطة',
              instructor: '',
              code: '',
            )
          : null;
    } else {
      _selectedCourse = widget.initialCourse;
    }
    _loadCourses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (selectedDate != null) {
      setState(() => _dueDate = selectedDate);
    }
  }

  Future<void> _pickEndDateTime() async {
    final now = DateTime.now();
    final initialDate = _endDateTime ?? _dueDate ?? now;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (selectedTime == null || !mounted) return;

    setState(() {
      _endDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      if (_reminderEnabled) {
        _reminderDate = _endDateTime!.subtract(
          Duration(minutes: _reminderOffsetMinutes),
        );
      }
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    final startDateTime =
        widget.existingTask?.startDateTime ?? DateTime.now();
    if (_endDateTime != null && !_endDateTime!.isAfter(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب أن يكون وقت الانتهاء بعد وقت البدء التلقائي.')),
      );
      return;
    }

    if (_reminderEnabled) {
      if (_endDateTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدد وقت الانتهاء أولاً لتفعيل التنبيه.')),
        );
        return;
      }
      _reminderDate = _endDateTime!.subtract(
        Duration(minutes: _reminderOffsetMinutes),
      );
      if (_reminderDate!.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('وقت التنبيه المحسوب أصبح في الماضي. اختر وقت انتهاء لاحقاً.')),
        );
        return;
      }
    } else {
      _reminderDate = null;
    }

    final task = TaskEntity(
      id: widget.existingTask?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _selectedType,
      priority: _selectedPriority,
      recurrence: _selectedRecurrence,
      dueDate: _dueDate,
      startDateTime: startDateTime,
      endDateTime: _endDateTime,
      isCompleted: _isCompleted,
      completedAt: _isCompleted
          ? widget.existingTask?.completedAt ?? DateTime.now()
          : null,
      courseId: _selectedCourse?.id,
      courseName: _selectedCourse?.name,
      notes: _notesController.text.trim(),
      reminderEnabled: _reminderEnabled,
      reminderDate: _reminderEnabled ? _reminderDate : null,
      reminderOffsetMinutes: _reminderOffsetMinutes,
    );

    setState(() => _isSaving = true);

    try {
      if (widget.existingTask == null) {
        await widget.useCases.addTask(task);
      } else {
        await widget.useCases.updateTask(task);
      }

      final tasks = await widget.useCases.getTasks();
      final courses = await widget.courseUseCases.getCourses();
      await NotificationService.instance.syncReminders(
        tasks: tasks,
        courses: courses,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('AddEditTaskScreen._saveTask error: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء حفظ المهمة.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isCourseLoading = true;
      _courseError = null;
    });

    try {
      final courses = await widget.courseUseCases.getCourses();
      if (!mounted) return;
      setState(() {
        _availableCourses = courses;
        if (_selectedCourse != null) {
          _selectedCourse = courses.firstWhere(
            (course) => course.id == _selectedCourse!.id,
            orElse: () => _selectedCourse!,
          );
        }
      });
    } catch (error, stackTrace) {
      debugPrint('AddEditTaskScreen._loadCourses error: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _courseError = 'فشل تحميل المواد');
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() => _isCourseLoading = false);
    }
  }

  Widget _buildPickerTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
    required bool isSet,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.indigo.shade600),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSet)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.clear, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingTask != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'تعديل مهمة' : 'إضافة مهمة')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration:
                          const InputDecoration(labelText: 'عنوان المهمة'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'أدخل عنوان المهمة'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration:
                          const InputDecoration(labelText: 'وصف المهمة'),
                      maxLines: 4,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'أدخل وصف المهمة'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<TaskType>(
                            value: _selectedType,
                            items: TaskType.values
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedType = value);
                              }
                            },
                            decoration:
                                const InputDecoration(labelText: 'نوع المهمة'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<TaskPriority>(
                            value: _selectedPriority,
                            decoration: const InputDecoration(
                              labelText: 'أولوية المهمة',
                            ),
                            items: TaskPriority.values
                                .map(
                                  (priority) => DropdownMenuItem(
                                    value: priority,
                                    child: Text(priority.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedPriority = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<TaskRecurrence>(
                            value: _selectedRecurrence,
                            decoration: const InputDecoration(
                              labelText: 'تكرار المهمة',
                            ),
                            items: TaskRecurrence.values
                                .map(
                                  (recurrence) => DropdownMenuItem(
                                    value: recurrence,
                                    child: Text(recurrence.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedRecurrence = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _isCourseLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(),
                          )
                        : DropdownButtonFormField<int?>(
                            value: _selectedCourse?.id,
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('بدون كورس'),
                              ),
                              ..._availableCourses.map(
                                (course) => DropdownMenuItem<int?>(
                                  value: course.id,
                                  child: Text(course.name),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                if (value == null) {
                                  _selectedCourse = null;
                                  return;
                                }
                                _selectedCourse = _availableCourses.firstWhere(
                                  (course) => course.id == value,
                                  orElse: () => CourseEntity(
                                    id: value,
                                    name: 'المقرر مرتبط',
                                    instructor: '',
                                    code: '',
                                  ),
                                );
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'المادة المرتبطة',
                            ),
                          ),
                    if (_courseError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _courseError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPickerTile(
                            icon: Icons.calendar_today_outlined,
                            title: 'تاريخ الاستحقاق',
                            value: _dueDate == null
                                ? 'اختر التاريخ'
                                : _formatDate(_dueDate!),
                            onTap: _pickDueDate,
                            isSet: _dueDate != null,
                            onClear: () => setState(() => _dueDate = null),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.play_circle_outline),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('وقت البدء'),
                                Text(
                                  widget.existingTask?.startDateTime == null
                                      ? 'يُسجل تلقائياً عند حفظ المهمة'
                                      : _formatDateTime(widget.existingTask!.startDateTime!),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.lock_clock_outlined),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPickerTile(
                      icon: Icons.flag_outlined,
                      title: 'وقت الانتهاء',
                      value: _endDateTime == null
                          ? 'اختر وقت الانتهاء'
                          : _formatDateTime(_endDateTime!),
                      onTap: _pickEndDateTime,
                      isSet: _endDateTime != null,
                      onClear: () => setState(() => _endDateTime = null),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات داخلية',
                      ),
                      maxLines: 3,
                    ),
                    CheckboxListTile(
                      value: _isCompleted,
                      onChanged: (value) =>
                          setState(() => _isCompleted = value ?? false),
                      title: const Text('المهمة مكتملة'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    SwitchListTile.adaptive(
                      value: _reminderEnabled,
                      onChanged: (value) {
                        setState(() {
                          _reminderEnabled = value;
                          _reminderDate = value && _endDateTime != null
                              ? _endDateTime!.subtract(
                                  Duration(minutes: _reminderOffsetMinutes),
                                )
                              : null;
                        });
                      },
                      title: const Text('تفعيل تذكير المهمة'),
                      subtitle: const Text(
                        'سيُحسب وقت التنبيه تلقائياً من وقت الانتهاء.',
                      ),
                    ),
                    if (_reminderEnabled) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _reminderOffsetMinutes,
                        decoration: const InputDecoration(
                          labelText: 'التنبيه قبل (دقيقة)',
                        ),
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5 دقائق')),
                          DropdownMenuItem(value: 15, child: Text('15 دقيقة')),
                          DropdownMenuItem(value: 30, child: Text('30 دقيقة')),
                          DropdownMenuItem(value: 60, child: Text('1 ساعة')),
                          DropdownMenuItem(value: 1440, child: Text('1 يوم')),
                        ],
                        onChanged: (value) => setState(
                            () => _reminderOffsetMinutes = value ?? 30),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveTask,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(isEditing ? 'تحديث' : 'حفظ'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
