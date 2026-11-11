import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/browser/browser_service.dart';
import '../../utils/platform_utils.dart';
import '../chat/utils/ensure_conversation.dart';
import 'browser_panel_controller.dart';
import 'browser_desktop_route.dart';
import 'pages/browser_page.dart';

/// The same conversation identity is used by the visible browser and its tools.
Future<void> openBrowserPage(
  BuildContext context, {
  String? conversationId,
  String? assistantId,
  String? tabId,
  String? url,
  bool fullPage = false,
}) async {
  final id = await ensureConversationId(
    context,
    conversationId: conversationId,
    assistantId: assistantId,
  );
  if (!context.mounted) return;
  final browser = BrowserService.instance;
  String? selectedTabId;
  // A historical/closed tab falls back to the normal entry path. Let the page
  // own cold initialization (including its existing storage-error UI).
  if (tabId != null && browser.tabs.any((tab) => tab.id == tabId)) {
    selectedTabId = tabId;
    await browser.selectTab(tabId);
    if (!context.mounted) return;
  }
  if (url != null) {
    await browser.initialize();
    final tab = await browser.createTab(ownerSessionId: id);
    selectedTabId = tab.id;
    try {
      if (browser.isSupported) {
        await browser.navigate(url, tabId: tab.id);
      } else {
        await browser.setSavedAddress(tab.id, url);
      }
    } catch (_) {
      await browser.closeTab(tab.id);
      rethrow;
    }
    if (!context.mounted) return;
  }
  final panel = BrowserPanelController.instance;
  if (!fullPage &&
      PlatformUtils.isDesktop &&
      panel.open(conversationId: id, initialTabId: selectedTabId)) {
    return;
  }
  final navigator = Navigator.of(context);
  final desktop = PlatformUtils.isDesktop;
  final initialTabId =
      selectedTabId ??
      (panel.isOpen && panel.conversationId == id ? browser.activeTabId : null);
  final canDock = desktop && panel.hasHost;
  Widget buildPage(BuildContext pageContext) => BrowserPage(
    conversationId: id,
    initialTabId: initialTabId,
    onDock: canDock
        ? () {
            unawaited(BrowserService.instance.refreshActivePreview());
            // Mount the destination in the same frame that removes this route.
            // Its ViewHost shows the saved preview until the old native host
            // detaches; waiting for route.completed would first expose a full
            // frame of chat and only then snap the browser pane into place.
            if (panel.open(
              conversationId: id,
              initialTabId: BrowserService.instance.activeTabId,
            )) {
              Navigator.of(pageContext).pop();
            }
          }
        : null,
  );
  final Route<void> route = desktop
      ? BrowserDesktopRoute(
          reduceMotion: MediaQuery.disableAnimationsOf(context),
          builder: buildPage,
        )
      : MaterialPageRoute<void>(builder: buildPage, allowSnapshotting: false);
  // Native WebViews must never participate in Material's whole-route zoom or
  // slide transform. Removing the pane and pushing the untransformed page in
  // one frame also prevents an intermediate full-width chat flash on expand.
  if (desktop) unawaited(BrowserService.instance.refreshActivePreview());
  panel.close();
  await navigator.push<void>(route);
}
