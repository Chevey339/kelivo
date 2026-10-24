import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cursor.dart';
import 'enums.dart';

class HistoryChanged {
  final bool canGoBack;
  final bool canGoForward;
  const HistoryChanged(this.canGoBack, this.canGoForward);
}

class WebviewDownloadEvent {
  final WebviewDownloadEventKind kind;
  final String url;
  final String resultFilePath;
  final int bytesReceived;
  final int totalBytesToReceive;
  const WebviewDownloadEvent(
    this.kind,
    this.url,
    this.resultFilePath,
    this.bytesReceived,
    this.totalBytesToReceive,
  );
}

typedef PermissionRequestedDelegate
    = FutureOr<WebviewPermissionDecision> Function(
        String url, WebviewPermissionKind permissionKind, bool isUserInitiated);

typedef ScriptID = String;

/// Attempts to translate a button constant such as [kPrimaryMouseButton]
/// to a [PointerButton]
PointerButton getButton(int value) {
  switch (value) {
    case kPrimaryMouseButton:
      return PointerButton.primary;
    case kSecondaryMouseButton:
      return PointerButton.secondary;
    case kTertiaryButton:
      return PointerButton.tertiary;
    default:
      return PointerButton.none;
  }
}

const String _pluginChannelPrefix = 'io.jns.webview.win';
const MethodChannel _pluginChannel = MethodChannel(_pluginChannelPrefix);

enum WebviewStatus { uninitialized, initializing, ready, failed, disposed }

class WebviewValue {
  const WebviewValue({
    required this.isInitialized,
    this.status = WebviewStatus.uninitialized,
    this.error,
  });

  final bool isInitialized;
  final WebviewStatus status;
  final Object? error;

  WebviewValue copyWith({
    bool? isInitialized,
    WebviewStatus? status,
    Object? error,
  }) {
    return WebviewValue(
      isInitialized: isInitialized ?? this.isInitialized,
      status: status ?? this.status,
      error: error,
    );
  }

  WebviewValue.uninitialized()
      : this(
          isInitialized: false,
        );
}

/// Controls a WebView and provides streams for various change events.
class WebviewController extends ValueNotifier<WebviewValue> {
  /// Explicitly initializes the underlying WebView environment
  /// using  an optional [browserExePath], an optional [userDataPath]
  /// and optional Chromium command line arguments [additionalArguments].
  ///
  /// The environment is shared between all WebviewController instances and
  /// can be initialized only once. Initialization must take place before any
  /// WebviewController is created/initialized.
  ///
  /// Throws [PlatformException] if the environment was initialized before.
  static Future<void> initializeEnvironment(
      {String? userDataPath,
      String? browserExePath,
      String? additionalArguments}) async {
    return _pluginChannel
        .invokeMethod('initializeEnvironment', <String, dynamic>{
      'userDataPath': userDataPath,
      'browserExePath': browserExePath,
      'additionalArguments': additionalArguments
    });
  }

  /// Get the browser version info including channel name if it is not the
  /// WebView2 Runtime.
  /// Returns [null] if the webview2 runtime is not installed.
  static Future<String?> getWebViewVersion() async {
    return _pluginChannel.invokeMethod<String>('getWebViewVersion');
  }

  final Completer<void> _creatingCompleter = Completer<void>();
  Future<void>? _initialization;
  Future<void>? _disposal;
  bool? _restricted;
  bool _hasNativeView = false;
  bool get isRestrictedPreview => _restricted == true;
  int _textureId = 0;
  bool _isDisposed = false;

  Future<void> get ready => _creatingCompleter.future;

  PermissionRequestedDelegate? _permissionRequested;

  late MethodChannel _methodChannel;
  bool _hasMethodChannel = false;
  late EventChannel _eventChannel;
  StreamSubscription? _eventStreamSubscription;

  final StreamController<String> _urlStreamController =
      StreamController<String>();

  /// A stream reflecting the current URL.
  Stream<String> get url => _urlStreamController.stream;

  final StreamController<LoadingState> _loadingStateStreamController =
      StreamController<LoadingState>.broadcast();

  final StreamController<WebviewDownloadEvent> _downloadEventStreamController =
      StreamController<WebviewDownloadEvent>.broadcast();

