/// A single source tag. Attribute values remain undecoded until inline parsing.
final class HtmlTag {
  HtmlTag(
    this.start,
    this.end,
    this.name,
    this.closing,
    this.selfClosing,
    Map<String, String> attributes,
  ) : attributes = Map.unmodifiable(attributes);
  final int start;
  final int end;
  final String name;
  final bool closing;
  final bool selfClosing;
  final Map<String, String> attributes;
}

final _tagName = RegExp(r'[A-Za-z][A-Za-z0-9-]*');
final _attribute = RegExp(
  r'''([A-Za-z_:][A-Za-z0-9_.:-]*)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?''',
);

HtmlTag? readHtmlTag(String source, int start, int end) {
  if (start >= end || source.codeUnitAt(start) != 60) return null;
  var i = start + 1;
  final closing = i < end && source.codeUnitAt(i) == 47;
  if (closing) i++;
  final name = _tagName.matchAsPrefix(source, i);
  if (name == null || name.end > end) return null;
  i = name.end;
  final attributes = <String, String>{};
  while (i < end) {
    final beforeSpace = i;
    while (i < end && _whitespace(source.codeUnitAt(i))) i++;
    if (i < end && source.codeUnitAt(i) == 62)
      return HtmlTag(
        start,
        i + 1,
        name[0]!.toLowerCase(),
        closing,
        false,
        attributes,
      );
    if (!closing && i + 1 < end && source.startsWith('/>', i))
      return HtmlTag(
        start,
        i + 2,
        name[0]!.toLowerCase(),
        false,
        true,
        attributes,
      );
    if (closing || i == beforeSpace) return null;
    final attr = _attribute.matchAsPrefix(source, i);
    if (attr == null || attr.end > end) return null;
    attributes.putIfAbsent(
      attr[1]!.toLowerCase(),
      () => attr[2] ?? attr[3] ?? attr[4] ?? '',
    );
    i = attr.end;
  }
  return null;
}

bool _whitespace(int c) => c == 32 || c == 9 || c == 10 || c == 13 || c == 12;

HtmlTag? findHtmlTag(
  String source,
  int start,
  int end,
  String name, {
  bool? closing,
}) {
  for (var i = start; i < end; i++) {
    final char = source.codeUnitAt(i);
    if (char == 92) {
      i++;
      continue;
    }
    if (char == 96) {
      var length = 1;
      while (i + length < end && source.codeUnitAt(i + length) == 96) length++;
      var next = i + length;
      while (next < end) {
        if (source.codeUnitAt(next) != 96) {
          next++;
          continue;
        }
        var run = 1;
        while (next + run < end && source.codeUnitAt(next + run) == 96) run++;
        if (run == length) {
          i = next + run - 1;
          break;
        }
        next += run;
      }
      continue;
    }
    if (char != 60) continue;
    final tag = readHtmlTag(source, i, end);
    if (tag != null &&
        (closing == null || tag.closing == closing) &&
        tag.name == name)
      return tag;
  }
  return null;
}
