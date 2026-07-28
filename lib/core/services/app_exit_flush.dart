import 'dart:async';

import 'package:flutter/foundation.dart';

/// Process-exit flush registry (desktop only).
///
/// Handlers run from AppLifecycleListener.onExitRequested so in-memory write
/// queues reach durable storage before the process exits. Handlers must be
/// fast and idempotent; a failing handler is skipped so later ones still run.
final class AppExitFlush {
  AppExitFlush._();

  static final List<Future<void> Function()> _handlers =
      <Future<void> Function()>[];

  static void register(Future<void> Function() handler) {
    _handlers.add(handler);
  }

  static Future<void> flushAll() async {
    for (final handler in List<Future<void> Function()>.of(_handlers)) {
      try {
        await handler();
      } catch (_) {}
    }
  }

  @visibleForTesting
  static void debugReset() {
    _handlers.clear();
  }
}
