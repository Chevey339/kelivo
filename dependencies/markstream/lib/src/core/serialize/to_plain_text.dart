import '../ast/nodes.dart';
import '../ast/source_span.dart';
import '../text_index/text_index.dart';
import 'common.dart';
import '../html/html_fragment.dart' show htmlBlockTags;

/// Structural clipboard text. Generated separators do not define selection offsets.
String toPlainText(MarkdownNode root) => _plainText(root, false).text;

/// The same serialization with provenance for every emitted UTF-16 unit.
/// List markers, table escaping and block separators use the same rendering
/// path as [toPlainText], so a plain-text selection can return to its source.
TextIndex plainTextIndex(MarkdownNode root) =>
    TextIndex.fromSegments(_plainText(root, true).segments!);

_PlainText _plainText(MarkdownNode root, bool track) {
  final writer = _PlainWriter(track);
  return serializeNodes<_PlainText>(root, (node, output) {
    _PlainText children([String separator = '']) => writer.join(
      node.children
          .map((child) => output[child]!)
          .where((part) => part.text.isNotEmpty),
      separator,
      node,
    );
    _PlainText literal(String value) => writer.source(value, node);
    _PlainText code() {
      final value = children();
      return value.text.endsWith('\n')
          ? value.slice(0, value.text.length - 1)
          : value;
    }

    if (node is TextNode) return literal(node.text);
    if (node is LineBreakNode) return literal('\n');
    if (node is ReferenceDefinitionNode) return literal('');
    if (node is CodeSpanNode) return children();
    if (node is CodeBlockNode) return code();
    if (node is MathInlineNode)
      return literal(
        mathSource(node.tex, node.delimiter, block: false, closed: node.closed),
      );
    if (node is MathBlockNode)
      return literal(
        mathSource(node.tex, node.delimiter, block: true, closed: node.closed),
      );
    if (node is ThematicBreakNode) return literal('---');
    _PlainText row(List<MarkdownNode> cells) => writer.join(
      cells.map((cell) => writer.cell(output[cell]!, '\t', cell)),
      '\t',
      node,
    );
    if (node is TableNode) {
      return writer.join(
        node.children.map((child) => row(child.children)),
        '\n',
        node,
      );
    }
    if (node is TableRowNode) return row(node.children);
    if (node is ListNode) {
      return writer.join(
        [
          for (var i = 0; i < node.children.length; i++)
            writer.indent(
              writer.join(
                [
                  writer.generated(
                    taskMarker(node.children[i]),
                    node.children[i],
                  ),
                  writer.join(
                    node.children[i].children
                        .map((child) => output[child]!)
                        .where((part) => part.text.isNotEmpty),
                    node.tight ? '\n' : '\n\n',
                    node.children[i],
                  ),
                ],
                '',
                node.children[i],
              ),
              node.ordered ? '${node.start + i}. ' : '- ',
              '  ',
              node.children[i],
            ),
        ],
        node.tight ? '\n' : '\n\n',
        node,
      );
    }
    if (node is ListItemNode) {
      final marker = node.checked == null
          ? ''
          : node.radio
          ? '(${node.checked! ? 'x' : ' '}) '
          : '[${node.checked! ? 'x' : ' '}] ';
      return writer.join(
        [writer.generated(marker, node), children('\n\n')],
        '',
        node,
      );
    }
    if (node is TaskItemNode) {
      return writer.join(
        [
          writer.generated(
            '${node.radio ? '(' : '['}${node.checked ? 'x' : ' '}${node.radio ? ')' : ']'} ',
            node,
          ),
          children(),
        ],
        '',
        node,
      );
    }
    if (node is HtmlBlockNode && node.fullDocument) {
      final value = writer.join(
        node.rawFragments.map((part) => writer.source(part.text, part)),
        '',
        node,
      );
      return value.text.endsWith('\n')
          ? value.slice(0, value.text.length - 1)
          : value;
    }
    if (node is HtmlElementNode) {
      if (node.tag == 'br') return literal('\n');
      if (node.tag == 'img') return literal(node.attributes['alt'] ?? '');
      if (node.tag == 'hr') return literal('---');
      if (node.tag == 'tr') {
        return row(
          node.children
              .whereType<HtmlElementNode>()
              .where((child) => child.tag == 'td' || child.tag == 'th')
              .toList(),
        );
      }
      if (const {'table', 'thead', 'tbody', 'tfoot'}.contains(node.tag)) {
        return writer.join(
          node.children.whereType<HtmlElementNode>().map(
            (child) => output[child]!,
          ),
          '\n',
          node,
        );
      }
      if (node.tag == 'ul' || node.tag == 'ol') {
        final items = node.children
            .whereType<HtmlElementNode>()
            .where((child) => child.tag == 'li')
            .toList();
        final start = int.tryParse(node.attributes['start'] ?? '') ?? 1;
        return writer.join(
          [
            for (var i = 0; i < items.length; i++)
              writer.indent(
                output[items[i]]!,
                node.tag == 'ol' ? '${start + i}. ' : '- ',
                '  ',
                items[i],
              ),
          ],
          '\n',
          node,
        );
      }
      if (node.tag != 'pre' && htmlBlockTags.contains(node.tag))
        return writer.htmlFlow(node, output);
    }
    if (node is HtmlBlockNode) return writer.htmlFlow(node, output);
    if (node is DocumentNode ||
        node is BlockQuoteNode ||
        node is DetailsNode ||
        node is NamedBlockNode)
      return children('\n\n');
    return children();
  })[root]!;
}

