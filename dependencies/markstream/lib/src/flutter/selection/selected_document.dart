import '../../core/ast/nodes.dart';
import '../../core/ast/source_span.dart';
import '../../core/ast/transform.dart';
import '../../core/text_index/text_index.dart';
import '../../core/serialize/to_plain_text.dart';

/// Clips syntax using rendered fragments, preserving containers and destinations.
/// The visible set deliberately excludes unmounted folded/paginated content.
DocumentNode selectedDocument(
  DocumentNode document,
  List<TextSegment> selected, {
  required Set<MarkdownNode> visible,
  required Set<MarkdownNode> complete,
}) {
  final completeHtmlTables = complete
      .whereType<HtmlElementNode>()
      .where((node) => node.tag == 'table')
      .toList();
  final parts = <MarkdownNode, List<TextSegment>>{};
  for (final part in selected) {
    if (part.node != null) (parts[part.node!] ??= []).add(part);
  }
  final spans = selected
      .where((part) => !part.sourceSpan.isEmpty)
      .map((part) => part.sourceSpan)
      .toList();
  final envelope = spans.isEmpty
      ? null
      : SourceSpan(
          spans.map((s) => s.start).reduce((a, b) => a < b ? a : b),
          spans.map((s) => s.end).reduce((a, b) => a > b ? a : b),
        );
  final converted = <MarkdownNode, MarkdownNode?>{};
  final pending = <(MarkdownNode, bool)>[(document, false)];
  while (pending.isNotEmpty) {
    final (node, visited) = pending.removeLast();
    final children = node is HtmlBlockNode && node.fullDocument
        ? node.rawFragments
        : node.children;
    if (!visited) {
      pending.add((node, true));
      for (final child in children.reversed) pending.add((child, false));
      continue;
    }
    final fragments = parts[node];
    if (fragments != null) {
      converted[node] = node is TextNode
          ? TextNode(
              span: SourceSpan(
                fragments.first.sourceSpan.start,
                fragments.last.sourceSpan.end,
              ),
              text: fragments.map((part) => part.text).join(),
            )
          : node;
      continue;
    }
    if (node is ReferenceDefinitionNode) {
      converted[node] = null;
      continue;
    }
    final kept = children
        .map((child) => converted[child])
        .whereType<MarkdownNode>()
        .toList();
    if (node is TableNode) {
      final rows = node.children;
      final selectedRows = <int>[];
      for (var i = 0; i < rows.length; i++) {
        if (rows[i].children.any((cell) => converted[cell] != null) ||
            complete.contains(node) && rows[i].children.any(visible.contains))
          selectedRows.add(i);
      }
      if (selectedRows.isEmpty) {
        converted[node] = null;
        continue;
      }
      converted[node] = TableNode(
        span: node.span,
        alignments: node.alignments,
        provisional: node.provisional,
        children: [
          for (var i = selectedRows.first; i <= selectedRows.last; i++)
            TableRowNode(
              span: rows[i].span,
              header: i == selectedRows.first,
              children: [
                for (final cell in rows[i].children)
                  converted[cell] as TableCellNode? ??
                      TableCellNode(span: cell.span, children: []),
              ],
            ),
        ],
      );
      continue;
    }
    if (node is HtmlElementNode &&
        node.tag == 'tr' &&
        (kept.isNotEmpty ||
            node.children.any(visible.contains) &&
                completeHtmlTables.any(
                  (table) =>
                      table.span.start <= node.span.start &&
                      table.span.end >= node.span.end,
                ))) {
      converted[node] = replaceChildren(node, [
        for (final child in node.children.whereType<HtmlElementNode>())
          if (child.tag == 'td' || child.tag == 'th')
            converted[child] ?? replaceChildren(child, []),
      ]);
      continue;
    }
    if (node is HtmlElementNode && node.tag == 'ol' && kept.isNotEmpty) {
      final items = node.children
          .whereType<HtmlElementNode>()
          .where((n) => n.tag == 'li')
          .toList();
      final first = items.indexWhere((child) => converted[child] != null);
      converted[node] = HtmlElementNode(
        span: node.span,
        tag: node.tag,
        attributes: {
          ...node.attributes,
          'start':
              '${(int.tryParse(node.attributes['start'] ?? '') ?? 1) + (first < 0 ? 0 : first)}',
        },
        children: kept.cast<InlineNode>(),
      );
      continue;
    }
    if (kept.isEmpty && node is! DocumentNode) {
      final inside =
          envelope != null &&
          envelope.start <= node.span.start &&
          envelope.end >= node.span.end;
      converted[node] =
          inside &&
              visible.contains(node) &&
              (node is ThematicBreakNode ||
                  node is CodeBlockNode && node.code.trim().isEmpty ||
                  node is ImageNode ||
                  node is HtmlElementNode &&
                      const {
                        'td',
                        'th',
                        'tr',
                        'img',
                        'hr',
                        'br',
                      }.contains(node.tag))
          ? node
          : null;
      continue;
    }
    if (node is NamedInlineNode && node.syntax == NamedInlineSyntax.extension) {
      // Only an explicit atomic projection may retain an extension's original
      // spelling. A default text rendering can have a partial label selected.
      converted[node] = TextNode(
        span: node.span,
        text: kept.map(toPlainText).join(),
      );
    } else if (node is HtmlBlockNode && node.fullDocument) {
      converted[node] = HtmlBlockNode(
        span: node.span,
        children: [],
        rawFragments: kept.cast<TextNode>(),
        fullDocument: true,
        closed: node.closed,
      );
    } else if (node is ListNode) {
      final first = node.children.indexWhere(
        (child) => converted[child] != null,
      );
      converted[node] = ListNode(
        span: node.span,
        children: kept.cast<ListItemNode>(),
        ordered: node.ordered,
        start: node.start + (first < 0 ? 0 : first),
        marker: node.marker,
        delimiter: node.delimiter,
        tight: node.tight,
      );
    } else {
      converted[node] = replaceChildren(node, kept);
    }
  }
  return converted[document]! as DocumentNode;
}
