import '../ast/nodes.dart';
import 'common.dart';

String _escape(String text) {
  final result = StringBuffer();
  for (final code in text.runes) {
    final char = String.fromCharCode(code);
    if (code == 38) {
      result.write('&amp;');
    } else if (const {40, 41, 91, 93}.contains(code)) {
      result.write('&#$code;');
    } else if (r'\`*_{}<>#+.!|~:$-='.contains(char)) {
      result.write('\\$char');
    } else {
      result.write(char);
    }
  }
  return result.toString();
}

String _destination(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('\\', '\\\\')
    .replaceAll('<', r'\<')
    .replaceAll('>', r'\>');
String _title(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('\\', '\\\\')
    .replaceAll('"', r'\"');
String _attributes(Map<String, String> attributes) => attributes.isEmpty
    ? ''
    : '{${attributes.entries.map((e) => '${e.key}="${e.value.replaceAll('&', '&amp;').replaceAll('\\', '\\\\').replaceAll('"', '&quot;')}"').join(' ')}}';
String _code(String text, {bool table = false}) {
  if (text.isEmpty) return '';
  final longest = RegExp(r'`+')
      .allMatches(text)
      .fold(
        0,
        (length, match) =>
            match[0]!.length > length ? match[0]!.length : length,
      );
  final marker = '`' * (longest + 1);
  final pad =
      text.startsWith('`') ||
          text.endsWith('`') ||
          text.startsWith(' ') && text.endsWith(' ') && text.trim().isNotEmpty
      ? ' '
      : '';
  return '$marker$pad${table ? text.replaceAll('|', r'\|') : text}$pad$marker';
}

