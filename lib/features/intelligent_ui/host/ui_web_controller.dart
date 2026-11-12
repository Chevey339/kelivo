import 'dart:async';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'ui_web_document.dart';

/// Windows activation is deferred by the user; Linux uses source/export.
bool uiWebPreviewSupported(TargetPlatform platform) => const {
  TargetPlatform.android,
  TargetPlatform.iOS,
  TargetPlatform.macOS,
}.contains(platform);

enum UiWebNativePhase { initializing, ready, failed, closed }

/// One native controller, created only in response to a ready card's Open action.
/// This deliberately has no application bridge, persistent state or tool access.
final class UiWebController extends ChangeNotifier {
  UiWebController();

  WebViewController? _controller;
  Future<void>? _starting, _closing;
  bool _closeRequested = false;
  bool _disposed = false;
  bool _loaded = false;
  bool _initialNavigation = true;
  UiWebNativePhase phase = UiWebNativePhase.initializing;
  Object? error;
  Object? closeError;

  static int _created = 0;
  @visibleForTesting
  static int get createdNativeViews => _created;

  Future<void> start(UiWebDocument document) {
    if (!document.canOpen) {
      return Future.error(StateError('Preview is not complete'));
    }
    return loadTrustedDocument(
      UiWebSandbox.wrap(document.html, title: document.title),
    );
  }

  /// Only host-produced markup belongs here. Production calls [start]; native
  /// acceptance may add a static, test-only observer to the same trusted shell.
  @visibleForTesting
  Future<void> loadTrustedDocument(String document) {
    if (_closeRequested) return Future.error(StateError('Preview is closed'));
    if (_starting != null) {
      return Future.error(StateError('Preview already started'));
    }
    return _starting = _start(document);
  }

  Future<void> _start(String document) async {
    try {
      if (!uiWebPreviewSupported(defaultTargetPlatform)) {
        throw UnsupportedError('This platform uses source and HTML export');
      }
      final params = WebViewPlatform.instance is WebKitWebViewPlatform
          ? WebKitWebViewControllerCreationParams(
              javaScriptCanOpenWindowsAutomatically: false,
            )
          : const PlatformWebViewControllerCreationParams();
      final controller = WebViewController.fromPlatformCreationParams(params);
      _controller = controller;
      _created++;
      // Await capability installation; the convenience constructor does not
      // await its platform permission registration future.
      await controller.platform.setOnPlatformPermissionRequest((request) {
        unawaited(
          request.deny().catchError((Object failure) {
            _fail(failure);
            unawaited(close());
          }),
        );
      });
      final navigation = NavigationDelegate();
      await navigation.platform.setOnNavigationRequest((request) {
        final localFrame =
            !request.isMainFrame &&
            (request.url == 'about:srcdoc' || request.url == 'about:blank');
        final hostBlank =
            request.isMainFrame &&
            request.url == 'about:blank' &&
            (_initialNavigation || _closeRequested);
        if (hostBlank) _initialNavigation = false;
        return localFrame || hostBlank
            ? NavigationDecision.navigate
            : NavigationDecision.prevent;
      });
      await navigation.platform.setOnPageStarted((_) {
        _initialNavigation = false;
      });
      await navigation.platform.setOnPageFinished((_) {
        if (_loaded && !_closeRequested && error == null) {
          phase = UiWebNativePhase.ready;
          _notify();
        }
      });
      await navigation.platform.setOnWebResourceError((failure) {
        if (failure.isForMainFrame == true && !_closeRequested) {
          _fail(
            StateError('Preview document load failed (${failure.errorCode})'),
          );
        }
      });
      await navigation.platform.setOnHttpAuthRequest((request) {
        request.onCancel();
      });
      await controller.setNavigationDelegate(navigation);
      // Mobile views can show the native shell before HTML is ready. The
      // WebKit plugin implements this through UIView APIs unavailable on
      // macOS; the loading cover shields that platform until its first paint.
      if (defaultTargetPlatform != TargetPlatform.macOS) {
        await controller.setBackgroundColor(const Color(0x00000000));
      }
      await controller.setOnJavaScriptAlertDialog((_) async {});
      await controller.setOnJavaScriptConfirmDialog((_) async => false);
      await controller.setOnJavaScriptTextInputDialog((_) async => '');
      final platform = controller.platform;
      if (platform is AndroidWebViewController) {
        await platform.setAllowFileAccess(false);
        await platform.setAllowContentAccess(false);
        await platform.setGeolocationEnabled(false);
        await platform.setOnShowFileSelector((_) async => const []);
        await platform.setGeolocationPermissionsPromptCallbacks(
          onShowPrompt: (_) async =>
              const GeolocationPermissionsResponse(allow: false, retain: false),
        );
        await platform.setMixedContentMode(MixedContentMode.neverAllow);
      }
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (_closeRequested) return;
      _loaded = true;
      _notify();
      await controller.loadHtmlString(document);
    } catch (failure) {
      _fail(failure);
      rethrow;
    }
  }

  void _fail(Object failure) {
    if (_closeRequested) return;
    error = failure;
    phase = UiWebNativePhase.failed;
    _notify();
  }

  Widget buildView() {
    final controller = _controller;
    return controller == null || !_loaded || phase == UiWebNativePhase.closed
        ? const SizedBox.shrink()
        : WebViewWidget(controller: controller);
  }

  @visibleForTesting
  WebViewController? get nativeController => _controller;

  @visibleForTesting
  Future<String?> nativeTitle() async => _controller?.getTitle();

  Future<void> close() {
    if (_closing != null) return _closing!;
    _closeRequested = true;
    return _closing = _close();
  }

  Future<void> _close() async {
    try {
      // Includes pending initialization and the cleanup evaluation. A blocked
      // script must not trap Close/Esc before we reach the empty-page wait.
      await _clearNative().timeout(const Duration(seconds: 5));
    } catch (failure) {
      closeError = failure;
    } finally {
      _controller = null;
      phase = UiWebNativePhase.closed;
      _notify();
    }
  }

  Future<void> _clearNative() async {
    try {
      await _starting;
    } catch (_) {
      /* Failure was already reported. */
    }
    final controller = _controller;
    if (controller == null || !_loaded) return;
    try {
      // Destroy the child context before releasing the platform view. This
      // constant neither reads generated content nor forwards it to the host.
      await controller.runJavaScript(UiWebSandbox.removeGeneratedDocument);
    } finally {
      await controller.setJavaScriptMode(JavaScriptMode.disabled);
      await controller.loadHtmlString(UiWebSandbox.emptyDocument);
      await _waitForEmptyDocument(controller);
    }
  }

  Future<void> _waitForEmptyDocument(WebViewController controller) async {
    // WKWebView can omit didFinish after cancelled child loads even though the
    // replacement has loaded. Both documents have about:blank as their URL;
    // verify the host-owned title instead. Generated content is opaque-origin
    // and cannot write this parent title. The outer deadline bounds all waits.
    while (phase != UiWebNativePhase.closed) {
      if (await controller.getTitle() == UiWebSandbox.closedTitle) return;
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(close());
    super.dispose();
  }
}
