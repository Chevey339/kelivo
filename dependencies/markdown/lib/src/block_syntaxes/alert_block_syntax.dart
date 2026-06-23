// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../line.dart';
import '../patterns.dart';
import 'block_syntax.dart';
import 'code_block_syntax.dart';
import 'paragraph_syntax.dart';

/// Parses GitHub Alerts blocks.
///
/// See also: https://docs.github.com/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#alerts
class AlertBlockSyntax extends BlockSyntax {
  const AlertBlockSyntax();

  @override
  RegExp get pattern => alertPattern;

  @override
  bool canParse(BlockParser parser) {
    return alertPattern.hasMatch(parser.current.content);
  }

  /// Whether this alert ends with a lazy continuation line.
  ///
  /// The definition of lazy continuation lines:
  /// https://spec.commonmark.org/0.30/#lazy-continuation-line
  static bool _lazyContinuation = false;
  static final _contentLineRegExp = RegExp(r'>?\s?(.*)*');

  @override
  List<Line> parseChildLines(BlockParser parser) {
    // Grab all of the lines that form the alert, stripping off the ">".
    final childLines = <Line>[];
    _lazyContinuation = false;

    while (!parser.isDone) {
      final lineContent = parser.current.content.trimLeft();
      final strippedContent = lineContent.replaceFirst(RegExp(r'^>?\s*'), '');
      final match = strippedContent.isEmpty && !lineContent.startsWith('>')
          ? null
          : _contentLineRegExp.firstMatch(strippedContent);
      if (match != null) {
        childLines.add(Line(strippedContent));
        parser.advance();
        _lazyContinuation = false;
        continue;
      }

      final lastLine = childLines.isEmpty ? Line('') : childLines.last;

      // A paragraph continuation is OK. This is content that cannot be parsed
      // as any other syntax except Paragraph, and it doesn't match the bar in
      // a Setext header.
      // Because indented code blocks cannot interrupt paragraphs, a line
      // matched CodeBlockSyntax is also paragraph continuation text.
      final otherMatched = parser.blockSyntaxes.firstWhere(
        (s) => s.canParse(parser),
      );
      if ((otherMatched is ParagraphSyntax &&
              !lastLine.isBlankLine &&
              !codeFencePattern.hasMatch(lastLine.content)) ||
          (otherMatched is CodeBlockSyntax &&
              !indentPattern.hasMatch(lastLine.content))) {
        childLines.add(parser.current);
        _lazyContinuation = true;
        parser.advance();
      } else {
        break;
      }
    }

    return childLines;
  }

  @override
  Node parse(BlockParser parser) {
    // Parse the alert type from the first line.
    final type = pattern
        .firstMatch(parser.current.content)!
        .group(1)!
        .toLowerCase();
    parser.advance();
    final childLines = parseChildLines(parser);
    // Recursively parse the contents of the alert.
    final children = BlockParser(childLines, parser.document).parseLines(
      // The setext heading underline cannot be a lazy continuation line in a
      // block quote.
      // https://spec.commonmark.org/0.30/#example-93
      disabledSetextHeading: _lazyContinuation,
      parentSyntax: this,
    );

    // Mapping the alert title text.
    const typeTextMap = {
      'note': 'Note',
      'tip': 'Tip',
      'important': 'Important',
      'caution': 'Caution',
      'warning': 'Warning',
    };
    final titleText = typeTextMap[type]!;
    final titleElement = Element('p', [Text(titleText)])
      ..attributes['class'] = 'markdown-alert-title';
    final elementClass = 'markdown-alert markdown-alert-$type';
    return Element('div', [titleElement, ...children])
      ..attributes['class'] = elementClass;
  }
}
