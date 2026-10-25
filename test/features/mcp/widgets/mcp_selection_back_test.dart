import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/mcp/pages/mcp_page.dart';

import '../../../support/mcp_presentation_harness.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('MCP selection handles back on $platform', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = (await tester.runAsync(McpPresentationHarness.create))!;
      await tester.pumpWidget(
        harness.app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const McpPage()),
                ),
                child: const Text('Parent page'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Parent page'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mcp-selection-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GitHub'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      if (platform == TargetPlatform.android) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(McpPage), findsOneWidget);
        expect(
          find.byKey(const ValueKey('mcp-selection-start')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('mcp-selection-start')));
        await tester.pumpAndSettle();
        expect(find.text('0 selected'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
      } else {
        final route = ModalRoute.of(tester.element(find.byType(McpPage)))!;
        expect(route.popGestureEnabled, isTrue);
        await tester.dragFrom(const Offset(1, 300), const Offset(350, 0));
      }
      await tester.pumpAndSettle();
      expect(find.text('Parent page'), findsOneWidget);
      expect(harness.mcp.getById('server-0'), isNotNull);
    }, variant: TargetPlatformVariant.only(platform));
  }
}
