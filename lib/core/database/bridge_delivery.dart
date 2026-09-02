import 'generation_run.dart';

/// Immutable provenance and idempotency claim for one external room turn.
final class BridgeDeliveryClaim {
  const BridgeDeliveryClaim({
    required this.originSystem,
    required this.originInstanceId,
    required this.idempotencyKey,
    required this.requestFingerprint,
    required this.roomEventId,
    required this.roomId,
  });

  final String originSystem;
  final String originInstanceId;
  final String idempotencyKey;
  final String requestFingerprint;
  final String roomEventId;
  final String roomId;
}

/// Durable mapping from an external delivery to Kelivo's native turn rows.
final class BridgeDelivery {
  const BridgeDelivery({
    required this.originSystem,
    required this.originInstanceId,
    required this.idempotencyKey,
    required this.requestFingerprint,
    required this.roomEventId,
    required this.roomId,
    required this.conversationId,
    required this.userRevisionId,
    required this.assistantRevisionId,
    required this.generationRunId,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
  });

  final String originSystem;
  final String originInstanceId;
  final String idempotencyKey;
  final String requestFingerprint;
  final String roomEventId;
  final String roomId;
  final String conversationId;
  final String userRevisionId;
  final String assistantRevisionId;
  final String generationRunId;
  final GenerationRunState state;
  final DateTime createdAt;
  final DateTime updatedAt;
}

enum BridgeGenerationBeginDisposition { created, duplicate, conflict }
