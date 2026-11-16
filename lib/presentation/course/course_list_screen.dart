import 'dart:async';

import 'package:flutter/material.dart';

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
                                  tooltip: 'حذف المقرر',
                                  onPressed: () async {
                                    final courseId = course.id;
                                    if (courseId == null) return;

                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        title: const Text('حذف المقرر؟'),
                                        content: const Text(
                                          'سيتم حذف المهام والاختبارات والحصص والمرفقات '
                                          'المرتبطة بهذا المقرر أيضاً. لا يمكن التراجع عن ذلك.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialogContext, false),
                                            child: const Text('إلغاء'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(dialogContext, true),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('حذف المقرر'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true || !mounted) return;

                                    try {
                                      await widget.courseUseCases.deleteCourse(courseId);
                                      await _loadCourses();
                                    } catch (error) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('تعذر حذف المقرر: $error'),
                                        ),
                                      );
                                    }
                                  },
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
