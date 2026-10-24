import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/widgets/browser_agent_status_chip.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    BrowserAgentActivity activity, {
    double scale = 1,
    double width = 390,
    VoidCallback? onPause,
    VoidCallback? onResume,
    BrowserAgentPauseReason? pauseReason,
  }) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: BrowserGlassScope(
                style: BrowserSurfaceStyle.solid,
                child: BrowserAgentStatusChip(
                  activity: activity,
                  pauseReason: pauseReason,
                  onPause: onPause ?? () {},
                  onResume: onResume ?? () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('idle has no status surface or action', (tester) async {
    await mount(tester, BrowserAgentActivity.idle);
    expect(find.byKey(const ValueKey('browserAgentStatusChip')), findsNothing);
    expect(find.text('AI is working'), findsNothing);
    expect(find.text('Allow to continue'), findsNothing);
  });

  testWidgets('running status is passive and only Take over pauses', (
    tester,
  ) async {
    var paused = 0;
    var resumed = 0;
    await mount(
      tester,
      BrowserAgentActivity.running,
      onPause: () => paused++,
      onResume: () => resumed++,
    );
    expect(find.text('AI is working'), findsOneWidget);
    final chip = find.byKey(const ValueKey('browserAgentStatusChip'));
    expect(tester.getSize(chip).height, lessThan(50));
    expect(paused, 0);
    await tester.tap(find.text('AI is working'));
    await tester.pumpAndSettle();
    expect(paused, 0);
    await tester.tap(find.text('Take over'));
    await tester.pumpAndSettle();
    expect(paused, 1);
    expect(resumed, 0);
  });

  testWidgets('paused state resumes without presenting a running label', (
    tester,
  ) async {
    var resumed = 0;
    await mount(tester, BrowserAgentActivity.paused, onResume: () => resumed++);
    expect(find.text('AI actions paused'), findsOneWidget);
    expect(find.text('AI is working'), findsNothing);
    await tester.tap(find.text('Allow to continue'));
    await tester.pumpAndSettle();
    expect(resumed, 1);
  });

  testWidgets('large text wraps naturally inside a narrow viewport', (
    tester,
  ) async {
    await mount(tester, BrowserAgentActivity.paused, width: 320, scale: 3);
    final rect = tester.getRect(
      find.byKey(const ValueKey('browserAgentStatusChip')),
    );
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(find.text('Allow to continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeout pause explains its cause and keeps the resume action', (
    tester,
  ) async {
    var resumed = 0;
    await mount(
      tester,
      BrowserAgentActivity.paused,
      pauseReason: BrowserAgentPauseReason.timeout,
      onResume: () => resumed++,
      width: 320,
      scale: 3,
    );
    expect(find.text('Operation timed out; AI paused'), findsOneWidget);
    expect(find.text('AI actions paused'), findsNothing);
    expect(find.text('Take over'), findsNothing);
    final rect = tester.getRect(
      find.byKey(const ValueKey('browserAgentStatusChip')),
    );
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    await tester.tap(find.text('Allow to continue'));
    expect(resumed, 1);
    expect(tester.takeException(), isNull);
  });
}
