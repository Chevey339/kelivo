import '../../ast/nodes.dart';
import '../inline_parser.dart';
import '../mapped_text.dart';
import 'characters.dart';
import 'link_destination.dart';

({int end, ReferenceDefinitionNode node})? readReferenceDefinition(
  MappedText input,
  int start, {
  bool entities = true,
}) {
  final text = input.text;
  var i = start;
  var spaces = 0;
  while (i < text.length && text.codeUnitAt(i) == 32 && spaces < 4) {
    i++;
    spaces++;
  }
  if (spaces > 3 || i >= text.length || text.codeUnitAt(i) != 91) return null;
  final beginning = ++i;
  while (i < text.length && i - beginning <= 999) {
    final c = text.codeUnitAt(i);
    if (c == 92 &&
        i + 1 < text.length &&
        isAsciiPunctuation(text.codeUnitAt(i + 1))) {
      i += 2;
      continue;
    }
    if (c == 91) return null;
    if (c == 93) break;
    i++;
  }
  if (i >= text.length ||
      i - beginning > 999 ||
      i + 1 >= text.length ||
      !text.startsWith(']:', i))
    return null;
  final label = text.substring(beginning, i);
  if (normalizeReferenceLabel(label).isEmpty) return null;
  i += 2;
  while (i < text.length && isSpace(text.codeUnitAt(i))) i++;
  final destination = readDestination(text, i, entities: entities);
  if (destination == null ||
      destination.end == i && destination.destination.isEmpty)
    return null;
  i = destination.end;
  final destinationEnd = i;
  while (i < text.length &&
      (text.codeUnitAt(i) == 32 || text.codeUnitAt(i) == 9))
    i++;
  final lineEnd = i;
  if (i < text.length && text.codeUnitAt(i) == 10) {
    i++;
    while (i < text.length &&
        (text.codeUnitAt(i) == 32 || text.codeUnitAt(i) == 9))
      i++;
  }
  final title = i > destinationEnd
      ? readLinkTitle(text, i, entities: entities)
      : null;
  String? titleText;
  if (title != null) {
    var end = title.end;
    while (end < text.length &&
        (text.codeUnitAt(end) == 32 || text.codeUnitAt(end) == 9))
      end++;
    if (end == text.length || text.codeUnitAt(end) == 10) {
      i = end;
      titleText = title.title;
    } else {
      i = lineEnd;
    }
  } else {
    i = lineEnd;
  }
  if (i < text.length && text.codeUnitAt(i) != 10) return null;
  final span = input.span(start, i);
  if (i < text.length) i++;
  return (
    end: i,
    node: ReferenceDefinitionNode(
      span: span,
      label: label,
      destination: destination.destination,
      title: titleText,
    ),
  );
}
