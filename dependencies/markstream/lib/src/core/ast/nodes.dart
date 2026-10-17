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
  DocumentNode({
    required this.source,
    required List<BlockNode> children,
    Map<String, ReferenceDefinitionNode> references = const {},
  }) : children = List.unmodifiable(children),
       references = Map.unmodifiable(references),
       super(SourceSpan(0, source.length));

  final String source;
  final Map<String, ReferenceDefinitionNode> references;
  @override
  final List<BlockNode> children;
  @override
  String get type => 'document';
  @override
  Map<String, Object?> get fields => {
    'source': source,
    if (references.isNotEmpty)
      'references': {
        for (final entry in references.entries) entry.key: entry.value.toJson(),
      },
  };
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
  ListItemNode({
    required SourceSpan span,
    required List<BlockNode> children,
    this.checked,
    this.radio = false,
    this.markerSpan,
  }) : children = List.unmodifiable(children),
       super(span);
  @override
  final List<BlockNode> children;
  final bool? checked;
  final bool radio;
  final SourceSpan? markerSpan;
  @override
  Map<String, Object?> get fields => {
    if (checked != null) 'checked': checked,
    if (radio) 'radio': true,
    if (markerSpan != null) 'markerSpan': markerSpan!.toJson(),
  };
  @override
  String get type => 'list_item';
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitListItem(this);
}

final class MathBlockNode extends BlockNode {
  MathBlockNode({
    required SourceSpan span,
    required List<TextNode> children,
    this.delimiter = r'$$',
    this.closed = true,
  }) : children = List.unmodifiable(children),
       tex = children.map((node) => node.text).join().trim(),
       super(span);
  @override
  final List<TextNode> children;
  final String tex;
  final String delimiter;
  final bool closed;
  @override
  String get type => 'math_block';
  @override
  Map<String, Object?> get fields => {
    'tex': tex,
    'delimiter': delimiter,
    'closed': closed,
  };
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitMathBlock(this);
}

final class TaskItemNode extends BlockNode {
  TaskItemNode({
    required SourceSpan span,
    required this.markerSpan,
    required this.checked,
    this.radio = false,
    required List<InlineNode> children,
  }) : children = List.unmodifiable(children),
       super(span);
  @override
  final List<InlineNode> children;
  final SourceSpan markerSpan;
  final bool checked;
  final bool radio;
  @override
  String get type => radio ? 'radio_item' : 'task_item';
  @override
  Map<String, Object?> get fields => {
    'checked': checked,
    'markerSpan': markerSpan.toJson(),
  };
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitTaskItem(this);
}

enum TableAlignment { none, left, center, right }

final class TableNode extends BlockNode {
  TableNode({
    required SourceSpan span,
    this.provisional = false,
    required List<TableRowNode> children,
    required List<TableAlignment> alignments,
  }) : children = List.unmodifiable(children),
       alignments = List.unmodifiable(alignments),
       super(span);
  @override
  final List<TableRowNode> children;
  final List<TableAlignment> alignments;
  final bool provisional;
  @override
  String get type => 'table';
  @override
  Map<String, Object?> get fields => {
    if (provisional) 'provisional': true,
    'alignments': alignments.map((a) => a.name).toList(),
  };
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitTable(this);
}

final class TableRowNode extends MarkdownNode {
  TableRowNode({
    required SourceSpan span,
    required List<TableCellNode> children,
    this.header = false,
  }) : children = List.unmodifiable(children),
       super(span);
  @override
  final List<TableCellNode> children;
  final bool header;
  @override
  String get type => 'table_row';
  @override
  Map<String, Object?> get fields => {'header': header};
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitTableRow(this);
}

final class TableCellNode extends MarkdownNode {
  TableCellNode({required SourceSpan span, required List<InlineNode> children})
    : children = List.unmodifiable(children),
      super(span);
  @override
  final List<InlineNode> children;
  @override
  String get type => 'table_cell';
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitTableCell(this);
}

