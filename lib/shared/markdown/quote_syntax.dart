import 'package:flutter/material.dart';
import 'package:markstream/markstream.dart';
import '../../core/models/quote_ref.dart';
import '../../features/chat/widgets/quote_chip.dart';
import '../../utils/source_text_map.dart';

class QuoteSyntax extends InlineSyntax {
  const QuoteSyntax();
  @override
  Set<int> get startCharacters => const {0xfffc};
  @override
  InlineSyntaxMatch? match(InlineSyntaxContext context, int offset) =>
      context.text.codeUnitAt(offset) == 0xfffc
      ? InlineSyntaxMatch(
          end: offset + 1,
          node: NamedInlineNode(
            span: context.span(offset, offset + 1),
            name: 'kelivo-quote',
            children: context.textNodes(offset, offset + 1),
          ),
        )
      : null;
}

class QuoteRenderScope extends InheritedWidget {
  const QuoteRenderScope({
    super.key,
    required this.source,
    required this.quotes,
    this.sourceMap,
    required super.child,
  });
  final String source;
  final List<QuoteRef> quotes;
  final SourceTextMap? sourceMap;
  QuoteRef? quoteAt(int offset) => quoteAtSourceOffset(
    source,
    quotes,
    sourceMap?.sourceRange(offset, offset + 1).start ?? offset,
  );
  static QuoteRenderScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<QuoteRenderScope>();
  @override
  bool updateShouldNotify(QuoteRenderScope oldWidget) =>
      source != oldWidget.source ||
      quotes != oldWidget.quotes ||
      sourceMap != oldWidget.sourceMap;
}

QuoteRef? quoteAtSourceOffset(
  String source,
  List<QuoteRef> quotes,
  int offset,
) {
  if (offset < 0 ||
      offset >= source.length ||
      source.codeUnitAt(offset) != 0xfffc) {
    return null;
  }
  final index = RegExp(
    quotePlaceholder,
  ).allMatches(source.substring(0, offset)).length;
  return index < quotes.length ? quotes[index] : null;
}

RenderedInline buildQuoteInline(
  BuildContext context,
  InlineNode node,
  MarkstreamRenderContext rendering,
) {
  final scope = QuoteRenderScope.of(context);
  final quote = scope?.quoteAt(node.span.start);
  return RenderedInline(
    segments: [
      TextSegment(text: quotePlaceholder, sourceSpan: node.span, node: node),
    ],
    span: quote == null
        ? const TextSpan(text: quotePlaceholder)
        : WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: SelectableSpanAdapter(
              selectedText: quotePlaceholder,
              child: QuoteChip(quote: quote, style: rendering.theme.body),
            ),
          ),
  );
}

/// Code bypasses inline parsing. Decorate its already-highlighted literal
/// spans using the renderer's source projection, preserving code styles and
/// one selectable UTF-16 character for each embedded reference.
TextSpan buildQuoteLiteralSpan(
  BuildContext context,
  TextSpan span,
  List<TextSegment> source,
) {
  final scope = QuoteRenderScope.of(context);
  if (scope == null || !span.toPlainText().contains(quotePlaceholder)) {
    return span;
  }
  final index = TextIndex.fromSegments(source);
  var offset = 0;
  InlineSpan decorate(InlineSpan part, TextStyle inherited) {
    if (part is! TextSpan) {
      offset += part.toPlainText().length;
      return part;
    }
    final style = inherited.merge(part.style);
    final text = part.text ?? '';
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in RegExp(quotePlaceholder).allMatches(text)) {
      if (cursor < match.start) {
        children.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final sourceOffset = index
          .sourceSpanForRange(offset + match.start, offset + match.end)
          .start;
      final quote = scope.quoteAt(sourceOffset);
      children.add(
        quote == null
            ? const TextSpan(text: quotePlaceholder)
            : WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: SelectableSpanAdapter(
                  selectedText: quotePlaceholder,
                  child: QuoteChip(quote: quote, style: style),
                ),
              ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    offset += text.length;
    for (final child in part.children ?? const <InlineSpan>[]) {
      children.add(decorate(child, style));
    }
    return TextSpan(style: part.style, children: children);
  }

  return decorate(span, DefaultTextStyle.of(context).style) as TextSpan;
}
