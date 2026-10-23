import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/services/haptics.dart';
import 'browser_glass.dart';
import 'browser_scroll_configuration.dart';

enum BrowserMenuGroup { navigation, page, library, application }

class BrowserMenuEntry<T> {
  const BrowserMenuEntry({
    required this.value,
    required this.icon,
    required this.label,
    this.group = BrowserMenuGroup.page,
    this.secondary = false,
    this.footer = false,
  });

  final T value;
  final IconData icon;
  final String label;
  final BrowserMenuGroup group;
  final bool secondary;
  final bool footer;
}

/// Acquire the held pointer synchronously, before the overlay's first frame.
/// A quick release or cancellation must not leave the new menu stuck holding
/// a pointer that has already ended.
class _HeldMenuPointer {
  _HeldMenuPointer(this.pointer, this.origin) {
    GestureBinding.instance.pointerRouter.addGlobalRoute(_route);
  }
  final int pointer;
  final Offset origin;
  final _pending = <PointerEvent>[];
  ValueChanged<PointerEvent>? _listener;
  bool _ready = false;
  bool _ended = false;
  bool _disposed = false;

  void _route(PointerEvent event) {
    if (_disposed || _ended || event.pointer != pointer) return;
    if (event is! PointerMoveEvent &&
        event is! PointerUpEvent &&
        event is! PointerCancelEvent) {
      return;
    }
    _ended = event is PointerUpEvent || event is PointerCancelEvent;
    if (_ready) {
      _listener?.call(event);
    } else {
      _pending.add(event);
    }
  }

  void attach(ValueChanged<PointerEvent> listener) {
    _listener = listener;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      _ready = true;
      final events = List<PointerEvent>.of(_pending);
      _pending.clear();
      for (final event in events) {
        if (_disposed) break;
        _listener?.call(event);
      }
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _listener = null;
    _pending.clear();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_route);
  }
}

/// The supplied rect is the actual triggering control in global coordinates.
/// Only the menu moves; its route never transforms the full browser viewport.
Future<T?> showBrowserMenu<T>(
  BuildContext context, {
  required String title,
  required List<BrowserMenuEntry<T>> items,
  required Rect anchorRect,
  required bool desktop,
  Widget? sourceContent,
  Rect? Function()? resolveAnchor,
  VoidCallback? onTransitionStart,
  VoidCallback? onOpened,
  int? heldPointer,
  Offset? pressPosition,
}) {
  final themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context, rootNavigator: true).context,
  );
  final reduced = MediaQuery.disableAnimationsOf(context);
  final contact = !desktop && heldPointer != null
      ? _HeldMenuPointer(heldPointer, pressPosition ?? anchorRect.center)
      : null;
  Rect lastAnchor = anchorRect;
  Rect currentAnchor(Animation<double> animation) {
    if (desktop || animation is! _TouchMenuAnimation || !animation.reversing) {
      return anchorRect;
    }
    final resolved = resolveAnchor?.call();
    if (resolved != null && resolved.isFinite && !resolved.isEmpty) {
      lastAnchor = resolved;
    }
    // Retarget gradually from the opening pose. Switching a 68pt lifted source
    // to its 48pt resting bounds at the first reverse frame would itself jump.
    return Rect.lerp(
      anchorRect,
      lastAnchor,
      Curves.easeInOut.transform(animation.reverseFraction),
    )!;
  }

  Widget panel(
    BuildContext context,
    Animation<double> animation,
    ValueChanged<T?> select,
    VoidCallback? onReady,
    bool transitionStarted,
  ) => themes.wrap(
    Builder(
      builder: (context) {
        final media = MediaQuery.of(context);
        final insets = EdgeInsets.fromLTRB(
          media.padding.left + 10,
          media.padding.top + 10,
          media.padding.right + 10,
          math.max(media.padding.bottom, media.viewInsets.bottom) + 10,
        );
        return AnimatedBuilder(
          animation: animation,
          child: _BrowserMenuPanel<T>(
            title: title,
            items: items,
            desktop: desktop,
            sourceContent: sourceContent,
            animation: animation,
            onSelected: select,
            contact: contact,
            onReady: onReady,
            transitionStarted: transitionStarted,
            sourceSize: () => currentAnchor(animation).size,
            alignBottom:
                !_MenuPosition(
                  anchor: anchorRect,
                  insets: insets,
                  desktop: desktop,
                  progress: 1,
                )._below(
                  Rect.fromLTRB(
                    insets.left,
                    insets.top,
                    media.size.width - insets.right,
                    media.size.height - insets.bottom,
                  ),
                ),
          ),
          builder: (context, child) {
            final progress = _menuProgress(animation, desktop: desktop);
            return CustomSingleChildLayout(
              delegate: _MenuPosition(
                anchor: currentAnchor(animation),
                insets: insets,
                desktop: desktop,
                progress: desktop || (reduced && transitionStarted)
                    ? 1
                    : progress,
              ),
              child: child,
            );
          },
        );
      },
    ),
  );
  if (!desktop) {
    final host = context.findAncestorStateOfType<_BrowserMenuHostState>();
    if (host == null) {
      contact?.dispose();
      throw StateError(
        'Touch browser menus require a BrowserMenuHost ancestor.',
      );
    }
    return host.show<T>(
      title: title,
      reducedMotion: reduced,
      contact: contact,
      onTransitionStart: onTransitionStart,
      onOpened: onOpened,
      builder: panel,
    );
  }
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    // A zero-alpha barrier lets native WebViews receive macOS clicks.
    barrierColor: const Color(0x01000000),
    transitionDuration: Duration(milliseconds: reduced ? 0 : 110),
    pageBuilder: (context, animation, _) => BrowserScrollConfiguration(
      child: panel(
        context,
        animation,
        (value) => Navigator.of(context).pop(value),
        null,
        true,
      ),
    ),
    transitionBuilder: (_, _, _, child) => child,
  );
}

/// Owns touch menus within the browser page. Its portal preserves the held
/// gesture and guarantees that a menu cannot outlive the page that opened it.
class BrowserMenuHost extends StatefulWidget {
  const BrowserMenuHost({super.key, required this.child});
  final Widget child;

