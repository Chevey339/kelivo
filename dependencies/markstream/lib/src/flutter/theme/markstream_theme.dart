import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Value equality keeps cached prefix widgets valid when an app reconstructs
// an equivalent theme during a streaming update.
@immutable
abstract class _ThemeTokens {
  const _ThemeTokens();
  List<Object?> get _values;
  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is _ThemeTokens &&
      listEquals(_values, other._values);
  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(_values));
}

final class MarkstreamFillAlphas extends _ThemeTokens {
  const MarkstreamFillAlphas({
    this.details = .55,
    this.inline = .40,
    this.table = .72,
    this.content = .80,
  });
  final double details, inline, table, content;
  @override
  List<Object?> get _values => [details, inline, table, content];
}

final class InlineCodeTheme extends _ThemeTokens {
  const InlineCodeTheme({
    required this.text,
    required this.padding,
    required this.radius,
    required this.backgroundColor,
    required this.borderColor,
  });
  final TextStyle text;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color backgroundColor;
  final Color borderColor;
  InlineCodeTheme copyWith({
    TextStyle? text,
    EdgeInsetsGeometry? padding,
    double? radius,
    Color? backgroundColor,
    Color? borderColor,
  }) => InlineCodeTheme(
    text: text ?? this.text,
    padding: padding ?? this.padding,
    radius: radius ?? this.radius,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    borderColor: borderColor ?? this.borderColor,
  );
  @override
  List<Object?> get _values => [
    text,
    padding,
    radius,
    backgroundColor,
    borderColor,
  ];
}

final class CodeBlockTheme extends _ThemeTokens {
  const CodeBlockTheme({
    required this.text,
    required this.label,
    required this.margin,
    required this.headerPadding,
    required this.radius,
    required this.borderColor,
    required this.backgroundColor,
    required this.headerBackgroundColor,
    required this.collapseDuration,
    required this.fadeHeight,
    required this.virtualizedHeight,
  });
  final TextStyle text;
  final TextStyle label;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry headerPadding;
  final double radius;
  final Color borderColor;
  final Color backgroundColor;
  final Color headerBackgroundColor;
  final Duration collapseDuration;
  final double fadeHeight;
  final double virtualizedHeight;
  CodeBlockTheme copyWith({
    TextStyle? text,
    TextStyle? label,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? headerPadding,
    double? radius,
    Color? borderColor,
    Color? backgroundColor,
    Color? headerBackgroundColor,
    Duration? collapseDuration,
    double? fadeHeight,
    double? virtualizedHeight,
  }) => CodeBlockTheme(
    text: text ?? this.text,
    label: label ?? this.label,
    margin: margin ?? this.margin,
    headerPadding: headerPadding ?? this.headerPadding,
    radius: radius ?? this.radius,
    borderColor: borderColor ?? this.borderColor,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    headerBackgroundColor: headerBackgroundColor ?? this.headerBackgroundColor,
    collapseDuration: collapseDuration ?? this.collapseDuration,
    fadeHeight: fadeHeight ?? this.fadeHeight,
    virtualizedHeight: virtualizedHeight ?? this.virtualizedHeight,
  );
  @override
  List<Object?> get _values => [
    text,
    label,
    margin,
    headerPadding,
    radius,
    borderColor,
    backgroundColor,
    headerBackgroundColor,
    collapseDuration,
    fadeHeight,
    virtualizedHeight,
  ];
}

final class QuoteTheme extends _ThemeTokens {
  const QuoteTheme({
    required this.margin,
    required this.padding,
    required this.barWidth,
    required this.barRadius,
    required this.barColor,
  });
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final double barWidth;
  final double barRadius;
  final Color barColor;
  QuoteTheme copyWith({
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    double? barWidth,
    double? barRadius,
    Color? barColor,
  }) => QuoteTheme(
    margin: margin ?? this.margin,
    padding: padding ?? this.padding,
    barWidth: barWidth ?? this.barWidth,
    barRadius: barRadius ?? this.barRadius,
    barColor: barColor ?? this.barColor,
  );
  @override
  List<Object?> get _values => [margin, padding, barWidth, barRadius, barColor];
}

