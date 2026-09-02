import 'dart:async';

import '../../../core/database/bridge_delivery.dart';
import '../../../core/database/generation_run.dart';
import '../../../core/models/chat_input_data.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/services/chat/chat_service.dart';
import '../controllers/chat_controller.dart';
import 'native_turn.dart';
import 'room_turn.dart';
import 'room_turn_formatter.dart';

abstract interface class KelivoBridgeApi {
  Future<BridgeSendTurnResult> sendTurn(BridgeSendTurnRequest request);

  Future<BridgeHealth> health();

  Future<BridgeSession?> getSession(String conversationId);

  Future<BridgeMessagePage?> getMessages(
    String conversationId, {
    String? after,
  });
}

typedef BridgeDiagnosticsSink =
    FutureOr<void> Function(String event, Map<String, Object?> fields);

abstract interface class BridgeConversationAccess {
  Conversation? get currentConversation;

  bool isTemporaryConversation(String conversationId);

  bool isPersistedConversation(String conversationId);

  Future<List<ChatMessage>> loadSelectedMessages(String conversationId);
}

final class _LiveBridgeConversationAccess implements BridgeConversationAccess {
  const _LiveBridgeConversationAccess(this.controller, this.service);

  final ChatController controller;
  final ChatService service;

  @override
  Conversation? get currentConversation => controller.currentConversation;

  @override
  bool isTemporaryConversation(String conversationId) =>
      service.isTemporaryConversation(conversationId);

  @override
  bool isPersistedConversation(String conversationId) =>
      service.isPersistedConversation(conversationId);

  @override
  Future<List<ChatMessage>> loadSelectedMessages(String conversationId) =>
      service.loadSelectedMessageProjections(conversationId);
}

/// Thin semantic bridge over Kelivo's one live native action graph.
///
/// It deliberately knows nothing about HTTP and performs no direct database
/// writes. P0 accepts only the current, persisted conversation.
final class KelivoBridgeFacade implements KelivoBridgeApi {
  factory KelivoBridgeFacade({
    required NativeTurnActions chatActions,
    required ChatController chatController,
    required ChatService chatService,
    RoomTurnFormatter formatter = const RoomTurnFormatter(),
    BridgeDiagnosticsSink? diagnostics,
  }) => KelivoBridgeFacade._(
    chatActions,
    _LiveBridgeConversationAccess(chatController, chatService),
    formatter,
    diagnostics,
  );

  factory KelivoBridgeFacade.withAccess({
    required NativeTurnActions chatActions,
    required BridgeConversationAccess access,
    RoomTurnFormatter formatter = const RoomTurnFormatter(),
    BridgeDiagnosticsSink? diagnostics,
  }) => KelivoBridgeFacade._(chatActions, access, formatter, diagnostics);

  const KelivoBridgeFacade._(
    this._chatActions,
    this._access,
    this._formatter,
    this._diagnostics,
  );

  static const protocolVersion = 'KELIVO_NATIVE_BRIDGE_P0';
  static const _messagePageLimit = 200;

  final NativeTurnActions _chatActions;
  final BridgeConversationAccess _access;
  final RoomTurnFormatter _formatter;
  final BridgeDiagnosticsSink? _diagnostics;

