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
  static Future<void> Function()? _prepare;
  static Future<void> Function()? _close;
  static Future<void>? _flushFuture;
  static Future<void>? _shutdownFuture;

  static bool get isExiting => _shutdownFuture != null;

  /// The process owner stops producers before flushing and closes the database
  /// afterwards. Ordinary flushes (for example before restart) do not close it.
  static void configureShutdown({
    required Future<void> Function() prepare,
    required Future<void> Function() close,
  }) {
    _prepare = prepare;
    _close = close;
  }

  static void register(Future<void> Function() handler) {
    _handlers.add(handler);
  }

  static void unregister(Future<void> Function() handler) {
    _handlers.remove(handler);
  }

  static Future<void> flushAll() => _shutdownFuture ?? _flush();

  static Future<void> _flush() =>
      _flushFuture ??= _flushHandlers().whenComplete(() => _flushFuture = null);

  static Future<void> _flushHandlers() async {
    for (final handler in List<Future<void> Function()>.of(_handlers)) {
      try {
        await handler();
      } catch (_) {}
    }
  }

  /// Tray and engine exit requests share one shutdown, including its deadline.
  /// A timeout does not start closing underneath a still-running write: the
  /// ordered work continues until the engine terminates the process.
  static Future<void> shutdown({
    Duration timeout = const Duration(seconds: 5),
  }) => _shutdownFuture ??=
      Future<void>.microtask(() async {
        try {
          await _prepare?.call();
        } finally {
          try {
            await _flush();
          } finally {
            await _close?.call();
          }
        }
      }).timeout(timeout).catchError((Object error) {
        debugPrint('App shutdown did not finish: $error');
      });

  @visibleForTesting
  static void debugReset() {
    _handlers.clear();
    _prepare = null;
    _close = null;
    _flushFuture = null;
    _shutdownFuture = null;
  }
}
