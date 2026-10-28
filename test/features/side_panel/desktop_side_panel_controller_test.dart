import 'dart:async';
import 'dart:convert';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/features/side_panel/desktop_side_panel_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../core/services/browser/browser_service_test.dart'
    show FakeBrowserEngine;
import '../../support/business_test_harness.dart';
import 'side_panel_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final right in [false, true]) {
    for (final files in [false, true]) {
      for (final topics in [false, true]) {
        test(
          'migration right=$right files=$files topics=$topics is idempotent',
          () async {
            final harness = await createBusinessTestHarness(
              initial: {
                'desktop_topic_position_v1': right ? 'right' : 'left',
                'desktop_workspace_bar_open_v1': files,
                'desktop_right_sidebar_open_v1': topics,
                'desktop_right_sidebar_width_v1': 300.0,
              },
            );
            final service = BrowserService(
              store: SidePanelMemoryStore(),
              supported: false,
            );
            final controller = DesktopSidePanelController(browser: service)
              ..bindPreferences(harness.preferences);
            expect(controller.isOpen, files || right && topics);
            expect(
              controller.lastKind,
              right && topics
                  ? SidePanelTabKind.topics
                  : SidePanelTabKind.files,
            );
            expect(controller.preferredWidth, 360);
            await controller.flush();
            expect(
              harness.preferences.getBool('desktop_side_panel_migrated_v1'),
              isTrue,
            );
            controller.setPreferredWidth(650);
            controller.close();
            await controller.flush();
            final restored = DesktopSidePanelController(browser: service)
              ..bindPreferences(harness.preferences);
            expect(restored.isOpen, isFalse);
            expect(restored.preferredWidth, 650);
            expect(
              harness.preferences.getDouble('desktop_right_sidebar_width_v1'),
              300,
            );
            await restored.flush();
            restored.dispose();
            controller.dispose();
            service.dispose();
          },
        );
      }
    }
  }
  test('default width, limits and presentation use available chat width', () {
    final service = BrowserService(
      store: SidePanelMemoryStore(),
      supported: false,
    );
    final panel = DesktopSidePanelController(browser: service);
    expect(panel.preferredWidth, 520);
    expect(panel.presentationFor(1440), SidePanelPresentation.hidden);
    panel.open();
    expect(panel.presentationFor(1040 - 314), SidePanelPresentation.overlay);
    expect(panel.presentationFor(1180 - 314), SidePanelPresentation.docked);
    expect(DesktopSidePanelController.maxWidthFor(1440 - 314), 637);
    panel.setPreferredWidth(1000);
    expect(panel.preferredWidth, 900);
    expect(panel.widthFor(1126), 637);
    expect(panel.widthFor(400), 400);
    expect(panel.preferredWidth, 900);
    panel.setPreferredWidth(20);
    expect(panel.preferredWidth, 360);
    panel.setExpanded(true);
    expect(panel.widthFor(1126), 1126);
    panel.close();
    expect(panel.isExpanded, isFalse);
    panel.dispose();
    service.dispose();
  });
  test(
    'closing during a pending new web request does not reopen the panel',
    () async {
      final service = BrowserService(
        store: SidePanelMemoryStore(),
        supported: false,
      );
      final panel = DesktopSidePanelController(browser: service);
      final pending = panel.newWebTab();
      panel.close();
      await pending;
      expect(panel.isOpen, isFalse);
      expect(service.tabs, hasLength(1));
      panel.dispose();
      service.dispose();
    },
  );

  test('capacity keeps selected resource visible, even in tight panels', () {
    final resources = List.generate(
      9,
      (i) => PreviewTab(id: '$i', path: '$i.md', source: 'outputs'),
    );
    expect(DesktopSidePanelController.resourceCapacity(520, 1), 2);
    expect(DesktopSidePanelController.resourceCapacity(360, 2), 0);
    final visible = DesktopSidePanelController.visibleResources(
      resources,
      2,
      '7',
    );
    expect(visible.map((tab) => tab.id), ['0', '7']);
    expect(
      DesktopSidePanelController.visibleResources(resources, 0, '7').single.id,
      '7',
    );
  });
  for (final kind in [SidePanelTabKind.web, SidePanelTabKind.preview]) {
    test(
      'reopening preserves the selected $kind in each conversation',
      () async {
        final service = BrowserService(
          store: SidePanelMemoryStore(),
          supported: false,
        );
        final panel = DesktopSidePanelController(browser: service)
          ..setContext(conversationId: 'a', topicsOnRight: false);
        for (var i = 0; i < 2; i++) {
          if (kind == SidePanelTabKind.web) {
            await panel.newWebTab();
          } else {
            panel.openPreview('/$i.md');
          }
        }
        final selected = panel.activeTab.id;
        panel.close();
        panel.toggle();
        expect(panel.activeTab.id, selected);
        panel.setContext(conversationId: 'b', topicsOnRight: false);
        panel.openPreview('/other.md');
        panel.close();
        panel.setContext(conversationId: 'a', topicsOnRight: false);
        panel.open();
        expect(panel.activeTab.id, selected);
        panel.open(kind: SidePanelTabKind.files);
        expect(panel.activeTab.kind, SidePanelTabKind.files);
        panel.dispose();
        service.dispose();
      },
    );
  }

  test('closing an idle web tab leaves agent browsing available', () async {
    final service = BrowserService(
      store: SidePanelMemoryStore(),
      supported: false,
    );
    final panel = DesktopSidePanelController(browser: service)
      ..setContext(conversationId: 'a', topicsOnRight: false);
    await panel.newWebTab();
    panel.closeTab(panel.activeTab.id);
    expect(service.agentPaused, isFalse);
    expect(
      await service.runAgentAction(
        sessionId: 'b',
        label: 'next action',
        action: () async => 'available',
      ),
      'available',
    );
    panel.dispose();
    service.dispose();
  });

  for (final relation in ['other topic', 'other tab', 'same tab', 'popup']) {
    test('closing a web tab scopes agent takeover to its $relation', () async {
      final service = BrowserService(
        store: SidePanelMemoryStore(),
        supported: false,
      );
      final panel = DesktopSidePanelController(browser: service)
        ..setContext(conversationId: 'a', topicsOnRight: false);
      final closing = await service.createTab(ownerSessionId: 'a');
      final running = relation == 'same tab'
          ? closing
          : await service.createTab(
              ownerSessionId: relation == 'other topic' ? 'b' : 'a',
              openerTabId: relation == 'popup' ? closing.id : null,
              popupGroupId: relation == 'popup' ? closing.id : null,
            );
      final started = Completer<void>();
      final finish = Completer<void>();
      final result = service
          .runAgentAction(
            sessionId: running.ownerSessionId!,
            tabId: running.id,
            label: 'running',
            action: () async {
              started.complete();
              await finish.future;
              return 'completed';
            },
          )
          .then<Object>((value) => value, onError: (Object error) => error);
      await started.future;
      panel.closeTab('web:${closing.id}');
      final affected = relation == 'same tab' || relation == 'popup';
      expect(service.agentPaused, affected);
      finish.complete();
      expect(await result, affected ? isA<StateError>() : 'completed');
      await Future<void>.delayed(Duration.zero);
      panel.dispose();
      service.dispose();
    });
  }

  test(
    'new and reopened URLs load, while activating an unloaded tab is lazy',
    () async {
      final engines = <String, FakeBrowserEngine>{};
      final service = BrowserService(
        store: SidePanelMemoryStore(),
        supported: true,
        liveViewLimit: 1,
        engineFactory:
            ({
              required tab,
              required settings,
              required onChanged,
              required onDownload,
              required onNewWindow,
              required isAgentActive,
            }) async => engines[tab.id] = FakeBrowserEngine(tab, onChanged),
      );
      final panel = DesktopSidePanelController(browser: service)
        ..setContext(conversationId: 'a', topicsOnRight: false);
      await panel.newWebTab(url: 'https://first.example');
      final first = panel.activeTab as WebTab;
      expect(service.hasLiveEngine(first.browserTabId), isTrue);
      expect(engines[first.browserTabId]!.tab.url, 'https://first.example');
      await panel.newWebTab(url: 'https://second.example');
      final second = panel.activeTab as WebTab;
      expect(first.evicted, isTrue);
      panel.activate(first.id);
      expect(first.evicted, isTrue);
      expect(engines, hasLength(2));
      panel.closeTab(second.id);
      await panel.reopenClosedTab();
      final reopened = panel.activeTab as WebTab;
      expect(reopened.browserTabId, isNot(second.browserTabId));
      expect(reopened.evicted, isFalse);
      expect(engines[reopened.browserTabId]!.tab.url, 'https://second.example');
      panel.dispose();
      service.dispose();
    },
  );

  test(
    'close selects left, pinned tabs survive, reopen is scoped and bounded',
    () async {
      final service = BrowserService(
        store: SidePanelMemoryStore(),
        supported: false,
      );
      final panel = DesktopSidePanelController(browser: service)
        ..setContext(conversationId: 'a', topicsOnRight: true);
      panel.openPreview('/a.md');
      final first = panel.activeTab.id;
      panel.openPreview('/b.md');
      final second = panel.activeTab.id;
      panel.openPreview('/c.md');
      expect(panel.closeTab(panel.activeTab.id), isTrue);
      expect(panel.activeTab.id, second);
      panel.closeTab(second);
      expect(panel.activeTab.id, first);
      panel.closeTab(first);
      expect(panel.activeTab.kind, SidePanelTabKind.files);
      expect(panel.closeTab('topics'), isFalse);
      expect(panel.closeTab('files'), isFalse);
      await panel.reopenClosedTab();
      expect((panel.activeTab as PreviewTab).path, '/a.md');
      panel.setContext(conversationId: 'b', topicsOnRight: true);
      expect(panel.tabs.length, 2);
      await panel.reopenClosedTab();
      expect(panel.tabs.length, 2);
      panel.setContext(conversationId: 'a', topicsOnRight: true);
      expect((panel.activeTab as PreviewTab).path, '/a.md');
      for (var i = 0; i < 12; i++) {
        panel.openPreview('/$i.md');
        panel.closeTab(panel.activeTab.id);
      }
      for (var i = 0; i < 12; i++) {
        await panel.reopenClosedTab();
      }
      expect(panel.tabs.whereType<PreviewTab>().length, 11);
      panel.dispose();
      service.dispose();
    },
  );
  test(
    'persisted resources restore before browser and reconcile BrowserStore',
    () async {
      final harness = await createBusinessTestHarness(
        initial: {'desktop_side_panel_migrated_v1': true},
      );
      final store = SidePanelMemoryStore();
      final service = BrowserService(store: store, supported: false);
      final panel = DesktopSidePanelController(browser: service)
        ..bindPreferences(harness.preferences)
        ..setContext(conversationId: 'a', topicsOnRight: false);
      panel.openPreview('/test.md', source: 'outputs');
      await panel.newWebTab(url: 'https://example.com');
      final web = panel.activeTab as WebTab;
      expect(web.evicted, isTrue);
      panel.activate(web.id);
      expect(service.liveViewCount, 0);
      await panel.flush();
      await service.flush();
      final persisted =
          jsonDecode(
                harness.preferences.getString('desktop_side_panel_tabs_v1')!,
              )
              as Map;
      expect(persisted['a']['tabs'].length, 2);
      final restoredBrowser = BrowserService(store: store, supported: false);
      final restored = DesktopSidePanelController(browser: restoredBrowser)
        ..bindPreferences(harness.preferences)
        ..setContext(conversationId: 'a', topicsOnRight: false);
      expect(restored.tabs.length, 3);
      expect(restored.activeTab.id, web.id);
      await restoredBrowser.initialize();
      expect(restored.activeTab.id, web.id);
      expect(restoredBrowser.liveViewCount, 0);
      await restored.flush();
      restored.dispose();
      restoredBrowser.dispose();
      panel.dispose();
      service.dispose();
    },
  );
}
