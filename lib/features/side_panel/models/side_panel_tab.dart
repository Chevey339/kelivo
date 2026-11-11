import '../../../core/services/browser/browser_service.dart';
import '../../browser/models/browser_models.dart';

enum SidePanelTabKind { topics, files, web, preview }

sealed class SidePanelTab {
  const SidePanelTab();
  String get id;
  SidePanelTabKind get kind;
  bool get pinned => false;
  bool get closable => !pinned;
  Map<String, Object?> toJson();
}

class PinnedTab extends SidePanelTab {
  const PinnedTab(this.kind)
    : assert(kind == SidePanelTabKind.topics || kind == SidePanelTabKind.files);
  @override
  final SidePanelTabKind kind;
  @override
  String get id => kind.name;
  @override
  bool get pinned => true;
  @override
  Map<String, Object?> toJson() => {'kind': kind.name, 'id': id};
}

class WebTab extends SidePanelTab {
  const WebTab({required this.browserTabId, required this.browser});
  final String browserTabId;
  final BrowserService browser;
  BrowserTab? get page =>
      browser.tabs.where((tab) => tab.id == browserTabId).firstOrNull;
  String? get conversationId => page?.ownerSessionId;
  bool get evicted =>
      page != null &&
      (page!.url != 'about:blank' || page!.hasContent) &&
      !browser.hasLiveEngine(browserTabId);
  @override
  String get id => 'web:$browserTabId';
  @override
  SidePanelTabKind get kind => SidePanelTabKind.web;
  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'id': id,
    'browserTabId': browserTabId,
    'conversationId': conversationId,
    'title': page?.title,
    'url': page?.url,
  };
}

class PreviewTab extends SidePanelTab {
  const PreviewTab({
    required this.id,
    required this.path,
    required this.source,
  });
  @override
  final String id;
  final String path;
  final String source;
  @override
  SidePanelTabKind get kind => SidePanelTabKind.preview;
  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'id': id,
    'path': path,
    'source': source,
  };
}
