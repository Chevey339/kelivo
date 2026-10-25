import '../ast/nodes.dart';
import '../parser/mapped_text.dart';
import 'named_entities.dart';

final _entity = RegExp(
  r'&(?:#([0-9]{1,7})|#[xX]([0-9a-fA-F]{1,6})|([A-Za-z][A-Za-z0-9]{1,31}));',
);
final _escape = RegExp(r'\\([!"#$%&\x27()*+,\-./:;<=>?@\[\]\\^_`{|}~])');

({int end, String text})? readEntity(String text, int start) {
  final match = _entity.matchAsPrefix(text, start);
  if (match == null) return null;
  if (match[3] case final name?) {
    final value = namedEntities[name];
    return value == null ? null : (end: match.end, text: value);
  }
  final code = match[1] != null
      ? int.parse(match[1]!)
      : int.parse(match[2]!, radix: 16);
  return (
    end: match.end,
    text: String.fromCharCode(
      code == 0 || code > 0x10FFFF || code >= 0xD800 && code <= 0xDFFF
          ? 0xFFFD
          : code,
    ),
  );
}

String decodeEntities(String text) => text.replaceAllMapped(
  _entity,
  (match) => readEntity(text, match.start)?.text ?? match[0]!,
);
String decodeMarkdownString(String text, {bool entities = true}) {
  final result = StringBuffer();
  var run = 0;
  var i = 0;
  while (i < text.length) {
    final escape = text.codeUnitAt(i) == 92
        ? _escape.matchAsPrefix(text, i)
        : null;
    final entity = entities && text.codeUnitAt(i) == 38
        ? readEntity(text, i)
        : null;
    if (escape != null || entity != null) {
      result.write(text.substring(run, i));
      result.write(escape != null ? escape[1] : entity!.text);
      i = escape?.end ?? entity!.end;
      run = i;
    } else {
      i++;
    }
  }
  result.write(text.substring(run));
  return result.toString();
}

List<TextNode> decodeHtmlText(List<TextNode> fragments) {
  final input = MappedText(fragments);
  final result = <TextNode>[];
  var cursor = 0;
  for (final match in _entity.allMatches(input.text)) {
    final entity = readEntity(input.text, match.start);
    if (entity == null) continue;
    result.addAll(input.slice(cursor, match.start));
    result.add(
      TextNode(span: input.span(match.start, entity.end), text: entity.text),
    );
    cursor = entity.end;
  }
  result.addAll(input.slice(cursor, input.text.length));
  return result;
}
