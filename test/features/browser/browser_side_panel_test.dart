import 'dart:async';

import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/features/browser/browser_panel_controller.dart';
import 'package:Kelivo/features/side_panel/desktop_side_panel_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore extends BrowserStore {
  @override
  Future<Map<String, dynamic>> read() async => {};
  @override
  Future<void> write(Map<String, Object?> state) async {}
}

class _DelayedStore extends _MemoryStore {
  final state = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> read() => state.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'closing the shared panel cancels a cold browser open request',
    () async {
      final store = _DelayedStore();
      final service = BrowserService(store: store, supported: false);
      final panel = DesktopSidePanelController(browser: service)
        ..setContext(conversationId: 'one', topicsOnRight: false);
      final browser = BrowserPanelController(panel: panel)..attachHost();
      final initializing = service.initialize();
      browser.open(conversationId: 'one');
      panel.close();
      store.state.complete({});
      await initializing;
      panel.open(kind: SidePanelTabKind.files);
      await Future<void>.delayed(Duration.zero);
      expect(panel.activeTab.kind, SidePanelTabKind.files);
      expect(service.tabs, isEmpty);
      browser.dispose();
      panel.dispose();
      service.dispose();
    },
  );

  test(
    'browser requests forward to shared panel and detach rejects stale requests',
    () async {
      final service = BrowserService(store: _MemoryStore(), supported: false);
      final panel = DesktopSidePanelController(browser: service);
      final browser = BrowserPanelController(panel: panel);
      expect(browser.open(conversationId: 'one'), isFalse);
      panel.setContext(conversationId: 'one', topicsOnRight: false);
      browser.attachHost();
      expect(browser.open(conversationId: 'one'), isTrue);
      await service.initialize();
      await Future<void>.delayed(Duration.zero);
      expect(panel.activeTab, isA<WebTab>());
      expect(browser.conversationId, 'one');
      final saved = panel.activeTab.id;
      browser.close();
      expect(panel.isOpen, isFalse);
      expect(panel.tabs.any((tab) => tab.id == saved), isTrue);
      browser.open(conversationId: 'one');
      browser.detachHost();
      await Future<void>.delayed(Duration.zero);
      expect(browser.hasHost, isFalse);
      expect(browser.isOpen, isFalse);
      expect(browser.conversationId, isNull);
      expect(browser.initialTabId, isNull);
      browser.dispose();
      panel.dispose();
      service.dispose();
    },
  );

  test(
    'foreign tab handoff retains ownership and no extra browser tab',
    () async {
      final service = BrowserService(store: _MemoryStore(), supported: false);
      final panel = DesktopSidePanelController(browser: service);
      final browser = BrowserPanelController(panel: panel);
      panel.setContext(conversationId: 'a', topicsOnRight: false);
      final foreign = await service.createTab(
        ownerSessionId: 'b',
        url: 'https://example.com',
      );
      browser.attachHost();
      browser.open(conversationId: 'a', initialTabId: foreign.id);
      await Future<void>.delayed(Duration.zero);
      expect((panel.activeTab as WebTab).conversationId, 'b');
      expect(service.tabs.length, 1);
      browser.close();
      expect(browser.initialTabId, isNull);
      browser.detachHost();
      browser.dispose();
      panel.dispose();
      service.dispose();
    },
  );
}
