import '../ast/nodes.dart';
import '../ast/source_span.dart';
import '../ast/transform.dart';
import '../html/entities.dart';
import 'block_parser.dart';
import 'dialect.dart';
import 'inline_parser.dart';
import 'mapped_text.dart';
import 'syntax/reference_definition.dart';
import 'syntax/inline_syntax.dart';

/// Two-phase block and inline parsing. References resolve across the document.
final class MarkdownParser {
  const MarkdownParser({
    this.options = const ParserOptions(),
    this.inlineSyntaxes = const [],
  });
  final ParserOptions options;
  final List<InlineSyntax> inlineSyntaxes;

  DocumentNode parse(String source, {bool streaming = false}) {
    final blocks = BlockParser(options: options)
        .parse(source, streaming: streaming);
    final references = <String, ReferenceDefinitionNode>{};
    final withReferences = _transform(blocks, (node) {
      if (node is! ParagraphNode) return [node];
      final input = MappedText(node.children.cast<TextNode>());
      var offset = 0;
      final result = <MarkdownNode>[];
      while (offset < input.text.length) {
        final reference = readReferenceDefinition(
          input,
          offset,
          entities: options.entities,
        );
        if (reference == null) break;
        result.add(reference.node);
        references.putIfAbsent(
          normalizeReferenceLabel(reference.node.label),
          () => reference.node,
        );
        offset = reference.end;
      }
      if (offset == 0) return [node];
      if (offset < input.text.length)
        result.add(
          ParagraphNode(
            span: SourceSpan(input.span(offset, offset).start, node.span.end),
            children: input.slice(offset, input.text.length),
          ),
        );
      return result;
    });
    final inline = InlineParser(options: options, syntaxes: inlineSyntaxes);
    return _transform(withReferences, (node) {
      if (node is ParagraphNode ||
          node is HeadingNode ||
          node is TableCellNode ||
          node is TaskItemNode ||
          node is DetailsSummaryNode ||
          node is DirectiveLabelNode)
        return [
          replaceChildren(
            node,
            inline.parseFragments(
              node.children.cast<TextNode>(),
              references: references,
            ),
          ),
        ];
      if (node is CodeBlockNode)
        return [
          CodeBlockNode(
            span: node.span,
            children: node.children,
            info: decodeMarkdownString(node.info, entities: options.entities),
            fenced: node.fenced,
            closed: node.closed,
            fenceCharacter: node.fenceCharacter,
            fenceLength: node.fenceLength,
          ),
        ];
      return [node];
    });
  }

  DocumentNode _transform(
    DocumentNode document,
    List<MarkdownNode> Function(MarkdownNode) leaf,
  ) {
    final results = <MarkdownNode, List<MarkdownNode>>{};
    final pending = <(MarkdownNode, bool)>[(document, false)];
    while (pending.isNotEmpty) {
      final (node, visited) = pending.removeLast();
      final container =
          node is DocumentNode ||
          node is BlockQuoteNode ||
          node is ListNode ||
          node is ListItemNode ||
          node is DetailsNode ||
          node is NamedBlockNode ||
          node is TableNode ||
          node is TableRowNode;
      if (!container) {
        results[node] = leaf(node);
        continue;
      }
      if (!visited) {
        pending.add((node, true));
        for (final child in node.children.reversed) pending.add((child, false));
      } else {
        results[node] = [
          replaceChildren(node, [
            for (final child in node.children) ...results[child]!,
          ]),
        ];
      }
    }
    return results[document]!.single as DocumentNode;
  }
}
