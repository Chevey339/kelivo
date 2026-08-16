import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/desktop/macos_title_bar_drag_area.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  testWidgets('double tap triggers zoom handler', (tester) async {
    var zoomCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MacOSTitleBarDragArea(
            onDoubleTapZoom: () async {
              zoomCount++;
            },
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(MacOSTitleBarDragArea));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(zoomCount, 1);
  });

  testWidgets('uses DragToMoveArea in production mode', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MacOSTitleBarDragArea())),
    );

    expect(find.byType(DragToMoveArea), findsOneWidget);
  });

  testWidgets('renders expected title bar height', (tester) async {
    const customHeight = 36.0;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MacOSTitleBarDragArea(height: customHeight)),
      ),
    );

    final sizedBox = tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(MacOSTitleBarDragArea),
        matching: find.byType(SizedBox),
      ),
    );

    expect(sizedBox.height, customHeight);
  });
}
