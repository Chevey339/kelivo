// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../inline_parser.dart';
import '../util.dart';
import 'inline_syntax.dart';

/// Encodes (`"`), (`<`), (`>`) and (`&`).
class EscapeHtmlSyntax extends InlineSyntax {
  EscapeHtmlSyntax() : super('["<>&]');
  @override
  bool onMatch(InlineParser parser, Match match) {
    final text = escapeHtml(match[0]!);
    parser.addNode(Text(text));

    return true;
  }
}
