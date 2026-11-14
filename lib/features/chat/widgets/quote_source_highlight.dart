import 'package:flutter/material.dart';
import 'package:markstream/markstream.dart';
import '../../../core/models/chat_message.dart';
import '../../../utils/source_text_map.dart';
import 'quote_interaction_scope.dart';

List<SourceSpan> quoteSourceHighlights(
  BuildContext context,
  ChatMessage message,
  String source, {
  int? sourceOffset,
  SourceTextMap? sourceMap,
}) {
  final quotes =
      QuoteInteractionScope.maybeOf(context)?.highlightsFor(message.id) ??
      const [];
  if (quotes.isEmpty) return const [];
  if (sourceMap != null) {
    return [
      for (final quote in quotes)
        ...sourceMap.displayRanges(SourceSpan(quote.start, quote.end)),
    ];
  }
  final base = sourceOffset ?? message.content.indexOf(source);
  if (base < 0) return const [];
  return [
    for (final quote in quotes)
      if (quote.end > base && quote.start < base + source.length)
        SourceSpan(
          (quote.start - base).clamp(0, source.length),
          (quote.end - base).clamp(0, source.length),
        ),
  ];
}

TextSpan highlightedQuoteSource(
  String text,
  List<SourceSpan> ranges,
  Color color, {
  int start = 0,
  int? end,
}) {
  final limit = end ?? text.length;
  final points = {
    start,
    limit,
    for (final range in ranges)
      if (range.start < limit && range.end > start) ...[
        range.start.clamp(start, limit),
        range.end.clamp(start, limit),
      ],
  }.toList()..sort();
  return TextSpan(
    children: [
      for (var i = 0; i < points.length - 1; i++)
        TextSpan(
          text: text.substring(points[i], points[i + 1]),
          style:
              ranges.any(
                (range) => range.start <= points[i] && range.end > points[i],
              )
              ? TextStyle(backgroundColor: color)
              : null,
        ),
    ],
  );
}
