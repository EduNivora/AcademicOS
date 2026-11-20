import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/notifications/notification_service.dart';
import '../../data/database/database_helper.dart';

import '../../domain/entities/course_entity.dart';
import '../../domain/usecases/course_use_cases.dart';
import '../../domain/usecases/task_use_cases.dart';
import 'add_edit_course_screen.dart';
import 'course_detail_screen.dart';

class CourseListScreen extends StatefulWidget {
  final CourseUseCases courseUseCases;
  final TaskUseCases taskUseCases;

  const CourseListScreen({
    super.key,
    required this.courseUseCases,
    required this.taskUseCases,
  });

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  List<CourseEntity> _courses = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _confirmAndDeleteCourse(CourseEntity course) async {
    final courseId = course.id;
    if (courseId == null) return;

    List<Map<String, Object?>> taskRows;
    List<Map<String, Object?>> examRows;
    List<Map<String, Object?>> scheduleRows;
    List<Map<String, Object?>> materialRows;
    try {
      final db = await DatabaseHelper.instance.database;
      taskRows = await db.query('tasks', where: 'course_id = ?', whereArgs: [courseId]);
      examRows = await db.query('exams', where: 'course_id = ?', whereArgs: [courseId]);
      scheduleRows = await db.query('schedule', where: 'course_id = ?', whereArgs: [courseId]);
      materialRows = await db.query('course_materials', where: 'course_id = ?', whereArgs: [courseId]);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فحص ارتباطات المقرر قبل الحذف: ' + error.toString())),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المقرر؟'),
        content: Text(
          'سيتم حذف «' + course.name + '» وكل ما يرتبط به نهائياً: ' +
          taskRows.length.toString() + ' مهام، ' +
          examRows.length.toString() + ' اختبارات، ' +
          scheduleRows.length.toString() + ' محاضرات، و' +
          materialRows.length.toString() + ' مرفقات. لا يمكن التراجع عن ذلك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف المقرر وكل ارتباطاته'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final deleted = await widget.courseUseCases.deleteCourse(courseId);
      if (deleted <= 0) throw StateError('لم يتم العثور على المقرر لحذفه.');

      for (final row in taskRows) {
        final id = row['id'];
        if (id is int && (row['reminder_enabled'] == 1 || row['reminder_enabled'] == true)) {
          await NotificationService.instance.cancelTaskReminder(id);
        }
      }
      for (final row in scheduleRows) {
        final id = row['id'];
        if (id is int && (row['reminder_enabled'] == 1 || row['reminder_enabled'] == true)) {
          await NotificationService.instance.cancelLectureReminder(id);
        }
      }
      await _loadCourses();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف المقرر «' + course.name + '» وارتباطاته.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حذف المقرر: ' + error.toString())),
      );
    }
  }

  Future<void> _loadCourses() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final courses = await widget.courseUseCases.getCourses();
    if (!mounted) return;
    setState(() {
      _courses = courses;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => setState(() => _searchQuery = query),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _courses
        .where((course) => course.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('المقررات الدراسية')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      labelText: 'بحث',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('لا توجد مقررات دراسية مضافة'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (_, index) {
                            final course = filtered[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ListTile(
                                title: Text(course.name),
                                subtitle: Text('${course.code} • ${course.instructor}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _confirmAndDeleteCourse(course),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CourseDetailScreen(
                                        course: course,
                                        taskUseCases: widget.taskUseCases,
                                        courseUseCases: widget.courseUseCases,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AddEditCourseScreen(useCases: widget.courseUseCases),
            ),
          );
          if (result == true) {
            await _loadCourses();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
