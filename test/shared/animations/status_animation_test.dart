import 'dart:async';

import 'package:Kelivo/shared/animations/status_animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {String? pausedBy}) => MediaQuery(
  data: MediaQueryData(disableAnimations: pausedBy == 'reduce motion'),
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

  testWidgets('returning from settings plays with accessible navigation', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final dispatcher = tester.platformDispatcher;
    dispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    addTearDown(dispatcher.clearAccessibilityFeaturesTestValue);
    late ValueListenable<double> progress;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: StatusAnimation(
          duration: const Duration(seconds: 2),
          builder: (_, value) {
            progress = value;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    expect(progress.value, greaterThan(0));

    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Settings')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final covered = progress.value;
    await tester.pump(const Duration(seconds: 1));
    expect(progress.value, covered);
    expect(tester.binding.hasScheduledFrame, isFalse);

    dispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      accessibleNavigation: true,
    );
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    final returned = progress.value;
    await tester.pump(const Duration(milliseconds: 40));
    expect(progress.value, greaterThan(returned));
    await tester.pumpWidget(const SizedBox());
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('Android clock advances when inactive and pauses when hidden', (
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
    final beforeInactive = progress.value;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 40));
    final beforeHidden = progress.value;
    expect(beforeHidden, greaterThan(beforeInactive));

    for (final state in [AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump(const Duration(milliseconds: 750));
      expect(progress.value, beforeHidden);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    }

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 40));
    expect(progress.value, greaterThan(beforeHidden));
    expect(progress.value - beforeHidden, lessThan(0.03));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('the status clock pauses when the Windows window loses focus', (
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
    expect(before, greaterThan(0));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 1));
    expect(progress.value, before);
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  }, variant: const TargetPlatformVariant({TargetPlatform.windows}));

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
