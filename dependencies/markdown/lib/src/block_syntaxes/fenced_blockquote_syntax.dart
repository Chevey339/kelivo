// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../line.dart';
import '../patterns.dart';
import 'block_syntax.dart';

/// Parses lines fenced by `>>>` to blockquotes
class FencedBlockquoteSyntax extends BlockSyntax {
  const FencedBlockquoteSyntax();

  @override
  RegExp get pattern => blockquoteFencePattern;

  @override
  List<Line> parseChildLines(BlockParser parser) {
    final childLines = <Line>[];
    parser.advance();

    while (!parser.isDone) {
      final match = pattern.hasMatch(parser.current.content);
      if (!match) {
        childLines.add(parser.current);
        parser.advance();
      } else {
        parser.advance();
        break;
      }
    }

    return childLines;
  }

  @override
  Node? parse(BlockParser parser) {
    final childLines = parseChildLines(parser);

    // Recursively parse the contents of the blockquote.
    final children = BlockParser(childLines, parser.document).parseLines();
    return Element('blockquote', children);
  }
}
