import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> showTooltip(WidgetTester tester, Finder target) async {
    await tester.longPress(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets(
    'AppBar Tooltip around IosIconButton shows a usable long-press tip',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                Tooltip(
                  message: 'x',
                  child: IosIconButton(
                    icon: Lucide.Plus,
                    size: 22,
                    minSize: 44,
                    semanticLabel: 'add',
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('x'), findsNothing);
      await showTooltip(tester, find.byType(IosIconButton));

      final tip = find.text('x');
      expect(tip, findsOneWidget);
      final size = tester.getSize(tip);
      expect(size.width, greaterThan(8));
      expect(size.height, greaterThan(8));
      expect(tester.getRect(tip).top, greaterThan(8));
    },
  );

  testWidgets('IosIconButton.tooltip shows below the AppBar control', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              IosIconButton(
                icon: Lucide.Plus,
                size: 22,
                minSize: 44,
                tooltip: 'x',
                semanticLabel: 'add',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await showTooltip(tester, find.byType(IosIconButton));

    final tip = find.text('x');
    expect(tip, findsOneWidget);
    final rect = tester.getRect(tip);
    expect(rect.width, greaterThan(8));
    expect(rect.height, greaterThan(8));
    expect(
      rect.top,
      greaterThan(tester.getRect(find.byType(IosIconButton)).top),
    );
  });

  testWidgets('IosIconButton tap still fires after tooltip-safe Listener', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IosIconButton(
            icon: Lucide.Plus,
            tooltip: 'x',
            onTap: () => taps += 1,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(IosIconButton));
    await tester.pump();
    expect(taps, 1);
    expect(find.text('x'), findsNothing);
  });
}
