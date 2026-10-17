import 'nodes.dart';

abstract class AstVisitor<T> {
  T visitNode(MarkdownNode node);
  T visitDocument(DocumentNode node) => visitNode(node);
  T visitParagraph(ParagraphNode node) => visitNode(node);
  T visitText(TextNode node) => visitNode(node);
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
