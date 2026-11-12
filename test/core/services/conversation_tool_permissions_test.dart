import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/tool_permission_mode.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/conversation_tool_permissions.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';

class MemoryChat extends ChatService {
  Conversation? conversation = Conversation(
    id: 'a',
    title: 'Test',
    assistantId: 'assistant',
    extras: const WorkspaceBinding(workspaceId: 'w').applyTo({}),
  );
  Completer<void>? saveBarrier;
  bool failSave = false;
  @override
  Conversation? getConversation(String id) =>
      conversation?.id == id ? conversation : null;
  @override
  Future<void> updateConversationExtras(
    String id,
    Map<String, dynamic> Function(Map<String, dynamic>) update, {
    Conversation? expectedOwner,
  }) async {
    await saveBarrier?.future;
    if (failSave) throw StateError('disk full');
    final current = getConversation(id);
    if (current == null) return;
    conversation = current.copyWith(extras: update(current.extras));
    notifyListeners();
  }
}

void main() {
  test('missing, malformed and legacy grants never imply full access', () {
    for (final value in [null, true, 42, 'unknown']) {
      expect(
        ToolPermissionMode.fromExtras({
          'workspace.allowAll': true,
          ToolPermissionMode.extrasKey: value,
        }),
        ToolPermissionMode.requestApproval,
      );
    }
    final full = ToolPermissionMode.fullAccess.applyTo({
      'workspace.allowAll': true,
      'keep': 1,
    });
    expect(full['workspace.allowAll'], isNull);
    expect(full['keep'], 1);
    expect(ToolPermissionMode.fromExtras(full), ToolPermissionMode.fullAccess);
    expect(
      ToolPermissionMode.fromExtras(
        const WorkspaceBinding(workspaceId: 'other').applyTo(full),
      ),
      ToolPermissionMode.requestApproval,
    );
  });
  test('save failure keeps mode and pending calls unchanged', () async {
    final chat = MemoryChat()..failSave = true;
    final approvals = ToolApprovalService();
    addTearDown(chat.dispose);
    addTearDown(approvals.dispose);
    final pending = approvals.requestApproval(
      toolCallId: 'tool',
      toolName: 'shell',
      arguments: {},
      conversationId: 'a',
      workspaceId: 'w',
    );
    await expectLater(
      ConversationToolPermissions.forChat(
        chat,
      ).setMode('a', ToolPermissionMode.fullAccess, approvals: approvals),
      throwsStateError,
    );
    expect(
      ConversationToolPermissions.forChat(chat).read('a')!.mode,
      ToolPermissionMode.requestApproval,
    );
    expect(approvals.hasPending, isTrue);
    approvals.cancelAll();
    expect((await pending).approved, isFalse);
  });
  test(
    'rapid enable then revoke does not release queued calls from a stale save',
    () async {
      final chat = MemoryChat()..saveBarrier = Completer<void>();
      final approvals = ToolApprovalService();
      addTearDown(chat.dispose);
      addTearDown(approvals.dispose);
      final pending = approvals.requestApproval(
        toolCallId: 'tool',
        toolName: 'shell',
        arguments: {},
        conversationId: 'a',
        workspaceId: 'w',
      );
      final permissions = ConversationToolPermissions.forChat(chat);
      final observed = <ToolPermissionMode>[];
      chat.addListener(() => observed.add(permissions.read('a')!.mode));
      final enabled = permissions.setMode(
        'a',
        ToolPermissionMode.fullAccess,
        approvals: approvals,
      );
      final revoked = permissions.setMode(
        'a',
        ToolPermissionMode.requestApproval,
        approvals: approvals,
      );
      chat.saveBarrier!.complete();
      await enabled;
      await revoked;
      expect(permissions.read('a')!.mode, ToolPermissionMode.requestApproval);
      expect(observed, everyElement(ToolPermissionMode.requestApproval));
      expect(approvals.hasPending, isTrue);
      approvals.cancelAll();
      expect((await pending).approved, isFalse);
    },
  );
  test(
    'an owner change while saving cannot grant access to the new assistant',
    () async {
      final chat = MemoryChat()..saveBarrier = Completer<void>();
      addTearDown(chat.dispose);
      final permission = ConversationToolPermissions.forChat(chat);
      final saved = permission.setMode('a', ToolPermissionMode.fullAccess);
      final result = expectLater(
        saved,
        throwsA(isA<ToolPermissionException>()),
      );
      await Future<void>.delayed(Duration.zero);
      chat.conversation = chat.conversation!.copyWith(assistantId: 'other');
      chat.saveBarrier!.complete();
      await result;
      expect(permission.read('a')!.mode, ToolPermissionMode.requestApproval);
    },
  );
  test(
    'binding changes invalidate a waiting request without another user action',
    () async {
      final chat = MemoryChat();
      final approvals = ToolApprovalService();
      addTearDown(chat.dispose);
      addTearDown(approvals.dispose);
      final permissions = ConversationToolPermissions.forChat(chat);
      final call = ToolCallPermission(
        toolName: 'shell',
        toolCallId: 'pending',
        conversationId: 'a',
        workspaceId: 'w',
        assistantId: 'assistant',
        approvals: approvals,
        stateChanges: chat,
        readState: () => permissions.read('a'),
      );
      final pending = call.authorize(needed: true, arguments: {});
      final expectation = expectLater(
        pending,
        throwsA(
          isA<ToolPermissionException>().having(
            (e) => e.code,
            'code',
            'context_changed',
          ),
        ),
      );
      await chat.updateConversationExtras(
        'a',
        const WorkspaceBinding(workspaceId: 'other').applyTo,
      );
      await expectation;
      expect(approvals.hasPending, isFalse);
    },
  );
  test(
    'enabled tool cannot execute after it is disabled during approval',
    () async {
      var enabled = true;
      final approvals = ToolApprovalService();
      addTearDown(approvals.dispose);
      final call = ToolCallPermission(
        toolName: 'read_file',
        toolCallId: 'pending',
        conversationId: 'a',
        approvals: approvals,
        isEnabled: () => enabled,
        readState: () => const ToolPermissionState(),
      );
      final pending = call.authorize(needed: true, arguments: {});
      final expectation = expectLater(
        pending,
        throwsA(
          isA<ToolPermissionException>().having(
            (e) => e.code,
            'code',
            'tool_disabled',
          ),
        ),
      );
      enabled = false;
      approvals.approve('pending', conversationId: 'a');
      await expectation;
    },
  );
}
