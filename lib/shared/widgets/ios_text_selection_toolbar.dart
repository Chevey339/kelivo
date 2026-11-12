import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// A UIKit edit menu on iOS 26+, with the existing Flutter menu elsewhere.
/// Only labels and an anchor cross the channel; document text stays in Dart.
class IosTextSelectionToolbar extends StatefulWidget {
  const IosTextSelectionToolbar({
    super.key,
    required this.anchors,
    required this.buttonItems,
    required this.selectionContext,
    required this.onDismiss,
  });

  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> buttonItems;
  final BuildContext selectionContext;
  final VoidCallback onDismiss;

  static const _channel = MethodChannel('app.ios_selection_menu');
  static Future<bool>? _availability;
  static _IosTextSelectionToolbarState? _active;
  static int _nextSession = 0;

  static Future<bool> _isAvailable() => _availability ??= () async {
    _channel.setMethodCallHandler((call) async {
      final active = _active;
      final args = call.arguments as Map?;
      if (active == null || args?['session'] != active._session) return;
      switch (call.method) {
        case 'action':
          if (args?['revision'] != active._revision) return;
          final index = args?['index'];
          if (index is! int ||
              index < 0 ||
              index >= active.widget.buttonItems.length) {
            return;
          }
          final action = active.widget.buttonItems[index].onPressed;
          if (action == null) return;
          // Dismiss first: Select All may synchronously open a new toolbar.
          active._dismiss();
          action();
        case 'dismissed':
          active._dismiss();
      }
    });
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }();

  @visibleForTesting
  static void resetAvailabilityForTesting() {
    assert(_active == null);
    _availability = null;
  }

  @override
  State<IosTextSelectionToolbar> createState() =>
      _IosTextSelectionToolbarState();
}

class _IosTextSelectionToolbarState extends State<IosTextSelectionToolbar>
    with WidgetsBindingObserver {
  final _session = ++IosTextSelectionToolbar._nextSession;
  final _scrollPositions = <ScrollPosition>[];
  bool? _supported;
  bool _closed = false;
  bool _scheduled = false;
  bool _observing = false;
  int _revision = 0;
  int _request = 0;
  List<String>? _titles;
  List<bool>? _enabled;
  Rect? _rect;
  (Size, double, EdgeInsets, EdgeInsets)? _windowGeometry;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    final supported = await IosTextSelectionToolbar._isAvailable();
    if (!mounted || _closed) return;
    setState(() => _supported = supported);
    if (supported) _scheduleSync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleSync();
  }

  @override
  void didUpdateWidget(IosTextSelectionToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_scheduled || _closed || _supported != true) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted && !_closed && _supported == true) unawaited(_sync());
    });
  }

  Future<void> _sync() async {
    if (widget.buttonItems.isEmpty || !widget.selectionContext.mounted) {
      _dismiss();
      return;
    }
    var primary = widget.anchors.primaryAnchor;
    var secondary = widget.anchors.secondaryAnchor ?? primary;
    if (!primary.dx.isFinite ||
        !primary.dy.isFinite ||
        !secondary.dx.isFinite ||
        !secondary.dy.isFinite) {
      _dismiss();
      return;
    }
    // re_editor uses an offscreen primary (-10000, -10000) to prefer the
    // secondary anchor. It must not become a screen-sized UIKit target rect.
    final view = View.of(context);
    final viewport = Offset.zero & (view.physicalSize / view.devicePixelRatio);
    if (!viewport.contains(primary) && viewport.contains(secondary)) {
      primary = secondary;
    } else if (viewport.contains(primary) && !viewport.contains(secondary)) {
      secondary = primary;
    }
    final bounds = Rect.fromPoints(primary, secondary);
    final rect = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      math.max(1, bounds.width),
      math.max(1, bounds.height),
    );
    final titles = [
      for (final item in widget.buttonItems)
        AdaptiveTextSelectionToolbar.getButtonLabel(context, item),
    ];
    final enabled = [
      for (final item in widget.buttonItems) item.onPressed != null,
    ];
    final itemsChanged =
        !listEquals(titles, _titles) || !listEquals(enabled, _enabled);
    if (!itemsChanged && rect == _rect) return;

    if (!_observing) {
      IosTextSelectionToolbar._active?._dismiss();
      IosTextSelectionToolbar._active = this;
      _startObserving();
    }
    if (itemsChanged) _revision++;
    _titles = titles;
    _enabled = enabled;
    _rect = rect;
    final revision = _revision;
    final request = ++_request;
    bool shown;
    try {
      shown =
          await IosTextSelectionToolbar._channel.invokeMethod<bool>('show', {
            'session': _session,
            'revision': revision,
            'rect': [rect.left, rect.top, rect.width, rect.height],
            'items': [
              for (var i = 0; i < titles.length; i++)
                {'title': titles[i], 'enabled': enabled[i]},
            ],
          }) ??
          false;
    } on MissingPluginException {
      shown = false;
    } on PlatformException {
      shown = false;
    }
    if (!shown && mounted && !_closed && request == _request) {
      _release();
      setState(() => _supported = false);
    }
  }

  void _startObserving() {
    _observing = true;
    _windowGeometry = _readWindowGeometry();
    WidgetsBinding.instance.addObserver(this);
    // Observe only while a menu is open. A programmatic parent scroll must
    // also dismiss it, since UIKit cannot follow Flutter's composited layers.
    BuildContext? source = widget.selectionContext;
    while (source != null && source.mounted) {
      final scrollable = Scrollable.maybeOf(source);
      if (scrollable == null) break;
      final position = scrollable.position;
      if (!_scrollPositions.contains(position)) {
        _scrollPositions.add(position);
        position.addListener(_dismiss);
      }
      source = scrollable.context;
    }
  }

  @override
  void didChangeMetrics() {
    // UIKit can emit unchanged viewport metrics while paging an edit menu.
    // Closing on those notifications would cancel its own buttons/overflow.
    if (_observing && _readWindowGeometry() != _windowGeometry) _dismiss();
  }

  (Size, double, EdgeInsets, EdgeInsets) _readWindowGeometry() {
    final view = View.of(context);
    return (
      view.physicalSize,
      view.devicePixelRatio,
      EdgeInsets.fromViewPadding(view.viewInsets, 1),
      EdgeInsets.fromViewPadding(view.viewPadding, 1),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _dismiss();
  }

  void _dismiss() {
    if (_closed) return;
    _closed = true;
    _release();
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDismiss();
      });
    } else if (mounted) {
      widget.onDismiss();
    }
  }

  void _release() {
    if (!_observing) return;
    _observing = false;
    WidgetsBinding.instance.removeObserver(this);
    for (final position in _scrollPositions) {
      position.removeListener(_dismiss);
    }
    _scrollPositions.clear();
    if (identical(IosTextSelectionToolbar._active, this)) {
      IosTextSelectionToolbar._active = null;
    }
    unawaited(_hide());
  }

  Future<void> _hide() async {
    try {
      await IosTextSelectionToolbar._channel.invokeMethod<void>('hide', {
        'session': _session,
      });
    } on MissingPluginException {
      // The host may have gone away along with the selection owner.
    } on PlatformException {
      // The Dart owner is already retired, so late actions remain ignored.
    }
  }

  @override
  void dispose() {
    _closed = true;
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _supported == false
      ? AdaptiveTextSelectionToolbar.buttonItems(
          anchors: widget.anchors,
          buttonItems: widget.buttonItems,
        )
      : const SizedBox.shrink();
}
