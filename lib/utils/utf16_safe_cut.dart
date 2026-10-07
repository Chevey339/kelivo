/// Surrogate-safe UTF-16 cut helpers.
///
/// Truncating a Dart `String` with a plain `substring` can split a UTF-16
/// surrogate pair, leaving a lone high/low surrogate behind. A lone surrogate
/// cannot be serialized by `jsonEncode` (and breaks any UTF-8/JSON boundary),
/// so every cross-process truncation site in this repo uses these helpers
/// instead of raw `substring`.
library;

/// Returns an end index suitable for `value.substring(0, result)` that never
/// ends on the middle of a UTF-16 surrogate pair. When [end] falls exactly
/// between a high surrogate (at `end - 1`) and its low surrogate (at `end`),
/// the cut moves one code unit back so the whole pair is dropped from the
/// head instead of being torn.
int utf16SafeHeadEnd(String value, int end) {
  if (end <= 0 || end >= value.length) return end;
  final prev = value.codeUnitAt(end - 1);
  final cur = value.codeUnitAt(end);
  if (!_isHighSurrogate(prev) || !_isLowSurrogate(cur)) return end;
  return end - 1;
}

/// Returns a start index suitable for `value.substring(result)` that never
/// starts on the middle of a UTF-16 surrogate pair. When [start] falls
/// exactly between a high surrogate (at `start - 1`) and its low surrogate
/// (at `start`), the cut moves one code unit forward so the whole pair is
/// dropped from the tail instead of being torn.
int utf16SafeTailStart(String value, int start) {
  if (start <= 0 || start >= value.length) return start;
  final prev = value.codeUnitAt(start - 1);
  final cur = value.codeUnitAt(start);
  if (!_isHighSurrogate(prev) || !_isLowSurrogate(cur)) return start;
  return start + 1;
}

/// Redistributes [value] over the original text slots without splitting pairs.
/// Cut positions use cumulative [originalLengths], so splitting or merging
/// adjacent slots cannot move a later boundary. A pair crossing a cut stays
/// in the earlier slot; the last slot receives all remaining text.
List<String> redistributeTextUtf16Safe(
  String value,
  List<int> originalLengths,
) {
  final parts = <String>[];
  var originalEnd = 0;
  var start = 0;
  for (var i = 0; i < originalLengths.length; i++) {
    originalEnd += originalLengths[i];
    final end = utf16SafeTailStart(
      value,
      i == originalLengths.length - 1
          ? value.length
          : originalEnd.clamp(0, value.length),
    );
    parts.add(value.substring(start, end));
    start = end;
  }
  return parts;
}

/// Truncates [value] to at most [maxLength] code units, keeping the head.
/// A UTF-16 surrogate pair straddling the cut is dropped whole, never split.
String truncateHeadUtf16Safe(String value, int maxLength) {
  if (value.length <= maxLength) return value;
  return value.substring(0, utf16SafeHeadEnd(value, maxLength));
}

/// Bounds [value] to [maxLength] code units, keeping a head/tail preview
/// joined by [marker]. Cut points are adjusted so a UTF-16 surrogate pair is
/// never split; the output length stays at or below [maxLength].
String truncateHeadTailUtf16Safe(
  String value,
  int maxLength, {
  required String marker,
}) {
  if (value.length <= maxLength) return value;
  final available = maxLength - marker.length;
  if (available <= 0) return truncateHeadUtf16Safe(value, maxLength);
  final head = available ~/ 2;
  final tail = available - head;
  final headEnd = utf16SafeHeadEnd(value, head);
  final tailStart = utf16SafeTailStart(value, value.length - tail);
  return '${value.substring(0, headEnd)}$marker'
      '${value.substring(tailStart)}';
}

/// Splits [value] into chunks of at most [maxLength] code units.
/// A UTF-16 surrogate pair is never torn; a pair that would straddle a
/// cut is kept whole, so a chunk may be one unit over [maxLength] when
/// [maxLength] is 1.
List<String> splitUtf16SafeChunks(String value, int maxLength) {
  if (maxLength <= 0) return value.isEmpty ? const <String>[] : [value];
  if (value.length <= maxLength) return [value];
  final out = <String>[];
  var start = 0;
  while (start < value.length) {
    var end = start + maxLength;
    if (end >= value.length) {
      out.add(value.substring(start));
      break;
    }
    end = utf16SafeHeadEnd(value, end);
    if (end <= start) {
      end = start + 2 <= value.length ? start + 2 : value.length;
    }
    out.add(value.substring(start, end));
    start = end;
  }
  return out;
}

/// Split [value] at the midpoint without tearing a UTF-16 surrogate pair.
///
/// Unlike cutting with [utf16SafeHeadEnd] and [utf16SafeTailStart]
/// independently, both halves cover the original string — the pair that
/// straddles the midpoint is kept wholly in one half, never dropped.
/// Returns null when the string cannot be split into two non-empty parts.
({String left, String right})? splitUtf16SafeHalves(String value) {
  if (value.length < 2) return null;
  final mid = value.length ~/ 2;
  var cut = utf16SafeHeadEnd(value, mid);
  if (cut <= 0 || cut >= value.length) {
    cut = utf16SafeTailStart(value, mid);
  }
  if (cut <= 0 || cut >= value.length) return null;
  return (left: value.substring(0, cut), right: value.substring(cut));
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;
