import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/chat/widgets/chat_tools_sheet.dart';

import '../support/mcp_golden_fonts.dart';
import '../support/mcp_presentation_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMcpGoldenFonts);
  for (final brightness in Brightness.values) {
    testWidgets('tools sheet ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(390, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = await McpPresentationHarness.create();
      const key = ValueKey('tools-golden');
      await tester.pumpWidget(
        harness.app(
          RepaintBoundary(
            key: key,
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ChatToolsSheet(assistantId: harness.assistantId),
              ),
            ),
          ),
          brightness: brightness,
          fontFamily: 'mcp-golden',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 on'), findsOneWidget);
      expect(find.text('Not linked'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('baselines/tools_sheet_${brightness.name}.png'),
      );
    });
  }
}
