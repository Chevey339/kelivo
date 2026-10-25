import 'nodes.dart';

/// Rebuilds immutable nodes while preserving their source metadata.
MarkdownNode replaceChildren(MarkdownNode node, List<MarkdownNode> children) =>
    switch (node) {
      DocumentNode() => DocumentNode(
        source: node.source,
        references: node.references,
        children: children.cast<BlockNode>(),
      ),
      ParagraphNode() => ParagraphNode(
        span: node.span,
        children: children.cast<InlineNode>(),
      ),
      HeadingNode() => HeadingNode(
        span: node.span,
        level: node.level,
        children: children.cast<InlineNode>(),
      ),
      BlockQuoteNode() => BlockQuoteNode(
        span: node.span,
        children: children.cast<BlockNode>(),
      ),
      ListNode() => ListNode(
        span: node.span,
        children: children.cast<ListItemNode>(),
        ordered: node.ordered,
        start: node.start,
        marker: node.marker,
        delimiter: node.delimiter,
        tight: node.tight,
      ),
      ListItemNode() => ListItemNode(
        span: node.span,
        children: children.cast<BlockNode>(),
        checked: node.checked,
        radio: node.radio,
        markerSpan: node.markerSpan,
      ),
      TaskItemNode() => TaskItemNode(
        span: node.span,
        children: children.cast<InlineNode>(),
        markerSpan: node.markerSpan,
        checked: node.checked,
        radio: node.radio,
      ),
      TableNode() => TableNode(
        span: node.span,
        provisional: node.provisional,
        children: children.cast<TableRowNode>(),
        alignments: node.alignments,
      ),
      TableRowNode() => TableRowNode(
        span: node.span,
        children: children.cast<TableCellNode>(),
        header: node.header,
      ),
      TableCellNode() => TableCellNode(
        span: node.span,
        children: children.cast<InlineNode>(),
      ),
      DetailsNode() => DetailsNode(
        span: node.span,
        children: children.cast<BlockNode>(),
        open: node.open,
        closed: node.closed,
      ),
      DetailsSummaryNode() => DetailsSummaryNode(
        span: node.span,
        children: children.cast<InlineNode>(),
      ),
      NamedBlockNode() => NamedBlockNode(
        span: node.span,
        children: children.cast<BlockNode>(),
        name: node.name,
        syntax: node.syntax,
        attributes: node.attributes,
        closed: node.closed,
      ),
      DirectiveLabelNode() => DirectiveLabelNode(
        span: node.span,
        children: children.cast<InlineNode>(),
      ),
      HtmlBlockNode() => HtmlBlockNode(
        span: node.span,
        children: children.cast<InlineNode>(),
        rawFragments: node.rawFragments,
        fullDocument: node.fullDocument,
        closed: node.closed,
      ),
      HtmlElementNode() => HtmlElementNode(
        span: node.span,
        children: children.cast<InlineNode>(),
        tag: node.tag,
        attributes: node.attributes,
      ),
      CodeBlockNode() => CodeBlockNode(
        span: node.span,
        children: children.cast<TextNode>(),
        info: node.info,
        fenced: node.fenced,
        closed: node.closed,
        fenceCharacter: node.fenceCharacter,
        fenceLength: node.fenceLength,
      ),
      CodeSpanNode() => CodeSpanNode(
        span: node.span,
        closed: node.closed,
        children: children.cast<TextNode>(),
        delimiterLength: node.delimiterLength,
      ),
      MathBlockNode() => MathBlockNode(
        span: node.span,
        children: children.cast<TextNode>(),
        delimiter: node.delimiter,
        closed: node.closed,
      ),
      EmphasisNode() => EmphasisNode(
        span: node.span,
        closed: node.closed,
        children: children.cast<InlineNode>(),
        strong: node.strong,
        marker: node.marker,
      ),
      LinkNode() => LinkNode(
        span: node.span,
        children: children.cast<InlineNode>(),
        destination: node.destination,
        title: node.title,
        autolink: node.autolink,
      ),
      ImageNode() => ImageNode(
        span: node.span,
        children: children.cast<InlineNode>(),
        destination: node.destination,
        title: node.title,
      ),
      StrikethroughNode() => StrikethroughNode(
        span: node.span,
        closed: node.closed,
        children: children.cast<InlineNode>(),
      ),
      MathInlineNode() => MathInlineNode(
        span: node.span,
        children: children.cast<TextNode>(),
        delimiter: node.delimiter,
        closed: node.closed,
      ),
      NamedInlineNode() => NamedInlineNode(
        span: node.span,
        children: children.cast<InlineNode>(),
        name: node.name,
        syntax: node.syntax,
        attributes: node.attributes,
      ),
      _ => node,
    };
