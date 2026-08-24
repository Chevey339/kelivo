import 'dart:async';
import 'package:flutter/foundation.dart';

/// Result of a tool approval request.
class ToolApprovalResult {
  final bool approved;
  final String? denyReason;

  const ToolApprovalResult({required this.approved, this.denyReason});

  factory ToolApprovalResult.approved() =>
      const ToolApprovalResult(approved: true);
  factory ToolApprovalResult.denied([String? reason]) =>
      ToolApprovalResult(approved: false, denyReason: reason);
}

typedef _PendingKey = ({String scope, String toolCallId});

/// A pending approval request for an MCP tool call.
class ToolApprovalRequest {
  final String toolCallId;
  final String toolName;
  final Map<String, dynamic> arguments;
  final String? conversationId;
  final Completer<ToolApprovalResult> _completer;

  ToolApprovalRequest({
    required this.toolCallId,
    required this.toolName,
    required this.arguments,
    this.conversationId,
    required this._completer,
  });

  Future<ToolApprovalResult> get future => _completer.future;
}

/// Manages approval state for MCP tool calls that require user confirmation.
///
/// Flow:
/// 1. [requestApproval] is called from the tool handler when a tool needs approval.
///    It creates a [Completer], stores the request in [pendingRequests], and returns
///    the completer's future. The tool handler `await`s this future, blocking execution.
/// 2. The UI watches this service and shows approve/deny buttons.
/// 3. When the user taps approve/deny, [approve] or [deny] completes the completer,
///    unblocking the tool handler.
///
/// Storage is keyed by `(conversationId, toolCallId)` so two chats that share a
/// placeholder id such as `round-0:tool-1` keep independent Completers.
class ToolApprovalService extends ChangeNotifier {
  final Map<_PendingKey, ToolApprovalRequest> _pending = {};
  int _unscopedSeq = 0;

  /// Unmodifiable snapshot of pending approval requests.
  List<ToolApprovalRequest> get pendingRequests =>
      List<ToolApprovalRequest>.unmodifiable(_pending.values);

  /// Whether there are any pending approval requests.
  bool get hasPending => _pending.isNotEmpty;

  /// Check if a specific tool call is pending approval.
  ///
  /// When [conversationId] is omitted, any conversation with [toolCallId] counts.
  /// When it is provided, only that conversation (or an unscoped fail-safe) matches.
  bool isPending(String toolCallId, {String? conversationId}) {
    if (conversationId == null || conversationId.trim().isEmpty) {
      return _pending.values.any((req) => req.toolCallId == toolCallId);
    }
    return pendingFor(toolCallId: toolCallId, conversationId: conversationId) !=
        null;
  }

  /// Look up a pending request by conversation and tool-call id.
  ///
  /// Prefers an exact `(conversationId, toolCallId)` match. If none exists, an
  /// unscoped request (`conversationId == null`) with the same [toolCallId] is
  /// returned as a fail-safe. Another conversation's request is never returned.
  ToolApprovalRequest? pendingFor({
    required String toolCallId,
    String? conversationId,
  }) {
    if (toolCallId.isEmpty) return null;
    final scopedId = conversationId?.trim() ?? '';
    if (scopedId.isNotEmpty) {
      final scoped = _pending[_scopedKey(scopedId, toolCallId)];
      if (scoped != null) return scoped;
      return _findUnscoped(toolCallId);
    }
    final matches = _pending.values
        .where((req) => req.toolCallId == toolCallId)
        .toList();
    if (matches.length == 1) return matches.single;
    return _findUnscoped(toolCallId);
  }

  /// Request approval for a tool call.
  /// Returns a [Future] that completes when the user approves or denies.
  ///
  /// New requests should pass [conversationId]. A null conversation is stored
  /// under a unique unscoped key so two chats cannot overwrite each other.
  Future<ToolApprovalResult> requestApproval({
    required String toolCallId,
    required String toolName,
    required Map<String, dynamic> arguments,
    String? conversationId,
  }) {
    final key = _storageKey(conversationId, toolCallId);
    final existing = _pending[key];
    if (existing != null) {
      return existing.future;
    }
    final completer = Completer<ToolApprovalResult>();
    _pending[key] = ToolApprovalRequest(
      toolCallId: toolCallId,
      toolName: toolName,
      arguments: arguments,
      conversationId: _storedConversationId(conversationId),
      completer: completer,
    );
    notifyListeners();
    return completer.future;
  }

