import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'conversation.g.dart';

@HiveType(typeId: 1)
class Conversation extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  DateTime updatedAt;

  @HiveField(4)
  final List<String> messageIds;

  @HiveField(5)
  bool isPinned;

  // Per-conversation enabled MCP servers (by server id)
  @HiveField(6)
  List<String> mcpServerIds;

  // Owner assistant id; null for global/default
  @HiveField(7)
  String? assistantId;

  // Truncate context starting at this index (-1 means no truncation)
  @HiveField(8)
  int truncateIndex;

  // Selected version per message group (groupId -> selected version index)
  @HiveField(9)
  Map<String, int> versionSelections;

  // LLM-generated conversation summary
  @HiveField(10)
  String? summary;

  // Message count when summary was last generated (to avoid redundant updates)
  @HiveField(11)
  int lastSummarizedMessageCount;

  // LLM-generated quick follow-up suggestions for the latest assistant reply.
  @HiveField(12)
  List<String> chatSuggestions;

  // Hash of the last injected memory block; null means never injected.
  @HiveField(13)
  String? injectedMemoryHash;

  // Highest message_order processed by background memory extraction; -1 = never.
  @HiveField(14)
  int lastMemoryExtractedOrder;

  // Per-conversation model override. null means inherit: the assistant's model
  // first, then the global default. Both are set or both are null.
  //
  // NOTE: conversation.g.dart is intentionally stale (it stops at field 12) and
  // must not be regenerated. The adapter is only read by the legacy
  // Hive-to-SQLite migration, whose source data predates these fields.
  @HiveField(15)
  String? chatModelProvider;

  @HiveField(16)
  String? chatModelId;

  // Context "floor": the 0-based message index at which context reading starts.
  // The generation prompt sends messages from here onward and drops everything
  // above, so the prompt prefix stays byte-stable and keeps hitting the
  // provider prompt cache as the conversation grows. -1 = disabled.
  //
  // NOTE: conversation.g.dart is intentionally stale (stops at field 12) and
  // must not be regenerated; like fields 13-16 this one lives in the SQLite
  // payload and Hive keeps its own copy indifferent to it.
  @HiveField(17)
  int contextFloor;

  Conversation({
    String? id,
    required this.title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? messageIds,
    this.isPinned = false,
    List<String>? mcpServerIds,
    this.assistantId,
    int? truncateIndex,
    Map<String, int>? versionSelections,
    this.summary,
    int? lastSummarizedMessageCount,
    List<String>? chatSuggestions,
    this.injectedMemoryHash,
    int? lastMemoryExtractedOrder,
    this.chatModelProvider,
    this.chatModelId,
    int? contextFloor,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       messageIds = messageIds ?? [],
       mcpServerIds = mcpServerIds ?? [],
       truncateIndex = truncateIndex ?? -1,
       versionSelections = versionSelections ?? <String, int>{},
       lastSummarizedMessageCount = lastSummarizedMessageCount ?? 0,
       chatSuggestions = chatSuggestions ?? [],
       lastMemoryExtractedOrder = lastMemoryExtractedOrder ?? -1,
       contextFloor = contextFloor ?? -1;

  Conversation copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? messageIds,
    bool? isPinned,
    List<String>? mcpServerIds,
    String? assistantId,
    int? truncateIndex,
    Map<String, int>? versionSelections,
    String? summary,
    int? lastSummarizedMessageCount,
    List<String>? chatSuggestions,
    String? injectedMemoryHash,
    int? lastMemoryExtractedOrder,
    String? chatModelProvider,
    String? chatModelId,
    int? contextFloor,
    bool clearSummary = false,
    bool clearInjectedMemoryHash = false,
    bool clearChatModel = false,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messageIds: messageIds ?? this.messageIds,
      isPinned: isPinned ?? this.isPinned,
      mcpServerIds: mcpServerIds ?? this.mcpServerIds,
      assistantId: assistantId ?? this.assistantId,
      truncateIndex: truncateIndex ?? this.truncateIndex,
      versionSelections: versionSelections ?? this.versionSelections,
      summary: clearSummary ? null : (summary ?? this.summary),
      lastSummarizedMessageCount:
          lastSummarizedMessageCount ?? this.lastSummarizedMessageCount,
      chatSuggestions: chatSuggestions ?? this.chatSuggestions,
      injectedMemoryHash: clearInjectedMemoryHash
          ? null
          : (injectedMemoryHash ?? this.injectedMemoryHash),
      lastMemoryExtractedOrder:
          lastMemoryExtractedOrder ?? this.lastMemoryExtractedOrder,
      chatModelProvider: clearChatModel
          ? null
          : (chatModelProvider ?? this.chatModelProvider),
      chatModelId: clearChatModel ? null : (chatModelId ?? this.chatModelId),
      contextFloor: contextFloor ?? this.contextFloor,
    );
  }

  /// Effective 0-based index at which context reading starts: the stricter of
  /// [truncateIndex] (清空上下文) and [contextFloor] (楼层), both of which mean
  /// "skip the first N messages". Returns -1 when neither is set.
  int get contextStartIndex {
    final t = truncateIndex >= 0 ? truncateIndex : -1;
    final f = contextFloor >= 0 ? contextFloor : -1;
    if (t >= 0 && f >= 0) return t > f ? t : f;
    return t >= 0 ? t : f;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'messageIds': messageIds,
      'isPinned': isPinned,
      'mcpServerIds': mcpServerIds,
      'assistantId': assistantId,
      'truncateIndex': truncateIndex,
      'versionSelections': versionSelections,
      'summary': summary,
      'lastSummarizedMessageCount': lastSummarizedMessageCount,
      'chatSuggestions': chatSuggestions,
      'injectedMemoryHash': injectedMemoryHash,
      'lastMemoryExtractedOrder': lastMemoryExtractedOrder,
      'chatModelProvider': chatModelProvider,
      'chatModelId': chatModelId,
      'contextFloor': contextFloor,
    };
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      messageIds: (json['messageIds'] as List<dynamic>).cast<String>(),
      isPinned: json['isPinned'] as bool? ?? false,
      mcpServerIds:
          (json['mcpServerIds'] as List?)?.cast<String>() ?? const <String>[],
      assistantId: json['assistantId'] as String?,
      truncateIndex: json['truncateIndex'] as int? ?? -1,
      versionSelections:
          (json['versionSelections'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          ) ??
          <String, int>{},
      summary: json['summary'] as String?,
      lastSummarizedMessageCount:
          json['lastSummarizedMessageCount'] as int? ?? 0,
      chatSuggestions:
          (json['chatSuggestions'] as List?)?.cast<String>() ??
          const <String>[],
      injectedMemoryHash: json['injectedMemoryHash'] as String?,
      lastMemoryExtractedOrder: json['lastMemoryExtractedOrder'] as int? ?? -1,
      chatModelProvider: json['chatModelProvider'] as String?,
      chatModelId: json['chatModelId'] as String?,
      contextFloor: json['contextFloor'] as int? ?? -1,
    );
  }
}
