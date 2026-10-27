import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// The wrapper does not expose path-handler disposal; own its Android channel.
// ignore: depend_on_referenced_packages
import 'package:flutter_inappwebview_android/flutter_inappwebview_android.dart'
    show AndroidPathHandler;
import '../../../features/browser/models/browser_models.dart';
import 'browser_engine.dart';
import 'browser_failure.dart';
import 'browser_download_cookies.dart';
import 'browser_favicon_loader.dart';
import 'browser_native_scroll_observer.dart';
import 'browser_scroll_observer.dart';
import 'browser_workspace_resources.dart';
import 'browser_windows_environment.dart';

const browserHistoryHandlerName = 'kelivoBrowserHistory';
const browserHistoryDocumentScript =
    'window.__kelivoBrowserHistoryDocument ?? null';

/// URL KVO precedes WebKit's same-document list update, and same-URL states do
/// not trigger it at all. Signal once after the History API/event task finishes;
/// Dart still reads the authoritative native list, never flags supplied by JS.
const browserHistoryObserverScript = r'''
(() => {
  if (window.__kelivoBrowserHistoryInstalled) return;
  window.__kelivoBrowserHistoryInstalled = true;
  const state = window.__kelivoBrowserHistoryDocument = {
    id: String(performance.timeOrigin) + ':' + Math.random().toString(36).slice(2),
    traversal: 0
  };
  let scheduled = false;
  const notify = () => {
    if (scheduled) return;
    scheduled = true;
    setTimeout(() => {
      scheduled = false;
      const bridge = window.flutter_inappwebview;
      if (bridge && typeof bridge.callHandler === 'function') {
        bridge.callHandler('kelivoBrowserHistory').catch(() => {});
      }
    }, 0);
  };
  const traversed = (event) => {
    if (!event.isTrusted) return;
    state.traversal++;
    notify();
  };
  addEventListener('popstate', traversed);
  addEventListener('hashchange', traversed);
  addEventListener('flutterInAppWebViewPlatformReady', notify, {once: true});
  for (const name of ['pushState', 'replaceState']) {
    const original = history[name];
    history[name] = function(...args) {
      const result = Reflect.apply(original, this, args);
      notify();
      return result;
    };
  }
})();
''';

/// A native view begins headless and is transferred to the visible host once.
/// The keep-alive token then preserves it when the browser panel is dismissed.
class NativeBrowserEngine implements BrowserEngine {
  NativeBrowserEngine._({
    required this.tab,
    required this.settings,
    required this.onChanged,
    required this.onDownload,
    required this.onNewWindow,
    required this.isAgentActive,
  }) : _ownerSessionId = tab.ownerSessionId;
  final BrowserTab tab;
  String? _ownerSessionId;
  int _workspaceEpoch = 0;
  bool get hasWorkspaceScope => _workspace != null;
  void updateOwnerSession(String sessionId) {
    _workspaceEpoch++;
    _ownerSessionId = sessionId;
    _workspace?.close();
  }

  BrowserSettings settings;
  final void Function(BrowserPageState) onChanged;
  final void Function(String, String?) onDownload;
  final Future<bool> Function(String?, int) onNewWindow;
  final bool Function() isAgentActive;
  final InAppWebViewKeepAlive _keepAlive = InAppWebViewKeepAlive();
  // WebView2's plugin does not implement the native find controller/channel.
  // Use Chromium's find operation there without preventing WebView creation.
  final FindInteractionController? _findController =
      defaultTargetPlatform == TargetPlatform.windows
      ? null
      : FindInteractionController();
  String _findText = '';
  BrowserWorkspaceScope? _workspace;
  WebViewAssetLoader? _workspaceLoader;
  _WorkspacePathHandler? _workspacePathHandler;
  final Completer<InAppWebViewController> _created = Completer();
  HeadlessInAppWebView? _headless;
  WebViewEnvironment? _environment;
  InAppWebViewController? _controller;
  bool _disposed = false;
  Future<void> _dialogBridgeReady = Future<void>.value();
  Completer<void>? _viewReady;
  bool _visible = true;
  Future<void> _visibilityUpdate = Future<void>.value();

  @override
  Future<void> get viewReady => _viewReady?.future ?? Future<void>.value();
  bool _converted = false;
  bool get _usesHybridComposition =>
      defaultTargetPlatform == TargetPlatform.android &&
      (settings.surfaceStyle == BrowserSurfaceStyle.solid ||
          (settings.surfaceStyle == BrowserSurfaceStyle.liquid &&
              !ui.ImageFilter.isShaderFilterSupported));
  late final _composition = ValueNotifier<bool>(_usesHybridComposition);
  String? _defaultUserAgent;
  String? _downloadUserAgent;
  String? _renderedDocumentUrl;
  bool _awaitingRenderedLoadStart = false;
  bool _replacingRenderedDocument = false;
  bool _renderedDocumentLoaded = false;
  Completer<void>? _navigation;
  Completer<void>? _commit;
  Future<void>? _domReady;
  Future<void> _redirectUpdate = Future<void>.value();
  bool _hasServerRedirect = false;
  BrowserFailure? _loadFailure;
  String? _navigationUrl;
  int _navigationGeneration = 0;
  int _historyRevision = 0;
  int _latestHistoryRevision = 0;
  int _historyCommandEpoch = 0;
  Future<void> _historyCommands = Future<void>.value();
  ({int generation, int index, int length, Completer<void> done})?
  _historyTraversal;
  ({int generation, int index, int length, String id, int traversal})?
  _historyDocument;
  ({int generation, String document})? _faviconRequest;
  late final _scrollObserver = BrowserScrollObserver(
    readDocumentId: () =>
        _webView.evaluateJavascript(source: browserScrollIdentityScript),
    onUpdate: (state) => _emit(BrowserPageState(scroll: state)),
  );
  late final _nativeScrollObserver = BrowserNativeScrollObserver(
    onUpdate: (state) => _emit(BrowserPageState(scroll: state)),
  );
  UnmodifiableListView<UserScript> get _userScripts => UnmodifiableListView([
    UserScript(
      groupName: 'kelivo-browser-identity',
      source: browserTabUserScriptMarker(tab.id),
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      forMainFrameOnly: true,
    ),
    UserScript(
      groupName: 'kelivo-browser-history',
      source: browserHistoryObserverScript,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      forMainFrameOnly: true,
    ),
    if (!Platform.isIOS)
      UserScript(
        groupName: 'kelivo-browser-scroll',
        source: browserScrollObserverScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: true,
      ),
  ]);
  void _beginNavigation({bool fromHistory = false}) {
    if (!fromHistory) _historyCommandEpoch++;
    _finishHistoryTraversal();
    _historyDocument = null;
    _navigationGeneration++;
    if (Platform.isIOS) {
      _nativeScrollObserver.reset();
    } else {
      _scrollObserver.invalidate();
    }
    final previous = _navigation;
    if (previous != null && !previous.isCompleted) {
      previous.completeError(StateError('browser_navigation_superseded'));
    }
    _navigation = Completer<void>();
    _navigation!.future.ignore();
    if (_commit != null && !_commit!.isCompleted) {
      _commit!.completeError(StateError('browser_navigation_superseded'));
    }
    _commit = Completer<void>();
    _commit!.future.ignore();
    _domReady = null;
    _redirectUpdate = Future<void>.value();
    _hasServerRedirect = false;
    _loadFailure = null;
  }