  @override
  State<BrowserMenuHost> createState() => _BrowserMenuHostState();
}

class _BrowserMenuHostState extends State<BrowserMenuHost> {
  final _portal = OverlayPortalController();
  WidgetBuilder? _overlayBuilder;
  VoidCallback? _finish;
  bool _disposing = false;

  Future<T?> show<T>({
    required String title,
    required bool reducedMotion,
    required _HeldMenuPointer? contact,
    VoidCallback? onTransitionStart,
    VoidCallback? onOpened,
    required Widget Function(
      BuildContext,
      Animation<double>,
      ValueChanged<T?>,
      VoidCallback,
      bool,
    )
    builder,
  }) {
    _finish?.call();
    final result = Completer<T?>();
    final overlayKey = GlobalKey<_TouchMenuOverlayState>();
    final previousFocus = FocusManager.instance.primaryFocus;
    LocalHistoryEntry? history;
    var closing = false;
    var removed = false;
    T? selected;

    void finish() {
      if (removed) return;
      removed = true;
      closing = true;
      overlayKey.currentState?.cancelPendingStart();
      contact?.dispose();
      history?.remove();
      if (!result.isCompleted) result.complete(_disposing ? null : selected);
      _finish = null;
      if (_disposing) return;
      _portal.hide();
      setState(() => _overlayBuilder = null);
      if (previousFocus?.context != null) previousFocus!.requestFocus();
    }

    void select(T? value) {
      if (closing || removed) return;
      closing = true;
      history?.remove();
      selected = value;
      if (overlayKey.currentState case final state?) {
        state.close();
      } else {
        finish();
      }
    }

    history = LocalHistoryEntry(onRemove: () => select(null));
    ModalRoute.of(context)?.addLocalHistoryEntry(history);
    _finish = finish;
    setState(() {
      _overlayBuilder = (context) => _TouchMenuOverlay(
        key: overlayKey,
        reducedMotion: reducedMotion,
        title: title,
        onDismiss: () => select(null),
        onClosed: finish,
        onTransitionStart: onTransitionStart,
        onOpened: onOpened,
        builder: (context, animation, onReady, started) =>
            builder(context, animation, select, onReady, started),
      );
    });
    _portal.show();
    return result.future;
  }

  @override
  void dispose() {
    _disposing = true;
    // Complete pending callers and detach the pointer/history synchronously.
    // Portal descendants are disposed by Flutter; never reverse their ticker
    // or mutate the portal while this host is being removed.
    _finish?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    overlayLocation: OverlayChildLocation.rootOverlay,
    controller: _portal,
    overlayChildBuilder: (context) =>
        _overlayBuilder?.call(context) ?? const SizedBox.shrink(),
    child: widget.child,
  );
}

class _TouchMenuOverlay extends StatefulWidget {
  const _TouchMenuOverlay({
    super.key,
    required this.reducedMotion,
    required this.title,
    required this.onDismiss,
    required this.onClosed,
    this.onTransitionStart,
    this.onOpened,
    required this.builder,
  });
  final bool reducedMotion;
  final String title;
  final VoidCallback onDismiss, onClosed;
  final VoidCallback? onTransitionStart;
  final VoidCallback? onOpened;
  final Widget Function(BuildContext, Animation<double>, VoidCallback, bool)
  builder;

  @override
  State<_TouchMenuOverlay> createState() => _TouchMenuOverlayState();
}

class _TouchMenuOverlayState extends State<_TouchMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.reducedMotion ? 0 : 250),
  );

  late final _motion = _TouchMenuAnimation(_animation);
  bool _started = false;
  bool _closing = false;
  bool _startScheduled = false;

  void _onReady() {
    if (!mounted || _closing || _started || _startScheduled) return;
    void start() {
      if (!mounted || _closing || _started) return;
      setState(() => _started = true);
      widget.onTransitionStart?.call();
      if (mounted && !_closing) {
        _animation.forward().whenCompleteOrCancel(() {
          if (mounted && !_closing && _animation.isCompleted) {
            widget.onOpened?.call();
          }
        });
      }
    }

    _startScheduled = true;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      start();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => start());
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  void cancelPendingStart() => _closing = true;

  void close() {
    if (_closing) return;
    _closing = true;
    if (!_started) {
      widget.onClosed();
      return;
    }
    _motion.beginReverse();
    _animation.reverse().whenCompleteOrCancel(widget.onClosed);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusScope(
    autofocus: true,
    child: BlockSemantics(
      child: Stack(
        children: [
          ModalBarrier(
            color: const Color(0x01000000),
            dismissible: true,
            semanticsLabel: widget.title,
            onDismiss: widget.onDismiss,
          ),
          widget.builder(context, _motion, _onReady, _started),
        ],
      ),
    ),
  );
}

/// Keep the visible morph continuous when dismissing before opening finishes.
/// The underlying controller still owns timing and ticker disposal.
class _TouchMenuAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  _TouchMenuAnimation(this.parent);
  @override
  final AnimationController parent;
  double? _reverseStart;
  double? _reverseProgress;

  bool get reversing => _reverseStart != null;
  double get reverseFraction {
    final start = _reverseStart;
    if (start == null) return 0;
    return start == 0 ? 1 : (1 - parent.value / start).clamp(0.0, 1.0);
  }

  void beginReverse() {
    _reverseProgress = value;
    _reverseStart = parent.value;
  }

  @override
  double get value {
    final start = _reverseStart;
    if (start == null) {
      return _motionProgress(
        parent.value,
        desktop: false,
        reverse: false,
      ).clamp(0.0, 1.0);
    }
    if (start == 0) return 0;
    final remaining = (parent.value / start).clamp(0.0, 1.0);
    return _reverseProgress! *
        _motionProgress(remaining, desktop: false, reverse: true);
  }
}

double _menuProgress(Animation<double> animation, {required bool desktop}) =>
    animation is _TouchMenuAnimation
    ? animation.value
    : _motionProgress(
        animation.value,
        desktop: desktop,
        reverse: animation.status == AnimationStatus.reverse,
      );

