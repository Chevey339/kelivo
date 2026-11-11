import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Development executable support. No flutter_test import or test binding.
/// Input is synthesized through Flutter; hardware and display scanout are not
/// measured. Idle waiting uses timers and never requests an extra frame.
class GenUiProfileHarness {
  final _root = GlobalKey();
  final _pointerClock = Stopwatch()..start();
  int _nextPointer = 1;
  int get viewId => ui.PlatformDispatcher.instance.views.first.viewId;

  Future<void> mount(Widget child) async {
    runApp(KeyedSubtree(key: _root, child: child));
    // An explicit mount needs a frame. This is never called in a timing region.
    await WidgetsBinding.instance.endOfFrame;
    await settle();
  }

  Future<void> settle() async {
    final limit = DateTime.now().add(const Duration(seconds: 10));
    var quiet = 0;
    while (quiet < 3 && DateTime.now().isBefore(limit)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final binding = SchedulerBinding.instance;
      quiet = !binding.hasScheduledFrame && binding.transientCallbackCount == 0
          ? quiet + 1
          : 0;
    }
  }

  Iterable<Element> _walk(Element root) sync* {
    yield root;
    final children = <Element>[];
    root.visitChildren(children.add);
    for (final child in children) {
      yield* _walk(child);
    }
  }

  Element element(bool Function(Widget) predicate) => _walk(
    _root.currentContext! as Element,
  ).firstWhere((e) => predicate(e.widget));
  T widget<T extends Widget>() => element((w) => w is T).widget as T;
  Rect rect(bool Function(Widget) predicate) {
    final box = element(predicate).findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<Map<String, Object?>> drag(
    Offset from,
    Offset to,
    Duration duration,
  ) async {
    final pointer = _nextPointer++;
    void dispatch(PointerEvent event) =>
        GestureBinding.instance.handlePointerEvent(event);
    final watch = Stopwatch()..start();
    var events = 0, latenessUs = 0;
    dispatch(
      PointerDownEvent(
        pointer: pointer,
        position: from,
        viewId: viewId,
        timeStamp: _pointerClock.elapsed,
      ),
    );
    var previous = from;
    while (watch.elapsed < duration) {
      final requested = watch.elapsedMicroseconds + 16667;
      await Future<void>.delayed(const Duration(microseconds: 16667));
      final elapsed = watch.elapsedMicroseconds;
      latenessUs += (elapsed - requested).clamp(0, 1 << 62);
      final ratio = (elapsed / duration.inMicroseconds).clamp(0.0, 1.0);
      final position = Offset.lerp(from, to, ratio)!;
      dispatch(
        PointerMoveEvent(
          pointer: pointer,
          position: position,
          delta: position - previous,
          buttons: kPrimaryButton,
          viewId: viewId,
          timeStamp: _pointerClock.elapsed,
        ),
      );
      previous = position;
      events++;
    }
    dispatch(
      PointerUpEvent(
        pointer: pointer,
        position: to,
        viewId: viewId,
        timeStamp: _pointerClock.elapsed,
      ),
    );
    return {
      'moves': events,
      'elapsedUs': watch.elapsedMicroseconds,
      'meanTimerLatenessUs': events == 0 ? null : latenessUs / events,
      'logicalDistance': (to - from).distance,
      'viewId': viewId,
    };
  }

  Future<void> hover(Rect rect) async {
    GestureBinding.instance.handlePointerEvent(
      PointerAddedEvent(
        kind: ui.PointerDeviceKind.mouse,
        device: 99,
        position: rect.center,
        viewId: viewId,
      ),
    );
    var previous = rect.center;
    for (var i = 0; i < 240; i++) {
      final position = Offset(
        rect.left + 45 + (rect.width - 70) * (i % 120) / 120,
        rect.top + 35 + (rect.height - 60) * (i % 20) / 20,
      );
      GestureBinding.instance.handlePointerEvent(
        PointerHoverEvent(
          kind: ui.PointerDeviceKind.mouse,
          device: 99,
          position: position,
          delta: position - previous,
          viewId: viewId,
          timeStamp: _pointerClock.elapsed,
        ),
      );
      previous = position;
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    GestureBinding.instance.handlePointerEvent(
      PointerRemovedEvent(
        kind: ui.PointerDeviceKind.mouse,
        device: 99,
        position: previous,
        viewId: viewId,
      ),
    );
  }
}
