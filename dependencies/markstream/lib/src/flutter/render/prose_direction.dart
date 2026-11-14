import 'package:flutter/widgets.dart';

import '../../core/ast/nodes.dart';
import 'bidi_classes.dart';

final _strong = RegExp('([$rtlCharacters])|[$ltrCharacters]', unicode: true);
final _rtl = RegExp('[$rtlCharacters]', unicode: true);

/// HTML dir=auto uses the first Unicode L, R or AL character. A neutral
/// string has no direction of its own and can inherit its surrounding one.
TextDirection? firstStrongDirection(String text) {
  final match = _strong.firstMatch(text);
  if (match == null) return null;
  return match.group(1) == null ? TextDirection.ltr : TextDirection.rtl;
}

/// Whether a left-to-right-only line renderer can encounter strong RTL text.
bool containsStrongRtl(String text) => _rtl.hasMatch(text);

/// A loose, start-aligned Markdown column would otherwise place a short RTL
/// block on the left even if its glyphs were shaped in the correct direction.
Widget directionalBlock(
  BuildContext context,
  TextDirection? direction,
  Widget child, {
  bool align = true,
}) {
  final ambient = Directionality.of(context);
  final resolved = direction ?? ambient;
  if (align && (resolved == TextDirection.rtl || resolved != ambient)) {
    final content = child;
    child = Builder(
      builder: (context) {
        final alignment = switch (DefaultTextStyle.of(context).textAlign) {
          TextAlign.center => Alignment.topCenter,
          TextAlign.right => Alignment.topRight,
          TextAlign.left => Alignment.topLeft,
          TextAlign.end => AlignmentDirectional.topEnd,
          _ => AlignmentDirectional.topStart,
        };
        return Align(alignment: alignment, widthFactor: 1, child: content);
      },
    );
  }
  return resolved == ambient
      ? child
      : Directionality(textDirection: resolved, child: child);
}

/// Directional columns stretch their children once the document has a known
/// width. During measurement every child reports its content width.
class ProseWidthScope extends InheritedWidget {
  const ProseWidthScope({required this.enabled, required super.child});
  final bool enabled;
  static bool isDirectional(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProseWidthScope>()?.enabled ??
      false;

  @override
  bool updateShouldNotify(ProseWidthScope oldWidget) =>
      enabled != oldWidget.enabled;
}

Widget proseColumn({required List<Widget> children, double spacing = 0}) {
  Widget column(CrossAxisAlignment alignment) => Column(
    spacing: spacing,
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: alignment,
    children: children,
  );
  return LayoutBuilder(
    builder: (context, constraints) => column(
      constraints.hasTightWidth && ProseWidthScope.isDirectional(context)
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
    ),
  );
}

/// Look through emphasis and link labels, skipping isolated inline widgets
/// and syntax such as link destinations, code fences and list markers.
TextDirection? proseDirection(Iterable<MarkdownNode> nodes) {
  for (final node in nodes) {
    if (_isolated(node)) continue;
    final direction = node is TextNode
        ? firstStrongDirection(node.text)
        : proseDirection(node.children);
    if (direction != null) return direction;
  }
  return null;
}

bool _isolated(MarkdownNode node) =>
    node is CodeSpanNode ||
    node is CodeBlockNode ||
    node is ImageNode ||
    node is MathInlineNode ||
    node is MathBlockNode ||
    (node is NamedInlineNode && node.syntax == NamedInlineSyntax.extension) ||
    (node is HtmlElementNode &&
        const {'code', 'kbd', 'pre', 'img'}.contains(node.tag));

/// Only paragraphs and containers with an RTL start need a shared width.
/// A Latin paragraph that quotes Persian, or a code block containing Persian,
/// must retain its normal layout and streaming path.
bool hasRtlBlock(MarkdownNode node) {
  if (_isolated(node)) return false;
  if (node is ParagraphNode ||
      node is HeadingNode ||
      node is TaskItemNode ||
      node is TableCellNode ||
      node is DetailsSummaryNode ||
      node is DirectiveLabelNode) {
    return proseDirection(node.children) == TextDirection.rtl;
  }
  if (node is HtmlBlockNode && node.fullDocument) return false;
  if (node is HtmlElementNode || node is HtmlBlockNode) {
    if (proseDirection(node.children) == TextDirection.rtl) return true;
  }
  return node.children.any(hasRtlBlock);
}