final class DetailsNode extends BlockNode {
  DetailsNode({
    required SourceSpan span,
    required List<BlockNode> children,
    this.open = false,
    this.closed = true,
  }) : children = List.unmodifiable(children),
       super(span);
  @override
  final List<BlockNode> children;
  final bool open;
  final bool closed;
  @override
  String get type => 'details';
  @override
  Map<String, Object?> get fields => {'open': open, 'closed': closed};
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitDetails(this);
}

final class DetailsSummaryNode extends BlockNode {
  DetailsSummaryNode({
    required SourceSpan span,
    required List<InlineNode> children,
  }) : children = List.unmodifiable(children),
       super(span);
  @override
  final List<InlineNode> children;
  @override
  String get type => 'details_summary';
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitDetailsSummary(this);
}

enum NamedBlockSyntax { alert, containerDirective, leafDirective }

final class NamedBlockNode extends BlockNode {
  NamedBlockNode({
    required SourceSpan span,
    required this.name,
    required this.syntax,
    required List<BlockNode> children,
    Map<String, String> attributes = const {},
    this.closed = true,
  }) : children = List.unmodifiable(children),
       attributes = Map.unmodifiable(attributes),
       super(span);
  final String name;
  final NamedBlockSyntax syntax;
  final Map<String, String> attributes;
  final bool closed;
  @override
  final List<BlockNode> children;
  @override
  String get type => 'named_block';
  @override
  Map<String, Object?> get fields => {
    'name': name,
    'syntax': syntax.name,
    'attributes': attributes,
    'closed': closed,
  };
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitNamedBlock(this);
}

final class DirectiveLabelNode extends BlockNode {
  DirectiveLabelNode({
    required SourceSpan span,
    required List<InlineNode> children,
  }) : children = List.unmodifiable(children),
       super(span);
  @override
  final List<InlineNode> children;
  @override
  String get type => 'directive_label';
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitDirectiveLabel(this);
}

final class HtmlBlockNode extends BlockNode {
  HtmlBlockNode({
    required SourceSpan span,
    required List<InlineNode> children,
    required List<TextNode> rawFragments,
    this.fullDocument = false,
    this.closed = true,
  }) : children = List.unmodifiable(children),
       rawFragments = List.unmodifiable(rawFragments),
       raw = rawFragments.map((n) => n.text).join(),
       super(span);
  @override
  final List<InlineNode> children;
  final String raw;
  final List<TextNode> rawFragments;
  final bool fullDocument;
  final bool closed;
  @override
  String get type => 'html_block';
  @override
  Map<String, Object?> get fields => {
    'raw': raw,
    if (fullDocument)
      'rawFragments': [for (final fragment in rawFragments) fragment.toJson()],
    'fullDocument': fullDocument,
    'closed': closed,
  };
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitHtmlBlock(this);
}

final class HtmlElementNode extends InlineNode {
  HtmlElementNode({
    required SourceSpan span,
    required this.tag,
    required List<InlineNode> children,
    Map<String, String> attributes = const {},
  }) : children = List.unmodifiable(children),
       attributes = Map.unmodifiable(attributes),
       super(span);
  final String tag;
  final Map<String, String> attributes;
  @override
  final List<InlineNode> children;
  @override
  String get type => 'html_element';
  @override
  Map<String, Object?> get fields => {'tag': tag, 'attributes': attributes};
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitHtmlElement(this);
}

final class EmphasisNode extends InlineNode {
  EmphasisNode({
    required SourceSpan span,
    this.closed = true,
    required List<InlineNode> children,
    this.strong = false,
    this.marker = '*',
  }) : children = List.unmodifiable(children),
       super(span);
  final bool closed;
  @override
  final List<InlineNode> children;
  final bool strong;
  final String marker;
  @override
  String get type => strong ? 'strong' : 'emphasis';
  @override
  Map<String, Object?> get fields => {
    'marker': marker,
    if (!closed) 'closed': false,
  };
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitEmphasis(this);
}

