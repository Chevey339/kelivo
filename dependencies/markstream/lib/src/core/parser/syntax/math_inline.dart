import 'characters.dart';

final class InlineMathMatch {
  const InlineMathMatch(
    this.end,
    this.bodyStart,
    this.bodyEnd,
    this.delimiter, {
    this.closed = true,
  });
  final int end;
  final int bodyStart;
  final int bodyEnd;
  final String delimiter;
  final bool closed;
}

bool _boundary(int c) => isSpace(c) || isPunctuation(c) || isCjk(c);
bool _bodyStart(int c) =>
    !isSpace(c) &&
    c != 36 &&
    !const {33, 34, 39, 41, 44, 46, 58, 59, 63, 93, 125}.contains(c) &&
    !(c > 127 && isPunctuation(c));
bool _adjacentStart(int c) =>
    c >= 65 && c <= 90 ||
    c >= 97 && c <= 122 ||
    c >= 48 && c <= 57 ||
    const {
      92,
      40,
      91,
      123,
      43,
      45,
      42,
      47,
      60,
      61,
      62,
      94,
      95,
      124,
    }.contains(c);

InlineMathMatch? readInlineMath(
  String text,
  int start, {
  int? end,
  bool adjacent = false,
  int maxLength = 512,
  bool allowOpen = false,
}) {
  final limit = end ?? text.length;
  final paren = text.startsWith(r'\(', start);
  if (!paren && text.codeUnitAt(start) != 36) return null;
  final bodyStart = start + (paren ? 2 : 1);
  if (bodyStart >= limit) return null;
  if (!paren) {
    final next = runeAt(text, bodyStart);
    if (!_bodyStart(next)) return null;
    final previous = runeBefore(text, start);
    if (previous == 36) {
      if (!adjacent || !_adjacentStart(next)) return null;
    } else if (!_boundary(previous)) {
      return null;
    }
  }
  final bound = bodyStart + maxLength < limit ? bodyStart + maxLength : limit;
  for (var i = bodyStart; i <= bound && i < limit; i++) {
    final c = text.codeUnitAt(i);
    if (c == 10 || c == 13) return null;
    if (paren && c == 92 && i + 1 < limit && text.codeUnitAt(i + 1) == 41) {
      var a = bodyStart;
      var b = i;
      while (a < b && isSpace(text.codeUnitAt(a))) a++;
      while (b > a && isSpace(text.codeUnitAt(b - 1))) b--;
      return a == b ? null : InlineMathMatch(i + 2, a, b, r'\(');
    }
    if (c == 92) {
      i++;
      continue;
    }
    if (!paren && c == 36) {
      if (i == bodyStart || isSpace(runeBefore(text, i))) return null;
      final after = i + 1 >= limit ? -1 : runeAt(text, i + 1);
      return after == 36 || _boundary(after)
          ? InlineMathMatch(i + 1, bodyStart, i, r'$')
          : null;
    }
  }
  if (allowOpen &&
      limit - bodyStart <= maxLength &&
      !text.substring(bodyStart, limit).contains(RegExp(r'[\r\n]'))) {
    var a = bodyStart;
    var b = limit;
    while (a < b && isSpace(text.codeUnitAt(a))) a++;
    while (b > a && isSpace(text.codeUnitAt(b - 1))) b--;
    if (b - a >= 2)
      return InlineMathMatch(limit, a, b, paren ? r'\(' : r'$', closed: false);
  }
  return null;
}