final class TaskTheme extends _ThemeTokens {
  const TaskTheme({
    required this.size,
    required this.radius,
    required this.borderColor,
    required this.selectedColor,
    required this.checkColor,
    required this.checkSize,
    required this.checkedText,
  });
  final double size;
  final double radius;
  final Color borderColor;
  final Color selectedColor;
  final Color checkColor;
  final double checkSize;
  final TextStyle checkedText;
  TaskTheme copyWith({
    double? size,
    double? radius,
    Color? borderColor,
    Color? selectedColor,
    Color? checkColor,
    double? checkSize,
    TextStyle? checkedText,
  }) => TaskTheme(
    size: size ?? this.size,
    radius: radius ?? this.radius,
    borderColor: borderColor ?? this.borderColor,
    selectedColor: selectedColor ?? this.selectedColor,
    checkColor: checkColor ?? this.checkColor,
    checkSize: checkSize ?? this.checkSize,
    checkedText: checkedText ?? this.checkedText,
  );
  @override
  List<Object?> get _values => [
    size,
    radius,
    borderColor,
    selectedColor,
    checkColor,
    checkSize,
    checkedText,
  ];
}

final class MarkdownTableTheme extends _ThemeTokens {
  const MarkdownTableTheme({
    required this.heading,
    required this.body,
    required this.cellPadding,
    required this.borderColor,
    required this.headerBackgroundColor,
    required this.bodyBackgroundColor,
    required this.compactBreakpoint,
    required this.compactRadius,
    required this.wideRadius,
    required this.toolbarHeight,
    required this.singleColumnMinWidth,
    required this.singleColumnMaxWidth,
    required this.columnMinWidth,
    required this.columnMaxWidth,
    required this.visibleColumns,
  });
  final TextStyle heading;
  final TextStyle body;
  final EdgeInsetsGeometry cellPadding;
  final Color borderColor;
  final Color headerBackgroundColor;
  final Color bodyBackgroundColor;
  final double compactBreakpoint;
  final double compactRadius;
  final double wideRadius;
  final double toolbarHeight;
  final double singleColumnMinWidth;
  final double singleColumnMaxWidth;
  final double columnMinWidth;
  final double columnMaxWidth;
  final double visibleColumns;
  MarkdownTableTheme copyWith({
    TextStyle? heading,
    TextStyle? body,
    EdgeInsetsGeometry? cellPadding,
    Color? borderColor,
    Color? headerBackgroundColor,
    Color? bodyBackgroundColor,
    double? compactBreakpoint,
    double? compactRadius,
    double? wideRadius,
    double? toolbarHeight,
    double? singleColumnMinWidth,
    double? singleColumnMaxWidth,
    double? columnMinWidth,
    double? columnMaxWidth,
    double? visibleColumns,
  }) => MarkdownTableTheme(
    heading: heading ?? this.heading,
    body: body ?? this.body,
    cellPadding: cellPadding ?? this.cellPadding,
    borderColor: borderColor ?? this.borderColor,
    headerBackgroundColor: headerBackgroundColor ?? this.headerBackgroundColor,
    bodyBackgroundColor: bodyBackgroundColor ?? this.bodyBackgroundColor,
    compactBreakpoint: compactBreakpoint ?? this.compactBreakpoint,
    compactRadius: compactRadius ?? this.compactRadius,
    wideRadius: wideRadius ?? this.wideRadius,
    toolbarHeight: toolbarHeight ?? this.toolbarHeight,
    singleColumnMinWidth: singleColumnMinWidth ?? this.singleColumnMinWidth,
    singleColumnMaxWidth: singleColumnMaxWidth ?? this.singleColumnMaxWidth,
    columnMinWidth: columnMinWidth ?? this.columnMinWidth,
    columnMaxWidth: columnMaxWidth ?? this.columnMaxWidth,
    visibleColumns: visibleColumns ?? this.visibleColumns,
  );
  @override
  List<Object?> get _values => [
    heading,
    body,
    cellPadding,
    borderColor,
    headerBackgroundColor,
    bodyBackgroundColor,
    compactBreakpoint,
    compactRadius,
    wideRadius,
    toolbarHeight,
    singleColumnMinWidth,
    singleColumnMaxWidth,
    columnMinWidth,
    columnMaxWidth,
    visibleColumns,
  ];
}

