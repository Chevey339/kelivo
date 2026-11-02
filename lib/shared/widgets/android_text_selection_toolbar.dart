import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Android's floating action mode. Only menu metadata and the selection bounds
/// cross the channel; copy, translation and process-text actions stay in Dart.
class AndroidTextSelectionToolbar extends StatefulWidget {
  const AndroidTextSelectionToolbar({
    super.key,
    required this.anchors,
    required this.buttonItems,
    required this.selectionContext,
    required this.onDismiss,
    this.overflowItems = const {},
    this.keepOpenOnSelectAll = true,
  });

  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> buttonItems;
  final Set<ContextMenuButtonItem> overflowItems;
  final BuildContext selectionContext;
  final VoidCallback onDismiss;

  /// False when Select All replaces callbacks captured from the old selection.
  final bool keepOpenOnSelectAll;

  bool _keepsMenuOpen(ContextMenuButtonItem item) =>
      keepOpenOnSelectAll && item.type == ContextMenuButtonType.selectAll;

  static const _channel = MethodChannel('app.android_selection_menu');
  static _AndroidTextSelectionToolbarState? _active;
  static int _nextSession = 0;

  static Future<void> _handleMethod(MethodCall call) async {
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
        final item = active.widget.buttonItems[index];
        final action = item.onPressed;
        if (action == null) return;
        // EditableText updates its toolbar in place. SelectableRegion replaces
        // it, so callbacks holding the previous selection must retire first.
        if (!active.widget._keepsMenuOpen(item)) active._dismiss();
        action();
      case 'dismissed':
        active._dismiss();
    }
  }

  @override
  State<AndroidTextSelectionToolbar> createState() =>
      _AndroidTextSelectionToolbarState();
}

class _AndroidTextSelectionToolbarState
    extends State<AndroidTextSelectionToolbar>
    with WidgetsBindingObserver {
  final _session = ++AndroidTextSelectionToolbar._nextSession;
  final _scrollPositions = <ScrollPosition>[];
  bool _closed = false;
  bool _scheduled = false;
  bool _observing = false;
  int _revision = 0;
  int _request = 0;
  List<(String, bool, bool, bool)>? _items;
  Rect? _rect;
  (Size, double, EdgeInsets, EdgeInsets)? _windowGeometry;

  @override
  void initState() {
    super.initState();
    AndroidTextSelectionToolbar._channel.setMethodCallHandler(
      AndroidTextSelectionToolbar._handleMethod,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleSync();
  }

  @override
  void didUpdateWidget(AndroidTextSelectionToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_scheduled || _closed) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted && !_closed) unawaited(_sync());
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
    final view = View.of(context);
    final viewport = Offset.zero & (view.physicalSize / view.devicePixelRatio);
    // Some editors use an offscreen primary to request the secondary anchor.
    if (!viewport.contains(primary) && viewport.contains(secondary)) {
      primary = secondary;
    } else if (viewport.contains(primary) && !viewport.contains(secondary)) {
      secondary = primary;
    }
    final bounds = Rect.fromPoints(primary, secondary);
    final scale = view.devicePixelRatio;
    final rect = Rect.fromLTWH(
      bounds.left * scale,
      bounds.top * scale,
      math.max(1, bounds.width * scale),
      math.max(1, bounds.height * scale),
    );
    final items = [
      for (final item in widget.buttonItems)
        (
          AdaptiveTextSelectionToolbar.getButtonLabel(context, item),
          item.onPressed != null,
          widget.overflowItems.contains(item),
          widget._keepsMenuOpen(item),
        ),
    ];
    final itemsChanged = !listEquals(items, _items);
    if (!itemsChanged && rect == _rect) return;
    if (!_observing) {
      AndroidTextSelectionToolbar._active?._dismiss();
      AndroidTextSelectionToolbar._active = this;
      _startObserving();
    }
    if (itemsChanged) _revision++;
    _items = items;
    _rect = rect;
    final request = ++_request;
    bool shown;
    try {
      shown =
          await AndroidTextSelectionToolbar._channel.invokeMethod<bool>(
            'show',
            {
              'session': _session,
              'revision': _revision,
              'rect': [rect.left, rect.top, rect.right, rect.bottom],
              'items': [
                for (final item in items)
                  {
                    'title': item.$1,
                    'enabled': item.$2,
                    'overflow': item.$3,
                    'keepOpen': item.$4,
                  },
              ],
            },
          ) ??
          false;
    } on MissingPluginException {
      shown = false;
    } on PlatformException {
      shown = false;
    }
    if (!shown && mounted && !_closed && request == _request) _dismiss();
  }

  void _startObserving() {
    _observing = true;
    _windowGeometry = _readWindowGeometry();
    WidgetsBinding.instance.addObserver(this);
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
  void didChangeMetrics() {
    if (_observing && _readWindowGeometry() != _windowGeometry) _dismiss();
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
    if (identical(AndroidTextSelectionToolbar._active, this)) {
      AndroidTextSelectionToolbar._active = null;
    }
    unawaited(_hide());
  }

  Future<void> _hide() async {
    try {
      await AndroidTextSelectionToolbar._channel.invokeMethod<void>('hide', {
        'session': _session,
      });
    } on MissingPluginException {
      // The Activity may already have detached from the shared engine.
    } on PlatformException {
      // The owner is retired; late native callbacks are ignored.
    }
  }

  @override
  void dispose() {
    _closed = true;
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _dismiss(),
    child: const SizedBox.expand(),
  );
}
