/// Block syntax defaults for LLM-authored Markdown.
final class ParserOptions {
  const ParserOptions({
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
    : alerts = false,
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
