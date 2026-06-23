// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../charcode.dart';
import '../inline_parser.dart';
import 'inline_syntax.dart';

/// Removes the single space before the line ending.
// https://spec.commonmark.org/0.30/#soft-line-breaks.
// If there are more than one spaces before the line ending, it may hit the hard
// break syntax.
class SoftLineBreakSyntax extends InlineSyntax {
  SoftLineBreakSyntax() : super(' \n', startCharacter: $space);

  @override
  bool onMatch(InlineParser parser, Match match) {
    parser.consume(1);
    return false;
  }
}
