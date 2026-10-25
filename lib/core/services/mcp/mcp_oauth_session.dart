import 'dart:async';

import '../auth/oauth_callback.dart';

enum McpOAuthStage { discovery, registration, browser, token, reconnect }

final class McpOAuthCancelled implements Exception {
  const McpOAuthCancelled();

  @override
  String toString() => 'MCP OAuth: authorization cancelled';
}

/// One sign-in attempt, independent of the settings page and connection.
final class McpOAuthSession {
  McpOAuthSession({this.onStageChanged});

  final void Function(McpOAuthStage stage)? onStageChanged;
  final Completer<void> _cancelled = Completer<void>();
  OAuthCallback? _callback;
  Future<void>? _closing;
  McpOAuthStage stage = McpOAuthStage.discovery;

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  void check() {
    if (isCancelled) throw const McpOAuthCancelled();
  }

  void moveTo(McpOAuthStage value) {
    check();
    stage = value;
    onStageChanged?.call(value);
  }

  Future<T> wait<T>(Future<T> operation) async {
    final value = await Future.any<T>([
      operation,
      whenCancelled.then<T>((_) => throw const McpOAuthCancelled()),
    ]);
    check();
    return value;
  }

  Future<void> bindCallback(OAuthCallback callback) async {
    _callback = callback;
    if (isCancelled) {
      await close();
      check();
    }
  }

  Future<void> cancel() {
    if (!isCancelled) _cancelled.complete();
    return close();
  }

  Future<void> close() {
    final callback = _callback;
    if (callback == null) return Future<void>.value();
    return _closing ??= callback.close();
  }
}