  static Future<BrowserEngine> create({
    required BrowserTab tab,
    required BrowserSettings settings,
    required void Function(BrowserPageState) onChanged,
    required void Function(String, String?) onDownload,
    required Future<bool> Function(String?, int) onNewWindow,
    required bool Function() isAgentActive,
    Future<WebViewEnvironment?> Function()? webViewEnvironment,
  }) async {
    final engine = NativeBrowserEngine._(
      tab: tab,
      settings: settings,
      onChanged: onChanged,
      onDownload: onDownload,
      onNewWindow: onNewWindow,
      isAgentActive: isAgentActive,
    );
    try {
      await engine._initialize(webViewEnvironment);
      return engine;
    } catch (error, stack) {
      try {
        await engine.dispose();
      } catch (cleanupError) {
        debugPrint('Browser initialization cleanup failed: $cleanupError');
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  InAppWebViewSettings get _viewSettings => InAppWebViewSettings(
    // Glass needs a texture for Flutter backdrop sampling. Solid controls can
    // use the native hierarchy, avoiding a second raster/composition pass on
    // each WebView scroll frame.
    useHybridComposition: _usesHybridComposition,
    javaScriptEnabled: true,
    resourceCustomSchemes: const ['kelivo'],
    webViewAssetLoader: _workspaceLoader,
    useShouldOverrideUrlLoading: true,
    useOnDownloadStart: true,
    supportMultipleWindows: true,
    javaScriptCanOpenWindowsAutomatically: false,
    mediaPlaybackRequiresUserGesture: true,
    allowsInlineMediaPlayback: true,
    allowsBackForwardNavigationGestures: true,
    allowFileAccess: false,
    allowContentAccess: false,
    allowFileAccessFromFileURLs: false,
    allowUniversalAccessFromFileURLs: false,
    isInspectable: kDebugMode,
    preferredContentMode: settings.desktopMode
        ? UserPreferredContentMode.DESKTOP
        : UserPreferredContentMode.MOBILE,
    userAgent: settings.customUserAgent.isNotEmpty
        ? settings.customUserAgent
        : settings.desktopMode &&
              Platform.isAndroid &&
              _defaultUserAgent != null
        ? _defaultUserAgent!
              .replaceFirst(
                RegExp(r'\(Linux; Android[^)]+\)'),
                '(X11; Linux x86_64)',
              )
              .replaceAll(' Mobile', '')
        : Platform.isAndroid
        ? _defaultUserAgent
        : '',
  );

  Future<void> _initialize(
    Future<WebViewEnvironment?> Function()? webViewEnvironment,
  ) async {
    _beginNavigation();
    _navigationUrl = tab.url;
    if (webViewEnvironment != null) {
      _environment = await webViewEnvironment();
    } else if (Platform.isWindows) {
      _environment = await BrowserWindowsEnvironment.instance.get();
    }
    if (Platform.isAndroid) {
      _defaultUserAgent = await InAppWebViewController.getDefaultUserAgent();
    }
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    final viewport = view == null
        ? const Size(1024, 768)
        : view.physicalSize / view.devicePixelRatio;
    // A new WebView already owns an empty document. Loading about:blank again
    // races the first loadData: its late stop can be mistaken for the rendered
    // document's completion before that document's start callback arrives.
    final initialUrl = await _prepareWorkspaceUrl(tab.url);
    final initialRequest = tab.windowId == null && tab.url != 'about:blank'
        ? URLRequest(url: WebUri(initialUrl))
        : null;
    _headless = HeadlessInAppWebView(
      webViewEnvironment: _environment,
      initialSize: Size(
        viewport.width.clamp(320, 1280),
        viewport.height.clamp(320, 1024),
      ),
      windowId: tab.windowId,
      initialUrlRequest: initialRequest,
      initialSettings: _viewSettings,
      initialUserScripts: _userScripts,
      findInteractionController: _findController,
      onWebViewCreated: _onCreated,
      onLoadStart: _onLoadStart,
      onLoadStop: _onLoadStop,
      onPageCommitVisible: _onPageCommit,
      onDidReceiveServerRedirectForProvisionalNavigation: _onRedirect,
      onUpdateVisitedHistory: _onHistory,
      onTitleChanged: _onTitle,
      onProgressChanged: _onProgress,
      onReceivedError: _onError,
      onReceivedHttpError: _onHttpError,
      shouldOverrideUrlLoading: _onNavigation,
      onCreateWindow: _onCreateWindow,
      onCloseWindow: (_) => _emit(const BrowserPageState(closeRequested: true)),
      onDownloadStartRequest: _onDownload,
      onLoadResourceWithCustomScheme: _onWorkspaceResource,
      onPermissionRequest: _onPermission,
      onJsAlert: _onAlert,
      onJsConfirm: _onConfirm,
      onJsPrompt: _onPrompt,
      onRenderProcessGone: (_, detail) => _onCrash(),
      onWebContentProcessDidTerminate: (_) => _onCrash(),
    );
    await _headless!.run().timeout(const Duration(seconds: 20));
    await _created.future.timeout(const Duration(seconds: 20));
    await _dialogBridgeReady;
    if (tab.windowId == null && initialRequest == null) {
      _emit(
        const BrowserPageState(
          url: 'about:blank',
          title: '',
          isLoading: false,
          progress: 1,
        ),
      );
      _completeNavigation();
    }
  }

  void _emit(BrowserPageState state) {
    if (!_disposed) onChanged(state);
  }

  void _onCreated(InAppWebViewController controller) {
    final previous = _controller;
    // The widget disposes its own Dart controller even when the native view
    // is kept alive. Keep a separate controller and callback handler for
    // background Agent operations and popup handoff.
    _controller = InAppWebViewController.fromPlatformCreationParams(
      params: controller.platform.params,
    );
    previous?.dispose(isKeepAlive: true);
    _controller!.addJavaScriptHandler(
      handlerName: browserHistoryHandlerName,
      callback: (_) async {
        if (!_disposed) await _refreshHistory(_webView);
      },
    );
    if (Platform.isIOS) {
      unawaited(_installScrollObserver());
    } else {
      _controller!.addJavaScriptHandler(
        handlerName: browserScrollHandlerName,
        callback: _scrollObserver.handle,
      );
    }
    if (Platform.isWindows) {
      _dialogBridgeReady = _installWindowsDialogs(_controller!);
    }
    if (!_created.isCompleted) _created.complete(_controller);
  }

  String publicUrl(String url) => _workspace?.publicUrl(url) ?? url;

  void _dialogEvent(String type, String? message, bool accept) {
    final text = message ?? '';
    _emit(
      BrowserPageState(
        agentEvent: {
          'type': 'dialog',
          'dialog': type,
          'message': text.length > 512 ? text.substring(0, 512) : text,
          'response': accept ? 'accepted' : 'dismissed',
        },
      ),
    );
  }

  Future<void> _installWindowsDialogs(InAppWebViewController controller) async {
    // CDP leaves the native human-facing dialogs intact. ScriptDialogOpening
    // would require disabling every default dialog (including manual prompts).
    await controller.addDevToolsProtocolEventListener(
      eventName: 'Page.javascriptDialogOpening',
      callback: (dynamic data) async {
        if (_disposed || !isAgentActive() || data is! Map) return;
        final type = data['type']?.toString() ?? 'confirm';
        final accept = type == 'alert';
        try {
          await controller.callDevToolsProtocolMethod(
            methodName: 'Page.handleJavaScriptDialog',
            parameters: {'accept': accept},
          );
          if (!_disposed) {
            _dialogEvent(type, data['message']?.toString(), accept);
          }
        } catch (_) {
          // A human may already have dismissed it; never retry a confirmation.
        }
      },
    );
    await controller.callDevToolsProtocolMethod(methodName: 'Page.enable');
  }

  void _onLoadStart(InAppWebViewController controller, WebUri? url) {
    if (_renderedDocumentUrl != null &&
        url?.scheme == 'data' &&
        (_renderedDocumentLoaded || _replacingRenderedDocument)) {
      // loadData can report this alias after its about:blank completion or
      // repeat it when the native view is reattached. It cannot be a new
      // document: arbitrary data: navigation is rejected by our policy.
      // Leave a pending real navigation intact, including a same-URL POST.
      return;
    }
    if (_navigation == null ||
        _navigation!.isCompleted ||
        _commit?.isCompleted == true) {
      _beginNavigation();
    }
    _navigationUrl = _pageUrl(url) ?? _navigationUrl;
    if (Platform.isIOS) {
      _nativeScrollObserver.reset();
    } else {
      _scrollObserver.invalidate();
    }
    final replaced =
        _renderedDocumentUrl != null &&
        (_replacingRenderedDocument || _renderedDocumentLoaded);
    if (replaced) _renderedDocumentUrl = null;
    _renderedDocumentLoaded = false;
    _replacingRenderedDocument = false;
    _awaitingRenderedLoadStart = false;
    _emit(
      BrowserPageState(
        url: _pageUrl(url),
        isLoading: true,
        progress: 0,
        replacesRenderedDocument: replaced,
      ),
    );
  }

  String? _pageUrl(WebUri? url) {
    if (url != null &&
        (url.scheme == 'chrome-error' ||
            url.scheme == 'chromewebdata' ||
            url.toString().startsWith('about:neterror'))) {
      return _navigationUrl;
    }
    final value = url == null
        ? null
        : (_workspace?.publicUrl(url.toString()) ?? url.toString());
    final documentUrl = _renderedDocumentUrl;
    if (documentUrl == null || url == null) return value;
    // Android can report loadData's synthetic document as a data: URL even
    // with an about:blank base. It is still the rendered document, not a new
    // navigation: exposing data: would discard its retained HTML and prevent
    // restoring the tab. Only an explicit loadHtml owns this normalization.
    if (url.scheme == 'data') return documentUrl;
    if ((url.scheme == 'http' || url.scheme == 'https') &&
        url.replace(fragment: '').toString() !=
            Uri.parse(documentUrl).replace(fragment: '').toString()) {
      _renderedDocumentUrl = null;
    }
    return value;
  }

  bool _isRenderedUrl(WebUri url) {
    final documentUrl = _renderedDocumentUrl;
    if (documentUrl == null) return false;
    return url.scheme == 'data' || url.toString() == documentUrl;
  }

  Future<void> _onLoadStop(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    if (_disposed) return;
    final generation = _navigationGeneration;
    final historyRevision = ++_historyRevision;
    final navigation = _navigation;
    final current = await controller.getUrl();
    if (url != null &&
        current != null &&
        current.toString() != url.toString()) {
      // Android's callback can use about:blank while getUrl returns the data:
      // representation of the same loadData document. Reject unrelated stale
      // callbacks, but allow this explicit render alias once its DOM is ready.
      if (!_isRenderedUrl(url) || !_isRenderedUrl(current)) return;
      final readiness = await controller.evaluateJavascript(
        source: 'document.readyState',
      );
      if (readiness != 'complete') return;
    }
    if (_disposed || generation != _navigationGeneration) return;
    // Only a validated load-stop supersedes another history read. A late stop
    // from the previous URL must not invalidate the current document's query.
    if (historyRevision > _latestHistoryRevision) {
      _latestHistoryRevision = historyRevision;
    }
    final values = await Future.wait<Object?>([
      controller.getTitle(),
      _readHistory(controller),
    ]);
    if (_disposed || generation != _navigationGeneration) return;
    _awaitingRenderedLoadStart = false;
    _renderedDocumentLoaded = _renderedDocumentUrl != null;
    final history = _acceptHistory(
      values[1] as ({int index, int length})?,
      generation: generation,
      revision: historyRevision,
    );
    _emit(
      BrowserPageState(
        url: historyRevision == _historyRevision ? _pageUrl(url) : null,
        title: values[0] as String?,
        isLoading: false,
        progress: 1,
        canGoBack: history == null ? null : history.index > 0,
        canGoForward: history == null
            ? null
            : history.index + 1 < history.length,
        completedNavigation: _loadFailure == null,
        error: _loadFailure?.message,
      ),
    );
    if (identical(navigation, _navigation)) _completeNavigation();
    _historyDocument = null;
    if (!Platform.isIOS) _scrollObserver.allowCurrentDocument();
    unawaited(_installScrollObserver());
    unawaited(_loadFavicon());
  }

  Future<void> _loadFavicon() async {
    final generation = _navigationGeneration;
    try {
      final controller = _webView;
      final url = (await controller.getUrl())?.toString();
      if (_disposed ||
          generation != _navigationGeneration ||
          url == null ||
          browserFaviconSite(url) == null) {
        return;
      }
      final document = browserFaviconDocument(url);
      final request = (generation: generation, document: document);
      if (_faviconRequest == request) return;
      _faviconRequest = request;
      final result = await controller
          .callAsyncJavaScript(
            functionBody: 'return await ($browserFaviconScript);',
          )
          .timeout(const Duration(seconds: 8));
      if (_disposed ||
          generation != _navigationGeneration ||
          _faviconRequest != request ||
          result?.error != null) {
        return;
      }
      final value = result?.value;
      if (value is! Map || value['pageUrl'] != document) return;
      final bytes = decodeBrowserFavicon(value['png']);
      if (bytes == null) return;
      final current = (await controller.getUrl())?.toString();
      if (_disposed ||
          generation != _navigationGeneration ||
          _faviconRequest != request ||
          current == null ||
          browserFaviconDocument(current) != document) {
        return;
      }
      _emit(BrowserPageState(favicon: bytes, faviconPageUrl: current));
    } catch (_) {
      // CSP, CORS, unsupported image data, and document replacement use the
      // local glyph. Favicon loading must never fail the page or load waiter.
    }
  }

  Future<void> _installScrollObserver() async {
    if (_disposed) return;
    try {
      if (Platform.isIOS) {
        final viewId = _controller?.getViewId();
        if (viewId == null) return;
        await _nativeScrollObserver.attach(
          viewId: viewId.toString(),
          visible: _visible && _converted,
        );
        return;
      }
      // Also covers engines where document-start injection is best effort and
      // BFCache/native-view transfers. Only document setup queries JavaScript.
      final reconnect = !_scrollObserver.hasDocument;
      await _webView.evaluateJavascript(source: browserScrollObserverScript);
      if (!_disposed && reconnect) {
        await _webView.evaluateJavascript(
          source: 'window.__kelivoBrowserScroll?.reconnect()',
        );
      }
    } catch (_) {
      // A navigation can replace the document while setup is in flight.
    }
  }

  Future<void> _onHistory(
    InAppWebViewController controller,
    WebUri? url,
    bool? reload,
  ) async {
    // URL callbacks arrive in native order. Publish the URL before querying
    // availability so a slower query cannot replay an older SPA location.
    // A newly created WebView can report its previous about:blank document
    // after load-start. URL notifications alone must not change the ownership
    // of an unfinished navigation; commit/redirect events establish that.
    if (_navigation?.isCompleted == true || _navigationUrl == null) {
      _navigationUrl = _pageUrl(url) ?? _navigationUrl;
    }
    _emit(BrowserPageState(url: _pageUrl(url)));
    await _refreshHistory(controller);
    if (_navigation?.isCompleted == true) unawaited(_loadFavicon());
  }

  void _onRedirect(InAppWebViewController controller) {
    _hasServerRedirect = true;
    final generation = _navigationGeneration;
    // WebKit redirects have no second provisional start. Keep the final
    // request address for failures that happen before commit.
    _redirectUpdate = (() async {
      final url = await controller.getUrl();
      if (!_disposed && generation == _navigationGeneration && url != null) {
        _navigationUrl = _pageUrl(url);
      }
    })().catchError((Object _) {});
  }

  Future<void> _onPageCommit(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    final generation = _navigationGeneration;
    if (url == null) return;
    try {
      if (!_isCurrentNavigation(url)) {
        if (!_hasServerRedirect) return;
        final current = await controller.getUrl();
        if (current == null ||
            current.replace(fragment: '') != url.replace(fragment: '')) {
          return;
        }
      }
      if (_disposed ||
          generation != _navigationGeneration ||
          _loadFailure != null) {
        return;
      }
      // The current native document, rather than an earlier history event,
      // owns this commit. Windows additionally filters by NavigationId.
      _navigationUrl = _pageUrl(url);
      if (!(_commit?.isCompleted ?? true)) _commit!.complete();
      unawaited(_refreshHistory(controller));
    } catch (_) {
      // Disposal or a replacing navigation invalidates this notification.
    }
  }

  Future<({int index, int length})?> _readHistory(
    InAppWebViewController controller,
  ) async {
    // One native call reads both directions from the same back-forward list.
    // Two independent boolean queries can straddle a rapid history traversal.
    final history = await controller.getCopyBackForwardList();
    final index = history?.currentIndex;
    final length = history?.list?.length;
    if (index == null ||
        length == null ||
        index < 0 ||
        (length == 0 ? index != 0 : index >= length)) {
      return null;
    }
    return (index: index, length: length);
  }

  ({int index, int length})? _acceptHistory(
    ({int index, int length})? history, {
    required int generation,
    required int revision,
  }) {
    if (_disposed ||
        generation != _navigationGeneration ||
        revision != _latestHistoryRevision) {
      return null;
    }
    final pending = _historyTraversal;
    if (pending != null && pending.generation == generation) {
      // goBack/goForward acknowledge scheduling, not the new current item.
      // Retain availability until WebKit actually moves or commits the item.
      if (history == null ||
          (history.index == pending.index &&
              history.length == pending.length)) {
        return null;
      }
      _finishHistoryTraversal();
      // Hash/History API traversal and BFCache can keep the same DOM without
      // a load-stop callback. The native history item has now moved, so allow
      // that document to re-handshake after _beginNavigation invalidated it.
      if (!Platform.isIOS) _scrollObserver.allowCurrentDocument();
      unawaited(_installScrollObserver());
    }
    return history;
  }

  void _finishHistoryTraversal() {
    final pending = _historyTraversal;
    _historyTraversal = null;
    if (pending != null && !pending.done.isCompleted) pending.done.complete();
  }

  Future<void> _refreshHistory(InAppWebViewController controller) async {
    if (_disposed) return;
    final generation = _navigationGeneration;
    final revision = ++_historyRevision;
    _latestHistoryRevision = revision;
    final read = await _readHistory(controller);
    final history = _acceptHistory(
      read,
      generation: generation,
      revision: revision,
    );
    if (history == null) return;
    _emit(
      BrowserPageState(
        canGoBack: history.index > 0,
        canGoForward: history.index + 1 < history.length,
      ),
    );
    await _completeDocumentHistory(controller, history);
  }

  Future<({String id, int traversal})?> _readHistoryDocument(
    InAppWebViewController controller,
  ) async {
    Object? state;
    try {
      state = await controller.evaluateJavascript(
        source: browserHistoryDocumentScript,
      );
    } on PlatformException {
      // A renderer being replaced may not accept JavaScript yet. Native
      // history navigation must remain usable and can complete via load-stop.
      return null;
    }
    if (state is! Map || state['id'] is! String) {
      return null;
    }
    // WKWebView boxes JavaScript numbers as Float64, including whole numbers.
    final traversal = state['traversal'];
    if (traversal is! num ||
        !traversal.isFinite ||
        traversal < 0 ||
        traversal != traversal.truncateToDouble()) {
      return null;
    }
    return (id: state['id'] as String, traversal: traversal.toInt());
  }

  Future<void> _completeDocumentHistory(
    InAppWebViewController controller,
    ({int index, int length}) history,
  ) async {
    final pending = _historyDocument;
    if (pending == null ||
        pending.generation != _navigationGeneration ||
        (pending.index == history.index && pending.length == history.length)) {
      return;
    }
    final document = await _readHistoryDocument(controller);
    if (_disposed ||
        pending != _historyDocument ||
        document?.id != pending.id ||
        document!.traversal <= pending.traversal) {
      return;
    }
    // An actual popstate/hashchange in the original document confirms a
    // same-document traversal. URL KVO/commit alone may precede a full load.
    _historyDocument = null;
    _completeNavigation();
    _emit(
      const BrowserPageState(
        isLoading: false,
        progress: 1,
        completedNavigation: true,
      ),
    );
  }

  void _onTitle(InAppWebViewController controller, String? title) {
    _emit(BrowserPageState(title: title));
  }

  void _onProgress(InAppWebViewController controller, int progress) {
    _emit(BrowserPageState(progress: progress / 100));
  }

  Future<void> _onError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) async {
    final generation = _navigationGeneration;
    await _redirectUpdate;
    if (_disposed || generation != _navigationGeneration) return;
    // WebKit reports a superseded/back/stop navigation as URLError.cancelled
    // (-999). The plugin also maps WebView2's cancellation to this type. It
    // belongs to the cancelled request, not the current page or load waiter;
    // an explicit stop() already settles its own loading state below.
    if (error.type == WebResourceErrorType.CANCELLED ||
        !_isCurrentNavigation(request.url) ||
        request.isForMainFrame != true) {
      return;
    }
    final type = error.type.toString().toLowerCase();
    final code = type.contains('timeout') || type.contains('timed_out')
        ? 'browser_connection_timeout'
        : type.contains('aborted')
        ? 'browser_connection_aborted'
        : type.contains('host_lookup') || type.contains('host_name')
        ? 'browser_name_not_resolved'
        : type.contains('ssl') || type.contains('certificate')
        ? 'browser_certificate_error'
        : 'browser_navigation_failed';
    _failNavigation(
      BrowserFailure(
        code,
        'The page could not be loaded ($code).',
        'Check the connection or address, then open another page in this tab. Do not repeat form submissions automatically.',
      ),
    );
    if (!Platform.isIOS) _scrollObserver.allowCurrentDocument();
    unawaited(_installScrollObserver());
  }

  bool _isCurrentNavigation(WebUri? url) {
    if (_disposed || url == null || _navigationUrl == null) return false;
    final actual = _isRenderedUrl(url)
        ? _renderedDocumentUrl!
        : publicUrl(url.toString());
    return Uri.parse(actual).replace(fragment: '') ==
        Uri.parse(_navigationUrl!).replace(fragment: '');
  }

  void _failNavigation(BrowserFailure failure) {
    _loadFailure = failure;
    _historyDocument = null;
    _emit(BrowserPageState(isLoading: false, error: failure.message));
    if (!(_commit?.isCompleted ?? true)) _commit!.completeError(failure);
    if (!(_navigation?.isCompleted ?? true)) {
      _navigation!.completeError(failure);
    }
  }

  void _completeNavigation() {
    if (_loadFailure != null) return;
    if (!(_commit?.isCompleted ?? true)) _commit!.complete();
    if (!(_navigation?.isCompleted ?? true)) _navigation!.complete();
  }

  void _onHttpError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceResponse response,
  ) {
    if (request.isForMainFrame == true &&
        _isCurrentNavigation(request.url) &&
        (response.statusCode ?? 0) >= 400) {
      _failNavigation(
        BrowserFailure(
          'browser_http_error',
          'The server returned HTTP ${response.statusCode}.',
          'Inspect the response page or check the address before retrying.',
        ),
      );
    }
  }

  Future<NavigationActionPolicy> _onNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final url = action.request.url;
    if (url == null) return NavigationActionPolicy.CANCEL;
    if (_workspace?.owns(url) == true) return NavigationActionPolicy.ALLOW;
    if (url.toString() == 'about:blank' ||
        url.scheme == 'http' ||
        url.scheme == 'https') {
      if (action.isForMainFrame && _renderedDocumentUrl != null) {
        // Some backends consult policy for loadHtml's first load at its base
        // URL. That is initialization, not a replacement. Subsequent links
        // can load a real document at exactly the same URL; URL comparison
        // alone cannot distinguish those from the retained synthetic HTML.
        final initialRender =
            _awaitingRenderedLoadStart &&
            url.replace(fragment: '').toString() ==
                Uri.parse(
                  _renderedDocumentUrl!,
                ).replace(fragment: '').toString();
        if (!initialRender) _replacingRenderedDocument = true;
      }
      return NavigationActionPolicy.ALLOW;
    }
    _emit(BrowserPageState(error: 'Unsupported navigation: ${url.scheme}'));
    return NavigationActionPolicy.CANCEL;
  }

