import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'room_turn.dart';

final class RoomTurnFormatter {
  const RoomTurnFormatter();

  static const envelopeMarker = 'ROOM_EVENT';

  String format(RoomTurn turn) =>
      '$envelopeMarker\n${jsonEncode(_envelope(turn))}';

  String fingerprint(BridgeSendTurnRequest request) {
    final canonical = <String, Object?>{
      'conversation_id': request.conversationId,
      'room_event': request.roomTurn.toJson(),
    };
    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }

  Map<String, Object?> _envelope(RoomTurn turn) => <String, Object?>{
    'room_id': turn.roomId,
    'room_event_id': turn.roomEventId,
    'sender': turn.sender.toJson(),
    'created_at': turn.createdAt.toUtc().toIso8601String(),
    'addressed_to_this_agent': turn.addressedToAgent,
    'reply_to_room_message_id': turn.replyToRoomMessageId,
    'trust_class': switch (turn.sender.kind) {
      RoomSenderKind.human => 'untrusted_human_content',
      RoomSenderKind.peerAgent => 'untrusted_peer_content',
    },
    'content': turn.content,
  };
}
