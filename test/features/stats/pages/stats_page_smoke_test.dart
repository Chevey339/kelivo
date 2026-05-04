import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/stats/models/stats_models.dart';
import 'package:Kelivo/features/stats/pages/stats_page.dart';
import 'package:Kelivo/features/stats/widgets/stats_heatmap.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

Widget _harness(StatsSnapshot snapshot) {
  return ChangeNotifierProvider(
    create: (_) => SettingsProvider(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StatsPage(snapshotOverride: snapshot),
    ),
  );
}

StatsSnapshot _snapshot({
  StatsDateRange? range,
  List<StatsRankItem> modelRank = const [],
  List<StatsRankItem> assistantRank = const [],
  List<StatsRankItem> topicRank = const [],
}) {
  final now = DateTime(2026, 5, 3);
  return StatsSnapshot(
    range: range ?? StatsDateRange.allTime(now),
    summary: const StatsSummary(
      totalConversations: 3,
      totalMessages: 12,
      inputTokens: 1200,
      outputTokens: 2400,
      cachedTokens: 300,
      launchCount: 8,
    ),
    heatmap: [
      for (var i = 6; i >= 0; i--)
        StatsHeatmapDay(
          date: now.subtract(Duration(days: i)),
          count: i == 0 ? 4 : i,
        ),
    ],
    trend: [
      StatsTrendDay(
        date: now,
        providerTokens: const {
          'OpenAI': StatsTokenBucket(inputTokens: 10, outputTokens: 20),
          'Gemini': StatsTokenBucket(inputTokens: 6, outputTokens: 8),
        },
      ),
    ],
    modelRank: modelRank,
    assistantRank: assistantRank,
    topicRank: topicRank,
  );
}

