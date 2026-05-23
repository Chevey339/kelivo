import 'package:flutter/material.dart';

import '../../icons/lucide_adapter.dart';
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
  static const double _dismissExtentGap = 0.08;
  static const double _minimumContentLayoutHeight = 112;
  static const double _dismissOverscrollThreshold = 24;

  late final AnimationController _presentationController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  double _extent = 0.60;
  double _handleDragStartExtent = 0.60;
  double? _scrollDragStartExtent;
  double _topOverscrollDistance = 0;
  bool _handleDragging = false;
  bool _scrollDragChangedSheetExtent = false;
  bool _dismissScheduled = false;

  @override
  void initState() {
    super.initState();
    _presentationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
    )..forward();
  }

  @override
  void dispose() {
    _presentationController.dispose();
    _sheetController.dispose();
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

        return AnimatedBuilder(
          animation: _presentationController,
          builder: (context, _) {
            final presentationProgress = Curves.easeOutCubic.transform(
              _presentationController.value,
            );
            final sheetProgress =
                (_extent / expandedExtent).clamp(0.0, 1.0).toDouble() *
                presentationProgress;

            return Material(
              type: MaterialType.transparency,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _dismiss,
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: 0.12 * sheetProgress,
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(
                      0,
                      parentHeight * (1 - presentationProgress),
                    ),
                    child: NotificationListener<ScrollStartNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.axis != Axis.vertical) {
                          return false;
                        }
                        _scrollDragStartExtent = _currentExtent(partialExtent);
                        _topOverscrollDistance = 0;
                        _scrollDragChangedSheetExtent = false;
                        return false;
                      },
                      child: NotificationListener<ScrollEndNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.axis != Axis.vertical) {
                            return false;
                          }
                          _settleScrollDrag(
                            partialExtent: partialExtent,
                            expandedExtent: expandedExtent,
                          );
                          return false;
                        },
                        child: NotificationListener<OverscrollNotification>(
                          onNotification: (notification) {
                            _handleOverscroll(
                              notification,
                              partialExtent: partialExtent,
                            );
                            return false;
                          },
                          child:
                              NotificationListener<
                                DraggableScrollableNotification
                              >(
                                onNotification: (notification) {
                                  if (!_dismissScheduled) {
                                    final changed =
                                        (notification.extent - _extent).abs() >
                                        0.001;
                                    if (changed && !_handleDragging) {
                                      _scrollDragStartExtent ??= _extent;
                                      _scrollDragChangedSheetExtent = true;
                                    }
                                    setState(
                                      () => _extent = notification.extent,
                                    );
                                  }
                                  return false;
                                },
                                child: DraggableScrollableSheet(
                                  controller: _sheetController,
                                  initialChildSize: partialExtent,
                                  minChildSize: partialExtent,
                                  maxChildSize: expandedExtent,
                                  builder: (context, scrollController) {
                                    return ClipRRect(
                                      key: CustomBottomSheet.panelKey,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                      child: ColoredBox(
                                        color: cs.surface,
                                        child: LayoutBuilder(
                                          builder: (context, panelConstraints) {
                                            if (panelConstraints.maxHeight <
                                                _minimumContentLayoutHeight) {
                                              return const SizedBox.shrink();
                                            }

                                            return SafeArea(
                                              top: false,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  GestureDetector(
                                                    behavior:
                                                        HitTestBehavior.opaque,
                                                    onVerticalDragStart: (_) {
                                                      _handleDragging = true;
                                                      _handleDragStartExtent =
                                                          _currentExtent(
                                                            partialExtent,
                                                          );
                                                    },
                                                    onVerticalDragUpdate:
                                                        (details) {
                                                          final next =
                                                              _currentExtent(
                                                                partialExtent,
                                                              ) -
                                                              details.delta.dy /
                                                                  parentHeight;
                                                          _jumpToExtent(
                                                            next.clamp(
                                                              partialExtent,
                                                              expandedExtent,
                                                            ),
                                                          );
                                                        },
                                                    onVerticalDragEnd: (details) {
                                                      _handleDragging = false;
                                                      _settleHandle(
                                                        velocityY:
                                                            details
                                                                .primaryVelocity ??
                                                            0,
                                                        partialExtent:
                                                            partialExtent,
                                                        expandedExtent:
                                                            expandedExtent,
                                                      );
                                                    },
                                                    onVerticalDragCancel: () {
                                                      _handleDragging = false;
                                                      _animateToExtent(
                                                        partialExtent,
                                                      );
                                                    },
                                                    child: _DragHandle(
                                                      color: cs.onSurface,
                                                    ),
                                                  ),
                                                  _SheetHeader(
                                                    title: widget.title,
                                                    count: widget.count,
                                                    closeSemanticLabel: widget
                                                        .closeSemanticLabel,
                                                    onClose: _dismiss,
                                                  ),
                                                  Expanded(
                                                    child:
                                                        widget.builder?.call(
                                                          context,
                                                          scrollController,
                                                        ) ??
                                                        SingleChildScrollView(
                                                          controller:
                                                              scrollController,
                                                          child: widget.child,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
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
      },
    );
  }

  double _currentExtent(double fallback) {
    if (!_sheetController.isAttached) return fallback;
    return _sheetController.size;
  }

  void _jumpToExtent(double extent) {
    if (!_sheetController.isAttached) return;
    _sheetController.jumpTo(extent);
  }

  void _handleOverscroll(
    OverscrollNotification notification, {
    required double partialExtent,
  }) {
    if (notification.metrics.axis != Axis.vertical) return;
    final dragDeltaY = notification.dragDetails?.delta.dy ?? 0;
    final startedAtPartial =
        (_scrollDragStartExtent ?? partialExtent) <= partialExtent + 0.02;
    final isAtTop =
        notification.metrics.pixels <= notification.metrics.minScrollExtent + 1;
    final isAtPartial = _currentExtent(partialExtent) <= partialExtent + 0.02;

    if (startedAtPartial && isAtPartial && isAtTop && dragDeltaY > 0) {
      _topOverscrollDistance += dragDeltaY;
    }
  }

  void _settleScrollDrag({
    required double partialExtent,
    required double expandedExtent,
  }) {
    final start = _scrollDragStartExtent ?? partialExtent;
    final shouldDismissFromPartial =
        start <= partialExtent + 0.02 &&
        _topOverscrollDistance >= _dismissOverscrollThreshold;

    if (_dismissScheduled) {
      _resetScrollDragTracking();
      return;
    }

    if (!_scrollDragChangedSheetExtent) {
      _resetScrollDragTracking();
      if (shouldDismissFromPartial) _dismiss();
      return;
    }

    final current = _currentExtent(partialExtent);
    final dragged = current - start;

    _resetScrollDragTracking();

    if (shouldDismissFromPartial) {
      _dismiss();
      return;
    }

    if (dragged > 0.005) {
      _animateToExtent(expandedExtent);
      return;
    }

    if (dragged < -0.005) {
      if (start <= partialExtent + 0.02) {
        _dismiss();
        return;
      }
      _animateToExtent(partialExtent);
      return;
    }

    final midpoint = (partialExtent + expandedExtent) / 2;
    _animateToExtent(current >= midpoint ? expandedExtent : partialExtent);
  }

  void _resetScrollDragTracking() {
    _scrollDragStartExtent = null;
    _topOverscrollDistance = 0;
    _scrollDragChangedSheetExtent = false;
  }

  void _settleHandle({
    required double velocityY,
    required double partialExtent,
    required double expandedExtent,
  }) {
    final current = _currentExtent(partialExtent);
    final dragged = current - _handleDragStartExtent;

    if (current < partialExtent - _dismissExtentGap) {
      _dismiss();
      return;
    }

    if (velocityY.abs() >= _flingVelocityThreshold) {
      if (velocityY < 0) {
        _animateToExtent(expandedExtent);
        return;
      }
      if (current <= partialExtent + 0.02) {
        _dismiss();
        return;
      }
      _animateToExtent(partialExtent);
      return;
    }

    if (dragged.abs() >= 0.12) {
      if (dragged > 0) {
        _animateToExtent(expandedExtent);
        return;
      }
      if (current <= partialExtent) {
        _dismiss();
        return;
      }
      _animateToExtent(partialExtent);
      return;
    }

    final midpoint = (partialExtent + expandedExtent) / 2;
    _animateToExtent(current >= midpoint ? expandedExtent : partialExtent);
  }

  void _animateToExtent(double extent) {
    if (!_sheetController.isAttached) return;
    _sheetController.animateTo(
      extent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _dismiss() {
    if (_dismissScheduled) return;
    _dismissScheduled = true;
    _presentationController.reverse().whenComplete(() {
      if (mounted) widget.onDismiss();
    });
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
      fontWeight: FontWeight.w600,
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
