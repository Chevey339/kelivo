import 'package:Kelivo/features/browser/browser_desktop_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('presentation fades without moving or resizing its native host', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    const pageKey = ValueKey('browserPresentation');
    var builds = 0;
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const ColoredBox(color: Colors.black),
      ),
    );
    final route = BrowserDesktopRoute(
      reduceMotion: false,
      builder: (_) {
        builds++;
        return GestureDetector(
          onTap: () => taps++,
          child: const ColoredBox(key: pageKey, color: Colors.white),
        );
      },
    );
    navigator.currentState!.push(route);
    await tester.pump();
    await tester.pump();
    final page = find.byKey(pageKey);
    final initialBounds = tester.getRect(page);
    final fade = find.ancestor(of: page, matching: find.byType(FadeTransition));
    double opacity() => tester.widget<FadeTransition>(fade.first).opacity.value;
    expect(opacity(), 0);
    await tester.pump(const Duration(milliseconds: 80));
    expect(opacity(), allOf(greaterThan(0), lessThan(1)));
    expect(tester.getRect(page), initialBounds);
    await tester.tap(page, warnIfMissed: false);
    expect(taps, 0);
    await tester.pumpAndSettle();
    expect(opacity(), 1);
    expect(builds, 1, reason: 'animation must not rebuild the native page');
    await tester.tap(page);
    expect(taps, 1);

    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(opacity(), allOf(greaterThan(0), lessThan(1)));
    expect(tester.getRect(page), initialBounds);
    expect(builds, 1);
    await tester.tap(page, warnIfMissed: false);
    expect(taps, 1, reason: 'a second dock click must not pop the next route');
    await tester.pumpAndSettle();
    expect(page, findsNothing);
  });

  testWidgets('reduced motion switches presentations without an animation', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const SizedBox.expand()),
    );
    final route = BrowserDesktopRoute(
      reduceMotion: true,
      builder: (_) => const ColoredBox(
        key: ValueKey('reducedMotionPage'),
        color: Colors.white,
      ),
    );
    navigator.currentState!.push(route);
    await tester.pumpAndSettle();
    expect(route.animation!.value, 1);
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reducedMotionPage')), findsNothing);
  });
}
