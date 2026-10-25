import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/home/services/context_usage_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/context_usage_ring.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

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

Future<void> pumpRing(
  WidgetTester tester, {
  required ContextUsageSnapshot? snapshot,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ContextUsageRing(snapshot: snapshot, onTap: () {}),
      ),
    ),
  );
}

ContextUsageRingPainter ringPainter(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .whereType<ContextUsageRingPainter>()
      .single;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final cs = ColorScheme.light();
  final warning = AppSemanticColors.light(cs).warning;
  final normal = cs.onSurface.withValues(alpha: 0.70);

  test('contextUsageColor maps ratio thresholds', () {
    expect(contextUsageColor(cs, null, warning: warning), cs.outline);
    expect(
      contextUsageColor(
        cs,
        usageSnap(state: ContextUsageState.none),
        warning: warning,
      ),
      cs.outline,
    );
    expect(
      contextUsageColor(
        cs,
        usageSnap(used: 750, window: 1000),
        warning: warning,
      ),
      normal,
    );
    expect(
      contextUsageColor(
        cs,
        usageSnap(used: 751, window: 1000),
        warning: warning,
      ),
      warning,
    );
    expect(
      contextUsageColor(
        cs,
        usageSnap(used: 900, window: 1000),
        warning: warning,
      ),
      warning,
    );
    expect(
      contextUsageColor(
        cs,
        usageSnap(used: 901, window: 1000),
        warning: warning,
      ),
      cs.error,
    );
  });

  test('contextUsageColor dims stale and computing', () {
    expect(
      contextUsageColor(
        cs,
        usageSnap(state: ContextUsageState.stale, used: 400, window: 1000),
        warning: warning,
      ),
      normal.withValues(alpha: 0.55),
    );
    expect(
      contextUsageColor(
        cs,
        usageSnap(state: ContextUsageState.computing, used: 400, window: 1000),
        warning: warning,
      ),
      normal.withValues(alpha: 0.5),
    );
    expect(
      contextUsageColor(cs, usageSnap(window: null), warning: warning),
      cs.outline,
    );
  });

  testWidgets('ring without a window has no arc or text', (tester) async {
    await pumpRing(tester, snapshot: usageSnap(window: null, used: 120));
    await tester.pumpAndSettle();

    final painter = ringPainter(tester);
    expect(painter.ratio, isNull);
    expect(
      find.descendant(
        of: find.byType(ContextUsageRing),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  });

  testWidgets('ring is compact, unlabeled, and sized for a 32px hit target', (
    tester,
  ) async {
    await pumpRing(tester, snapshot: usageSnap());
    await tester.pumpAndSettle();

    expect(find.byType(ContextUsageRing), findsOneWidget);
    expect(tester.getSize(find.byType(ContextUsageRing)), const Size(32, 32));

    final ring = tester.widget<ContextUsageRing>(find.byType(ContextUsageRing));
    expect(ring.size, kContextUsageRingSize);
    expect(ring.strokeWidth, kContextUsageRingStroke);
    expect(ring.hitSize, 32);

    final painter = ringPainter(tester);
    expect(painter.strokeWidth, kContextUsageRingStroke);
    expect(painter.ratio, closeTo(0.4, 0.001));

    expect(
      find.descendant(
        of: find.byType(ContextUsageRing),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
    expect(find.textContaining('%'), findsNothing);
  });
}