  Future<bool> _onCreateWindow(
    InAppWebViewController controller,
    CreateWindowAction action,
  ) async {
    final url = action.request.url;
    if (url != null &&
        url.toString() != 'about:blank' &&
        url.scheme != 'http' &&
        url.scheme != 'https' &&
        _workspace?.owns(url) != true) {
      return false;
    }
    return onNewWindow(
      url == null
          ? null
          : (_workspace?.publicUrl(url.toString()) ?? url.toString()),
      action.windowId,
    );
  }

  void _onDownload(
    InAppWebViewController controller,
    DownloadStartRequest request,
  ) {
    onDownload(request.url.toString(), request.suggestedFilename);
  }

  Future<PermissionResponse> _onPermission(
    InAppWebViewController controller,
    PermissionRequest request,
  ) async => PermissionResponse(
    resources: request.resources,
    action: PermissionResponseAction.DENY,
  );
  Future<JsAlertResponse?> _onAlert(
    InAppWebViewController controller,
    JsAlertRequest request,
  ) async {
    if (!isAgentActive()) return null;
    _dialogEvent('alert', request.message, true);
    return JsAlertResponse(
      handledByClient: true,
      action: JsAlertResponseAction.CONFIRM,
    );
  }

  Future<JsConfirmResponse?> _onConfirm(
    InAppWebViewController controller,
    JsConfirmRequest request,
  ) async {
    if (!isAgentActive()) return null;
    _dialogEvent('confirm', request.message, false);
    return JsConfirmResponse(
      handledByClient: true,
      action: JsConfirmResponseAction.CANCEL,
    );
  }

