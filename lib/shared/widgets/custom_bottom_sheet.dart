import 'package:flutter/material.dart';

import '../../icons/lucide_adapter.dart';
import '../../theme/app_font_weights.dart';
import 'ios_tactile.dart';

typedef CustomBottomSheetBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

Future<T?> showCustomBottomSheet<T>({
  required BuildContext context,
  required String title,
  required CustomBottomSheetBuilder builder,
  int? count,
  String? closeSemanticLabel,
  double partialHeightFactor = 0.60,
  double expandedHeightFactor = 0.90,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, _, __) {
      return CustomBottomSheet(
        title: title,
        count: count,
        closeSemanticLabel: closeSemanticLabel,
        partialHeightFactor: partialHeightFactor,
        expandedHeightFactor: expandedHeightFactor,
        onDismiss: () => Navigator.of(dialogContext).maybePop(),
        builder: builder,
      );
    },
  );
}

class CustomBottomSheet extends StatefulWidget {
  const CustomBottomSheet({
    super.key,
    required this.title,
    required this.onDismiss,
    this.count,
    this.closeSemanticLabel,
    this.child,
    this.builder,
    this.partialHeightFactor = 0.60,
    this.expandedHeightFactor = 0.90,
  }) : assert(
         child != null || builder != null,
         'Either child or builder must be provided',
       );

  static const panelKey = ValueKey('custom_bottom_sheet_panel');
  static const dragHandleKey = ValueKey('custom_bottom_sheet_drag_handle');
  static const closeButtonKey = ValueKey('custom_bottom_sheet_close_button');

  final String title;
  final int? count;
  final String? closeSemanticLabel;
  final VoidCallback onDismiss;
  final Widget? child;
  final CustomBottomSheetBuilder? builder;
  final double partialHeightFactor;
  final double expandedHeightFactor;

  @override
  State<CustomBottomSheet> createState() => _CustomBottomSheetState();
}

