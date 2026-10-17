import '../ast/nodes.dart';
import 'common.dart';

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
          .map((n) => separatedCell(output[n]!, '\t'))
          .join('\t');
    if (const {
      'table',
      'thead',
      'tbody',
      'tfoot',
      'ul',
      'ol',
    }.contains(node.tag))
      return joinChildren(node, output, '\n');
    if (node.tag == 'li') return '- ${joinChildren(node, output)}';
  }
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
