import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/home/services/context_usage_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/context_usage_ring.dart';

ContextUsageSnapshot usageSnap({
  ContextUsageState state = ContextUsageState.estimated,
  int used = 400,
  int? window = 1000,
  ContextUsageBuckets buckets = const ContextUsageBuckets(),
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
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final cs = ColorScheme.light();

  test('contextUsageColor maps ratio thresholds', () {
    expect(contextUsageColor(cs, null), cs.outline);
    expect(
      contextUsageColor(cs, usageSnap(state: ContextUsageState.none)),
      cs.outline,
    );
    expect(
      contextUsageColor(cs, usageSnap(used: 799, window: 1000)),
      cs.primary,
    );
    expect(
      contextUsageColor(cs, usageSnap(used: 800, window: 1000)),
      cs.tertiary,
    );
    expect(
      contextUsageColor(cs, usageSnap(used: 950, window: 1000)),
      cs.tertiary,
    );
    expect(contextUsageColor(cs, usageSnap(used: 951, window: 1000)), cs.error);
  });

  test('contextUsageColor dims stale and computing', () {
    expect(
      contextUsageColor(
        cs,
        usageSnap(state: ContextUsageState.stale, used: 400, window: 1000),
      ),
      cs.primary.withValues(alpha: 0.55),
    );
    expect(
      contextUsageColor(
        cs,
        usageSnap(state: ContextUsageState.computing, used: 400, window: 1000),
      ),
      cs.primary.withValues(alpha: 0.5),
    );
    expect(contextUsageColor(cs, usageSnap(window: null)), cs.outline);
  });

  testWidgets('ring without a window has no arc or percent label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ContextUsageRing(
            snapshot: usageSnap(window: null, used: 120),
            onTap: () {},
          ),
        ),
      ),
    );

    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<ContextUsageRingPainter>()
        .single;
    expect(painter.ratio, isNull);
    expect(find.textContaining('%'), findsNothing);
  });
}
