// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../patterns.dart';
import 'block_syntax.dart';

/// Parses atx-style headers: `## Header ##`.
class HeaderSyntax extends BlockSyntax {
  @override
  RegExp get pattern => headerPattern;

  const HeaderSyntax();

  @override
  Node parse(BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content)!;
    final matchedText = match[0]!;
    final openMarker = match[1]!;
    final closeMarker = match[2];
    final level = openMarker.length;
    final openMarkerStart = matchedText.indexOf(openMarker);
    final openMarkerEnd = openMarkerStart + level;

    String? content;
    if (closeMarker == null) {
      content = parser.current.content.substring(openMarkerEnd);
    } else {
      final closeMarkerStart = matchedText.lastIndexOf(closeMarker);
      content = parser.current.content.substring(
        openMarkerEnd,
        closeMarkerStart,
      );
    }
    content = content.trim();

    // https://spec.commonmark.org/0.30/#example-79
    if (closeMarker == null && RegExp(r'^#+$').hasMatch(content)) {
      content = null;
    }

    parser.advance();
    return Element('h$level', [if (content != null) UnparsedContent(content)]);
  }
}