  final StreamController<WebErrorStatus> _onLoadErrorStreamController =
      StreamController<WebErrorStatus>();

  /// A stream reflecting the current loading state.
  Stream<LoadingState> get loadingState => _loadingStateStreamController.stream;

  Stream<WebviewDownloadEvent> get onDownloadEvent =>
      _downloadEventStreamController.stream;

  /// A stream reflecting the navigation error when navigation completed with an error.
  Stream<WebErrorStatus> get onLoadError => _onLoadErrorStreamController.stream;

  final StreamController<HistoryChanged> _historyChangedStreamController =
      StreamController<HistoryChanged>();

  /// A stream reflecting the current history state.
  Stream<HistoryChanged> get historyChanged =>
      _historyChangedStreamController.stream;

  final StreamController<String> _securityStateChangedStreamController =
      StreamController<String>();

  /// A stream reflecting the current security state.
  Stream<String> get securityStateChanged =>
      _securityStateChangedStreamController.stream;

  final StreamController<String> _titleStreamController =
      StreamController<String>();

  /// A stream reflecting the current document title.
  Stream<String> get title => _titleStreamController.stream;

  final StreamController<SystemMouseCursor> _cursorStreamController =
      StreamController<SystemMouseCursor>.broadcast();

  /// A stream reflecting the current cursor style.
  Stream<SystemMouseCursor> get _cursor => _cursorStreamController.stream;

  final StreamController<dynamic> _webMessageStreamController =
      StreamController<dynamic>();

  Stream<dynamic> get webMessage => _webMessageStreamController.stream;

  final StreamController<bool>
      _containsFullScreenElementChangedStreamController =
      StreamController<bool>.broadcast();

  /// A stream reflecting whether the document currently contains full-screen elements.
  Stream<bool> get containsFullScreenElementChanged =>
      _containsFullScreenElementChangedStreamController.stream;

  final _restrictedBlockedController = StreamController<String>.broadcast();

  /// Observes decisions already enforced synchronously by the native policy.
  /// These bounded reason codes cannot approve a request or weaken the policy.
  Stream<String> get restrictedBlocked => _restrictedBlockedController.stream;

  WebviewController() : super(WebviewValue.uninitialized()) {
    // A caller may await initialize() without also subscribing to ready.
    _creatingCompleter.future.ignore();
  }

  /// Initializes an ordinary view using the existing shared environment.
  Future<void> initialize() => _initialize(restricted: false);

  /// Creates an immutable restricted controller in the shared environment.
  /// The caller must load a trusted outer CSP + opaque sandbox document once.
  /// Unsupported Runtime capabilities fail initialization; no fallback occurs.
  Future<void> initializeRestrictedPreview() => _initialize(restricted: true);

  Future<void> _initialize({required bool restricted}) {
    if (_isDisposed) return Future.error(StateError('Webview is disposed'));
    if (_restricted != null && _restricted != restricted) {
      return Future.error(
          StateError('Webview initialization mode is immutable'));
    }
    if (_initialization != null) return _initialization!;
    _restricted = restricted;
    _initialization = Future<void>.microtask(() => _create(restricted));
    value = value.copyWith(status: WebviewStatus.initializing);
    return _initialization!;
  }

