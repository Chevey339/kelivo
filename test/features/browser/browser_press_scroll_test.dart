import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'scrolling through a glass button never flashes its touch light',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final scroll = ScrollController();
      var taps = 0;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BrowserGlassScope(
                style: BrowserSurfaceStyle.solid,
                child: ListView(
                  controller: scroll,
                  children: [
                    const SizedBox(height: 160),
                    BrowserPress(
                      // A surface can stretch in a toolbar, but must yield to
                      // scrolling when the same control is used in a list.
                      draggable: true,
                      onTap: () => taps++,
                      child: const BrowserGlass(child: SizedBox(height: 48)),
                    ),
                    const SizedBox(height: 1800),
                  ],
                ),
              ),
            ),
          ),
        );
        final light = find.byKey(const ValueKey('browserGlassTouchLight'));
        final button = find.byType(BrowserPress);
        final gesture = await tester.startGesture(tester.getCenter(button));
        await tester.pump(const Duration(milliseconds: 20));
        expect(light, findsNothing);
        await gesture.moveBy(const Offset(0, -40));
        await tester.pump(const Duration(milliseconds: 20));
        expect(light, findsNothing);
        await gesture.moveBy(const Offset(0, -80));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(0));
        expect(taps, 0);
        expect(light, findsNothing);

        scroll.jumpTo(0);
        await tester.pump();
        final press = await tester.startGesture(tester.getCenter(button));
        await tester.pump(const Duration(milliseconds: 110));
        await tester.pump(const Duration(milliseconds: 100));
        expect(light, findsOneWidget);
        await press.up();
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(light, findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        scroll.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
