import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:Kelivo/core/models/conversation.dart';
import '../kelivo_database.dart';

Conversation conversationFromRow(ConversationRow row) {
  return Conversation(
    id: row.id,
    title: row.title,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    messageIds: (jsonDecode(row.messageIds) as List).cast<String>(),
    isPinned: row.isPinned,
    mcpServerIds: (jsonDecode(row.mcpServerIds) as List).cast<String>(),
    assistantId: row.assistantId,
    truncateIndex: row.truncateIndex,
    versionSelections: (jsonDecode(row.versionSelections) as Map).map(
      (k, v) => MapEntry(k.toString(), (v as num).toInt()),
    ),
    summary: row.summary,
    lastSummarizedMessageCount: row.lastSummarizedMessageCount,
    chatSuggestions: (jsonDecode(row.chatSuggestions) as List).cast<String>(),
  );
}

ConversationsCompanion conversationToCompanion(Conversation c) {
  return ConversationsCompanion(
    id: Value(c.id),
    title: Value(c.title),
    createdAt: Value(c.createdAt.millisecondsSinceEpoch),
    updatedAt: Value(c.updatedAt.millisecondsSinceEpoch),
    messageIds: Value(jsonEncode(c.messageIds)),
    isPinned: Value(c.isPinned),
    mcpServerIds: Value(jsonEncode(c.mcpServerIds)),
    assistantId: Value(c.assistantId),
    truncateIndex: Value(c.truncateIndex),
    versionSelections: Value(jsonEncode(c.versionSelections)),
    summary: Value(c.summary),
    lastSummarizedMessageCount: Value(c.lastSummarizedMessageCount),
    chatSuggestions: Value(jsonEncode(c.chatSuggestions)),
  );
}
