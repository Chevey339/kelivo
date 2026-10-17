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
