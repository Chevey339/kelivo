import 'dart:convert';

enum CarryMode { unset, off, count, all }

const carriedWireKey = '_kelivo_carried_wire';
const carriedArtifactKind = 'carried_wire';
const carriedTextOnlyArtifactKind = 'carried_text_only';
const carriedImageHandlesKey = '_kelivo_carried_image_handles';
const carriedTextOnlyKey = '_kelivo_carried_text_only';
const carriedPrefix = 'context-carried:';
const carriedReplyPrefix = 'context-carried-reply:';
bool isCarriedMessageId(String id) =>
    id.startsWith(carriedPrefix) || id.startsWith(carriedReplyPrefix);

String carriedSourceId(String id) {
  if (!id.startsWith(carriedPrefix)) return id;
  final separator = id.indexOf(':', carriedPrefix.length);
  return separator < 0 ? id : id.substring(separator + 1);
}

class CarrySetting {
  const CarrySetting({this.mode = CarryMode.unset, this.count = 3});
  final CarryMode mode;
  final int count;
  Map<String, dynamic> toJson() => {'mode': mode.name, 'count': count};
  factory CarrySetting.fromJson(Object? value) {
    if (value is! Map) return const CarrySetting();
    final count = value['count'] ?? 3;
    final mode = CarryMode.values
        .where((m) => m.name == value['mode'])
        .firstOrNull;
    if (count is! int || count < 1 || count > 10000 || mode == null) {
      throw const FormatException('Invalid compression settings');
    }
    return CarrySetting(mode: mode, count: count);
  }
}

class CarriedReply {
  const CarriedReply({
    required this.messageIds,
    required this.text,
    this.editedText,
    required this.estimatedTokens,
  });
  final List<String> messageIds;
  final String text;
  final String? editedText;
  final int estimatedTokens;
  String get effectiveText => editedText ?? text;
  CarriedReply copyWith({List<String>? messageIds, String? editedText}) =>
      CarriedReply(
        messageIds: messageIds ?? this.messageIds,
        text: text,
        editedText: editedText ?? this.editedText,
        estimatedTokens: estimatedTokens,
      );
  Map<String, dynamic> toJson() => {
    'messageIds': messageIds,
    'text': text,
    'editedText': editedText,
    'estimatedTokens': estimatedTokens,
  };
  factory CarriedReply.fromJson(Map json) => CarriedReply(
    messageIds: List<String>.from(json['messageIds'] as List),
    text: json['text'] as String,
    editedText: json['editedText'] as String?,
    estimatedTokens: json['estimatedTokens'] as int,
  );
}

class CarriedOriginal {
  const CarriedOriginal({
    required this.sourceMessageId,
    required this.sourceGroupId,
    required this.sourceVersion,
    required this.contentHash,
    required this.text,
    this.editedText,
    this.truncated = false,
    this.imageHandles = const [],
    this.wire,
    this.estimatedTokens = 0,
    this.fromOperationId,
    this.reply,
    this.hasAttachments = false,
    this.textWithoutAttachments,
    this.attachmentCount = 0,
    this.inheritedEdit = false,
  });
  final String sourceMessageId;
  final String sourceGroupId;
  final int sourceVersion;
  final String contentHash;
  final String text;
  final String? editedText;
  final bool truncated;
  final List<String> imageHandles;
  final Map<String, dynamic>? wire;
  final int estimatedTokens;
  final String? fromOperationId;
  final CarriedReply? reply;
  final bool hasAttachments;
  final String? textWithoutAttachments;
  final int attachmentCount;
  final bool inheritedEdit;
  String get effectiveText => editedText ?? text;
  bool get isEdited => editedText != null || inheritedEdit;

  Map<String, dynamic> get wireItem {
    if (wire == null) {
      return textWire('user', effectiveText, images: imageHandles);
    }
    if (editedText == null) return Map<String, dynamic>.from(wire!);
    return replaceWireText(wire!, effectiveText);
  }

