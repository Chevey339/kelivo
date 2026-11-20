import 'dart:async';
import 'dart:io' show Platform;

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/quote_ref.dart';
import 'package:Kelivo/core/providers/hotkey_provider.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/desktop/hotkeys/hotkey_event_bus.dart';
import 'package:Kelivo/desktop/setting/hotkeys_pane.dart';
import 'package:Kelivo/desktop/widgets/desktop_labeled_control.dart';
import 'package:Kelivo/features/chat/widgets/conversation_find_bar.dart';
import 'package:Kelivo/features/chat/widgets/quote_interaction_scope.dart';
import 'package:Kelivo/features/side_panel/desktop_side_panel_controller.dart';
import 'package:Kelivo/features/side_panel/widgets/desktop_side_panel.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'side_panel_test_support.dart';

String get _modifier =>
    defaultTargetPlatform == TargetPlatform.macOS ? 'cmd' : 'ctrl';

class _FailFirstCommandWrite extends InMemorySharedPreferencesStore {
  _FailFirstCommandWrite() : super.empty();

  static const commandKey = 'flutter.desktop_hotkeys_commands_v1';
  bool _fail = true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == commandKey && _fail) {
      _fail = false;
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

Future<HotkeyProvider> _hotkeys(
  WidgetTester tester, {
  List<String> savedCommands = const [],
}) async {
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
    'desktop_hotkeys_commands_v1': [
      'side_panel_address=$_modifier+l',
      ...savedCommands,
    ],
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
  String? modifier,
}) async {
  final primary = (modifier ?? _modifier) == 'cmd'
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(primary);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(primary);
  await tester.pumpAndSettle();
}