  Future<void> _create(bool restricted) async {
    try {
      if (_isDisposed) throw StateError('Webview is disposed');
      final reply = await _pluginChannel.invokeMapMethod<String, dynamic>(
          restricted ? 'initializeRestrictedPreview' : 'initialize');
      final id = reply?['textureId'];
      if (id is! int || id < 0) {
        throw const FormatException('Missing native WebView texture');
      }
      _textureId = id;
      _hasNativeView = true;
      if (_isDisposed) {
        await _disposeNative();
        throw StateError('Webview was disposed during initialization');
      }
      _methodChannel = MethodChannel('$_pluginChannelPrefix/$_textureId');
      _hasMethodChannel = true;
      _eventChannel = EventChannel('$_pluginChannelPrefix/$_textureId/events');
      _eventStreamSubscription =
          _eventChannel.receiveBroadcastStream().listen((event) {
        if (_isDisposed) return;
        final map = event as Map<dynamic, dynamic>;
        switch (map['type']) {
          case 'restrictedBlocked':
            if (restricted) {
              _restrictedBlockedController.add(map['value'] as String);
            }
            break;
          case 'restrictedClosed':
            if (restricted) {
              value = value.copyWith(
                  isInitialized: false,
                  status: WebviewStatus.failed,
                  error: PlatformException(code: 'restricted_preview_closed'));
            }
            break;
          case 'urlChanged':
            _urlStreamController.add(map['value']);
            break;
          case 'onLoadError':
            final value = WebErrorStatus.values[map['value']];
            _onLoadErrorStreamController.add(value);
            break;
          case 'loadingStateChanged':
            final value = LoadingState.values[map['value']];
            _loadingStateStreamController.add(value);
            break;
          case 'downloadEvent':
            final value = WebviewDownloadEvent(
              WebviewDownloadEventKind.values[map['value']['kind']],
              map['value']['url'],
              map['value']['resultFilePath'],
              map['value']['bytesReceived'],
              map['value']['totalBytesToReceive'],
            );
            _downloadEventStreamController.add(value);
            break;
          case 'historyChanged':
            final value = HistoryChanged(
                map['value']['canGoBack'], map['value']['canGoForward']);
            _historyChangedStreamController.add(value);
            break;
          case 'securityStateChanged':
            _securityStateChangedStreamController.add(map['value']);
            break;
          case 'titleChanged':
            _titleStreamController.add(map['value']);
            break;
          case 'cursorChanged':
            _cursorStreamController.add(getCursorByName(map['value']));
            break;
          case 'webMessageReceived':
            if (restricted) break;
            try {
              final message = json.decode(map['value']);
              _webMessageStreamController.add(message);
            } catch (ex) {
              _webMessageStreamController.addError(ex);
            }
            break;
          case 'containsFullScreenElementChanged':
            _containsFullScreenElementChangedStreamController.add(map['value']);
            break;
        }
      });

      if (!restricted) {
        _methodChannel.setMethodCallHandler((call) {
          if (call.method == 'permissionRequested') {
            return _onPermissionRequested(
                call.arguments as Map<dynamic, dynamic>);
          }
          throw MissingPluginException('Unknown method ${call.method}');
        });
      }
      value = value.copyWith(isInitialized: true, status: WebviewStatus.ready);
      _creatingCompleter.complete();
    } catch (error, stack) {
      if (!_isDisposed) {
        value = value.copyWith(
            isInitialized: false, status: WebviewStatus.failed, error: error);
      }
      if (!_creatingCompleter.isCompleted) {
        _creatingCompleter.completeError(error, stack);
      }
      rethrow;
    }
  }

  Future<bool?> _onPermissionRequested(Map<dynamic, dynamic> args) async {
    if (_permissionRequested == null) {
      return null;
    }

    final url = args['url'] as String?;
    final permissionKindIndex = args['permissionKind'] as int?;
    final isUserInitiated = args['isUserInitiated'] as bool?;

    if (url != null && permissionKindIndex != null && isUserInitiated != null) {
      final permissionKind = WebviewPermissionKind.values[permissionKindIndex];
      final decision =
          await _permissionRequested!(url, permissionKind, isUserInitiated);

      switch (decision) {
        case WebviewPermissionDecision.allow:
          return true;
        case WebviewPermissionDecision.deny:
          return false;
        default:
          return null;
      }
    }

    return null;
  }

  @override
  Future<void> dispose() {
    if (_disposal != null) return _disposal!;
    _isDisposed = true;
    final completion = Completer<void>();
    _disposal = completion.future;
    value =
        value.copyWith(isInitialized: false, status: WebviewStatus.disposed);
    if (_initialization == null && !_creatingCompleter.isCompleted) {
      _creatingCompleter.completeError(StateError('Webview is disposed'));
    }
    super.dispose();
    unawaited(_dispose()
        .then(completion.complete, onError: completion.completeError));
    return _disposal!;
  }

  Future<void> _disposeNative() async {
    if (!_hasNativeView) return;
    await _pluginChannel.invokeMethod('dispose', _textureId);
    _hasNativeView = false;
  }

