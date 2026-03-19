import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/services/haptics.dart';

enum NotificationType { success, error, info, warning }

class AppNotification {
  final String message;
  final NotificationType type;
  final Duration duration;
  final VoidCallback? onTap;
  final String? actionLabel;
  final VoidCallback? onAction;

  AppNotification({
    required this.message,
    this.type = NotificationType.info,
    this.duration = const Duration(seconds: 3),
    this.onTap,
    this.actionLabel,
    this.onAction,
  });
}

class AppSnackBarManager extends ChangeNotifier {
  static final AppSnackBarManager _instance = AppSnackBarManager._internal();
  factory AppSnackBarManager() => _instance;
  AppSnackBarManager._internal();

  final List<NotificationEntry> _activeToasts = [];
  static const int _maxVisible = 3;

  List<NotificationEntry> get activeToasts => List.unmodifiable(_activeToasts);

  void show(BuildContext context, AppNotification notification) {
    final entry = NotificationEntry(
      key: UniqueKey(),
      notification: notification,
      animationController: AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: Navigator.of(context),
      ),
      slideAnimation: null,
      fadeAnimation: null,
    );

    // Setup smooth entrance animations
    entry.slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: entry.animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    entry.fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: entry.animationController, curve: Curves.easeOut),
    );

    _activeToasts.insert(0, entry);
    notifyListeners();

    entry.animationController.forward();

    // Auto dismiss
    Timer(notification.duration, () {
      _dismiss(entry);
    });
  }

  void _dismiss(NotificationEntry entry) async {
    if (!_activeToasts.contains(entry)) return;

    // Start exit animation
    await entry.animationController.reverse();

    _activeToasts.remove(entry);
    entry.animationController.dispose();
    notifyListeners();
  }

  void dismissAt(int index) {
    if (index < 0 || index >= _activeToasts.length) return;
    _dismiss(_activeToasts[index]);
  }

  void dismissAll() {
    final toasts = List<NotificationEntry>.from(_activeToasts);
    for (final toast in toasts) {
      _dismiss(toast);
    }
  }
}

class NotificationEntry {
  final Key key;
  final AppNotification notification;
  final AnimationController animationController;
  Animation<Offset>? slideAnimation;
  Animation<double>? fadeAnimation;

  NotificationEntry({
    required this.key,
    required this.notification,
    required this.animationController,
    this.slideAnimation,
    this.fadeAnimation,
  });
}

class AppSnackBarOverlay extends StatefulWidget {
  final Widget child;

  const AppSnackBarOverlay({super.key, required this.child});

  @override
  State<AppSnackBarOverlay> createState() => _AppSnackBarOverlayState();
}

class _AppSnackBarOverlayState extends State<AppSnackBarOverlay> {
  final AppSnackBarManager _manager = AppSnackBarManager();

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onToastsChanged);
  }

  @override
  void dispose() {
    _manager.removeListener(_onToastsChanged);
    super.dispose();
  }

  void _onToastsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  for (
                    int i = math.min(
                      _manager.activeToasts.length - 1,
                      AppSnackBarManager._maxVisible - 1,
                    );
                    i >= 0;
                    i--
                  )
                    _buildToast(context, i),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToast(BuildContext context, int index) {
    final entry = _manager.activeToasts[index];
    final isTop = index == 0;
    final visualIndex = math.min(index, AppSnackBarManager._maxVisible - 1);
    final isVisible = index < AppSnackBarManager._maxVisible;

    return AnimatedBuilder(
      animation: entry.animationController,
      builder: (context, child) {
        // Calculate positioning - 统一间距
        final baseOffset = visualIndex * 8.0; // 每个Toast固定间距8px

        // Calculate scale - 统一缩放
        final scaleValue = 1.0 - (visualIndex * 0.03);

        // Calculate opacity - 统一透明度
        final fadeValue = entry.fadeAnimation?.value ?? 1.0;
        final baseOpacity = isVisible ? 1.0 - (visualIndex * 0.2) : 0.0;
        final opacity = fadeValue * baseOpacity;

        // Apply slide animation
        final slideValue = entry.slideAnimation?.value ?? Offset.zero;

        return Transform.translate(
          offset: Offset(0, baseOffset + slideValue.dy * 100),
          child: Transform.scale(
            scale: scaleValue,
            alignment: Alignment.topCenter,
            child: Opacity(
              opacity: opacity,
              child: NotificationWidget(
                key: entry.key,
                notification: entry.notification,
                onDismiss: () => _manager._dismiss(entry),
                isTop: isTop,
                fadeValue: fadeValue,
              ),
            ),
          ),
        );
      },
    );
  }
}

