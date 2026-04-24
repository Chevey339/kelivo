import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'message_attachment.g.dart';

/// An attachment associated with a unified message.
/// Can represent images, files, code blocks, citations, tool calls, or tool results.
@HiveType(typeId: 52)
class MessageAttachment extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String type; // 'image', 'file', 'code', 'citation', 'tool_call', 'tool_result'

  @HiveField(2)
  final String? url;

  @HiveField(3)
  final String? name;

  @HiveField(4)
  final String? mimeType;

  @HiveField(5)
  final String? content; // inline content (base64 for images, raw text for code)

  MessageAttachment({
    String? id,
    required this.type,
    this.url,
    this.name,
    this.mimeType,
    this.content,
  }) : id = id ?? const Uuid().v4();

  MessageAttachment copyWith({
    String? id,
    String? type,
    String? url,
    String? name,
    String? mimeType,
    String? content,
  }) {
    return MessageAttachment(
      id: id ?? this.id,
      type: type ?? this.type,
      url: url ?? this.url,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      content: content ?? this.content,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'url': url,
      'name': name,
      'mimeType': mimeType,
      'content': content,
    };
  }

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      id: json['id'] as String? ?? const Uuid().v4(),
      type: json['type'] as String? ?? 'file',
      url: json['url'] as String?,
      name: json['name'] as String?,
      mimeType: json['mimeType'] as String?,
      content: json['content'] as String?,
    );
  }

  @override
  String toString() => 'MessageAttachment(type: $type, name: $name)';
}
