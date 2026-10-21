enum BrowserSearchEngine { bing, google, duckDuckGo, baidu }

enum BrowserSurfaceStyle { liquid, frosted, solid }

class BrowserSettings {
  const BrowserSettings({
    this.searchEngine = BrowserSearchEngine.bing,
    this.desktopMode = false,
    this.customUserAgent = '',
    this.restoreTabs = true,
    this.saveHistory = true,
    this.agentEnabled = true,
    this.surfaceStyle = BrowserSurfaceStyle.solid,
  });

  final BrowserSearchEngine searchEngine;
  final bool desktopMode;

  /// Empty uses the mobile/desktop preset. A custom value overrides that UA.
  final String customUserAgent;
  static bool isValidUserAgent(String value) =>
      value.length <= 2048 && !RegExp(r'[^\x20-\x7e]').hasMatch(value);
  final bool restoreTabs;
  final bool saveHistory;
  final bool agentEnabled;
  final BrowserSurfaceStyle surfaceStyle;

  BrowserSettings copyWith({
    BrowserSearchEngine? searchEngine,
    bool? desktopMode,
    String? customUserAgent,
    bool? restoreTabs,
    bool? saveHistory,
    bool? agentEnabled,
    BrowserSurfaceStyle? surfaceStyle,
  }) => BrowserSettings(
    searchEngine: searchEngine ?? this.searchEngine,
    desktopMode: desktopMode ?? this.desktopMode,
    customUserAgent: customUserAgent ?? this.customUserAgent,
    restoreTabs: restoreTabs ?? this.restoreTabs,
    saveHistory: saveHistory ?? this.saveHistory,
    agentEnabled: agentEnabled ?? this.agentEnabled,
    surfaceStyle: surfaceStyle ?? this.surfaceStyle,
  );

  Map<String, Object?> toJson() => {
    'searchEngine': searchEngine.name,
    'desktopMode': desktopMode,
    'customUserAgent': customUserAgent,
    'restoreTabs': restoreTabs,
    'saveHistory': saveHistory,
    'agentEnabled': agentEnabled,
    'surfaceStyle': surfaceStyle.name,
  };

  factory BrowserSettings.fromJson(
    Map<String, dynamic> json, {
    bool defaultDesktopMode = false,
  }) => BrowserSettings(
    searchEngine: BrowserSearchEngine.values.firstWhere(
      (value) => value.name == json['searchEngine'],
      orElse: () => BrowserSearchEngine.bing,
    ),
    desktopMode: json['desktopMode'] is bool
        ? json['desktopMode'] as bool
        : defaultDesktopMode,
    customUserAgent: switch (json['customUserAgent']) {
      final String value when isValidUserAgent(value) => value.trim(),
      _ => '',
    },
    restoreTabs: json['restoreTabs'] != false,
    saveHistory: json['saveHistory'] != false,
    agentEnabled: json['agentEnabled'] != false,
    surfaceStyle: BrowserSurfaceStyle.values.firstWhere(
      (value) => value.name == json['surfaceStyle'],
      orElse: () => BrowserSurfaceStyle.solid,
    ),
  );
}

class BrowserTab {
  const BrowserTab({
    required this.id,
    this.url = 'about:blank',
    this.title = '',
    this.ownerSessionId,
    this.isLoading = false,
    this.progress = 0,
    this.canGoBack = false,
    this.canGoForward = false,
    this.error,
    this.hasContent = false,
    this.runtimeVersion = 0,
    this.windowId,
    this.openerTabId,
    this.popupGroupId,
  });

  final String id;
  final String url;
  final String title;
  final String? ownerSessionId;
  final bool isLoading;
  final double progress;
  final bool canGoBack;
  final bool canGoForward;
  final String? error;
  final bool hasContent;
  final int runtimeVersion;
  final int? windowId;
  final String? openerTabId;
  final String? popupGroupId;

