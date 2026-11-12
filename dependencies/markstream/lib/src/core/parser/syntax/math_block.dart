/// A display-math opener in an original source line.
final class MathBlockStart {
  const MathBlockStart(this.start, this.delimiter, this.closer);
  final int start;
  final String delimiter;
  final String closer;
  int get bodyStart => start + delimiter.length;
}

bool _escaped(String source, int offset) {
  var slashes = 0;
  for (var i = offset - 1; i >= 0 && source.codeUnitAt(i) == 92; i--) {
    slashes++;
  }
  return slashes.isOdd;
}

int findMathBlockClose(String source, int start, int end, String closer) {
  var offset = source.indexOf(closer, start);
  while (offset >= 0 && offset + closer.length <= end) {
    if (!_escaped(source, offset)) return offset;
    offset = source.indexOf(closer, offset + closer.length);
  }
  return -1;
}

int findLastMathBlockClose(String source, String closer) {
  var offset = source.lastIndexOf(closer);
  while (offset >= 0 && _escaped(source, offset)) {
    if (offset == 0) return -1;
    offset = source.lastIndexOf(closer, offset - 1);
  }
  return offset;
}

MathBlockStart? findMathBlockStart(
  String source,
  int start,
  int end, {
  bool streaming = false,
  bool Function(int after, String closer)? hasLaterClose,
}) {
  for (var i = start; i < end; i++) {
    final char = source.codeUnitAt(i);
    if (char != 96 &&
        !(char == 36 && source.startsWith(r'$$', i)) &&
        !(char == 92 && source.startsWith(r'\[', i)))
      continue;
    if (_escaped(source, i)) continue;
    if (char == 96) {
      var run = i + 1;
      while (run < end && source.codeUnitAt(run) == 96) run++;
      final marker = source.substring(i, run);
      var close = source.indexOf(marker, run);
      while (close >= 0 && close < end) {
        var after = close + marker.length;
        while (after < end && source.codeUnitAt(after) == 96) after++;
        if (after - close == marker.length) {
          i = after - 1;
          break;
        }
        close = source.indexOf(marker, after);
      }
      if (close >= 0 && close < end) continue;
      i = run - 1;
      continue;
    }
    final String opener;
    final String closer;
    if (i + 2 <= end && source.startsWith(r'$$', i)) {
      if (i > start && !RegExp(r'\s').hasMatch(source[i - 1])) continue;
      opener = closer = r'$$';
    } else if (i + 2 <= end && source.startsWith(r'\[', i)) {
      opener = r'\[';
      closer = r'\]';
    } else {
      continue;
    }
    final bodyStart = i + opener.length;
    final sameLineClose = findMathBlockClose(source, bodyStart, end, closer);
    // Empty escaped brackets are punctuation, not a display formula.
    if (opener == r'\[' &&
        sameLineClose >= 0 &&
        source.substring(bodyStart, sameLineClose).trim().isEmpty) {
      i = sameLineClose + closer.length - 1;
      continue;
    }
    final after = source.substring(bodyStart, end);
    if (after.trim().isEmpty ||
        findMathBlockClose(source, i + opener.length, end, closer) >= 0 ||
        streaming ||
        (hasLaterClose?.call(end, closer) ?? false)) {
      return MathBlockStart(i, opener, closer);
    }
  }
  return null;
}
