import 'package:flutter/material.dart';

import '../../domain/usecases/course_use_cases.dart';
import '../gpa/gpa_calculator_screen.dart';
import '../gpa/target_grade_calculator_screen.dart';
import '../grade_simulator/grade_simulator_screen.dart';
import '../screens/grade_distribution_screen.dart';

class GradeToolsHubScreen extends StatelessWidget {
  final CourseUseCases courseUseCases;

  const GradeToolsHubScreen({
    super.key,
    required this.courseUseCases,
  });

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('أدوات الدرجات والمعدل')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'اختر الأداة التي تحتاجها. كل أداة لها غرض مختلف ولا تنشئ سجلات مكررة.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.school_outlined)),
              title: const Text('حاسبة المعدل الأكاديمي'),
              subtitle: const Text('قراءة درجات المقررات المحفوظة وحساب المعدل الموزون بالساعات'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _open(context, const GpaCalculatorScreen()),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.flag_outlined)),
              title: const Text('حاسبة الدرجة المطلوبة'),
              subtitle: const Text('احسب الدرجة التي تحتاجها في النهائي للوصول إلى هدفك'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _open(
                context,
                TargetGradeCalculatorScreen(courseUseCases: courseUseCases),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.tune_rounded)),
              title: const Text('محاكي الدرجات'),
              subtitle: const Text('جرّب سيناريوهات الدرجات النظرية والعملية قبل الاختبارات'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _open(context, const GradeSimulatorScreen()),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.pie_chart_outline_rounded)),
              title: const Text('توزيع مكونات الدرجة'),
              subtitle: const Text('استكشف توزيع درجات المقرر النظري أو العملي'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _open(context, const GradeDistributionScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
