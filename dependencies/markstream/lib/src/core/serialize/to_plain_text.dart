import '../ast/nodes.dart';
import 'common.dart';
import '../html/html_fragment.dart' show htmlBlockTags;

/// Structural clipboard text. Generated separators do not define selection offsets.
String toPlainText(MarkdownNode root) => serializeNodes(root, (node, output) {
  if (node is TextNode) return node.text;
  if (node is LineBreakNode) return '\n';
  if (node is ReferenceDefinitionNode) return '';
  if (node is CodeSpanNode) return node.code;
  if (node is CodeBlockNode)
    return node.code.endsWith('\n')
        ? node.code.substring(0, node.code.length - 1)
        : node.code;
  if (node is MathInlineNode)
    return mathSource(
      node.tex,
      node.delimiter,
      block: false,
      closed: node.closed,
    );
  if (node is MathBlockNode)
    return mathSource(
      node.tex,
      node.delimiter,
      block: true,
      closed: node.closed,
    );
  if (node is ThematicBreakNode) return '---';
  if (node is TableNode)
    return node.children
        .map(
          (row) => row.children
              .map((cell) => separatedCell(output[cell]!, '\t'))
              .join('\t'),
        )
        .join('\n');
  if (node is TableRowNode)
    return node.children
        .map((cell) => separatedCell(output[cell]!, '\t'))
        .join('\t');
  if (node is ListNode)
    return [
      for (var i = 0; i < node.children.length; i++)
        indentLines(
          '${taskMarker(node.children[i])}${joinChildren(node.children[i], output, node.tight ? '\n' : '\n\n')}',
          node.ordered ? '${node.start + i}. ' : '- ',
          '  ',
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
    return '${node.radio ? '(' : '['}${node.checked ? 'x' : ' '}${node.radio ? ')' : ']'} ${joinChildren(node, output)}';
  if (node is HtmlBlockNode && node.fullDocument)
    return node.raw.endsWith('\n')
        ? node.raw.substring(0, node.raw.length - 1)
        : node.raw;
  if (node is HtmlElementNode) {
    if (node.tag == 'br') return '\n';
    if (node.tag == 'img') return node.attributes['alt'] ?? '';
    if (node.tag == 'hr') return '---';
    if (node.tag == 'tr')
      return node.children
          .whereType<HtmlElementNode>()
          .where((n) => n.tag == 'td' || n.tag == 'th')
          .map((n) => separatedCell(output[n]!, '\t'))
          .join('\t');
    if (const {'table', 'thead', 'tbody', 'tfoot'}.contains(node.tag))
      return node.children
          .whereType<HtmlElementNode>()
          .map((child) => output[child]!)
          .join('\n');
    if (node.tag == 'ul' || node.tag == 'ol') {
      final items = node.children
          .whereType<HtmlElementNode>()
          .where((n) => n.tag == 'li')
          .toList();
      final start = int.tryParse(node.attributes['start'] ?? '') ?? 1;
      return [
        for (var i = 0; i < items.length; i++)
          indentLines(
            output[items[i]]!,
            node.tag == 'ol' ? '${start + i}. ' : '- ',
            '  ',
          ),
      ].join('\n');
    }
    if (node.tag != 'pre' && htmlBlockTags.contains(node.tag))
      return _htmlFlow(node.children, output);
  }
  if (node is HtmlBlockNode) return _htmlFlow(node.children, output);
  if (node is DocumentNode ||
      node is BlockQuoteNode ||
      node is DetailsNode ||
      node is NamedBlockNode)
    return joinChildren(node, output, '\n\n');
  return joinChildren(node, output);
})[root]!;

String tableToCsv(TableNode table) => table.children
    .map(
      (row) => row.children
          .map((cell) => separatedCell(toPlainText(cell), ','))
          .join(','),
    )
    .join('\r\n');

String _htmlFlow(List<InlineNode> nodes, Map<MarkdownNode, String> output) {
  final result = StringBuffer();
  var previousBlock = false;
  final hasBlocks = nodes.any(
    (node) => node is HtmlElementNode && htmlBlockTags.contains(node.tag),
  );
  for (final node in nodes) {
    final block = node is HtmlElementNode && htmlBlockTags.contains(node.tag);
    final text = output[node]!;
    if (text.trim().isEmpty && hasBlocks) continue;
    if (result.isNotEmpty && (block || previousBlock)) result.write('\n\n');
    result.write(text);
    previousBlock = block;
  }
  return result.toString();
}
