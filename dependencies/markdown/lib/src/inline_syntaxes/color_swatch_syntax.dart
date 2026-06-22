// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../charcode.dart';
import '../inline_parser.dart';
import '../util.dart';
import 'inline_syntax.dart';

/// Matches code blocks containing a subset of CSS color syntax.
class ColorSwatchSyntax extends InlineSyntax {
  /// This pattern matches:
  /// * GitHub Flavored Markup supports fewer of these options, GitLab Flavored
  ///   Markup supports all of these. Presumably GitHub will be more complete at
  ///   some point.
  /// * CSS style '#' prefixed color hex codes in 3,4,6 or 8 digits in length.
  /// * CSS style RGB()/RgbA()/Hsl()/HSLA() style color declarations, of any
  ///   capitalization.
  /// EXAMPLES:
  /// * `#f00`
  /// * `#BA`        (2 digit hex, regex will not match)
  /// * `#F00a`
  /// * `#F0BAD`     (5 digit hex, regex will not match)
  /// * `#FF0000`
  /// * `#F000BAD`   (7 digit hex, regex will not match)
  /// * `#FF0000aA`    (GitHub supports only this style)
  /// * `RGB(0,255,0)`
  /// * `rgb(0,255,0)`
  /// * `RGB(0%,100%,0%)`
  /// * `rgb(0%,100%,0%)`
  /// * `RGBA(0,255,0,0.3)`
  /// * `rgba(0,255,0,0.3)`
  /// * `HSL(540,70%,50%)`
  /// * `hsl(540,70%,50%)`
  /// * `HSLA(540,70%,50%,0.3)`
  /// * `Hsla(540,70%,50%,0.3)`
  static const _pattern =
      '`((#([A-Fa-f0-9]{3}|[A-Fa-f0-9]{4}|[A-Fa-f0-9]{6}|[A-Fa-f0-9]{8}))|'
      r'([Rr][Gg][Bb][Aa]?\((\d+[%]?),(\d+[%]?),(\d+[%]?),?(\d+\.?\d+[%]?)?\))|'
      r'([Hh][Ss][Ll][Aa]?\((\d+[%]?),(\d+[%]?),(\d+[%]?),?(\d+\.?\d+[%]?)?\)))`';

  ColorSwatchSyntax() : super(_pattern);

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
    var code = match[1]!.trim().replaceAll('\n', ' ');

    if (parser.encodeHtml) code = escapeHtml(code);

    parser.addNode(
      Element('code', [
        Text(code),
        Element.withTag('span')
          ..attributes['style'] = 'background-color:$code;',
      ])..attributes['class'] = 'gfm-color_chip',
    );

    return true;
  }
}