final class CodeSpanNode extends InlineNode {
  CodeSpanNode({
    required SourceSpan span,
    this.closed = true,
    required List<TextNode> children,
    this.delimiterLength = 1,
  }) : children = List.unmodifiable(children),
       code = children.map((n) => n.text).join(),
       super(span);
  final bool closed;
  @override
  final List<TextNode> children;
  final String code;
  final int delimiterLength;
  @override
  String get type => 'code_span';
  @override
  Map<String, Object?> get fields => {
    'code': code,
    if (!closed) 'closed': false,
    'delimiterLength': delimiterLength,
  };
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitCodeSpan(this);
}

final class LinkNode extends InlineNode {
  LinkNode({
    required SourceSpan span,
    required List<InlineNode> children,
    required this.destination,
    this.title,
    this.autolink = false,
  }) : children = List.unmodifiable(children),
       super(span);
  @override
  final List<InlineNode> children;
  final String destination;
  final String? title;
  final bool autolink;
  @override
  String get type => 'link';
  @override
  Map<String, Object?> get fields => {
    'destination': destination,
    if (title != null) 'title': title,
    if (autolink) 'autolink': true,
  };
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitLink(this);
}

final class ImageNode extends InlineNode {
  ImageNode({
    required SourceSpan span,
    required List<InlineNode> children,
    required this.destination,
    this.title,
  }) : children = List.unmodifiable(children),
       super(span);
  @override
  final List<InlineNode> children;
  final String destination;
  final String? title;
  @override
  String get type => 'image';
  @override
  Map<String, Object?> get fields => {
    'destination': destination,
    if (title != null) 'title': title,
  };
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitImage(this);
}

final class LineBreakNode extends InlineNode {
  const LineBreakNode({required SourceSpan span, required this.hard})
    : super(span);
  final bool hard;
  @override
  String get type => hard ? 'hard_break' : 'soft_break';
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitLineBreak(this);
}

final class ReferenceDefinitionNode extends BlockNode {
  const ReferenceDefinitionNode({
    required SourceSpan span,
    required this.label,
    required this.destination,
    this.title,
  }) : super(span);
  final String label;
  final String destination;
  final String? title;
  @override
  String get type => 'reference_definition';
  @override
  Map<String, Object?> get fields => {
    'label': label,
    'destination': destination,
    if (title != null) 'title': title,
  };
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitReferenceDefinition(this);
}

final class StrikethroughNode extends InlineNode {
  StrikethroughNode({
    required SourceSpan span,
    this.closed = true,
    required List<InlineNode> children,
  }) : children = List.unmodifiable(children),
       super(span);
  final bool closed;
  @override
  final List<InlineNode> children;
  @override
  String get type => 'strikethrough';
  @override
  Map<String, Object?> get fields => {if (!closed) 'closed': false};
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitStrikethrough(this);
}

final class MathInlineNode extends InlineNode {
  MathInlineNode({
    required SourceSpan span,
    required List<TextNode> children,
    this.delimiter = r'$',
    this.closed = true,
  }) : children = List.unmodifiable(children),
       tex = children.map((n) => n.text).join(),
       super(span);
  @override
  final List<TextNode> children;
  final String tex;
  final String delimiter;
  final bool closed;
  @override
  String get type => 'math_inline';
  @override
  Map<String, Object?> get fields => {
    'tex': tex,
    'delimiter': delimiter,
    'closed': closed,
  };
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitMathInline(this);
}

enum NamedInlineSyntax { directive, extension }

final class NamedInlineNode extends InlineNode {
  NamedInlineNode({
    required SourceSpan span,
    required this.name,
    required List<InlineNode> children,
    this.syntax = NamedInlineSyntax.extension,
    Map<String, String> attributes = const {},
  }) : children = List.unmodifiable(children),
       attributes = Map.unmodifiable(attributes),
       super(span);
  final String name;
  final NamedInlineSyntax syntax;
  final Map<String, String> attributes;
  @override
  final List<InlineNode> children;
  @override
  String get type => 'named_inline';
  @override
  Map<String, Object?> get fields => {
    'name': name,
    'syntax': syntax.name,
    'attributes': attributes,
  };
  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitNamedInline(this);
}
