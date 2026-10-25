import 'package:markstream/markstream_core.dart';

/// Image destinations as rendered in message Markdown, excluding code samples.
Iterable<String> markdownImageSources(String source) sync* {
  final pending = <MarkdownNode>[
    MarkdownParser(
      inlineSyntaxes: const [LocalImagePathSyntax()],
    ).parse(source),
  ];
  while (pending.isNotEmpty) {
    final node = pending.removeLast();
    if (node is ImageNode) {
      yield node.destination;
    } else if (node is HtmlElementNode && node.tag == 'img') {
      final source = node.attributes['src'];
      if (source != null && isSafeHtmlUrl(source, image: true)) yield source;
    }
    pending.addAll(node.children.reversed);
  }
}

/// Local paths with spaces are parsed directly, without changing source spans.
/// Standard links, escaped labels and URL/title parsing remain in the core.
class LocalImagePathSyntax extends InlineSyntax {
  const LocalImagePathSyntax();
  static final _local = RegExp(r'^(?:/|file://|[A-Za-z]:[\\/])');
  @override
  Set<int> get startCharacters => const {33};
  @override
  InlineSyntaxMatch? match(InlineSyntaxContext context, int offset) {
    final text = context.text;
    if (!text.startsWith('![', offset)) return null;
    var closeLabel = offset + 2;
    while (closeLabel < text.length && text[closeLabel] != ']') {
      if (text[closeLabel] == '\n' || text[closeLabel] == '\r') return null;
      if (text[closeLabel] == '\\') closeLabel++;
      closeLabel++;
    }
    if (closeLabel >= text.length || !text.startsWith('](', closeLabel)) {
      return null;
    }
    final start = closeLabel + 2;
    var end = start, depth = 0;
    String? quote;
    while (end < text.length) {
      final c = text[end];
      if (c == '\n' || c == '\r') return null;
      if (quote != null) {
        if (c == '\\') {
          end += 2;
          continue;
        }
        if (c == quote) quote = null;
        end++;
        continue;
      }
      if ((c == '"' || c == "'") && end > start && text[end - 1] == ' ') {
        quote = c;
        end++;
        continue;
      }
      if (c == '(') depth++;
      if (c == ')') {
        if (depth == 0) break;
        depth--;
      }
      end++;
    }
    if (end >= text.length) return null;
    var destination = text.substring(start, end).trim();
    if (!_local.hasMatch(destination) || !destination.contains(' ')) {
      return null;
    }
    String? title;
    final titleMatch = RegExp(r'''\s+["'](.*)["']$''').firstMatch(destination);
    if (titleMatch != null) {
      title = titleMatch[1];
      destination = destination.substring(0, titleMatch.start).trimRight();
    }
    return InlineSyntaxMatch(
      end: end + 1,
      node: ImageNode(
        span: context.span(offset, end + 1),
        children: InlineParser(
          options: context.options,
        ).parseFragments(context.textNodes(offset + 2, closeLabel)),
        destination: destination,
        title: title,
      ),
    );
  }
}
