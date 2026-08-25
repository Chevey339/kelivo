import 'dart:convert';

/// Structured message part — single source of truth for attachments and text.
///
/// Payload contract:
/// - `text` / `reasoning`: raw string
/// - `tool_call`: JSON string preserved as-is
/// - `image`: `{"uri","mime"?,"assetId"?,"unavailable"?}`
/// - `file`: `{"uri","name","mime"?,"assetId"?,"unavailable"?}`
/// - unknown kinds: stored in [UnknownPart] and written back unchanged
/// - malformed known kinds: created only while hydrating database rows and
///   stored in [MalformedPart] for lossless write-back
sealed class MessagePart {
  const MessagePart();

  factory MessagePart.fromRow(String kind, String payload) {
    switch (kind) {
      case 'text':
        return TextPart(payload);
      case 'reasoning':
        return ReasoningPart(payload);
      case 'tool_call':
        return ToolCallPart(payload);
      case 'image':
        return ImagePart.fromPayload(payload);
      case 'file':
        return FilePart.fromPayload(payload);
      default:
        return UnknownPart(rawKind: kind, payload: payload);
    }
  }

  String get kind;

  String encodePayload();
}

final class TextPart extends MessagePart {
  const TextPart(this.text);

  final String text;

  @override
  String get kind => 'text';

  @override
  String encodePayload() => text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TextPart && text == other.text;

  @override
  int get hashCode => text.hashCode;
}

final class ReasoningPart extends MessagePart {
  const ReasoningPart(this.text);

  final String text;

  @override
  String get kind => 'reasoning';

  @override
  String encodePayload() => text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ReasoningPart && text == other.text;

  @override
  int get hashCode => text.hashCode;
}

final class ToolCallPart extends MessagePart {
  const ToolCallPart(this.payloadJson);

  final String payloadJson;

  @override
  String get kind => 'tool_call';

  @override
  String encodePayload() => payloadJson;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolCallPart && payloadJson == other.payloadJson;

  @override
  int get hashCode => payloadJson.hashCode;
}

final class ImagePart extends MessagePart {
  const ImagePart({
    required this.uri,
    this.mime,
    this.assetId,
    this.id,
    this.unavailable = false,
  });

  factory ImagePart.fromPayload(String payload) {
    final map = _decodeObjectPayload(payload);
    final uri = map['uri'];
    if (uri is! String || uri.isEmpty) {
      throw const _MessagePartFormatException('missing_uri');
    }
    return ImagePart(
      uri: uri,
      mime: _optionalString(map, 'mime'),
      assetId: _optionalString(map, 'assetId'),
      unavailable: _optionalBool(map, 'unavailable'),
    );
  }

  final String uri;
  final String? mime;
  final String? assetId;

  /// Stream image id. Runtime-only — not written to [encodePayload].
  final String? id;
  final bool unavailable;

  @override
  String get kind => 'image';

