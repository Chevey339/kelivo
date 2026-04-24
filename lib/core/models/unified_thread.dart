import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'unified_thread.g.dart';

/// Source chat application for a backed-up thread.
enum ChatSource {
  kelivo,
  chatgpt,
  gemini,
  perplexity,
  claude,
  other;

  String get displayName {
    // Localized display names come from AppLocalizations.
    // This is used for fallback / non-UI contexts.
    switch (this) {
      case ChatSource.kelivo:
        return 'Kelivo';
      case ChatSource.chatgpt:
        return 'ChatGPT';
      case ChatSource.gemini:
        return 'Gemini';
      case ChatSource.perplexity:
        return 'Perplexity';
      case ChatSource.claude:
        return 'Claude';
      case ChatSource.other:
        return 'Other';
    }
  }

  String get jsonValue => name;

  static ChatSource fromJson(String value) {
    return ChatSource.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ChatSource.other,
    );
  }
}

@HiveType(typeId: 50)
class UnifiedThread extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String source; // JSON value of ChatSource

  @HiveField(2)
  final String? originalId;

  @HiveField(3)
  String title;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  @HiveField(6)
  final List<UnifiedMessage> messages;

  @HiveField(7)
  final Map<String, dynamic>? metadata;

  UnifiedThread({
    String? id,
    required this.source,
    this.originalId,
    required this.title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<UnifiedMessage>? messages,
    this.metadata,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       messages = messages ?? [];

  ChatSource get chatSource => ChatSource.fromJson(source);

  bool get hasOriginalId => originalId != null && originalId!.isNotEmpty;

  /// Returns a dedup key: source + originalId (if available),
  /// or source + title (fallback).
  String get dedupKey {
    if (hasOriginalId) return '$source::$originalId';
    return '$source::${title.trim().toLowerCase()}';
  }

  UnifiedThread copyWith({
    String? id,
    String? source,
    String? originalId,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<UnifiedMessage>? messages,
    Map<String, dynamic>? metadata,
    bool clearMetadata = false,
  }) {
    return UnifiedThread(
      id: id ?? this.id,
      source: source ?? this.source,
      originalId: originalId ?? this.originalId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      metadata: clearMetadata ? null : (metadata ?? this.metadata),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source,
      'originalId': originalId,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'metadata': metadata,
    };
  }

  factory UnifiedThread.fromJson(Map<String, dynamic> json) {
    return UnifiedThread(
      id: json['id'] as String? ?? const Uuid().v4(),
      source: json['source'] as String? ?? 'other',
      originalId: json['originalId'] as String?,
      title: json['title'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      messages: (json['messages'] as List<dynamic>?)
              ?.map(
                (m) => UnifiedMessage.fromJson(m as Map<String, dynamic>),
              )
              .toList() ??
          [],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => 'UnifiedThread(id: $id, source: $source, title: $title, messages: ${messages.length})';
}
