// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../charcode.dart';
import '../inline_parser.dart';
import '../util.dart';
import 'inline_syntax.dart';

/// Matches autolinks like `http://foo.com` and `foo@bar.com`.
class AutolinkExtensionSyntax extends InlineSyntax {
  static const _linkPattern =
      // Autolinks can only come at the beginning of a line, after whitespace,
      // or any of the delimiting characters *, _, ~, and (.
      // Note: Disable this piece for now, as Safari does not support
      // lookarounds. Consider re-enabling later.
      // r'(?<=^|[\s*_~(>])'
      // An extended url autolink will be recognised when one of the schemes
      // http://, or https://, followed by a valid domain. See
      // https://github.github.com/gfm/#extended-url-autolink.
      r'(?:(?:https?|ftp):\/\/|www\.)'
      // A valid domain consists of segments of alphanumeric characters,
      // underscores (_) and hyphens (-) separated by periods (.). There must
      // be at least one period, and no underscores may be present in the last
      // two segments of the domain. See
      // https://github.github.com/gfm/#valid-domain.
      r'(?:[-_a-z0-9]+\.)*(?:[-a-z0-9]+\.[-a-z0-9]+)'
      // After a valid domain, zero or more non-space non-< characters may
      // follow.
      r'[^\s<]*'
      // Trailing punctuation (specifically, ?, !, ., ,, :, *, _, and ~) will
      // not be considered part of the autolink, though they may be included in
      // the interior of the link. See
      // https://github.github.com/gfm/#extended-autolink-path-validation.
      // Note: Do not use negative lookbehind, as Safari does not support it.
      // '(?<![?!.,:*_~])'
      r'[^\s<?!.,:*_~]';

  // An extended email autolink, see
  // https://github.github.com/gfm/#extended-email-autolink.
  static const _emailPattern =
      r'[-_.+a-z0-9]+@(?:[-_a-z0-9]+\.)+[-_a-z0-9]*[a-z0-9]';

  AutolinkExtensionSyntax()
    : super('($_linkPattern)|($_emailPattern)', caseSensitive: false);

  @override
  bool tryMatch(InlineParser parser, [int? startMatchPos]) {
    startMatchPos ??= parser.pos;
    final startMatch = pattern.matchAsPrefix(parser.source, startMatchPos);
    if (startMatch == null) {
      return false;
    }

    // When it is a link and it is not at the beginning of a line, or preceded
    // by whitespace, `*`, `_`, `~`, `(`, or `>`, it is invalid. See
    // https://github.github.com/gfm/#autolinks-extension-.
    if (startMatch[1] != null && parser.pos > 0) {
      final precededBy = String.fromCharCode(parser.charAt(parser.pos - 1));
      const validPrecedingChars = {'\n', ' ', '*', '_', '~', '(', '>'};
      if (!validPrecedingChars.contains(precededBy)) {
        return false;
      }
    }

    // When it is an email link and followed by `_` or `-`, it is invalid. See
    // https://github.github.com/gfm/#example-633
    if (startMatch[2] != null && parser.source.length > startMatch.end) {
      final followedBy = String.fromCharCode(parser.charAt(startMatch.end));
      const invalidFollowingChars = {'_', '-'};
      if (invalidFollowingChars.contains(followedBy)) {
        return false;
      }
    }

    parser.writeText();
    return onMatch(parser, startMatch);
  }

  @override
  bool onMatch(InlineParser parser, Match match) {
    int consumeLength;

    final isEmailLink = match[2] != null;
    if (isEmailLink) {
      consumeLength = match.match.length;
    } else {
      consumeLength = _getConsumeLength(match.match);
    }

    var text = match.match.substring(0, consumeLength);
    text = parser.encodeHtml ? escapeHtml(text) : text;

    var destination = text;
    if (isEmailLink) {
      destination = 'mailto:$destination';
    } else if (destination[0] == 'w') {
      // When there is no scheme specified, insert the scheme `http`.
      destination = 'http://$destination';
    }

    final anchor = Element.text('a', text)
      ..attributes['href'] = Uri.encodeFull(destination);

    parser
      ..addNode(anchor)
      ..consume(consumeLength);

    return true;
  }

  int _getConsumeLength(String text) {
    var excludedLength = 0;

    // When an autolink ends in `)`, see
    // https://github.github.com/gfm/#example-625.
    if (text.endsWith(')')) {
      final match = RegExp(r'(\(.*)?(\)+)$').firstMatch(text)!;

      if (match[1] == null) {
        excludedLength = match[2]!.length;
      } else {
        var parenCount = 0;
        for (var i = 0; i < text.length; i++) {
          final char = text.codeUnitAt(i);
          if (char == $lparen) {
            parenCount++;
          } else if (char == $rparen) {
            parenCount--;
          }
        }
        if (parenCount < 0) {
          excludedLength = parenCount.abs();
        }
      }
    }
    // If an autolink ends in a semicolon `;`, see
    // https://github.github.com/gfm/#example-627
    else if (text.endsWith(';')) {
      final match = RegExp(r'&[0-9a-z]+;$').firstMatch(text);
      if (match != null) {
        excludedLength = match.match.length;
      }
    }

    return text.length - excludedLength;
  }
}