  @override
  String encodePayload() => jsonEncode({
    'uri': uri,
    if (mime != null) 'mime': mime,
    if (assetId != null) 'assetId': assetId,
    if (unavailable) 'unavailable': true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImagePart &&
          uri == other.uri &&
          mime == other.mime &&
          assetId == other.assetId &&
          id == other.id &&
          unavailable == other.unavailable;

  @override
  int get hashCode => Object.hash(uri, mime, assetId, id, unavailable);
}

final class FilePart extends MessagePart {
  const FilePart({
    required this.uri,
    required this.name,
    this.mime,
    this.assetId,
    this.unavailable = false,
  });

  factory FilePart.fromPayload(String payload) {
    final map = _decodeObjectPayload(payload);
    final uri = map['uri'];
    final name = map['name'];
    if (uri is! String || uri.isEmpty) {
      throw const _MessagePartFormatException('missing_uri');
    }
    if (name is! String || name.isEmpty) {
      throw const _MessagePartFormatException('missing_name');
    }
    return FilePart(
      uri: uri,
      name: name,
      mime: _optionalString(map, 'mime'),
      assetId: _optionalString(map, 'assetId'),
      unavailable: _optionalBool(map, 'unavailable'),
    );
  }

  final String uri;
  final String name;
  final String? mime;
  final String? assetId;
  final bool unavailable;

  @override
  String get kind => 'file';

  @override
  String encodePayload() => jsonEncode({
    'uri': uri,
    'name': name,
    if (mime != null) 'mime': mime,
    if (assetId != null) 'assetId': assetId,
    if (unavailable) 'unavailable': true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilePart &&
          uri == other.uri &&
          name == other.name &&
          mime == other.mime &&
          assetId == other.assetId &&
          unavailable == other.unavailable;

  @override
  int get hashCode => Object.hash(uri, name, mime, assetId, unavailable);
}

/// Forward-compatible carrier for kinds this build does not understand.
final class UnknownPart extends MessagePart {
  const UnknownPart({required this.rawKind, required this.payload});

  final String rawKind;
  final String payload;

  @override
  String get kind => rawKind;

  @override
  String encodePayload() => payload;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnknownPart &&
          rawKind == other.rawKind &&
          payload == other.payload;

  @override
  int get hashCode => Object.hash(rawKind, payload);
}

/// A known part kind whose persisted payload cannot be parsed.
///
/// Unlike [UnknownPart], an attachment-shaped malformed part may still own an
/// asset reference. Database hydration uses this carrier to isolate corrupt
/// rows while preserving their exact payload for a later repair or write-back.
final class MalformedPart extends MessagePart {
  const MalformedPart({
    required this.rawKind,
    required this.rawPayload,
    required this.parseError,
  });

  final String rawKind;
  final String rawPayload;
  final String parseError;

  bool get isAttachmentKind => rawKind == 'image' || rawKind == 'file';

  @override
  String get kind => rawKind;

  @override
  String encodePayload() => rawPayload;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MalformedPart &&
          rawKind == other.rawKind &&
          rawPayload == other.rawPayload &&
          parseError == other.parseError;

  @override
  int get hashCode => Object.hash(rawKind, rawPayload, parseError);
}

String messagePartParseErrorCategory(FormatException error) {
  return error is _MessagePartFormatException
      ? error.category
      : 'invalid_payload';
}

final class _MessagePartFormatException extends FormatException {
  const _MessagePartFormatException(this.category) : super(category);

  final String category;
}

Map<String, dynamic> _decodeObjectPayload(String payload) {
  late final Object? decoded;
  try {
    decoded = jsonDecode(payload);
  } on FormatException {
    throw const _MessagePartFormatException('invalid_json');
  }
  if (decoded is! Map) {
    throw const _MessagePartFormatException('not_object');
  }
  return Map<String, dynamic>.from(decoded);
}

String? _optionalString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) {
    final category = switch (key) {
      'mime' => 'invalid_mime',
      'assetId' => 'invalid_asset_id',
      _ => 'invalid_optional_string',
    };
    throw _MessagePartFormatException(category);
  }
  return value;
}

bool _optionalBool(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return false;
  if (value is! bool) {
    throw const _MessagePartFormatException('invalid_unavailable');
  }
  return value;
}

/// Whether persisted split triples can drive the historical interleaving
/// renderer.
///
/// Empty arrays, length mismatches, negative values, and count regressions
/// are not usable. Those messages must keep [MessagePart] arrival order.
bool contentSplitsAreUsable(
  List<int>? offsets,
  List<int>? reasoningCounts,
  List<int>? toolCounts,
) {
  if (offsets == null || reasoningCounts == null || toolCounts == null) {
    return false;
  }
  if (offsets.isEmpty ||
      offsets.length != reasoningCounts.length ||
      offsets.length != toolCounts.length) {
    return false;
  }

  var previousOffset = 0;
  var previousReasoning = 0;
  var previousTool = 0;
  for (var i = 0; i < offsets.length; i++) {
    final offset = offsets[i];
    final reasoning = reasoningCounts[i];
    final tool = toolCounts[i];
    if (offset < 0 || reasoning < 0 || tool < 0) {
      return false;
    }
    if (i > 0 &&
        (offset < previousOffset ||
            reasoning < previousReasoning ||
            tool < previousTool)) {
      return false;
    }
    previousOffset = offset;
    previousReasoning = reasoning;
    previousTool = tool;
  }
  return true;
}

/// Parse persisted split triples only when they pass [contentSplitsAreUsable].
///
/// Length mismatches are rejected instead of being truncated down to the
/// shortest array, so a broken payload cannot be repaired into a "valid"
/// interleaving.
({List<int> offsets, List<int> reasoningCounts, List<int> toolCounts})?
tryParseContentSplits(dynamic raw) {
  if (raw is! Map) return null;
  final json = raw is Map<String, dynamic> ? raw : raw.cast<String, dynamic>();
  final offsets = _tryContentSplitIntList(json['offsets']);
  final reasoningCounts = _tryContentSplitIntList(json['reasoningCounts']);
  final toolCounts = _tryContentSplitIntList(json['toolCounts']);
  if (!contentSplitsAreUsable(offsets, reasoningCounts, toolCounts)) {
    return null;
  }
  return (
    offsets: offsets!,
    reasoningCounts: reasoningCounts!,
    toolCounts: toolCounts!,
  );
}

List<int>? _tryContentSplitIntList(dynamic value) {
  if (value == null) return const <int>[];
  if (value is! List) return null;
  final out = <int>[];
  for (final item in value) {
    if (item is int) {
      out.add(item);
    } else if (item is num && item == item.roundToDouble()) {
      out.add(item.toInt());
    } else {
      return null;
    }
  }
  return out;
}

/// Whether structurally valid split triples actually cover the timeline.
///
/// Offsets must stay within [contentLength], each target count pair must
/// appear in order on the rendered steps, and the last target must consume
/// every step. Incomplete coverage would otherwise append leftover
/// reasoning/tool cards after the trailing body.
bool contentSplitsMatchTimeline({
  required List<int> offsets,
  required List<int> reasoningCounts,
  required List<int> toolCounts,
  required int contentLength,
  required List<int> stepReasoningCounts,
  required List<int> stepToolCounts,
}) {
  if (!contentSplitsAreUsable(offsets, reasoningCounts, toolCounts)) {
    return false;
  }
  if (stepReasoningCounts.length != stepToolCounts.length ||
      stepReasoningCounts.isEmpty) {
    return false;
  }

  var stepIndex = 0;
  for (var i = 0; i < offsets.length; i++) {
    if (offsets[i] > contentLength) return false;
    final targetReasoning = reasoningCounts[i];
    final targetTool = toolCounts[i];
    var found = false;
    while (stepIndex < stepReasoningCounts.length) {
      final reasoningAfter = stepReasoningCounts[stepIndex];
      final toolAfter = stepToolCounts[stepIndex];
      stepIndex++;
      if (reasoningAfter == targetReasoning && toolAfter == targetTool) {
        found = true;
        break;
      }
    }
    if (!found) return false;
  }
  return stepIndex == stepReasoningCounts.length;
}

/// Whether the assistant bubble should walk [parts] instead of contentSplits.
///
/// Historical rows keep a flat `[reasoning, tools…, body]` layout plus
/// persisted split triples that reconstruct interleaving. Those stay on the
/// split renderer. New streams persist [ReasoningPart] / [ToolCallPart]
/// (and generated [ImagePart]s) in arrival order and have no splits.
bool renderAssistantFromParts({
  required List<MessagePart> parts,
  required bool hasContentSplits,
}) {
  if (hasContentSplits) return false;
  for (final part in parts) {
    if (part is ReasoningPart || part is ToolCallPart) return true;
  }
  return parts.any((part) => part is ImagePart);
}
