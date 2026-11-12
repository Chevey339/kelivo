import 'package:Kelivo/shared/animations/status_animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {String? pausedBy}) => MediaQuery(
  data: MediaQueryData(
    disableAnimations: pausedBy == 'reduce motion',
    accessibleNavigation: pausedBy == 'accessible navigation',
  ),
  child: TickerMode(
    enabled: pausedBy != 'ticker mode',
    child: Visibility(
      visible: pausedBy != 'visibility',
      maintainState: true,
      maintainAnimation: true,
      child: child,
    ),
  ),
);

void main() {
  testWidgets('many status effects share bounded updates on a 120 Hz display', (
    tester,
  ) async {
    final progress = <ValueListenable<double>>[];
    await tester.pumpWidget(
      _host(
        Column(
          children: List.generate(
            8,
            (_) => StatusAnimation(
              duration: const Duration(seconds: 2),
              builder: (_, value) {
                progress.add(value);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    final ticks = List.filled(progress.length, 0);
    for (var i = 0; i < progress.length; i++) {
      progress[i].addListener(() => ticks[i]++);
    }
    for (var frame = 0; frame < 120; frame++) {
      await tester.pump(const Duration(microseconds: 8333));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
    expect(ticks.first, inInclusiveRange(29, 30));
    expect(ticks, everyElement(ticks.first));
    expect(progress.first.value, closeTo(0.5, 0.03));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  for (final pause in [
    'explicit pause',
    'ticker mode',
    'visibility',
    'reduce motion',
    'accessible navigation',
  ]) {
    testWidgets('$pause stops updates and resumes without losing phase', (
      tester,
    ) async {
      late ValueListenable<double> progress;
      Widget effect({bool paused = false}) => _host(
        StatusAnimation(
          duration: const Duration(seconds: 2),
          paused: paused && pause == 'explicit pause',
          builder: (_, value) {
            progress = value;
            return const SizedBox();
          },
        ),
        pausedBy: paused ? pause : null,
      );
      await tester.pumpWidget(effect());
      await tester.pump(const Duration(milliseconds: 40));
      final before = progress.value;
      expect(before, greaterThan(0));
      await tester.pumpWidget(effect(paused: true));
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(progress.value, before);
        expect(tester.binding.hasScheduledFrame, isFalse);
      }
      await tester.pumpWidget(effect());
      expect(progress.value, before);
      await tester.pump(const Duration(milliseconds: 40));
      expect(progress.value, greaterThan(before));
      expect(progress.value - before, lessThan(0.03));
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('backgrounding stops the clock and resuming keeps its phase', (
    tester,
  ) async {
    late ValueListenable<double> progress;
    await tester.pumpWidget(
      _host(
        StatusAnimation(
          duration: const Duration(seconds: 2),
          builder: (_, value) {
            progress = value;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    final before = progress.value;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 5));
    expect(progress.value, before);
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 40));
    expect(progress.value, greaterThan(before));
    expect(progress.value - before, lessThan(0.03));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('removing one consumer keeps others running, then stops fully', (
    tester,
  ) async {
    late ValueListenable<double> remaining;
    Widget effects({required bool first}) => _host(
      Column(
        children: [
          if (first)
            StatusAnimation(
              key: const ValueKey('first'),
              duration: const Duration(seconds: 1),
              builder: (_, _) => const SizedBox(),
            ),
          StatusAnimation(
            key: const ValueKey('remaining'),
            duration: const Duration(seconds: 2),
            builder: (_, value) {
              remaining = value;
              return const SizedBox();
            },
          ),
        ],
      ),
    );
    await tester.pumpWidget(effects(first: true));
    await tester.pump(const Duration(milliseconds: 40));
    final before = remaining.value;
    await tester.pumpWidget(effects(first: false));
    await tester.pump(const Duration(milliseconds: 40));
    expect(remaining.value, greaterThan(before));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