class _CustomBottomSheetState extends State<CustomBottomSheet>
    with SingleTickerProviderStateMixin {
  static const double _flingVelocityThreshold = 400;
  static const double _dismissDistanceThreshold = 200;
  static const double _dismissExtentGapPx = 10;

  late final AnimationController _sheetAnimationController;
  final ScrollController _scrollController = ScrollController();
  Animation<double>? _topAnimation;
  VoidCallback? _animationComplete;
  double? _sheetTop;
  double? _lastParentHeight;
  double _handleDragStartTop = 0;
  double _contentDragStartTop = 0;
  int? _contentPointer;
  double? _lastContentPointerY;
  bool _contentDragChangedSheetTop = false;
  bool _dismissScheduled = false;

  @override
  void initState() {
    super.initState();
    _sheetAnimationController = AnimationController(vsync: this)
      ..addListener(() {
        final animation = _topAnimation;
        if (animation == null) return;
        setState(() => _sheetTop = animation.value);
      })
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        _topAnimation = null;
        final onComplete = _animationComplete;
        _animationComplete = null;
        onComplete?.call();
      });
  }

  @override
  void dispose() {
    _sheetAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final parentHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final partialExtent = widget.partialHeightFactor;
        final expandedExtent = widget.expandedHeightFactor;
        final expandedTop = parentHeight * (1 - expandedExtent);
        final partialTop = parentHeight * (1 - partialExtent);
        final hiddenTop = parentHeight;
        final expandedHeight = parentHeight * expandedExtent;

        _syncSheetTop(
          parentHeight: parentHeight,
          expandedTop: expandedTop,
          partialTop: partialTop,
          hiddenTop: hiddenTop,
        );

        final sheetTop = _sheetTop ?? hiddenTop;
        final sheetProgress =
            ((hiddenTop - sheetTop) / (hiddenTop - expandedTop))
                .clamp(0.0, 1.0)
                .toDouble();

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _dismiss,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.12 * sheetProgress),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: sheetTop,
                height: expandedHeight,
                child: ClipRRect(
                  key: CustomBottomSheet.panelKey,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: ColoredBox(
                    color: cs.surface,
                    child: SafeArea(
                      top: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragStart: (_) {
                              _handleDragStartTop = _currentTop(partialTop);
                            },
                            onVerticalDragUpdate: (details) {
                              _dragSheetBy(
                                details.delta.dy,
                                expandedTop: expandedTop,
                                hiddenTop: hiddenTop,
                              );
                            },
                            onVerticalDragEnd: (details) {
                              _settleDrag(
                                startTop: _handleDragStartTop,
                                currentTop: _currentTop(partialTop),
                                velocityY: details.primaryVelocity ?? 0,
                                expandedTop: expandedTop,
                                partialTop: partialTop,
                              );
                            },
                            onVerticalDragCancel: () {
                              _animateToTop(partialTop);
                            },
                            child: _DragHandle(color: cs.onSurface),
                          ),
                          _SheetHeader(
                            title: widget.title,
                            count: widget.count,
                            closeSemanticLabel: widget.closeSemanticLabel,
                            onClose: _dismiss,
                          ),
                          Expanded(
                            child: Listener(
                              onPointerDown: (event) => _startContentDrag(
                                event.pointer,
                                event.position.dy,
                                partialTop: partialTop,
                              ),
                              onPointerMove: (event) => _updateContentDrag(
                                event.pointer,
                                event.position.dy,
                                expandedTop: expandedTop,
                                partialTop: partialTop,
                                hiddenTop: hiddenTop,
                              ),
                              onPointerUp: (event) => _endContentDrag(
                                event.pointer,
                                expandedTop: expandedTop,
                                partialTop: partialTop,
                              ),
                              onPointerCancel: (event) => _cancelContentDrag(
                                event.pointer,
                                partialTop: partialTop,
                              ),
                              child:
                                  widget.builder?.call(
                                    context,
                                    _scrollController,
                                  ) ??
                                  SingleChildScrollView(
                                    controller: _scrollController,
                                    child: widget.child,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _syncSheetTop({
    required double parentHeight,
    required double expandedTop,
    required double partialTop,
    required double hiddenTop,
  }) {
    final previousHeight = _lastParentHeight;
    if (_sheetTop == null) {
      _sheetTop = hiddenTop;
      _lastParentHeight = parentHeight;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _dismissScheduled) return;
        _animateToTop(partialTop, duration: const Duration(milliseconds: 260));
      });
      return;
    }

    if (previousHeight != null && previousHeight != parentHeight) {
      final previousExpandedTop =
          previousHeight * (1 - widget.expandedHeightFactor);
      final previousHiddenTop = previousHeight;
      final previousRange = previousHiddenTop - previousExpandedTop;
      final progress = previousRange <= 0
          ? 0.0
          : ((previousHiddenTop - _sheetTop!) / previousRange).clamp(0.0, 1.0);
      _sheetTop = hiddenTop - progress * (hiddenTop - expandedTop);
    }
    _lastParentHeight = parentHeight;
  }

  double _currentTop(double fallback) => _sheetTop ?? fallback;

  void _startContentDrag(
    int pointer,
    double positionY, {
    required double partialTop,
  }) {
    if (_contentPointer != null) return;
    _contentPointer = pointer;
    _lastContentPointerY = positionY;
    _contentDragStartTop = _currentTop(partialTop);
    _contentDragChangedSheetTop = false;
  }

  void _updateContentDrag(
    int pointer,
    double positionY, {
    required double expandedTop,
    required double partialTop,
    required double hiddenTop,
  }) {
    if (_contentPointer != pointer) return;
    final lastY = _lastContentPointerY;
    if (lastY == null) return;
    final deltaY = positionY - lastY;
    _lastContentPointerY = positionY;
    if (deltaY == 0) return;

    final currentTop = _currentTop(partialTop);
    final shouldExpandSheet = deltaY < 0 && currentTop > expandedTop + 0.5;
    final shouldCollapseSheet = deltaY > 0 && _contentScrollIsAtTop();
    if (!shouldExpandSheet && !shouldCollapseSheet) return;

    _contentDragChangedSheetTop = true;
    if (shouldExpandSheet) _restoreScrollToTop();
    _dragSheetBy(deltaY, expandedTop: expandedTop, hiddenTop: hiddenTop);
  }

  void _endContentDrag(
    int pointer, {
    required double expandedTop,
    required double partialTop,
  }) {
    if (_contentPointer != pointer) return;
    _contentPointer = null;
    _lastContentPointerY = null;
    if (!_contentDragChangedSheetTop) return;
    _contentDragChangedSheetTop = false;
    _settleDrag(
      startTop: _contentDragStartTop,
      currentTop: _currentTop(partialTop),
      velocityY: 0,
      expandedTop: expandedTop,
      partialTop: partialTop,
    );
  }

  void _cancelContentDrag(int pointer, {required double partialTop}) {
    if (_contentPointer != pointer) return;
    _contentPointer = null;
    _lastContentPointerY = null;
    _contentDragChangedSheetTop = false;
    _animateToTop(partialTop);
  }

  bool _contentScrollIsAtTop() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.pixels <= position.minScrollExtent + 1;
  }

  void _restoreScrollToTop() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels <= position.minScrollExtent) return;
    position.jumpTo(position.minScrollExtent);
  }

  void _dragSheetBy(
    double deltaY, {
    required double expandedTop,
    required double hiddenTop,
  }) {
    final current = _currentTop(hiddenTop);
    final next = (current + deltaY).clamp(expandedTop, hiddenTop).toDouble();
    if ((next - current).abs() < 0.1) return;
    _sheetAnimationController.stop();
    _topAnimation = null;
    _animationComplete = null;
    setState(() => _sheetTop = next);
  }

  void _settleDrag({
    required double startTop,
    required double currentTop,
    required double velocityY,
    required double expandedTop,
    required double partialTop,
  }) {
    final dragged = currentTop - startTop;

    if (velocityY <= -_flingVelocityThreshold || dragged < -0.5) {
      _animateToTop(expandedTop);
      return;
    }

    if (velocityY >= _flingVelocityThreshold || dragged > 0.5) {
      if (_shouldDismissAfterDownDrag(
        startTop: startTop,
        currentTop: currentTop,
        partialTop: partialTop,
      )) {
        _dismiss();
        return;
      }
      _animateToTop(partialTop);
      return;
    }

    _animateToTop(_nearestVisibleTop(currentTop, expandedTop, partialTop));
  }

  bool _shouldDismissAfterDownDrag({
    required double startTop,
    required double currentTop,
    required double partialTop,
  }) {
    final draggedDownPx = currentTop - startTop;
    final belowPartialPx = currentTop - partialTop;
    return draggedDownPx >= _dismissDistanceThreshold &&
        belowPartialPx > _dismissExtentGapPx;
  }

  double _nearestVisibleTop(
    double currentTop,
    double expandedTop,
    double partialTop,
  ) {
    final expandedDistance = (currentTop - expandedTop).abs();
    final partialDistance = (currentTop - partialTop).abs();
    return expandedDistance < partialDistance ? expandedTop : partialTop;
  }

  void _animateToTop(
    double targetTop, {
    Duration duration = const Duration(milliseconds: 220),
    Curve curve = Curves.easeOutCubic,
    VoidCallback? onComplete,
  }) {
    final current = _currentTop(targetTop);
    _sheetAnimationController.stop();
    _animationComplete = null;
    if ((current - targetTop).abs() < 0.5) {
      setState(() => _sheetTop = targetTop);
      onComplete?.call();
      return;
    }
    _topAnimation = Tween<double>(
      begin: current,
      end: targetTop,
    ).animate(CurvedAnimation(parent: _sheetAnimationController, curve: curve));
    _animationComplete = onComplete;
    _sheetAnimationController.duration = duration;
    _sheetAnimationController.forward(from: 0);
  }

  void _dismiss() {
    if (_dismissScheduled) return;
    _dismissScheduled = true;
    final hiddenTop = _lastParentHeight;
    if (hiddenTop == null) {
      widget.onDismiss();
      return;
    }
    _animateToTop(
      hiddenTop,
      duration: const Duration(milliseconds: 220),
      onComplete: () {
        if (mounted) widget.onDismiss();
      },
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Center(
        child: Container(
          key: CustomBottomSheet.dragHandleKey,
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.onClose,
    this.count,
    this.closeSemanticLabel,
  });

  final String title;
  final int? count;
  final String? closeSemanticLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleStyle = TextStyle(
      color: cs.onSurface,
      fontSize: 15,
      fontWeight: AppFontWeights.emphasis,
      height: 1.2,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
                if (count != null && count! > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    count!.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            key: CustomBottomSheet.closeButtonKey,
            width: 24,
            height: 24,
            child: IosIconButton(
              icon: Lucide.X,
              size: 20,
              padding: EdgeInsets.zero,
              color: cs.onSurface.withValues(alpha: 0.62),
              semanticLabel: closeSemanticLabel,
              onTap: onClose,
            ),
          ),
        ],
      ),
    );
  }
}
