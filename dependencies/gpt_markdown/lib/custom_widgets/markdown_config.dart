import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// A builder function for the ordered list.
typedef OrderedListBuilder =
    Widget Function(
      BuildContext context,
      String no,
      Widget child,
      GptMarkdownConfig config,
    );

/// A builder function for the unordered list.
typedef UnOrderedListBuilder =
    Widget Function(
      BuildContext context,
      Widget child,
      GptMarkdownConfig config,
    );

/// A builder function for the source tag.
typedef SourceTagBuilder =
    Widget Function(BuildContext context, String content, TextStyle textStyle);

/// A builder function for the code block.
typedef CodeBlockBuilder =
    Widget Function(
      BuildContext context,
      String name,
      String code,
      bool closed,
    );

/// A builder function for the LaTeX.
typedef LatexBuilder =
    Widget Function(
      BuildContext context,
      String tex,
      TextStyle textStyle,
      bool inline,
    );

/// A builder function for the link.
typedef LinkBuilder =
    Widget Function(
      BuildContext context,
      InlineSpan text,
      String url,
      TextStyle style,
    );

/// A builder function for the table.
typedef TableBuilder =
    Widget Function(
      BuildContext context,
      List<CustomTableRow> tableRows,
      TextStyle textStyle,
      GptMarkdownConfig config,
    );

/// A builder function for the highlight.
typedef HighlightBuilder =
    Widget Function(BuildContext context, String text, TextStyle style);

/// A builder function for the image.
///
/// [width] and [height] come from the image alt text when parsed as `WxH`
/// (for example `![100x200](url)`); otherwise they are null.
typedef ImageBuilder =
    Widget Function(
      BuildContext context,
      String imageUrl,
      double? width,
      double? height,
    );

/// A configuration class for the GPT Markdown component.
///
/// The [GptMarkdownConfig] class is used to configure the GPT Markdown component.
/// It takes a [style] parameter to set the style of the text,
/// a [textDirection] parameter to set the direction of the text,
/// and an optional [onLinkTap] parameter to handle link clicks.
class GptMarkdownConfig {
  const GptMarkdownConfig({
    this.style,
    this.textDirection = TextDirection.ltr,
    this.onLinkTap,
    this.textAlign,
    this.textScaler,
    this.latexWorkaround,
    this.latexBuilder,
    this.followLinkColor = false,
    this.codeBuilder,
    this.sourceTagBuilder,
    this.highlightBuilder,
    this.orderedListBuilder,
    this.unOrderedListBuilder,
    this.linkBuilder,
    this.imageBuilder,
    this.maxLines,
    this.overflow,
    this.components,
    this.inlineComponents,
    this.tableBuilder,
    this.preprocessBlocks,
    this.generation,
    this.textBuilder,
    this.streaming = false,
    this.spanBuilder,
  });

  final Widget Function(Text text)? textBuilder;
  final bool streaming;

  /// Render a block already parsed by the caller without reparsing its source.
  final List<InlineSpan> Function(BuildContext, GptMarkdownConfig)? spanBuilder;

  /// The direction of the text.
  final TextDirection textDirection;

  /// The style of the text.
  final TextStyle? style;

  /// The alignment of the text.
  final TextAlign? textAlign;

  /// The text scaler.
  final TextScaler? textScaler;

  /// The callback function to handle link clicks.
  final void Function(String url, String title)? onLinkTap;

  /// The LaTeX workaround.
  final String Function(String tex)? latexWorkaround;

  /// The LaTeX builder.
  final LatexBuilder? latexBuilder;

  /// The source tag builder.
  final SourceTagBuilder? sourceTagBuilder;

  /// Whether to follow the link color.
  final bool followLinkColor;

  /// The code builder.
  final CodeBlockBuilder? codeBuilder;

  /// The Ordered List builder.
  final OrderedListBuilder? orderedListBuilder;

  /// The Unordered List builder.
  final UnOrderedListBuilder? unOrderedListBuilder;

  /// The maximum number of lines.
  final int? maxLines;

  /// The overflow.
  final TextOverflow? overflow;

  /// The highlight builder.
  final HighlightBuilder? highlightBuilder;

  /// The link builder.
  final LinkBuilder? linkBuilder;

  /// The image builder.
  final ImageBuilder? imageBuilder;

  /// The list of components.
  final List<MarkdownComponent>? components;

  /// The list of inline components.
  final List<MarkdownComponent>? inlineComponents;

