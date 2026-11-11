import 'dart:async';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/quote_ref.dart';
import 'package:Kelivo/core/providers/hotkey_provider.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/desktop/hotkeys/hotkey_event_bus.dart';
import 'package:Kelivo/features/chat/widgets/quote_interaction_scope.dart';
import 'package:Kelivo/features/side_panel/desktop_side_panel_controller.dart';
import 'package:Kelivo/features/side_panel/widgets/desktop_side_panel.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'side_panel_test_support.dart';

String get _modifier =>
    defaultTargetPlatform == TargetPlatform.macOS ? 'cmd' : 'ctrl';

Future<HotkeyProvider> _hotkeys(WidgetTester tester) async {
  for (final name in [
    'dev.leanflutter.plugins/hotkey_manager',
    'dev.leanflutter.plugins/hotkey_manager_event',
  ]) {
    final channel = MethodChannel(name);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
  }
  SharedPreferences.setMockInitialValues({
    'desktop_hotkeys_commands_v1': ['side_panel_address=$_modifier+l'],
  });
  final provider = HotkeyProvider();
  await tester.runAsync(provider.initialize);
  addTearDown(() async {
    for (final key in List<HotKey>.of(
      HotKeyManager.instance.registeredHotKeyList,
    )) {
      await HotKeyManager.instance.unregister(key);
    }
    provider.dispose();
  });
  return provider;
}

Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  final modifier = defaultTargetPlatform == TargetPlatform.macOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'address shortcut stays out of app-wide registration after rebinding',
    (tester) async {
      final hotkeys = await _hotkeys(tester);
      for (final key in ['l', 'o']) {
        await hotkeys.setCommand('side_panel_address', '$_modifier+$key');
        expect(hotkeys.nativeCommands['$_modifier+$key'], 'side_panel_address');
        expect(
          HotKeyManager.instance.registeredHotKeyList.where(
            (hotkey) =>
                hotkey.logicalKey ==
                (key == 'l'
                    ? LogicalKeyboardKey.keyL
                    : LogicalKeyboardKey.keyO),
          ),
          isEmpty,
        );
      }
      await hotkeys.setEnabled('side_panel_address', false);
      expect(
        hotkeys.nativeCommands.values,
        isNot(contains('side_panel_address')),
      );
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets(
    'quote and address share their shortcut only within the focused surface',
    (tester) async {
      tester.view.physicalSize = const Size(1126, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final hotkeys = await _hotkeys(tester);
      const nativeChannel = MethodChannel('app.browser_window');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        nativeChannel,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          nativeChannel,
          null,
        ),
      );
      final native = defaultTargetPlatform != TargetPlatform.linux;
      Future<void> nativeCommand(String command) async {
        final reply = Completer<void>();
        tester.binding.channelBuffers.push(
          nativeChannel.name,
          nativeChannel.codec.encodeMethodCall(MethodCall('shortcut', command)),
          (_) => reply.complete(),
        );
        await reply.future;
        await tester.pumpAndSettle();
      }

      final browser = BrowserService(
        store: SidePanelMemoryStore(),
        supported: false,
      );
      final panel = DesktopSidePanelController(browser: browser)
        ..setContext(conversationId: 'a', topicsOnRight: false);
      await panel.newWebTab(url: 'https://example.com');
      panel.close();
      final quotes = <QuoteRef>[];
      final quoteController = QuoteInteractionController(
        onQuote: (quote) async => quotes.add(quote),
        onJump: (_) async => true,
        sourceExists: (_) async => true,
      );
      final actions = <HotkeyAction>[];
      final subscription = HotkeyEventBus.instance.stream.listen(actions.add);
      addTearDown(subscription.cancel);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await browser.flush();
        quoteController.dispose();
        panel.dispose();
        browser.dispose();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: hotkeys,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: QuoteInteractionScope(
              controller: quoteController,
              child: DesktopSidePanel(
                controller: panel,
                conversationId: 'a',
                topicsOnRight: false,
                topicsBuilder: (_, _) => const Text('Topics'),
                filesBuilder: (_) => const Text('Files'),
                child: Material(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(60),
                      child: AppSelectionArea(
                        message: ChatMessage(
                          id: 'message',
                          role: 'assistant',
                          conversationId: 'a',
                          content: 'selected words',
                        ),
                        child: const Text('selected words'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final address = find.byKey(const ValueKey('browserAddressField'));
      for (final open in [false, true]) {
        if (open) panel.open();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.tap(
          find.text('selected words'),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(
          find.text('selected words'),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        actions.clear();
        await _press(tester, LogicalKeyboardKey.keyL);
        expect(quotes, hasLength(open ? 2 : 1));
        expect(actions, isEmpty);
        expect(address, findsNothing);
        expect(panel.hasFocus, isFalse);
      }
      if (native) {
        await nativeCommand('$_modifier+l');
        expect(address, findsNothing);
        expect(actions, isEmpty);
      }

      Future<void> focusWeb() async {
        final focus = tester
            .widgetList<Focus>(find.byType(Focus))
            .singleWhere(
              (widget) => widget.focusNode?.debugLabel == 'Panel content',
            )
            .focusNode!;
        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(panel.hasFocus, isTrue);
        actions.clear();
      }

      await focusWeb();
      await _press(tester, LogicalKeyboardKey.keyL);
      expect(address, findsOneWidget);
      expect(actions, [HotkeyAction.sidePanelAddress]);
      expect(quotes, hasLength(2));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // This focus node attaches directly to the panel scope, bypassing the
      // content handler. The address command must still belong to the panel.
      Focus.of(
        tester.element(find.byKey(const ValueKey('sidePanelResizeHandle'))),
      ).requestFocus();
      await tester.pumpAndSettle();
      await _press(tester, LogicalKeyboardKey.keyL);
      expect(address, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await hotkeys.setCommand('side_panel_address', '$_modifier+shift+o');
      await focusWeb();
      await _press(tester, LogicalKeyboardKey.keyL);
      expect(address, findsNothing);
      if (native) {
        await nativeCommand('$_modifier+l');
        expect(address, findsNothing);
        await nativeCommand('$_modifier+shift+o');
        expect(address, findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await focusWeb();
      }
      await _press(tester, LogicalKeyboardKey.keyO, shift: true);
      expect(address, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await hotkeys.setEnabled('side_panel_address', false);
      await focusWeb();
      await _press(tester, LogicalKeyboardKey.keyO, shift: true);
      expect(address, findsNothing);
      expect(actions, isEmpty);
      if (native) {
        await nativeCommand('$_modifier+shift+o');
        expect(address, findsNothing);
        expect(actions, isEmpty);
      }
      await hotkeys.setEnabled('side_panel_address', true);
      final recorder = Object();
      hotkeys.beginRecording(recorder);
      await focusWeb();
      await _press(tester, LogicalKeyboardKey.keyO, shift: true);
      expect(address, findsNothing);
      expect(actions, isEmpty);
      hotkeys.endRecording(recorder);
      await _press(tester, LogicalKeyboardKey.keyO, shift: true);
      expect(address, findsOneWidget);
    },
    variant: TargetPlatformVariant.desktop(),
  );
}