void main() {
  testWidgets('heatmap shows month labels above columns', (tester) async {
    final days = [
      for (var i = 0; i < 14; i++)
        StatsHeatmapDay(date: DateTime(2026, 4, 25 + i), count: i),
    ];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: StatsHeatmap(days: days)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('stats-heatmap-month-2026-5')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stats-heatmap-weekday-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stats-heatmap-weekday-3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stats-heatmap-weekday-5')),
      findsOneWidget,
    );
  });

  testWidgets('heatmap completes leading week as calendar dates', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatsHeatmap(
            days: [StatsHeatmapDay(date: DateTime(2026, 1, 3), count: 2)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('stats-heatmap-day-2025-12-28')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stats-heatmap-day-2026-1-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stats-heatmap-month-2026-1')),
      findsOneWidget,
    );
  });

  testWidgets('heatmap does not complete trailing week after latest date', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatsHeatmap(
            days: [StatsHeatmapDay(date: DateTime(2026, 1, 7), count: 2)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('stats-heatmap-day-2026-1-7')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stats-heatmap-day-2026-1-8')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('stats-heatmap-day-2026-1-10')),
      findsNothing,
    );
  });

  testWidgets('heatmap initially shows latest date on narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(220, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final latest = DateTime(2026, 5, 3);
    final earliest = latest.subtract(const Duration(days: 179));
    final days = [
      for (var i = 179; i >= 0; i--)
        StatsHeatmapDay(date: latest.subtract(Duration(days: i)), count: 1),
    ];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: StatsHeatmap(days: days)),
      ),
    );
    await tester.pumpAndSettle();

    final latestCell = tester.getRect(
      find.byKey(const ValueKey('stats-heatmap-day-2026-5-3')),
    );
    final earliestCell = tester.getRect(
      find.byKey(
        ValueKey(
          'stats-heatmap-day-${earliest.year}-${earliest.month}-${earliest.day}',
        ),
      ),
    );

    expect(latestCell.right, lessThanOrEqualTo(220));
    expect(latestCell.left, greaterThan(160));
    expect(earliestCell.right, lessThan(0));
  });

  testWidgets('heatmap legend follows graph width on wide viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatsHeatmap(
            days: [StatsHeatmapDay(date: DateTime(2026, 5, 3), count: 1)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final latestCell = tester.getRect(
      find.byKey(const ValueKey('stats-heatmap-day-2026-5-3')),
    );
    final legend = tester.getRect(
      find.byKey(const ValueKey('stats-heatmap-legend')),
    );

    expect(latestCell.left, lessThan(40));
    expect(legend.left, greaterThan(18));
    expect(legend.right, lessThan(190));
  });

  testWidgets('renders summary sections and empty rankings', (tester) async {
    await tester.pumpWidget(_harness(_snapshot()));
    await tester.pumpAndSettle();

    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Chat Heatmap'), findsOneWidget);
    expect(find.text('Total Conversations'), findsOneWidget);
    expect(find.text('Input Tokens'), findsOneWidget);
    expect(find.text('Usage Trend'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Model Usage'), findsOneWidget);
    expect(find.text('No statistics yet'), findsNWidgets(3));
  });

  testWidgets('rankings show top five and expand to all rows', (tester) async {
    final ranks = [
      for (var i = 1; i <= 6; i++)
        StatsRankItem(id: 'model-$i', label: 'model-$i', value: 10 - i),
    ];

    await tester.pumpWidget(_harness(_snapshot(modelRank: ranks)));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('model-1'), findsOneWidget);
    expect(find.text('model-5'), findsOneWidget);
    expect(find.text('model-6'), findsNothing);

    await tester.tap(find.byTooltip('Show all').first);
    await tester.pumpAndSettle();

    expect(find.text('model-6'), findsOneWidget);
  });

  testWidgets('ranking expand opens a mobile page for long names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ranks = [
      for (var i = 1; i <= 6; i++)
        StatsRankItem(
          id: 'model-$i',
          label: 'very-long-model-name-that-needs-mobile-dialog-width-$i',
          value: 10 - i,
        ),
    ];

    await tester.pumpWidget(_harness(_snapshot(modelRank: ranks)));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Show all').first);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(AppBar, 'Model Usage'), findsOneWidget);
    expect(
      find.text('very-long-model-name-that-needs-mobile-dialog-width-6'),
      findsOneWidget,
    );
  });

  testWidgets('ranking sections can render per-item leading widgets', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _snapshot(
          modelRank: const [
            StatsRankItem(id: 'model-a', label: 'model-a', value: 2),
          ],
          assistantRank: const [
            StatsRankItem(id: 'assistant-a', label: 'Assistant A', value: 1),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('stats-model-icon-model-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stats-assistant-avatar-assistant-a')),
      findsOneWidget,
    );
  });

  testWidgets('ranking labels are painted outside the value capsule', (
    tester,
  ) async {
    const longLabel = 'very-long-model-name-that-is-longer-than-the-capsule';

    await tester.pumpWidget(
      _harness(
        _snapshot(
          modelRank: const [
            StatsRankItem(id: 'model-a', label: longLabel, value: 1),
            StatsRankItem(id: 'model-b', label: 'model-b', value: 10),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    final label = tester.widget<Text>(find.text(longLabel));
    expect(label.overflow, isNot(TextOverflow.ellipsis));
  });

  testWidgets(
    'custom range uses the stats calendar instead of material picker',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          _snapshot(
            range: StatsDateRange.custom(
              DateTime(2026, 5, 2),
              DateTime(2026, 5, 3),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
      expect(
        find.byKey(const ValueKey('stats-custom-date-calendar')),
        findsOneWidget,
      );
      expect(find.text('2026-05'), findsOneWidget);

      await tester.tap(find.text('2').first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('stats-custom-date-calendar')),
        findsNothing,
      );
      expect(find.text('2026-05-02'), findsOneWidget);
    },
  );

  testWidgets('custom range calendar arrows switch months in day mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _snapshot(
          range: StatsDateRange.custom(
            DateTime(2026, 5, 2),
            DateTime(2026, 5, 3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.text('2026-05'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stats-date-picker-prev-year')));
    await tester.pumpAndSettle();

    expect(find.text('2026-04'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('stats-custom-month-picker')),
      findsNothing,
    );
  });

  testWidgets('custom range calendar title opens month selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _snapshot(
          range: StatsDateRange.custom(
            DateTime(2026, 5, 2),
            DateTime(2026, 5, 3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stats-date-picker-title')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('stats-custom-month-picker')),
      findsOneWidget,
    );
    expect(find.text('2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stats-date-picker-prev-year')));
    await tester.pumpAndSettle();

    expect(find.text('2025'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stats-month-cell-4')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('stats-custom-month-picker')),
      findsNothing,
    );
    expect(find.text('2025-04'), findsOneWidget);

    await tester.tap(find.text('2').first);
    await tester.pumpAndSettle();

    expect(find.text('2025-04-02'), findsOneWidget);
  });
}
