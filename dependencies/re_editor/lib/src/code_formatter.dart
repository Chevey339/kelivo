part of 're_editor.dart';

abstract class CodeCommentFormatter {

  CodeLineEditingValue format(CodeLineEditingValue value, String indent, bool single);

}

abstract class DefaultCodeCommentFormatter implements CodeCommentFormatter {

  factory DefaultCodeCommentFormatter({
    String? singleLinePrefix,
    String? multiLinePrefix,
    String? multiLineSuffix
  }) => _DefaultCodeCommentFormatter(
    singleLinePrefix: singleLinePrefix,
    multiLinePrefix: multiLinePrefix,
    multiLineSuffix: multiLineSuffix
  );

}
