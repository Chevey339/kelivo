import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/home/services/context_usage_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/context_usage_details.dart';

ContextUsageSnapshot usageSnap({
  ContextUsageState state = ContextUsageState.estimated,
  int used = 110,
  int? window = 1000,
  bool calibrated = false,
  ContextUsageBuckets buckets = const ContextUsageBuckets(
    system: 10,
    injections: 8,
    history: 70,
    tools: 6,
    attachments: 7,
    draft: 9,
  ),
}) {
  return ContextUsageSnapshot(
    state: state,
    buckets: buckets,
    usedTokens: used,
    contextWindow: window,
    conversationId: 'c1',
    revision: 1,
    providerKey: 'TestProvider',
    modelId: 'window-model',
    assistantId: null,
    computedAt: DateTime.utc(2026, 1, 1),
    calibrated: calibrated,
  );
}

void expectSegment(
  ContextUsageSegment segment, {
  required String key,
  required int tokens,
  required double fraction,
}) {
  expect(segment.key, key);
  expect(segment.tokens, tokens);
  expect(segment.fraction, closeTo(fraction, 1e-9));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final width in [320.0, 720.0]) {
    for (final brightness in Brightness.values) {
      for (final language in ['en', 'zh']) {
        testWidgets('detailed legend fits $width $brightness $language', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 800);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const buckets = ContextUsageBuckets(
            history: 76000,
            tools: 2000,
            mcpTools: 1000,
            skills: 500,
            system: 1300,
            memory: 400,
            worldBook: 200,
            injections: 792,
            workspace: 300,
            search: 100,
            attachments: 258,
            draft: 50,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ContextUsageBreakdown(
                    snapshot: usageSnap(
                      buckets: buckets,
                      used: buckets.total,
                      window: 1000000,
                    ),
                  ),
                ),
              ),
            ),
          );
          for (final key in [
            'memory',
            'worldBook',
            'skills',
            'workspace',
            'search',
            'tools',
            'mcpTools',
          ]) {
            expect(
              find.byKey(ValueKey('context-usage-bucket-$key')),
              findsOneWidget,
            );
          }
          expect(find.text('0%'), findsNothing);
          expect(find.text('<0.1%'), findsWidgets);
          expect(find.text('7.6%'), findsOneWidget);
          expect(tester.takeException(), isNull);
          final segments = buildContextUsageSegments(
            usageSnap(buckets: buckets, used: buckets.total, window: 1000000),
          );
          expect(
            segments.fold<int>(0, (sum, segment) => sum + segment.tokens),
            1000000,
          );
        });
      }
    }
  }

  test('segments with a window are proportional to the window', () {
    final segments = buildContextUsageSegments(usageSnap());
    expect(segments, hasLength(7));
    expectSegment(segments[2], key: 'system', tokens: 10, fraction: 0.01);
    expectSegment(segments[3], key: 'injections', tokens: 8, fraction: 0.008);
    expectSegment(segments[0], key: 'history', tokens: 70, fraction: 0.07);
    expectSegment(segments[1], key: 'tools', tokens: 6, fraction: 0.006);
    expectSegment(segments[4], key: 'attachments', tokens: 7, fraction: 0.007);
    expectSegment(segments[5], key: 'draft', tokens: 9, fraction: 0.009);
    expectSegment(segments[6], key: 'freeSpace', tokens: 890, fraction: 0.89);
  });

  test('segments without a window are proportional to used total', () {
    final segments = buildContextUsageSegments(usageSnap(window: null));
    expect(segments, hasLength(6));
    expectSegment(segments[2], key: 'system', tokens: 10, fraction: 10 / 110);
    expectSegment(segments[3], key: 'injections', tokens: 8, fraction: 8 / 110);
    expectSegment(segments[0], key: 'history', tokens: 70, fraction: 70 / 110);
    expectSegment(segments[1], key: 'tools', tokens: 6, fraction: 6 / 110);
    expectSegment(
      segments[4],
      key: 'attachments',
      tokens: 7,
      fraction: 7 / 110,
    );
    expectSegment(segments[5], key: 'draft', tokens: 9, fraction: 9 / 110);
    expect(segments.any((segment) => segment.isFreeSpace), isFalse);
  });

  test('calibrated exact snapshot uses bucket segments', () {
    final segments = buildContextUsageSegments(
      usageSnap(state: ContextUsageState.exact, calibrated: true),
    );
    expect(segments, hasLength(7));
    expectSegment(segments[2], key: 'system', tokens: 10, fraction: 0.01);
    expectSegment(segments[3], key: 'injections', tokens: 8, fraction: 0.008);
    expectSegment(segments[0], key: 'history', tokens: 70, fraction: 0.07);
    expectSegment(segments[1], key: 'tools', tokens: 6, fraction: 0.006);
    expectSegment(segments[4], key: 'attachments', tokens: 7, fraction: 0.007);
    expectSegment(segments[5], key: 'draft', tokens: 9, fraction: 0.009);
    expectSegment(segments[6], key: 'freeSpace', tokens: 890, fraction: 0.89);
  });

  test('exact snapshot is a single used segment plus free space', () {
    final segments = buildContextUsageSegments(
      usageSnap(
        state: ContextUsageState.exact,
        used: 250,
        window: 1000,
        buckets: const ContextUsageBuckets(),
      ),
    );
    expect(segments, hasLength(2));
    expectSegment(segments[0], key: 'used', tokens: 250, fraction: 0.25);
    expectSegment(segments[1], key: 'freeSpace', tokens: 750, fraction: 0.75);
  });

  test('exact snapshot without a window is only the used segment', () {
    final segments = buildContextUsageSegments(
      usageSnap(
        state: ContextUsageState.exact,
        used: 250,
        window: null,
        buckets: const ContextUsageBuckets(),
      ),
    );
    expect(segments, hasLength(1));
    expectSegment(segments[0], key: 'used', tokens: 250, fraction: 1);
  });

  test('zero buckets are omitted from estimated segments', () {
    final segments = buildContextUsageSegments(
      usageSnap(
        used: 45,
        buckets: const ContextUsageBuckets(history: 40, draft: 5),
      ),
    );
    expect(segments.map((segment) => segment.key).toList(), [
      'history',
      'draft',
      'freeSpace',
    ]);
  });

  testWidgets('summary without a window is just the used count', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ContextUsageSummaryHeader(snapshot: usageSnap(window: null)),
        ),
      ),
    );

    expect(find.text('110'), findsOneWidget);
    expect(find.textContaining('/'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('Estimated'), findsOneWidget);
  });

  testWidgets('legend hides percents when there is no window', (tester) async {
    final snapshot = usageSnap(
      window: null,
      used: 40,
      buckets: const ContextUsageBuckets(history: 40),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ContextUsageLegend(snapshot: snapshot)),
      ),
    );

    expect(
      find.byKey(const ValueKey('context-usage-bucket-history')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-usage-bucket-freeSpace')),
      findsNothing,
    );
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('legend shows window percents and free space', (tester) async {
    final snapshot = usageSnap(
      used: 45,
      buckets: const ContextUsageBuckets(history: 40, draft: 5),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ContextUsageLegend(snapshot: snapshot)),
      ),
    );

    expect(find.text('4.0%'), findsOneWidget);
    expect(find.text('0.5%'), findsOneWidget);
    expect(find.text('95.5%'), findsOneWidget);
    expect(find.text('Free space'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('context-usage-bucket-freeSpace')),
      findsOneWidget,
    );
  });

  testWidgets('exact breakdown uses used row without a note', (tester) async {
    final snapshot = usageSnap(
      state: ContextUsageState.exact,
      used: 250,
      buckets: const ContextUsageBuckets(),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ContextUsageBreakdown(snapshot: snapshot)),
      ),
    );

    expect(find.text('Used'), findsOneWidget);
    expect(find.text('250'), findsOneWidget);
    expect(find.text('25.0%'), findsOneWidget);
    expect(find.text('Exact (from last response)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('context-usage-bucket-used')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-usage-bucket-history')),
      findsNothing,
    );
    expect(
      find.text(
        'Totals come from the last response; a bucket breakdown is not available.',
      ),
      findsNothing,
    );
  });

  testWidgets('calibrated exact breakdown shows buckets and no note', (
    tester,
  ) async {
    final snapshot = usageSnap(
      state: ContextUsageState.exact,
      calibrated: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ContextUsageBreakdown(snapshot: snapshot)),
      ),
    );

    expect(find.text('Exact (breakdown scaled from estimate)'), findsOneWidget);
    expect(find.text('System prompt'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Used'), findsNothing);
    expect(
      find.byKey(const ValueKey('context-usage-bucket-history')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-usage-bucket-used')),
      findsNothing,
    );
    expect(
      find.text(
        'Totals come from the last response; a bucket breakdown is not available.',
      ),
      findsNothing,
    );
  });
}
