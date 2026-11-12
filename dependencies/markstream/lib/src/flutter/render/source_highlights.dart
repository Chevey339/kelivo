import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/ast/source_span.dart';
import '../../core/text_index/text_index.dart';

/// Immutable, merged intervals in the original UTF-16 source. Decoration never
/// changes parser input, AST identity, text projections or clipboard content.
class SourceHighlights {
  factory SourceHighlights(Iterable<SourceSpan> ranges, Color color) {
    if (ranges.isEmpty) return empty;
    final sorted = ranges.where((range) => !range.isEmpty).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final merged = <SourceSpan>[];
    for (final range in sorted) {
      if (merged.isNotEmpty && merged.last.end >= range.start) {
        final previous = merged.removeLast();
        merged.add(
          SourceSpan(
            previous.start,
            previous.end > range.end ? previous.end : range.end,
          ),
        );
      } else {
        merged.add(range);
      }
    }
    return merged.isEmpty
        ? empty
        : SourceHighlights._(List.unmodifiable(merged), color);
  }
  const SourceHighlights._(this.ranges, this.color);
  static const empty = SourceHighlights._([], Color(0x00000000));
  final List<SourceSpan> ranges;
  final Color color;
  bool get isEmpty => ranges.isEmpty;

  Iterable<SourceSpan> _overlaps(SourceSpan span) sync* {
    if (span.isEmpty) return;
    var low = 0, high = ranges.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (ranges[mid].end <= span.start)
        low = mid + 1;
      else
        high = mid;
    }
    for (var i = low; i < ranges.length && ranges[i].start < span.end; i++) {
      yield ranges[i];
    }
  }

  bool intersects(SourceSpan span) => _overlaps(span).isNotEmpty;

  /// Nonlinear fragments (decoded entities and escapes) are indivisible. The
  /// returned intervals use rendered text offsets, not original source offsets.
  List<SourceSpan> textRanges(Iterable<TextSegment> segments) {
    final result = <SourceSpan>[];
    var offset = 0;
    for (final segment in segments) {
      final source = segment.sourceSpan;
      for (final range in _overlaps(source)) {
        final linear = source.length == segment.text.length;
        final start = linear && range.start > source.start
            ? range.start - source.start
            : 0;
        final end = linear && range.end < source.end
            ? range.end - source.start
            : segment.text.length;
        if (start < end) result.add(SourceSpan(offset + start, offset + end));
      }
      offset += segment.text.length;
    }
    return result;
  }

  TextSpan text(TextSpan span, Iterable<TextSegment> segments) =>
      isEmpty ? span : paintTextHighlights(span, textRanges(segments), color);

  /// Custom nodes containing widgets are atoms: their selectable projection
  /// can be longer than WidgetSpan's single rendered placeholder.
  InlineSpan customInline(
    InlineSpan span,
    SourceSpan source,
    List<TextSegment> segments,
  ) {
    if (isEmpty) return span;
    var embedded = span is WidgetSpan;
    span.visitChildren((child) {
      if (child is WidgetSpan) embedded = true;
      return !embedded;
    });
    if (!embedded) return span is TextSpan ? text(span, segments) : span;
    if (!intersects(source)) return span;
    InlineSpan paint(InlineSpan part) {
      if (part is WidgetSpan) {
        return WidgetSpan(
          alignment: part.alignment,
          baseline: part.baseline,
          style: part.style,
          child: atom(source, part.child),
        );
      }
      if (part is TextSpan) {
        return _copySpan(
          part,
          text: part.text,
          children: [
            for (final child in part.children ?? <InlineSpan>[]) paint(child),
          ],
          style: (part.style ?? const TextStyle()).copyWith(
            background: Paint()..color = color,
          ),
        );
      }
      return part;
    }

    return paint(span);
  }

  Widget atom(SourceSpan source, Widget child) => isEmpty || !intersects(source)
      ? child
      : DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(color: color),
          child: child,
        );

  @override
  bool operator ==(Object other) =>
      other is SourceHighlights &&
      color == other.color &&
      listEquals(ranges, other.ranges);
  @override
  int get hashCode => Object.hash(color, Object.hashAll(ranges));
}

