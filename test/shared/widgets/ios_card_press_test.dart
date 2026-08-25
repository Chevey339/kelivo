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

  testWidgets('mouse exit within slop keeps pressed until tap up', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: IosCardPress(
                baseColor: Colors.transparent,
                pressedScale: 1,
                onTap: () => taps++,
                child: const SizedBox(
                  width: 240,
                  height: 80,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text('row'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    Color color() {
      final box = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(IosCardPress),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return (box.decoration as BoxDecoration).color!;
    }

    final card = tester.getRect(find.byType(IosCardPress));
    final nearEdge = Offset(card.center.dx, card.bottom - 4);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(nearEdge);
    await tester.pump();
    await gesture.down(nearEdge);
    await tester.pump();
    final pressed = color();
    expect(pressed.a, greaterThan(0.05));

    await gesture.moveTo(nearEdge + const Offset(0, 10));
    await tester.pump();
    expect(color().a, greaterThan(0.05));

    await gesture.up();
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('disabling mid-interaction clears hover and pressed', (
    tester,
  ) async {
    var enabled = true;
    late void Function(void Function()) rebuild;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return IosCardPress(
                  baseColor: Colors.transparent,
                  pressedScale: 1,
                  onTap: enabled ? () {} : null,
                  child: const SizedBox(
                    width: 200,
                    height: 48,
                    child: Text('row'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    Color color() {
      final box = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(IosCardPress),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return (box.decoration as BoxDecoration).color!;
    }

    final center = tester.getCenter(find.byType(IosCardPress));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(center);
    await tester.pump();
    await gesture.down(center);
    await tester.pump();
    expect(color().a, greaterThan(0.05));

    enabled = false;
    rebuild(() {});
    await tester.pump();
    expect(color(), Colors.transparent);
  });
}
