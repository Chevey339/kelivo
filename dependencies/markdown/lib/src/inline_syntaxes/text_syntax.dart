// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../inline_parser.dart';
import '../util.dart';
import 'inline_syntax.dart';

/// Matches stuff that should just be passed through as straight text.
class TextSyntax extends InlineSyntax {
  final String substitute;

  /// Create a new [TextSyntax] which matches text on [pattern].
  ///
  /// If [sub] is passed, it is used as a simple replacement for [pattern]. If
  /// [startCharacter] is passed, it is used as a pre-matching check which is
  /// faster than matching against [pattern].
  TextSyntax(
    super.pattern, {
    String sub = '',
    super.startCharacter,
    super.caseSensitive,
  }) : substitute = sub;

  /// Adds a [Text] node to [parser] and returns `true` if there is a
  /// [substitute], as long as the preceding character (if any) is not a `/`.
  ///
  /// Otherwise, the parser is advanced by the length of [match] and `false` is
  /// returned.
  @override
  bool onMatch(InlineParser parser, Match match) {
    if (substitute.isEmpty ||
        (match.start > 0 &&
            match.input.substring(match.start - 1, match.start) == '/')) {
      // Just use the original matched text.
      parser.advanceBy(match.match.length);
      return false;
    }

    // Insert the substitution.
    parser.addNode(Text(substitute));
    return true;
  }
}
