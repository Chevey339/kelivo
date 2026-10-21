import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/services/browser/browser_service.dart';
import 'models/browser_models.dart';
import 'widgets/browser_transition_snapshot.dart';

/// The tab transition animates a retained image, never a live platform view.
/// Card keys keep the flight aligned with the actual scrolled grid geometry.
class BrowserTabTransitionController {
  BrowserTabTransitionController({
    required this.service,
    required String? initialTabId,
    required Rect initialContentRect,
    required this.contentRectForTab,
    required this.fallbackBuilder,
    this.openingPreviewReady = true,
    ui.Image? startPageSnapshot,
    Map<String, Uint8List>? previews,
  }) : _contentRect = initialContentRect,
       _previews = Map.unmodifiable(
         previews ??
             {
               for (final tab in service.tabs)
                 if (service.previewForTab(tab.id) case final bytes?)
                   tab.id: bytes,
             },
       ),
       _startPageSnapshot = startPageSnapshot?.clone() {
    _setTab(initialTabId);
  }

  final BrowserService service;

  /// Screen-space content bounds in this route's coordinate system. Snapshots
  /// contain only these pixels: native status-bar padding is cropped at capture.
  final Rect Function(BrowserTab?) contentRectForTab;
  final Widget Function(BuildContext, BrowserTab?) fallbackBuilder;
  final bool openingPreviewReady;
  final ui.Image? _startPageSnapshot;
  final Map<String, Uint8List> _previews;
  final Map<String, GlobalKey> _cardKeys = {};
  String? _tabId;
  BrowserTab? _tab;
  Uint8List? _bytes;
  Widget? _snapshot;
  bool _returnPrepared = false;
  Rect? _flightRect;
  bool _geometryResolved = false;
  Rect _contentRect;

  String? get tabId => _tabId;
  Rect get contentRect => _contentRect;
  bool get canFly => openingPreviewReady || _returnPrepared;
  Uint8List? get previewBytes => _bytes;
  Uint8List? previewForTab(String id) => _previews[id];
  bool get hasImageSnapshot =>
      _bytes != null || startPageSnapshotFor(_tab) != null;

  /// The browser owns this clone while it bridges the final route frame to a
  /// ready native viewport. Disposing this route cannot invalidate that image.
  ui.Image? cloneReturnRaster() => startPageSnapshotFor(_tab)?.clone();

  ui.Image? startPageSnapshotFor(BrowserTab? tab) =>
      tab != null &&
          !tab.hasContent &&
          (tab.url.isEmpty || tab.url == 'about:blank')
      ? _startPageSnapshot
      : null;

  GlobalKey previewKeyFor(String id) =>
      _cardKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'tab-flight-$id'));

  void _setTab(String? id) {
    _tabId = id;
    _tab = service.tabs.where((tab) => tab.id == id).firstOrNull;
    _bytes = id == null ? null : previewForTab(id);
    _snapshot = null;
    _flightRect = null;
    _geometryResolved = false;
  }

  /// Call before selecting/popping so the flight starts from the tapped card.
  /// A new tab passes null and returns with a short fade instead of inventing
  /// a card origin outside the visible grid.
  void prepareReturn(String? id) {
    _returnPrepared = true;
    _setTab(id);
    _contentRect = contentRectForTab(_tab);
  }

  void prepareDefaultReturn() {
    if (_returnPrepared) return;
    _returnPrepared = true;
    _setTab(service.activeTabId);
    _contentRect = contentRectForTab(_tab);
  }

  void cancelReturn() {
    _returnPrepared = false;
    invalidateGeometry();
  }

  /// A keyboard/window/grid re-layout can move the destination after the first
  /// frame. Keep the frozen flight rect only while those metrics stay valid.
  void invalidateGeometry() {
    _flightRect = null;
    _geometryResolved = false;
  }

  Rect? previewRect(RenderBox viewport) {
    if (_geometryResolved) return _flightRect;
    final box = _cardKeys[_tabId]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    _geometryResolved = true;
    final rect =
        viewport.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
    final visible = (Offset.zero & viewport.size).intersect(rect);
    // Offscreen cards should not fly through the toolbar or from outside the
    // screen when Done, system Back or a new-tab action dismisses the overview.
    return _flightRect =
        visible.width >= rect.width * .9 && visible.height >= rect.height * .9
        ? rect
        : null;
  }

  Widget snapshot(BuildContext context) {
    final raster = startPageSnapshotFor(_tab);
    return _snapshot ??= RepaintBoundary(
      child: raster != null
          ? RawImage(
              image: raster,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.low,
            )
          : _bytes == null
          ? _fallback(context)
          : Image.memory(
              _bytes!,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
              errorBuilder: (context, _, __) => _fallback(context),
            ),
    );
  }

  Widget _fallback(BuildContext context) => Material(
    type: MaterialType.transparency,
    textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      decoration: TextDecoration.none,
    ),
    child: fallbackBuilder(context, _tab),
  );

  void dispose() => _startPageSnapshot?.dispose();
}

/// Full-page to tab-card motion using one cached texture. The overview remains
/// at its final geometry, including while an edge-back gesture is cancelled.
class BrowserTabsRoute extends PageRoute<void> {
  BrowserTabsRoute({
    required this.transition,
    required this.builder,
    this.reduceMotion = false,
    this.onReturnStarted,
  });

  final BrowserTabTransitionController transition;
  final WidgetBuilder builder;
  final bool reduceMotion;
  final VoidCallback? onReturnStarted;
  bool _dragging = false;
  bool _returnNotified = false;
  AnimationStatusListener? _gestureEndListener;

