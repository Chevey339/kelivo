// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../charcode.dart';
import '../inline_parser.dart';
import '../util.dart';
import 'inline_syntax.dart';

/// Matches backtick-enclosed inline code blocks.
class CodeSyntax extends InlineSyntax {
  // This pattern matches:
  //
  // * a string of backticks (not followed by any more), followed by
  // * a non-greedy string of anything, including newlines, ending with anything
  //   except a backtick, followed by
  // * a string of backticks the same length as the first, not followed by any
  //   more.
  //
  // This conforms to the delimiters of inline code, both in Markdown.pl, and
  // CommonMark.
  static const _pattern = r'(`+(?!`))((?:.|\n)*?[^`])\1(?!`)';

  CodeSyntax() : super(_pattern);

  @override
  bool tryMatch(InlineParser parser, [int? startMatchPos]) {
    if (parser.pos > 0 && parser.charAt(parser.pos - 1) == $backquote) {
      // Not really a match! We can't just sneak past one backtick to try the
      // next character. An example of this situation would be:
      //
      //     before ``` and `` after.
      //             ^--parser.pos
      return false;
    }

    final match = pattern.matchAsPrefix(parser.source, parser.pos);
    if (match == null) {
      return false;
    }
    parser.writeText();
    if (onMatch(parser, match)) parser.consume(match.match.length);
    return true;
  }

  @override
  bool onMatch(InlineParser parser, Match match) {
    final markerLength = match[1]!.length;
    final contentLength = match.match.length - markerLength * 2;
    final contentStart = parser.pos + markerLength;
    final contentEnd = contentStart + contentLength;

    var code = parser.source.substring(contentStart, contentEnd);
    if (_shouldStrip(code)) {
      code = code.substring(1, code.length - 1);
    }
    code = code.replaceAll('\n', ' ');

    if (parser.encodeHtml) {
      code = escapeHtml(code, escapeApos: false);
    }

    parser.addNode(Element.text('code', code));
    return true;
  }

  bool _shouldStrip(String code) {
    // No stripping occurs if the code span contains only spaces:
    // https://spec.commonmark.org/0.30/#example-334.
    if (code.trim().isEmpty) {
      return false;
    }

    // Only spaces, and not unicode whitespace in general, are stripped in this
    // way, see https://spec.commonmark.org/0.30/#example-333.
    final startsWithSpace = code.startsWith(' ') || code.startsWith('\n');
    final endsWithSpace = code.endsWith(' ') || code.endsWith('\n');

    // The stripping only happens if the space is on both sides of the string:
    // https://spec.commonmark.org/0.30/#example-332.
    if (!startsWithSpace || !endsWithSpace) {
      return false;
    }

    return true;
  }
}
