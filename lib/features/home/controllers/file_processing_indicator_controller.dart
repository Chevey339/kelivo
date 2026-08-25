import 'dart:async';

import 'package:flutter/foundation.dart';

/// Owns the "parsing files" indicator: which assistant message shows it, and
/// the timing that keeps it honest.
///
/// Two rules drive everything here:
///
/// * **Ownership.** Exactly one message owns the indicator at a time, and only
///   that owner may clear it. A generation finishing in a background
///   conversation must not hide the bar another conversation just raised.
/// * **Timing.** Attachment parsing is usually milliseconds, so the bar waits
///   [showDelay] before appearing and then stays for at least [minVisible].
///   A parse that beats the delay never renders at all.
class FileProcessingIndicatorController {
  FileProcessingIndicatorController({
    this.showDelay = const Duration(milliseconds: 220),
    this.minVisible = const Duration(milliseconds: 320),
  });

  /// How long parsing must run before the indicator appears.
  final Duration showDelay;

  /// How long the indicator stays once it has appeared.
  final Duration minVisible;

  /// Assistant message currently showing the indicator, or null.
  final ValueNotifier<String?> messageId = ValueNotifier<String?>(null);

  Timer? _showTimer;
  Timer? _holdTimer;
  String? _pendingMessageId;
  bool _finishRequested = false;

  /// Message waiting out [showDelay], or the visible one once it appeared.
  @visibleForTesting
  String? get owner => _pendingMessageId ?? messageId.value;

  /// Parsing started for [id]. A different message takes ownership at once.
  void start(String id) {
    if (messageId.value == id) {
      // Already visible for this message: keep it and drop a pending hide.
      _finishRequested = false;
      _pendingMessageId = id;
      return;
    }
    if (_pendingMessageId == id && _showTimer != null) return;
    reset();
    _pendingMessageId = id;
    _showTimer = Timer(showDelay, _show);
  }

  /// Parsing finished for [id]. A null [id] clears whoever owns the indicator
  /// and is reserved for teardown — normal terminal paths pass their own id so
  /// they cannot clear another conversation's bar.
  void finish(String? id) {
    if (id != null) {
      final current = owner;
      if (current != null && current != id) return;
    }
    _pendingMessageId = null;
    _showTimer?.cancel();
    _showTimer = null;
    if (messageId.value == null) {
      _finishRequested = false;
      return;
    }
    if (_holdTimer != null) {
      // Still inside the minimum-visible hold; hide when it expires.
      _finishRequested = true;
      return;
    }
    _clear();
  }

  /// Drops the indicator immediately, ignoring the minimum-visible hold. For
  /// conversation switches and teardown, where the owner left the screen.
  void reset() {
    _showTimer?.cancel();
    _showTimer = null;
    _pendingMessageId = null;
    _clear();
  }

  void dispose() {
    _showTimer?.cancel();
    _holdTimer?.cancel();
    messageId.dispose();
  }

  void _show() {
    _showTimer = null;
    final pending = _pendingMessageId;
    if (pending == null) return;
    messageId.value = pending;
    _holdTimer = Timer(minVisible, () {
      _holdTimer = null;
      if (_finishRequested) _clear();
    });
  }

  void _clear() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _finishRequested = false;
    messageId.value = null;
  }
}
