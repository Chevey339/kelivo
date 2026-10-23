import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/desktop/desktop_settings_navigation_bus.dart';
import 'package:Kelivo/desktop/tools_popover.dart';
import 'package:Kelivo/features/chat/widgets/chat_tools_sheet.dart';
import 'package:Kelivo/features/mcp/pages/mcp_page.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_server_avatar.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

import '../../../support/mcp_presentation_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '50 servers are built lazily and the last row remains reachable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = await McpPresentationHarness.create(count: 50);
      await tester.pumpWidget(
        harness.app(
          Scaffold(body: ChatToolsSheet(assistantId: harness.assistantId)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(McpServerAvatar).evaluate().length, lessThan(25));
      final last = find.byKey(ChatToolsSheet.mcpServerKey('server-49'));
      expect(last, findsNothing);
      await tester.scrollUntilVisible(
        last,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(last, findsOneWidget);
      await tester.tap(
        find.descendant(of: last, matching: find.byType(IosSwitch)),
      );
      await tester.runAsync(harness.preferences.flushPendingWrites);
      expect(
        harness.assistants.getById(harness.assistantId)!.mcpServerIds,
        isNot(contains('server-49')),
      );
    },
  );

  testWidgets('tools sheet remains readable at 1.3 text scale in both themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = await McpPresentationHarness.create();
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        harness.app(
          Scaffold(body: ChatToolsSheet(assistantId: harness.assistantId)),
          brightness: brightness,
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('18/26 tools'), findsNWidgets(3));
      expect(find.text('Manage'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('manage closes the tools sheet and opens MCP settings', (
    tester,
  ) async {
    final harness = await McpPresentationHarness.create();
    await tester.pumpWidget(
      harness.app(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showChatToolsSheet(context, assistantId: harness.assistantId),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Manage')).height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(find.byType(McpPage), findsOneWidget);
    expect(find.byType(ChatToolsSheet), findsNothing);
  });

  testWidgets(
    'popover hover and keyboard focus share a fill; manage uses settings navigation',
    (tester) async {
      tester.view.physicalSize = const Size(640, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = await McpPresentationHarness.create(count: 50);
      final anchor = GlobalKey();
      final targets = <DesktopSettingsNavigationTarget>[];
      final subscription = DesktopSettingsNavigationBus.instance.stream.listen(
        targets.add,
      );
      addTearDown(subscription.cancel);
      await tester.pumpWidget(
        harness.app(
          Scaffold(
            body: Builder(
              builder: (context) => Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  key: anchor,
                  width: 400,
                  height: 44,
                  child: TextButton(
                    onPressed: () => showDesktopToolsPopover(
                      context,
                      anchorKey: anchor,
                      assistantId: harness.assistantId,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(McpServerAvatar).evaluate().length, lessThan(25));
      final row = find.byKey(const ValueKey('desktop-tools-mcp-server-0'));
      final background = find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is AnimatedContainer &&
              widget.decoration is BoxDecoration &&
              widget.constraints?.minHeight == 38 &&
              (widget.decoration as BoxDecoration).borderRadius ==
                  BorderRadius.circular(10),
        ),
      );
      Color? fill() =>
          (tester.widget<AnimatedContainer>(background).decoration
                  as BoxDecoration)
              .color;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(row));
      await tester.pumpAndSettle();
      expect(fill(), tester.element(row).appColors.surfaceFill);
      await mouse.moveTo(const Offset(0, 0));
      await mouse.removePointer();
      final oldStrategy = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = oldStrategy);
      Focus.of(
        tester.element(find.descendant(of: row, matching: find.text('GitHub'))),
      ).requestFocus();
      await tester.pumpAndSettle();
      expect(fill(), tester.element(row).appColors.surfaceFill);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.runAsync(harness.preferences.flushPendingWrites);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IosSwitch>(
              find.descendant(of: row, matching: find.byType(IosSwitch)),
            )
            .value,
        isFalse,
      );
      await tester.tap(find.text('Manage'));
      await tester.pumpAndSettle();
      expect(targets, [DesktopSettingsNavigationTarget.mcp]);
      expect(find.text('Manage'), findsNothing);
    },
  );
}
