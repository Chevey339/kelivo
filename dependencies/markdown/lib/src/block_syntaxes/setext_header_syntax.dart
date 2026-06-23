// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';
import 'paragraph_syntax.dart';

/// Parses setext-style headers.
class SetextHeaderSyntax extends BlockSyntax {
  @override
  RegExp get pattern => setextPattern;

  const SetextHeaderSyntax();

  @override
  bool canParse(BlockParser parser) {
    final lastSyntax = parser.currentSyntax;
    if (parser.setextHeadingDisabled || lastSyntax is! ParagraphSyntax) {
      return false;
    }
    return pattern.hasMatch(parser.current.content);
  }

  @override
  Node? parse(BlockParser parser) {
    final lines = parser.linesToConsume;
    if (lines.length < 2) {
      return null;
    }

    // Remove the last line which is a marker.
    lines.removeLast();

    final marker = parser.current.content.trim();
    final level = (marker[0] == '=') ? '1' : '2';
    final content = lines.map((e) => e.content).join('\n').trimRight();

    parser.advance();
    return Element('h$level', [UnparsedContent(content)]);
  }
}
