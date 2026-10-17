/// Block syntax defaults for LLM-authored Markdown.
final class ParserOptions {
  const ParserOptions({
    this.setextHeadings = false,
    this.indentedCode = false,
    this.relaxedListIndentation = true,
  });

  const ParserOptions.commonMark()
    : setextHeadings = true,
      indentedCode = true,
      relaxedListIndentation = false;

  final bool setextHeadings;
  final bool indentedCode;
  final bool relaxedListIndentation;
}
