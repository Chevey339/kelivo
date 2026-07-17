import 'package:uuid/uuid.dart';

class ChatMessage {
  final String id;

  final String role; // 'user' or 'assistant'

  final String content;

  final DateTime timestamp;

  final String? modelId;

  final String? providerId;

  final int? totalTokens;

  final String conversationId;

  final bool isStreaming;

  // Optional reasoning fields for assistant messages
  final String? reasoningText;

  final DateTime? reasoningStartAt;

  final DateTime? reasoningFinishedAt;

  // Translation field for translated content
  final String? translation;

  // JSON encoded reasoning segments for multiple reasoning blocks
  final String? reasoningSegmentsJson;

  // Versioning: group messages sharing the same semantic position
  // groupId identifies a message thread; version starts from 0 and increments
  final String? groupId;

  // Multi-AI comparison: different subgroupId within same groupId → cards
  final String? subgroupId;

  final int version;

  final int? promptTokens;

  final int? completionTokens;

  final int? cachedTokens;

  final int? durationMs;

  factory ChatMessage({
    String? id,
    required String role,
    required String content,
    DateTime? timestamp,
    String? modelId,
    String? providerId,
    int? totalTokens,
    required String conversationId,
    bool isStreaming = false,
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
    String? translation,
    String? reasoningSegmentsJson,
    String? groupId,
    String? subgroupId,
    int? version,
    int? promptTokens,
    int? completionTokens,
    int? cachedTokens,
    int? durationMs,
  }) {
    final resolvedId = id ?? const Uuid().v4();
    return ChatMessage._(
      id: resolvedId,
      role: role,
      content: content,
      timestamp: timestamp ?? DateTime.now(),
      modelId: modelId,
      providerId: providerId,
      totalTokens: totalTokens,
      conversationId: conversationId,
      isStreaming: isStreaming,
      reasoningText: reasoningText,
      reasoningStartAt: reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt,
      translation: translation,
      reasoningSegmentsJson: reasoningSegmentsJson,
      groupId: groupId ?? resolvedId,
      subgroupId: subgroupId,
      version: version ?? 0,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      cachedTokens: cachedTokens,
      durationMs: durationMs,
    );
  }

  ChatMessage._({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.modelId,
    this.providerId,
    this.totalTokens,
    required this.conversationId,
    this.isStreaming = false,
    this.reasoningText,
    this.reasoningStartAt,
    this.reasoningFinishedAt,
    this.translation,
    this.reasoningSegmentsJson,
    this.groupId,
    this.subgroupId,
    required this.version,
    this.promptTokens,
    this.completionTokens,
    this.cachedTokens,
    this.durationMs,
  });

  // Sentinel for copyWith — not passed vs explicitly null.
  static const sentinel = Object();

  ChatMessage copyWith({
    Object? id = sentinel,
    Object? role = sentinel,
    Object? content = sentinel,
    Object? timestamp = sentinel,
    Object? modelId = sentinel,
    Object? providerId = sentinel,
    Object? totalTokens = sentinel,
    Object? conversationId = sentinel,
    Object? isStreaming = sentinel,
    Object? reasoningText = sentinel,
    Object? reasoningStartAt = sentinel,
    Object? reasoningFinishedAt = sentinel,
    Object? translation = sentinel,
    Object? reasoningSegmentsJson = sentinel,
    Object? groupId = sentinel,
    Object? subgroupId = sentinel,
    Object? version = sentinel,
    Object? promptTokens = sentinel,
    Object? completionTokens = sentinel,
    Object? cachedTokens = sentinel,
    Object? durationMs = sentinel,
  }) {
    return ChatMessage(
      id: identical(id, sentinel) ? this.id : id as String,
      role: identical(role, sentinel) ? this.role : role as String,
      content: identical(content, sentinel) ? this.content : content as String,
      timestamp: identical(timestamp, sentinel)
          ? this.timestamp
          : timestamp as DateTime,
      modelId: identical(modelId, sentinel) ? this.modelId : modelId as String?,
      providerId: identical(providerId, sentinel)
          ? this.providerId
          : providerId as String?,
      totalTokens: identical(totalTokens, sentinel)
          ? this.totalTokens
          : totalTokens as int?,
      conversationId: identical(conversationId, sentinel)
          ? this.conversationId
          : conversationId as String,
      isStreaming: identical(isStreaming, sentinel)
          ? this.isStreaming
          : isStreaming as bool,
      reasoningText: identical(reasoningText, sentinel)
          ? this.reasoningText
          : reasoningText as String?,
      reasoningStartAt: identical(reasoningStartAt, sentinel)
          ? this.reasoningStartAt
          : reasoningStartAt as DateTime?,
      reasoningFinishedAt: identical(reasoningFinishedAt, sentinel)
          ? this.reasoningFinishedAt
          : reasoningFinishedAt as DateTime?,
      translation: identical(translation, sentinel)
          ? this.translation
          : translation as String?,
      reasoningSegmentsJson: identical(reasoningSegmentsJson, sentinel)
          ? this.reasoningSegmentsJson
          : reasoningSegmentsJson as String?,
      groupId: identical(groupId, sentinel) ? this.groupId : groupId as String?,
      subgroupId: identical(subgroupId, sentinel)
          ? this.subgroupId
          : subgroupId as String?,
      version: identical(version, sentinel) ? this.version : version as int,
      promptTokens: identical(promptTokens, sentinel)
          ? this.promptTokens
          : promptTokens as int?,
      completionTokens: identical(completionTokens, sentinel)
          ? this.completionTokens
          : completionTokens as int?,
      cachedTokens: identical(cachedTokens, sentinel)
          ? this.cachedTokens
          : cachedTokens as int?,
      durationMs: identical(durationMs, sentinel)
          ? this.durationMs
          : durationMs as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'modelId': modelId,
      'providerId': providerId,
      'totalTokens': totalTokens,
      'conversationId': conversationId,
      'isStreaming': isStreaming,
      'reasoningText': reasoningText,
      'reasoningStartAt': reasoningStartAt?.toIso8601String(),
      'reasoningFinishedAt': reasoningFinishedAt?.toIso8601String(),
      'translation': translation,
      'reasoningSegmentsJson': reasoningSegmentsJson,
      'groupId': groupId,
      'subgroupId': subgroupId,
      'version': version,
      'promptTokens': promptTokens,
      'completionTokens': completionTokens,
      'cachedTokens': cachedTokens,
      'durationMs': durationMs,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      modelId: json['modelId'] as String?,
      providerId: json['providerId'] as String?,
      totalTokens: json['totalTokens'] as int?,
      conversationId: json['conversationId'] as String,
      isStreaming: json['isStreaming'] as bool? ?? false,
      reasoningText: json['reasoningText'] as String?,
      reasoningStartAt: json['reasoningStartAt'] != null
          ? DateTime.parse(json['reasoningStartAt'] as String)
          : null,
      reasoningFinishedAt: json['reasoningFinishedAt'] != null
          ? DateTime.parse(json['reasoningFinishedAt'] as String)
          : null,
      translation: json['translation'] as String?,
      reasoningSegmentsJson: json['reasoningSegmentsJson'] as String?,
      groupId: json['groupId'] as String?,
      subgroupId: json['subgroupId'] as String?,
      version: (json['version'] as int?) ?? 0,
      promptTokens: json['promptTokens'] as int?,
      completionTokens: json['completionTokens'] as int?,
      cachedTokens: json['cachedTokens'] as int?,
      durationMs: json['durationMs'] as int?,
    );
  }
}