final class DetailsTheme extends _ThemeTokens {
  const DetailsTheme({
    required this.margin,
    required this.radius,
    required this.backgroundColor,
    required this.borderColor,
    required this.summary,
    required this.summaryPadding,
    required this.chevronSize,
    required this.chevronDuration,
  });
  final EdgeInsetsGeometry margin;
  final double radius;
  final Color backgroundColor;
  final Color borderColor;
  final TextStyle summary;
  final EdgeInsetsGeometry summaryPadding;
  final double chevronSize;
  final Duration chevronDuration;
  DetailsTheme copyWith({
    EdgeInsetsGeometry? margin,
    double? radius,
    Color? backgroundColor,
    Color? borderColor,
    TextStyle? summary,
    EdgeInsetsGeometry? summaryPadding,
    double? chevronSize,
    Duration? chevronDuration,
  }) => DetailsTheme(
    margin: margin ?? this.margin,
    radius: radius ?? this.radius,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    borderColor: borderColor ?? this.borderColor,
    summary: summary ?? this.summary,
    summaryPadding: summaryPadding ?? this.summaryPadding,
    chevronSize: chevronSize ?? this.chevronSize,
    chevronDuration: chevronDuration ?? this.chevronDuration,
  );
  @override
  List<Object?> get _values => [
    margin,
    radius,
    backgroundColor,
    borderColor,
    summary,
    summaryPadding,
    chevronSize,
    chevronDuration,
  ];
}

final class MarkstreamTheme extends _ThemeTokens {
  MarkstreamTheme({
    required this.brightness,
    required this.body,
    required this.strongWeight,
    required List<TextStyle> headings,
    required this.headingPadding,
    required this.blockSpacing,
    required this.link,
    required this.inlineCode,
    required this.code,
    required this.quote,
    required this.listMarkerPadding,
    required this.task,
    required this.table,
    required this.rulePadding,
    required this.ruleThickness,
    required this.ruleColor,
    required this.imageRadius,
    required this.inlineMathScale,
    required this.mathPadding,
    required this.details,
    required this.fillAlphas,
  }) : assert(headings.length == 6),
       headings = List.unmodifiable(headings);
  final Brightness brightness;
  final TextStyle body;
  final FontWeight strongWeight;
  final List<TextStyle> headings;
  final EdgeInsetsGeometry headingPadding;
  final double blockSpacing;
  final TextStyle link;
  final InlineCodeTheme inlineCode;
  final CodeBlockTheme code;
  final QuoteTheme quote;
  final EdgeInsetsGeometry listMarkerPadding;
  final TaskTheme task;
  final MarkdownTableTheme table;
  final EdgeInsetsGeometry rulePadding;
  final double ruleThickness;
  final Color ruleColor;
  final double imageRadius;
  final double inlineMathScale;
  final EdgeInsetsGeometry mathPadding;
  final DetailsTheme details;
  final MarkstreamFillAlphas fillAlphas;
  MarkstreamTheme copyWith({
    Brightness? brightness,
    TextStyle? body,
    FontWeight? strongWeight,
    List<TextStyle>? headings,
    EdgeInsetsGeometry? headingPadding,
    double? blockSpacing,
    TextStyle? link,
    InlineCodeTheme? inlineCode,
    CodeBlockTheme? code,
    QuoteTheme? quote,
    EdgeInsetsGeometry? listMarkerPadding,
    TaskTheme? task,
    MarkdownTableTheme? table,
    EdgeInsetsGeometry? rulePadding,
    double? ruleThickness,
    Color? ruleColor,
    double? imageRadius,
    double? inlineMathScale,
    EdgeInsetsGeometry? mathPadding,
    DetailsTheme? details,
    MarkstreamFillAlphas? fillAlphas,
  }) => MarkstreamTheme(
    brightness: brightness ?? this.brightness,
    body: body ?? this.body,
    strongWeight: strongWeight ?? this.strongWeight,
    headings: headings ?? this.headings,
    headingPadding: headingPadding ?? this.headingPadding,
    blockSpacing: blockSpacing ?? this.blockSpacing,
    link: link ?? this.link,
    inlineCode: inlineCode ?? this.inlineCode,
    code: code ?? this.code,
    quote: quote ?? this.quote,
    listMarkerPadding: listMarkerPadding ?? this.listMarkerPadding,
    task: task ?? this.task,
    table: table ?? this.table,
    rulePadding: rulePadding ?? this.rulePadding,
    ruleThickness: ruleThickness ?? this.ruleThickness,
    ruleColor: ruleColor ?? this.ruleColor,
    imageRadius: imageRadius ?? this.imageRadius,
    inlineMathScale: inlineMathScale ?? this.inlineMathScale,
    mathPadding: mathPadding ?? this.mathPadding,
    details: details ?? this.details,
    fillAlphas: fillAlphas ?? this.fillAlphas,
  );
  @override
  List<Object?> get _values => [
    brightness,
    body,
    strongWeight,
    ...headings,
    headingPadding,
    blockSpacing,
    link,
    inlineCode,
    code,
    quote,
    listMarkerPadding,
    task,
    table,
    rulePadding,
    ruleThickness,
    ruleColor,
    imageRadius,
    inlineMathScale,
    mathPadding,
    details,
    fillAlphas,
  ];

