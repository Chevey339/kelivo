import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:Kelivo/features/mcp/pages/mcp_page.dart';
import 'package:Kelivo/features/chat/widgets/chat_tools_sheet.dart';

import '../test/support/mcp_presentation_harness.dart';

// Run with flutter drive --profile --driver=test_driver/integration_test.dart
// --target=integration_test/mcp_presentation_performance_test.dart on the same
// device before and after a change.
// Fixtures use an isolated in-memory database and never connect to MCP servers.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

  testWidgets('50 servers: scroll MCP and open the tools panel', (
    tester,
  ) async {
    await binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => binding.setSurfaceSize(null));
    final harness = await McpPresentationHarness.create(count: 50);
    await tester.pumpWidget(
      harness.app(const McpPage(), logicalSize: const Size(800, 600)),
    );
    await tester.pumpAndSettle();
    // Live tests otherwise retain the host window's MediaQuery size even when
    // the render surface is constrained, which can select a different layout.
    expect(
      MediaQuery.sizeOf(tester.element(find.byType(McpPage))),
      const Size(800, 600),
    );

    Future<void> measure(String name, Future<void> Function() action) async {
      final frames = <FrameTiming>[];
      void collect(List<FrameTiming> values) => frames.addAll(values);
      SchedulerBinding.instance.addTimingsCallback(collect);
      await action();
      await tester.pump(const Duration(seconds: 1));
      SchedulerBinding.instance.removeTimingsCallback(collect);
      expect(frames, isNotEmpty);
      double mean(Iterable<int> values) =>
          values.reduce((a, b) => a + b) / values.length;
      final spans = frames.map((f) => f.totalSpan.inMicroseconds).toList()
        ..sort();
      final result = {
        'frames': frames.length,
        'buildUs': mean(frames.map((f) => f.buildDuration.inMicroseconds)),
        'rasterUs': mean(frames.map((f) => f.rasterDuration.inMicroseconds)),
        'totalUs': mean(spans),
        'p90TotalUs': spans[((spans.length - 1) * .9).round()],
      };
      // ignore: avoid_print
      print('MCP_PROFILE $name ${jsonEncode(result)}');
      (binding.reportData ??= {})[name] = result;
    }

    // Warm the scrolling path before measuring it.
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, -700),
      1200,
    );
    await tester.pumpAndSettle();
    for (var run = 0; run < 3; run++) {
      await measure('scroll-$run', () async {
        for (var i = 0; i < 6; i++) {
          await tester.fling(
            find.byType(Scrollable).first,
            Offset(0, i.isEven ? -700 : 700),
            1200,
          );
          await tester.pumpAndSettle();
        }
      });
    }

    await tester.pumpWidget(
      harness.app(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showChatToolsSheet(context, assistantId: harness.assistantId),
              child: const Text('Open tools'),
            ),
          ),
        ),
        logicalSize: const Size(800, 600),
      ),
    );
    await tester.pumpAndSettle();
    for (var run = 0; run < 3; run++) {
      await measure('tools-$run', () async {
        for (var i = 0; i < 5; i++) {
          await tester.tap(find.text('Open tools'));
          await tester.pumpAndSettle();
          expect(find.byType(ChatToolsSheet), findsOneWidget);
          Navigator.of(tester.element(find.byType(ChatToolsSheet))).pop();
          await tester.pumpAndSettle();
        }
      });
    }
  });
}
