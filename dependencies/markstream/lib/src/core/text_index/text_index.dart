import '../ast/nodes.dart';
import '../ast/source_span.dart';
import '../serialize/common.dart';

/// One rendered/selectable fragment. Generated glyphs use an empty source span.
final class TextSegment {
  const TextSegment({required this.text, required this.sourceSpan, this.node});
  final String text;
  final SourceSpan sourceSpan;
  final MarkdownNode? node;
}

final class TextIndexEntry {
  const TextIndexEntry(this.start, this.end, this.segment);
  final int start;
  final int end;
  final TextSegment segment;
  SourceSpan get sourceSpan => segment.sourceSpan;
}

/// Maps selectable UTF-16 offsets to original source, independently of TSV,
/// list markers and paragraph separators generated for clipboard text.
final class TextIndex {
  factory TextIndex.fromSegments(Iterable<TextSegment> segments) {
    final entries = <TextIndexEntry>[];
    final text = StringBuffer();
    var offset = 0;
    for (final segment in segments) {
      if (segment.text.isEmpty) continue;
      entries.add(
        TextIndexEntry(offset, offset + segment.text.length, segment),
      );
      text.write(segment.text);
      offset += segment.text.length;
    }
    return TextIndex._(text.toString(), entries);
  }

  factory TextIndex.fromDocument(DocumentNode document) {
    final segments = <TextSegment>[];
    final pending = <MarkdownNode>[document];
    void emit(String text, MarkdownNode node, [SourceSpan? span]) =>
        segments.add(
          TextSegment(text: text, sourceSpan: span ?? node.span, node: node),
        );
    void code(List<TextNode> fragments) {
      var length = fragments.fold(0, (sum, node) => sum + node.text.length);
      if (fragments.isNotEmpty && fragments.last.text.endsWith('\n')) length--;
      for (final fragment in fragments) {
        if (length <= 0) break;
        final take = length < fragment.text.length
            ? length
            : fragment.text.length;
        final source =
            take == fragment.text.length ||
                fragment.span.length != fragment.text.length
            ? fragment.span
            : SourceSpan(fragment.span.start, fragment.span.start + take);
        emit(fragment.text.substring(0, take), fragment, source);
        length -= take;
      }
    }

    while (pending.isNotEmpty) {
      final node = pending.removeLast();
      if (node is TextNode) {
        emit(node.text, node);
      } else if (node is LineBreakNode) {
        emit('\n', node);
      } else if (node is CodeBlockNode) {
        code(node.children);
      } else if (node is HtmlBlockNode && node.fullDocument) {
        code(node.rawFragments);
      } else if (node is MathInlineNode) {
        emit(
          mathSource(
            node.tex,
            node.delimiter,
            block: false,
            closed: node.closed,
          ),
          node,
        );
      } else if (node is MathBlockNode) {
        emit(
          mathSource(
            node.tex,
            node.delimiter,
            block: true,
            closed: node.closed,
          ),
          node,
        );
      } else if (node is ReferenceDefinitionNode || node is ThematicBreakNode) {
        continue;
      } else if (node is HtmlElementNode && node.tag == 'br') {
        emit('\n', node);
      } else if (node is HtmlElementNode && node.tag == 'img') {
        emit(node.attributes['alt'] ?? '', node);
      } else {
        pending.addAll(node.children.reversed);
      }
    }
    return TextIndex.fromSegments(segments);
  }

  TextIndex._(this.text, List<TextIndexEntry> entries)
    : entries = List.unmodifiable(entries);
  final String text;
  final List<TextIndexEntry> entries;
  int get length => text.length;

  SourceSpan sourceSpanForRange(int start, int end) {
    _check(start, end);
    if (entries.isEmpty) return const SourceSpan(0, 0);
    if (start == end) {
      final entry =
          entries[_entryAt(start == length && start > 0 ? start - 1 : start)];
      final position = _sourceOffset(entry, start, endBoundary: false);
      return SourceSpan(position, position);
    }
    int? sourceStart, sourceEnd;
    final first = _entryAt(start);
    for (var i = first; i < entries.length && entries[i].start < end; i++) {
      final entry = entries[i];
      if (entry.sourceSpan.isEmpty) continue;
      final a = _sourceOffset(
        entry,
        start.clamp(entry.start, entry.end),
        endBoundary: false,
      );
      final b = _sourceOffset(
        entry,
        end.clamp(entry.start, entry.end),
        endBoundary: true,
      );
      sourceStart = sourceStart == null || a < sourceStart ? a : sourceStart;
      sourceEnd = sourceEnd == null || b > sourceEnd ? b : sourceEnd;
    }
    // Clipboard-only separators have no source width. They must not move a
    // real selected range backwards to their generated anchor.
    return sourceStart == null
        ? SourceSpan(
            entries[first].sourceSpan.start,
            entries[first].sourceSpan.start,
          )
        : SourceSpan(sourceStart, sourceEnd!);
  }

  ({int start, int end})? textRangeForSource(SourceSpan source) {
    int? start;
    int? end;
    for (final entry in entries) {
      if (!entry.sourceSpan.overlaps(source)) continue;
      final oneToOne = entry.sourceSpan.length == entry.end - entry.start;
      final a = oneToOne && source.start > entry.sourceSpan.start
          ? entry.start + source.start - entry.sourceSpan.start
          : entry.start;
      final b = oneToOne && source.end < entry.sourceSpan.end
          ? entry.start + source.end - entry.sourceSpan.start
          : entry.end;
      start ??= a;
      end = b;
    }
    return start == null ? null : (start: start, end: end!);
  }

  List<TextSegment> segmentsForRange(int start, int end) {
    _check(start, end);
    final selected = <TextSegment>[];
    if (start == end) return selected;
    for (
      var i = _entryAt(start);
      i < entries.length && entries[i].start < end;
      i++
    ) {
      final entry = entries[i];
      final a = start > entry.start ? start : entry.start;
      final b = end < entry.end ? end : entry.end;
      selected.add(
        TextSegment(
          text: text.substring(a, b),
          sourceSpan: SourceSpan(
            _sourceOffset(entry, a, endBoundary: false),
            _sourceOffset(entry, b, endBoundary: true),
          ),
          node: entry.segment.node,
        ),
      );
    }
    return List.unmodifiable(selected);
  }

  int _entryAt(int offset) {
    var low = 0;
    var high = entries.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (entries[mid].end <= offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low < entries.length ? low : entries.length - 1;
  }

  int _sourceOffset(
    TextIndexEntry entry,
    int offset, {
    required bool endBoundary,
  }) {
    if (entry.sourceSpan.length == entry.end - entry.start)
      return entry.sourceSpan.start + offset - entry.start;
    if (offset <= entry.start) return entry.sourceSpan.start;
    if (offset >= entry.end) return entry.sourceSpan.end;
    return endBoundary ? entry.sourceSpan.end : entry.sourceSpan.start;
  }

  void _check(int start, int end) {
    if (start < 0 || end < start || end > length)
      throw RangeError(
        'Invalid selectable range $start..$end for length $length',
      );
  }
}
