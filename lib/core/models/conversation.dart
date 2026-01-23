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

  // Last scroll position in the conversation (-1.0 means no saved position)
  @HiveField(12)
  double scrollOffset;

  Conversation({
    String? id,
    required this.title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? messageIds,
    this.isPinned = false,
    List<String>? mcpServerIds,
    String? assistantId,
    int? truncateIndex,
    Map<String, int>? versionSelections,
    this.summary,
    int? lastSummarizedMessageCount,
    double? scrollOffset,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        messageIds = messageIds ?? [],
        mcpServerIds = mcpServerIds ?? [],
        assistantId = assistantId,
        truncateIndex = truncateIndex ?? -1,
        versionSelections = versionSelections ?? <String, int>{},
        lastSummarizedMessageCount = lastSummarizedMessageCount ?? 0,
        scrollOffset = scrollOffset ?? -1.0;

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
    bool clearSummary = false,
    double? scrollOffset,
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
      scrollOffset: scrollOffset ?? this.scrollOffset,
    );
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
      'scrollOffset': scrollOffset,
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
      mcpServerIds: (json['mcpServerIds'] as List?)?.cast<String>() ?? const <String>[],
      assistantId: json['assistantId'] as String?,
      truncateIndex: json['truncateIndex'] as int? ?? -1,
      versionSelections: (json['versionSelections'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? <String, int>{},
      summary: json['summary'] as String?,
      lastSummarizedMessageCount: json['lastSummarizedMessageCount'] as int? ?? 0,
      scrollOffset: (json['scrollOffset'] as num?)?.toDouble() ?? -1.0,
    );
  }
}
