import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';

import '../../support/business_test_harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('transparent no-scale press keeps AnimatedContainer wash', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
        child: MaterialApp(
          home: Scaffold(
            body: IosCardPress(
              baseColor: Colors.transparent,
              pressedScale: 1,
              borderRadius: BorderRadius.circular(12),
              onTap: () {},
              child: const SizedBox(width: 200, height: 48, child: Text('row')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AnimatedScale), findsNothing);
    expect(find.byType(AnimatedContainer), findsOneWidget);

    Color color() {
      final box = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(IosCardPress),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return (box.decoration as BoxDecoration).color!;
    }

    expect(color(), Colors.transparent);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byType(IosCardPress)));
    await tester.pump();

    expect(color().a, greaterThan(0.05));
    expect(find.byType(AnimatedScale), findsNothing);
    expect(find.byType(AnimatedContainer), findsOneWidget);

    await gesture.down(tester.getCenter(find.byType(IosCardPress)));
    await tester.pump();
    expect(color().a, greaterThan(0.05));

    await gesture.up();
    await tester.pump();
    expect(color().a, greaterThan(0.05));
  });

  testWidgets('pressedBlendStrength 0 omits AnimatedContainer', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
        child: MaterialApp(
          home: Scaffold(
            body: IosCardPress(
              baseColor: Colors.transparent,
              pressedScale: 1,
              pressedBlendStrength: 0,
              onTap: () {},
              child: const SizedBox(width: 200, height: 48, child: Text('row')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AnimatedScale), findsNothing);
    expect(find.byType(AnimatedContainer), findsNothing);
    expect(find.byType(DecoratedBox), findsWidgets);
  });

  testWidgets('pressedScale keeps AnimatedScale', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
        child: MaterialApp(
          home: Scaffold(
            body: IosCardPress(
              pressedScale: 0.98,
              onTap: () {},
              child: const SizedBox(width: 200, height: 48, child: Text('row')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AnimatedScale), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsOneWidget);
  });

  testWidgets('long-pressing a tap-only button still completes the tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
        child: MaterialApp(
          home: Scaffold(
            body: IosCardPress(
              onTap: () => taps++,
              child: const SizedBox(width: 200, height: 48, child: Text('row')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final center = tester.getCenter(find.text('row'));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('non-interactive IosCardPress does not swallow a child tap', (
    tester,
  ) async {
    var childTaps = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
        child: MaterialApp(
          home: Scaffold(
            body: IosCardPress(
              child: GestureDetector(
                onTap: () => childTaps++,
                child: const SizedBox(
                  width: 200,
                  height: 48,
                  child: Text('inner'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('inner'));
    await tester.pump();
    expect(childTaps, 1);
  });
}
