// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../charcode.dart';
import '../inline_parser.dart';
import '../patterns.dart';
import '../util.dart';
import 'inline_syntax.dart';

/// Escape ASCII punctuation preceded by a backslash.
///
/// Backslashes before other characters are treated as literal backslashes.
// See https://spec.commonmark.org/0.30/#backslash-escapes.
class EscapeSyntax extends InlineSyntax {
  EscapeSyntax()
    : super('\\\\([$asciiPunctuationEscaped])', startCharacter: $backslash);

  @override
  bool onMatch(InlineParser parser, Match match) {
    final chars = match.match;

    String text;
    if ('&"<>'.contains(match[1]!) && parser.encodeHtml) {
      text = escapeHtml(match[1]!);
    } else {
      text = chars[1];
    }

    parser.addNode(Text(text));
    return true;
  }
}
