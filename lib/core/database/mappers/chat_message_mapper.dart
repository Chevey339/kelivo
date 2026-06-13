import 'package:drift/drift.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import '../kelivo_database.dart';

ChatMessage chatMessageFromRow(MessageRow row) {
  return ChatMessage(
    id: row.id,
    role: row.role,
    content: row.content,
    timestamp: DateTime.fromMillisecondsSinceEpoch(row.timestamp),
    modelId: row.modelId,
    providerId: row.providerId,
    totalTokens: row.totalTokens,
    conversationId: row.conversationId,
    isStreaming: row.isStreaming,
    reasoningText: row.reasoningText,
    reasoningStartAt: row.reasoningStartAt != null
        ? DateTime.fromMillisecondsSinceEpoch(row.reasoningStartAt!)
        : null,
    reasoningFinishedAt: row.reasoningFinishedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(row.reasoningFinishedAt!)
        : null,
    translation: row.translation,
    reasoningSegmentsJson: row.reasoningSegmentsJson,
    groupId: row.groupId,
    version: row.version,
    promptTokens: row.promptTokens,
    completionTokens: row.completionTokens,
    cachedTokens: row.cachedTokens,
    durationMs: row.durationMs,
  );
}

MessagesCompanion chatMessageToCompanion(ChatMessage msg) {
  return MessagesCompanion(
    id: Value(msg.id),
    role: Value(msg.role),
    content: Value(msg.content),
    timestamp: Value(msg.timestamp.millisecondsSinceEpoch),
    modelId: Value(msg.modelId),
    providerId: Value(msg.providerId),
    totalTokens: Value(msg.totalTokens),
    conversationId: Value(msg.conversationId),
    isStreaming: Value(msg.isStreaming),
    reasoningText: Value(msg.reasoningText),
    reasoningStartAt: msg.reasoningStartAt != null
        ? Value(msg.reasoningStartAt!.millisecondsSinceEpoch)
        : const Value(null),
    reasoningFinishedAt: msg.reasoningFinishedAt != null
        ? Value(msg.reasoningFinishedAt!.millisecondsSinceEpoch)
        : const Value(null),
    translation: Value(msg.translation),
    reasoningSegmentsJson: Value(msg.reasoningSegmentsJson),
    groupId: Value(msg.groupId),
    version: Value(msg.version),
    promptTokens: Value(msg.promptTokens),
    completionTokens: Value(msg.completionTokens),
    cachedTokens: Value(msg.cachedTokens),
    durationMs: Value(msg.durationMs),
  );
}
