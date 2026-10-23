import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/mcp_presentation.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/desktop/setting/mcp_pane.dart';
import 'package:Kelivo/features/mcp/pages/mcp_page.dart';
import 'package:Kelivo/utils/brand_assets.dart';

import '../support/mcp_golden_fonts.dart';
import '../support/mcp_presentation_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMcpGoldenFonts);
  for (final brightness in Brightness.values) {
    for (final mode in ['mobile', 'selection', 'desktop']) {
      testWidgets('grouped MCP ${brightness.name} $mode', (tester) async {
        final desktop = mode == 'desktop';
        tester.view.physicalSize = desktop
            ? const Size(1040, 800)
            : const Size(430, 920);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final harness = (await tester.runAsync(() async {
          final fixture = await McpPresentationHarness.create(count: 6);
          fixture.mcp.items = [
            for (var i = 0; i < 6; i++)
              presentationServer(
                'server-$i',
                [
                  'Exa Search',
                  'Brave Search',
                  'GitHub',
                  'Filesystem',
                  'Notion',
                  'Fetch',
                ][i],
                enabled: i != 5,
                transport: i == 1
                    ? McpTransportType.sse
                    : i == 3
                    ? McpTransportType.stdio
                    : i == 5
                    ? McpTransportType.inmemory
                    : McpTransportType.http,
              ),
          ];
          final search = await fixture.mcp.createGroup('Search');
          final dev = await fixture.mcp.createGroup('Development');
          final notes = await fixture.mcp.createGroup('Notes');
          await fixture.mcp.moveServersToGroup({
            'server-0',
            'server-1',
          }, search);
          await fixture.mcp.moveServersToGroup({'server-2', 'server-3'}, dev);
          await fixture.mcp.moveServersToGroup({'server-4'}, notes);
          await fixture.mcp.setServerIcon(
            'server-0',
            McpServerIcon(
              type: McpIconType.asset,
              value: BrandAssets.selectableIcons.first.asset,
            ),
          );
          await fixture.mcp.setServerIcon(
            'server-1',
            McpServerIcon(
              type: McpIconType.asset,
              value: BrandAssets.selectableIcons[1].asset,
            ),
          );
          fixture.mcp.statuses['server-3'] = McpStatus.connecting;
          fixture.mcp.statuses['server-4'] = McpStatus.error;
          fixture.mcp.errors['server-4'] = '401 Unauthorized';
          return fixture;
        }))!;
        await tester.pumpWidget(
          harness.app(
            desktop ? const Scaffold(body: DesktopMcpPane()) : const McpPage(),
            brightness: brightness,
            fontFamily: 'mcp-golden',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        if (mode == 'selection') {
          await tester.tap(find.byKey(const ValueKey('mcp-selection-start')));
          await tester.pump();
          await tester.tap(find.text('Exa Search'));
          await tester.tap(find.text('Brave Search'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          expect(
            tester
                .widget<TextButton>(
                  find.byKey(const ValueKey('mcp-selection-enable')),
                )
                .onPressed,
            isNotNull,
          );
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'baselines/mcp_management_${brightness.name}_$mode.png',
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
