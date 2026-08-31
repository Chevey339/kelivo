import 'dart:async';

import 'package:Kelivo/core/database/bridge_delivery.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/features/home/bridge/kelivo_bridge_facade.dart';
import 'package:Kelivo/features/home/bridge/native_turn.dart';
import 'package:Kelivo/features/home/bridge/room_turn.dart';
import 'package:Kelivo/features/home/bridge/room_turn_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 8, 30, 12, 34, 56);

  RoomTurn turn({String content = 'Remember nonce 7f3a'}) => RoomTurn(
    roomEventId: 'event-1',
    roomId: 'room-1',
    originSystem: 'test-harness',
    originInstanceId: 'harness-1',
    sender: const RoomSender(
      id: 'agent-2',
      displayName: 'Peer',
      kind: RoomSenderKind.peerAgent,
    ),
    createdAt: createdAt,
    content: content,
    addressedToAgent: true,
    replyToRoomMessageId: 'room-message-9',
    causationId: 'cause-1',
    correlationId: 'round-1',
  );

  BridgeSendTurnRequest request({
    String conversationId = 'conversation-1',
    String content = 'Remember nonce 7f3a',
  }) => BridgeSendTurnRequest(
    conversationId: conversationId,
    roomTurn: turn(content: content),
    idempotencyKey: 'delivery-secret-key',
  );

  test('RoomTurn formatter is stable and derives untrusted peer content', () {
    const formatter = RoomTurnFormatter();
    final formatted = formatter.format(turn());

    expect(formatted, startsWith('ROOM_EVENT\n{'));
    expect(formatted, contains('"trust_class":"untrusted_peer_content"'));
    expect(formatted, contains('"content":"Remember nonce 7f3a"'));
    expect(formatted, isNot(contains('delivery-secret-key')));
    expect(formatter.format(turn()), formatted);
    expect(formatter.fingerprint(request()), hasLength(64));
    expect(
      formatter.fingerprint(request(content: 'changed')),
      isNot(formatter.fingerprint(request())),
    );
  });

  test('non-active conversation is rejected before native actions', () async {
    final access = _TestBridgeAccess(
      Conversation(id: 'conversation-1', title: 'Active'),
    );
    final actions = _TestNativeTurnActions(
      _completedStart(conversationId: 'conversation-1'),
    );
    final facade = KelivoBridgeFacade.withAccess(
      chatActions: actions,
      access: access,
    );

    final result = await facade.sendTurn(
      request(conversationId: 'conversation-other'),
    );

    expect(result.status, BridgeSendTurnStatus.failed);
    expect(result.errorCode, 'NOT_ACTIVE_CONVERSATION');
    expect(actions.callCount, 0);
  });

  test(
    'temporary active conversation is rejected before native actions',
    () async {
      final access = _TestBridgeAccess(
        Conversation(id: 'conversation-1', title: 'Temporary'),
        temporary: true,
        persisted: false,
      );
      final actions = _TestNativeTurnActions(
        _completedStart(conversationId: 'conversation-1'),
      );
      final facade = KelivoBridgeFacade.withAccess(
        chatActions: actions,
        access: access,
      );

      final result = await facade.sendTurn(request());

      expect(result.status, BridgeSendTurnStatus.failed);
      expect(result.errorCode, 'UNSUPPORTED_TEMPORARY_CONVERSATION');
      expect(actions.callCount, 0);
      expect((await facade.health()).ready, isFalse);
    },
  );

  test('busy returns defer semantics without a native turn', () async {
    final access = _TestBridgeAccess(
      Conversation(id: 'conversation-1', title: 'Active'),
    );
    final actions = _TestNativeTurnActions(
      const NativeTurnStartResult(
        status: NativeTurnStartStatus.busy,
        errorCode: 'GENERATION_BUSY',
      ),
    );
    final facade = KelivoBridgeFacade.withAccess(
      chatActions: actions,
      access: access,
    );

    final result = await facade.sendTurn(request());

    expect(result.status, BridgeSendTurnStatus.busy);
    expect(result.nativeUserMessageId, isNull);
    expect(result.nativeAssistantMessageId, isNull);
    expect(actions.callCount, 1);
  });

  test(
    'final result waits for native completion and ignores diagnostics failure',
    () async {
      final conversation = Conversation(
        id: 'conversation-1',
        title: 'Active',
        assistantId: 'assistant-owner',
        versionSelections: const {'assistant-group': 2},
      );
      final access = _TestBridgeAccess(conversation);
      final completion = Completer<NativeTurnTerminalResult>();
      final actions = _TestNativeTurnActions(
        NativeTurnStartResult(
          status: NativeTurnStartStatus.accepted,
          handle: NativeTurnHandle(
            userMessageId: 'user-1',
            assistantMessageId: 'assistant-1',
            generationRunId: 'run-1',
            deduplicated: false,
            completion: completion.future,
          ),
        ),
      );
      final facade = KelivoBridgeFacade.withAccess(
        chatActions: actions,
        access: access,
        diagnostics: (_, _) => throw StateError('diagnostics unavailable'),
      );

      final future = facade.sendTurn(request());
      await Future<void>.delayed(Duration.zero);
      expect(actions.lastInput?.text, startsWith('ROOM_EVENT\n'));
      expect(actions.lastClaim?.idempotencyKey, 'delivery-secret-key');
      expect(actions.lastClaim?.requestFingerprint, hasLength(64));
      expect(actions.lastInput?.text, isNot(contains('delivery-secret-key')));

      final assistantMessage = ChatMessage(
        id: 'assistant-1',
        conversationId: conversation.id,
        role: 'assistant',
        content: 'nonce 7f3a',
        isStreaming: false,
      );
      completion.complete(
        NativeTurnTerminalResult(
          state: GenerationRunState.completed,
          userMessageId: 'user-1',
          assistantMessageId: 'assistant-1',
          generationRunId: 'run-1',
          assistantMessage: assistantMessage,
        ),
      );
      final result = await future;

      expect(result.status, BridgeSendTurnStatus.completed);
      expect(result.assistantContent, 'nonce 7f3a');
      expect(result.nativeUserMessageId, 'user-1');
      expect(result.nativeAssistantMessageId, 'assistant-1');
      expect(result.generationRunId, 'run-1');
      expect(result.deduplicated, isFalse);
      final session = await facade.getSession(conversation.id);
      expect(session?.assistantId, 'assistant-owner');
      expect(session?.branchRevision, {'assistant-group': 2});
    },
  );

  test(
    'idempotency conflict is returned without terminal completion',
    () async {
      final access = _TestBridgeAccess(
        Conversation(id: 'conversation-1', title: 'Active'),
      );
      final actions = _TestNativeTurnActions(
        const NativeTurnStartResult(
          status: NativeTurnStartStatus.idempotencyConflict,
          errorCode: 'IDEMPOTENCY_CONFLICT',
        ),
      );
      final facade = KelivoBridgeFacade.withAccess(
        chatActions: actions,
        access: access,
      );

      final result = await facade.sendTurn(request());

      expect(result.status, BridgeSendTurnStatus.idempotencyConflict);
      expect(result.errorCode, 'IDEMPOTENCY_CONFLICT');
      expect(result.deduplicated, isFalse);
    },
  );
}

