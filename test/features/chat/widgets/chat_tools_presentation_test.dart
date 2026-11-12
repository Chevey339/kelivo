import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';

import 'package:Kelivo/desktop/tools_popover.dart';
import 'package:Kelivo/features/chat/widgets/chat_tools_sheet.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_server_avatar.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';

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

  for (final desktop in [false, true]) {
    testWidgets(
      'tool groups follow settings order and keep server toggles desktop=$desktop',
      (tester) async {
        tester.view.physicalSize = Size(desktop ? 1280 : 390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final harness = (await tester.runAsync(
          () => McpPresentationHarness.create(count: 4),
        ))!;
        await tester.runAsync(() async {
          final development = await harness.mcp.createGroup(
            'Development group',
          );
          final search = await harness.mcp.createGroup('Search group');
          final offline = await harness.mcp.createGroup('Offline group');
          await harness.mcp.moveServersToGroup({'server-0'}, development);
          await harness.mcp.moveServersToGroup({'server-1'}, search);
          await harness.mcp.moveServersToGroup({'server-3'}, offline);
          await harness.mcp.reorderGroup(search, 0);
          // Settings collapse does not hide available tools in the chat picker.
          await harness.mcp.setGroupCollapsed(development, true);
        });
        harness.mcp.statuses['server-3'] = McpStatus.error;
        final anchor = GlobalKey();
        await tester.pumpWidget(
          harness.app(
            Scaffold(
              body: desktop
                  ? Builder(
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
                              supportsModelTools: true,
                            ),
                            child: const Text('Open'),
                          ),
                        ),
                      ),
                    )
                  : ChatToolsSheet(assistantId: harness.assistantId),
            ),
          ),
        );
        if (desktop) await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        if (desktop) {
          await tester.scrollUntilVisible(
            find.text('Search group'),
            200,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
        }
        expect(find.text('Offline group'), findsNothing);
        final order = [
          'Search group',
          'Brave Search',
          'Development group',
          'GitHub',
          'Other',
          'Filesystem',
        ];
        for (var index = 1; index < order.length; index++) {
          expect(
            tester.getTopLeft(find.text(order[index])).dy,
            greaterThan(tester.getTopLeft(find.text(order[index - 1])).dy),
          );
        }
        final row = find.byKey(
          desktop
              ? const ValueKey('desktop-tools-mcp-server-0')
              : ChatToolsSheet.mcpServerKey('server-0'),
        );
        final avatar = find.descendant(
          of: row,
          matching: find.byType(McpServerAvatar),
        );
        final mark = find.descendant(
          of: avatar,
          matching: find.byType(SvgPicture),
        );
        expect(tester.getSize(mark), Size.square(desktop ? 16 : 20));
        expect(tester.widget<McpServerAvatar>(avatar).showBackground, isFalse);
        expect(find.text('18/26'), findsNWidgets(3));
        await tester.tap(row);
        await tester.pump();
        for (var turn = 0; turn < 6; turn++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        final selected = harness.assistants
            .getById(harness.assistantId)!
            .mcpServerIds;
        expect(selected, isNot(contains('server-0')));
        expect(selected, contains('server-2'));
        expect(tester.takeException(), isNull);
      },
    );
  }

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
      expect(find.text('18/26'), findsNWidgets(3));
      expect(find.text('Manage'), findsNothing);
      expect(find.textContaining(' on'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('original popover hover and keyboard focus toggle a server', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(640, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = await McpPresentationHarness.create(count: 50);
    final anchor = GlobalKey();
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
                    supportsModelTools: true,
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
    await tester.scrollUntilVisible(
      row,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(tester.getSemantics(row).flagsCollection.isToggled, Tristate.isTrue);
    final background = find.descendant(
      of: row,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedContainer &&
            widget.decoration is BoxDecoration &&
            widget.constraints?.minHeight == 40 &&
            (widget.decoration as BoxDecoration).borderRadius ==
                BorderRadius.circular(12),
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
    final hoveredFill = fill();
    expect(hoveredFill, isNot(Colors.transparent));
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
    expect(fill(), hoveredFill);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.runAsync(harness.preferences.flushPendingWrites);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(row).flagsCollection.isToggled,
      Tristate.isFalse,
    );
    expect(
      harness.assistants.getById(harness.assistantId)!.mcpServerIds,
      isNot(contains('server-0')),
    );
    expect(find.text('Manage'), findsNothing);
    semantics.dispose();
  });
}