class NotificationWidget extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;
  final bool isTop;
  final double fadeValue;

  const NotificationWidget({
    super.key,
    required this.notification,
    required this.onDismiss,
    required this.isTop,
    this.fadeValue = 1.0,
  });

  @override
  State<NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<NotificationWidget>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  late AnimationController _dragController;
  late Animation<double> _dragAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _dragController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _dragController.addListener(() {
      if (mounted) {
        setState(() {
          _dragOffset = _dragAnimation.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.isTop || _isDismissing) return;
    // 禁止向下滑动，仅允许向上滑动以关闭
    if (details.delta.dy > 0) return;
    setState(() {
      _dragOffset = math.min(0, _dragOffset + details.delta.dy);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!widget.isTop || _isDismissing) return;

    final velocity = details.velocity.pixelsPerSecond.dy;
    // Dismiss if dragged up sufficiently or with enough velocity
    if (_dragOffset < -40 || velocity < -300) {
      _isDismissing = true;

      // Animate off screen smoothly
      _dragAnimation = Tween<double>(begin: _dragOffset, end: -150.0).animate(
        CurvedAnimation(parent: _dragController, curve: Curves.easeOut),
      );

      _dragController.forward().then((_) {
        if (mounted) {
          widget.onDismiss();
        }
      });
    } else {
      // Smoothly return to position
      _dragAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
        CurvedAnimation(parent: _dragController, curve: Curves.easeOutCubic),
      );

      _dragController.forward(from: 0).then((_) {
        if (mounted) {
          setState(() {
            _dragOffset = 0;
            _dragController.reset();
          });
        }
      });
    }
  }

  IconData _getIcon() {
    switch (widget.notification.type) {
      case NotificationType.success:
        return Icons.check_circle_rounded;
      case NotificationType.error:
        return Icons.error_rounded;
      case NotificationType.warning:
        return Icons.warning_rounded;
      case NotificationType.info:
        return Icons.info_rounded;
    }
  }

  Color _getIconColor(ColorScheme cs) {
    switch (widget.notification.type) {
      case NotificationType.success:
        return const Color(0xFF34C759);
      case NotificationType.error:
        return const Color(0xFFFF3B30);
      case NotificationType.warning:
        return const Color(0xFFFF9500);
      case NotificationType.info:
        return cs.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Apply interactive feedback scale
    final interactiveScale = _isDismissing ? 0.98 : 1.0;

    return GestureDetector(
      onVerticalDragStart: (_) {
        if (_dragController.isAnimating) _dragController.stop();
      },
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      onTap: () {
        if (!_isDismissing) {
          Haptics.light();
          widget.notification.onTap?.call();
          widget.onDismiss();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, _dragOffset, 0)
          ..scaleByDouble(
            interactiveScale,
            interactiveScale,
            interactiveScale,
            1.0,
          ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1C1C1E).withValues(alpha: 0.98)
                : Colors.white.withValues(alpha: 0.98),
            // color: cs.surface.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(_getIcon(), size: 22, color: _getIconColor(cs)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.notification.message,
                      style:
                          (Theme.of(context).textTheme.bodyMedium ??
                                  const TextStyle())
                              .copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                                height: 1.3,
                                decoration: TextDecoration.none,
                              ),
                    ),
                  ),
                  if (widget.notification.actionLabel != null) ...[
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () {
                        Haptics.light();
                        widget.notification.onAction?.call();
                        widget.onDismiss();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        widget.notification.actionLabel!,
                        style:
                            (Theme.of(context).textTheme.labelLarge ??
                                    const TextStyle())
                                .copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary,
                                ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper function for easy use
void showAppSnackBar(
  BuildContext context, {
  required String message,
  NotificationType type = NotificationType.info,
  Duration duration = const Duration(seconds: 3),
  VoidCallback? onTap,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  AppSnackBarManager().show(
    context,
    AppNotification(
      message: message,
      type: type,
      duration: duration,
      onTap: onTap,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
  );
}