  @override
  Duration get transitionDuration =>
      Duration(milliseconds: reduceMotion ? 0 : 360);
  @override
  Duration get reverseTransitionDuration =>
      Duration(milliseconds: reduceMotion ? 0 : 320);
  @override
  bool get opaque => true;
  @override
  bool get maintainState => true;
  @override
  Color? get barrierColor => null;
  @override
  String? get barrierLabel => null;

  @override
  bool didPop(void result) {
    final accepted = super.didPop(result);
    // Local history can consume Back to dismiss the scope menu while keeping
    // this route open. Resolve its return target only when the route exits.
    if (accepted) transition.prepareDefaultReturn();
    if (accepted && !_returnNotified) {
      _returnNotified = true;
      onReturnStarted?.call();
    }
    return accepted;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  void _startDrag(DragStartDetails _) {
    if (!popGestureEnabled || _dragging) return;
    transition.prepareDefaultReturn();
    _dragging = true;
    navigator!.didStartUserGesture();
  }

  void _updateDrag(DragUpdateDetails details, double width, bool rtl) {
    if (!_dragging) return;
    controller!.value -= details.delta.dx / width * (rtl ? -1 : 1);
  }

  void _stopGesture() {
    if (_gestureEndListener != null) {
      controller?.removeStatusListener(_gestureEndListener!);
      _gestureEndListener = null;
    }
    if (!_dragging) return;
    _dragging = false;
    if (isCurrent) {
      transition.cancelReturn();
      _returnNotified = false;
    }
    navigator?.didStopUserGesture();
  }

  void _endDrag({double velocity = 0, bool cancelled = false}) {
    if (!_dragging) return;
    final returnToOverview = !isCurrent
        ? isActive
        : cancelled ||
              (velocity.abs() > 1 ? velocity <= 0 : controller!.value >= .5);
    if (!returnToOverview) {
      if (isCurrent) navigator!.pop();
      if (controller!.isAnimating) {
        controller!.animateBack(
          0,
          duration: reverseTransitionDuration,
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      controller!.animateTo(
        1,
        duration: transitionDuration,
        curve: Curves.easeOutCubic,
      );
    }
    if (controller!.isAnimating) {
      _gestureEndListener = (_) => _stopGesture();
      controller!.addStatusListener(_gestureEndListener!);
    } else {
      _stopGesture();
    }
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final rtl = Directionality.of(context) == TextDirection.rtl;
      final size = constraints.biggest;
      return AnimatedBuilder(
        animation: animation,
        child: BrowserTransitionSnapshot(
          animation: animation,
          child: RepaintBoundary(
            key: const ValueKey('browserTabOverviewPaintBoundary'),
            child: child,
          ),
        ),
        builder: (context, child) {
          final progress = popGestureInProgress
              ? animation.value
              : Curves.easeInOutCubic.transform(animation.value);
          final viewport = context.findRenderObject();
          final card = viewport is RenderBox && viewport.hasSize
              ? transition.previewRect(viewport)
              : null;
          // Before the grid's first layout there is no card box yet. Keep the
          // snapshot at its actual content viewport during that first frame;
          // status-bar space must not change the image scale or crop.
          final awaitingCard =
              transition.tabId != null &&
              animation.status != AnimationStatus.reverse &&
              animation.value < .1;
          final flying =
              transition.canFly &&
              !reduceMotion &&
              animation.value < 1 &&
              (card != null || awaitingCard);
          final full = transition.contentRect;
          final rect = Rect.lerp(full, card ?? full, progress)!;
          // A real flight already reveals/conceals the grid by moving over it.
          // Do not put the entire live optical grid into an animated saveLayer.
          // Only destinations without a visible card need a page fade.
          final fadeOverview = !reduceMotion && !flying && animation.value < 1;
          return Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                ignoring: animation.status != AnimationStatus.completed,
                child: Opacity(
                  key: const ValueKey('browserTabOverviewOpacity'),
                  opacity: fadeOverview ? animation.value : 1,
                  child: child,
                ),
              ),
              if (flying)
                Positioned.fromRect(
                  rect: rect,
                  child: IgnorePointer(
                    // The real image remains opaque through the final frame.
                    // The caller retains the same image over native attachment
                    // after pop, instead of exposing an empty viewport here.
                    // A missing-image placeholder still blends into its card.
                    child: Opacity(
                      key: const ValueKey('browserTabFlightOpacity'),
                      opacity: transition.hasImageSnapshot
                          ? 1
                          : ((1 - animation.value) / .12).clamp(0.0, 1.0),
                      child: ClipRRect(
                        key: const ValueKey('browserTabSnapshotFlight'),
                        borderRadius: BorderRadius.circular(18 * progress),
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.surface,
                          child: FittedBox(
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.topCenter,
                            child: SizedBox.fromSize(
                              size: full.size,
                              child: transition.snapshot(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width:
                    24 +
                    (rtl
                        ? MediaQuery.paddingOf(context).right
                        : MediaQuery.paddingOf(context).left),
                child: GestureDetector(
                  key: const ValueKey('browserTabsBackGesture'),
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: _startDrag,
                  onHorizontalDragUpdate: (details) =>
                      _updateDrag(details, size.width, rtl),
                  onHorizontalDragEnd: (details) => _endDrag(
                    velocity:
                        details.velocity.pixelsPerSecond.dx /
                        size.width *
                        (rtl ? -1 : 1),
                  ),
                  onHorizontalDragCancel: () => _endDrag(cancelled: true),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  @override
  void dispose() {
    _stopGesture();
    transition.dispose();
    super.dispose();
  }
}
