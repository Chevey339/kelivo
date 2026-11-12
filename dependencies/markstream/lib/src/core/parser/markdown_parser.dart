import '../ast/nodes.dart';
import '../ast/source_span.dart';
import '../ast/transform.dart';
import '../html/entities.dart';
import 'block_parser.dart';
import 'dialect.dart';
import 'inline_parser.dart';
import 'mapped_text.dart';
import 'source_line.dart';
import 'syntax/reference_definition.dart';
import 'syntax/inline_syntax.dart';
import 'syntax/block_syntax.dart';

/// Two-phase block and inline parsing. References resolve across the document.
final class MarkdownParser {
  const MarkdownParser({
    this.options = const ParserOptions(),
    this.inlineSyntaxes = const [],
    this.blockSyntaxes = const [],
  });
  final ParserOptions options;
  final List<InlineSyntax> inlineSyntaxes;
  final List<BlockSyntax> blockSyntaxes;

  DocumentNode parse(
    String source, {
    bool streaming = false,
    int start = 0,
    Map<String, ReferenceDefinitionNode> initialReferences = const {},
    StreamingOptions streamingOptions = const StreamingOptions(),
  }) {
    final blocks = BlockParser(options: options).parse(
      source,
      streaming: streaming && streamingOptions.optimisticBlocks,
      start: start,
    );
    final references = <String, ReferenceDefinitionNode>{...initialReferences};
    final taskLabels = <MarkdownNode>{};
    final pendingBlocks = <BlockNode>[...blocks.children];
    while (pendingBlocks.isNotEmpty) {
      final block = pendingBlocks.removeLast();
      if (block is ListItemNode &&
          block.checked != null &&
          block.children.isNotEmpty)
        taskLabels.add(block.children.first);
      pendingBlocks.addAll(block.children.whereType<BlockNode>());
    }
    final withReferences = _transform(blocks, (node) {
      if (node is! ParagraphNode || taskLabels.contains(node)) return [node];
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
    final document = _transform(withReferences, (node) {
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
              optimistic:
                  streaming &&
                  streamingOptions.optimisticInlines &&
                  _openInlineTail(node, source),
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
    final projected = streaming && !streamingOptions.optimisticBlocks
        ? _literalIncomplete(document)
        : document;
    final extended = blockSyntaxes.isEmpty
        ? projected
        : _transform(projected, (node) {
            if (node is! BlockNode || node is ReferenceDefinitionNode)
              return [node];
            final context = BlockSyntaxContext(
              source: source,
              block: node,
              options: options,
              streaming: streaming,
            );
            for (final syntax in blockSyntaxes) {
              final replacement = syntax.parse(context);
              if (replacement == null) continue;
              if (replacement.span != node.span) {
                throw ArgumentError(
                  'BlockSyntax must preserve the scanned source boundary',
                );
              }
              final pending = <MarkdownNode>[replacement];
              while (pending.isNotEmpty) {
                final parent = pending.removeLast();
                for (final child in parent.children) {
                  if (child.span.end < child.span.start ||
                      child.span.start < parent.span.start ||
                      child.span.end > parent.span.end) {
                    throw ArgumentError(
                      'BlockSyntax child source range is outside its parent',
                    );
                  }
                  pending.add(child);
                }
              }
              return [replacement];
            }
            return [node];
          });
    return DocumentNode(
      source: source,
      children: extended.children,
      references: references,
    );
  }

  bool _openInlineTail(MarkdownNode node, String source) =>
      node.children.isNotEmpty &&
      node.children.last.span.end == node.span.end &&
      RegExp(
        options.unicodeLineBreaks
            ? r'^[ \t]*(?:\r\n|[\r\n\u2028\u2029])?[ \t]*$'
            : r'^[ \t]*(?:\r\n|\r|\n)?[ \t]*$',
      ).hasMatch(source.substring(node.span.end));

  DocumentNode _literalIncomplete(DocumentNode document) {
    final converted = <MarkdownNode, MarkdownNode>{};
    final pending = <(MarkdownNode, bool)>[(document, false)];
    while (pending.isNotEmpty) {
      final (node, visited) = pending.removeLast();
      final incomplete = switch (node) {
        CodeBlockNode() => !node.closed,
        MathBlockNode() => !node.closed,
        DetailsNode() => !node.closed,
        NamedBlockNode() => !node.closed,
        HtmlBlockNode() => !node.closed,
        TableNode() => node.provisional,
        _ => false,
      };
      if (incomplete) {
        final raw = node.span.slice(document.source);
        final fragments = <TextNode>[];
        for (final line in SourceLine.scan(
          raw,
          unicodeLineBreaks: options.unicodeLineBreaks,
        )) {
          fragments.add(
            TextNode(
              span: SourceSpan(
                node.span.start + line.start,
                node.span.start + line.end,
              ),
              text: raw
                  .substring(line.start, line.end)
                  .replaceAll('\u0000', '\uFFFD'),
            ),
          );
          if (line.next > line.end)
            fragments.add(
              TextNode(
                span: SourceSpan(
                  node.span.start + line.end,
                  node.span.start + line.next,
                ),
                text: '\n',
              ),
            );
        }
        converted[node] = ParagraphNode(span: node.span, children: fragments);
        continue;
      }
      if (!visited) {
        pending.add((node, true));
        for (final child in node.children.reversed) pending.add((child, false));
      } else {
        converted[node] = replaceChildren(node, [
          for (final child in node.children) converted[child]!,
        ]);
      }
    }
    return converted[document]! as DocumentNode;
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