  @override
  Future<BridgeSendTurnResult> sendTurn(BridgeSendTurnRequest request) async {
    final roomTurn = request.roomTurn;
    final current = _access.currentConversation;
    if (current?.id != request.conversationId) {
      return _failure(request, 'NOT_ACTIVE_CONVERSATION');
    }
    if (_access.isTemporaryConversation(current!.id) ||
        !_access.isPersistedConversation(current.id)) {
      return _failure(request, 'UNSUPPORTED_TEMPORARY_CONVERSATION');
    }

    await _diagnose('bridge_turn_received', <String, Object?>{
      'conversation_id': request.conversationId,
      'room_event_id': roomTurn.roomEventId,
    });

    final start = await _chatActions.sendExternalTurn(
      input: ChatInputData(text: _formatter.format(roomTurn)),
      conversation: current,
      deliveryClaim: BridgeDeliveryClaim(
        originSystem: roomTurn.originSystem,
        originInstanceId: roomTurn.originInstanceId,
        idempotencyKey: request.idempotencyKey,
        requestFingerprint: _formatter.fingerprint(request),
        roomEventId: roomTurn.roomEventId,
        roomId: roomTurn.roomId,
      ),
    );

    if (start.status == NativeTurnStartStatus.busy) {
      return BridgeSendTurnResult(
        status: BridgeSendTurnStatus.busy,
        roomEventId: roomTurn.roomEventId,
        conversationId: request.conversationId,
        deduplicated: false,
        errorCode: start.errorCode,
      );
    }
    if (start.status == NativeTurnStartStatus.idempotencyConflict) {
      return BridgeSendTurnResult(
        status: BridgeSendTurnStatus.idempotencyConflict,
        roomEventId: roomTurn.roomEventId,
        conversationId: request.conversationId,
        deduplicated: false,
        errorCode: 'IDEMPOTENCY_CONFLICT',
      );
    }
    final handle = start.handle;
    if (start.status != NativeTurnStartStatus.accepted || handle == null) {
      return _failure(request, start.errorCode ?? 'NATIVE_SEND_REJECTED');
    }

    final terminal = await handle.completion;
    final status = switch (terminal.state) {
      GenerationRunState.completed => BridgeSendTurnStatus.completed,
      GenerationRunState.cancelled => BridgeSendTurnStatus.cancelled,
      GenerationRunState.interrupted => BridgeSendTurnStatus.interrupted,
      GenerationRunState.failed ||
      GenerationRunState.preparing ||
      GenerationRunState.requesting ||
      GenerationRunState.streaming ||
      GenerationRunState.waitingTool => BridgeSendTurnStatus.failed,
    };
    final result = BridgeSendTurnResult(
      status: status,
      roomEventId: roomTurn.roomEventId,
      conversationId: request.conversationId,
      nativeUserMessageId: terminal.userMessageId,
      nativeAssistantMessageId: terminal.assistantMessageId,
      generationRunId: terminal.generationRunId,
      assistantContent: status == BridgeSendTurnStatus.completed
          ? terminal.assistantMessage.content
          : null,
      deduplicated: handle.deduplicated,
      errorCode: terminal.errorCode,
    );
    await _diagnose('bridge_turn_terminal', <String, Object?>{
      'conversation_id': request.conversationId,
      'room_event_id': roomTurn.roomEventId,
      'status': status.wireValue,
      'deduplicated': handle.deduplicated,
    });
    return result;
  }

  BridgeSendTurnResult _failure(
    BridgeSendTurnRequest request,
    String errorCode,
  ) => BridgeSendTurnResult(
    status: BridgeSendTurnStatus.failed,
    roomEventId: request.roomTurn.roomEventId,
    conversationId: request.conversationId,
    deduplicated: false,
    errorCode: errorCode,
  );

  @override
  Future<BridgeHealth> health() async {
    final current = _access.currentConversation;
    final ready =
        current != null &&
        !_access.isTemporaryConversation(current.id) &&
        _access.isPersistedConversation(current.id);
    return BridgeHealth(ready: ready, protocolVersion: protocolVersion);
  }

  @override
  Future<BridgeSession?> getSession(String conversationId) async {
    final current = _access.currentConversation;
    if (current?.id != conversationId) return null;
    return BridgeSession(
      conversationId: conversationId,
      active: true,
      persisted:
          !_access.isTemporaryConversation(conversationId) &&
          _access.isPersistedConversation(conversationId),
      assistantId: current!.assistantId,
      branchRevision: Map<String, int>.unmodifiable(current.versionSelections),
    );
  }

  @override
  Future<BridgeMessagePage?> getMessages(
    String conversationId, {
    String? after,
  }) async {
    final current = _access.currentConversation;
    if (current?.id != conversationId ||
        _access.isTemporaryConversation(conversationId) ||
        !_access.isPersistedConversation(conversationId)) {
      return null;
    }
    final messages = await _access.loadSelectedMessages(conversationId);
    final afterIndex = after == null
        ? -1
        : messages.indexWhere((message) => message.id == after);
    final start = afterIndex < 0 ? 0 : afterIndex + 1;
    final end = start + _messagePageLimit < messages.length
        ? start + _messagePageLimit
        : messages.length;
    final page = List<ChatMessage>.unmodifiable(
      messages.sublist(start > messages.length ? messages.length : start, end),
    );
    return BridgeMessagePage(
      messages: page,
      nextAfter: end < messages.length && page.isNotEmpty ? page.last.id : null,
    );
  }

  Future<void> _diagnose(String event, Map<String, Object?> fields) async {
    final diagnostics = _diagnostics;
    if (diagnostics == null) return;
    try {
      await diagnostics(event, fields);
    } catch (_) {
      // Diagnostics are deliberately non-critical to native generation.
    }
  }
}
