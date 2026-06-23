// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../document.dart';
import '../line.dart';
import '../link_parser.dart';
import '../patterns.dart';
import '../util.dart';
import 'block_syntax.dart';

class LinkReferenceDefinitionSyntax extends BlockSyntax {
  @override
  RegExp get pattern => linkReferenceDefinitionPattern;

  @override
  bool canEndBlock(BlockParser parser) => false;

  const LinkReferenceDefinitionSyntax();

  @override
  Node? parse(BlockParser parser) {
    final lines = <Line>[parser.current];
    parser.advance();

    while (!BlockSyntax.isAtBlockEnd(parser)) {
      lines.add(parser.current);
      parser.advance();
    }

    if (!_parseLinkReferenceDefinition(lines, parser)) {
      parser.retreatBy(lines.length);
    }

    return null;
  }

  bool _parseLinkReferenceDefinition(List<Line> lines, BlockParser parser) {
    final linkParser = LinkParser(lines.map((e) => e.content).join('\n'))
      ..parseDefinition();

    if (!linkParser.valid) {
      return false;
    }

    // Retreat the parsing position back to where the link reference definition
    // ends, so that the next syntax can continue parsing from there.
    parser.retreatBy(linkParser.unconsumedLines);

    final labelString = normalizeLinkLabel(linkParser.label!);

    parser.document.linkReferences.putIfAbsent(
      labelString,
      () =>
          LinkReference(labelString, linkParser.destination!, linkParser.title),
    );

    return true;
  }
}
