import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Window spacing and shortcuts belong to the browser's route, including when
/// the native WebView (rather than Flutter) owns keyboard focus.
class BrowserWindowChrome extends StatefulWidget {
  const BrowserWindowChrome({
    super.key,
    this.onShortcut,
    this.windowSpacing = true,
    this.shortcutsEnabled = true,
    required this.child,
  });

  /// Receives the unmodified command letter: f, l, t, w, or r.
  final ValueChanged<String>? onShortcut;
  final bool windowSpacing;
  final bool shortcutsEnabled;
  final Widget child;

  @override
  State<BrowserWindowChrome> createState() => _BrowserWindowChromeState();
}

class _BrowserWindowChromeState extends State<BrowserWindowChrome> {
  static const _channel = MethodChannel('app.browser_window');
  static final _hosts = <_BrowserWindowChromeState>[];
  static bool _chromeEnabled = false;
  static bool _shortcutsEnabled = false;
  ModalRoute<dynamic>? _route;
  bool _registered = false;

  bool get _acceptsShortcuts =>
      mounted &&
      widget.shortcutsEnabled &&
      widget.onShortcut != null &&
      (_route?.isCurrent ?? true);

  static _BrowserWindowChromeState? get _activeHost =>
      _hosts.reversed.where((host) => host._acceptsShortcuts).firstOrNull;

  static Future<void> _setEnabled(String method, bool enabled) async {
    try {
      await _channel.invokeMethod<void>(method, enabled);
    } on MissingPluginException {
      // Widget tests and standalone previews have no native window.
    }
  }

  static void _syncWindow() {
    final chromeEnabled = _hosts.any((host) => host.widget.windowSpacing);
    final shortcutsEnabled = _activeHost != null;
    if (_chromeEnabled != chromeEnabled) {
      _chromeEnabled = chromeEnabled;
      unawaited(_setEnabled('setBrowserChrome', chromeEnabled));
    }
    if (_shortcutsEnabled != shortcutsEnabled) {
      _shortcutsEnabled = shortcutsEnabled;
      unawaited(_setEnabled('setBrowserShortcuts', shortcutsEnabled));
    }
  }

  static Future<void> _handleMethod(MethodCall call) async {
    if (call.method != 'shortcut' || call.arguments is! String) return;
    final key = call.arguments as String;
    if (!const {'f', 'l', 't', 'w', 'r'}.contains(key)) return;
    // Read isCurrent again: an event queued before a modal opened must not
    // activate a browser command underneath that modal.
    _activeHost?.widget.onShortcut?.call(key);
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    _registered = true;
    if (_hosts.isEmpty) _channel.setMethodCallHandler(_handleMethod);
    _hosts.add(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_registered) return;
    _route = ModalRoute.of(context);
    _syncWindow();
  }

  @override
  void didUpdateWidget(BrowserWindowChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_registered) _syncWindow();
  }

  @override
  void dispose() {
    if (_registered) {
      _hosts.remove(this);
      _syncWindow();
      if (_hosts.isEmpty) _channel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
