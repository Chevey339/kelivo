import 'source_span.dart';
import 'visitor.dart';

/// Immutable syntax with offsets into the caller's unmodified source.
abstract class MarkdownNode {
  const MarkdownNode(this.span);
  final SourceSpan span;
  String get type;
  List<MarkdownNode> get children => const [];
  Map<String, Object?> get fields => const {};
  T accept<T>(AstVisitor<T> visitor);

  Map<String, Object?> toJson() => {
    'type': type,
    'span': span.toJson(),
    ...fields,
    if (children.isNotEmpty)
      'children': [for (final child in children) child.toJson()],
  };
}

abstract class BlockNode extends MarkdownNode {
  const BlockNode(super.span);
}

abstract class InlineNode extends MarkdownNode {
  const InlineNode(super.span);
}

final class DocumentNode extends MarkdownNode {
  DocumentNode({required this.source, required List<BlockNode> children})
    : children = List.unmodifiable(children),
      super(SourceSpan(0, source.length));

  final String source;
  @override
  final List<BlockNode> children;
  @override
  String get type => 'document';
  @override
  Map<String, Object?> get fields => {'source': source};
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitDocument(this);
}

final class ParagraphNode extends BlockNode {
  ParagraphNode({required SourceSpan span, required List<InlineNode> children})
    : children = List.unmodifiable(children),
      super(span);

  @override
  final List<InlineNode> children;
  @override
  String get type => 'paragraph';
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitParagraph(this);
}

final class TextNode extends InlineNode {
  const TextNode({required SourceSpan span, required this.text}) : super(span);
  final String text;
  @override
  String get type => 'text';
  @override
  Map<String, Object?> get fields => {'text': text};
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitText(this);
}

final class HeadingNode extends BlockNode {
  HeadingNode({
    required SourceSpan span,
    required this.level,
    required List<InlineNode> children,
  }) : assert(level >= 1 && level <= 6),
       children = List.unmodifiable(children),
       super(span);
  final int level;
  @override
  final List<InlineNode> children;
  @override
  String get type => 'heading';
  @override
  Map<String, Object?> get fields => {'level': level};
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitHeading(this);
}

final class ThematicBreakNode extends BlockNode {
  const ThematicBreakNode(super.span);
  @override
  String get type => 'thematic_break';
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitThematicBreak(this);
}

final class CodeBlockNode extends BlockNode {
  CodeBlockNode({
    required SourceSpan span,
    required List<TextNode> children,
    this.info = '',
    this.fenced = true,
    this.closed = true,
    this.fenceCharacter = '`',
    this.fenceLength = 3,
  }) : children = List.unmodifiable(children),
       code = children.map((node) => node.text).join(),
       super(span);
  @override
  final List<TextNode> children;
  final String code;
  final String info;
  final bool fenced;
  final bool closed;
  final String fenceCharacter;
  final int fenceLength;
  @override
  String get type => 'code_block';
  @override
  Map<String, Object?> get fields => {
    'code': code,
    'info': info,
    'fenced': fenced,
    'closed': closed,
    'fenceCharacter': fenceCharacter,
    'fenceLength': fenceLength,
  };
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitCodeBlock(this);
}

final class BlockQuoteNode extends BlockNode {
  BlockQuoteNode({required SourceSpan span, required List<BlockNode> children})
    : children = List.unmodifiable(children),
      super(span);
  @override
  final List<BlockNode> children;
  @override
  String get type => 'blockquote';
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitBlockQuote(this);
}

final class ListNode extends BlockNode {
  ListNode({
    required SourceSpan span,
    required List<ListItemNode> children,
    required this.ordered,
    this.start = 1,
    this.marker = '-',
    this.delimiter = '.',
    this.tight = true,
  }) : children = List.unmodifiable(children),
       super(span);
  @override
  final List<ListItemNode> children;
  final bool ordered;
  final int start;
  final String marker;
  final String delimiter;
  final bool tight;
  @override
  String get type => 'list';
  @override
  Map<String, Object?> get fields => {
    'ordered': ordered,
    'start': start,
    'marker': marker,
    'delimiter': delimiter,
    'tight': tight,
  };
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitList(this);
}

final class ListItemNode extends BlockNode {
  ListItemNode({required SourceSpan span, required List<BlockNode> children})
    : children = List.unmodifiable(children),
      super(span);
  @override
  final List<BlockNode> children;
  @override
  String get type => 'list_item';
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitListItem(this);
}
