/// Block syntax defaults for LLM-authored Markdown.
final class ParserOptions {
  const ParserOptions({
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
  });

  const ParserOptions.commonMark()
    : softBreakAsHardBreak = false,
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
}