  Future<JsPromptResponse?> _onPrompt(
    InAppWebViewController controller,
    JsPromptRequest request,
  ) async {
    if (!isAgentActive()) return null;
    _dialogEvent('prompt', request.message, false);
    return JsPromptResponse(
      handledByClient: true,
      action: JsPromptResponseAction.CANCEL,
    );
  }

  void _onCrash() {
    if (!(_commit?.isCompleted ?? true)) {
      _commit!.completeError(BrowserFailure.renderer);
    }
    _loadFailure = BrowserFailure.renderer;
    _historyDocument = null;
    _historyCommandEpoch++;
    _finishHistoryTraversal();
    if (Platform.isIOS) {
      _nativeScrollObserver.reset();
    } else {
      _scrollObserver.invalidate();
    }
    if (!(_navigation?.isCompleted ?? true)) {
      _navigation!.completeError(BrowserFailure.renderer);
    }
    _emit(
      const BrowserPageState(
        isLoading: false,
        error: 'browser_renderer_terminated',
        rendererTerminated: true,
      ),
    );
  }

  @override
  Widget buildView() {
    final initialReady = _viewReady = Completer<void>();
    Widget? host;
    bool? hostComposition;
    return ValueListenableBuilder<bool>(
      valueListenable: _composition,
      builder: (_, hybrid, _) {
        if (host == null || hostComposition != hybrid) {
          final ready = host == null
              ? initialReady
              : (_viewReady = Completer<void>());
          hostComposition = hybrid;
          host = _buildNativeView(hybrid, ready);
        }
        return host!;
      },
    );
  }