  CarriedOriginal copyWith({
    String? sourceMessageId,
    String? sourceGroupId,
    String? contentHash,
    String? text,
    String? editedText,
    bool clearEdit = false,
    bool clearWire = false,
    bool? truncated,
    List<String>? imageHandles,
    Map<String, dynamic>? wire,
    int? estimatedTokens,
    String? fromOperationId,
    CarriedReply? reply,
    bool removeReply = false,
    bool? hasAttachments,
    String? textWithoutAttachments,
    int? attachmentCount,
    bool? inheritedEdit,
  }) => CarriedOriginal(
    sourceMessageId: sourceMessageId ?? this.sourceMessageId,
    sourceGroupId: sourceGroupId ?? this.sourceGroupId,
    sourceVersion: sourceVersion,
    contentHash: contentHash ?? this.contentHash,
    text: text ?? this.text,
    editedText: clearEdit ? null : editedText ?? this.editedText,
    truncated: truncated ?? this.truncated,
    imageHandles: imageHandles ?? this.imageHandles,
    wire: clearWire ? null : wire ?? this.wire,
    estimatedTokens: estimatedTokens ?? this.estimatedTokens,
    fromOperationId: fromOperationId ?? this.fromOperationId,
    reply: removeReply ? null : reply ?? this.reply,
    hasAttachments: hasAttachments ?? this.hasAttachments,
    textWithoutAttachments:
        textWithoutAttachments ?? this.textWithoutAttachments,
    attachmentCount: attachmentCount ?? this.attachmentCount,
    inheritedEdit: inheritedEdit ?? this.inheritedEdit,
  );
  CarriedOriginal textOnly() => copyWith(
    imageHandles: [],
    hasAttachments: false,
    attachmentCount: 0,
    wire: wire == null
        ? null
        : replaceWireText(wire!, effectiveText, textOnly: true),
  );
  Map<String, dynamic> toJson() => {
    'sourceMessageId': sourceMessageId,
    'sourceGroupId': sourceGroupId,
    'sourceVersion': sourceVersion,
    'contentHash': contentHash,
    'text': text,
    'editedText': editedText,
    'truncated': truncated,
    'imageHandles': imageHandles,
    'wire': wire,
    'estimatedTokens': estimatedTokens,
    'fromOperationId': fromOperationId,
    'reply': reply?.toJson(),
    'hasAttachments': hasAttachments,
    if (textWithoutAttachments != null)
      'textWithoutAttachments': textWithoutAttachments,
    if (attachmentCount > 0) 'attachmentCount': attachmentCount,
    'inheritedEdit': inheritedEdit,
  };
  factory CarriedOriginal.fromJson(Map json) => CarriedOriginal(
    sourceMessageId: json['sourceMessageId'] as String,
    sourceGroupId: json['sourceGroupId'] as String,
    sourceVersion: json['sourceVersion'] as int,
    contentHash: json['contentHash'] as String,
    text: json['text'] as String,
    editedText: json['editedText'] as String?,
    truncated: json['truncated'] == true,
    imageHandles: List<String>.from(json['imageHandles'] as List? ?? []),
    wire: json['wire'] is Map
        ? Map<String, dynamic>.from(json['wire'] as Map)
        : null,
    estimatedTokens: json['estimatedTokens'] as int,
    fromOperationId: json['fromOperationId'] as String?,
    reply: json['reply'] is Map
        ? CarriedReply.fromJson(json['reply'] as Map)
        : null,
    hasAttachments: json['hasAttachments'] == true,
    textWithoutAttachments: json['textWithoutAttachments'] as String?,
    attachmentCount: json['attachmentCount'] as int? ?? 0,
    inheritedEdit: json['inheritedEdit'] == true,
  );
}

class CarriedOriginals {
  const CarriedOriginals({
    this.formatVersion = 1,
    this.origin = 'explicit',
    required this.setting,
    this.fromSummaries = false,
    this.notFit = 0,
    required this.items,
  });
  final int formatVersion;
  final String origin;
  final CarrySetting setting;
  final bool fromSummaries;
  final int notFit;
  final List<CarriedOriginal> items;
  CarriedOriginals withItems(List<CarriedOriginal> value, {int? notFit}) =>
      CarriedOriginals(
        origin: origin,
        setting: setting,
        fromSummaries: fromSummaries,
        notFit: notFit ?? this.notFit,
        items: value,
      );
  Map<String, dynamic> toJson() => {
    'formatVersion': formatVersion,
    'origin': origin,
    'setting': setting.toJson(),
    'fromSummaries': fromSummaries,
    'notFit': notFit,
    'items': items.map((i) => i.toJson()).toList(),
  };
  factory CarriedOriginals.fromJson(Map json) {
    if (json['formatVersion'] != 1) {
      throw const FormatException('Unknown carried format');
    }
    return CarriedOriginals(
      origin: json['origin'] as String,
      setting: CarrySetting.fromJson(json['setting']),
      fromSummaries: json['fromSummaries'] == true,
      notFit: json['notFit'] as int? ?? 0,
      items: (json['items'] as List)
          .map((i) => CarriedOriginal.fromJson(i as Map))
          .toList(),
    );
  }
}

Map<String, dynamic> textWire(
  String role,
  String text, {
  List<String> images = const [],
}) => {
  'role': role,
  'content': [
    {'type': role == 'assistant' ? 'output_text' : 'input_text', 'text': text},
    for (final image in images) {'type': 'input_image', 'image_url': image},
  ],
};

String carriedWireText(Map wire) {
  final content = wire['content'];
  return content is String
      ? content
      : content is List
      ? content
            .whereType<Map>()
            .where((p) => p['text'] is String)
            .map((p) => p['text'])
            .join('\n')
      : '';
}

/// Explicit carry replays text and images only. Native file and audio bytes
/// belong to the original request. An extracted document travels in the text.
Map<String, dynamic> explicitCarriedWire(
  Map<String, dynamic> wire,
  String text,
) {
  final content = wire['content'];
  if (content is! List) {
    return carriedWireText(wire) == text ? wire : replaceWireText(wire, text);
  }
  final allowed = content
      .where(
        (part) =>
            part is Map &&
            (part['type'] == 'input_text' || part['type'] == 'input_image'),
      )
      .toList();
  final filtered = allowed.length == content.length
      ? wire
      : {...wire, 'content': allowed};
  return carriedWireText(filtered) == text
      ? filtered
      : replaceWireText(filtered, text);
}

Map<String, dynamic> replaceWireText(
  Map<String, dynamic> wire,
  String text, {
  bool textOnly = false,
}) => {
  ...wire,
  'content': wire['content'] is String
      ? text
      : [
          {
            'type': wire['role'] == 'assistant' ? 'output_text' : 'input_text',
            'text': text,
          },
          if (!textOnly && wire['content'] is List)
            for (final p in wire['content'] as List)
              if (p is Map &&
                  p['type'] != 'input_text' &&
                  p['type'] != 'output_text')
                jsonDecode(jsonEncode(p)),
        ],
};
