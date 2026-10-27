import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/ast/nodes.dart';
import '../../core/text_index/text_index.dart';
import '../../core/html/html_fragment.dart' show htmlBlockTags;
import '../../core/serialize/to_plain_text.dart';
import '../extensions/registry.dart';
import '../selection/document_selection.dart';
import '../selection/selection_controller.dart';
import '../interfaces/renderers.dart';
import '../theme/markstream_theme.dart';
import 'inline_builder.dart';
import 'optical_baseline.dart';
import 'source_highlights.dart';
import 'streaming_text.dart';
import 'chrome.dart';
import 'blocks/code_block.dart';
import 'blocks/table_block.dart';
import 'blocks/math_block.dart';
import 'blocks/details_block.dart';
import 'blocks/directive_card.dart';
import '../../core/ast/source_span.dart';

part 'html_block_builder.dart';

/// One view owns this session. Cached prefix widgets do not retain historical
/// whole-document snapshots; recursive callbacks read the current session.
class MarkstreamRenderer {
  MarkstreamRenderer(this.recognizerFor);
  final LinkRecognizerBuilder recognizerFor;
  late DocumentNode document;
  late MarkstreamTheme theme;
  late MarkstreamExtensions extensions;
  CodeHighlighter? codeHighlighter;
  MathRenderer? mathRenderer;
  ImageBuilder? imageBuilder;
  LinkHandler? linkHandler;
  late InlineSpanBuilder _inline;
  MarkstreamRenderer? _blockContentRenderer;
  late CodeBlockOptions codeOptions;
  late MarkstreamLabels labels;
  bool exporting = false;
  bool trackSelection = false;
  SourceHighlights highlights = SourceHighlights.empty;

  void update({
    required DocumentNode document,
    required MarkstreamTheme theme,
    required MarkstreamExtensions extensions,
    CodeHighlighter? codeHighlighter,
    MathRenderer? mathRenderer,
    ImageBuilder? imageBuilder,
    LinkHandler? linkHandler,
    required CodeBlockOptions codeOptions,
    required MarkstreamLabels labels,
    required bool exporting,
    required bool trackSelection,
    SourceHighlights highlights = SourceHighlights.empty,
  }) {
    this.document = document;
    this.theme = theme;
    this.extensions = extensions;
    this.codeHighlighter = codeHighlighter;
    this.mathRenderer = mathRenderer;
    this.imageBuilder = imageBuilder;
    this.linkHandler = linkHandler;
    this.codeOptions = codeOptions;
    this.labels = labels;
    this.exporting = exporting;
    this.trackSelection = trackSelection;
    this.highlights = highlights;
    _inline = InlineSpanBuilder(
      theme: theme,
      extensions: extensions,
      renderingContext: contextFor,
      recognizerFor: recognizerFor,
      mathRenderer: mathRenderer,
      imageBuilder: imageBuilder,
      linkHandler: linkHandler,
      highlights: highlights,
    );
    _updateBlockContent();
  }

  // Keep a live session for nested painted surfaces too. Cached fold/cell
  // callbacks must read the latest document instead of retaining snapshots.
  MarkstreamRenderer get _blockContent {
    if (theme.body.color == theme.colors.ink) return this;
    if (_blockContentRenderer == null) {
      _blockContentRenderer = MarkstreamRenderer(recognizerFor);
      _updateBlockContent();
    }
    return _blockContentRenderer!;
  }

  void _updateBlockContent() => _blockContentRenderer?.update(
    document: document,
    theme: theme.blockContentTheme,
    extensions: extensions,
    codeHighlighter: codeHighlighter,
    mathRenderer: mathRenderer,
    imageBuilder: imageBuilder,
    linkHandler: linkHandler,
    codeOptions: codeOptions,
    labels: labels,
    exporting: exporting,
    trackSelection: trackSelection,
    highlights: highlights,
  );

  MarkstreamRenderContext contextFor(BuildContext context, bool streaming) =>
      MarkstreamRenderContext(
        document: document,
        theme: theme,
        streaming: streaming,
        buildBlock: (node) => build(context, node, streaming: streaming),
        buildInline: (node, style) =>
            _inline.build(context, node, style, streaming: streaming),
      );

