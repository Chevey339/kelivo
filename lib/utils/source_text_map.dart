import 'package:markstream/markstream_core.dart' show SourceSpan, TextSegment;

/// UTF-16 provenance through slicing, concatenation and display replacements.
/// Unchanged text maps character-for-character; replacement text maps to the
/// original match as one unit. No search for an identical paragraph is needed.
class SourceTextMap {
  SourceTextMap._(this.length, this._pieces, this._origin);
  factory SourceTextMap.identity(int length, {int offset = 0}) =>
      SourceTextMap._(length, [
        if (length > 0) _SourcePiece(0, length, offset, offset + length, true),
      ], offset);
  factory SourceTextMap.replacement(int length, SourceSpan source) =>
      SourceTextMap._(length, [
        if (length > 0)
          _SourcePiece(0, length, source.start, source.end, false),
      ], source.start);
  factory SourceTextMap.fromSegments(Iterable<TextSegment> source) {
    final pieces = <_SourcePiece>[];
    var offset = 0;
    for (final segment in source) {
      if (segment.text.isEmpty) continue;
      pieces.add(
        _SourcePiece(
          offset,
          offset + segment.text.length,
          segment.sourceSpan.start,
          segment.sourceSpan.end,
          segment.text.length == segment.sourceSpan.length,
        ),
      );
      offset += segment.text.length;
    }
    return SourceTextMap._(
      offset,
      pieces,
      pieces.firstOrNull?.sourceStart ?? 0,
    );
  }
  factory SourceTextMap.join(Iterable<SourceTextMap> maps) {
    final pieces = <_SourcePiece>[];
    var length = 0;
    int? origin;
    for (final map in maps) {
      origin ??= map._origin;
      for (final piece in map._pieces) {
        pieces.add(piece.shift(length));
      }
      length += map.length;
    }
    return SourceTextMap._(length, pieces, origin ?? 0);
  }

  /// Compose this text's source coordinates with an earlier transformation.
  SourceTextMap through(SourceTextMap original) => SourceTextMap.join([
    for (final piece in _pieces)
      if (piece.linear)
        original.slice(piece.sourceStart, piece.sourceEnd)
      else
        (() {
          final source = original.sourceRange(
            piece.sourceStart,
            piece.sourceEnd,
          );
          return SourceTextMap._(piece.end - piece.start, [
            _SourcePiece(
              0,
              piece.end - piece.start,
              source.start,
              source.end,
              false,
            ),
          ], source.start);
        })(),
  ]);

  final int length;
  final List<_SourcePiece> _pieces;
  final int _origin;

  int _firstAfter(int offset) {
    var low = 0, high = _pieces.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (_pieces[middle].end <= offset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  Iterable<_SourcePiece> _overlapping(int start, int end) sync* {
    for (
      var i = _firstAfter(start);
      i < _pieces.length && _pieces[i].start < end;
      i++
    ) {
      yield _pieces[i];
    }
  }

  SourceSpan sourceRange(int start, int end) {
    assert(start >= 0 && end >= start && end <= length);
    final spans = <SourceSpan>[];
    for (final piece in _overlapping(start, end)) {
      final span = piece.sourceSlice(start, end);
      if (!span.isEmpty) spans.add(span);
    }
    if (spans.isNotEmpty) {
      return SourceSpan(
        spans.map((span) => span.start).reduce((a, b) => a < b ? a : b),
        spans.map((span) => span.end).reduce((a, b) => a > b ? a : b),
      );
    }
    final next = _firstAfter(start);
    if (next < _pieces.length) {
      final piece = _pieces[next];
      final point = piece.linear
          ? piece.sourceStart +
                (start - piece.start).clamp(0, piece.end - piece.start)
          : piece.sourceStart;
      return SourceSpan(point, point);
    }
    final point = _pieces.lastOrNull?.sourceEnd ?? _origin;
    return SourceSpan(point, point);
  }

  List<SourceSpan> displayRanges(SourceSpan source) => [
    for (final piece in _pieces)
      if (piece.sourceEnd > source.start && piece.sourceStart < source.end)
        SourceSpan(
          piece.linear
              ? piece.start +
                    (source.start - piece.sourceStart).clamp(
                      0,
                      piece.end - piece.start,
                    )
              : piece.start,
          piece.linear
              ? piece.start +
                    (source.end - piece.sourceStart).clamp(
                      0,
                      piece.end - piece.start,
                    )
              : piece.end,
        ),
  ];

  SourceTextMap slice(int start, int end) {
    assert(start >= 0 && end >= start && end <= length);
    final pieces = <_SourcePiece>[];
    for (final piece in _overlapping(start, end)) {
      final from = piece.start.clamp(start, end),
          to = piece.end.clamp(start, end);
      final source = piece.sourceSlice(from, to);
      pieces.add(
        _SourcePiece(
          from - start,
          to - start,
          source.start,
          source.end,
          piece.linear,
        ),
      );
    }
    return SourceTextMap._(
      end - start,
      pieces,
      sourceRange(start, start).start,
    );
  }

  SourceTextMap replace(List<(int start, int end, int length)> changes) {
    if (changes.isEmpty) return this;
    final maps = <SourceTextMap>[];
    var cursor = 0;
    for (final (start, end, count) in changes) {
      maps.add(slice(cursor, start));
      if (count > 0) {
        final source = sourceRange(start, end);
        maps.add(
          SourceTextMap._(count, [
            _SourcePiece(0, count, source.start, source.end, false),
          ], source.start),
        );
      }
      cursor = end;
    }
    maps.add(slice(cursor, length));
    return SourceTextMap.join(maps);
  }
}

class _SourcePiece {
  const _SourcePiece(
    this.start,
    this.end,
    this.sourceStart,
    this.sourceEnd,
    this.linear,
  );
  final int start, end, sourceStart, sourceEnd;
  final bool linear;
  _SourcePiece shift(int offset) => _SourcePiece(
    start + offset,
    end + offset,
    sourceStart,
    sourceEnd,
    linear,
  );
  SourceSpan sourceSlice(int from, int to) => linear
      ? SourceSpan(
          sourceStart + (from - start).clamp(0, end - start),
          sourceStart + (to - start).clamp(0, end - start),
        )
      : SourceSpan(sourceStart, sourceEnd);
}
