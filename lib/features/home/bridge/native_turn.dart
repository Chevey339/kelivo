import '../../../core/database/bridge_delivery.dart';
import '../../../core/database/generation_run.dart';
import '../../../core/models/chat_input_data.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';

enum NativeTurnStartStatus { accepted, busy, idempotencyConflict, rejected }

final class NativeTurnTerminalResult {
  const NativeTurnTerminalResult({
    required this.state,
    required this.userMessageId,
    required this.assistantMessageId,
    required this.generationRunId,
    required this.assistantMessage,
    this.errorCode,
  });

  final GenerationRunState state;
  final String userMessageId;
  final String assistantMessageId;
  final String generationRunId;
  final ChatMessage assistantMessage;
  final String? errorCode;
}

final class NativeTurnHandle {
  const NativeTurnHandle({
    required this.userMessageId,
    required this.assistantMessageId,
    required this.generationRunId,
    required this.deduplicated,
    required this.completion,
  });

  final String userMessageId;
  final String assistantMessageId;
  final String generationRunId;
  final bool deduplicated;
  final Future<NativeTurnTerminalResult> completion;
}

final class NativeTurnStartResult {
  const NativeTurnStartResult({
    required this.status,
    this.handle,
    this.errorCode,
  });

  final NativeTurnStartStatus status;
  final NativeTurnHandle? handle;
  final String? errorCode;
}

abstract interface class NativeTurnActions {
  Future<NativeTurnStartResult> sendExternalTurn({
    required ChatInputData input,
    required Conversation conversation,
    required BridgeDeliveryClaim deliveryClaim,
  });
}
