import 'package:Kelivo/features/home/widgets/scroll_nav_buttons.dart';
import 'package:Kelivo/features/settings/widgets/memory_navigable_list.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _list({required int count, bool Function(int index)? isEntry}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: 400,
          child: MemoryNavigableList(
            itemCount: count,
            isEntry: isEntry ?? (_) => true,
            itemBuilder: (context, i) =>
                SizedBox(height: 100, child: Text('Item $i')),
          ),
        ),
      ),
    ),
  );
}

bool _navVisible(WidgetTester tester) => tester
    .widget<ScrollNavButtonsPanel>(find.byType(ScrollNavButtonsPanel))
    .visible;

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

double _offsetFromListTop(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy -
    tester.getTopLeft(find.byType(MemoryNavigableList)).dy;

void main() {
  testWidgets('navigation buttons show while scrolling and hide after', (
    tester,
  ) async {
    await tester.pumpWidget(_list(count: 30));
    expect(_navVisible(tester), isFalse);

    await tester.drag(find.text('Item 0'), const Offset(0, -150));
    await tester.pump();
    expect(_navVisible(tester), isTrue);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(_navVisible(tester), isFalse);
  });

  testWidgets('previous and next step one memory at a time, skipping headers', (
    tester,
  ) async {
    // Item 2 stands in for a section header.
    await tester.pumpWidget(_list(count: 30, isEntry: (i) => i != 2));
    await tester.drag(find.text('Item 0'), const Offset(0, -10));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Lucide.ChevronDown));
    await tester.pumpAndSettle();
    expect(_offsetFromListTop(tester, 'Item 1'), 0);

    await tester.tap(find.byIcon(Lucide.ChevronDown));
    await tester.pumpAndSettle();
    expect(_offsetFromListTop(tester, 'Item 3'), 0);

    await tester.tap(find.byIcon(Lucide.ChevronUp));
    await tester.pumpAndSettle();
    expect(_offsetFromListTop(tester, 'Item 1'), 0);
  });

  testWidgets('top and bottom jump to the ends of the list', (tester) async {
    await tester.pumpWidget(_list(count: 30));
    await tester.drag(find.text('Item 0'), const Offset(0, -10));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Lucide.ChevronsDown));
    await tester.pumpAndSettle();
    final position = _position(tester);
    expect(position.pixels, position.maxScrollExtent);
    expect(find.text('Item 29'), findsOneWidget);

    await tester.tap(find.byIcon(Lucide.ChevronsUp));
    await tester.pumpAndSettle();
    expect(_position(tester).pixels, 0);
    expect(find.text('Item 0'), findsOneWidget);
  });

  testWidgets('previous leaves the end of the list on the first tap', (
    tester,
  ) async {
    // 6 x 100 in a 400 viewport: items 3-5 can never reach the top.
    await tester.pumpWidget(_list(count: 6));
    await tester.drag(find.text('Item 0'), const Offset(0, -10));
    await tester.pumpAndSettle();

    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byIcon(Lucide.ChevronDown));
      await tester.pumpAndSettle();
    }
    final position = _position(tester);
    expect(position.pixels, position.maxScrollExtent);
    expect(_offsetFromListTop(tester, 'Item 2'), 0);

    await tester.tap(find.byIcon(Lucide.ChevronUp));
    await tester.pumpAndSettle();
    expect(_offsetFromListTop(tester, 'Item 1'), 0);
  });
}