/// Canonical Markdown. [source] preserves app-specific extension spellings.
String toMarkdown(MarkdownNode root, {String? source}) {
  final original = source ?? (root is DocumentNode ? root.source : null);
  final tableDescendants = <MarkdownNode>{};
  final scan = <(MarkdownNode, bool)>[(root, false)];
  while (scan.isNotEmpty) {
    final (node, inside) = scan.removeLast();
    if (inside) tableDescendants.add(node);
    for (final child in node.children)
      scan.add((child, inside || node is TableNode));
  }
  return serializeNodes(root, (node, output) {
    final body = joinChildren(node, output);
    if (node is TextNode) {
      final escaped = _escape(node.text);
      return tableDescendants.contains(node)
          ? escaped.replaceAll(RegExp(r'\r\n|\r|\n'), '<br>')
          : escaped;
    }
    if (node is LineBreakNode)
      return tableDescendants.contains(node)
          ? '<br>'
          : node.hard
          ? '  \n'
          : '\n';
    if (node is EmphasisNode) {
      final marker = node.marker * (node.strong ? 2 : 1);
      return '$marker$body$marker';
    }
    if (node is StrikethroughNode) return '~~$body~~';
    if (node is HighlightNode) return '==$body==';
    if (node is CodeSpanNode)
      return _code(node.code, table: tableDescendants.contains(node));
    if (node is MathInlineNode)
      return mathSource(node.tex, node.delimiter, block: false);
    if (node is MathBlockNode)
      return mathSource(node.tex, node.delimiter, block: true);
    if (node is LinkNode || node is ImageNode) {
      final destination = node is LinkNode
          ? node.destination
          : (node as ImageNode).destination;
      final title = node is LinkNode ? node.title : (node as ImageNode).title;
      final escaped = _destination(destination);
      final suffix = title == null ? '' : ' "${_title(title)}"';
      return '${node is ImageNode ? '!' : ''}[$body](<$escaped>$suffix)';
    }
    if (node is HeadingNode) return '${'#' * node.level} $body';
    if (node is ThematicBreakNode) return '---';
    if (node is CodeBlockNode || node is HtmlBlockNode && node.fullDocument) {
      final code = node is CodeBlockNode
          ? node.code
          : (node as HtmlBlockNode).raw;
      final info = node is CodeBlockNode ? node.info : 'html';
      final char = info.contains('`') ? '~' : '`';
      final length =
          RegExp('${RegExp.escape(char)}+')
              .allMatches(code)
              .fold(2, (n, m) => m[0]!.length > n ? m[0]!.length : n) +
          1;
      final fence = char * length;
      return '$fence${info.replaceAll('&', '&amp;').replaceAll('\\', '\\\\')}\n$code${code.isEmpty || code.endsWith('\n') ? '' : '\n'}$fence';
    }
    if (node is BlockQuoteNode)
      return indentLines(joinChildren(node, output, '\n\n'), '> ');
    if (node is ListNode)
      return [
        for (var i = 0; i < node.children.length; i++)
          indentLines(
            '${taskMarker(node.children[i])}${joinChildren(node.children[i], output, node.tight ? '\n' : '\n\n')}',
            node.ordered
                ? '${node.start + i}${node.delimiter} '
                : '${node.marker} ',
            ' ' *
                (node.ordered
                    ? '${node.start + i}${node.delimiter} '.length
                    : 2),
          ),
      ].join(node.tight ? '\n' : '\n\n');
    if (node is ListItemNode) {
      final marker = node.checked == null
          ? ''
          : node.radio
          ? '(${node.checked! ? 'x' : ' '}) '
          : '[${node.checked! ? 'x' : ' '}] ';
      return '$marker${joinChildren(node, output, '\n\n')}';
    }
    if (node is TaskItemNode)
      return '${node.radio ? '(' : '['}${node.checked ? 'x' : ' '}${node.radio ? ')' : ']'} $body';
    if (node is TableNode) {
      final rows = node.children
          .map(
            (row) =>
                '| ${row.children.map((cell) => output[cell]!).join(' | ')} |',
          )
          .toList();
      final delimiter =
          '| ${node.alignments.map((a) => switch (a) {
            TableAlignment.left => ':---',
            TableAlignment.center => ':---:',
            TableAlignment.right => '---:',
            TableAlignment.none => '---',
          }).join(' | ')} |';
      return [
        if (rows.isNotEmpty) rows.first,
        delimiter,
        ...rows.skip(1),
      ].join('\n');
    }
    if (node is DetailsSummaryNode) return '<summary>$body</summary>';
    if (node is DetailsNode)
      return '<details${node.open ? ' open' : ''}>\n${joinChildren(node, output, '\n\n')}\n</details>';
    if (node is NamedBlockNode) {
      if (node.syntax == NamedBlockSyntax.alert)
        return '> [!${node.name.toUpperCase()}]${node.attributes['title'] == null ? '' : ' ${_escape(node.attributes['title']!)}'}\n${indentLines(joinChildren(node, output, '\n\n'), '> ')}';
      final label =
          node.children.isNotEmpty && node.children.first is DirectiveLabelNode
          ? '[${output[node.children.first]}]'
          : '';
      final children = node.children
          .where((n) => n is! DirectiveLabelNode)
          .map((n) => output[n]!)
          .join('\n\n');
      if (node.syntax == NamedBlockSyntax.leafDirective)
        return '::${node.name}$label${_attributes(node.attributes)}';
      final length =
          RegExp(r'^:+', multiLine: true)
              .allMatches(children)
              .fold(2, (n, m) => m[0]!.length > n ? m[0]!.length : n) +
          1;
      final marker = ':' * length;
      return '$marker${node.name}$label${_attributes(node.attributes)}\n$children\n$marker';
    }
    if (node is NamedInlineNode) {
      if (node.syntax == NamedInlineSyntax.extension &&
          original != null &&
          node.span.end <= original.length)
        return node.span.slice(original);
      return ':${node.name}[$body]${_attributes(node.attributes)}';
    }
    if (node is ReferenceDefinitionNode)
      return '[${node.label}]: <${_destination(node.destination)}>${node.title == null ? '' : ' "${_title(node.title!)}"'}';
    if (node is HtmlElementNode) {
      final attrs = node.attributes.entries
          .map(
            (e) =>
                ' ${e.key}="${e.value.replaceAll('&', '&amp;').replaceAll('"', '&quot;')}"',
          )
          .join();
      final htmlBody = node.children
          .map(
            (child) => child is TextNode
                ? child.text.replaceAll('&', '&amp;').replaceAll('<', '&lt;')
                : output[child]!,
          )
          .join();
      return '<${node.tag}$attrs>${const {'br', 'img', 'hr'}.contains(node.tag) ? '' : '$htmlBody</${node.tag}>'}';
    }
    if (node is DocumentNode) return joinChildren(node, output, '\n\n');
    return body;
  })[root]!;
}