  /// Approve a pending tool call.
  void approve(String toolCallId, {String? conversationId}) {
    final req = _takePending(
      toolCallId: toolCallId,
      conversationId: conversationId,
    );
    if (req != null && !req._completer.isCompleted) {
      req._completer.complete(ToolApprovalResult.approved());
    }
    notifyListeners();
  }

  /// Deny a pending tool call with an optional reason.
  void deny(String toolCallId, {String? reason, String? conversationId}) {
    final req = _takePending(
      toolCallId: toolCallId,
      conversationId: conversationId,
    );
    if (req != null && !req._completer.isCompleted) {
      req._completer.complete(ToolApprovalResult.denied(reason));
    }
    notifyListeners();
  }

  /// Cancel all pending approvals (e.g., when streaming is cancelled).
  void cancelAll() {
    for (final req in _pending.values) {
      if (!req._completer.isCompleted) {
        req._completer.complete(ToolApprovalResult.denied('cancelled'));
      }
    }
    _pending.clear();
    notifyListeners();
  }

  /// Cancel pending approvals that belong to [conversationId]. Requests with
  /// no recorded conversation are cancelled too (fail-safe against leaking a
  /// blocked tool handler), but approvals owned by other conversations keep
  /// waiting so cancelling one conversation cannot break another's stream.
  void cancelForConversation(String conversationId) {
    final toCancel = _pending.values
        .where(
          (req) =>
              req.conversationId == null ||
              req.conversationId == conversationId,
        )
        .toList();
    if (toCancel.isEmpty) return;
    for (final req in toCancel) {
      _pending.removeWhere((_, value) => identical(value, req));
      if (!req._completer.isCompleted) {
        req._completer.complete(ToolApprovalResult.denied('cancelled'));
      }
    }
    notifyListeners();
  }

  ToolApprovalRequest? _takePending({
    required String toolCallId,
    String? conversationId,
  }) {
    final scopedId = conversationId?.trim() ?? '';
    if (scopedId.isNotEmpty) {
      final scoped = _pending.remove(_scopedKey(scopedId, toolCallId));
      if (scoped != null) return scoped;
      return _removeUnscoped(toolCallId);
    }
    final matches = _pending.entries
        .where((entry) => entry.value.toolCallId == toolCallId)
        .toList();
    if (matches.length == 1) {
      _pending.remove(matches.single.key);
      return matches.single.value;
    }
    return _removeUnscoped(toolCallId);
  }

  ToolApprovalRequest? _findUnscoped(String toolCallId) {
    final matches = _pending.values
        .where(
          (req) =>
              req.toolCallId == toolCallId &&
              (req.conversationId == null || req.conversationId!.isEmpty),
        )
        .toList();
    if (matches.length == 1) return matches.single;
    return null;
  }

  ToolApprovalRequest? _removeUnscoped(String toolCallId) {
    final matches = _pending.entries
        .where(
          (entry) =>
              entry.value.toolCallId == toolCallId &&
              (entry.value.conversationId == null ||
                  entry.value.conversationId!.isEmpty),
        )
        .toList();
    if (matches.length != 1) return null;
    _pending.remove(matches.single.key);
    return matches.single.value;
  }

  _PendingKey _storageKey(String? conversationId, String toolCallId) {
    final scopedId = conversationId?.trim() ?? '';
    if (scopedId.isNotEmpty) {
      return _scopedKey(scopedId, toolCallId);
    }
    return (scope: 'unscoped:${_unscopedSeq++}', toolCallId: toolCallId);
  }

  static _PendingKey _scopedKey(String conversationId, String toolCallId) {
    return (scope: conversationId, toolCallId: toolCallId);
  }

  static String? _storedConversationId(String? conversationId) {
    final trimmed = conversationId?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
