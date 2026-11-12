final _unicodePunctuation = RegExp(r'^[\p{P}\p{S}]$', unicode: true);
final _unicodeSpace = RegExp(r'^\s$', unicode: true);

bool isAsciiPunctuation(int c) =>
    c >= 33 && c <= 47 ||
    c >= 58 && c <= 64 ||
    c >= 91 && c <= 96 ||
    c >= 123 && c <= 126;
bool isSpace(int c) =>
    c == -1 || c >= 0 && _unicodeSpace.hasMatch(String.fromCharCode(c));
bool isPunctuation(int c) =>
    c >= 0 &&
    (isAsciiPunctuation(c) ||
        _unicodePunctuation.hasMatch(String.fromCharCode(c)));
bool isCjk(int c) =>
    c >= 0x2E80 && c <= 0x9FFF ||
    c >= 0xAC00 && c <= 0xD7AF ||
    c >= 0xF900 && c <= 0xFAFF ||
    c >= 0x20000 && c <= 0x323AF;

int runeAt(String text, int offset) {
  if (offset < 0 || offset >= text.length) return -1;
  final first = text.codeUnitAt(offset);
  if (first >= 0xD800 && first <= 0xDBFF && offset + 1 < text.length) {
    final second = text.codeUnitAt(offset + 1);
    if (second >= 0xDC00 && second <= 0xDFFF)
      return 0x10000 + ((first - 0xD800) << 10) + second - 0xDC00;
  }
  return first;
}

int runeBefore(String text, int offset) {
  if (offset <= 0) return -1;
  final last = text.codeUnitAt(offset - 1);
  return last >= 0xDC00 && last <= 0xDFFF && offset >= 2
      ? runeAt(text, offset - 2)
      : last;
}
