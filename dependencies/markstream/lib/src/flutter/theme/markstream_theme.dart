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
      identical(this, other) ||
      (other.runtimeType == runtimeType &&
          other is _ThemeTokens &&
          listEquals(_values, other._values));
  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(_values));
}

enum MarkstreamBackdrop { plain, wallpaper, frostedBubble, solidBubble }

@Deprecated('unused; see MarkstreamBackdrop')
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

final class MarkstreamColors extends _ThemeTokens {
  MarkstreamColors({
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.border,
    required this.divider,
    required this.borderStrong,
    required this.fillBlock,
    required this.fillBlockOpaque,
    required this.fillRaised,
    required this.fillHead,
    required this.fillInline,
    required this.quoteBar,
    required this.accent,
    required this.surface,
    required this.tip,
    required this.warning,
    required this.danger,
    required this.important,
  }) : _values = [
         ink,
         ink2,
         ink3,
         border,
         divider,
         borderStrong,
         fillBlock,
         fillBlockOpaque,
         fillRaised,
         fillHead,
         fillInline,
         quoteBar,
         accent,
         surface,
         tip,
         warning,
         danger,
         important,
       ];
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color border;
  final Color divider;
  final Color borderStrong;
  final Color fillBlock;
  final Color fillBlockOpaque;
  final Color fillRaised;
  final Color fillHead;
  final Color fillInline;
  final Color quoteBar;
  final Color accent;
  final Color surface;
  final Color tip;
  final Color warning;
  final Color danger;
  final Color important;
  MarkstreamColors copyWith({
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? border,
    Color? divider,
    Color? borderStrong,
    Color? fillBlock,
    Color? fillBlockOpaque,
    Color? fillRaised,
    Color? fillHead,
    Color? fillInline,
    Color? quoteBar,
    Color? accent,
    Color? surface,
    Color? tip,
    Color? warning,
    Color? danger,
    Color? important,
  }) => MarkstreamColors(
    ink: ink ?? this.ink,
    ink2: ink2 ?? this.ink2,
    ink3: ink3 ?? this.ink3,
    border: border ?? this.border,
    divider: divider ?? this.divider,
    borderStrong: borderStrong ?? this.borderStrong,
    fillBlock: fillBlock ?? this.fillBlock,
    fillBlockOpaque: fillBlockOpaque ?? this.fillBlockOpaque,
    fillRaised: fillRaised ?? this.fillRaised,
    fillHead: fillHead ?? this.fillHead,
    fillInline: fillInline ?? this.fillInline,
    quoteBar: quoteBar ?? this.quoteBar,
    accent: accent ?? this.accent,
    surface: surface ?? this.surface,
    tip: tip ?? this.tip,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    important: important ?? this.important,
  );
  @override
  final List<Object?> _values;
}

final class MarkstreamChromeTheme extends _ThemeTokens {
  MarkstreamChromeTheme({
    required this.height,
    required this.padding,
    required this.background,
    required this.divider,
    required this.label,
    required this.actionSize,
    required this.actionIconSize,
    required this.actionColor,
    required this.actionRadius,
  }) : _values = [
         height,
         padding,
         background,
         divider,
         label,
         actionSize,
         actionIconSize,
         actionColor,
         actionRadius,
       ];
  final double height;
  final EdgeInsetsGeometry padding;
  final Color background;
  final Color divider;
  final TextStyle label;
  final double actionSize;
  final double actionIconSize;
  final Color actionColor;
  final double actionRadius;
  MarkstreamChromeTheme copyWith({
    double? height,
    EdgeInsetsGeometry? padding,
    Color? background,
    Color? divider,
    TextStyle? label,
    double? actionSize,
    double? actionIconSize,
    Color? actionColor,
    double? actionRadius,
  }) => MarkstreamChromeTheme(
    height: height ?? this.height,
    padding: padding ?? this.padding,
    background: background ?? this.background,
    divider: divider ?? this.divider,
    label: label ?? this.label,
    actionSize: actionSize ?? this.actionSize,
    actionIconSize: actionIconSize ?? this.actionIconSize,
    actionColor: actionColor ?? this.actionColor,
    actionRadius: actionRadius ?? this.actionRadius,
  );
  @override
  final List<Object?> _values;
}

