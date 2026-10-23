import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_server_card.dart';

import '../support/mcp_golden_fonts.dart';
import '../support/mcp_presentation_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMcpGoldenFonts);
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('MCP cards ${brightness.name} scale $scale', (tester) async {
        tester.view.physicalSize = const Size(430, 1120);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final harness = await McpPresentationHarness.create();
        const key = ValueKey('cards-golden');
        Widget card(
          String name,
          McpStatus status, {
          bool enabled = true,
          bool selecting = false,
          bool selected = false,
          bool desktop = false,
        }) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: McpServerCard(
            server: presentationServer(name, name, enabled: enabled),
            status: status,
            error:
                status == McpStatus.error ||
                    status == McpStatus.needsAuthorization
                ? '401 Unauthorized: sign in again'
                : null,
            onTap: () {},
            onDetails: () {},
            onEnabledChanged: desktop ? (_) {} : null,
            selectionMode: selecting,
            selected: selected,
          ),
        );
        await tester.pumpWidget(
          harness.app(
            RepaintBoundary(
              key: key,
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      card('GitHub', McpStatus.connected),
                      card('Filesystem', McpStatus.connecting),
                      card('OAuth browser', McpStatus.authorizing),
                      card('Notion', McpStatus.error),
                      card('Authorization', McpStatus.needsAuthorization),
                      card('Fetch', McpStatus.idle, enabled: false),
                      card(
                        'Selected',
                        McpStatus.connected,
                        selecting: true,
                        selected: true,
                      ),
                      card('Unselected', McpStatus.connected, selecting: true),
                      card('Desktop', McpStatus.connected, desktop: true),
                    ],
                  ),
                ),
              ),
            ),
            brightness: brightness,
            textScale: scale,
            fontFamily: 'mcp-golden',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(key),
          matchesGoldenFile(
            'baselines/mcp_cards_${brightness.name}_${scale == 1 ? 'normal' : 'large'}.png',
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
