import '../ast/nodes.dart';
import 'entities.dart';
import '../parser/mapped_text.dart';
import '../parser/syntax/html_tag.dart';

const htmlBlockTags = {
  'details',
  'summary',
  'div',
  'p',
  'center',
  'table',
  'thead',
  'tbody',
  'tfoot',
  'tr',
  'td',
  'th',
  'ul',
  'ol',
  'li',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'blockquote',
  'pre',
  'hr',
};
const htmlInlineTags = {
  'b',
  'strong',
  'i',
  'em',
  'u',
  's',
  'del',
  'sub',
  'sup',
  'mark',
  'kbd',
  'code',
  'br',
  'span',
  'font',
  'a',
  'img',
};
const _voidTags = {
  'br',
  'hr',
  'img',
  'input',
  'meta',
  'link',
  'wbr',
  'source',
  'area',
  'base',
  'col',
  'embed',
  'param',
  'track',
};
const discardedHtmlTags = {'script', 'style', 'iframe'};

final class _Element {
  _Element(this.tag, this.start, this.attributes);
  final String tag;
  final int start;
  final Map<String, String> attributes;
  final children = <InlineNode>[];
}

/// Tokenizes a fragment without a browser, retaining only the native HTML subset.
/// Unknown shells disappear; raw script/style/iframe bodies disappear with them.
List<InlineNode> parseHtmlFragment(
  List<TextNode> fragments, {
  bool block = false,
  bool entities = true,
}) {
  final input = MappedText(fragments);
  final text = input.text;
  final lower = text.toLowerCase();
  final stack = <_Element>[_Element('', 0, const {})];
  void close(int end) {
    final element = stack.removeLast();
    if (htmlBlockTags.contains(element.tag) ||
        htmlInlineTags.contains(element.tag)) {
      stack.last.children.add(
        HtmlElementNode(
          span: input.span(element.start, end),
          tag: element.tag,
          children: element.children,
          attributes: element.attributes,
        ),
      );
    } else {
      stack.last.children.addAll(element.children);
    }
  }

  var run = 0;
  var i = 0;
  while (i < text.length) {
    if (text.codeUnitAt(i) != 60) {
      i++;
      continue;
    }
    final tag = readHtmlTag(text, i, text.length);
    final comment = text.startsWith('<!--', i);
    final declaration = text.startsWith('<!', i) || text.startsWith('<?', i);
    if (tag == null && !comment && !declaration) {
      i++;
      continue;
    }
    if (run < i)
      stack.last.children.addAll(
        entities ? decodeHtmlText(input.slice(run, i)) : input.slice(run, i),
      );
    if (comment || declaration) {
      final marker = comment ? '-->' : '>';
      final end = text.indexOf(marker, i + 2);
      i = end < 0 ? text.length : end + marker.length;
    } else if (tag!.closing) {
      final index = stack.lastIndexWhere((element) => element.tag == tag.name);
      if (index > 0) {
        while (stack.length > index + 1) close(i);
        close(tag.end);
      }
      i = tag.end;
    } else if (discardedHtmlTags.contains(tag.name)) {
      var end = lower.indexOf('</${tag.name}', tag.end);
      HtmlTag? closing;
      while (end >= 0) {
        closing = readHtmlTag(text, end, text.length);
        if (closing?.closing == true && closing?.name == tag.name) break;
        end = lower.indexOf('</${tag.name}', end + 2);
      }
      i = end < 0 ? text.length : closing!.end;
    } else {
      stack.add(_Element(tag.name, i, _attributes(tag, entities: entities)));
      i = tag.end;
      if (tag.selfClosing || _voidTags.contains(tag.name)) close(i);
    }
    run = i;
  }
  if (run < text.length)
    stack.last.children.addAll(
      entities
          ? decodeHtmlText(input.slice(run, text.length))
          : input.slice(run, text.length),
    );
  while (stack.length > 1) close(text.length);
  final result = stack.single.children;
  if (block) {
    while (result.isNotEmpty &&
        result.first is TextNode &&
        (result.first as TextNode).text.trim().isEmpty)
      result.removeAt(0);
    while (result.isNotEmpty &&
        result.last is TextNode &&
        (result.last as TextNode).text.trim().isEmpty)
      result.removeLast();
  }
  return List.unmodifiable(result);
}

Map<String, String> _attributes(HtmlTag tag, {required bool entities}) => {
  for (final entry in tag.attributes.entries)
    if (const {
          'title',
          'id',
          'class',
          'open',
          'start',
          'colspan',
          'rowspan',
          'align',
        }.contains(entry.key) ||
        tag.name == 'a' && entry.key == 'href' ||
        tag.name == 'img' &&
            const {'src', 'alt', 'width', 'height'}.contains(entry.key) ||
        tag.name == 'span' && entry.key == 'style' ||
        tag.name == 'font' && entry.key == 'color')
      entry.key: entities ? decodeEntities(entry.value) : entry.value,
};
