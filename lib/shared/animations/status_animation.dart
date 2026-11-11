import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A repeating status effect driven by a shared, on-demand 30 Hz clock.
///
/// Unlike a repeating AnimationController, this does not request a frame at
/// every display vsync. Builders can pass [ValueListenable] directly to a
/// painter so only the small animated surface needs repainting.
class StatusAnimation extends StatefulWidget {
  const StatusAnimation({
    super.key,
    required this.duration,
    required this.builder,
    this.paused = false,
    this.initialValue = 0,
  }) : assert(duration > Duration.zero),
       assert(initialValue >= 0 && initialValue < 1);

  final Duration duration;
  final Widget Function(BuildContext, ValueListenable<double>) builder;
  final bool paused;
  final double initialValue;

  @override
  State<StatusAnimation> createState() => _StatusAnimationState();
}

class _StatusAnimationState extends State<StatusAnimation> {
  final _clock = _StatusAnimationClock.instance;
  late final _progress = ValueNotifier<double>(widget.initialValue);
  Duration _lastTick = Duration.zero;
  bool _listening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPlayback();
  }

  @override
  void didUpdateWidget(StatusAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPlayback();
  }

  void _syncPlayback() {
    final active =
        !widget.paused &&
        TickerMode.valuesOf(context).enabled &&
        Visibility.of(context) &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false) &&
        !(MediaQuery.maybeAccessibleNavigationOf(context) ?? false);
    if (active == _listening) return;
    _listening = active;
    if (active) {
      _lastTick = _clock.elapsed;
      _clock.addListener(_tick);
    } else {
      _clock.removeListener(_tick);
    }
  }

  void _tick() {
    final elapsed = _clock.elapsed;
    _progress.value =
        (_progress.value +
            (elapsed - _lastTick).inMicroseconds /
                widget.duration.inMicroseconds) %
        1;
    _lastTick = elapsed;
  }

  @override
  void dispose() {
    if (_listening) _clock.removeListener(_tick);
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _progress);
}

class _StatusAnimationClock extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = _StatusAnimationClock();
  static const _interval = Duration(microseconds: 33334);

  Duration elapsed = Duration.zero;
  Duration? _lastFrameTime;
  Timer? _timer;
  int? _frameId;

  @override
  void addListener(VoidCallback listener) {
    final wasEmpty = !hasListeners;
    super.addListener(listener);
    if (wasEmpty) {
      WidgetsBinding.instance.addObserver(this);
      _syncPlayback();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      WidgetsBinding.instance.removeObserver(this);
      _stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncPlayback();

  void _syncPlayback() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!hasListeners ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      _stop();
    } else {
      _timer ??= Timer.periodic(_interval, (_) => _scheduleFrame());
    }
  }

  void _scheduleFrame() {
    // Coalesce timers if the UI thread has not presented the previous pulse.
    if (_frameId != null) return;
    _frameId = WidgetsBinding.instance.scheduleFrameCallback((time) {
      _frameId = null;
      elapsed += _lastFrameTime == null ? _interval : time - _lastFrameTime!;
      _lastFrameTime = time;
      notifyListeners();
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _lastFrameTime = null;
    if (_frameId != null) {
      WidgetsBinding.instance.cancelFrameCallbackWithId(_frameId!);
      _frameId = null;
    }
  }
}