  BrowserTab copyWith({
    String? url,
    String? title,
    String? ownerSessionId,
    bool? isLoading,
    double? progress,
    bool? canGoBack,
    bool? canGoForward,
    String? error,
    bool? hasContent,
    int? runtimeVersion,
    bool clearWindowId = false,
    bool detachPopup = false,
  }) => BrowserTab(
    id: id,
    url: url ?? this.url,
    title: title ?? this.title,
    ownerSessionId: ownerSessionId ?? this.ownerSessionId,
    isLoading: isLoading ?? this.isLoading,
    progress: progress ?? this.progress,
    canGoBack: canGoBack ?? this.canGoBack,
    canGoForward: canGoForward ?? this.canGoForward,
    error: error,
    hasContent: hasContent ?? this.hasContent,
    runtimeVersion: runtimeVersion ?? this.runtimeVersion,
    windowId: clearWindowId ? null : windowId,
    openerTabId: detachPopup ? null : openerTabId,
    popupGroupId: detachPopup ? null : popupGroupId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'url': url,
    'title': title,
    'ownerSessionId': ownerSessionId,
  };

  factory BrowserTab.fromJson(Map<String, dynamic> json) => BrowserTab(
    id: json['id'] as String,
    url: json['url'] as String? ?? 'about:blank',
    title: json['title'] as String? ?? '',
    ownerSessionId: json['ownerSessionId'] as String?,
  );
}

class BrowserBookmark {
  const BrowserBookmark({
    required this.url,
    required this.title,
    required this.createdAt,
  });
  final String url;
  final String title;
  final DateTime createdAt;
  Map<String, Object?> toJson() => {
    'url': url,
    'title': title,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };
  factory BrowserBookmark.fromJson(Map<String, dynamic> json) =>
      BrowserBookmark(
        url: json['url'] as String,
        title: json['title'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['createdAt'] as int,
        ),
      );
}

class BrowserHistoryEntry {
  const BrowserHistoryEntry({
    required this.url,
    required this.title,
    required this.visitedAt,
  });
  final String url;
  final String title;
  final DateTime visitedAt;
  Map<String, Object?> toJson() => {
    'url': url,
    'title': title,
    'visitedAt': visitedAt.millisecondsSinceEpoch,
  };
  factory BrowserHistoryEntry.fromJson(Map<String, dynamic> json) =>
      BrowserHistoryEntry(
        url: json['url'] as String,
        title: json['title'] as String? ?? '',
        visitedAt: DateTime.fromMillisecondsSinceEpoch(
          json['visitedAt'] as int,
        ),
      );
}

enum BrowserDownloadStatus { downloading, completed, failed, cancelled }

class BrowserDownload {
  const BrowserDownload({
    required this.id,
    required this.url,
    required this.fileName,
    this.path,
    this.receivedBytes = 0,
    this.totalBytes = -1,
    this.status = BrowserDownloadStatus.downloading,
    this.error,
  });
  final String id;
  final String url;
  final String fileName;
  final String? path;
  final int receivedBytes;
  final int totalBytes;
  final BrowserDownloadStatus status;
  final String? error;
  BrowserDownload copyWith({
    String? path,
    int? receivedBytes,
    int? totalBytes,
    BrowserDownloadStatus? status,
    String? error,
  }) => BrowserDownload(
    id: id,
    url: url,
    fileName: fileName,
    path: path ?? this.path,
    receivedBytes: receivedBytes ?? this.receivedBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    status: status ?? this.status,
    error: error,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'url': url,
    'fileName': fileName,
    'path': path,
    'receivedBytes': receivedBytes,
    'totalBytes': totalBytes,
    'status': status.name,
    'error': error,
  };
  factory BrowserDownload.fromJson(Map<String, dynamic> json) =>
      BrowserDownload(
        id: json['id'] as String,
        url: json['url'] as String,
        fileName: json['fileName'] as String,
        path: json['path'] as String?,
        receivedBytes: json['receivedBytes'] as int? ?? 0,
        totalBytes: json['totalBytes'] as int? ?? -1,
        status: BrowserDownloadStatus.values.firstWhere(
          (status) =>
              status.name == json['status'] &&
              status != BrowserDownloadStatus.downloading,
          orElse: () => BrowserDownloadStatus.cancelled,
        ),
        error: json['error'] as String?,
      );
}
