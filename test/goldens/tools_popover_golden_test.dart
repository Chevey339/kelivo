import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/desktop/tools_popover.dart';

import '../support/mcp_golden_fonts.dart';
import '../support/mcp_presentation_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMcpGoldenFonts);
  for (final brightness in Brightness.values) {
    testWidgets('tools popover ${brightness.name} with hover', (tester) async {
      tester.view.physicalSize = const Size(440, 620);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = await McpPresentationHarness.create();
      final anchor = GlobalKey();
      await tester.pumpWidget(
        harness.app(
          Scaffold(
            body: Builder(
              builder: (context) => Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 390,
                  height: 44,
                  key: anchor,
                  child: TextButton(
                    onPressed: () => showDesktopToolsPopover(
                      context,
                      anchorKey: anchor,
                      assistantId: harness.assistantId,
                    ),
                    child: const Text('Open tools'),
                  ),
                ),
              ),
            ),
          ),
          brightness: brightness,
          fontFamily: 'mcp-golden',
        ),
      );
      await tester.tap(find.text('Open tools'));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(find.text('GitHub')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('baselines/tools_popover_${brightness.name}.png'),
      );
      await mouse.removePointer();
    });
  }
}