final class InlineCodeTheme extends _ThemeTokens {
  const InlineCodeTheme({
    required this.opticalCenter,
    required this.text,
    required this.padding,
    required this.radius,
    required this.backgroundColor,
    required this.borderColor,
  });
  final double opticalCenter;
  final TextStyle text;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color backgroundColor;
  final Color borderColor;
  InlineCodeTheme copyWith({
    double? opticalCenter,
    TextStyle? text,
    EdgeInsetsGeometry? padding,
    double? radius,
    Color? backgroundColor,
    Color? borderColor,
  }) => InlineCodeTheme(
    opticalCenter: opticalCenter ?? this.opticalCenter,
    text: text ?? this.text,
    padding: padding ?? this.padding,
    radius: radius ?? this.radius,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    borderColor: borderColor ?? this.borderColor,
  );
  @override
  List<Object?> get _values => [
    opticalCenter,
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
    required this.textColor,
    required this.margin,
    required this.padding,
    required this.barWidth,
    required this.barRadius,
    required this.barColor,
  });
  final Color textColor;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final double barWidth;
  final double barRadius;
  final Color barColor;
  QuoteTheme copyWith({
    Color? textColor,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    double? barWidth,
    double? barRadius,
    Color? barColor,
  }) => QuoteTheme(
    textColor: textColor ?? this.textColor,
    margin: margin ?? this.margin,
    padding: padding ?? this.padding,
    barWidth: barWidth ?? this.barWidth,
    barRadius: barRadius ?? this.barRadius,
    barColor: barColor ?? this.barColor,
  );
  @override
  List<Object?> get _values => [
    textColor,
    margin,
    padding,
    barWidth,
    barRadius,
    barColor,
  ];
}

