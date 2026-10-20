import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import '../../../features/browser/models/browser_models.dart';

/// Native window integration identifies only Kelivo's own browser WKWebView.
/// Encode even restored IDs so this inert script cannot terminate its comment.
String browserTabUserScriptMarker(String tabId) =>
    '/* kelivo-browser-tab:${base64Url.encode(utf8.encode(tabId))} */';

enum BrowserScrollPhase { reset, update, end, metrics }

/// Main-document geometry in CSS pixels. End is emitted only by a real DOM
/// scrollend event; unsupported engines still report updates and capability.
class BrowserScrollState {
  const BrowserScrollState({
    required this.offset,
    required this.viewportExtent,
    required this.contentExtent,
    required this.phase,
    required this.supportsScrollEnd,
    this.isUserInteracting = false,
    this.gestureDelta = 0,
  });

  const BrowserScrollState.reset()
    : offset = 0,
      viewportExtent = 0,
      contentExtent = 0,
      phase = BrowserScrollPhase.reset,
      supportsScrollEnd = false,
      isUserInteracting = false,
      gestureDelta = 0;

  final double offset;
  final double viewportExtent;
  final double contentExtent;
  final BrowserScrollPhase phase;
  final bool supportsScrollEnd;

  /// A trusted main-document touch is still down. Native scrolling continues
  /// after release during deceleration and rubber-band recovery.
  final bool isUserInteracting;

  /// Coalesced vertical touch intent in CSS pixels, positive towards the end of
  /// the document. Unlike scrollY, this changes when a boundary pins the page.
  final double gestureDelta;
}

class BrowserPageState {
  const BrowserPageState({
    this.url,
    this.title,
    this.isLoading,
    this.progress,
    this.canGoBack,
    this.canGoForward,
    this.error,
    this.completedNavigation = false,
    this.rendererTerminated = false,
    this.closeRequested = false,
    this.replacesRenderedDocument = false,
    this.scroll,
    this.favicon,
    this.faviconPageUrl,
  });
  final String? url;
  final String? title;
  final bool? isLoading;
  final double? progress;
  final bool? canGoBack;
  final bool? canGoForward;
  final String? error;
  final bool completedNavigation;
  final bool rendererTerminated;
  final bool closeRequested;

  /// A real main-frame navigation replaces loadHtml, even at its base URL.
  final bool replacesRenderedDocument;
  final BrowserScrollState? scroll;

  /// A bounded, rasterized icon from this exact main document's session.
  final Uint8List? favicon;
  final String? faviconPageUrl;
}

typedef BrowserEngineFactory =
    Future<BrowserEngine> Function({
      required BrowserTab tab,
      required BrowserSettings settings,
      required void Function(BrowserPageState state) onChanged,
      required void Function(String url, String? fileName) onDownload,
      required Future<bool> Function(String? url, int windowId) onNewWindow,
      required bool Function() isAgentActive,
    });

abstract class BrowserEngine {
  Widget buildView();

  /// Completes when the most recently built platform view has attached.
  Future<void> get viewReady => Future<void>.value();
  Future<void> navigate(String url);
  Future<void> loadHtml(String html, {String? baseUrl});
  Future<void> back();
  Future<void> forward();
  Future<void> reload();
  Future<void> stop();
  Future<void> waitForLoad(Duration timeout);
  Future<Object?> evaluate(String source, {bool awaitPromise = false});
  Future<Uint8List?> screenshot();

  /// Lightweight last-view image for the tab switcher, separate from tool images.
  Future<Uint8List?> thumbnail() => screenshot();
  Future<void> updateSettings(BrowserSettings settings);
  Future<void> find(String text);
  Future<void> findNext(bool forward);
  Future<void> clearFind();
  Future<Map<String, String>> downloadHeaders(String url);

  /// Presentation changes also release native focus from covered web pages.
  /// Background tool calls can resume work without making that page visible.
  Future<void> setVisible(bool visible) => visible ? resume() : pause();
  Future<void> pause();
  Future<void> resume();
  Future<void> dispose();
}