NativeTurnStartResult _completedStart({required String conversationId}) {
  final assistant = ChatMessage(
    id: 'assistant-1',
    conversationId: conversationId,
    role: 'assistant',
    content: 'done',
    isStreaming: false,
  );
  return NativeTurnStartResult(
    status: NativeTurnStartStatus.accepted,
    handle: NativeTurnHandle(
      userMessageId: 'user-1',
      assistantMessageId: assistant.id,
      generationRunId: 'run-1',
      deduplicated: false,
      completion: Future<NativeTurnTerminalResult>.value(
        NativeTurnTerminalResult(
          state: GenerationRunState.completed,
          userMessageId: 'user-1',
          assistantMessageId: assistant.id,
          generationRunId: 'run-1',
          assistantMessage: assistant,
        ),
      ),
    ),
  );
}

final class _TestNativeTurnActions implements NativeTurnActions {
  _TestNativeTurnActions(this.result);

  final NativeTurnStartResult result;
  int callCount = 0;
  ChatInputData? lastInput;
  BridgeDeliveryClaim? lastClaim;

  @override
  Future<NativeTurnStartResult> sendExternalTurn({
    required ChatInputData input,
    required Conversation conversation,
    required BridgeDeliveryClaim deliveryClaim,
  }) async {
    callCount += 1;
    lastInput = input;
    lastClaim = deliveryClaim;
    return result;
  }
}

final class _TestBridgeAccess implements BridgeConversationAccess {
  _TestBridgeAccess(
    this.activeConversation, {
    this.temporary = false,
    this.persisted = true,
  });

  final Conversation? activeConversation;
  final bool temporary;
  final bool persisted;

  @override
  Conversation? get currentConversation => activeConversation;

  @override
  bool isTemporaryConversation(String id) => temporary;

  @override
  bool isPersistedConversation(String id) => persisted;

  @override
  Future<List<ChatMessage>> loadSelectedMessages(String conversationId) async =>
      const <ChatMessage>[];
}