  RenderedInline inlineContent(
    BuildContext context,
    List<InlineNode> nodes,
    TextStyle style, {
    required bool streaming,
  }) {
    final projection = trackSelection ? <TextSegment>[] : null;
    return RenderedInline(
      span: TextSpan(
        style: style,
        children: [
          for (final node in nodes)
            _inline.build(
              context,
              node,
              style,
              streaming: streaming,
              projection: projection,
            ),
        ],
      ),
      segments: projection ?? const [],
    );
  }

  Widget inlineText(
    BuildContext context,
    MarkdownNode owner,
    List<InlineNode> nodes,
    TextStyle style, {
    required bool streaming,
  }) {
    if (nodes.any(
      (node) => node is HtmlElementNode && htmlBlockTags.contains(node.tag),
    )) {
      return htmlFlow(context, nodes, style, streaming: streaming);
    }
    final content = inlineContent(context, nodes, style, streaming: streaming);
    final child = StreamingText(
      streaming: streaming,
      text: Text.rich(content.span, style: style),
    );
    return !trackSelection
        ? child
        : MarkstreamSelectionFragment(
            node: owner,
            segments: content.segments,
            child: child,
          );
  }

  Widget children(
    BuildContext context,
    List<BlockNode> nodes, {
    required bool streaming,
    double? spacing,
    TextStyle? firstStyle,
    TextStyle? style,
    int listDepth = 0,
  }) {
    final visible = nodes
        .where((node) => node is! ReferenceDefinitionNode)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < visible.length; i++)
          Padding(
            key: ValueKey(visible[i].span.start),
            padding: EdgeInsets.only(
              top: i == 0
                  ? 0
                  : visible[i - 1] is HeadingNode
                  ? math.min(spacing ?? theme.blockSpacing, 8)
                  : spacing ?? theme.blockSpacing,
            ),
            child: build(
              context,
              visible[i],
              streaming: streaming && identical(visible[i], nodes.last),
              style: i == 0 ? firstStyle ?? style : style,
              listDepth: listDepth,
            ),
          ),
      ],
    );
  }

  Widget build(
    BuildContext context,
    BlockNode node, {
    required bool streaming,
    TextStyle? style,
    int listDepth = 0,
  }) => DocumentSelectionGroup(
    node: node,
    separator: node is ListNode ? '\n' : '\n\n',
    prefix: node is TaskItemNode
        ? '${node.radio ? '(' : '['}${node.checked ? 'x' : ' '}${node.radio ? ')' : ']'} '
        : '',
    child: _build(
      context,
      node,
      streaming: streaming,
      style: style,
      listDepth: listDepth,
    ),
  );

  Widget _build(
    BuildContext context,
    BlockNode node, {
    required bool streaming,
    TextStyle? style,
    int listDepth = 0,
  }) {
    final custom = extensions.blockBuilderFor(node);
    if (custom != null) {
      final child = custom(context, node, contextFor(context, streaming));
      // Code extensions use MarkstreamCodeContent, which paints exact ranges.
      return node is CodeBlockNode ? child : highlights.atom(node.span, child);
    }
    final body = style ?? theme.body;
    if (node is CodeBlockNode)
      return MarkstreamCodeBlock(
        node: node,
        theme: theme,
        extensions: extensions,
        options: codeOptions,
        labels: labels,
        highlighter: codeHighlighter,
        streaming: streaming,
        exporting: exporting,
      );
    if (node is HtmlBlockNode && node.fullDocument)
      return build(
        context,
        CodeBlockNode(
          span: node.span,
          children: node.rawFragments,
          info: 'html',
          closed: node.closed,
        ),
        streaming: streaming,
      );
    if (node is HtmlBlockNode)
      return inlineText(
        context,
        node,
        node.children,
        body,
        streaming: streaming,
      );
    if (node is TableNode)
      return MarkstreamTableBlock(
        node: node,
        source: node.span.slice(document.source),
        theme: theme,
        extensions: extensions,
        labels: labels,
        streaming: streaming,
        exporting: exporting,
        buildCell: (context, cell, style) => _blockContent.inlineText(
          context,
          cell,
          cell.children,
          style,
          streaming: streaming,
        ),
      );
    if (node is MathBlockNode)
      return MarkstreamMathBlock(
        node: node,
        tex: node.tex,
        theme: theme,
        renderer: mathRenderer,
      );
    if (node is DetailsNode) {
      final summary = node.children.whereType<DetailsSummaryNode>().firstOrNull;
      return MarkstreamDetailsBlock(
        node: node,
        open: node.open,
        source: node.span.slice(document.source),
        theme: theme,
        summary: summary == null
            ? SelectionContainer.disabled(
                child: Text(labels.details, style: theme.details.summary),
              )
            : _blockContent.inlineText(
                context,
                summary,
                summary.children,
                theme.details.summary,
                streaming: streaming,
              ),
        body: (context) => _blockContent.children(
          context,
          node.children.where((child) => child is! DetailsSummaryNode).toList(),
          streaming: streaming,
          style: body.copyWith(color: theme.colors.ink2),
          listDepth: listDepth,
        ),
      );
    }
    if (node is DetailsSummaryNode)
      return inlineText(
        context,
        node,
        node.children,
        theme.details.summary,
        streaming: streaming,
      );
    if (node is ParagraphNode)
      return inlineText(
        context,
        node,
        node.children,
        body,
        streaming: streaming,
      );
    if (node is HeadingNode)
      return Padding(
        padding: theme.headingPadding,
        child: Semantics(
          header: true,
          child: inlineText(
            context,
            node,
            node.children,
            theme.headings[node.level - 1],
            streaming: streaming,
          ),
        ),
      );
    if (node is ThematicBreakNode)
      return Padding(
        padding: theme.rulePadding,
        child: ColoredBox(
          key: const ValueKey('markstream-rule'),
          color: theme.ruleColor,
          child: SizedBox(height: theme.ruleThickness, width: double.infinity),
        ),
      );
    if (node is BlockQuoteNode)
      return Padding(
        padding: theme.quote.margin,
        child: CustomPaint(
          key: const ValueKey('markstream-quote'),
          painter: _QuoteBar(theme.quote, Directionality.of(context)),
          child: Padding(
            padding: theme.quote.padding,
            child: DefaultTextStyle.merge(
              style: TextStyle(color: theme.quote.textColor),
              child: children(
                context,
                node.children,
                streaming: streaming,
                style: body.copyWith(color: theme.quote.textColor),
                listDepth: listDepth,
              ),
            ),
          ),
        ),
      );
    if (node is ListNode) {
      final b = theme.body.fontSize!;
      final markerWidth = node.ordered
          ? (node.start + node.children.length - 1).toString().length *
                    .62 *
                    b +
                .5 * b
          : 20.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < node.children.length; i++)
            Padding(
              key: ValueKey(node.children[i].span.start),
              padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
              child: DocumentSelectionGroup(
                node: node.children[i],
                prefix:
                    '${node.ordered ? '${node.start + i}.' : '-'} ${node.children[i].checked == null
                        ? ''
                        : node.children[i].radio
                        ? '(${node.children[i].checked! ? 'x' : ' '}) '
                        : '[${node.children[i].checked! ? 'x' : ' '}] '}',
                continuation: '  ',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Padding(
                      padding: theme.listMarkerPadding,
                      child: SelectionContainer.disabled(
                        child: node.children[i].checked == null
                            ? SizedBox(
                                width: node.ordered
                                    ? MediaQuery.textScalerOf(
                                        context,
                                      ).scale(markerWidth)
                                    : markerWidth,
                                child: Text(
                                  node.ordered
                                      ? '${node.start + i}.'
                                      : const ['•', '◦', '▪'][listDepth % 3],
                                  textAlign: node.ordered
                                      ? TextAlign.end
                                      : TextAlign.center,
                                  style: body.copyWith(
                                    color: theme.proseInk.withValues(
                                      alpha: theme.colors.ink3.a,
                                    ),
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              )
                            : _TaskIndicator(
                                checked: node.children[i].checked!,
                                radio: node.children[i].radio,
                                theme: theme.task,
                                opticalCenter: theme.inlineCode.opticalCenter,
                              ),
                      ),
                    ),
                    Expanded(
                      child: children(
                        context,
                        node.children[i].children,
                        streaming: streaming && i == node.children.length - 1,
                        spacing: node.tight ? 0 : theme.blockSpacing,
                        listDepth: listDepth + 1,
                        style: body,
                        firstStyle: node.children[i].checked == true
                            ? theme.task.checkedText
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    if (node is TaskItemNode)
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Padding(
            padding: theme.listMarkerPadding,
            child: SelectionContainer.disabled(
              child: _TaskIndicator(
                checked: node.checked,
                radio: node.radio,
                theme: theme.task,
                opticalCenter: theme.inlineCode.opticalCenter,
              ),
            ),
          ),
          Expanded(
            child: inlineText(
              context,
              node,
              node.children,
              node.checked ? theme.task.checkedText : body,
              streaming: streaming,
            ),
          ),
        ],
      );
    if (node is ListItemNode)
      return children(context, node.children, streaming: streaming);
    if (node is ReferenceDefinitionNode) return const SizedBox.shrink();
    if (node is NamedBlockNode) {
      final kind = node.name.toLowerCase();
      final content = children(context, node.children, streaming: streaming);
      if (!MarkstreamDirectiveCard.kinds.contains(kind)) return content;
      final title =
          node.attributes['title'] ??
          switch (kind) {
            'tip' => labels.tip,
            'important' => labels.important,
            'warning' => labels.warning,
            'caution' => labels.caution,
            'danger' => labels.danger,
            _ => labels.note,
          };
      return MarkstreamDirectiveCard(
        kind: kind,
        title: title,
        theme: theme,
        child: content,
      );
    }
    if (node is DirectiveLabelNode)
      return inlineText(
        context,
        node,
        node.children,
        body,
        streaming: streaming,
      );
    // Unregistered leaf types remain readable and expose an atomic projection.
    final text = toPlainText(node);
    final child = StreamingText(
      streaming: streaming,
      text: Text(text, style: body),
    );
    return trackSelection
        ? MarkstreamSelectionFragment(
            node: node,
            segments: [
              TextSegment(text: text, sourceSpan: node.span, node: node),
            ],
            child: child,
          )
        : child;
  }
}

class _QuoteBar extends CustomPainter {
  const _QuoteBar(this.theme, this.direction);
  final QuoteTheme theme;
  final TextDirection direction;
  @override
  void paint(Canvas canvas, Size size) {
    final left = direction == TextDirection.ltr
        ? 0.0
        : size.width - theme.barWidth;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, theme.barWidth, size.height),
        Radius.circular(theme.barRadius),
      ),
      Paint()..color = theme.barColor,
    );
  }

  @override
  bool shouldRepaint(_QuoteBar oldDelegate) =>
      oldDelegate.theme != theme || oldDelegate.direction != direction;
}