  Future<void> _dispose() async {
    try {
      try {
        await _initialization;
      } catch (_) {
        // A failed or cancelled creation still needs its local streams closed.
      }
      try {
        await _eventStreamSubscription?.cancel();
      } finally {
        if (_hasMethodChannel) _methodChannel.setMethodCallHandler(null);
        await _disposeNative();
      }
    } finally {
      // Single-subscription streams need not have a listener; awaiting their
      // close futures could otherwise keep disposal pending forever.
      unawaited(_urlStreamController.close());
      unawaited(_loadingStateStreamController.close());
      unawaited(_downloadEventStreamController.close());
      unawaited(_onLoadErrorStreamController.close());
      unawaited(_historyChangedStreamController.close());
      unawaited(_securityStateChangedStreamController.close());
      unawaited(_titleStreamController.close());
      unawaited(_cursorStreamController.close());
      unawaited(_webMessageStreamController.close());
      unawaited(_containsFullScreenElementChangedStreamController.close());
      unawaited(_restrictedBlockedController.close());
      _permissionRequested = null;
    }
  }

  /// Loads the given [url].
  Future<void> loadUrl(String url) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('loadUrl', url);
  }

  /// Loads a document from the given string.
  Future<void> loadStringContent(String content) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('loadStringContent', content);
  }

  /// Reloads the current document.
  Future<void> reload() async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('reload');
  }

  /// Stops all navigations and pending resource fetches.
  Future<void> stop() async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('stop');
  }

  /// Navigates the WebView to the previous page in the navigation history.
  Future<void> goBack() async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('goBack');
  }

  /// Navigates the WebView to the next page in the navigation history.
  Future<void> goForward() async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('goForward');
  }

  /// Adds the provided JavaScript [script] to a list of scripts that should be run after the global
  /// object has been created, but before the HTML document has been parsed and before any
  /// other script included by the HTML document is run.
  ///
  /// Returns a [ScriptID] on success which can be used for [removeScriptToExecuteOnDocumentCreated].
  ///
  /// see https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.1264.42#addscripttoexecuteondocumentcreated
  Future<ScriptID?> addScriptToExecuteOnDocumentCreated(String script) async {
    if (_isDisposed) {
      return null;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod<String?>(
        'addScriptToExecuteOnDocumentCreated', script);
  }

  /// Removes the script identified by [scriptId] from the list of registered scripts.
  ///
  /// see https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.1264.42#removescripttoexecuteondocumentcreated
  Future<void> removeScriptToExecuteOnDocumentCreated(ScriptID scriptId) async {
    if (_isDisposed) {
      return null;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod(
        'removeScriptToExecuteOnDocumentCreated', scriptId);
  }

  /// Runs the JavaScript [script] in the current top-level document rendered in
  /// the WebView and returns its result.
  ///
  /// see https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.1264.42#executescript
  Future<dynamic> executeScript(String script) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);

    final data = await _methodChannel.invokeMethod('executeScript', script);
    if (data == null) return null;
    return jsonDecode(data as String);
  }

  /// Posts the given JSON-formatted message to the current document.
  Future<void> postWebMessage(String message) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('postWebMessage', message);
  }

  /// Sets the user agent value.
  Future<void> setUserAgent(String userAgent) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setUserAgent', userAgent);
  }

  /// Clears browser cookies.
  Future<void> clearCookies() async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('clearCookies');
  }

  /// Clears browser cache.
  Future<void> clearCache() async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('clearCache');
  }

  /// Toggles ignoring cache for each request. If true, cache will not be used.
  Future<void> setCacheDisabled(bool disabled) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setCacheDisabled', disabled);
  }

  /// Opens the Browser DevTools in a separate window
  Future<void> openDevTools() async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('openDevTools');
  }

  /// Sets the background color to the provided [color].
  ///
  /// Due to a limitation of the underlying WebView implementation,
  /// semi-transparent values are not supported.
  /// Any non-zero alpha value will be considered as opaque (0xff).
  Future<void> setBackgroundColor(Color color) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod(
        'setBackgroundColor', color.toARGB32().toSigned(32));
  }

  /// Sets the zoom factor.
  Future<void> setZoomFactor(double zoomFactor) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setZoomFactor', zoomFactor);
  }

  /// Sets the [WebviewPopupWindowPolicy].
  Future<void> setPopupWindowPolicy(
      WebviewPopupWindowPolicy popupPolicy) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod(
        'setPopupWindowPolicy', popupPolicy.index);
  }

  /// Suspends the web view.
  Future<void> suspend() async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('suspend');
  }

  /// Resumes the web view.
  Future<void> resume() async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('resume');
  }

  /// Adds a Virtual Host Name Mapping.
  ///
  /// Please refer to
  /// [Microsofts](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2_3#setvirtualhostnametofoldermapping)
  /// documentation for more details.
  Future<void> addVirtualHostNameMapping(String hostName, String folderPath,
      WebviewHostResourceAccessKind accessKind) async {
    if (_isDisposed) {
      return;
    }

    return _methodChannel.invokeMethod(
        'setVirtualHostNameMapping', [hostName, folderPath, accessKind.index]);
  }

  /// Removes a Virtual Host Name Mapping.
  ///
  /// Please refer to
  /// [Microsofts](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2_3#clearvirtualhostnametofoldermapping)
  /// documentation for more details.
  Future<void> removeVirtualHostNameMapping(String hostName) async {
    if (_isDisposed) {
      return;
    }
    return _methodChannel.invokeMethod('clearVirtualHostNameMapping', hostName);
  }

  /// Limits the number of frames per second to the given value.
  Future<void> setFpsLimit([int? maxFps = 0]) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setFpsLimit', maxFps);
  }

  /// Sends a Pointer (Touch) update
  Future<void> _setPointerUpdate(WebviewPointerEventKind kind, int pointer,
      Offset position, double size, double pressure) async {
    if (_isDisposed || !value.isInitialized) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setPointerUpdate',
        [pointer, kind.index, position.dx, position.dy, size, pressure]);
  }

  /// Moves the virtual cursor to [position].
  Future<void> _setCursorPos(Offset position) async {
    if (_isDisposed || !value.isInitialized) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel
        .invokeMethod('setCursorPos', [position.dx, position.dy]);
  }

  /// Indicates whether the specified [button] is currently down.
  Future<void> _setPointerButtonState(PointerButton button, bool isDown) async {
    if (_isDisposed || !value.isInitialized) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setPointerButton',
        <String, dynamic>{'button': button.index, 'isDown': isDown});
  }

  /// Sets the horizontal and vertical scroll delta.
  Future<void> _setScrollDelta(double dx, double dy) async {
    if (_isDisposed || !value.isInitialized) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setScrollDelta', [dx, dy]);
  }

  /// Sets the surface size to the provided [size].
  Future<void> _setSize(Size size, double scaleFactor) async {
    if (_isDisposed || !value.isInitialized) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel
        .invokeMethod('setSize', [size.width, size.height, scaleFactor]);
  }
}

