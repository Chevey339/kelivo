import 'nodes.dart';

abstract class AstVisitor<T> {
  T visitNode(MarkdownNode node);
  T visitDocument(DocumentNode node) => visitNode(node);
  T visitParagraph(ParagraphNode node) => visitNode(node);
  T visitText(TextNode node) => visitNode(node);
  T visitHeading(HeadingNode node) => visitNode(node);
  T visitThematicBreak(ThematicBreakNode node) => visitNode(node);
  T visitMathBlock(MathBlockNode node) => visitNode(node);
  T visitCodeBlock(CodeBlockNode node) => visitNode(node);
  T visitBlockQuote(BlockQuoteNode node) => visitNode(node);
  T visitList(ListNode node) => visitNode(node);
  T visitTaskItem(TaskItemNode node) => visitNode(node);
  T visitTable(TableNode node) => visitNode(node);
  T visitTableRow(TableRowNode node) => visitNode(node);
  T visitTableCell(TableCellNode node) => visitNode(node);
  T visitDetails(DetailsNode node) => visitNode(node);
  T visitDetailsSummary(DetailsSummaryNode node) => visitNode(node);
  T visitListItem(ListItemNode node) => visitNode(node);
}

/// Override specific visits and call super to keep walking their descendants.
class RecursiveAstVisitor extends AstVisitor<void> {
  @override
  void visitNode(MarkdownNode node) {
    for (final child in node.children) {
      child.accept(this);
    }
  }
}