class _TaskIndicator extends StatelessWidget {
  const _TaskIndicator({
    required this.checked,
    required this.radio,
    required this.theme,
    required this.opticalCenter,
  });
  final bool checked;
  final bool radio;
  final TaskTheme theme;
  final double opticalCenter;
  @override
  Widget build(BuildContext context) => Semantics(
    checked: checked,
    inMutuallyExclusiveGroup: radio,
    child: OpticalBaseline(
      center: MediaQuery.textScalerOf(context).scale(opticalCenter),
      child: SizedBox(
        width: 22,
        child: Center(
          heightFactor: 1,
          child: SizedBox.square(
            key: ValueKey(
              radio
                  ? 'markstream-radio-indicator'
                  : 'markstream-task-indicator',
            ),
            dimension: theme.size,
            child: CustomPaint(painter: _TaskPaint(checked, radio, theme)),
          ),
        ),
      ),
    ),
  );
}

class _TaskPaint extends CustomPainter {
  const _TaskPaint(this.checked, this.radio, this.theme);
  final bool checked;
  final bool radio;
  final TaskTheme theme;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(theme.strokeWidth / 2);
    final outline = RRect.fromRectAndRadius(
      rect,
      Radius.circular(radio ? size.width / 2 : theme.radius),
    );
    if (checked)
      canvas.drawRRect(outline, Paint()..color = theme.selectedColor);
    canvas.drawRRect(
      outline,
      Paint()
        ..color = checked ? theme.selectedColor : theme.borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = theme.strokeWidth,
    );
    if (!checked) return;
    if (radio) {
      canvas.drawCircle(
        size.center(Offset.zero),
        3,
        Paint()..color = theme.checkColor,
      );
    } else {
      final offset = (size.width - theme.checkSize) / 2;
      final path = Path()
        ..moveTo(offset + theme.checkSize * .15, offset + theme.checkSize * .5)
        ..lineTo(offset + theme.checkSize * .4, offset + theme.checkSize * .75)
        ..lineTo(offset + theme.checkSize * .9, offset + theme.checkSize * .2);
      canvas.drawPath(
        path,
        Paint()
          ..color = theme.checkColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_TaskPaint oldDelegate) =>
      oldDelegate.checked != checked ||
      oldDelegate.radio != radio ||
      oldDelegate.theme != theme;
}
