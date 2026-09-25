import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../search/settings_search_index.dart';
import '../search/settings_search_navigation.dart';
import '../widgets/settings_search_view.dart';
import '../widgets/settings_search_field.dart';
import '../widgets/custom_theme_widgets.dart';

/// A modal layer keeps the settings page still beneath the moving field.
Future<void> showMobileSettingsSearch(
  BuildContext context, {
  required SettingsSearchOrigin origin,
  required VoidCallback onColorMode,
}) async {
  final route = _SettingsSearchRoute(
    origin: origin,
    onColorMode: onColorMode,
    reduceMotion: MediaQuery.disableAnimationsOf(context),
  );
  await Navigator.of(context).push<void>(route);
  // Prevent reopening until the reverse animation and overlay teardown finish.
  await route.completed;
}

class _SettingsSearchRoute extends PopupRoute<void> {
  _SettingsSearchRoute({
    required this.origin,
    required this.onColorMode,
    required this.reduceMotion,
  });
  final SettingsSearchOrigin origin;
  final VoidCallback onColorMode;
  final bool reduceMotion;
  late final CurvedAnimation _motion;
  bool _dragging = false;
  bool _gestureInProgress = false;
  FocusNode? _dragFocus;

  @override
  Animation<double> createAnimation() {
    final animation = super.createAnimation();
    _motion = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return animation;
  }

  void _startDrag(DragStartDetails details) {
    if (!isCurrent || controller!.isAnimating || _gestureInProgress) return;
    _dragging = true;
  }

  void _updateDrag(DragUpdateDetails details, double width) {
    if (!_dragging || !isCurrent) return;
    if (!_gestureInProgress) {
      if (details.primaryDelta! <= 0) return;
      _gestureInProgress = true;
      _dragFocus = FocusManager.instance.primaryFocus;
      controller!.addStatusListener(_handleGestureStatus);
      navigator!.didStartUserGesture();
    }
    controller!.value -= details.primaryDelta! / width;
  }

  void _endDrag({double velocity = 0, bool cancelled = false}) {
    if (!_dragging) return;
    _dragging = false;
    if (!_gestureInProgress) return;
    final dismiss = isCurrent
        ? !cancelled &&
              (velocity.abs() >= 700 ? velocity > 0 : controller!.value < 0.5)
        : !isActive;
    final duration = Duration(milliseconds: reduceMotion ? 0 : 220);
    if (dismiss) {
      if (isCurrent) navigator!.pop();
      if (controller!.isAnimating) {
        controller!.animateBack(
          0,
          duration: duration,
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      controller!.animateTo(1, duration: duration, curve: Curves.easeOutCubic);
    }
    if (!controller!.isAnimating) _stopGesture();
  }

  void _handleGestureStatus(AnimationStatus status) {
    if ((status == AnimationStatus.dismissed && !isCurrent) ||
        (!_dragging && status == AnimationStatus.completed)) {
      _stopGesture();
    }
  }

  void _stopGesture() {
    if (!_gestureInProgress) return;
    _dragging = false;
    _gestureInProgress = false;
    controller!.removeStatusListener(_handleGestureStatus);
    navigator!.didStopUserGesture();
    final focus = _dragFocus;
    _dragFocus = null;
    if (isCurrent && focus != null) {
      // Navigator suspends this route's focus during a back gesture. Restore
      // the original input only after a cancelled gesture has settled.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isCurrent && focus.context != null && focus.canRequestFocus) {
          focus.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _stopGesture();
    _motion.dispose();
    super.dispose();
  }

  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => false;
  @override
  String? get barrierLabel => null;
  @override
  Duration get transitionDuration =>
      Duration(milliseconds: reduceMotion ? 0 : 300);
  @override
  Duration get reverseTransitionDuration =>
      Duration(milliseconds: reduceMotion ? 0 : 300);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Listener(
    // An accepted DragGestureRecognizer reports pointer cancellation as an
    // end, so catch it before the recognizer can commit a dismissal.
    onPointerCancel: (_) => _endDrag(cancelled: true),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _startDrag,
      onHorizontalDragUpdate: (details) =>
          _updateDrag(details, MediaQuery.sizeOf(context).width),
      onHorizontalDragEnd: (details) =>
          _endDrag(velocity: details.primaryVelocity!),
      onHorizontalDragCancel: () => _endDrag(cancelled: true),
      child: ValueListenableBuilder<bool>(
        valueListenable: navigator!.userGestureInProgressNotifier,
        builder: (context, dragging, _) => SettingsSearchPage(
          onColorMode: onColorMode,
          origin: origin,
          // Stay linear through the drag and its settling animation. Switching
          // back to the route curve mid-flight would make the field jump.
          transition: dragging ? animation : _motion,
        ),
      ),
    ),
  );
}

class SettingsSearchPage extends StatelessWidget {
  const SettingsSearchPage({
    super.key,
    required this.onColorMode,
    this.origin,
    this.transition = const AlwaysStoppedAnimation(1),
  });
  final VoidCallback onColorMode;
  final SettingsSearchOrigin? origin;
  final Animation<double> transition;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: _SettingsSearch(
      origin: origin,
      transition: transition,
      safeAreaInsets: MediaQuery.paddingOf(context),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      onSelected: (item) {
        if (item.destination == SettingsSearchDestination.colorMode) {
          onColorMode();
        } else {
          openMobileSettingsSearchResult(context, item);
        }
      },
      onClose: () => Navigator.of(context).pop(),
    ),
  );
}

Future<SettingsSearchItem?> showDesktopSettingsSearch(BuildContext context) =>
    showAppDialog<SettingsSearchItem>(
      context,
      maxWidth: 640,
      child: SizedBox(
        height: 640,
        child: Builder(
          builder: (context) => _SettingsSearch(
            onSelected: (item) => Navigator.of(context).pop(item),
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );

class _SettingsSearch extends StatefulWidget {
  const _SettingsSearch({
    required this.onSelected,
    required this.onClose,
    this.origin,
    this.transition = const AlwaysStoppedAnimation(1),
    this.safeAreaInsets = EdgeInsets.zero,
    this.backgroundColor,
  });
  final SettingsSearchOrigin? origin;
  final Animation<double> transition;
  final EdgeInsets safeAreaInsets;
  final Color? backgroundColor;
  final ValueChanged<SettingsSearchItem> onSelected;
  final VoidCallback onClose;

  @override
  State<_SettingsSearch> createState() => _SettingsSearchState();
}

class _SettingsSearchState extends State<_SettingsSearch> {
  SettingsSearchIndex? _index;
  (AppLocalizations, TargetPlatform, bool, bool)? _configuration;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (logs, dynamicColor) = context.select<SettingsProvider, (bool, bool)>(
      (settings) => (
        settings.requestLogEnabled ||
            settings.flutterLogEnabled ||
            settings.contextLogEnabled,
        settings.dynamicColorSupported,
      ),
    );
    final configuration = (l10n, defaultTargetPlatform, logs, dynamicColor);
    if (_configuration != configuration) {
      _configuration = configuration;
      _index = SettingsSearchIndex(
        l10n,
        platform: defaultTargetPlatform,
        logsEnabled: logs,
        dynamicColorSupported: dynamicColor,
      );
    }
    return SettingsSearchView(
      index: _index!,
      origin: widget.origin,
      transition: widget.transition,
      safeAreaInsets: widget.safeAreaInsets,
      backgroundColor: widget.backgroundColor,
      onSelected: widget.onSelected,
      onClose: widget.onClose,
    );
  }
}
