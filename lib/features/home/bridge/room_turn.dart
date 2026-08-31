import '../../../core/models/chat_message.dart';

enum RoomSenderKind {
  human('human'),
  peerAgent('peer_agent');

  const RoomSenderKind(this.wireValue);

  final String wireValue;

  static RoomSenderKind parse(Object? value) => switch (value) {
    'human' => RoomSenderKind.human,
    'peer_agent' => RoomSenderKind.peerAgent,
    _ => throw const FormatException('invalid_sender_kind'),
  };
}

final class RoomSender {
  const RoomSender({
    required this.id,
    required this.displayName,
    required this.kind,
  });

  final String id;
  final String displayName;
  final RoomSenderKind kind;

  factory RoomSender.fromJson(Map<String, Object?> json) => RoomSender(
    id: _requiredString(json, 'id'),
    displayName: _requiredString(json, 'display_name'),
    kind: RoomSenderKind.parse(json['kind']),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'display_name': displayName,
    'kind': kind.wireValue,
  };
}

/// One structured event received from an external room.
///
/// Every field is untrusted input. In particular, trust classification is not
/// accepted from JSON and is derived locally by the room-turn formatter.
final class RoomTurn {
  const RoomTurn({
    required this.roomEventId,
    required this.roomId,
    required this.originSystem,
    required this.originInstanceId,
    required this.sender,
    required this.createdAt,
    required this.content,
    required this.addressedToAgent,
    this.replyToRoomMessageId,
    this.causationId,
    this.correlationId,
  });

  final String roomEventId;
  final String roomId;
  final String originSystem;
  final String originInstanceId;
  final RoomSender sender;
  final DateTime createdAt;
  final String content;
  final String? replyToRoomMessageId;
  final bool addressedToAgent;
  final String? causationId;
  final String? correlationId;

  factory RoomTurn.fromJson(Map<String, Object?> json) {
    final senderJson = json['sender'];
    if (senderJson is! Map) {
      throw const FormatException('invalid_sender');
    }
    final createdAtValue = _requiredString(json, 'created_at');
    final createdAt = DateTime.tryParse(createdAtValue);
    if (createdAt == null) {
      throw const FormatException('invalid_created_at');
    }
    final addressedToAgent = json['addressed_to_agent'];
    if (addressedToAgent is! bool) {
      throw const FormatException('invalid_addressed_to_agent');
    }
    return RoomTurn(
      roomEventId: _requiredString(json, 'room_event_id'),
      roomId: _requiredString(json, 'room_id'),
      originSystem: _requiredString(json, 'origin_system'),
      originInstanceId: _requiredString(json, 'origin_instance_id'),
      sender: RoomSender.fromJson(Map<String, Object?>.from(senderJson)),
      createdAt: createdAt.toUtc(),
      content: _requiredString(json, 'content'),
      replyToRoomMessageId: _optionalString(json, 'reply_to_room_message_id'),
      addressedToAgent: addressedToAgent,
      causationId: _optionalString(json, 'causation_id'),
      correlationId: _optionalString(json, 'correlation_id'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'room_event_id': roomEventId,
    'room_id': roomId,
    'origin_system': originSystem,
    'origin_instance_id': originInstanceId,
    'sender': sender.toJson(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'content': content,
    'reply_to_room_message_id': replyToRoomMessageId,
    'addressed_to_agent': addressedToAgent,
    'causation_id': causationId,
    'correlation_id': correlationId,
  };
}

final class BridgeSendTurnRequest {
  const BridgeSendTurnRequest({
    required this.conversationId,
    required this.roomTurn,
    required this.idempotencyKey,
  });

  final String conversationId;
  final RoomTurn roomTurn;
  final String idempotencyKey;

  factory BridgeSendTurnRequest.fromJson(Map<String, Object?> json) {
    final roomEvent = json['room_event'];
    if (roomEvent is! Map) {
      throw const FormatException('invalid_room_event');
    }
    return BridgeSendTurnRequest(
      conversationId: _requiredString(json, 'conversation_id'),
      roomTurn: RoomTurn.fromJson(Map<String, Object?>.from(roomEvent)),
      idempotencyKey: _requiredString(json, 'idempotency_key'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'conversation_id': conversationId,
    'room_event': roomTurn.toJson(),
    'idempotency_key': idempotencyKey,
  };
}

enum BridgeSendTurnStatus {
  completed('completed'),
  busy('busy'),
  failed('failed'),
  cancelled('cancelled'),
  interrupted('interrupted'),
  idempotencyConflict('idempotency_conflict');

  const BridgeSendTurnStatus(this.wireValue);

  final String wireValue;
}

final class BridgeSendTurnResult {
  const BridgeSendTurnResult({
    required this.status,
    required this.roomEventId,
    required this.conversationId,
    required this.deduplicated,
    this.nativeUserMessageId,
    this.nativeAssistantMessageId,
    this.generationRunId,
    this.assistantContent,
    this.errorCode,
  });

  final BridgeSendTurnStatus status;
  final String roomEventId;
  final String conversationId;
  final String? nativeUserMessageId;
  final String? nativeAssistantMessageId;
  final String? generationRunId;
  final String? assistantContent;
  final bool deduplicated;
  final String? errorCode;

  Map<String, Object?> toJson() => <String, Object?>{
    'status': status.wireValue,
    'room_event_id': roomEventId,
    'conversation_id': conversationId,
    'native_user_message_id': nativeUserMessageId,
    'native_assistant_message_id': nativeAssistantMessageId,
    'generation_run_id': generationRunId,
    if (status == BridgeSendTurnStatus.completed)
      'assistant_content': assistantContent,
    'deduplicated': deduplicated,
    if (errorCode != null) 'error_code': errorCode,
  };
}

final class BridgeHealth {
  const BridgeHealth({required this.ready, required this.protocolVersion});

  final bool ready;
  final String protocolVersion;

  Map<String, Object?> toJson() => <String, Object?>{
    'ready': ready,
    'protocol_version': protocolVersion,
  };
}

final class BridgeSession {
  const BridgeSession({
    required this.conversationId,
    required this.active,
    required this.persisted,
    required this.assistantId,
    required this.branchRevision,
  });

  final String conversationId;
  final bool active;
  final bool persisted;
  final String? assistantId;
  final Map<String, int> branchRevision;

  Map<String, Object?> toJson() => <String, Object?>{
    'conversation_id': conversationId,
    'active': active,
    'persisted': persisted,
    'assistant_id': assistantId,
    'branch_revision': branchRevision,
  };
}

final class BridgeMessagePage {
  const BridgeMessagePage({required this.messages, required this.nextAfter});

  final List<ChatMessage> messages;
  final String? nextAfter;
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('invalid_$key');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('invalid_$key');
  }
  return value;
}