  /// Defaults match Kelivo's Markdown geometry. Apps supply font families,
  /// platform-adjusted weights and an optional base style here.
  factory MarkstreamTheme.fromColorScheme(
    ColorScheme colors, {
    TextStyle? bodyStyle,
    String codeFontFamily = 'monospace',
    FontWeight medium = FontWeight.w500,
    FontWeight semibold = FontWeight.w600,
    FontWeight strong = FontWeight.w700,
    bool cjk = false,
    MarkstreamFillAlphas fillAlphas = const MarkstreamFillAlphas(),
  }) {
    final dark = colors.brightness == Brightness.dark;
    final body = (bodyStyle ?? const TextStyle()).copyWith(
      fontSize: bodyStyle?.fontSize ?? 15.5,
      height: bodyStyle?.height ?? 1.55,
      letterSpacing: bodyStyle?.letterSpacing ?? (cjk ? 0 : .05),
      color: bodyStyle?.color ?? colors.onSurface,
    );
    final ink = body.color ?? body.foreground?.color ?? colors.onSurface;
    final mono = TextStyle(
      fontSize: 13,
      height: 1.5,
      color: colors.onSurface,
      fontFamily: codeFontFamily,
      fontFamilyFallback: body.fontFamilyFallback,
    );
    final extremeOutline =
        colors.outlineVariant == Colors.black ||
        colors.outlineVariant == Colors.white;
    return MarkstreamTheme(
      brightness: colors.brightness,
      body: body,
      strongWeight: strong,
      headings: [
        body.copyWith(fontSize: 24, fontWeight: strong, height: 1.25),
        body.copyWith(fontSize: 20, fontWeight: semibold, height: 1.30),
        body.copyWith(fontSize: 18, fontWeight: semibold, height: 1.35),
        body.copyWith(fontSize: 16, fontWeight: medium),
        body.copyWith(fontSize: 15, fontWeight: medium),
        body.copyWith(fontSize: 14, fontWeight: medium),
      ],
      headingPadding: const EdgeInsets.symmetric(vertical: 2),
      blockSpacing: body.fontSize! * 1.15,
      link: TextStyle(color: colors.primary, decoration: TextDecoration.none),
      inlineCode: InlineCodeTheme(
        text: mono.copyWith(height: 1.4, color: body.color),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        radius: 6,
        backgroundColor: dark
            ? Colors.white12
            : const Color(0xFFF1F3F5).withValues(alpha: fillAlphas.inline),
        borderColor: colors.outlineVariant.withValues(alpha: .22),
      ),
      code: CodeBlockTheme(
        text: mono,
        label: body.copyWith(
          fontSize: 12,
          fontWeight: medium,
          color: colors.onSurfaceVariant.withValues(alpha: .72),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        headerPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        radius: 16,
        borderColor: extremeOutline
            ? Color.alphaBlend(
                colors.onSurfaceVariant.withValues(alpha: dark ? .32 : .24),
                colors.surface,
              )
            : colors.outlineVariant,
        backgroundColor: colors.surfaceContainer.withValues(
          alpha: fillAlphas.content,
        ),
        headerBackgroundColor: colors.surfaceContainerHighest.withValues(
          alpha: fillAlphas.content,
        ),
        collapseDuration: const Duration(milliseconds: 220),
        fadeHeight: 24,
        virtualizedHeight: 420,
      ),
      quote: QuoteTheme(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsetsDirectional.only(start: 13),
        barWidth: 3,
        barRadius: 2,
        barColor: colors.onSurfaceVariant.withValues(alpha: dark ? .48 : .36),
      ),
      listMarkerPadding: const EdgeInsetsDirectional.only(start: 6, end: 6),
      task: TaskTheme(
        size: 18,
        radius: 5,
        borderColor: colors.outlineVariant.withValues(alpha: .8),
        selectedColor: colors.primary.withValues(alpha: .12),
        checkColor: colors.primary,
        checkSize: 14,
        checkedText: body.copyWith(
          decoration: TextDecoration.lineThrough,
          color: ink.withValues(alpha: .75),
        ),
      ),
      table: MarkdownTableTheme(
        heading: body.copyWith(
          fontSize: 13,
          height: 1.42,
          fontWeight: semibold,
          color: colors.onSurface,
        ),
        body: body.copyWith(
          fontSize: 13.5,
          height: 1.42,
          color: colors.onSurface.withValues(alpha: .90),
        ),
        cellPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        borderColor: colors.outlineVariant.withValues(alpha: dark ? .22 : .30),
        headerBackgroundColor: Color.alphaBlend(
          colors.primary.withValues(alpha: dark ? .15 : .07),
          colors.surface,
        ).withValues(alpha: fillAlphas.table),
        bodyBackgroundColor: Color.alphaBlend(
          colors.primary.withValues(alpha: dark ? .04 : .015),
          colors.surface,
        ).withValues(alpha: fillAlphas.table),
        compactBreakpoint: 520,
        compactRadius: 12,
        wideRadius: 10,
        toolbarHeight: 38,
        singleColumnMinWidth: 220,
        singleColumnMaxWidth: 360,
        columnMinWidth: 112,
        columnMaxWidth: 178,
        visibleColumns: 2.45,
      ),
      rulePadding: const EdgeInsets.symmetric(vertical: 10),
      ruleThickness: 1,
      ruleColor: colors.outlineVariant.withValues(alpha: .40),
      imageRadius: 8,
      inlineMathScale: 1.2,
      mathPadding: const EdgeInsets.symmetric(vertical: 4),
      details: DetailsTheme(
        margin: const EdgeInsets.symmetric(vertical: 4),
        radius: 16,
        backgroundColor: Color.alphaBlend(
          colors.onSurface.withValues(alpha: dark ? .05 : .025),
          colors.surface,
        ).withValues(alpha: fillAlphas.details),
        borderColor: colors.outlineVariant.withValues(alpha: dark ? .18 : .30),
        summary: body.copyWith(fontWeight: medium),
        summaryPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        chevronSize: 15,
        chevronDuration: const Duration(milliseconds: 160),
      ),
      fillAlphas: fillAlphas,
    );
  }
}
