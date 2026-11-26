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
  final sorted = ranges.where((r) => r.start < limit && r.end > start).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final spans = <TextSpan>[];
  var cursor = start;
  var i = 0;
  while (i < sorted.length) {
    final a = sorted[i].start.clamp(start, limit);
    var b = sorted[i++].end.clamp(start, limit);
    while (i < sorted.length && sorted[i].start <= b) {
      final next = sorted[i++].end.clamp(start, limit);
      if (next > b) b = next;
    }
    if (a > cursor) spans.add(TextSpan(text: text.substring(cursor, a)));
    spans.add(
      TextSpan(
        text: text.substring(a, b),
        style: TextStyle(backgroundColor: color),
      ),
    );
    cursor = b;
  }
  if (cursor < limit) spans.add(TextSpan(text: text.substring(cursor, limit)));
  return TextSpan(children: spans);
}
