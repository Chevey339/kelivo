import 'dart:async';

import 'package:Kelivo/core/utils/scheduler_idle.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('waits alongside animation frames without idle task polling', (
    tester,
  ) async {
    final strategy = tester.binding.schedulingStrategy;
    var checks = 0;
    tester.binding.schedulingStrategy =
        ({required priority, required scheduler}) {
          checks++;
          return strategy(priority: priority, scheduler: scheduler);
        };
    addTearDown(() => tester.binding.schedulingStrategy = strategy);
    final ticker = Ticker((_) {})..start();
    addTearDown(ticker.dispose);
    var ready = false;
    unawaited(waitForSchedulerIdle().then((_) => ready = true));
    await tester.pump(const Duration(seconds: 1));
    expect(ready, false);
    expect(checks, lessThanOrEqualTo(2));
    await tester.pump(const Duration(milliseconds: 16));
    expect(ready, false);
    expect(checks, lessThanOrEqualTo(3));
    ticker.stop();
    await tester.pump();
    expect(ready, true);
  });

  testWidgets(
    'cancellation completes before animation and prevents later work',
    (tester) async {
      final ticker = Ticker((_) {})..start();
      final abort = Completer<void>();
      bool? ready;
      unawaited(
        waitForSchedulerIdle(cancelled: abort.future).then((v) => ready = v),
      );
      await tester.pump(Duration.zero);
      expect(ready, isNull);
      abort.complete();
      await tester.pump();
      expect(ready, false);
      ticker.dispose();
      await tester.pump();
      expect(ready, false);
    },
  );

  testWidgets('already idle work still starts asynchronously', (tester) async {
    var ready = false;
    unawaited(waitForSchedulerIdle().then((_) => ready = true));
    expect(ready, false);
    await tester.pump(Duration.zero);
    expect(ready, true);
  });
}