  Widget _buildNativeView(bool hybrid, Completer<void> ready) {
    return InAppWebView(
      key: ValueKey(hybrid),
      webViewEnvironment: _environment,
      initialSettings: _viewSettings,
      initialUserScripts: _userScripts,
      keepAlive: _keepAlive,
      headlessWebView: _headless,
      findInteractionController: _findController,
      onWebViewCreated: (controller) {
        _converted = true;
        _headless = null;
        _onCreated(controller);
        if (!ready.isCompleted) ready.complete();
      },
      onLoadStart: _onLoadStart,
      onLoadStop: _onLoadStop,
      onPageCommitVisible: _onPageCommit,
      onDidReceiveServerRedirectForProvisionalNavigation: _onRedirect,
      onUpdateVisitedHistory: _onHistory,
      onTitleChanged: _onTitle,
      onProgressChanged: _onProgress,
      onReceivedError: _onError,
      onReceivedHttpError: _onHttpError,
      shouldOverrideUrlLoading: _onNavigation,
      onCreateWindow: _onCreateWindow,
      onCloseWindow: (_) => _emit(const BrowserPageState(closeRequested: true)),
      onDownloadStartRequest: _onDownload,
      onLoadResourceWithCustomScheme: _onWorkspaceResource,
      onPermissionRequest: _onPermission,
      onJsAlert: _onAlert,
      onJsConfirm: _onConfirm,
      onJsPrompt: _onPrompt,
      onRenderProcessGone: (_, detail) => _onCrash(),
      onWebContentProcessDidTerminate: (_) => _onCrash(),
    );
  }