void main() {
  const findId = HotkeyProvider.conversationFindId;
  final findModifier = Platform.isMacOS ? 'cmd' : 'ctrl';

  testWidgets(
    'an existing app-wide shortcut takes priority over the new find default',
    (tester) async {
      final hotkeys = await _hotkeys(
        tester,
        savedCommands: ['new_topic=$findModifier+f'],
      );
      final find = hotkeys.getById(findId);
      expect(find.command, '$findModifier+f');
      expect(hotkeys.conflictingActionLabelKey(find), 'hotkeyNewTopic');
      expect(hotkeys.shortcutFor(findId), isNull);

      final command = '$findModifier+keyK';
      expect(await hotkeys.setCommand(findId, command), isNull);
      expect(await hotkeys.resetToDefault(findId), 'hotkeyNewTopic');
      expect(find.command, command);
      await hotkeys.setEnabled('new_topic', false);
      expect(await hotkeys.resetToDefault(findId), isNull);
      expect(hotkeys.conflictingActionLabelKey(find), isNull);
      expect(hotkeys.shortcutFor(findId)?.trigger, LogicalKeyboardKey.keyF);
    },
  );

  testWidgets(
    'find rejects overlapping enabled shortcuts and allows separate focus scopes',
    (tester) async {
      final hotkeys = await _hotkeys(tester);
      final find = hotkeys.getById(findId);
      final topic = hotkeys.getById('new_topic');
      expect(
        await hotkeys.setCommand(findId, topic.command!),
        'hotkeyNewTopic',
      );
      expect(find.command, find.defaultCommand);

      final command = '$findModifier+keyK';
      expect(await hotkeys.setCommand(findId, command), isNull);
      expect(
        await hotkeys.setCommand('new_topic', '$findModifier+k'),
        'conversationFindOpenTooltip',
      );
      expect(topic.command, topic.defaultCommand);

      expect(await hotkeys.setCommand('side_panel_address', command), isNull);
      final binding = hotkeys.shortcutFor(findId)!;
      expect(binding.trigger, LogicalKeyboardKey.keyK);
      expect(hotkeys.handlesShortcut(binding), isFalse);
      expect(hotkeys.nativeCommands['$findModifier+k'], 'side_panel_address');
      expect(hotkeys.nativeCommands.values, isNot(contains(findId)));

      expect(find.command, command);
      await hotkeys.setEnabled(findId, false);
      expect(await hotkeys.setCommand(findId, topic.command!), isNull);
      expect(await hotkeys.setEnabled(findId, true), 'hotkeyNewTopic');
      expect(find.enabled, isFalse);
      expect(hotkeys.shortcutFor(findId), isNull);
    },
  );

  testWidgets(
    'find protects built-in chat editing and the side panel retains webpage find',
    (tester) async {
      final hotkeys = await _hotkeys(tester);
      final find = hotkeys.getById(findId);
      final reservedForChat = {
        '$findModifier+keyL': 'selectionQuote',
        '$findModifier+shift+keyL': 'selectionQuote',
        'ctrl+alt+keyV': 'paste',
        '$findModifier+keyC': 'copy',
        'shift+keyF': 'hotkeysTextEditing',
        'shift+tab': 'hotkeysTextEditing',
      };
      for (final entry in reservedForChat.entries) {
        expect(await hotkeys.setCommand(findId, entry.key), entry.value);
      }
      expect(find.command, find.defaultCommand);
      expect(hotkeys.shortcutFor(findId)?.trigger, LogicalKeyboardKey.keyF);
      expect(await hotkeys.setCommand(findId, '$findModifier+keyK'), isNull);

      for (final id in [
        'side_panel_address',
        'new_topic',
        'toggle_app_visibility',
      ]) {
        expect(
          await hotkeys.setCommand(id, '$findModifier+keyF'),
          'browserFind',
        );
      }
      expect(hotkeys.nativeCommands.containsKey('$findModifier+f'), isFalse);
    },
  );

  testWidgets('a stored chat binding cannot override typing', (tester) async {
    final hotkeys = await _hotkeys(
      tester,
      savedCommands: ['$findId=shift+keyF'],
    );
    expect(
      hotkeys.conflictingActionLabelKey(hotkeys.getById(findId)),
      'hotkeysTextEditing',
    );
    expect(hotkeys.shortcutFor(findId), isNull);
  });

  testWidgets('recording the same chord retries a failed preference write', (
    tester,
  ) async {
    final hotkeys = await _hotkeys(tester);
    final previousStore = SharedPreferencesStorePlatform.instance;
    final store = _FailFirstCommandWrite();
    SharedPreferencesStorePlatform.instance = store;
    addTearDown(() => SharedPreferencesStorePlatform.instance = previousStore);

    final command = '$findModifier+keyK';
    await hotkeys.setCommand(findId, command);
    expect((await store.getAll())[_FailFirstCommandWrite.commandKey], isNull);

    await hotkeys.setCommand(findId, command);
    expect(
      (await store.getAll())[_FailFirstCommandWrite.commandKey],
      contains('$findId=$command'),
    );
  });

  testWidgets(
    'settings records a find shortcut and names the conflicting action',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final hotkeys = await _hotkeys(tester);
      final item = hotkeys.getById(findId);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: hotkeys,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (_, child) => AppSnackBarOverlay(child: child!),
            home: const Scaffold(body: DesktopHotkeysPane()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DesktopHotkeysPane)),
      )!;
      final label = find.text(l10n.conversationFindOpenTooltip);
      final row = find.ancestor(
        of: label,
        matching: find.byType(DesktopLabeledControl),
      );
      final editor = find.descendant(
        of: row,
        matching: find.text(
          HotkeyProvider.formatCommandForDisplay(item.command),
        ),
      );
      await tester.ensureVisible(editor);
      await tester.pumpAndSettle();
      await tester.tap(editor);
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.keyN, modifier: findModifier);
      expect(
        find.text(l10n.hotkeysShortcutInUse(l10n.hotkeyNewTopic)),
        findsOne,
      );
      expect(editor, findsOne);
      expect(item.command, item.defaultCommand);

      await tester.tap(editor);
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.keyL, modifier: findModifier);
      expect(
        find.text(l10n.hotkeysShortcutInUse(l10n.selectionQuote)),
        findsOne,
      );
      expect(item.command, item.defaultCommand);

      await tester.tap(editor);
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.digit1, modifier: findModifier);
      expect(item.command, '$findModifier+1');
      expect(hotkeys.shortcutFor(findId)?.trigger, LogicalKeyboardKey.digit1);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('desktop_hotkeys_commands_v1'),
        contains('$findId=$findModifier+1'),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'the configured find key follows the chat focus and updates live',
    (tester) async {
      final hotkeys = await _hotkeys(tester);
      final chat = FocusNode();
      final outside = FocusNode();
      addTearDown(chat.dispose);
      addTearDown(outside.dispose);
      var opened = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: hotkeys,
          child: MaterialApp(
            home: Column(
              children: [
                ConversationFindShortcut(
                  onOpen: () => opened++,
                  child: Focus(focusNode: chat, child: const SizedBox.shrink()),
                ),
                Focus(focusNode: outside, child: const SizedBox.shrink()),
              ],
            ),
          ),
        ),
      );
      chat.requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.keyF, modifier: findModifier);
      expect(opened, 1);

      await hotkeys.setCommand(findId, '$findModifier+keyK');
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.keyF, modifier: findModifier);
      expect(opened, 1);
      await _press(tester, LogicalKeyboardKey.keyK, modifier: findModifier);
      expect(opened, 2);

      outside.requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.keyK, modifier: findModifier);
      expect(opened, 2);

      chat.requestFocus();
      await hotkeys.clearCommand(findId);
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.keyK, modifier: findModifier);
      await _press(tester, LogicalKeyboardKey.keyF, modifier: findModifier);
      expect(opened, 2);
    },
  );

  testWidgets(
    'a Ctrl+Alt find shortcut leaves printable AltGr input unhandled',
    (tester) async {
      final hotkeys = await _hotkeys(tester);
      expect(await hotkeys.setCommand(findId, 'ctrl+alt+q'), isNull);
      var opened = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: hotkeys,
          child: MaterialApp(
            home: ConversationFindShortcut(
              onOpen: () => opened++,
              child: const Focus(autofocus: true, child: SizedBox.shrink()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altRight);
      expect(
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ, character: '@'),
        isFalse,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altRight);
      expect(opened, 0);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(opened, 1);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );

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