final class TaskTheme extends _ThemeTokens {
  const TaskTheme({
    required this.strokeWidth,
    required this.size,
    required this.radius,
    required this.borderColor,
    required this.selectedColor,
    required this.checkColor,
    required this.checkSize,
    required this.checkedText,
  });
  final double strokeWidth;
  final double size;
  final double radius;
  final Color borderColor;
  final Color selectedColor;
  final Color checkColor;
  final double checkSize;
  final TextStyle checkedText;
  TaskTheme copyWith({
    double? strokeWidth,
    double? size,
    double? radius,
    Color? borderColor,
    Color? selectedColor,
    Color? checkColor,
    double? checkSize,
    TextStyle? checkedText,
  }) => TaskTheme(
    strokeWidth: strokeWidth ?? this.strokeWidth,
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
    strokeWidth,
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
    required this.outerBorderColor,
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
  final Color outerBorderColor;
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
    Color? outerBorderColor,
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
    outerBorderColor: outerBorderColor ?? this.outerBorderColor,
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
    outerBorderColor,
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
    required this.contentPadding,
    required this.margin,
    required this.radius,
    required this.backgroundColor,
    required this.borderColor,
    required this.summary,
    required this.summaryPadding,
    required this.chevronSize,
    required this.chevronDuration,
  });
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final Color backgroundColor;
  final Color borderColor;
  final TextStyle summary;
  final EdgeInsetsGeometry summaryPadding;
  final double chevronSize;
  final Duration chevronDuration;
  DetailsTheme copyWith({
    EdgeInsetsGeometry? contentPadding,
    EdgeInsetsGeometry? margin,
    double? radius,
    Color? backgroundColor,
    Color? borderColor,
    TextStyle? summary,
    EdgeInsetsGeometry? summaryPadding,
    double? chevronSize,
    Duration? chevronDuration,
  }) => DetailsTheme(
    contentPadding: contentPadding ?? this.contentPadding,
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
    contentPadding,
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
  static const radiusXs = 4.0, radiusSm = 6.0, radiusMd = 12.0;
  static const stroke = 1.0;
  MarkstreamTheme({
    this.backdrop = MarkstreamBackdrop.plain,
    required this.chrome,
    required this.colors,
    required this.brightness,
    required this.body,
    required this.strongWeight,
    required List<TextStyle> headings,
    required this.headingPadding,
    required this.blockSpacing,
    required this.link,
    required this.inlineCode,
    required this.keyboard,
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
  final MarkstreamBackdrop backdrop;
  final MarkstreamChromeTheme chrome;
  final MarkstreamColors colors;
  final Brightness brightness;
  final TextStyle body;
  final FontWeight strongWeight;
  final List<TextStyle> headings;
  final EdgeInsetsGeometry headingPadding;
  final double blockSpacing;
  final TextStyle link;
  final InlineCodeTheme inlineCode;
  final InlineCodeTheme keyboard;
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

  /// Foreground for content painted directly on the surrounding message.
  Color get proseInk => backdrop == MarkstreamBackdrop.plain
      ? colors.ink
      : body.color ?? colors.ink;

  /// Paragraphs and nested markup inside a painted block share its ink.
  MarkstreamTheme get blockContentTheme {
    if (body.color == colors.ink) return this;
    final quoteBar = colors.ink.withValues(alpha: colors.quoteBar.a);
    return copyWith(
      colors: colors.copyWith(quoteBar: quoteBar),
      body: body.copyWith(color: colors.ink),
      headings: [
        for (var i = 0; i < headings.length; i++)
          headings[i].copyWith(color: i == 5 ? colors.ink2 : colors.ink),
      ],
      quote: quote.copyWith(textColor: colors.ink2, barColor: quoteBar),
      task: task.copyWith(
        borderColor: colors.borderStrong,
        checkedText: task.checkedText.copyWith(
          color: colors.ink3,
          decorationColor: colors.ink3,
        ),
      ),
      ruleColor: colors.border,
    );
  }

  MarkstreamTheme copyWith({
    MarkstreamBackdrop? backdrop,
    MarkstreamChromeTheme? chrome,
    MarkstreamColors? colors,
    Brightness? brightness,
    TextStyle? body,
    FontWeight? strongWeight,
    List<TextStyle>? headings,
    EdgeInsetsGeometry? headingPadding,
    double? blockSpacing,
    TextStyle? link,
    InlineCodeTheme? inlineCode,
    InlineCodeTheme? keyboard,
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
    backdrop: backdrop ?? this.backdrop,
    chrome: chrome ?? this.chrome,
    colors: colors ?? this.colors,
    brightness: brightness ?? this.brightness,
    body: body ?? this.body,
    strongWeight: strongWeight ?? this.strongWeight,
    headings: headings ?? this.headings,
    headingPadding: headingPadding ?? this.headingPadding,
    blockSpacing: blockSpacing ?? this.blockSpacing,
    link: link ?? this.link,
    inlineCode: inlineCode ?? this.inlineCode,
    keyboard: keyboard ?? this.keyboard,
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
    backdrop,
    chrome,
    colors,
    brightness,
    body,
    strongWeight,
    ...headings,
    headingPadding,
    blockSpacing,
    link,
    inlineCode,
    keyboard,
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
    MarkstreamBackdrop backdrop = MarkstreamBackdrop.plain,
    double maskStrength = 1,
    String codeFontFamily = 'monospace',
    bool desktop = false,
    FontWeight medium = FontWeight.w500,
    FontWeight semibold = FontWeight.w600,
    FontWeight strong = FontWeight.w700,
    bool cjk = false,
    MarkstreamFillAlphas fillAlphas = const MarkstreamFillAlphas(),
  }) {
    final dark = colors.brightness == Brightness.dark;
    // App adapters already resolve these defaults. Keep that immutable style
    // instead of allocating an identical copy for every theme construction.
    final body =
        bodyStyle != null &&
            bodyStyle.fontSize != null &&
            bodyStyle.height != null &&
            bodyStyle.letterSpacing != null &&
            bodyStyle.color != null
        ? bodyStyle
        : (bodyStyle ?? const TextStyle()).copyWith(
            fontSize: bodyStyle?.fontSize ?? 15.5,
            height: bodyStyle?.height ?? 1.55,
            letterSpacing: bodyStyle?.letterSpacing ?? (cjk ? 0 : .05),
            color: bodyStyle?.color ?? colors.onSurface,
          );
    final b = body.fontSize!;
    // Painted blocks keep their paired scheme ink even when translucent.
    // Text directly on the message bubble retains its inherited foreground.
    final on = colors.onSurface;
    final bodyInk = backdrop == MarkstreamBackdrop.plain ? on : body.color!;
    const white = Colors.white;
    final tint = dark ? white : on;
    final bodyTint = dark ? white : bodyInk;
    final surface = colors.surface;
    final opaque = Color.alphaBlend(
      white.withValues(alpha: dark ? .04 : .70),
      surface,
    );
    final wallpaper = backdrop == MarkstreamBackdrop.wallpaper;
    final translucent =
        wallpaper || backdrop == MarkstreamBackdrop.frostedBubble;
    final bubble =
        backdrop == MarkstreamBackdrop.frostedBubble ||
        backdrop == MarkstreamBackdrop.solidBubble;
    final lowMask = 1 - maskStrength.clamp(0.0, 1.0);
    final fillBlock = switch (backdrop) {
      MarkstreamBackdrop.plain => opaque,
      MarkstreamBackdrop.wallpaper => surface.withValues(
        alpha: (dark ? .74 : .80) + .10 * lowMask,
      ),
      MarkstreamBackdrop.frostedBubble => surface.withValues(
        alpha: dark ? .36 : .42,
      ),
      MarkstreamBackdrop.solidBubble => tint.withValues(
        alpha: dark ? .05 : .035,
      ),
    };
    final palette = MarkstreamColors(
      ink: on,
      ink2: on.withValues(alpha: dark ? .70 : .72),
      ink3: on.withValues(
        alpha: translucent ? (dark ? .58 : .60) : (dark ? .48 : .50),
      ),
      border: tint.withValues(
        alpha: bubble ? (dark ? .14 : .12) : (wallpaper && dark ? .12 : .10),
      ),
      divider: tint.withValues(
        alpha: bubble || (wallpaper && dark) ? .08 : .07,
      ),
      borderStrong: tint.withValues(alpha: dark ? .32 : .30),
      fillBlock: fillBlock,
      fillBlockOpaque: opaque,
      fillRaised: switch (backdrop) {
        MarkstreamBackdrop.plain => surface,
        MarkstreamBackdrop.wallpaper ||
        MarkstreamBackdrop.frostedBubble => surface.withValues(alpha: .92),
        MarkstreamBackdrop.solidBubble => tint.withValues(
          alpha: dark ? .14 : .10,
        ),
      },
      fillHead: tint.withValues(
        alpha: bubble
            ? (dark ? .07 : .05)
            : (dark ? .06 : (wallpaper ? .045 : .04)),
      ),
      fillInline: translucent
          ? Color.alphaBlend(
              tint.withValues(alpha: dark ? .10 : .07),
              fillBlock,
            )
          : tint.withValues(alpha: dark ? .10 : (bubble ? .07 : .06)),
      quoteBar: bodyTint.withValues(alpha: dark ? .20 : .14),
      accent: colors.primary,
      surface: surface,
      tip: Color(dark ? 0xff75dfa3 : 0xff16a34a),
      warning: Color(dark ? 0xffffd17b : 0xffb45309),
      danger: colors.error,
      important: colors.tertiary,
    );
    final mutedBodyInk = bodyInk.withValues(alpha: palette.ink2.a);
    final faintBodyInk = bodyInk.withValues(alpha: palette.ink3.a);
    final chrome = MarkstreamChromeTheme(
      height: 36,
      padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
      background: palette.fillHead,
      divider: palette.divider,
      label: body.copyWith(
        fontSize: 12.5,
        fontWeight: medium,
        // The translucent header adds another tint over the block fill.
        color: translucent ? on.withValues(alpha: .78) : palette.ink2,
        letterSpacing: .2,
        height: 1,
      ),
      actionSize: 28,
      actionIconSize: 15,
      actionColor: palette.ink3,
      actionRadius: 7,
    );
    final mono = TextStyle(
      fontSize: desktop ? 12.5 : 13,
      height: 1.55,
      color: palette.ink,
      fontFamily: codeFontFamily,
      fontFamilyFallback: body.fontFamilyFallback,
    );
    final inlineCode = InlineCodeTheme(
      text: mono.copyWith(
        fontSize: b * .86,
        height: 1,
        leadingDistribution: TextLeadingDistribution.even,
        color: palette.ink.withValues(alpha: .92),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      opticalCenter: b * .35,
      radius: radiusSm,
      backgroundColor: palette.fillInline,
      borderColor: Colors.transparent,
    );
    return MarkstreamTheme(
      backdrop: backdrop,
      colors: palette,
      chrome: chrome,
      brightness: colors.brightness,
      body: body,
      strongWeight: strong,
      headings: [
        body.copyWith(fontSize: b * 1.45, fontWeight: strong, height: 1.3),
        body.copyWith(fontSize: b * 1.27, fontWeight: semibold, height: 1.35),
        body.copyWith(fontSize: b * 1.13, fontWeight: semibold, height: 1.4),
        body.copyWith(fontSize: b, fontWeight: semibold, height: 1.45),
        body.copyWith(fontSize: b * .94, fontWeight: semibold, height: 1.45),
        body.copyWith(
          fontSize: b * .88,
          fontWeight: semibold,
          height: 1.45,
          color: mutedBodyInk,
        ),
      ],
      headingPadding: const EdgeInsets.only(top: 4),
      blockSpacing: b * .9,
      link: TextStyle(
        color: palette.accent,
        decoration: TextDecoration.underline,
        decorationColor: palette.accent.withValues(alpha: .35),
        decorationThickness: 1,
      ),
      inlineCode: inlineCode,
      keyboard: inlineCode.copyWith(
        radius: radiusXs,
        backgroundColor: backdrop == MarkstreamBackdrop.plain
            ? palette.fillBlock
            : palette.fillRaised,
        borderColor: palette.borderStrong,
      ),
      code: CodeBlockTheme(
        text: mono,
        label: chrome.label,
        margin: const EdgeInsets.symmetric(vertical: 4),
        headerPadding: const EdgeInsets.symmetric(horizontal: 12),
        radius: radiusMd,
        borderColor: palette.border,
        backgroundColor: palette.fillBlock,
        headerBackgroundColor: palette.fillHead,
        collapseDuration: const Duration(milliseconds: 220),
        fadeHeight: 24,
        virtualizedHeight: 420,
      ),
      quote: QuoteTheme(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsetsDirectional.only(start: 12),
        barWidth: 3,
        barRadius: 1.5,
        barColor: palette.quoteBar,
        textColor: mutedBodyInk,
      ),
      listMarkerPadding: const EdgeInsetsDirectional.only(end: 6),
      task: TaskTheme(
        size: 16,
        radius: radiusXs,
        strokeWidth: 1.5,
        borderColor: bodyTint.withValues(alpha: palette.borderStrong.a),
        selectedColor: colors.primary,
        checkColor: colors.onPrimary,
        checkSize: 10,
        checkedText: body.copyWith(
          decoration: TextDecoration.lineThrough,
          decorationColor: faintBodyInk,
          color: faintBodyInk,
        ),
      ),
      table: MarkdownTableTheme(
        heading: body.copyWith(
          fontSize: 13,
          height: 1.45,
          fontWeight: semibold,
          color: palette.ink,
        ),
        body: body.copyWith(
          fontSize: 13.5,
          height: 1.45,
          color: palette.ink.withValues(alpha: .88),
        ),
        cellPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderColor: palette.divider,
        outerBorderColor: palette.border,
        headerBackgroundColor: palette.fillHead,
        bodyBackgroundColor: palette.fillBlock,
        compactBreakpoint: 520,
        compactRadius: radiusMd,
        wideRadius: radiusMd,
        toolbarHeight: chrome.height,
        singleColumnMinWidth: 220,
        singleColumnMaxWidth: 360,
        columnMinWidth: 112,
        columnMaxWidth: 178,
        visibleColumns: 2.45,
      ),
      rulePadding: const EdgeInsets.symmetric(vertical: 12),
      ruleThickness: stroke,
      ruleColor: bodyTint.withValues(alpha: palette.border.a),
      imageRadius: radiusMd,
      inlineMathScale: 1.1,
      mathPadding: const EdgeInsets.symmetric(vertical: 8),
      details: DetailsTheme(
        margin: const EdgeInsets.symmetric(vertical: 4),
        radius: radiusMd,
        backgroundColor: palette.fillBlock,
        borderColor: palette.border,
        summary: body.copyWith(fontWeight: medium, color: palette.ink),
        summaryPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        chevronSize: 14,
        chevronDuration: const Duration(milliseconds: 160),
      ),
      fillAlphas: fillAlphas,
    );
  }
}