  InAppWebViewController get _webView =>
      _controller ?? (throw StateError('browser_engine_not_ready'));
  Future<String> _prepareWorkspaceUrl(String url) async {
    if (!BrowserWorkspaceResources.isWorkspaceUrl(url)) return url;
    final epoch = _workspaceEpoch;
    final owner = _ownerSessionId;
    void checkOwner() {
      if (_disposed || epoch != _workspaceEpoch) {
        throw StateError('browser_tab_owner_changed');
      }
    }

    final next = await BrowserWorkspaceResources.instance.scope(owner);
    try {
      checkOwner();
      await next.file(Uri.parse(url));
      checkOwner();
      if (_workspace?.host == next.host) {
        next.close();
      } else {
        _workspace?.close();
        _workspace = next;
        if (Platform.isAndroid) {
          _workspacePathHandler?.close();
          _workspacePathHandler = _WorkspacePathHandler(next);
          _workspaceLoader = WebViewAssetLoader(
            domain: next.host,
            httpAllowed: false,
            pathHandlers: [_workspacePathHandler!],
          );
          if (_controller != null) {
            await _webView.setSettings(settings: _viewSettings);
            checkOwner();
          }
        }
      }
      return _workspace!
          .internalUrl(url, android: Platform.isAndroid)
          .toString();
    } catch (_) {
      next.close();
      if (identical(_workspace, next)) _workspace = null;
      rethrow;
    }
  }

  Future<CustomSchemeResponse?> _onWorkspaceResource(
    InAppWebViewController controller,
    WebResourceRequest request,
  ) async {
    final scope = _workspace;
    final uri = Uri.tryParse(request.url.toString());
    if (scope == null ||
        uri == null ||
        uri.scheme != 'kelivo' ||
        !scope.owns(uri) ||
        request.method != 'GET') {
      return null;
    }
    final resource = await scope.read(uri);
    if (resource == null) return null;
    return CustomSchemeResponse(
      data: resource.bytes,
      contentType: resource.mime,
      contentEncoding: 'utf-8',
    );
  }