class _PlainText {
  _PlainText(this.text, this.segments);
  final String text;
  final List<TextSegment>? segments;
  late final TextIndex? index = segments == null
      ? null
      : TextIndex.fromSegments(segments!);
  _PlainText slice(int start, int end) => _PlainText(
    text.substring(start, end),
    index?.segmentsForRange(start, end),
  );
  _PlainText escapeQuotes() {
    if (!text.contains('"')) return this;
    if (segments == null) return _PlainText(text.replaceAll('"', '""'), null);
    final mapped = <TextSegment>[];
    var start = 0;
    for (final match in '"'.allMatches(text)) {
      mapped.addAll(index!.segmentsForRange(start, match.start));
      mapped.add(
        TextSegment(
          text: '""',
          sourceSpan: index!.sourceSpanForRange(match.start, match.end),
        ),
      );
      start = match.end;
    }
    mapped.addAll(index!.segmentsForRange(start, text.length));
    return _PlainText(text.replaceAll('"', '""'), mapped);
  }
}

class _PlainWriter {
  const _PlainWriter(this.track);
  final bool track;
  _PlainText source(String text, MarkdownNode node) => _PlainText(
    text,
    track ? [TextSegment(text: text, sourceSpan: node.span, node: node)] : null,
  );
  _PlainText generated(String text, MarkdownNode node) => _PlainText(
    text,
    track
        ? [
            TextSegment(
              text: text,
              sourceSpan: SourceSpan(node.span.start, node.span.start),
            ),
          ]
        : null,
  );
  _PlainText join(
    Iterable<_PlainText> values,
    String separator,
    MarkdownNode node,
  ) {
    final text = StringBuffer();
    final segments = track ? <TextSegment>[] : null;
    var first = true;
    for (final value in values) {
      if (!first) {
        text.write(separator);
        segments?.addAll(generated(separator, node).segments!);
      }
      first = false;
      text.write(value.text);
      segments?.addAll(value.segments!);
    }
    return _PlainText(text.toString(), segments);
  }

  _PlainText indent(
    _PlainText value,
    String prefix,
    String continuation,
    MarkdownNode node,
  ) {
    var start = 0;
    final lines = <_PlainText>[];
    for (final line in value.text.split('\n')) {
      lines.add(
        join(
          [
            generated(lines.isEmpty ? prefix : continuation, node),
            value.slice(start, start + line.length),
          ],
          '',
          node,
        ),
      );
      start += line.length + 1;
    }
    return join(lines, '\n', node);
  }

  _PlainText cell(_PlainText value, String separator, MarkdownNode node) =>
      value.text.contains(separator) ||
          value.text.contains('\n') ||
          value.text.contains('\r') ||
          value.text.contains('"')
      ? join(
          [generated('"', node), value.escapeQuotes(), generated('"', node)],
          '',
          node,
        )
      : value;
  _PlainText htmlFlow(
    MarkdownNode parent,
    Map<MarkdownNode, _PlainText> output,
  ) {
    final values = <_PlainText>[];
    var previousBlock = false, hasText = false;
    final hasBlocks = parent.children.any(
      (node) => node is HtmlElementNode && htmlBlockTags.contains(node.tag),
    );
    for (final node in parent.children) {
      final block = node is HtmlElementNode && htmlBlockTags.contains(node.tag);
      final text = output[node]!;
      if (text.text.trim().isEmpty && hasBlocks) continue;
      if (hasText && (block || previousBlock))
        values.add(generated('\n\n', node));
      values.add(text);
      hasText = hasText || text.text.isNotEmpty;
      previousBlock = block;
    }
    return join(values, '', parent);
  }
}

String tableToCsv(TableNode table) => table.children
    .map(
      (row) => row.children
          .map((cell) => separatedCell(toPlainText(cell), ','))
          .join(','),
    )
    .join('\r\n');
