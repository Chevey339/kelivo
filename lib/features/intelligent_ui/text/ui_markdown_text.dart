import 'package:markstream/markstream_core.dart';

const genUiMarkdownOptions = ParserOptions(
  inlineHtml: false,
  htmlBlocks: false,
  directives: false,
  details: false,
  taskItems: false,
  radioItems: false,
  standaloneTaskLine: false,
);

String uiMarkdownText(String source) => toPlainText(
  const MarkdownParser(options: genUiMarkdownOptions).parse(source),
);
