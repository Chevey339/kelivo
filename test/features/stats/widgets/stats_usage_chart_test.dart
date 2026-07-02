import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/features/stats/models/stats_models.dart';
import 'package:Cuplivo/features/stats/widgets/stats_usage_chart.dart';
import 'package:Cuplivo/l10n/app_localizations.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('uses a custom painter for provider bars', (tester) async {
    await tester.pumpWidget(
      _harness(
        StatsUsageChart(
          days: [
            for (var i = 0; i < 3; i++)
              StatsTrendDay(
                date: DateTime(2026, 5, i + 1),
                providerTokens: const {
                  'OpenAI': StatsTokenBucket(activityCount: 1),
                },
              ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('stats-usage-chart-bars')),
      findsOneWidget,
    );
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('OpenAI'), findsOneWidget);
  });

  testWidgets('shows compact provider totals after tapping a bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        Center(
          child: SizedBox(
            width: 320,
            child: StatsUsageChart(
              days: [
                StatsTrendDay(
                  date: DateTime(2026, 5, 3),
                  providerTokens: const {
                    'OpenAI': StatsTokenBucket(
                      inputTokens: 10,
                      outputTokens: 20,
                      cachedTokens: 3,
                    ),
                    'Gemini': StatsTokenBucket(activityCount: 2),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bars = find.byKey(const ValueKey('stats-usage-chart-bars'));
    final barsRect = tester.getRect(bars);
    await tester.tapAt(barsRect.bottomLeft + const Offset(6, -36));
    await tester.pumpAndSettle();

    expect(find.text('2026-05-03'), findsOneWidget);
    expect(find.text('OpenAI'), findsNWidgets(2));
    expect(find.text('30 tokens'), findsOneWidget);
    expect(find.text('Input Tokens 10'), findsNothing);
    expect(find.text('Output Tokens 20'), findsNothing);
    expect(find.text('Cached Tokens 3'), findsNothing);
    expect(find.text('0 tokens'), findsNothing);
    expect(find.text('Gemini'), findsOneWidget);
  });

  testWidgets('does not show details for days without token totals', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        Center(
          child: SizedBox(
            width: 320,
            child: StatsUsageChart(
              days: [
                StatsTrendDay(
                  date: DateTime(2026, 5, 3),
                  providerTokens: const {
                    'OpenAI': StatsTokenBucket(inputTokens: 10),
                  },
                ),
                StatsTrendDay(
                  date: DateTime(2026, 5, 4),
                  providerTokens: const {
                    'OpenAI': StatsTokenBucket(activityCount: 1),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bars = find.byKey(const ValueKey('stats-usage-chart-bars'));
    final barsRect = tester.getRect(bars);
    await tester.tapAt(barsRect.bottomLeft + const Offset(23, -36));
    await tester.pumpAndSettle();

    expect(find.text('2026-05-04'), findsNothing);
  });

  testWidgets('keeps long desktop trend ranges horizontally scrollable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        Center(
          child: SizedBox(
            width: 320,
            child: StatsUsageChart(
              days: [
                for (var i = 0; i < 120; i++)
                  StatsTrendDay(
                    date: DateTime(2026, 1, 1).add(Duration(days: i)),
                    providerTokens: const {
                      'OpenAI': StatsTokenBucket(inputTokens: 10),
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('stats-usage-chart-scroll')),
      findsOneWidget,
    );
    expect(find.byType(Scrollbar), findsNothing);
  });

  testWidgets('supports mouse drag scrolling for long desktop trend ranges', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        Center(
          child: SizedBox(
            width: 320,
            child: StatsUsageChart(
              days: [
                for (var i = 0; i < 120; i++)
                  StatsTrendDay(
                    date: DateTime(2026, 1, 1).add(Duration(days: i)),
                    providerTokens: const {
                      'OpenAI': StatsTokenBucket(inputTokens: 10),
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('stats-usage-chart-scroll')),
      matching: find.byType(Scrollable),
    );
    final scrollableState = tester.state<ScrollableState>(scrollable);
    final initialPixels = scrollableState.position.pixels;
    final center = tester.getCenter(scrollable);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(center);
    await gesture.moveBy(const Offset(160, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(scrollableState.position.pixels, isNot(initialPixels));
  });

  testWidgets('supports mouse wheel scrolling for long desktop trend ranges', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        Center(
          child: SizedBox(
            width: 320,
            child: StatsUsageChart(
              days: [
                for (var i = 0; i < 120; i++)
                  StatsTrendDay(
                    date: DateTime(2026, 1, 1).add(Duration(days: i)),
                    providerTokens: const {
                      'OpenAI': StatsTokenBucket(inputTokens: 10),
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('stats-usage-chart-scroll')),
      matching: find.byType(Scrollable),
    );
    final scrollableState = tester.state<ScrollableState>(scrollable);
    final initialPixels = scrollableState.position.pixels;
    final center = tester.getCenter(scrollable);

    await tester.sendEventToBinding(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, 160)),
    );
    await tester.pumpAndSettle();

    expect(scrollableState.position.pixels, isNot(initialPixels));
  });
}