final _mobileSpring = SpringSimulation(
  SpringDescription.withDampingRatio(mass: 1, stiffness: 700, ratio: .9),
  0,
  1,
  0,
);

double _motionProgress(
  double value, {
  required bool desktop,
  required bool reverse,
}) {
  if (value == 0 || value == 1) return value;
  if (reverse) {
    // Closing must respond immediately and settle at the button. Evaluating
    // the opening curve backwards would linger at full size then snap shut.
    return 1 - _motionProgress(1 - value, desktop: desktop, reverse: false);
  }
  if (desktop) return Curves.easeOutCubic.transform(value);
  // A small spatial spring, not a large scale-up of the entire overlay.
  return _mobileSpring.x(value * .25) / _mobileSpring.x(.25);
}

class _MenuPosition extends SingleChildLayoutDelegate {
  const _MenuPosition({
    required this.anchor,
    required this.insets,
    required this.desktop,
    required this.progress,
  });

  final Rect anchor;
  final EdgeInsets insets;
  final bool desktop;
  final double progress;
  static const double _gap = 7;

  Rect _available(Size size) => Rect.fromLTRB(
    insets.left,
    insets.top,
    math.max(insets.left, size.width - insets.right),
    math.max(insets.top, size.height - insets.bottom),
  );

  bool _below(Rect available) {
    final below = desktop
        ? available.bottom - anchor.bottom - _gap
        : available.bottom - anchor.top;
    final above = desktop
        ? anchor.top - available.top - _gap
        : anchor.bottom - available.top;
    final preferred = desktop ? below : above;
    final alternate = desktop ? above : below;
    if (preferred >= math.min(300, available.height * .55)) return desktop;
    return preferred >= alternate ? desktop : !desktop;
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final available = _available(constraints.biggest);
    final below = _below(available);
    final space = below
        ? available.bottom - (desktop ? anchor.bottom + _gap : anchor.top)
        : (desktop ? anchor.top - _gap : anchor.bottom) - available.top;
    final width = math.min(
      desktop ? 256.0 : math.max(250.0, anchor.width),
      available.width,
    );
    return BoxConstraints(
      minWidth: desktop ? width : 0,
      maxWidth: width,
      maxHeight: math.max(0, math.min(available.height, math.max(80, space))),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final available = _available(size);
    final below = _below(available);
    final x = (anchor.right - childSize.width).clamp(
      available.left,
      math.max(available.left, available.right - childSize.width),
    );
    final y =
        (below
                ? (desktop ? anchor.bottom + _gap : anchor.top)
                : (desktop ? anchor.top - _gap : anchor.bottom) -
                      childSize.height)
            .clamp(
              available.top,
              math.max(available.top, available.bottom - childSize.height),
            );
    // The small lens lifts off the trigger, then settles into the panel. The
    // same spatial path brings it back to the trigger on dismissal.
    if (!desktop) {
      final lift = 48 * math.sin(math.pi * progress);
      return Offset(
        x.toDouble(),
        (y + (below ? lift : -lift)).clamp(
          available.top,
          math.max(available.top, available.bottom - childSize.height),
        ),
      );
    }
    final travel = 3.0 * (1 - progress);
    return Offset(x.toDouble(), y + (below ? -travel : travel));
  }

  @override
  bool shouldRelayout(_MenuPosition oldDelegate) =>
      anchor != oldDelegate.anchor ||
      insets != oldDelegate.insets ||
      desktop != oldDelegate.desktop ||
      progress != oldDelegate.progress;
}

class _BrowserMenuPanel<T> extends StatefulWidget {
  const _BrowserMenuPanel({
    required this.title,
    required this.items,
    required this.desktop,
    required this.animation,
    this.sourceContent,
    required this.sourceSize,
    required this.alignBottom,
    required this.onSelected,
    this.contact,
    this.onReady,
    this.transitionStarted = true,
  });

  final Animation<double> animation;
  final Size Function() sourceSize;
  final bool alignBottom;
  final String title;
  final List<BrowserMenuEntry<T>> items;
  final bool desktop;
  final Widget? sourceContent;
  final ValueChanged<T?> onSelected;
  final _HeldMenuPointer? contact;
  final VoidCallback? onReady;
  final bool transitionStarted;

  @override
  State<_BrowserMenuPanel<T>> createState() => _BrowserMenuPanelState<T>();
}

class _MenuTarget {
  const _MenuTarget(
    this.key,
    this.activate, {
    required this.secondary,
    this.submenu = false,
  });
  final GlobalKey key;
  final VoidCallback activate;
  final bool submenu;
  final bool secondary;
}

class _SubmenuPosition extends SingleChildLayoutDelegate {
  const _SubmenuPosition({
    required this.parent,
    required this.source,
    required this.insets,
    required this.desktop,
    required this.progress,
    required this.rootProgress,
  });
  final Rect parent, source;
  final EdgeInsets insets;
  final bool desktop;
  final double progress;
  final double rootProgress;

  Rect _available(Size size) => Rect.fromLTRB(
    insets.left,
    insets.top,
    math.max(insets.left, size.width - insets.right),
    math.max(insets.top, size.height - insets.bottom),
  );

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final available = _available(constraints.biggest);
    final width = math.min(desktop ? 256.0 : 250.0, available.width);
    return BoxConstraints(
      minWidth: desktop ? width : 0,
      maxWidth: width,
      maxHeight: available.height,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final available = _available(size);
    final rightSpace = available.right - parent.right;
    final leftSpace = parent.left - available.left;
    final right = rightSpace >= childSize.width + 7 || rightSpace >= leftSpace;
    final x = desktop
        ? (right ? parent.right + 7 : parent.left - childSize.width - 7)
        : parent.center.dx - childSize.width / 2;
    // Align the child header with the row that opened it. During whole-menu
    // dismissal the two material layers converge on the same source lens.
    final y = desktop
        ? source.top - 6
        : ui.lerpDouble(parent.top, source.top - 8, rootProgress)!;
    final travel = (desktop ? 3 : 12) * (1 - progress);
    final top = available.top;
    final bottom = math.max(top, available.bottom - childSize.height);
    return Offset(
      x.clamp(
        available.left,
        math.max(available.left, available.right - childSize.width),
      ),
      desktop ? y.clamp(top, bottom) + travel : (y + travel).clamp(top, bottom),
    );
  }

