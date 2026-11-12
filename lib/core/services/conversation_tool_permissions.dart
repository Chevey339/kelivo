import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/tool_permission_mode.dart';
import '../models/workspace_binding.dart';
import 'chat/chat_service.dart';
import 'api/tool_call_cancellation.dart';
import '../../features/home/services/tool_approval_service.dart';

class ToolPermissionException implements Exception {
  const ToolPermissionException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => '$code: $message';
}

/// Device-local grants belong to a conversation, never the foreground page.
class ConversationToolPermissions {
  ConversationToolPermissions._(this.chat);
  static final _instances = Expando<ConversationToolPermissions>();
  factory ConversationToolPermissions.forChat(ChatService chat) =>
      _instances[chat] ??= ConversationToolPermissions._(chat);
  final ChatService chat;
  final _tails = <String, Future<void>>{};
  final _revisions = <String, int>{};
  final _requestedModes = <String, ToolPermissionMode>{};

  ToolPermissionState? read(String id) {
    final saved = _readStored(id);
    if (saved == null ||
        _requestedModes[id] != ToolPermissionMode.requestApproval) {
      return saved;
    }
    // A queued revocation must also fence new calls while an older enable save
    // is completing. Failed saves remove this fence and retain the stored mode.
    return ToolPermissionState(
      mode: ToolPermissionMode.requestApproval,
      workspaceId: saved.workspaceId,
      assistantId: saved.assistantId,
    );
  }

  ToolPermissionState? _readStored(String id) {
    final conversation = chat.getConversation(id);
    if (conversation == null) return null;
    return ToolPermissionState(
      mode: ToolPermissionMode.fromExtras(conversation.extras),
      workspaceId: WorkspaceBinding.fromExtras(conversation.extras).workspaceId,
      assistantId: conversation.assistantId,
    );
  }

  Future<void> setMode(
    String id,
    ToolPermissionMode mode, {
    ToolApprovalService? approvals,
  }) {
    final expected = read(id);
    if (expected == null) {
      return Future.error(
        const ToolPermissionException(
          'context_changed',
          'Conversation no longer exists',
        ),
      );
    }
    final revision = (_revisions[id] ?? 0) + 1;
    final expectedOwner = chat.getConversation(id)?.copyWith();
    _revisions[id] = revision;
    _requestedModes[id] = mode;
    final previous = _tails[id] ?? Future<void>.value();
    final result = previous.then((_) async {
      final current = read(id);
      if (current == null ||
          current.workspaceId != expected.workspaceId ||
          current.assistantId != expected.assistantId) {
        throw const ToolPermissionException(
          'context_changed',
          'Conversation context changed',
        );
      }
      await chat.updateConversationExtras(id, (extras) {
        final owner = _readStored(id);
        if (owner == null ||
            owner.assistantId != expected.assistantId ||
            WorkspaceBinding.fromExtras(extras).workspaceId !=
                expected.workspaceId) {
          throw const ToolPermissionException(
            'context_changed',
            'Conversation context changed',
          );
        }
        return mode.applyTo(extras);
      }, expectedOwner: expectedOwner);
      final saved = _readStored(id);
      if (saved == null ||
          saved.mode != mode ||
          saved.workspaceId != expected.workspaceId ||
          saved.assistantId != expected.assistantId) {
        throw const ToolPermissionException(
          'context_changed',
          'Permission was not saved',
        );
      }
      if (_revisions[id] == revision && mode == ToolPermissionMode.fullAccess) {
        approvals?.approveConversationTools(
          conversationId: id,
          workspaceId: saved.workspaceId,
          assistantId: saved.assistantId,
        );
      }
    });
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _tails[id] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_tails[id], tail)) {
          _tails.remove(id);
          _revisions.remove(id);
          _requestedModes.remove(id);
        }
      }),
    );
    return result;
  }
}

/// Lives for one tool call. A manual approval never authorizes another call.
class ToolCallPermission {
  ToolCallPermission({
    required this.toolName,
    required this.toolCallId,
    required this.readState,
    this.conversationId,
    this.workspaceId,
    this.assistantId,
    this.approvals,
    this.stateChanges,
    this.isEnabled,
  });
  final String toolName;
  final String toolCallId;
  final String? conversationId;
  final String? workspaceId;
  final String? assistantId;
  final ToolPermissionState? Function() readState;
  final ToolApprovalService? approvals;
  final Listenable? stateChanges;
  final bool Function()? isEnabled;
  bool _approvedOnce = false;
  bool byFullAccess = false;

  ToolPermissionState check() {
    ToolCallCancellation.current?.throwIfCancelled();
    if (isEnabled?.call() == false) {
      throw const ToolPermissionException(
        'tool_disabled',
        'This tool is disabled',
      );
    }
    final state = readState();
    if (state == null ||
        (workspaceId != null && state.workspaceId != workspaceId) ||
        (conversationId != null && state.assistantId != assistantId)) {
      throw const ToolPermissionException(
        'context_changed',
        'Conversation context changed',
      );
    }
    return state;
  }

  Future<void> authorize({
    required bool needed,
    required Map<String, dynamic> arguments,
    String? requestedPath,
    String? realTarget,
  }) async {
    var state = check();
    if (!needed || _approvedOnce) return;
    if (state.mode == ToolPermissionMode.fullAccess) {
      byFullAccess = true;
      return;
    }
    byFullAccess = false;
    if (approvals == null) {
      throw const ToolPermissionException(
        'approval_denied',
        'Approval is unavailable',
      );
    }
    final requestId = toolCallId.isEmpty
        ? '${toolName}_${DateTime.now().microsecondsSinceEpoch}'
        : toolCallId;
    void invalidate() {
      try {
        check();
      } on ToolPermissionException catch (error) {
        approvals!.deny(
          requestId,
          conversationId: conversationId,
          reason: error.code,
        );
      }
    }

    stateChanges?.addListener(invalidate);
    late final ToolApprovalResult result;
    try {
      result = await approvals!.requestApproval(
        toolCallId: requestId,
        toolName: toolName,
        arguments: arguments,
        conversationId: conversationId,
        workspaceId: workspaceId,
        assistantId: assistantId,
        requestedPath: requestedPath,
        realTarget: realTarget,
      );
    } finally {
      stateChanges?.removeListener(invalidate);
    }
    state = check();
    if (!result.approved) {
      throw ToolPermissionException(
        result.denyReason == 'context_changed'
            ? 'context_changed'
            : 'approval_denied',
        result.denyReason ?? 'User denied the tool call',
      );
    }
    if (result.byFullAccess) {
      // A grant may have been revoked while a released call was resuming.
      if (state.mode != ToolPermissionMode.fullAccess) {
        return authorize(
          needed: needed,
          arguments: arguments,
          requestedPath: requestedPath,
          realTarget: realTarget,
        );
      }
      byFullAccess = true;
    } else {
      _approvedOnce = true;
      byFullAccess = false;
    }
  }
}
