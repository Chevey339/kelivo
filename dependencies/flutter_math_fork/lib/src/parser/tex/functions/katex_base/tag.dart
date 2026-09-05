part of katex_base;

const _tagEntries = {
  ['\\tag']: FunctionSpec(numArgs: 1, handler: _tagHandler),
};

GreenNode _tagHandler(TexParser parser, FunctionContext context) {
  if (!parser.settings.displayMode) {
    throw ParseException(
        '\\tag works only in display equations', context.token);
  }
  if (parser.equationTag != null) {
    throw ParseException('Multiple \\tag in one equation', context.token);
  }
  parser.consumeSpaces();
  final literal = parser.fetch().text == '*';
  if (literal) parser.consume();
  final body = parser.parseArgNode(mode: Mode.text, optional: false)!;
  parser.equationTag = StyleNode(
    optionsDiff: OptionsDiff(
      style: MathStyle.text,
      textFontOptions: texTextFontOptions['\\textnormal'],
    ),
    children: [
      if (!literal) SymbolNode(symbol: '(', mode: Mode.text),
      ...body.expandEquationRow(),
      if (!literal) SymbolNode(symbol: ')', mode: Mode.text),
    ],
  ).wrapWithEquationRow();
  return EquationRowNode.empty();
}
