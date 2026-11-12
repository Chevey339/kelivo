import 'package:flutter/foundation.dart';

const quotePlaceholder = '\uFFFC';
const maxMessageQuotes = 10;

@immutable
class QuoteRef {
  const QuoteRef({
    required this.id,
    required this.messageId,
    required this.start,
    required this.end,
    required this.text,
    required this.model,
    required this.createdAt,
    this.hasSourceRange = true,
  });

  final String id;
  final String messageId;
  final int start;
  final int end;
  final String text;
  final String? model;
  final DateTime createdAt;

  /// False for text snapshots (such as reasoning selections). In that case
  /// [start] and [end] are unused; the message supplies attribution only.
  final bool hasSourceRange;

  bool sameSource(QuoteRef other) =>
      messageId == other.messageId &&
      hasSourceRange == other.hasSourceRange &&
      (hasSourceRange
          ? start == other.start && end == other.end
          : text == other.text);

  QuoteRef withMessageId(String value) => QuoteRef(
    id: id,
    messageId: value,
    start: start,
    end: end,
    text: text,
    model: model,
    createdAt: createdAt,
    hasSourceRange: hasSourceRange,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'messageId': messageId,
    'start': start,
    'end': end,
    'text': text,
    'model': model,
    'createdAt': createdAt.toIso8601String(),
    'hasSourceRange': hasSourceRange,
  };

  factory QuoteRef.fromJson(Map<String, dynamic> json) => QuoteRef(
    id: json['id'] as String,
    messageId: json['messageId'] as String,
    start: json['start'] as int,
    end: json['end'] as int,
    text: json['text'] as String,
    model: json['model'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    hasSourceRange: json['hasSourceRange'] as bool? ?? true,
  );

  static List<QuoteRef> decodeList(Object? raw) => raw is List
      ? List.unmodifiable(
          raw.map(
            (value) =>
                QuoteRef.fromJson(Map<String, dynamic>.from(value as Map)),
          ),
        )
      : const [];

  @override
  bool operator ==(Object other) =>
      other is QuoteRef &&
      id == other.id &&
      messageId == other.messageId &&
      start == other.start &&
      end == other.end &&
      hasSourceRange == other.hasSourceRange &&
      text == other.text &&
      model == other.model &&
      createdAt == other.createdAt;
  @override
  int get hashCode => Object.hash(
    id,
    messageId,
    start,
    end,
    text,
    model,
    createdAt,
    hasSourceRange,
  );
}

/// The stored body stays editable: one code unit per quote, in list order.
/// Only request/export boundaries expand it into provider-independent text.
String formatQuotedMessage(
  String content,
  List<QuoteRef> quotes, {
  required String Function(int) quoteMarker,
}) {
  if (quotes.isEmpty) return content;
  var index = 0;
  final body = content.replaceAllMapped(RegExp(quotePlaceholder), (_) {
    final number = ++index;
    return number <= quotes.length ? quoteMarker(number) : '';
  });
  final blocks = <String>[];
  for (var i = 0; i < index && i < quotes.length; i++) {
    final lines = quotes[i].text.replaceAll('\r\n', '\n').split('\n');
    blocks.add(
      [
        '> ${quoteMarker(i + 1)} ${lines.first}',
        for (final line in lines.skip(1)) '> $line',
      ].join('\n'),
    );
  }
  return blocks.isEmpty ? body : '${blocks.join('\n')}\n\n$body';
}
