import '../../html/entities.dart';
import 'characters.dart';

({int end, String destination})? readDestination(
  String text,
  int start, {
  bool entities = true,
}) {
  if (start >= text.length) return null;
  var i = start;
  if (text.codeUnitAt(i) == 60) {
    final beginning = ++i;
    while (i < text.length) {
      final c = text.codeUnitAt(i);
      if (c == 10 || c == 60) return null;
      if (c == 62)
        return (
          end: i + 1,
          destination: decodeMarkdownString(
            text.substring(beginning, i),
            entities: entities,
          ),
        );
      if (c == 92 &&
          i + 1 < text.length &&
          isAsciiPunctuation(text.codeUnitAt(i + 1)))
        i++;
      i++;
    }
    return null;
  }
  var nesting = 0;
  while (i < text.length) {
    final c = text.codeUnitAt(i);
    if (c <= 32 || c == 127) break;
    if (c == 92 &&
        i + 1 < text.length &&
        isAsciiPunctuation(text.codeUnitAt(i + 1))) {
      i += 2;
      continue;
    }
    if (c == 40) nesting++;
    if (c == 41) {
      if (nesting == 0) break;
      nesting--;
    }
    i++;
  }
  if (nesting != 0) return null;
  return (
    end: i,
    destination: decodeMarkdownString(
      text.substring(start, i),
      entities: entities,
    ),
  );
}

({int end, String title})? readLinkTitle(
  String text,
  int start, {
  bool entities = true,
}) {
  if (start >= text.length) return null;
  final opener = text.codeUnitAt(start);
  if (opener != 34 && opener != 39 && opener != 40) return null;
  final closer = opener == 40 ? 41 : opener;
  var i = start + 1;
  while (i < text.length) {
    final c = text.codeUnitAt(i);
    if (c == closer)
      return (
        end: i + 1,
        title: decodeMarkdownString(
          text.substring(start + 1, i),
          entities: entities,
        ),
      );
    if (opener == 40 && c == 40 || text.startsWith('\n\n', i)) return null;
    if (c == 92 &&
        i + 1 < text.length &&
        isAsciiPunctuation(text.codeUnitAt(i + 1)))
      i++;
    i++;
  }
  return null;
}

({int end, String destination, String? title})? readInlineLink(
  String text,
  int start, {
  bool entities = true,
}) {
  if (start >= text.length || text.codeUnitAt(start) != 40) return null;
  var i = start + 1;
  while (i < text.length && isSpace(text.codeUnitAt(i))) i++;
  final destination = readDestination(text, i, entities: entities);
  if (destination == null) return null;
  i = destination.end;
  final afterDestination = i;
  while (i < text.length && isSpace(text.codeUnitAt(i))) i++;
  String? title;
  if (i > afterDestination) {
    final parsed = readLinkTitle(text, i, entities: entities);
    if (parsed != null) {
      title = parsed.title;
      i = parsed.end;
      while (i < text.length && isSpace(text.codeUnitAt(i))) i++;
    }
  }
  if (i >= text.length || text.codeUnitAt(i) != 41) return null;
  return (end: i + 1, destination: destination.destination, title: title);
}