  /// The table builder.
  final TableBuilder? tableBuilder;

  /// Rewrites a block-level fragment before [MarkdownComponent.generate]
  /// parses it. List items, quotes, and table cells all enter generate
  /// again, so this is the shared hook for deterministic preprocessing.
  final String Function(String text)? preprocessBlocks;

  /// Compared by [isSame] so a reused [MdWidget] regenerates when
  /// image/citation/theme inputs change without a new GptMarkdown key.
  final Object? generation;

  /// A copy of the configuration with the specified parameters.
  GptMarkdownConfig copyWith({
    TextStyle? style,
    TextDirection? textDirection,
    final void Function(String url, String title)? onLinkTap,
    final TextAlign? textAlign,
    final TextScaler? textScaler,
    final String Function(String tex)? latexWorkaround,
    final LatexBuilder? latexBuilder,
    final SourceTagBuilder? sourceTagBuilder,
    final bool? followLinkColor,
    final CodeBlockBuilder? codeBuilder,
    final int? maxLines,
    final TextOverflow? overflow,
    final HighlightBuilder? highlightBuilder,
    final LinkBuilder? linkBuilder,
    final ImageBuilder? imageBuilder,
    final OrderedListBuilder? orderedListBuilder,
    final UnOrderedListBuilder? unOrderedListBuilder,
    final List<MarkdownComponent>? components,
    final List<MarkdownComponent>? inlineComponents,
    final TableBuilder? tableBuilder,
    final String Function(String text)? preprocessBlocks,
    final Object? generation,
  }) {
    return GptMarkdownConfig(
      style: style ?? this.style,
      textDirection: textDirection ?? this.textDirection,
      onLinkTap: onLinkTap ?? this.onLinkTap,
      textAlign: textAlign ?? this.textAlign,
      textScaler: textScaler ?? this.textScaler,
      latexWorkaround: latexWorkaround ?? this.latexWorkaround,
      latexBuilder: latexBuilder ?? this.latexBuilder,
      followLinkColor: followLinkColor ?? this.followLinkColor,
      codeBuilder: codeBuilder ?? this.codeBuilder,
      sourceTagBuilder: sourceTagBuilder ?? this.sourceTagBuilder,
      maxLines: maxLines ?? this.maxLines,
      overflow: overflow ?? this.overflow,
      highlightBuilder: highlightBuilder ?? this.highlightBuilder,
      linkBuilder: linkBuilder ?? this.linkBuilder,
      imageBuilder: imageBuilder ?? this.imageBuilder,
      orderedListBuilder: orderedListBuilder ?? this.orderedListBuilder,
      unOrderedListBuilder: unOrderedListBuilder ?? this.unOrderedListBuilder,
      components: components ?? this.components,
      inlineComponents: inlineComponents ?? this.inlineComponents,
      tableBuilder: tableBuilder ?? this.tableBuilder,
      preprocessBlocks: preprocessBlocks ?? this.preprocessBlocks,
      generation: generation ?? this.generation,
      textBuilder: textBuilder,
      streaming: streaming,
      spanBuilder: spanBuilder,
    );
  }

  /// A method to get a rich text widget from an inline span.
  Text getRich(InlineSpan span) {
    return Text.rich(
      span,
      textDirection: textDirection,
      textScaler: textScaler,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  /// A method to check if the configuration is the same.
  bool isSame(GptMarkdownConfig other) {
    return (spanBuilder == null) == (other.spanBuilder == null) &&
        style == other.style &&
        textAlign == other.textAlign &&
        textScaler == other.textScaler &&
        maxLines == other.maxLines &&
        overflow == other.overflow &&
        followLinkColor == other.followLinkColor &&
        // latexWorkaround == other.latexWorkaround &&
        // components == other.components &&
        // inlineComponents == other.inlineComponents &&
        // latexBuilder == other.latexBuilder &&
        // sourceTagBuilder == other.sourceTagBuilder &&
        // codeBuilder == other.codeBuilder &&
        // orderedListBuilder == other.orderedListBuilder &&
        // unOrderedListBuilder == other.unOrderedListBuilder &&
        // linkBuilder == other.linkBuilder &&
        // imageBuilder == other.imageBuilder &&
        // highlightBuilder == other.highlightBuilder &&
        // onLinkTap == other.onLinkTap &&
        textDirection == other.textDirection &&
        generation == other.generation;
  }
}
