import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/presentation/course/document_viewer_screen.dart';

void main() {
  testWidgets('shows the current page count and enables valid navigation', (tester) async {
    var previous = 0;
    var next = 0;
    var zoomIn = 0;
    var zoomOut = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentViewerControls(
            currentPage: 2,
            pageCount: 8,
            enabled: true,
            onPrevious: () => previous++,
            onNext: () => next++,
            onZoomIn: () => zoomIn++,
            onZoomOut: () => zoomOut++,
          ),
        ),
      ),
    );
    expect(find.text('2 / 8'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pdf-previous-page')));
    await tester.tap(find.byKey(const Key('pdf-next-page')));
    await tester.tap(find.byKey(const Key('pdf-zoom-in')));
    await tester.tap(find.byKey(const Key('pdf-zoom-out')));
    expect(previous, 1);
    expect(next, 1);
    expect(zoomIn, 1);
    expect(zoomOut, 1);
  });

  testWidgets('disables previous and next controls at document boundaries', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentViewerControls(
            currentPage: 1,
            pageCount: 1,
            enabled: true,
            onPrevious: () {},
            onNext: () {},
            onZoomIn: () {},
            onZoomOut: () {},
          ),
        ),
      ),
    );
    final previous = tester.widget<IconButton>(find.byKey(const Key('pdf-previous-page')));
    final next = tester.widget<IconButton>(find.byKey(const Key('pdf-next-page')));
    expect(previous.onPressed, isNull);
    expect(next.onPressed, isNull);
  });
}
