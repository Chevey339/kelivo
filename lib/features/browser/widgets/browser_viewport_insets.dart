import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../core/services/browser/browser_engine.dart';

/// Keeps page content below the header until the actual WKWebView confirms its
/// native obscured inset. Fixed/sticky website headers then remain WebKit-owned.
class BrowserViewportInsets extends StatefulWidget {
  const BrowserViewportInsets({
    super.key,
    required this.tabId,
    required this.top,
    required this.builder,
    this.viewIdentity,
  });

  final String? tabId;
  final double top;

  /// Changes when the same tab replaces a terminated/evicted native runtime.
  final Object? viewIdentity;
  final Widget Function(BuildContext, bool underlapHeader) builder;

  /// Actual iOS preference, shared by the mounted viewport hosts. Unknown state
  /// remains protected until the native query returns; no layout depends on it.
  static ValueListenable<bool> get reduceTransparency =>
      _BrowserViewportInsetsState._reduceTransparency;

  @override
  State<BrowserViewportInsets> createState() => _BrowserViewportInsetsState();
}

class _BrowserViewportInsetsState extends State<BrowserViewportInsets> {
  static const _channel = MethodChannel('app.browser_window');
  static int _nextOwner = 0;
  static final _reduceTransparency = ValueNotifier<bool>(true);
  static int _accessibilityUsers = 0;
  static int _accessibilityRevision = 0;
  final _owner = 'browser-insets-${_nextOwner++}';
  Timer? _retry;
  int _generation = 0;
  int _attempts = 0;
  bool _supported = false;
  bool _applied = false;
  bool _retainedUnderlap = false;
  bool _accessibilityRegistered = false;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      unawaited(_checkSupport());
    }
  }

  Future<void> _checkSupport() async {
    try {
      final supported =
          await _channel.invokeMethod<bool>('supportsBrowserViewportInsets') ??
          false;
      if (!mounted) return;
      _supported = supported;
      if (supported) {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          _registerAccessibility();
        }
        _synchronize();
      }
    } on MissingPluginException {
      // Tests/previews and older hosts keep content below the header.
    }
  }

  void _registerAccessibility() {
    if (_accessibilityRegistered) return;
    _accessibilityRegistered = true;
    if (_accessibilityUsers++ != 0) return;
    _reduceTransparency.value = true;
    final revision = ++_accessibilityRevision;
    // BrowserWindowChrome owns this channel's inbound handler on macOS only.
    _channel.setMethodCallHandler(_handleAccessibilityChange);
    unawaited(_queryReduceTransparency(revision));
  }

  static Future<void> _queryReduceTransparency(int revision) async {
    try {
      final reduced = await _channel.invokeMethod<bool>(
        'getBrowserReduceTransparency',
      );
      if (_accessibilityUsers > 0 &&
          revision == _accessibilityRevision &&
          reduced != null) {
        _reduceTransparency.value = reduced;
      }
    } on MissingPluginException {
      // Older hosts keep the existing edge protection.
    } on PlatformException {
      // A detached host cannot confirm that transparency is allowed.
    }
  }

  static Future<void> _handleAccessibilityChange(MethodCall call) async {
    if (_accessibilityUsers == 0 ||
        call.method != 'browserReduceTransparencyChanged' ||
        call.arguments is! bool) {
      return;
    }
    // A notification supersedes an older in-flight query, even if its reply
    // arrives later. Disposal/remount also invalidates that query below.
    _accessibilityRevision++;
    _reduceTransparency.value = call.arguments as bool;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (_supported && (_route?.isCurrent ?? true)) _synchronize();
  }

  @override
  void didUpdateWidget(BrowserViewportInsets oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabId != widget.tabId ||
        oldWidget.top != widget.top ||
        oldWidget.viewIdentity != widget.viewIdentity) {
      _generation++;
      _retry?.cancel();
      // Switching tabs must not shrink/expand the entire native viewport by
      // the header height while the next retained view receives its inset.
      _retainedUnderlap =
          (_applied || _retainedUnderlap) && oldWidget.top == widget.top;
      _applied = false;
      // Retained renderers keep their obscured inset even while another tab
      // (including the start page) is active. The owner releases them together
      // when its host is disposed; native updates apply a new top to all leases.
    }
    if (_supported && !_applied) _synchronize();
  }

  void _synchronize() {
    if (!_supported || widget.tabId == null || !(_route?.isCurrent ?? true)) {
      return;
    }
    _retry?.cancel();
    _attempts = 0;
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation) unawaited(_apply(generation));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _apply(int generation) async {
    if (!mounted || generation != _generation || !(_route?.isCurrent ?? true)) {
      return;
    }
    final tabId = widget.tabId;
    if (tabId == null) return;
    try {
      final applied =
          await _channel.invokeMethod<bool>('setBrowserViewportInsets', {
            'owner': _owner,
            'marker': browserTabUserScriptMarker(tabId),
            'top': widget.top,
          }) ??
          false;
      if (!mounted || generation != _generation) return;
      if (applied) {
        if (!_applied) {
          setState(() {
            _applied = true;
            _retainedUnderlap = false;
          });
        }
      } else if (++_attempts < 20) {
        // Platform view creation is asynchronous. Retry only while attaching;
        // steady-state frames never traverse the native view hierarchy.
        _retry = Timer(
          const Duration(milliseconds: 50),
          () => unawaited(_apply(generation)),
        );
      } else if (_retainedUnderlap) {
        setState(() => _retainedUnderlap = false);
      }
    } on MissingPluginException {
      // Native registration can disappear while the page is being removed.
    }
  }

  Future<void> _release() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('releaseBrowserViewportInsets', _owner);
    } on MissingPluginException {
      // The window may already be gone.
    }
  }

  @override
  void dispose() {
    _generation++;
    _retry?.cancel();
    unawaited(_release());
    if (_accessibilityRegistered && --_accessibilityUsers == 0) {
      _accessibilityRevision++;
      _channel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _applied || _retainedUnderlap);
}