  @override
  Future<void> navigate(String url) async {
    final epoch = _workspaceEpoch;
    url = await _prepareWorkspaceUrl(url);
    if (_disposed || epoch != _workspaceEpoch) {
      throw StateError('browser_tab_owner_changed');
    }
    _renderedDocumentUrl = null;
    _awaitingRenderedLoadStart = false;
    _replacingRenderedDocument = false;
    _renderedDocumentLoaded = false;
    _beginNavigation();
    _navigationUrl = publicUrl(url);
    await _webView.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  @override
  Future<void> loadHtml(String html, {String? baseUrl}) async {
    _renderedDocumentUrl = baseUrl ?? 'about:blank';
    _navigationUrl = _renderedDocumentUrl;
    _awaitingRenderedLoadStart = true;
    _replacingRenderedDocument = false;
    _renderedDocumentLoaded = false;
    _beginNavigation();
    try {
      await _webView.loadData(
        data: html,
        baseUrl: baseUrl == null ? null : WebUri(baseUrl),
      );
    } catch (_) {
      _renderedDocumentUrl = null;
      _awaitingRenderedLoadStart = false;
      rethrow;
    }
  }

  @override
  Future<void> back() => _traverseHistory(-1);

  @override
  Future<void> forward() => _traverseHistory(1);

  Future<void> _traverseHistory(int direction) {
    final commandEpoch = _historyCommandEpoch;
    final issued = Completer<void>();
    final operation = _historyCommands.then((_) async {
      if (_disposed || commandEpoch != _historyCommandEpoch) return;
      final controller = _webView;
      final before = await _readHistory(controller);
      if (_disposed || commandEpoch != _historyCommandEpoch || before == null) {
        return;
      }
      final target = before.index + direction;
      if (target < 0 || target >= before.length) return;
      final document = await _readHistoryDocument(controller);
      if (_disposed || commandEpoch != _historyCommandEpoch) return;
      _replacingRenderedDocument = _renderedDocumentUrl != null;
      _beginNavigation(fromHistory: true);
      _navigationUrl = null;
      if (document != null) {
        _historyDocument = (
          generation: _navigationGeneration,
          index: before.index,
          length: before.length,
          id: document.id,
          traversal: document.traversal,
        );
      }
      final pending = (
        generation: _navigationGeneration,
        index: before.index,
        length: before.length,
        done: Completer<void>(),
      );
      _historyTraversal = pending;
      try {
        if (direction < 0) {
          await controller.goBack();
        } else {
          await controller.goForward();
        }
        await _refreshHistory(controller);
        // Public navigation completes once native code accepted the command;
        // only the internal command queue waits for the current item to move.
        // Callers may separately waitForLoad, as for ordinary navigate().
        issued.complete();
        // No polling: URL/commit/load-stop events acknowledge the actual list
        // movement. A suspended process cannot strand queued navigation forever.
        await pending.done.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () async {
            if (_historyTraversal?.done == pending.done) {
              _finishHistoryTraversal();
              await _refreshHistory(controller);
            }
          },
        );
      } finally {
        if (_historyTraversal?.done == pending.done) _finishHistoryTraversal();
      }
    });
    _historyCommands = operation.then<void>(
      (_) {
        if (!issued.isCompleted) issued.complete();
      },
      onError: (Object error, StackTrace stack) {
        if (!issued.isCompleted) issued.completeError(error, stack);
      },
    );
    return issued.future;
  }

  @override
  Future<void> reload() async {
    if (_renderedDocumentUrl != null) {
      // Reloading the synthetic page preserves it; a subsequent independent
      // main-frame load (including POST, which bypasses policy) replaces it.
      _renderedDocumentLoaded = false;
      _awaitingRenderedLoadStart = true;
      _replacingRenderedDocument = false;
    }
    _beginNavigation();
    await _webView.reload();
  }

  @override
  Future<void> stop() async {
    if (!_disposed) {
      _historyDocument = null;
      _historyCommandEpoch++;
      _finishHistoryTraversal();
      await _controller?.stopLoading();
      final stopped = StateError('browser_navigation_stopped');
      if (!(_commit?.isCompleted ?? true)) _commit!.completeError(stopped);
      if (!(_navigation?.isCompleted ?? true)) {
        _navigation!.completeError(stopped);
      }
      _emit(const BrowserPageState(isLoading: false));
      if (!Platform.isIOS) _scrollObserver.allowCurrentDocument();
      unawaited(_installScrollObserver());
    }
  }

  @override
  Future<void> waitForLoad(
    Duration timeout, {
    BrowserLoadStage stage = BrowserLoadStage.load,
  }) async {
    if (stage == BrowserLoadStage.none) return;
    final navigation = _navigation;
    final generation = _navigationGeneration;
    Future<void> wait() async {
      if (stage == BrowserLoadStage.load) {
        await navigation?.future;
        return;
      }
      await _commit?.future;
      if (generation != _navigationGeneration) {
        throw StateError('browser_navigation_superseded');
      }
      if (stage == BrowserLoadStage.commit) return;
      // One event-backed DOM wait per navigation; no permanent polling or new
      // renderer. Commit ensures an old document cannot satisfy a reload wait.
      await (_domReady ??= Future.any<void>([
        (() async {
          final result = await _webView.callAsyncJavaScript(
            functionBody: r"""
            if (document.readyState === 'loading') {
              await new Promise(resolve => document.addEventListener('DOMContentLoaded', resolve, {once:true}));
            }
            return true;
          """,
          );
          if (result?.error != null || result?.value != true) {
            throw const BrowserFailure(
              'browser_document_changed',
              'The document changed while waiting for its DOM.',
              'Inspect the current page and wait again.',
            );
          }
        })(),
        if (navigation != null) navigation.future,
      ]));
    }

    try {
      await wait().timeout(timeout);
    } on TimeoutException {
      throw BrowserFailure.loadTimeout(stage.name);
    }
    if (generation != _navigationGeneration) {
      throw StateError('browser_navigation_superseded');
    }
  }

  @override
  Future<Object?> evaluate(String source, {bool awaitPromise = false}) async {
    if (!awaitPromise) return _webView.evaluateJavascript(source: source);
    final result = await _webView.callAsyncJavaScript(
      functionBody: 'return await ($source);',
    );
    if (result?.error != null) throw StateError(result!.error.toString());
    return result?.value;
  }

