import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'message_part.dart';

part 'chat_message.g.dart';

@HiveType(typeId: 0)
class ChatMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String role; // 'user' or 'assistant'

  /// Structured parts — single source of truth for body text and attachments.
  ///
  /// Hive field 2 (legacy content string) is intentionally not a stored field
  /// here. [ChatMessageAdapter] still reads field 2 for migration only;
  /// [content] is derived from [TextPart]s.
  final List<MessagePart> parts;

  /// Derived text body: concatenation of every [TextPart] in [parts] order.
  String get content =>
      parts.whereType<TextPart>().map((part) => part.text).join();

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final String? modelId;

  @HiveField(5)
  final String? providerId;

  @HiveField(6)
  final int? totalTokens;

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

  @HiveField(16)
  final int? promptTokens;

  @HiveField(17)
  final int? completionTokens;

  @HiveField(18)
  final int? cachedTokens;

  @HiveField(19)
  final int? durationMs;

  ChatMessage({
    String? id,
    required this.role,
    String? content,
    List<MessagePart>? parts,
    DateTime? timestamp,
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
    String? groupId,
    int? version,
    this.promptTokens,
    this.completionTokens,
    this.cachedTokens,
    this.durationMs,
  }) : parts = List<MessagePart>.unmodifiable(
         parts ?? <MessagePart>[TextPart(content ?? '')],
       ),
       id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now(),
       groupId = groupId ?? id,
       version = version ?? 0;

  /// Content-only rewrite that preserves part ordinal.
  ///
  /// Walks [original] in order: emits [TextPart] with [newContent] at the first
  /// TextPart position, skips later TextParts, and keeps Image/File/ToolCall/
  /// Reasoning/Unknown/Malformed parts in place. If there is no TextPart,
  /// prepends one.
  static List<MessagePart> partsWithReplacedText(
    List<MessagePart> original,
    String newContent,
  ) {
    final next = <MessagePart>[];
    var replaced = false;
    for (final part in original) {
      if (part is TextPart) {
        if (!replaced) {
          next.add(TextPart(newContent));
          replaced = true;
        }
        continue;
      }
      next.add(part);
    }
    if (!replaced) {
      next.insert(0, TextPart(newContent));
    }
    return next;
  }

  /// Content-only rewrite that keeps each [TextPart] slot.
  ///
  /// Earlier text parts keep their original lengths as split points; the last
  /// [TextPart] receives the remainder so interleaved tool / image / reasoning
  /// cards stay in place.
  static List<MessagePart> partsWithRedistributedText(
    List<MessagePart> original,
    String newContent,
  ) {
    final lengths = [
      for (final part in original)
        if (part is TextPart) part.text.length,
    ];
    if (lengths.length <= 1) {
      return partsWithReplacedText(original, newContent);
    }
    final next = <MessagePart>[];
    var offset = 0;
    var textIndex = 0;
    for (final part in original) {
      if (part is! TextPart) {
        next.add(part);
        continue;
      }
      final remaining = newContent.length - offset;
      final isLast = textIndex == lengths.length - 1;
      final take = isLast
          ? remaining
          : (lengths[textIndex] < remaining ? lengths[textIndex] : remaining);
      final end = offset + (take < 0 ? 0 : take);
      next.add(
        TextPart(
          offset >= newContent.length ? '' : newContent.substring(offset, end),
        ),
      );
      offset = end;
      textIndex++;
    }
    return next;
  }

  /// Rewrite each [TextPart] in place. Non-text parts keep their ordinal.
  static List<MessagePart> partsWithRewrittenText(
    List<MessagePart> original,
    String Function(String text) rewrite,
  ) {
    var changed = false;
    final next = <MessagePart>[];
    for (final part in original) {
      if (part is! TextPart) {
        next.add(part);
        continue;
      }
      final rewritten = rewrite(part.text);
      if (rewritten != part.text) changed = true;
      next.add(rewritten == part.text ? part : TextPart(rewritten));
    }
    return changed ? next : original;
  }

  /// Replace reasoning with a single scalar value.
  ///
  /// The first [ReasoningPart] is rewritten (or prepended when none exists);
  /// any later reasoning parts are removed so a later join equals [reasoningText].
  /// An empty string removes every [ReasoningPart].
  static List<MessagePart> partsWithReplacedReasoning(
    List<MessagePart> original,
    String reasoningText,
  ) {
    if (reasoningText.isEmpty) {
      return [
        for (final part in original)
          if (part is! ReasoningPart) part,
      ];
    }
    if (!original.any((part) => part is ReasoningPart)) {
      return [ReasoningPart(reasoningText), ...original];
    }
    var replaced = false;
    final next = <MessagePart>[];
    for (final part in original) {
      if (part is! ReasoningPart) {
        next.add(part);
        continue;
      }
      if (replaced) continue;
      next.add(ReasoningPart(reasoningText));
      replaced = true;
    }
    return next;
  }

  /// Body-only assistant edit: drop thinking and tool cards, keep attachments.
  ///
  /// Writes [newContent] into the first [TextPart] (or prepends one). Image,
  /// file, and unknown parts stay in place so generated media is not lost.
  static List<MessagePart> partsWithoutThinkingAndToolCards(
    List<MessagePart> original,
    String newContent,
  ) {
    return partsWithReplacedText([
      for (final part in original)
        if (part is! ReasoningPart && part is! ToolCallPart) part,
    ], newContent);
  }

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    List<MessagePart>? parts,
    DateTime? timestamp,
    String? modelId,
    String? providerId,
    int? totalTokens,
    String? conversationId,
    bool? isStreaming,
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
    String? translation,
    String? reasoningSegmentsJson,
    String? groupId,
    int? version,
    int? promptTokens,
    int? completionTokens,
    int? cachedTokens,
    int? durationMs,
  }) {
    final List<MessagePart>? nextParts;
    if (parts != null) {
      nextParts = parts;
    } else if (content != null) {
      nextParts = partsWithRedistributedText(this.parts, content);
    } else {
      nextParts = this.parts;
    }
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      parts: nextParts,
      timestamp: timestamp ?? this.timestamp,
      modelId: modelId ?? this.modelId,
      providerId: providerId ?? this.providerId,
      totalTokens: totalTokens ?? this.totalTokens,
      conversationId: conversationId ?? this.conversationId,
      isStreaming: isStreaming ?? this.isStreaming,
      reasoningText: reasoningText ?? this.reasoningText,
      reasoningStartAt: reasoningStartAt ?? this.reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt ?? this.reasoningFinishedAt,
      translation: translation ?? this.translation,
      reasoningSegmentsJson:
          reasoningSegmentsJson ?? this.reasoningSegmentsJson,
      groupId: groupId ?? this.groupId,
      version: version ?? this.version,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      cachedTokens: cachedTokens ?? this.cachedTokens,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      // Derived text for older readers; structured attachments live in [parts].
      'content': content,
      'parts': [
        for (final part in parts)
          {'kind': part.kind, 'payload': part.encodePayload()},
      ],
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
      'version': version,
      'promptTokens': promptTokens,
      'completionTokens': completionTokens,
      'cachedTokens': cachedTokens,
      'durationMs': durationMs,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawParts = json['parts'];
    List<MessagePart>? parts;
    if (rawParts is List) {
      parts = <MessagePart>[];
      for (var ordinal = 0; ordinal < rawParts.length; ordinal++) {
        final entry = rawParts[ordinal];
        if (entry is! Map) continue;
        final kind = (entry['kind'] ?? '').toString();
        final payload = (entry['payload'] ?? '').toString();
        try {
          parts.add(MessagePart.fromRow(kind, payload));
        } on FormatException catch (error) {
          final parseError = messagePartParseErrorCategory(error);
          throw FormatException(
            'Invalid message part: messageId=${json['id']} '
            'ordinal=$ordinal kind=$kind parseError=$parseError',
          );
        }
      }
    }
    return ChatMessage(
      id: json['id'] as String,
      role: json['role'] as String,
      // Prefer structured parts when present. Legacy backups that only carry
      // marker-bearing [content] keep that string here; import boundaries run
      // decodeLegacyContent to promote markers into parts.
      content: parts == null ? json['content'] as String : null,
      parts: parts,
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
      version: (json['version'] as int?) ?? 0,
      promptTokens: json['promptTokens'] as int?,
      completionTokens: json['completionTokens'] as int?,
      cachedTokens: json['cachedTokens'] as int?,
      durationMs: json['durationMs'] as int?,
    );
  }
}
