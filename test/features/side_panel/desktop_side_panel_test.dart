import '../../core/services/browser/browser_service_test.dart'
    show FakeBrowserEngine;
import 'package:Kelivo/core/providers/hotkey_provider.dart';
import 'dart:async';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/desktop/hotkeys/hotkey_event_bus.dart';
import 'package:Kelivo/features/browser/widgets/browser_controls.dart';
import 'package:Kelivo/features/browser/pages/browser_page.dart';
import 'package:Kelivo/features/side_panel/desktop_side_panel_controller.dart';
import 'package:Kelivo/features/side_panel/widgets/side_panel_tab_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'side_panel_test_support.dart';

class _RetryPanelStore extends SidePanelMemoryStore {
  bool fail = true;
  @override
  Future<Map<String, dynamic>> read() async {
    if (fail) throw StateError('Temporary browser storage error');
    return {};
  }
}

class _RetainedEngine extends FakeBrowserEngine {
  _RetainedEngine(super.tab, super.onChanged);
  @override
  Future<Uint8List?> screenshot() async => null;
}

void main() {
  late BrowserService browser;
  late DesktopSidePanelController panel;
  setUp(() {
    browser = BrowserService(store: SidePanelMemoryStore(), supported: false);
    panel = DesktopSidePanelController(browser: browser);
  });
  tearDown(() {
    panel.dispose();
    browser.dispose();
  });
  Future<void> size(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final supported in [true, false]) {
    testWidgets(
      'find does not load an unavailable web page supported=$supported',
      (tester) async {
        await size(tester, 1126);
        var allocations = 0;
        final service = BrowserService(
          store: SidePanelMemoryStore(),
          supported: supported,
          engineFactory:
              ({
                required tab,
                required settings,
                required onChanged,
                required onDownload,
                required onNewWindow,
                required isAgentActive,
              }) async {
                allocations++;
                return _RetainedEngine(tab, onChanged);
              },
        );
        final controller = DesktopSidePanelController(browser: service)
          ..setContext(conversationId: 'a', topicsOnRight: false);
        final saved = await service.createTab(
          url: 'https://saved.example',
          ownerSessionId: 'a',
        );
        controller.openWebTab(saved.id);
        await tester.pumpWidget(sidePanelHarness(controller));
        await tester.pumpAndSettle();
        final page = tester.state<BrowserPageViewState>(
          find.byType(BrowserPage),
        );
        page.focusFind();
        await tester.pump();
        final handledEscape = page.escapePanelEditing();
        await tester.pumpAndSettle();
        expect(handledEscape, isFalse);
        expect(allocations, 0);
        expect(service.hasLiveEngine(saved.id), isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        service.dispose();
      },
    );
  }

  testWidgets(
    'browser storage can recover without leaving a stale panel error',
    (tester) async {
      await size(tester, 1126);
      final store = _RetryPanelStore();
      final service = BrowserService(store: store, supported: false);
      final controller = DesktopSidePanelController(browser: service)..open();
      await tester.pumpWidget(sidePanelHarness(controller));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Temporary browser storage error'),
        findsOneWidget,
      );
      store.fail = false;
      await tester.tap(
        find.descendant(
          of: find.byType(MaterialBanner),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Temporary browser storage error'),
        findsNothing,
      );
      expect(service.isInitialized, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      service.dispose();
    },
  );

  test(
    'recording a shortcut does not execute the captured app command',
    () async {
      final provider = HotkeyProvider();
      final actions = <HotkeyAction>[];
      final sub = HotkeyEventBus.instance.stream.listen(actions.add);
      final owner = Object();
      provider.beginRecording(owner);
      provider.invoke('side_panel_new_web');
      await Future<void>.delayed(Duration.zero);
      expect(actions, isEmpty);
      provider.endRecording(owner);
      provider.invoke('side_panel_new_web');
      await Future<void>.delayed(Duration.zero);
      expect(actions, [HotkeyAction.sidePanelNewWeb]);
      await sub.cancel();
      provider.dispose();
    },
  );

  test('custom letter commands use the same native canonical spelling', () {
    expect(HotkeyProvider.canonicalCommand('cmd+shift+keyt'), 'cmd+shift+t');
    expect(HotkeyProvider.canonicalCommand('meta+option+keyb'), 'cmd+alt+b');
  });
  testWidgets(
    'native viewport stays mounted across tab, width and presentation changes',
    (tester) async {
      await size(tester, 1126);
      final engines = <String, _RetainedEngine>{};
      final service = BrowserService(
        store: SidePanelMemoryStore(),
        supported: true,
        liveViewLimit: 6,
        engineFactory:
            ({
              required tab,
              required settings,
              required onChanged,
              required onDownload,
              required onNewWindow,
              required isAgentActive,
            }) async => engines[tab.id] = _RetainedEngine(tab, onChanged),
      );
      final controller = DesktopSidePanelController(browser: service)
        ..setContext(conversationId: 'a', topicsOnRight: false);
      await controller.newWebTab(url: 'https://one.example');
      await service.reload();
      final first = service.activeTabId!;
      await tester.pumpWidget(sidePanelHarness(controller));
      await tester.pumpAndSettle();
      final native = tester.element(find.byKey(ValueKey('$first:0')));
      await controller.newWebTab(url: 'https://two.example');
      await service.reload();
      await tester.pumpAndSettle();
      controller.activate('web:$first');
      await tester.pumpAndSettle();
      expect(tester.element(find.byKey(ValueKey('$first:0'))), same(native));
      await tester.drag(
        find.byKey(const ValueKey('sidePanelResizeHandle')),
        const Offset(-70, 0),
      );
      await tester.pump();
      controller.activate('files');
      await tester.pump();
      controller.activate('web:$first');
      controller.close();
      await tester.pump();
      controller.open();
      controller.setExpanded(true);
      await tester.pump();
      controller.setExpanded(false);
      await tester.pump(const Duration(milliseconds: 100));
      tester.view.physicalSize = const Size(726, 720);
      await tester.pump();
      expect(tester.element(find.byKey(ValueKey('$first:0'))), same(native));
      expect(
        engines.values.map((engine) => engine.viewBuilds),
        everyElement(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      service.dispose();
    },
  );

  testWidgets(
    'docked drag accumulates deltas, clamps, saves only at end and resets',
    (tester) async {
      await size(tester, 1126);
      await tester.pumpWidget(sidePanelHarness(panel));
      panel.open();
      await tester.pumpAndSettle();
      final files = find.byKey(const ValueKey('filesBody'));
      final chat = find.byKey(const ValueKey('chatBody'));
      final element = tester.element(chat);
      expect(tester.getSize(files).width, closeTo(520, 1));
      final grip = find.byKey(const ValueKey('sidePanelResizeHandle'));
      final mouse = await tester.startGesture(
        tester.getCenter(grip),
        kind: PointerDeviceKind.mouse,
      );
      await mouse.moveBy(const Offset(-10, 0));
      await mouse.moveBy(const Offset(-20, 0));
      await tester.pump();
      expect(panel.preferredWidth, 520);
      expect(tester.getSize(files).width, closeTo(550, 1));
      await mouse.moveBy(const Offset(-400, 0));
      await tester.pump();
      expect(tester.getSize(files).width, closeTo(637, 1));
      await mouse.up();
      await tester.pump();
      expect(panel.preferredWidth, 637);
      expect(panel.hasFocus, isTrue);
      expect(panel.handleCloseWindow(), isTrue);
      await tester.tap(grip);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(grip);
      await tester.pumpAndSettle();
      expect(panel.preferredWidth, 520);
      panel.close();
      await tester.pump();
      expect(tester.element(chat), same(element));
      expect(find.byType(SidePanelTabBar), findsNothing);
      await browser.flush();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('overlay dismisses, returns focus and widens into docked', (
    tester,
  ) async {
    await size(tester, 726);
    var focusedChat = 0;
    await tester.pumpWidget(
      sidePanelHarness(panel, onFocusChat: () => focusedChat++),
    );
    panel.open();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sidePanelScrim')), findsOneWidget);
    expect(panel.hasFocus, isTrue);
    expect(find.byKey(const ValueKey('sidePanelResizeHandle')), findsNothing);
    await tester.tapAt(const Offset(30, 300));
    await tester.pumpAndSettle();
    expect(panel.isOpen, isFalse);
    expect(focusedChat, greaterThan(0));
    panel.open();
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1126, 720);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sidePanelScrim')), findsNothing);
    expect(find.byKey(const ValueKey('sidePanelResizeHandle')), findsOneWidget);
    expect(panel.preferredWidth, 520);
    await browser.flush();
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('keyboard tab traversal activates and closes resources', (
    tester,
  ) async {
    await size(tester, 1126);
    panel.setContext(conversationId: 'a', topicsOnRight: false);
    panel.openPreview('/PLAN.md');
    final previewId = panel.activeTab.id;
    await tester.pumpWidget(sidePanelHarness(panel));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sidePanelTab-files')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'Panel tab $previewId',
    );
    expect(panel.activeTab.id, 'files');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(panel.activeTab.id, previewId);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(panel.tabs.whereType<PreviewTab>(), isEmpty);
    expect(panel.activeTab.id, 'files');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'close window dispatch follows real focus including pinned entry',
    (tester) async {
      await size(tester, 1126);
      final chatFocus = FocusNode();
      addTearDown(chatFocus.dispose);
      await tester.pumpWidget(
        sidePanelHarness(
          panel,
          child: Material(child: TextField(focusNode: chatFocus)),
        ),
      );
      chatFocus.requestFocus();
      panel.open();
      await tester.pumpAndSettle();
      var windowCloses = 0;
      void closeCommand() {
        if (!panel.handleCloseWindow()) windowCloses++;
      }

      closeCommand();
      expect(windowCloses, 1);
      await tester.tap(find.byKey(const ValueKey('filesBody')));
      await tester.pump();
      expect(panel.hasFocus, isTrue);
      closeCommand();
      expect(windowCloses, 1);
      expect(panel.isOpen, isTrue);
      panel.openPreview('/missing.md');
      await tester.pumpAndSettle();
      final id = panel.activeTab.id;
      closeCommand();
      await tester.pump();
      expect(panel.tabs.any((tab) => tab.id == id), isFalse);
      expect(windowCloses, 1);
      await browser.flush();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Esc closes menu then address, expanded view, overlay and restores chat',
    (tester) async {
      await size(tester, 726);
      panel.setContext(conversationId: 'a', topicsOnRight: false);
      await panel.newWebTab(url: 'https://example.com');
      var chatFocused = 0;
      await tester.pumpWidget(
        sidePanelHarness(panel, onFocusChat: () => chatFocused++),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sidePanelAdd')));
      await tester.pumpAndSettle();
      expect(find.text('Open file…'), findsOneWidget);
      expect(panel.isAvailable, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Open file…'), findsNothing);
      expect(panel.isAvailable, isTrue);
      expect(panel.isOpen, isTrue);
      await tester.tap(find.byType(BrowserAddressBar));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('browserAddressField')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('browserAddressField')), findsNothing);
      expect(panel.isOpen, isTrue);
      panel.setExpanded(true);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(panel.isExpanded, isFalse);
      expect(panel.isOpen, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(panel.isOpen, isFalse);
      expect(chatFocused, greaterThan(0));
      expect(panel.tabs.whereType<WebTab>().length, 1);
      await browser.flush();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'F6 cycles chat tabs content, reopen and tab traversal use focus',
    (tester) async {
      await size(tester, 1126);
      final chatFocus = FocusNode();
      addTearDown(chatFocus.dispose);
      await tester.pumpWidget(
        sidePanelHarness(
          panel,
          child: Material(child: TextField(focusNode: chatFocus)),
          onFocusChat: chatFocus.requestFocus,
        ),
      );
      panel.open();
      chatFocus.requestFocus();
      await tester.pumpAndSettle();
      HotkeyEventBus.instance.fire(HotkeyAction.sidePanelFocus);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Panel tab files');
      HotkeyEventBus.instance.fire(HotkeyAction.sidePanelFocus);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Panel content');
      HotkeyEventBus.instance.fire(HotkeyAction.sidePanelFocus);
      await tester.pump();
      expect(chatFocus.hasFocus, isTrue);
      panel.openPreview('/missing.md');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SidePanelTabBar));
      await tester.pump();
      final id = panel.activeTab.id;
      panel.closeTab(id);
      await tester.pump();
      HotkeyEventBus.instance.fire(HotkeyAction.sidePanelReopenTab);
      await tester.pumpAndSettle();
      expect(panel.activeTab.id, id);
      HotkeyEventBus.instance.fire(HotkeyAction.sidePanelPreviousTab);
      await tester.pump();
      expect(panel.activeTab.kind, SidePanelTabKind.files);
      await browser.flush();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Linux web tabs remain available without native creation', (
    tester,
  ) async {
    await size(tester, 1126);
    panel.setContext(conversationId: 'a', topicsOnRight: false);
    await panel.newWebTab(url: 'https://example.com');
    await tester.pumpWidget(sidePanelHarness(panel));
    await tester.pumpAndSettle();
    expect(
      find.text('The embedded browser is not available on this platform.'),
      findsOneWidget,
    );
    expect(find.text('Open in default browser'), findsWidgets);
    expect(browser.liveViewCount, 0);
    panel.activate('files');
    await tester.pump();
    expect(find.byKey(const ValueKey('filesBody')), findsOneWidget);
    await browser.flush();
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'tight overflow keeps active tab and searchable list closes directly',
    (tester) async {
      await size(tester, 1126);
      panel.setContext(conversationId: 'a', topicsOnRight: true);
      for (var i = 0; i < 8; i++) {
        panel.openPreview('/file$i.md');
      }
      panel.setPreferredWidth(360);
      await tester.pumpWidget(sidePanelHarness(panel, topicsOnRight: true));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('sidePanelTab-${panel.activeTab.id}')),
        findsOneWidget,
      );
      expect(find.text('» 7'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('sidePanelAllTabs')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'file3');
      await tester.pump();
      expect(find.text('file3.md'), findsOneWidget);
      final close = find.bySemanticsLabel('Close tab');
      await tester.tap(close.last);
      await tester.pumpAndSettle();
      expect(
        panel.tabs.whereType<PreviewTab>().any(
          (tab) => tab.path == '/file3.md',
        ),
        isFalse,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await browser.flush();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'native command disabled for chat, enabled for focused panel and modal safe',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await size(tester, 1126);
      const channel = MethodChannel('app.browser_window');
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
      Future<void> command(String command) async {
        final complete = Completer<void>();
        tester.binding.channelBuffers.push(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall('shortcut', command)),
          (_) => complete.complete(),
        );
        await complete.future;
      }

      await tester.pumpWidget(sidePanelHarness(panel));
      panel.openPreview('/native.md');
      await tester.pumpAndSettle();
      await command('cmd+w');
      await tester.pump();
      expect(panel.tabs.whereType<PreviewTab>().length, 1);
      await tester.tap(find.byType(SidePanelTabBar));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sidePanelAdd')));
      await tester.pumpAndSettle();
      await command('cmd+w');
      await tester.pump();
      expect(panel.tabs.whereType<PreviewTab>().length, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await command('cmd+w');
      await tester.pump();
      expect(panel.tabs.whereType<PreviewTab>(), isEmpty);
      await browser.flush();
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
