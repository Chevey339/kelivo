import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// A platform-interface fake, not evidence about a browser engine.
class FakeGenUiWebPlatform extends WebViewPlatform {
  final controllers = <FakeGenUiWebController>[];
  final events = <String>[];
  String? failAt;
  Completer<void>? permissionWait, cleanupWait, emptyWait;
  bool finishEmpty = true, finishInitial = true;
  VoidCallback? onTap;

  Future<void> step(String name) async {
    events.add(name);
    if (failAt == name) throw StateError('Injected $name failure');
  }

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = FakeGenUiWebController(params, this);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => FakeGenUiNavigation(params, this);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => FakeGenUiWebWidget(params, this);
}

class FakeGenUiWebController extends PlatformWebViewController {
  FakeGenUiWebController(super.params, this.owner) : super.implementation();
  final FakeGenUiWebPlatform owner;
  FakeGenUiNavigation? navigation;
  String title = 'Initial document';
  final documents = <String>[];
  final scripts = <String>[];
  void Function(PlatformWebViewPermissionRequest)? permission;
  Future<bool> Function(JavaScriptConfirmDialogRequest)? confirm;
  Future<String> Function(JavaScriptTextInputDialogRequest)? prompt;
  @override
  Future<void> setOnPlatformPermissionRequest(
    void Function(PlatformWebViewPermissionRequest) callback,
  ) async {
    await owner.step('permission');
    await owner.permissionWait?.future;
    permission = callback;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    await owner.step('navigationDelegate');
    navigation = handler as FakeGenUiNavigation;
  }

  @override
  Future<void> setOnJavaScriptAlertDialog(
    Future<void> Function(JavaScriptAlertDialogRequest) callback,
  ) => owner.step('alert');
  @override
  Future<void> setOnJavaScriptConfirmDialog(
    Future<bool> Function(JavaScriptConfirmDialogRequest) callback,
  ) async {
    await owner.step('confirm');
    confirm = callback;
  }

  @override
  Future<void> setOnJavaScriptTextInputDialog(
    Future<String> Function(JavaScriptTextInputDialogRequest) callback,
  ) async {
    await owner.step('prompt');
    prompt = callback;
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) =>
      owner.step('javascript:${mode.name}');
  @override
  Future<void> setBackgroundColor(Color color) =>
      owner.step('background:${color.toARGB32()}');
  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    await owner.step('load');
    documents.add(html);
    navigation?.started?.call('about:blank');
    if (html.contains('<title>Kelivo preview closed</title>')) {
      await owner.emptyWait?.future;
      title = 'Kelivo preview closed';
      if (owner.finishEmpty) navigation?.finished?.call('about:blank');
    } else if (owner.finishInitial) {
      navigation?.finished?.call('about:blank');
    }
  }

  @override
  Future<String?> getTitle() async => title;
  @override
  Future<void> runJavaScript(String script) async {
    await owner.step('cleanup');
    scripts.add(script);
    await owner.cleanupWait?.future;
  }
}

class FakeGenUiNavigation extends PlatformNavigationDelegate {
  FakeGenUiNavigation(super.params, this.owner) : super.implementation();
  final FakeGenUiWebPlatform owner;
  NavigationRequestCallback? request;
  PageEventCallback? started, finished;
  WebResourceErrorCallback? error;
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {
    await owner.step('navigationPolicy');
    request = callback;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {
    started = callback;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    finished = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    error = callback;
  }

  @override
  Future<void> setOnHttpAuthRequest(HttpAuthRequestCallback callback) =>
      owner.step('httpAuth');
}

class FakeGenUiWebWidget extends PlatformWebViewWidget {
  FakeGenUiWebWidget(super.params, this.owner) : super.implementation();
  final FakeGenUiWebPlatform owner;
  @override
  Widget build(BuildContext context) {
    const view = ColoredBox(
      color: Color(0xffeeeeee),
      child: Center(
        child: Text(
          'Native preview test double',
          style: TextStyle(color: Color(0xff222222)),
        ),
      ),
    );
    return owner.onTap == null
        ? view
        : Semantics(
            label: 'Native preview action',
            button: true,
            child: GestureDetector(onTap: owner.onTap, child: view),
          );
  }
}

class FakeGenUiPermission extends PlatformWebViewPermissionRequest {
  FakeGenUiPermission()
    : super(
        types: const {
          WebViewPermissionResourceType.camera,
          WebViewPermissionResourceType.microphone,
        },
      );
  final _decisions = <bool>[];
  int get grants => _decisions.where((granted) => granted).length;
  int get denials => _decisions.where((granted) => !granted).length;
  @override
  Future<void> grant() async {
    _decisions.add(true);
  }

  @override
  Future<void> deny() async {
    _decisions.add(false);
  }
}