class Webview extends StatefulWidget {
  final WebviewController controller;
  final PermissionRequestedDelegate? permissionRequested;
  final double? width;
  final double? height;

  /// An optional scale factor. Defaults to [FlutterView.devicePixelRatio] for
  /// rendering in native resolution.
  /// Setting this to 1.0 will disable high-DPI support.
  /// This should only be needed to mimic old behavior before high-DPI support
  /// was available.
  final double? scaleFactor;

  /// The [FilterQuality] used for scaling the texture's contents.
  /// Defaults to [FilterQuality.none] as this renders in native resolution
  /// unless specifying a [scaleFactor].
  final FilterQuality filterQuality;

  const Webview(this.controller,
      {this.width,
      this.height,
      this.permissionRequested,
      this.scaleFactor,
      this.filterQuality = FilterQuality.none});

  @override
  _WebviewState createState() => _WebviewState();
}

class _WebviewState extends State<Webview> {
  final GlobalKey _key = GlobalKey();
  final _downButtons = <int, PointerButton>{};

  PointerDeviceKind _pointerKind = PointerDeviceKind.unknown;

  MouseCursor _cursor = SystemMouseCursors.basic;

  WebviewController get _controller => widget.controller;

  StreamSubscription? _cursorSubscription;

  @override
  void initState() {
    super.initState();

    // TODO: Refactor callback and event handling and
    // remove this line
    _controller._permissionRequested = widget.permissionRequested;

    // Report initial surface size
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportSurfaceSize());

