import 'package:flutter/material.dart';

import '../../data/database/database_helper.dart';
import '../../data/models/course_model.dart';
import '../../domain/entities/course_entity.dart';

class GpaCalculatorScreen extends StatefulWidget {
  const GpaCalculatorScreen({super.key});

  @override
  State<GpaCalculatorScreen> createState() => _GpaCalculatorScreenState();
}

class _GpaCalculatorScreenState extends State<GpaCalculatorScreen> {
  List<CourseEntity> _courses = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('courses', orderBy: 'name ASC');
      final loaded = rows.map(CourseModel.fromMap).toList();
      if (!mounted) return;
      setState(() {
        _courses = loaded;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذّر تحميل المقررات. حاول مرة أخرى.';
        _loading = false;
      });
    }
  }

  double _gradeToPercent(double mid, double practical, double finalGrade) {
    return ((mid * 0.3) + (practical * 0.3) + (finalGrade * 0.4));
  }

  String _letterGrade(double percent) {
    if (percent >= 90) return 'A';
    if (percent >= 85) return 'A-';
    if (percent >= 80) return 'B+';
    if (percent >= 75) return 'B';
    if (percent >= 70) return 'B-';
    if (percent >= 65) return 'C+';
    if (percent >= 60) return 'C';
    if (percent >= 55) return 'C-';
    if (percent >= 50) return 'D';
    return 'F';
  }

  double _letterPoints(String letter) {
    switch (letter) {
      case 'A':
        return 4.0;
      case 'A-':
        return 3.7;
      case 'B+':
        return 3.3;
      case 'B':
        return 3.0;
      case 'B-':
        return 2.7;
      case 'C+':
        return 2.3;
      case 'C':
        return 2.0;
      case 'C-':
        return 1.7;
      case 'D':
        return 1.0;
      default:
        return 0.0;
    }
  }

  String _academicStanding(double gpa) {
    if (gpa >= 3.7) return 'Excellent';
    if (gpa >= 3.3) return 'Very Good';
    if (gpa >= 2.7) return 'Good';
    if (gpa >= 2.0) return 'Fair';
    return 'Needs Improvement';
  }

  Future<void> _updateCourseGrade(int courseId, CourseEntity course) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'courses',
        {
          'mid_grade': course.midGrade ?? 0,
          'practical_grade': course.practicalGrade ?? 0,
          'final_grade': course.finalGrade ?? 0,
          'credit_hours': course.creditHours ?? 3,
        },
        where: 'id = ?',
        whereArgs: [courseId],
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر حفظ التعديلات. حاول مرة أخرى.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCredits = _courses.fold<int>(0, (sum, course) => sum + (course.creditHours ?? 3));
    final weighted = _courses.fold<double>(0, (sum, course) {
      final mid = course.midGrade ?? 0;
      final practical = course.practicalGrade ?? 0;
      final finalGrade = course.finalGrade ?? 0;
      final percent = _gradeToPercent(mid, practical, finalGrade);
      final letter = _letterGrade(percent);
      final points = _letterPoints(letter);
      return sum + ((points * (course.creditHours ?? 3)));
    });
    final gpa = totalCredits == 0 ? 0.0 : weighted / totalCredits;
    final semesterPercent = totalCredits == 0 ? 0.0 : (_courses.fold<double>(0, (sum, course) {
      final mid = course.midGrade ?? 0;
      final practical = course.practicalGrade ?? 0;
      final finalGrade = course.finalGrade ?? 0;
      return sum + (_gradeToPercent(mid, practical, finalGrade) * (course.creditHours ?? 3));
    }) / totalCredits);

    return Scaffold(
      appBar: AppBar(title: const Text('حاسبة المعدل والدرجات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadCourses,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.analytics_outlined),
                            const SizedBox(width: 8),
                            const Text(
                              'Semester GPA',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          gpa.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'معدل الفصل: ${(semesterPercent / 25).clamp(0, 4).toStringAsFixed(2)}/4.0',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'الساعات المكتملة: $totalCredits',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _academicStanding(gpa),
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ..._courses.map((course) {
                  final mid = course.midGrade ?? 0;
                  final practical = course.practicalGrade ?? 0;
                  final finalGrade = course.finalGrade ?? 0;
                  final percent = _gradeToPercent(mid, practical, finalGrade);
                  final letter = _letterGrade(percent);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  course.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$letter • ${percent.toStringAsFixed(0)}%',
                                  style: TextStyle(color: Colors.blue.shade800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text(course.code)),
                              Chip(label: Text('${course.creditHours ?? 3} ساعة')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _gradeInput(
                                  label: 'Mid',
                                  value: mid,
                                  onChanged: (value) async {
                                    final updated = course.copyWith(midGrade: value);
                                    setState(() {
                                      final index = _courses.indexWhere((c) => c.id == course.id);
                                      if (index >= 0) _courses[index] = updated;
                                    });
                                    if (course.id != null) {
                                      await _updateCourseGrade(course.id!, updated);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _gradeInput(
                                  label: 'Practical',
                                  value: practical,
                                  onChanged: (value) async {
                                    final updated = course.copyWith(practicalGrade: value);
                                    setState(() {
                                      final index = _courses.indexWhere((c) => c.id == course.id);
                                      if (index >= 0) _courses[index] = updated;
                                    });
                                    if (course.id != null) {
                                      await _updateCourseGrade(course.id!, updated);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _gradeInput(
                                  label: 'Final',
                                  value: finalGrade,
                                  onChanged: (value) async {
                                    final updated = course.copyWith(finalGrade: value);
                                    setState(() {
                                      final index = _courses.indexWhere((c) => c.id == course.id);
                                      if (index >= 0) _courses[index] = updated;
                                    });
                                    if (course.id != null) {
                                      await _updateCourseGrade(course.id!, updated);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: course.creditHours ?? 3,
                                  decoration: const InputDecoration(labelText: 'Credits'),
                                  items: const [
                                    DropdownMenuItem(value: 1, child: Text('1')),
                                    DropdownMenuItem(value: 2, child: Text('2')),
                                    DropdownMenuItem(value: 3, child: Text('3')),
                                    DropdownMenuItem(value: 4, child: Text('4')),
                                    DropdownMenuItem(value: 5, child: Text('5')),
                                  ],
                                  onChanged: (value) async {
                                    if (value == null || course.id == null) return;
                                    final updated = course.copyWith(creditHours: value);
                                    setState(() {
                                      final index = _courses.indexWhere((c) => c.id == course.id);
                                      if (index >= 0) _courses[index] = updated;
                                    });
                                    await _updateCourseGrade(course.id!, updated);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('${course.id}_$letter'),
                                  initialValue: letter,
                                  decoration: const InputDecoration(labelText: 'Letter'),
                                  items: const [
                                    DropdownMenuItem(value: 'A', child: Text('A')),
                                    DropdownMenuItem(value: 'A-', child: Text('A-')),
                                    DropdownMenuItem(value: 'B+', child: Text('B+')),
                                    DropdownMenuItem(value: 'B', child: Text('B')),
                                    DropdownMenuItem(value: 'B-', child: Text('B-')),
                                    DropdownMenuItem(value: 'C+', child: Text('C+')),
                                    DropdownMenuItem(value: 'C', child: Text('C')),
                                    DropdownMenuItem(value: 'C-', child: Text('C-')),
                                    DropdownMenuItem(value: 'D', child: Text('D')),
                                    DropdownMenuItem(value: 'F', child: Text('F')),
                                  ],
                                  onChanged: (value) async {
                                    if (value == null) return;
                                    final numeric = _letterPoints(value);
                                    final newPercent = (numeric / 4) * 100;
                                    // Store the same normalized component percentage.
                                    // _gradeToPercent applies the 30/30/40 weighting.
                                    final updated = course.copyWith(
                                      midGrade: newPercent,
                                      practicalGrade: newPercent,
                                      finalGrade: newPercent,
                                    );
                                    if (course.id != null) {
                                      await _updateCourseGrade(course.id!, updated);
                                    }
                                    if (!mounted) return;
                                    setState(() {
                                      final index = _courses.indexWhere((c) => c.id == course.id);
                                      if (index >= 0) _courses[index] = updated;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _gradeInput({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return TextFormField(
      initialValue: value.toStringAsFixed(0),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(labelText: label),
      validator: (text) {
        final trimmed = text?.trim() ?? '';
        if (trimmed.isEmpty) return null;
        final parsed = double.tryParse(trimmed);
        if (parsed == null || parsed < 0 || parsed > 100) {
          return '0 - 100';
        }
        return null;
      },
      onChanged: (text) {
        final trimmed = text.trim();
        if (trimmed.isEmpty) {
          onChanged(0);
          return;
        }
        final parsed = double.tryParse(trimmed);
        if (parsed == null) return;
        onChanged(parsed.clamp(0.0, 100.0));
      },
    );
  }
}
