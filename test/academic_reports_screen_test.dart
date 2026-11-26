import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:academic_os/core/academic/academic_report_service.dart';
import 'package:academic_os/presentation/reports/academic_reports_screen.dart';

void main() {
  testWidgets('shows the standalone academic reports screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AcademicReportsScreen()));

    expect(find.text('التقارير الأكاديمية'), findsOneWidget);
    expect(
      find.text('تقارير أكاديمية مبنية على إنجازاتك المسجلة فعلياً'),
      findsOneWidget,
    );
    expect(find.text('إنشاء التقرير اليومي'), findsOneWidget);
    expect(
      find.text('اختر نوع التقرير ثم اضغط «إنشاء التقرير». '),
      findsOneWidget,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('حفظ التقرير ومشاركته'), findsOneWidget);
  });

  testWidgets('changes the selected report period without leaving the screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AcademicReportsScreen()));

    await tester.tap(
      find.byType(DropdownButtonFormField<AcademicReportPeriod>),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('التقرير الأسبوعي').last);
    await tester.pumpAndSettle();

    expect(find.text('التقارير الأكاديمية'), findsOneWidget);
    expect(find.text('إنشاء التقرير الأسبوعي'), findsOneWidget);
  });
}
