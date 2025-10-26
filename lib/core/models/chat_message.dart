import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:kelivo/core/models/token_usage.dart';

part 'chat_message.g.dart';

@HiveType(typeId: 0)
class ChatMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String role; // 'user' or 'assistant'

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final String? modelId;

  @HiveField(5)
  final String? providerId;

  @HiveField(6)
  final int? totalTokens;
  
  // Detailed token usage information (stored as JSON string)
  @HiveField(16)
  final String? tokenUsageJson;

  @HiveField(7)
  final String conversationId;

  @HiveField(8)
  final bool isStreaming;

  // Optional reasoning fields for assistant messages
  @HiveField(9)
  final String? reasoningText;

  @HiveField(10)
  final DateTime? reasoningStartAt;

  @HiveField(11)
  final DateTime? reasoningFinishedAt;

  // Translation field for translated content
  @HiveField(12)
  final String? translation;
  
  // JSON encoded reasoning segments for multiple reasoning blocks
  @HiveField(13)
  final String? reasoningSegmentsJson;

  // Versioning: group messages sharing the same semantic position
  // groupId identifies a message thread; version starts from 0 and increments
  @HiveField(14)
  final String? groupId;

  @HiveField(15)
  final int version;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.modelId,
    this.providerId,
    this.totalTokens,
    this.tokenUsageJson,
    required this.conversationId,
    this.isStreaming = false,
    this.reasoningText,
    this.reasoningStartAt,
    this.reasoningFinishedAt,
    this.translation,
    this.reasoningSegmentsJson,
    String? groupId,
    int? version,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now(),
        groupId = groupId ?? id,
        version = version ?? 0;

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    String? modelId,
    String? providerId,
    int? totalTokens,
    String? tokenUsageJson,
    String? conversationId,
    bool? isStreaming,
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
    String? translation,
    String? reasoningSegmentsJson,
    String? groupId,
    int? version,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      modelId: modelId ?? this.modelId,
      providerId: providerId ?? this.providerId,
      totalTokens: totalTokens ?? this.totalTokens,
      tokenUsageJson: tokenUsageJson ?? this.tokenUsageJson,
      conversationId: conversationId ?? this.conversationId,
      isStreaming: isStreaming ?? this.isStreaming,
      reasoningText: reasoningText ?? this.reasoningText,
      reasoningStartAt: reasoningStartAt ?? this.reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt ?? this.reasoningFinishedAt,
      translation: translation ?? this.translation,
      reasoningSegmentsJson: reasoningSegmentsJson ?? this.reasoningSegmentsJson,
      groupId: groupId ?? this.groupId,
      version: version ?? this.version,
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
      'tokenUsageJson': tokenUsageJson,
      'conversationId': conversationId,
      'isStreaming': isStreaming,
      'reasoningText': reasoningText,
      'reasoningStartAt': reasoningStartAt?.toIso8601String(),
      'reasoningFinishedAt': reasoningFinishedAt?.toIso8601String(),
      'translation': translation,
      'reasoningSegmentsJson': reasoningSegmentsJson,
      'groupId': groupId,
      'version': version,
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
      tokenUsageJson: json['tokenUsageJson'] as String?,
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
      version: (json['version'] as int?) ?? 0,
    );
  }
  
  // Helper method to get TokenUsage from tokenUsageJson
  TokenUsage? get tokenUsage {
    if (tokenUsageJson == null || tokenUsageJson!.isEmpty) return null;
    try {
      final json = jsonDecode(tokenUsageJson!) as Map<String, dynamic>;
      return TokenUsage(
        promptTokens: json['promptTokens'] as int? ?? 0,
        completionTokens: json['completionTokens'] as int? ?? 0,
        cachedTokens: json['cachedTokens'] as int? ?? 0,
        totalTokens: json['totalTokens'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