    _cursorSubscription = _controller._cursor.listen((cursor) {
      if (!mounted) return;
      setState(() {
        _cursor = cursor;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return (widget.height != null && widget.width != null)
        ? SizedBox(
            key: _key,
            width: widget.width,
            height: widget.height,
            child: _buildInner())
        : SizedBox.expand(key: _key, child: _buildInner());
  }

  Widget _buildInner() {
    return ValueListenableBuilder<WebviewValue>(
        valueListenable: _controller,
        builder: (context, value, _) => NotificationListener<
                SizeChangedLayoutNotification>(
            onNotification: (notification) {
              _reportSurfaceSize();
              return true;
            },
            child: SizeChangedLayoutNotifier(
                child: _controller.value.isInitialized
                    ? Listener(
                        onPointerHover: (ev) {
                          // ev.kind is for whatever reason not set to touch
                          // even on touch input
                          if (_pointerKind == PointerDeviceKind.touch) {
                            // Ignoring hover events on touch for now
                            return;
                          }
                          _controller._setCursorPos(ev.localPosition);
                        },
                        onPointerDown: (ev) {
                          _pointerKind = ev.kind;
                          if (ev.kind == PointerDeviceKind.touch) {
                            _controller._setPointerUpdate(
                                WebviewPointerEventKind.down,
                                ev.pointer,
                                ev.localPosition,
                                ev.size,
                                ev.pressure);
                            return;
                          }
                          final button = getButton(ev.buttons);
                          _downButtons[ev.pointer] = button;
                          _controller._setPointerButtonState(button, true);
                        },
                        onPointerUp: (ev) {
                          _pointerKind = ev.kind;
                          if (ev.kind == PointerDeviceKind.touch) {
                            _controller._setPointerUpdate(
                                WebviewPointerEventKind.up,
                                ev.pointer,
                                ev.localPosition,
                                ev.size,
                                ev.pressure);
                            return;
                          }
                          final button = _downButtons.remove(ev.pointer);
                          if (button != null) {
                            _controller._setPointerButtonState(button, false);
                          }
                        },
                        onPointerCancel: (ev) {
                          _pointerKind = ev.kind;
                          final button = _downButtons.remove(ev.pointer);
                          if (button != null) {
                            _controller._setPointerButtonState(button, false);
                          }
                        },
                        onPointerMove: (ev) {
                          _pointerKind = ev.kind;
                          if (ev.kind == PointerDeviceKind.touch) {
                            _controller._setPointerUpdate(
                                WebviewPointerEventKind.update,
                                ev.pointer,
                                ev.localPosition,
                                ev.size,
                                ev.pressure);
                          } else {
                            _controller._setCursorPos(ev.localPosition);
                          }
                        },
                        onPointerSignal: (signal) {
                          if (signal is PointerScrollEvent) {
                            _controller._setScrollDelta(
                                -signal.scrollDelta.dx, -signal.scrollDelta.dy);
                          }
                        },
                        onPointerPanZoomUpdate: (signal) {
                          if (signal.panDelta.dx.abs() >
                              signal.panDelta.dy.abs()) {
                            _controller._setScrollDelta(-signal.panDelta.dx, 0);
                          } else {
                            _controller._setScrollDelta(0, signal.panDelta.dy);
                          }
                        },
                        child: MouseRegion(
                            cursor: _cursor,
                            child: Texture(
                              textureId: _controller._textureId,
                              filterQuality: widget.filterQuality,
                            )),
                      )
                    : const SizedBox())));
  }

  void _reportSurfaceSize() async {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      try {
        await _controller.ready;
      } catch (_) {
        return;
      }
      if (!mounted ||
          _controller._isDisposed ||
          !_controller.value.isInitialized) {
        return;
      }
      unawaited(_controller._setSize(
          box.size, widget.scaleFactor ?? View.of(context).devicePixelRatio));
    }
  }

  @override
  void dispose() {
    super.dispose();
    _cursorSubscription?.cancel();
  }
}
