import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'message_attachment.dart';

part 'unified_message.g.dart';

/// Role of a message sender.
@HiveType(typeId: 53)
class MessageRole {
  @HiveField(0)
  final String value;

  const MessageRole._(this.value);

  static const user = MessageRole._('user');
  static const assistant = MessageRole._('assistant');
  static const system = MessageRole._('system');
  static const tool = MessageRole._('tool');

  static MessageRole fromJson(String value) {
    switch (value.toLowerCase()) {
      case 'user':
      case 'human':
        return MessageRole.user;
      case 'assistant':
      case 'model':
      case 'ai':
        return MessageRole.assistant;
      case 'system':
        return MessageRole.system;
      case 'tool':
        return MessageRole.tool;
      default:
        return MessageRole.user;
    }
  }

  String get jsonValue => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRole && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

@HiveType(typeId: 51)
class UnifiedMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? originalId;

  @HiveField(2)
  final String role; // 'user', 'assistant', 'system', 'tool'

  @HiveField(3)
  String content;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final List<MessageAttachment>? attachments;

  @HiveField(6)
  final Map<String, dynamic>? metadata;

  UnifiedMessage({
    String? id,
    this.originalId,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.attachments,
    this.metadata,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  MessageRole get messageRole => MessageRole.fromJson(role);

  UnifiedMessage copyWith({
    String? id,
    String? originalId,
    String? role,
    String? content,
    DateTime? timestamp,
    List<MessageAttachment>? attachments,
    Map<String, dynamic>? metadata,
    bool clearAttachments = false,
    bool clearMetadata = false,
  }) {
    return UnifiedMessage(
      id: id ?? this.id,
      originalId: originalId ?? this.originalId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      attachments: clearAttachments ? null : (attachments ?? this.attachments),
      metadata: clearMetadata ? null : (metadata ?? this.metadata),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalId': originalId,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'attachments': attachments?.map((a) => a.toJson()).toList(),
      'metadata': metadata,
    };
  }

  factory UnifiedMessage.fromJson(Map<String, dynamic> json) {
    return UnifiedMessage(
      id: json['id'] as String? ?? const Uuid().v4(),
      originalId: json['originalId'] as String?,
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map(
            (a) => MessageAttachment.fromJson(a as Map<String, dynamic>),
          )
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => 'UnifiedMessage(role: $role, content: ${content.length} chars, ts: $timestamp)';
}
