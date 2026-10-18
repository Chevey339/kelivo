import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/ast/nodes.dart';
import '../../core/text_index/text_index.dart';
import '../../core/serialize/to_plain_text.dart';
import '../extensions/registry.dart';
import '../interfaces/renderers.dart';
import '../selection/selectable_span_adapter.dart';
import '../theme/markstream_theme.dart';
import 'fitted_math.dart';
import 'inline_code_capsule.dart';

typedef LinkRecognizerBuilder = TapGestureRecognizer Function(
  LinkNode,
  VoidCallback,
);

class InlineSpanBuilder {
  const InlineSpanBuilder({
    required this.theme,
    required this.extensions,
    required this.renderingContext,
    required this.recognizerFor,
    this.mathRenderer,
    this.imageBuilder,
    this.linkHandler,
  });
  final MarkstreamTheme theme;
  final MarkstreamExtensions extensions;
  final MarkstreamRenderContext Function(BuildContext, bool) renderingContext;
  final LinkRecognizerBuilder recognizerFor;
  final MathRenderer? mathRenderer;
  final ImageBuilder? imageBuilder;
  final LinkHandler? linkHandler;

  InlineSpan build(
    BuildContext context,
    InlineNode node,
    TextStyle style, {
    required bool streaming,
    LinkNode? link,
    List<TextSegment>? projection,
  }) {
    final custom = extensions.inlineBuilderFor(node);
    if (custom != null) {
      final rendered = custom(
        context,
        node,
        renderingContext(context, streaming),
      );
      projection?.addAll(rendered.segments);
      return rendered.span;
    }
    void emit(String text, MarkdownNode source) => projection?.add(
      TextSegment(text: text, sourceSpan: source.span, node: source),
    );
    VoidCallback? openLink(LinkNode? target) =>
        target == null || linkHandler == null
        ? null
        : () => unawaited(
            Future<void>.sync(() => linkHandler!.open(context, target)),
          );
    final onTap = openLink(link);
    TapGestureRecognizer? recognizer() =>
        onTap == null ? null : recognizerFor(link!, onTap);
    InlineSpan children(
      List<InlineNode> nodes,
      TextStyle childStyle, {
      LinkNode? target,
    }) => TextSpan(
      style: childStyle,
      children: [
        for (final child in nodes)
          build(
            context,
            child,
            childStyle,
            streaming: streaming,
            link: target ?? link,
            projection: projection,
          ),
      ],
    );
    WidgetSpan atom(Widget child, String selectedText) {
      Widget selected = SelectableSpanAdapter(
        selectedText: selectedText,
        child: child,
      );
      if (onTap != null)
        selected = MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: onTap, child: selected),
        );
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: selected,
      );
    }

    if (node is TextNode) {
      emit(node.text, node);
      return TextSpan(
        text: node.text,
        style: style,
        recognizer: recognizer(),
        mouseCursor: onTap == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
      );
    }
    if (node is LineBreakNode) {
      emit(node.hard ? "\n" : " ", node);
      return TextSpan(
        text: node.hard ? '\n' : ' ',
        style: style,
        recognizer: recognizer(),
      );
    }
    if (node is EmphasisNode)
      return children(
        node.children,
        node.strong
            ? style.copyWith(fontWeight: theme.strongWeight)
            : style.copyWith(fontStyle: FontStyle.italic),
      );
    if (node is StrikethroughNode)
      return children(
        node.children,
        style.copyWith(
          decoration: TextDecoration.combine([
            if (style.decoration != null) style.decoration!,
            TextDecoration.lineThrough,
          ]),
        ),
      );
    if (node is LinkNode)
      return children(node.children, style.merge(theme.link), target: node);
    if (node is CodeSpanNode) {
      for (final fragment in node.children) emit(fragment.text, fragment);
      Widget capsule = InlineCodeCapsule(
        text: node.code,
        style: theme.inlineCode.text,
        backgroundColor: theme.inlineCode.backgroundColor,
        borderColor: theme.inlineCode.borderColor,
        padding: theme.inlineCode.padding,
        radius: theme.inlineCode.radius,
      );
      if (onTap != null)
        capsule = MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: onTap, child: capsule),
        );
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: capsule,
      );
    }
    if (node is MathInlineNode) {
      emit(toPlainText(node), node);
      final mathStyle = style.copyWith(
        fontSize:
            (style.fontSize ?? theme.body.fontSize!) * theme.inlineMathScale,
      );
      final child =
          mathRenderer?.build(
            context,
            node.tex,
            style: mathStyle,
            displayMode: false,
          ) ??
          Text(node.tex, style: mathStyle);
      return atom(BaselineFittedBox(child: child), toPlainText(node));
    }
    if (node is ImageNode) {
      final alt = node.children.map(toPlainText).join();
      emit(alt, node);
      final child =
          imageBuilder?.build(context, node, theme) ?? Text(alt, style: style);
      return atom(
        ClipRRect(
          borderRadius: BorderRadius.circular(theme.imageRadius),
          child: child,
        ),
        alt,
      );
    }
    if (node is HtmlElementNode && node.tag == 'br') {
      emit('\n', node);
      return TextSpan(text: '\n', style: style);
    }
    return children(node.children.cast<InlineNode>(), style);
  }
}