class SourceHighlightScope extends InheritedWidget {
  const SourceHighlightScope({
    super.key,
    required this.highlights,
    required super.child,
  });
  final SourceHighlights highlights;
  static SourceHighlights of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SourceHighlightScope>()
          ?.highlights ??
      SourceHighlights.empty;
  @override
  bool updateShouldNotify(SourceHighlightScope oldWidget) =>
      highlights != oldWidget.highlights;
}

/// Paints offsets in a text-only span tree without changing its selectable text
/// or syntax/link metadata. Splits never bisect a UTF-16 surrogate pair.
TextSpan paintTextHighlights(
  TextSpan root,
  List<SourceSpan> ranges,
  Color color,
) {
  if (ranges.isEmpty) return root;
  final normalized = SourceHighlights(ranges, color);
  var offset = 0;
  TextSpan visit(TextSpan span) {
    final text = span.text ?? '';
    final start = offset;
    offset += text.length;
    final cuts = <int>{0, text.length};
    final local = <SourceSpan>[];
    for (final range in normalized._overlaps(SourceSpan(start, offset))) {
      var a = (range.start - start).clamp(0, text.length);
      var b = (range.end - start).clamp(0, text.length);
      if (a >= b) continue;
      bool lowSurrogate(int i) =>
          i > 0 &&
          i < text.length &&
          text.codeUnitAt(i) >= 0xdc00 &&
          text.codeUnitAt(i) <= 0xdfff &&
          text.codeUnitAt(i - 1) >= 0xd800 &&
          text.codeUnitAt(i - 1) <= 0xdbff;
      if (lowSurrogate(a)) a--;
      if (lowSurrogate(b)) b++;
      local.add(SourceSpan(a, b));
      cuts.addAll([a, b]);
    }
    final children = [
      for (final child in span.children ?? const <InlineSpan>[])
        if (child is TextSpan) visit(child) else child,
    ];
    if (local.isEmpty)
      return _copySpan(span, text: span.text, children: children);
    if (span.semanticsLabel != null ||
        span.semanticsIdentifier != null ||
        span.spellOut != null) {
      // Splitting text below a semantics override would speak both its label
      // and the new children. Keep this accessible fragment as one paint atom.
      return _copySpan(
        span,
        text: span.text,
        children: children,
        style: (span.style ?? const TextStyle()).copyWith(
          background: Paint()..color = color,
        ),
      );
    }
    final points = cuts.toList()..sort();
    final pieces = <InlineSpan>[];
    var selected = 0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (a == b) continue;
      while (selected < local.length && local[selected].end <= a) selected++;
      final marked = selected < local.length && local[selected].contains(a);
      pieces.add(
        TextSpan(
          text: text.substring(a, b),
          style: marked ? TextStyle(background: Paint()..color = color) : null,
          recognizer: span.recognizer,
          mouseCursor: span.mouseCursor,
          onEnter: span.onEnter,
          onExit: span.onExit,
        ),
      );
    }
    return _copySpan(span, children: [...pieces, ...children]);
  }

  return visit(root);
}

TextSpan _copySpan(
  TextSpan span, {
  String? text,
  required List<InlineSpan> children,
  TextStyle? style,
}) => TextSpan(
  text: text,
  children: children,
  style: style ?? span.style,
  recognizer: span.recognizer,
  mouseCursor: span.mouseCursor,
  onEnter: span.onEnter,
  onExit: span.onExit,
  semanticsLabel: span.semanticsLabel,
  semanticsIdentifier: span.semanticsIdentifier,
  locale: span.locale,
  spellOut: span.spellOut,
);
