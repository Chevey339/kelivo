import 'dart:async';

import 'package:flutter/scheduler.dart';

/// Waits for an idle slot without repeatedly queuing zero-delay tasks while an
/// animation is active. A denied slot is checked again after the next frame.
/// Returns false if [cancelled] completes first.
Future<bool> waitForSchedulerIdle({Future<void>? cancelled}) {
  final binding = SchedulerBinding.instance;
  final ready = Completer<bool>();
  void check() {
    if (ready.isCompleted) return;
    if (binding.schedulingStrategy(
      priority: Priority.idle.value,
      scheduler: binding,
    )) {
      ready.complete(true);
    } else {
      binding.addPostFrameCallback((_) => check());
    }
  }

  if (cancelled != null) {
    unawaited(
      cancelled.then((_) {
        if (!ready.isCompleted) ready.complete(false);
      }),
    );
  }
  // Preserve the asynchronous boundary even when there is no active animation.
  Timer.run(check);
  return ready.future;
}
