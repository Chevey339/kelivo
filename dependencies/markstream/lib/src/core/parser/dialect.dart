/// Independently configurable Markdown syntax, defaulting to the LLM dialect.
final class ParserOptions {
  const ParserOptions({
    this.plusListMarker = true,
    this.unicodeLineBreaks = true,
    this.orderedParenthesis = true,
    this.tablePipesOptional = true,
    this.maxInlineMathLength = 512,
    this.inlineMath = true,
    this.dollarInlineMath = true,
    this.strikethrough = true,
    this.highlight = true,
    this.inlineHtml = true,
    this.softBreakAsHardBreak = true,
    this.underscoreEmphasis = true,
    this.autolinks = true,
    this.entities = true,
    this.cjkFlankingRelax = true,
    this.alerts = true,
    this.directives = true,
    this.htmlBlocks = true,
    this.tables = true,
    this.details = true,
    this.taskItems = true,
    this.standaloneTaskLine = true,
    this.radioItems = true,
    this.mathBlocks = true,
    this.setextHeadings = false,
    this.indentedCode = false,
    this.relaxedListIndentation = true,
  }) : assert(maxInlineMathLength > 0);

  const ParserOptions.llm() : this();

  const ParserOptions.commonMark()
    : plusListMarker = true,
      unicodeLineBreaks = false,
      orderedParenthesis = true,
      tablePipesOptional = true,
      maxInlineMathLength = 512,
      inlineMath = false,
      dollarInlineMath = false,
      strikethrough = false,
      highlight = false,
      inlineHtml = true,
      softBreakAsHardBreak = false,
      underscoreEmphasis = true,
      autolinks = false,
      entities = true,
      cjkFlankingRelax = false,
      alerts = false,
      directives = false,
      htmlBlocks = true,
      tables = false,
      details = false,
      taskItems = false,
      standaloneTaskLine = false,
      radioItems = false,
      mathBlocks = false,
      setextHeadings = true,
      indentedCode = true,
      relaxedListIndentation = false;

  const ParserOptions.gfm()
    : plusListMarker = true,
      unicodeLineBreaks = false,
      orderedParenthesis = true,
      tablePipesOptional = true,
      maxInlineMathLength = 512,
      inlineMath = false,
      dollarInlineMath = false,
      strikethrough = true,
      highlight = false,
      inlineHtml = true,
      softBreakAsHardBreak = false,
      underscoreEmphasis = true,
      autolinks = true,
      entities = true,
      cjkFlankingRelax = false,
      alerts = false,
      directives = false,
      htmlBlocks = true,
      tables = true,
      details = false,
      taskItems = true,
      standaloneTaskLine = false,
      radioItems = false,
      mathBlocks = false,
      setextHeadings = true,
      indentedCode = true,
      relaxedListIndentation = false;

  /// Treat LS and PS as line boundaries in the LLM dialect.
  final bool unicodeLineBreaks;
  final bool plusListMarker;
  final bool orderedParenthesis;
  final bool tablePipesOptional;
  final int maxInlineMathLength;
  final bool inlineMath;

  /// Single-dollar inline math; parenthesized and display math stay independent.
  final bool dollarInlineMath;
  final bool strikethrough;
  final bool highlight;
  final bool inlineHtml;
  final bool softBreakAsHardBreak;
  final bool underscoreEmphasis;
  final bool autolinks;
  final bool entities;
  final bool cjkFlankingRelax;
  final bool alerts;
  final bool directives;
  final bool htmlBlocks;
  final bool tables;
  final bool details;
  final bool taskItems;
  final bool standaloneTaskLine;
  final bool radioItems;
  final bool mathBlocks;
  final bool setextHeadings;
  final bool indentedCode;
  final bool relaxedListIndentation;

  ParserOptions copyWith({
    bool? plusListMarker,
    bool? unicodeLineBreaks,
    bool? orderedParenthesis,
    bool? tablePipesOptional,
    int? maxInlineMathLength,
    bool? inlineMath,
    bool? dollarInlineMath,
    bool? strikethrough,
    bool? highlight,
    bool? inlineHtml,
    bool? softBreakAsHardBreak,
    bool? underscoreEmphasis,
    bool? autolinks,
    bool? entities,
    bool? cjkFlankingRelax,
    bool? alerts,
    bool? directives,
    bool? htmlBlocks,
    bool? tables,
    bool? details,
    bool? taskItems,
    bool? standaloneTaskLine,
    bool? radioItems,
    bool? mathBlocks,
    bool? setextHeadings,
    bool? indentedCode,
    bool? relaxedListIndentation,
  }) => ParserOptions(
    plusListMarker: plusListMarker ?? this.plusListMarker,
    unicodeLineBreaks: unicodeLineBreaks ?? this.unicodeLineBreaks,
    orderedParenthesis: orderedParenthesis ?? this.orderedParenthesis,
    tablePipesOptional: tablePipesOptional ?? this.tablePipesOptional,
    maxInlineMathLength: maxInlineMathLength ?? this.maxInlineMathLength,
    inlineMath: inlineMath ?? this.inlineMath,
    dollarInlineMath: dollarInlineMath ?? this.dollarInlineMath,
    strikethrough: strikethrough ?? this.strikethrough,
    highlight: highlight ?? this.highlight,
    inlineHtml: inlineHtml ?? this.inlineHtml,
    softBreakAsHardBreak: softBreakAsHardBreak ?? this.softBreakAsHardBreak,
    underscoreEmphasis: underscoreEmphasis ?? this.underscoreEmphasis,
    autolinks: autolinks ?? this.autolinks,
    entities: entities ?? this.entities,
    cjkFlankingRelax: cjkFlankingRelax ?? this.cjkFlankingRelax,
    alerts: alerts ?? this.alerts,
    directives: directives ?? this.directives,
    htmlBlocks: htmlBlocks ?? this.htmlBlocks,
    tables: tables ?? this.tables,
    details: details ?? this.details,
    taskItems: taskItems ?? this.taskItems,
    standaloneTaskLine: standaloneTaskLine ?? this.standaloneTaskLine,
    radioItems: radioItems ?? this.radioItems,
    mathBlocks: mathBlocks ?? this.mathBlocks,
    setextHeadings: setextHeadings ?? this.setextHeadings,
    indentedCode: indentedCode ?? this.indentedCode,
    relaxedListIndentation:
        relaxedListIndentation ?? this.relaxedListIndentation,
  );
}

/// Closure policy for an incomplete document; complete input keeps its syntax.
final class StreamingOptions {
  const StreamingOptions({
    this.optimisticBlocks = true,
    this.optimisticInlines = false,
  });

  /// Render unfinished fenced code, math, tables and containers structurally.
  final bool optimisticBlocks;

  /// Allow the incremental parser to close unfinished inline syntax for display.
  final bool optimisticInlines;
}
