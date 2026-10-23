import 'package:flutter/services.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_text_dialog.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_form.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/desktop/widgets/desktop_form_dialog.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/mcp_presentation.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_error_details_sheet.dart';
import 'package:Kelivo/desktop/setting/mcp_pane.dart';
import 'package:Kelivo/features/mcp/pages/mcp_page.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_icon_picker.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_server_card.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

import '../../../support/mcp_presentation_harness.dart';

Future<void> _settleWrites(
  WidgetTester tester,
  McpPresentationHarness harness,
) async {
  await tester.pumpAndSettle();
  // Provider and preference writes each have a serialized async tail. Let
  // their continuations advance between real SQLite turns.
  for (var i = 0; i < 5; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  await tester.pumpAndSettle();
}

Future<void> _deleteFirst(
  WidgetTester tester,
  McpPresentationHarness harness,
) async {
  await tester.tap(find.byKey(const ValueKey('mcp-selection-start')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('GitHub'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('mcp-selection-delete')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(FormSheetActions),
      matching: find.text('Delete'),
    ),
  );
  await _settleWrites(tester, harness);
  expect(harness.mcp.getById('server-0'), isNull);
}

void main() {
  testWidgets(
    'icon changes remain saved while another server is reconnecting',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = (await tester.runAsync(McpPresentationHarness.create))!;
      final reconnect = Completer<void>();
      harness.mcp.reconnectWait = reconnect.future;
      await tester.pumpWidget(
        harness.app(const Scaffold(body: DesktopMcpPane())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reconnect'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Server icon'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose Emoji'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '🌿');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await _settleWrites(tester, harness);
      expect(harness.mcp.presentationFor('server-1').icon!.value, '🌿');
      reconnect.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('desktop toolbar, menu and group form work with Tab and Enter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = (await tester.runAsync(McpPresentationHarness.create))!;
    await tester.pumpWidget(
      harness.app(const Scaffold(body: DesktopMcpPane())),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('New group…'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(McpTextDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Keyboard group');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settleWrites(tester, harness);
    expect(harness.mcp.groups.single.name, 'Keyboard group');
    expect(find.byType(McpTextDialog), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  TestWidgetsFlutterBinding.ensureInitialized();

  for (final desktop in [false, true]) {
    testWidgets(
      'group drag proxy remains valid desktop=$desktop',
      (tester) async {
        tester.view.physicalSize = Size(desktop ? 1280 : 430, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final harness = (await tester.runAsync(McpPresentationHarness.create))!;
        final first = (await tester.runAsync(
          () => harness.mcp.createGroup('First'),
        ))!;
        final second = (await tester.runAsync(
          () => harness.mcp.createGroup('Second'),
        ))!;
        await tester.runAsync(
          () => harness.mcp.moveServersToGroup({'server-0'}, first),
        );
        await tester.runAsync(
          () =>
              harness.mcp.moveServersToGroup({'server-1', 'server-2'}, second),
        );
        await tester.pumpWidget(
          harness.app(
            desktop ? const Scaffold(body: DesktopMcpPane()) : const McpPage(),
          ),
        );
        await tester.pumpAndSettle();
        final target =
            tester.getBottomLeft(
              find.byKey(
                ValueKey('${desktop ? 'desktop-mcp' : 'mcp'}-server-2'),
              ),
            ) +
            const Offset(90, 30);
        final header = find.byKey(ValueKey('mcp-group-$first'));
        final dragHandle = desktop
            ? find.descendant(
                of: header,
                matching: find.byType(ReorderableDragStartListener),
              )
            : find.text('First');
        final gesture = await tester.startGesture(tester.getCenter(dragHandle));
        if (!desktop) await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveBy(const Offset(0, 14));
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          tester.takeException(),
          isNull,
          reason:
              'The group is now in the overlay, outside its original Material ancestor',
        );
        await gesture.moveTo(target);
        await tester.pump(const Duration(milliseconds: 350));
        await gesture.up();
        await _settleWrites(tester, harness);
        expect(harness.mcp.groups.map((g) => g.id), [second, first]);
        expect(harness.mcp.presentationFor('server-0').groupId, first);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(
        desktop ? TargetPlatform.macOS : TargetPlatform.android,
      ),
    );
  }

  testWidgets('Android long press on the server name drags the entire card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = (await tester.runAsync(McpPresentationHarness.create))!;
    await tester.pumpWidget(harness.app(const McpPage()));
    await tester.pumpAndSettle();
    final target =
        tester.getBottomLeft(find.byKey(const ValueKey('mcp-server-2'))) +
        const Offset(120, 30);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('GitHub')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 14));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
    await gesture.moveTo(target);
    await tester.pump(const Duration(milliseconds: 350));
    await gesture.up();
    await _settleWrites(tester, harness);
    expect(harness.mcp.items.map((s) => s.id), [
      'server-1',
      'server-2',
      'server-0',
    ]);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Undo restores after leaving the MCP page', (tester) async {
    final harness = (await tester.runAsync(McpPresentationHarness.create))!;
    await tester.runAsync(
      () => harness.mcp.setServerIcon(
        'server-0',
        const McpServerIcon(type: McpIconType.emoji, value: '🌱'),
      ),
    );
    await tester.pumpWidget(
      harness.app(
        AppSnackBarOverlay(
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const McpPage()),
                ),
                child: const Text('Open MCP'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open MCP'));
    await tester.pumpAndSettle();
    await _deleteFirst(tester, harness);
    Navigator.of(tester.element(find.byType(McpPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(McpPage), findsNothing);
    await tester.tap(find.text('Undo').hitTestable());
    await _settleWrites(tester, harness);
    expect(harness.mcp.getById('server-0'), isNotNull);
    expect(harness.mcp.restoredPresentations['server-0']!.icon!.value, '🌱');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('Undo remains actionable during another server reconnect', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = (await tester.runAsync(McpPresentationHarness.create))!;
    final reconnect = Completer<void>();
    harness.mcp.reconnectWait = reconnect.future;
    await tester.pumpWidget(
      harness.app(
        const AppSnackBarOverlay(child: Scaffold(body: DesktopMcpPane())),
      ),
    );
    await tester.pumpAndSettle();
    await _deleteFirst(tester, harness);
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reconnect'));
    await tester.pump();
    expect(
      tester
          .widget<IosIconButton>(
            find.byKey(const ValueKey('mcp-selection-start')),
          )
          .enabled,
      isFalse,
    );
    await tester.tap(find.text('Undo').hitTestable());
    await _settleWrites(tester, harness);
    expect(harness.mcp.getById('server-0'), isNotNull);
    reconnect.complete();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('desktop error details use a scrollable dialog', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = (await tester.runAsync(McpPresentationHarness.create))!;
    harness.mcp.statuses['server-0'] = McpStatus.error;
    harness.mcp.errors['server-0'] =
        'Connection failed\n${'diagnostic detail\n' * 300}';
    await tester.pumpWidget(
      harness.app(const Scaffold(body: DesktopMcpPane())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.byType(McpErrorDetailsDialog), findsOneWidget);
    expect(find.byType(DesktopFormDialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Close').hitTestable(), findsOneWidget);
    expect(find.text('Reconnect').hitTestable(), findsOneWidget);
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(McpErrorDetailsDialog),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(McpErrorDetailsDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final desktop in [false, true]) {
    testWidgets(
      'group creation, multi-select, batch toggle and move desktop=$desktop',
      (tester) async {
        tester.view.physicalSize = Size(desktop ? 1280 : 390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final harness = (await tester.runAsync(McpPresentationHarness.create))!;
        await tester.runAsync(
          () => harness.mcp.setServerIcon(
            'server-0',
            const McpServerIcon(type: McpIconType.emoji, value: '🌱'),
          ),
        );
        await tester.pumpWidget(
          harness.app(
            desktop ? const Scaffold(body: DesktopMcpPane()) : const McpPage(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Manage groups'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New group…'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Development');
        await tester.pump();
        await tester.tap(find.text('Create'));
        await _settleWrites(tester, harness);
        expect(harness.mcp.groups.single.name, 'Development');
        await tester.tap(find.byKey(const ValueKey('mcp-selection-start')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('GitHub'));
        await tester.tap(find.text('Brave Search'));
        await tester.pumpAndSettle();
        expect(find.text('2 selected'), findsOneWidget);
        expect(find.byType(IosSwitch), findsNothing);
        expect(
          tester
              .widgetList<McpServerCard>(find.byType(McpServerCard))
              .where((card) => card.selected)
              .length,
          2,
        );
        await tester.tap(find.byKey(const ValueKey('mcp-selection-enable')));
        await _settleWrites(tester, harness);
        expect(harness.mcp.getById('server-0')!.enabled, isFalse);
        expect(harness.mcp.getById('server-1')!.enabled, isFalse);
        expect(harness.mcp.getById('server-2')!.enabled, isTrue);
        await tester.tap(find.byKey(const ValueKey('mcp-selection-move')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(McpForm),
            matching: find.text('Development'),
          ),
        );
        await _settleWrites(tester, harness);
        expect(
          harness.mcp.presentationFor('server-0').groupId,
          harness.mcp.groups.single.id,
        );
        expect(
          harness.mcp.presentationFor('server-1').groupId,
          harness.mcp.groups.single.id,
        );
        expect(harness.mcp.presentationFor('server-0').icon!.value, '🌱');
        expect(
          find.byKey(const ValueKey('mcp-selection-start')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'group collapse preserves selection and group delete preserves servers',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = (await tester.runAsync(McpPresentationHarness.create))!;
      final group = (await tester.runAsync(
        () => harness.mcp.createGroup('Search'),
      ))!;
      await tester.runAsync(
        () => harness.mcp.moveServersToGroup({'server-0', 'server-1'}, group),
      );
      await tester.pumpWidget(harness.app(const McpPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search'));
      await _settleWrites(tester, harness);
      expect(find.text('GitHub'), findsNothing);
      await tester.tap(find.text('Search'));
      await _settleWrites(tester, harness);
      await tester.tap(find.byTooltip('More').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select servers'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.text('Search'));
      await _settleWrites(tester, harness);
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final header = find.byKey(ValueKey('mcp-group-$group'));
      await tester.tap(
        find.descendant(
          of: header,
          matching: find.byKey(ValueKey('mcp-group-menu-$group')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(FormSheetActions),
          matching: find.text('Delete'),
        ),
      );
      await _settleWrites(tester, harness);
      expect(harness.mcp.groups, isEmpty);
      expect(harness.mcp.items.length, 3);
      expect(find.text('GitHub'), findsOneWidget);
    },
  );

  testWidgets('batch delete removes only selected servers after confirmation', (
    tester,
  ) async {
    final harness = (await tester.runAsync(McpPresentationHarness.create))!;
    await tester.pumpWidget(harness.app(const McpPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mcp-selection-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GitHub'));
    await tester.tap(find.text('Brave Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mcp-selection-delete')));
    await tester.pumpAndSettle();
    expect(harness.mcp.items.length, 3);
    await tester.tap(
      find.descendant(
        of: find.byType(FormSheetActions),
        matching: find.text('Delete'),
      ),
    );
    await _settleWrites(tester, harness);
    expect(harness.mcp.items.single.id, 'server-2');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('failed deletion preserves selection and reports no success', (
    tester,
  ) async {
    final harness = (await tester.runAsync(McpPresentationHarness.create))!;
    harness.mcp.rejectRemoval = true;
    await tester.pumpWidget(harness.app(const McpPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mcp-selection-start')));
    await tester.pump();
    await tester.tap(find.text('GitHub'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('mcp-selection-delete')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(FormSheetActions),
        matching: find.text('Delete'),
      ),
    );
    await _settleWrites(tester, harness);
    expect(harness.mcp.items.length, 3);
    expect(find.text('1 selected'), findsOneWidget);
    final notifications = AppSnackBarManager().activeToasts.map(
      (entry) => entry.notification,
    );
    expect(notifications.single.message, contains('Storage unavailable'));
    expect(notifications.single.type, NotificationType.error);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'dragging between groups and above the first header updates membership',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = (await tester.runAsync(McpPresentationHarness.create))!;
      final first = (await tester.runAsync(
        () => harness.mcp.createGroup('First'),
      ))!;
      final second = (await tester.runAsync(
        () => harness.mcp.createGroup('Second'),
      ))!;
      await tester.runAsync(
        () => harness.mcp.moveServersToGroup({'server-0'}, first),
      );
      await tester.runAsync(
        () => harness.mcp.moveServersToGroup({'server-1', 'server-2'}, second),
      );
      await tester.pumpWidget(
        harness.app(const Scaffold(body: DesktopMcpPane())),
      );
      await tester.pumpAndSettle();
      Future<void> drag(String id, Offset target) async {
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(ValueKey('desktop-mcp-$id'))),
        );
        await gesture.moveBy(const Offset(0, 12));
        await tester.pump(const Duration(milliseconds: 250));
        await gesture.moveTo(target);
        await tester.pump(const Duration(milliseconds: 350));
        await gesture.up();
        await _settleWrites(tester, harness);
      }

      await drag(
        'server-0',
        tester.getBottomLeft(
              find.byKey(const ValueKey('desktop-mcp-server-1')),
            ) +
            const Offset(150, 10),
      );
      expect(harness.mcp.presentationFor('server-0').groupId, second);
      await drag(
        'server-0',
        tester.getTopLeft(find.byKey(ValueKey('mcp-group-$first'))) +
            const Offset(150, 1),
      );
      expect(harness.mcp.presentationFor('server-0').groupId, first);
      expect(
        tester.getTopLeft(find.text('GitHub')).dy,
        lessThan(tester.getTopLeft(find.text('Brave Search')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom emoji can be chosen and reset through the shared picker',
    (tester) async {
      final harness = (await tester.runAsync(McpPresentationHarness.create))!;
      await tester.pumpWidget(
        harness.app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMcpIconPicker(
                  context,
                  onSelected: (icon) =>
                      harness.mcp.setServerIcon('server-0', icon),
                ),
                child: const Text('Icon'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Icon'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose Emoji'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '🧰');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await _settleWrites(tester, harness);
      expect(harness.mcp.presentationFor('server-0').icon!.value, '🧰');
      await tester.tap(find.text('Icon'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await _settleWrites(tester, harness);
      expect(harness.mcp.presentationFor('server-0').icon, isNull);
    },
  );
}
