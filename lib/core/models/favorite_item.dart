import 'package:uuid/uuid.dart';

/// 收藏项模型
class FavoriteItem {
  final String id;
  final String title; // 话题标题
  final String question; // 提问内容
  final String answer; // 回复内容
  final DateTime createdAt;
  final String? conversationId; // 关联的对话ID
  final String? messageId; // 关联的消息ID
  final String? providerId; // 供应商ID
  final String? modelId; // 模型ID
  final String? assistantId; // 助手ID
  final String? assistantName; // 助手名称
  final String? assistantAvatar; // 助手头像

  FavoriteItem({
    String? id,
    required this.title,
    required this.question,
    required this.answer,
    DateTime? createdAt,
    this.conversationId,
    this.messageId,
    this.providerId,
    this.modelId,
    this.assistantId,
    this.assistantName,
    this.assistantAvatar,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  FavoriteItem copyWith({
    String? id,
    String? title,
    String? question,
    String? answer,
    DateTime? createdAt,
    String? conversationId,
    String? messageId,
    String? providerId,
    String? modelId,
    String? assistantId,
    String? assistantName,
    String? assistantAvatar,
  }) {
    return FavoriteItem(
      id: id ?? this.id,
      title: title ?? this.title,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      createdAt: createdAt ?? this.createdAt,
      conversationId: conversationId ?? this.conversationId,
      messageId: messageId ?? this.messageId,
      providerId: providerId ?? this.providerId,
      modelId: modelId ?? this.modelId,
      assistantId: assistantId ?? this.assistantId,
      assistantName: assistantName ?? this.assistantName,
      assistantAvatar: assistantAvatar ?? this.assistantAvatar,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'question': question,
      'answer': answer,
      'createdAt': createdAt.toIso8601String(),
      'conversationId': conversationId,
      'messageId': messageId,
      'providerId': providerId,
      'modelId': modelId,
      'assistantId': assistantId,
      'assistantName': assistantName,
      'assistantAvatar': assistantAvatar,
    };
  }

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      id: json['id'] as String,
      title: json['title'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      conversationId: json['conversationId'] as String?,
      messageId: json['messageId'] as String?,
      providerId: json['providerId'] as String?,
      modelId: json['modelId'] as String?,
      assistantId: json['assistantId'] as String?,
      assistantName: json['assistantName'] as String?,
      assistantAvatar: json['assistantAvatar'] as String?,
    );
  }
}
