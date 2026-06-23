// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../line.dart';

abstract class BlockSyntax {
  const BlockSyntax();

  /// Gets the regex used to identify the beginning of this block, if any.
  RegExp get pattern;

  bool canEndBlock(BlockParser parser) => true;

  bool canParse(BlockParser parser) {
    return pattern.hasMatch(parser.current.content);
  }

  Node? parse(BlockParser parser);

  List<Line?> parseChildLines(BlockParser parser) {
    // Grab all of the lines that form the block element.
    final childLines = <Line?>[];

    while (!parser.isDone) {
      final match = pattern.firstMatch(parser.current.content);
      if (match == null) break;
      childLines.add(parser.current);
      parser.advance();
    }

    return childLines;
  }

  /// Returns the block which interrupts current syntax parsing if there is one,
  /// otherwise returns `null`.
  ///
  /// Make sure to check if [parser] `isDone` is `false` first.
  BlockSyntax? interruptedBy(BlockParser parser) {
    for (final syntax in parser.blockSyntaxes) {
      if (syntax.canParse(parser) && syntax.canEndBlock(parser)) {
        return syntax;
      }
    }
    return null;
  }

  /// Gets whether or not [parser]'s current line should end the previous block.
  static bool isAtBlockEnd(BlockParser parser) {
    if (parser.isDone) return true;
    return parser.blockSyntaxes.any(
      (s) => s.canParse(parser) && s.canEndBlock(parser),
    );
  }

  /// Generates a valid HTML anchor from the inner text of [element].
  static String generateAnchorHash(Element element) => element
      .children!
      .first
      .textContent
      .toLowerCase()
      .trim()
      .replaceAll(RegExp('[^a-z0-9 _-]'), '')
      .replaceAll(RegExp(r'\s'), '-');
}