  @override
  bool shouldRelayout(_SubmenuPosition oldDelegate) =>
      parent != oldDelegate.parent ||
      source != oldDelegate.source ||
      insets != oldDelegate.insets ||
      desktop != oldDelegate.desktop ||
      progress != oldDelegate.progress ||
      rootProgress != oldDelegate.rootProgress;
}

class _BrowserMenuPanelState<T> extends State<_BrowserMenuPanel<T>>
    with TickerProviderStateMixin {
  bool _secondary = false;
  bool _submenuMounted = false;
  bool _submenuReady = false;
  bool _disposing = false;
  final _submenuPortal = OverlayPortalController();
  late final _submenuAnimation = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.desktop ? 110 : 200),
  );
  late final _submenuMotion = CurvedAnimation(
    parent: _submenuAnimation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInOutCubic,
  );
  LocalHistoryEntry? _submenuHistory;
  Timer? _hoverOpenTimer;
  Timer? _hoverCloseTimer;
  Offset? _corridorOrigin;
  final _keys = <Object, GlobalKey>{};
  final _targets = <GlobalKey, _MenuTarget>{};
  final _backKey = Object();
  final _submenuKey = Object();
  final _primaryFocus = FocusNode();
  final _submenuSourceFocus = FocusNode();
  final _surfaceKey = GlobalKey();
  final _selectionSpace = GlobalKey();
  final _submenuSurfaceKey = GlobalKey();
  final _submenuSelectionSpace = GlobalKey();
  GlobalKey? _highlighted;
  GlobalKey? _desktopHoverPrimary;
  GlobalKey? _desktopHoverSecondary;
  Rect? _selectionRect;
  bool _selectionIsSecondary = false;
  final _scroll = ScrollController();
  final _submenuScroll = ScrollController();
  _HeldMenuPointer? _selectionContact;
  bool _sourceHeld = false;
  bool get _canScroll {
    final scroll = _secondary ? _submenuScroll : _scroll;
    return scroll.hasClients && scroll.position.maxScrollExtent > 0;
  }

  bool _scrolling = false;
  bool _needsSubmenuMove = false;
  Offset _pointerOrigin = Offset.zero;
  Offset _pointerPosition = Offset.zero;
  int? _pointer;
  bool _moved = false;
  Timer? _submenuTimer;

  @override
  void initState() {
    super.initState();
    _pointer = widget.contact?.pointer;
    _sourceHeld = _pointer != null;
    _pointerOrigin = widget.contact?.origin ?? Offset.zero;
    widget.contact?.attach(_trackPointer);
    if (widget.desktop) {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_trackHover);
    }
  }

  void _beginSelection(PointerDownEvent event) {
    if (widget.desktop ||
        _pointer != null ||
        _targetAt(event.position) == null) {
      return;
    }
    _sourceHeld = false;
    _pointer = event.pointer;
    _pointerOrigin = _pointerPosition = event.position;
    _moved = false;
    _needsSubmenuMove = false;
    _selectionContact?.dispose();
    _selectionContact = _HeldMenuPointer(event.pointer, event.position)
      ..attach(_trackPointer);
    _highlightAt(event.position);
  }

  void _clearSelection() {
    _pointer = null;
    _scrolling = false;
    _submenuTimer?.cancel();
    _selectionContact?.dispose();
    _selectionContact = null;
    setState(() => _highlighted = null);
  }

  void _trackPointer(PointerEvent event) {
    if (event.pointer != _pointer || !mounted) return;
    _pointerPosition = event.position;
    if (_scrolling) {
      if (event is PointerUpEvent || event is PointerCancelEvent) {
        _clearSelection();
      }
      return;
    }
    if (event is PointerMoveEvent) {
      final delta = event.position - _pointerOrigin;
      if (!_sourceHeld &&
          _canScroll &&
          delta.dy.abs() > kTouchSlop &&
          delta.dy.abs() > delta.dx.abs()) {
        // A vertically scrollable menu keeps Flutter's normal drag recognizer.
        // This passive listener never claims its gesture arena.
        _scrolling = true;
        _submenuTimer?.cancel();
        setState(() => _highlighted = null);
        return;
      }
      _moved = _moved || delta.distance > 8;
      if (!_moved) return;
      _highlightAt(event.position);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      final choose =
          event is PointerUpEvent &&
          (_sourceHeld ? _moved : (!_needsSubmenuMove || _moved));
      final target = choose ? _targetAt(event.position) : null;
      final dismiss = _sourceHeld && (choose || event is PointerCancelEvent);
      _clearSelection();
      if (target != null) {
        target.activate();
      } else if (dismiss) {
        widget.onSelected(null);
      }
    }
  }

  _MenuTarget? _targetAt(Offset global) {
    // Ignore content while it is still a small blurred lens. Row coordinates
    // include the menu's live opening morph, not its final layout.
    if (widget.animation.value < .7) return null;
    if (_secondary && _submenuAnimation.value < .7) return null;
    final surface = (_secondary ? _submenuSurfaceKey : _surfaceKey)
        .currentContext
        ?.findRenderObject();
    if (surface is! RenderBox || !surface.hasSize) return null;
    final point = surface.globalToLocal(global);
    if (!RRect.fromRectAndRadius(
      Offset.zero & surface.size,
      const Radius.circular(25),
    ).contains(point)) {
      return null;
    }
    for (final target in _targets.values) {
      if (target.secondary != _secondary) continue;
      final box = target.key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      if ((Offset.zero & box.size).contains(box.globalToLocal(global))) {
        return target;
      }
    }
    return null;
  }

  void _highlightAt(Offset point) {
    final target = _targetAt(point);
    if (_highlighted == target?.key) return;
    _submenuTimer?.cancel();
    Rect? rect;
    final row = target?.key.currentContext?.findRenderObject();
    final space = (_secondary ? _submenuSelectionSpace : _selectionSpace)
        .currentContext
        ?.findRenderObject();
    if (row is RenderBox &&
        space is RenderBox &&
        row.hasSize &&
        space.hasSize) {
      final bounds = Rect.fromPoints(
        space.globalToLocal(row.localToGlobal(Offset.zero)),
        space.globalToLocal(
          row.localToGlobal(row.size.bottomRight(Offset.zero)),
        ),
      );
      final inset = math.min(4.0, bounds.width / 2);
      rect = Rect.fromLTRB(
        bounds.left + inset,
        bounds.top,
        bounds.right - inset,
        bounds.bottom,
      );
    }
    setState(() {
      _highlighted = target?.key;
      _selectionIsSecondary = _secondary;
      if (rect != null) _selectionRect = rect;
    });
    if (target != null) Haptics.soft();
    if (target?.submenu == true) {
      _submenuTimer = Timer(const Duration(milliseconds: 350), () {
        if (!mounted || _pointer == null || _highlighted != target!.key) return;
        // Navigation is safe while held; actions execute only on release.
        _moved = false;
        _needsSubmenuMove = true;
        _pointerOrigin = _pointerPosition;
        _highlighted = null;
        _selectionRect = null;
        target.activate();
      });
    }
  }

  @override
  void dispose() {
    _disposing = true;
    _hoverOpenTimer?.cancel();
    _hoverCloseTimer?.cancel();
    _submenuHistory?.remove();
    if (widget.desktop) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_trackHover);
    }
    _submenuMotion.dispose();
    _submenuAnimation.dispose();
    _primaryFocus.dispose();
    _submenuSourceFocus.dispose();
    _submenuTimer?.cancel();
    _selectionContact?.dispose();
    _scroll.dispose();
    _submenuScroll.dispose();
    super.dispose();
  }

  void _back({bool restoreSourceFocus = true}) {
    if (!_secondary || _disposing) return;
    _hoverOpenTimer?.cancel();
    _hoverCloseTimer?.cancel();
    final history = _submenuHistory;
    _submenuHistory = null;
    setState(() {
      _secondary = false;
      _highlighted = null;
      _selectionRect = null;
    });
    history?.remove();
    if (restoreSourceFocus) {
      _submenuSourceFocus.requestFocus();
    } else if (_desktopHoverPrimary == null) {
      // A pointer exit must not reselect the source row. Keep keyboard
      // dismissal available on the menu when the pointer left both panels.
      _primaryFocus.requestFocus();
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _submenuAnimation.value = 0;
    } else {
      _submenuAnimation.reverse();
    }
    // Keep both passive material hosts mounted until this whole menu closes.
    // Removing one under a live OS pointer can cancel that pointer on iOS.
  }

  void _openSubmenu() {
    if (!mounted ||
        _secondary ||
        !widget.transitionStarted ||
        widget.animation.value < .7 ||
        widget.animation.status == AnimationStatus.reverse ||
        !widget.items.any((entry) => entry.secondary)) {
      return;
    }
    _hoverOpenTimer?.cancel();
    _hoverCloseTimer?.cancel();
    setState(() {
      _secondary = true;
      _submenuMounted = true;
      _highlighted = null;
      _selectionRect = null;
    });
    if (!widget.desktop) {
      _submenuHistory = LocalHistoryEntry(onRemove: _back);
      ModalRoute.of(context)?.addLocalHistoryEntry(_submenuHistory!);
    }
    _submenuPortal.show();
    if (_submenuReady) _startSubmenu();
  }

  void _startSubmenu() {
    if (!mounted) return;
    _submenuReady = true;
    if (!_secondary || widget.animation.status == AnimationStatus.reverse) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _submenuAnimation.value = 1;
    } else {
      _submenuAnimation.forward();
    }
  }

  Rect? _bounds(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }

  void _hoverSubmenuSource(bool entered, Offset position) {
    if (!widget.desktop) return;
    if (entered) {
      _corridorOrigin = position;
      _hoverCloseTimer?.cancel();
      _hoverOpenTimer?.cancel();
      if (!_secondary) {
        _hoverOpenTimer = Timer(
          const Duration(milliseconds: 160),
          _openSubmenu,
        );
      }
    } else {
      _hoverOpenTimer?.cancel();
      if (!_protectsHover(position)) _scheduleHoverClose();
    }
  }

  void _scheduleHoverClose() {
    if (!_secondary || _hoverCloseTimer?.isActive == true) return;
    _hoverCloseTimer = Timer(
      const Duration(milliseconds: 320),
      () => _back(restoreSourceFocus: false),
    );
  }

  void _trackHover(PointerEvent event) {
    if (!mounted || event is! PointerHoverEvent || !_secondary) return;
    if (_protectsHover(event.position)) {
      _hoverCloseTimer?.cancel();
    } else {
      _scheduleHoverClose();
    }
  }

  bool _protectsHover(Offset point) {
    final sourceKey = _keys[_submenuKey];
    final source = sourceKey == null ? null : _bounds(sourceKey);
    final menu = _bounds(_submenuSurfaceKey);
    if (source == null || menu == null) return false;
    if (source.contains(point)) {
      _corridorOrigin = point;
      return true;
    }
    if (menu.inflate(4).contains(point)) return true;
    final origin = _corridorOrigin ?? source.center;
    final edge = menu.center.dx > source.center.dx ? menu.left : menu.right;
    final corridor = Path()
      ..moveTo(origin.dx, origin.dy)
      ..lineTo(edge, menu.top - 12)
      ..lineTo(edge, menu.bottom + 12)
      ..close();
    return corridor.contains(point);
  }

  Widget _contents(BuildContext context, {required bool secondary}) {
    final colors = Theme.of(context).colorScheme;
    final appTextStyle = Theme.of(context).textTheme.bodyMedium!;
    final l = AppLocalizations.of(context)!;
    final reduced = MediaQuery.disableAnimationsOf(context);
    Widget row({
      required Object id,
      required String label,
      required IconData icon,
      required VoidCallback activate,
      String? semanticLabel,
      IconData? trailing,
      bool vertical = false,
      bool autofocus = false,
      bool submenu = false,
    }) {
      final key = _keys.putIfAbsent(id, GlobalKey.new);
      _targets[key] = _MenuTarget(
        key,
        activate,
        secondary: secondary,
        submenu: submenu,
      );
      return _MenuRow(
        key: key,
        label: label,
        semanticLabel: semanticLabel,
        icon: icon,
        trailing: trailing,
        desktop: widget.desktop,
        vertical: vertical,
        autofocus: autofocus,
        selected:
            _highlighted == key ||
            (widget.desktop &&
                (secondary ? _desktopHoverSecondary : _desktopHoverPrimary) ==
                    key) ||
            (id == _submenuKey && _secondary && _desktopHoverPrimary == null),
        onTap: activate,
        onHover: widget.desktop
            ? (entered, position) {
                final previous = secondary
                    ? _desktopHoverSecondary
                    : _desktopHoverPrimary;
                if (entered && previous != key || !entered && previous == key) {
                  setState(() {
                    if (secondary) {
                      _desktopHoverSecondary = entered ? key : null;
                    } else {
                      _desktopHoverPrimary = entered ? key : null;
                    }
                  });
                }
                if (id == _submenuKey) _hoverSubmenuSource(entered, position);
              }
            : null,
        focusNode: id == _submenuKey ? _submenuSourceFocus : null,
      );
    }

    final footer = widget.desktop || secondary
        ? <BrowserMenuEntry<T>>[]
        : widget.items
              .where((entry) => entry.footer && !entry.secondary)
              .take(3)
              .toList();
    final entries = widget.items
        .where(
          (entry) => entry.secondary == secondary && !footer.contains(entry),
        )
        .toList();
    final groups = <List<Widget>>[];
    if (secondary && !widget.desktop) {
      groups.add([
        row(
          id: _backKey,
          label: l.browserPageOptions,
          semanticLabel: '${l.browserBack}: ${l.browserPageOptions}',
          icon: LucideIcons.chevronLeft,
          autofocus: true,
          activate: _back,
          submenu: true,
        ),
      ]);
    }
    for (final group in BrowserMenuGroup.values) {
      final rows = <Widget>[
        for (final entry in entries.where((entry) => entry.group == group))
          row(
            id: entry,
            label: entry.label,
            icon: entry.icon,
            autofocus: secondary && widget.desktop && entry == entries.first,
            activate: () => widget.onSelected(entry.value),
          ),
        if (!secondary &&
            widget.items.any((entry) => entry.secondary) &&
            group == BrowserMenuGroup.page)
          row(
            id: _submenuKey,
            label: l.browserPageOptions,
            icon: LucideIcons.panelTop,
            trailing: LucideIcons.chevronRight,
            activate: _openSubmenu,
            submenu: true,
          ),
      ];
      if (rows.isNotEmpty) groups.add(rows);
    }
    if (footer.isNotEmpty) {
      groups.add([
        Row(
          children: [
            for (final entry in footer)
              Expanded(
                child: row(
                  id: entry,
                  label: entry.label,
                  icon: entry.icon,
                  vertical: true,
                  activate: () => widget.onSelected(entry.value),
                ),
              ),
          ],
        ),
      ]);
    }
    final rect = _selectionIsSecondary == secondary ? _selectionRect : null;
    return SelectionContainer.disabled(
      child: DecoratedBox(
        // AppKit's FlutterCursorCoordinator restores Flutter's cursor only
        // over actual foreground paint regions above a platform view. Keep
        // glyphs, row gaps and padding in one region; MouseRegion alone does
        // not affect those compositor regions. This paint is above, never an
        // opacity/clip ancestor of, the native material.
        key: ValueKey(
          secondary
              ? 'browserSubmenuCursorFootprint'
              : 'browserMenuCursorFootprint',
        ),
        decoration: BoxDecoration(
          color: widget.desktop ? const Color(0x01000000) : Colors.transparent,
          borderRadius: BorderRadius.circular(widget.desktop ? 16 : 25),
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            fontFamily: appTextStyle.fontFamily,
            fontFamilyFallback: appTextStyle.fontFamilyFallback,
            color: colors.onSurface,
            fontSize: widget.desktop ? 13 : 16,
            decoration: TextDecoration.none,
          ),
          child: SingleChildScrollView(
            controller: secondary ? _submenuScroll : _scroll,
            child: Padding(
              padding: EdgeInsets.all(widget.desktop ? 6 : 8),
              child: Stack(
                key: secondary ? _submenuSelectionSpace : _selectionSpace,
                children: [
                  if (rect != null)
                    AnimatedPositioned(
                      duration: Duration(milliseconds: reduced ? 0 : 160),
                      curve: Curves.easeInOut,
                      left: rect.left,
                      top: rect.top,
                      width: rect.width,
                      height: rect.height,
                      child: IgnorePointer(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: _highlighted == null ? 0 : 1,
                          ),
                          duration: Duration(milliseconds: reduced ? 0 : 200),
                          curve: Curves.easeInOut,
                          builder: (context, value, child) => value == 0
                              ? const SizedBox.expand()
                              : Opacity(opacity: value, child: child),
                          child: DecoratedBox(
                            key: const ValueKey('browserMenuSelection'),
                            decoration: BoxDecoration(
                              color: colors.onSurface.withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(
                                math.min(
                                  20,
                                  math.min(rect.width, rect.height) / 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < groups.length; index++) ...[
                        if (index > 0)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: widget.desktop ? 8 : 4,
                            ),
                            child: SizedBox(
                              height: .5,
                              child: ColoredBox(
                                color: colors.onSurface.withValues(alpha: .12),
                              ),
                            ),
                          ),
                        ...groups[index],
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _keyboard(Widget child, {bool secondary = false}) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (_secondary) {
          _back();
        } else {
          widget.onSelected(null);
        }
      },
      const SingleActivator(LogicalKeyboardKey.arrowLeft): _back,
      if (!secondary)
        const SingleActivator(LogicalKeyboardKey.arrowRight): _openSubmenu,
    },
    child: Focus(
      focusNode: secondary ? null : _primaryFocus,
      autofocus: true,
      child: FocusTraversalGroup(
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
            SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
          },
          child: child,
        ),
      ),
    ),
  );

  Widget _primarySurface(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = RepaintBoundary(
          child: SizedBox(
            width: constraints.maxWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: constraints.maxHeight),
              child: _contents(context, secondary: false),
            ),
          ),
        );
        return AnimatedBuilder(
          animation: Listenable.merge([widget.animation, _submenuMotion]),
          child: IgnorePointer(
            ignoring:
                !widget.transitionStarted ||
                (_sourceHeld && _pointer != null) ||
                (!widget.desktop && _secondary),
            child: ExcludeSemantics(
              excluding: !widget.desktop && _secondary,
              child: ExcludeFocus(
                excluding: !widget.desktop && _secondary,
                child: content,
              ),
            ),
          ),
          builder: (context, child) {
            final progress = !widget.transitionStarted
                ? 0.0
                : reduced
                ? 1.0
                : _menuProgress(
                    widget.animation,
                    desktop: widget.desktop,
                  ).clamp(0.0, 1.0);
            final sourceSize = widget.sourceSize();
            final currentWidth =
                sourceSize.width +
                (constraints.maxWidth - sourceSize.width) * progress;
            final corners = _smoothRange(progress, .85, 1);
            final radius = widget.desktop
                ? 16.0
                : corners == 0
                ? 1000.0
                : currentWidth / 2 + (25 - currentWidth / 2) * corners;
            final sigma = 8 * (1 - _smoothRange(progress, .7, 1));
            final depth = widget.desktop
                ? 0.0
                : _submenuMotion.value * progress;
            return Transform.translate(
              offset: Offset(0, -14 * depth),
              child: Transform.scale(
                key: const ValueKey('browserMenuParentDepth'),
                scale: 1 - .06 * depth,
                alignment: widget.alignBottom
                    ? Alignment.bottomCenter
                    : Alignment.topCenter,
                child: KeyedSubtree(
                  key: _surfaceKey,
                  child: BrowserGlass(
                    key: const ValueKey('browserMenuSurface'),
                    radius: radius,
                    opacity: !widget.transitionStarted
                        ? 0
                        : widget.desktop
                        ? progress
                        : 1,
                    onReady: widget.onReady,
                    child: widget.desktop
                        ? child!
                        : Stack(
                            children: [
                              _MenuMorph(
                                progress: progress,
                                initialSize: sourceSize,
                                radius: radius,
                                child: ImageFiltered(
                                  key: const ValueKey('browserMenuContentBlur'),
                                  // Android already composites the WebView
                                  // and menu on competing render paths. Keep
                                  // the geometry/fade, without an extra large
                                  // offscreen blur of the menu's sharp text.
                                  enabled:
                                      Theme.of(context).platform !=
                                          TargetPlatform.android &&
                                      sigma > .01,
                                  imageFilter: ui.ImageFilter.blur(
                                    sigmaX: sigma,
                                    sigmaY: sigma,
                                  ),
                                  child: Opacity(
                                    opacity: _smoothRange(progress, .1, .5),
                                    child: Opacity(
                                      key: const ValueKey(
                                        'browserMenuParentContent',
                                      ),
                                      opacity: 1 - .28 * depth,
                                      child: child,
                                    ),
                                  ),
                                ),
                              ),
                              if (widget.transitionStarted && progress < .25)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity:
                                          1 - _smoothRange(progress, 0, .25),
                                      child: Center(
                                        child: ExcludeSemantics(
                                          child: SizedBox.fromSize(
                                            size: sourceSize,
                                            child: Center(
                                              child:
                                                  widget.sourceContent ??
                                                  Icon(
                                                    LucideIcons.ellipsis,
                                                    size: 22,
                                                    color: colors.onSurface,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSubmenu(BuildContext context) {
    if (!_submenuMounted) return const SizedBox.shrink();
    final media = MediaQuery.of(context);
    final child = _keyboard(
      MouseRegion(
        cursor: SystemMouseCursors.basic,
        onEnter: (_) => _hoverCloseTimer?.cancel(),
        onExit: (event) {
          if (!_protectsHover(event.position)) _scheduleHoverClose();
        },
        child: Listener(
          onPointerDown: _beginSelection,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: _contents(context, secondary: true),
          ),
        ),
      ),
      secondary: true,
    );
    return AnimatedBuilder(
      animation: Listenable.merge([widget.animation, _submenuMotion]),
      child: child,
      builder: (context, child) {
        final rootProgress = _menuProgress(
          widget.animation,
          desktop: widget.desktop,
        ).clamp(0.0, 1.0);
        final p = _submenuMotion.value;
        final sourceKey = _keys[_submenuKey];
        final parent = _bounds(_surfaceKey) ?? Rect.zero;
        final source = sourceKey == null
            ? parent
            : _bounds(sourceKey) ?? parent;
        return ExcludeSemantics(
          excluding: !_secondary,
          child: ExcludeFocus(
            excluding: !_secondary,
            child: IgnorePointer(
              ignoring:
                  !_secondary || p < .7 || (_sourceHeld && _pointer != null),
              child: CustomSingleChildLayout(
                delegate: _SubmenuPosition(
                  parent: parent,
                  source: source,
                  desktop: widget.desktop,
                  progress: p,
                  rootProgress: rootProgress,
                  insets: EdgeInsets.fromLTRB(
                    media.padding.left + 10,
                    media.padding.top + 10,
                    media.padding.right + 10,
                    math.max(media.padding.bottom, media.viewInsets.bottom) +
                        10,
                  ),
                ),
                child: Transform.scale(
                  scale: widget.desktop ? 1 : .96 + .04 * p,
                  alignment: Alignment.bottomCenter,
                  child: KeyedSubtree(
                    key: _submenuSurfaceKey,
                    child: BrowserGlass(
                      key: const ValueKey('browserSubmenuSurface'),
                      radius: widget.desktop ? 16 : 25,
                      opacity: (p * rootProgress).clamp(0.0, 1.0),
                      onReady: _startSubmenu,
                      child: widget.desktop
                          ? child!
                          : _MenuMorph(
                              progress: rootProgress,
                              initialSize: widget.sourceSize(),
                              radius: 25,
                              child: Opacity(
                                key: const ValueKey('browserSubmenuContent'),
                                opacity: _smoothRange(p, .35, 1),
                                child: child!,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _submenuPortal,
    overlayLocation: OverlayChildLocation.rootOverlay,
    overlayChildBuilder: _buildSubmenu,
    child: MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: _keyboard(
        Semantics(
          namesRoute: true,
          label: widget.title,
          child: Listener(
            onPointerDown: _beginSelection,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_secondary && !widget.desktop) _back();
              },
              child: _primarySurface(context),
            ),
          ),
        ),
      ),
    ),
  );
}

// The child surface occludes its parent through normal compositing. Do not
// punch a second hole in the parent's text using a sibling portal's geometry:
// that geometry and the native backdrop can reach the display in different
// frames, erasing rows that are still outside the visible child panel.

/// Menu selection uses a quiet highlight and keyboard focus, without dragging,
/// elastic scaling or Material ink. Desktop menus must stay stationary.
class _MenuRow extends StatefulWidget {
  const _MenuRow({
    super.key,
    required this.label,
    required this.icon,
    required this.desktop,
    required this.onTap,
    this.semanticLabel,
    this.trailing,
    this.autofocus = false,
    this.vertical = false,
    this.selected = false,
    this.onHover,
    this.focusNode,
  });

  final String label;
  final String? semanticLabel;
  final IconData icon;
  final IconData? trailing;
  final bool desktop;
  final bool autofocus;
  final bool vertical;
  final bool selected;
  final VoidCallback onTap;
  final void Function(bool entered, Offset position)? onHover;
  final FocusNode? focusNode;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  final _ownedFocus = FocusNode();
  FocusNode get _focus => widget.focusNode ?? _ownedFocus;
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  @override
  void dispose() {
    _ownedFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final highlighted = _pressed || _hovered || _focused || widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (event) {
        if (widget.desktop) _focus.requestFocus();
        widget.onHover?.call(true, event.position);
      },
      onHover: (event) => widget.onHover?.call(true, event.position),
      onExit: (event) => widget.onHover?.call(false, event.position),
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: widget.semanticLabel ?? widget.label,
        excludeSemantics: true,
        onTap: widget.onTap,
        child: FocusableActionDetector(
          focusNode: _focus,
          autofocus: widget.autofocus,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          onShowHoverHighlight: (value) => setState(() => _hovered = value),
          mouseCursor: SystemMouseCursors.basic,
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: widget.desktop
                ? (_) => setState(() => _pressed = true)
                : null,
            onTapCancel: widget.desktop
                ? () => setState(() => _pressed = false)
                : null,
            onTapUp: widget.desktop
                ? (_) => setState(() => _pressed = false)
                : null,
            onTap: widget.desktop ? widget.onTap : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.desktop && highlighted
                    ? colors.onSurface.withValues(alpha: .075)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(widget.desktop ? 16 : 22),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: widget.vertical ? 64 : (widget.desktop ? 32 : 44),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.vertical ? 2 : (widget.desktop ? 8 : 16),
                    vertical: widget.desktop ? 5 : 9,
                  ),
                  child: widget.vertical
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.icon,
                              size: 21,
                              color: colors.onSurface,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Icon(
                              widget.icon,
                              size: widget.desktop ? 16 : 20,
                              color: colors.onSurface,
                            ),
                            SizedBox(width: widget.desktop ? 9 : 12),
                            Expanded(
                              child: Text(
                                widget.label,
                                style: TextStyle(
                                  fontSize: widget.desktop ? 13 : 16,
                                ),
                              ),
                            ),
                            if (widget.trailing != null) ...[
                              const SizedBox(width: 6),
                              Icon(
                                widget.trailing,
                                size: 14,
                                color: colors.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _smoothRange(double value, double start, double end) {
  final t = ((value - start) / (end - start)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// The material changes size in layout, while its contents keep their final
/// layout and scale into that same geometry. Only content is clipped/blurred;
/// the glass surface is outside this render object's paint subtree.
class _MenuMorph extends SingleChildRenderObjectWidget {
  const _MenuMorph({
    required this.progress,
    required this.initialSize,
    required this.radius,
    required super.child,
  });
  final double progress;
  final Size initialSize;
  final double radius;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMenuMorph(progress, initialSize, radius);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMenuMorph renderObject,
  ) => renderObject.update(progress, initialSize, radius);
}

class _RenderMenuMorph extends RenderShiftedBox {
  _RenderMenuMorph(this.progress, this.initialSize, this.radius) : super(null);
  double progress;
  Size initialSize;
  double radius;
  Matrix4 _contentTransform = Matrix4.identity();

  void update(double nextProgress, Size nextSize, double nextRadius) {
    if (progress == nextProgress &&
        initialSize == nextSize &&
        radius == nextRadius) {
      return;
    }
    progress = nextProgress;
    initialSize = nextSize;
    radius = nextRadius;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    child!.layout(constraints.loosen(), parentUsesSize: true);
    final target = child!.size;
    size = constraints.constrain(Size.lerp(initialSize, target, progress)!);
    (child!.parentData! as BoxParentData).offset = Offset.zero;
    _contentTransform = Matrix4.diagonal3Values(
      target.width == 0 ? 1 : size.width / target.width,
      target.height == 0 ? 1 : size.height / target.height,
      1,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final bounds = Offset.zero & size;
    final corner = math.min(radius, math.min(size.width, size.height) / 2);
    context.pushClipRRect(
      needsCompositing,
      offset,
      bounds,
      RRect.fromRectAndRadius(bounds, Radius.circular(corner)),
      (context, offset) => context.pushTransform(
        needsCompositing,
        offset,
        _contentTransform,
        (context, offset) => context.paintChild(child!, offset),
      ),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintTransform(
        transform: _contentTransform,
        position: position,
        hitTest: (result, transformed) =>
            child!.hitTest(result, position: transformed),
      );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.multiply(_contentTransform);

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => Offset.zero & size;
}