  @override
  Future<Uint8List?> screenshot() => _webView.takeScreenshot(
    screenshotConfiguration: ScreenshotConfiguration(
      snapshotWidth: 1280,
      compressFormat: CompressFormat.PNG,
    ),
  );
  @override
  Future<Uint8List?> thumbnail() async {
    InAppWebViewRect? rect;
    var snapshotWidth = 440.0;
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      // These platforms interpret snapshotWidth in logical pixels. Bound the
      // encoded image to 440 physical pixels, including Retina desktop screens.
      snapshotWidth /= WidgetsBinding
          .instance
          .platformDispatcher
          .views
          .first
          .devicePixelRatio;
    }
    if (Platform.isIOS && _headless == null) {
      final viewId = _webView.getViewId();
      final viewport = viewId == null
          ? null
          : await const MethodChannel(
              'app.browser_window',
            ).invokeMapMethod<String, num>(
              'browserSnapshotRect',
              viewId.toString(),
            );
      // A keep-alive view can be detached after the browser page closes.
      // Its own bounds still describe webpage content; only attached views
      // need the native status-bar crop.
      if (viewport != null) {
        // WKSnapshotConfiguration measures width in points; its UIImage uses the
        // hosting screen's scale. Bound the decoded thumbnail to 440 pixels,
        // rather than allocating a 1320px image on every 3x iPhone tab.
        snapshotWidth = 440 / viewport['scale']!.toDouble();
        rect = InAppWebViewRect(
          x: viewport['x']!.toDouble(),
          y: viewport['y']!.toDouble(),
          width: viewport['width']!.toDouble(),
          height: viewport['height']!.toDouble(),
        );
      }
    }
    return _webView.takeScreenshot(
      screenshotConfiguration: ScreenshotConfiguration(
        rect: rect,
        snapshotWidth: snapshotWidth,
        compressFormat: CompressFormat.JPEG,
        quality: 70,
        afterScreenUpdates: false,
      ),
    );
  }

  @override
  Future<void> updateSettings(BrowserSettings settings) async {
    final previousComposition = _composition.value;
    this.settings = settings;
    await _webView.setSettings(settings: _viewSettings);
    _downloadUserAgent = null;
    if (!_disposed && previousComposition != _usesHybridComposition) {
      // Reattach the retained native view with a different platform host. The
      // keep-alive token preserves the document, forms, scroll and history;
      // changing the visual style must not navigate or reload the page.
      _composition.value = _usesHybridComposition;
    }
  }

  @override
  Future<void> find(String text) async {
    if (_findController != null) return _findController.findAll(find: text);
    _findText = text;
    await _webView.evaluateJavascript(
      source: 'window.getSelection()?.removeAllRanges()',
    );
    if (text.isNotEmpty) await findNext(true);
  }

  @override
  Future<void> findNext(bool forward) async {
    if (_findController != null) {
      return _findController.findNext(forward: forward);
    }
    if (_findText.isEmpty) return;
    await _webView.evaluateJavascript(
      source: 'window.find(${jsonEncode(_findText)}, false, ${!forward}, true)',
    );
  }

  @override
  Future<void> clearFind() async {
    if (_findController != null) return _findController.clearMatches();
    _findText = '';
    await _webView.evaluateJavascript(
      source: 'window.getSelection()?.removeAllRanges()',
    );
  }

  @override
  Future<Map<String, String>> downloadHeaders(String url) async {
    final destination = Uri.parse(url);
    final cookies =
        (await CookieManager.instance(
              webViewEnvironment: _environment,
            ).getCookies(url: WebUri(url)))
            .where(
              (cookie) => browserDownloadCookieMatches(cookie, destination),
            )
            .toList();
    // A download may outlive the originating tab and still follow redirects.
    // Cookies are fetched for each destination, while its UA stays stable.
    if (_downloadUserAgent == null && !_disposed) {
      final userAgent = await _controller?.evaluateJavascript(
        source: 'navigator.userAgent',
      );
      if (userAgent is String) _downloadUserAgent = userAgent;
    }
    return {
      if (cookies.isNotEmpty)
        'Cookie': cookies
            .map((cookie) => '${cookie.name}=${cookie.value}')
            .join('; '),
      if (_downloadUserAgent != null) 'User-Agent': _downloadUserAgent!,
    };
  }

  @override
  Future<void> setVisible(bool visible) {
    _visible = visible;
    if (Platform.isIOS) {
      unawaited(_installScrollObserver());
    }
    final update = _visibilityUpdate.then((_) async {
      if (_disposed || _visible != visible) return;
      if (visible) return resume();
      if (Platform.isMacOS || Platform.isIOS || Platform.isAndroid) {
        await _controller?.clearFocus();
      }
      if (!_disposed && !_visible) await pause();
    });
    // A rapid switch back must resume after any older pause, not race it.
    _visibilityUpdate = update.catchError((Object _) {});
    return update;
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    if (Platform.isAndroid) {
      await _controller?.pause();
    } else if (Platform.isIOS || Platform.isMacOS) {
      await _controller?.pauseAllMediaPlayback();
    }
  }

  @override
  Future<void> resume() async {
    if (_disposed) return;
    if (Platform.isAndroid) await _controller?.resume();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _workspace?.close();
    _workspacePathHandler?.close();
    _workspacePathHandler = null;
    _composition.dispose();
    _historyCommandEpoch++;
    _finishHistoryTraversal();
    if (Platform.isIOS) {
      await _nativeScrollObserver.dispose();
    } else {
      _scrollObserver.dispose();
    }
    final disposed = StateError('browser_engine_disposed');
    if (!(_commit?.isCompleted ?? true)) _commit!.completeError(disposed);
    if (!(_navigation?.isCompleted ?? true)) {
      _navigation!.completeError(disposed);
    }
    if (_headless != null) await _headless!.dispose();
    if (_converted) await InAppWebViewController.disposeKeepAlive(_keepAlive);
    _headless = null;
    _controller?.dispose();
    _controller = null;
  }

  static Future<void> clearWebsiteData() async {
    if (Platform.isWindows) {
      throw UnsupportedError('browser_website_data_clear_unsupported');
    }
    await CookieManager.instance().deleteAllCookies();
    await InAppWebViewController.clearAllCache();
    if (Platform.isIOS || Platform.isMacOS) {
      await WebStorageManager.instance().removeDataModifiedSince(
        dataTypes: WebsiteDataType.ALL,
        date: DateTime.fromMillisecondsSinceEpoch(0),
      );
    } else if (Platform.isAndroid) {
      await WebStorageManager.instance().deleteAllData();
    }
  }
}

class _WorkspacePathHandler extends CustomPathHandler {
  _WorkspacePathHandler(this.scope) : super(path: '/');
  final BrowserWorkspaceScope scope;
  void close() => (platform as AndroidPathHandler).dispose();

  @override
  Future<WebResourceResponse?> handle(String path) async {
    // Android's asset loader supplies a decoded path, not a URL. Re-encode it
    // once; the common resolver still rejects dot segments and symlink escapes.
    final uri = Uri(scheme: 'https', host: scope.host, path: '/$path');
    final resource = await scope.read(uri);
    return WebResourceResponse(
      data: resource?.bytes ?? Uint8List(0),
      contentType: resource?.mime ?? 'text/plain',
      contentEncoding: 'utf-8',
      statusCode: resource == null ? 404 : 200,
      reasonPhrase: resource == null ? 'Not Found' : 'OK',
      headers: const {
        'Cache-Control': 'no-store',
        'X-Content-Type-Options': 'nosniff',
      },
    );
  }
}
