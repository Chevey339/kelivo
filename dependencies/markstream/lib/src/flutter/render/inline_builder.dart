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
import 'optical_baseline.dart';
import 'html_style.dart';
import 'shifted_baseline.dart';
import 'source_highlights.dart';
import '../../core/serialize/to_html.dart' show isSafeHtmlUrl;

typedef LinkRecognizerBuilder =
    TapGestureRecognizer Function(LinkNode, VoidCallback);

class InlineSpanBuilder {
  const InlineSpanBuilder({
    required this.theme,
    required this.extensions,
    required this.renderingContext,
    required this.recognizerFor,
    this.mathRenderer,
    this.imageBuilder,
    this.linkHandler,
    this.highlights = SourceHighlights.empty,
  });
  final MarkstreamTheme theme;
  final MarkstreamExtensions extensions;
  final MarkstreamRenderContext Function(BuildContext, bool) renderingContext;
  final LinkRecognizerBuilder recognizerFor;
  final MathRenderer? mathRenderer;
  final ImageBuilder? imageBuilder;
  final LinkHandler? linkHandler;
  final SourceHighlights highlights;

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
      return highlights.customInline(
        rendered.span,
        node.span,
        rendered.segments,
      );
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
    // RichText scales WidgetSpans; their text must not scale a second time.
    Widget unscaled(Widget child) =>
        MediaQuery.textScalerOf(context) == TextScaler.noScaling
        ? child
        : MediaQuery.withNoTextScaling(child: child);
    WidgetSpan atom(Widget child, String selectedText) {
      child = highlights.atom(node.span, child);
      Widget selected = SelectableSpanAdapter(
        selectedText: selectedText,
        mouseCursor: onTap == null
            ? SystemMouseCursors.text
            : SystemMouseCursors.click,
        child: onTap == null ? child : IgnorePointer(child: child),
      );
      if (onTap != null)
        selected = MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: selected,
          ),
        );
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: unscaled(selected),
      );
    }

    WidgetSpan codeAtom(String value, {bool keyboard = false}) {
      Widget capsule = InlineCodeCapsule(
        text: value,
        mouseCursor: onTap == null
            ? SystemMouseCursors.text
            : SystemMouseCursors.click,
        style: theme.inlineCode.text,
        backgroundColor: keyboard
            ? (theme.backdrop == MarkstreamBackdrop.plain
                  ? theme.colors.fillBlock
                  : theme.colors.fillRaised)
            : theme.inlineCode.backgroundColor,
        borderColor: theme.inlineCode.borderColor,
        padding: theme.inlineCode.padding,
        radius: keyboard ? MarkstreamTheme.radiusXs : theme.inlineCode.radius,
        border: keyboard
            ? Border(
                top: BorderSide(color: theme.colors.borderStrong),
                left: BorderSide(color: theme.colors.borderStrong),
                right: BorderSide(color: theme.colors.borderStrong),
                bottom: BorderSide(
                  color: theme.colors.borderStrong,
                  width: 1.5,
                ),
              )
            : null,
      );
      if (onTap != null)
        capsule = MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: onTap, child: capsule),
        );
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: unscaled(
          highlights.atom(
            node.span,
            OpticalBaseline(
              center: theme.inlineCode.opticalCenter,
              child: capsule,
            ),
          ),
        ),
      );
    }

    if (node is TextNode) {
      emit(node.text, node);
      final span = TextSpan(
        text: node.text,
        style: style,
        recognizer: recognizer(),
        mouseCursor: onTap == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
      );
      if (highlights.isEmpty) return span;
      return highlights.text(span, [
        TextSegment(text: node.text, sourceSpan: node.span, node: node),
      ]);
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
    if (node is HighlightNode)
      return children(node.children, highlightedTextStyle(style, theme));
    if (node is LinkNode)
      return children(node.children, style.merge(theme.link), target: node);
    if (node is CodeSpanNode) {
      for (final fragment in node.children) emit(fragment.text, fragment);
      return codeAtom(node.code);
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
    if (node is HtmlElementNode) {
      if (node.tag == 'br') {
        emit('\n', node);
        return TextSpan(text: '\n', style: style);
      }
      final htmlStyle = htmlTextStyle(node, style, theme);
      if (node.tag == 'a') {
        final href = node.attributes['href'];
        return children(
          node.children,
          href != null && isSafeHtmlUrl(href)
              ? htmlStyle.merge(theme.link)
              : htmlStyle,
          target: href != null && isSafeHtmlUrl(href)
              ? LinkNode(
                  span: node.span,
                  destination: href,
                  children: node.children,
                  title: node.attributes['title'],
                )
              : link,
        );
      }
      if (node.tag == 'img') {
        final alt = node.attributes['alt'] ?? '';
        final src = node.attributes['src'];
        emit(alt, node);
        if (src == null || !isSafeHtmlUrl(src, image: true))
          return TextSpan(text: alt, style: htmlStyle);
        final image = ImageNode(
          span: node.span,
          destination: src,
          title: node.attributes['title'],
          children: [TextNode(span: node.span, text: alt)],
        );
        double? dimension(String name) {
          final value = double.tryParse(node.attributes[name] ?? '');
          return value != null && value.isFinite && value > 0
              ? value.clamp(1, 4096)
              : null;
        }

        return atom(
          ClipRRect(
            borderRadius: BorderRadius.circular(theme.imageRadius),
            child: SizedBox(
              width: dimension('width'),
              height: dimension('height'),
              child:
                  imageBuilder?.build(context, image, theme) ??
                  Text(alt, style: htmlStyle),
            ),
          ),
          alt,
        );
      }
      if (node.tag == 'code' || node.tag == 'kbd') {
        emit(toPlainText(node), node);
        return codeAtom(toPlainText(node), keyboard: node.tag == 'kbd');
      }
      if (node.tag == 'sub' || node.tag == 'sup') {
        emit(toPlainText(node), node);
        final fontSize = htmlStyle.fontSize ?? theme.body.fontSize ?? 15.5;
        return atom(
          ShiftedBaseline(
            shift: fontSize * (node.tag == 'sup' ? .35 : -.2),
            child: Text.rich(
              TextSpan(
                children: [
                  for (final child in node.children)
                    build(
                      context,
                      child,
                      htmlStyle.copyWith(fontSize: fontSize * .75),
                      streaming: streaming,
                      link: link,
                    ),
                ],
              ),
              style: htmlStyle.copyWith(fontSize: fontSize * .75),
            ),
          ),
          toPlainText(node),
        );
      }
      return children(node.children, htmlStyle);
    }
    return children(node.children.cast<InlineNode>(), style);
  }
}
