import 'package:markstream/markstream_core.dart';
import 'source_text_map.dart';

/// Executes regexes in whole-text coordinates (including ^/$ and lookarounds),
/// while retaining immutable source intervals and their line boundaries.
final class ProtectedText {
  factory ProtectedText(
    String text,
    Iterable<SourceSpan> ranges, {
    Iterable<int> offsets = const [],
    Iterable<bool>? beforeInsertion,
    SourceTextMap? sourceMap,
  }) {
    final positions = List<int>.unmodifiable(offsets);
    return ProtectedText._(
      text,
      List.unmodifiable(ranges),
      positions,
      List.unmodifiable(
        beforeInsertion ??
            [
              for (final (index, offset) in positions.indexed)
                offset == 0 &&
                    (text.isNotEmpty || index < positions.length - 1),
            ],
      ),
      sourceMap,
    );
  }
  ProtectedText._(
    this.text,
    this.ranges,
    this.offsets,
    this.beforeInsertion,
    this.sourceMap,
  );
  final String text;
  final List<SourceSpan> ranges;
  final List<int> offsets;
  final List<bool> beforeInsertion;
  final SourceTextMap? sourceMap;

  ProtectedText replaceAll(Pattern pattern, String replacement) =>
      replaceAllMapped(pattern, (_) => replacement);

  ProtectedText replaceAllMapped(
    Pattern pattern,
    String Function(Match) replacement,
  ) {
    final buffer = StringBuffer();
    final changes = <(int, int, int)>[];
    final sourceChanges = <(int, int, int)>[];
    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      final blocked = ranges.any((span) {
        var start = span.start, end = span.end;
        // Keep the newline separating a fence from surrounding prose. Deleting
        // it or inserting at the closer can change Markdown block structure.
        if (start > 0 && text.codeUnitAt(start - 1) == 10) {
          start--;
          if (start > 0 && text.codeUnitAt(start - 1) == 13) start--;
        }
        if (end < text.length && text.codeUnitAt(end) == 13) end++;
        if (end < text.length && text.codeUnitAt(end) == 10) end++;
        return match.start == match.end
            ? match.start >= start && match.start <= end
            : match.start < end && match.end > start;
      });
      if (blocked) continue;
      buffer.write(text.substring(cursor, match.start));
      final value = replacement(match);
      buffer.write(value);
      changes.add((match.start, match.end, value.length));
      if (value != match[0]) {
        sourceChanges.add((match.start, match.end, value.length));
      }
      cursor = match.end;
    }
    if (changes.isEmpty) return this;
    buffer.write(text.substring(cursor));
    var index = 0, delta = 0;
    final mapped = <SourceSpan>[];
    for (final range in ranges) {
      while (index < changes.length && changes[index].$2 <= range.start) {
        final change = changes[index++];
        delta += change.$3 - (change.$2 - change.$1);
      }
      mapped.add(SourceSpan(range.start + delta, range.end + delta));
    }
    int mapOffset(int offset, bool before) {
      var shift = 0;
      for (final (start, end, length) in changes) {
        if (end < offset || (end == offset && (start < end || !before))) {
          shift += length - (end - start);
        } else if (start < offset) {
          return start + shift + length;
        } else {
          break;
        }
      }
      return offset + shift;
    }

    return ProtectedText(
      buffer.toString(),
      mapped,
      offsets: [
        for (var i = 0; i < offsets.length; i++)
          mapOffset(offsets[i], beforeInsertion[i]),
      ],
      beforeInsertion: beforeInsertion,
      sourceMap: sourceMap?.replace(sourceChanges),
    );
  }
}
