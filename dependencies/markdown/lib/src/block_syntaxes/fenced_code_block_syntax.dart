// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../charcode.dart' show $space;
import '../line.dart';
import '../patterns.dart';
import '../util.dart';
import 'block_syntax.dart';

/// Parses preformatted code blocks between two ~~~ or ``` sequences.
///
/// See the CommonMark spec:
/// https://spec.commonmark.org/0.30/#fenced-code-blocks
class FencedCodeBlockSyntax extends BlockSyntax {
  @override
  RegExp get pattern => codeFencePattern;

  const FencedCodeBlockSyntax();

  @override
  Node parse(BlockParser parser) {
    final openingFence = _FenceMatch.fromMatch(
      pattern.firstMatch(escapePunctuation(parser.current.content))!,
    );

    var text = parseChildLines(
      parser,
      openingFence.marker,
      openingFence.indent,
    ).map((e) => e.content).join('\n');

    if (parser.document.encodeHtml) {
      text = escapeHtml(text, escapeApos: false);
    }
    if (text.isNotEmpty) {
      text = '$text\n';
    }

    final (languageString, metadataString) = openingFence.languageAndMetadata;

    final code = Element.text('code', text);
    if (languageString != null) {
      final processedLanguage = _processAttribute(
        languageString,
        encodeHtml: parser.document.encodeHtml,
      );
      code.attributes['class'] = 'language-$processedLanguage';
    }

    final pre = Element('pre', [code]);
    if (metadataString != null) {
      final processedMetadata = _processAttribute(
        metadataString,
        encodeHtml: parser.document.encodeHtml,
      );
      pre.attributes['data-metadata'] = processedMetadata;
    }

    return pre;
  }

  static String _processAttribute(String value, {bool encodeHtml = false}) {
    final decodedValue = decodeHtmlCharacters(value);
    if (encodeHtml) {
      return escapeHtmlAttribute(decodedValue);
    }
    return decodedValue;
  }

  @override
  List<Line> parseChildLines(
    BlockParser parser, [
    String openingMarker = '',
    int indent = 0,
  ]) {
    final childLines = <Line>[];

    parser.advance();

    _FenceMatch? closingFence;
    while (!parser.isDone) {
      final match = pattern.firstMatch(parser.current.content);
      closingFence = match == null ? null : _FenceMatch.fromMatch(match);

      // Closing code fences cannot have info strings:
      // https://spec.commonmark.org/0.30/#example-147
      if (closingFence == null ||
          !closingFence.marker.startsWith(openingMarker) ||
          closingFence.hasInfo) {
        childLines.add(
          Line(_removeLeadingSpaces(parser.current.content, upTo: indent)),
        );
        parser.advance();
      } else {
        parser.advance();
        break;
      }
    }

    // https://spec.commonmark.org/0.30/#example-127
    // https://spec.commonmark.org/0.30/#example-128
    if (closingFence == null &&
        childLines.isNotEmpty &&
        childLines.last.isBlankLine) {
      childLines.removeLast();
    }

    return childLines;
  }

  /// Removes the leading spaces (` `) from [content] up the given [upTo] count.
  static String _removeLeadingSpaces(String content, {required int upTo}) {
    var leadingSpacesCount = 0;

    // Find the index of the first non-space character
    // or the first space after the maximum removed specified by 'upTo'.
    while (leadingSpacesCount < upTo && leadingSpacesCount < content.length) {
      // We can just check for space (` `) since fenced code blocks
      // consider spaces before the opening code fence as the
      // indentation that should be removed.
      if (content.codeUnitAt(leadingSpacesCount) != $space) {
        break;
      }
      leadingSpacesCount += 1;
    }
    return content.substring(leadingSpacesCount);
  }
}

class _FenceMatch {
  _FenceMatch._({
    required this.indent,
    required this.marker,
    required this.info,
  });

  factory _FenceMatch.fromMatch(RegExpMatch match) {
    String marker;
    String info;

    if (match.namedGroup('backtick') != null) {
      marker = match.namedGroup('backtick')!;
      info = match.namedGroup('backtickInfo')!;
    } else {
      marker = match.namedGroup('tilde')!;
      info = match.namedGroup('tildeInfo')!;
    }

    return _FenceMatch._(
      indent: match[1]!.length,
      marker: marker,
      info: info.trim(),
    );
  }

  final int indent;
  final String marker;

  // The info-string should be trimmed,
  // https://spec.commonmark.org/0.30/#info-string.
  final String info;

  /// Returns the language and remaining metadata from the [info] string.
  ///
  /// The language is the first word of the info string,
  /// to match the (unspecified, but typical) behavior of CommonMark parsers,
  /// as suggested in https://spec.commonmark.org/0.30/#example-143.
  ///
  /// The metadata is any remaining part of the info string after the language.
  (String? language, String? metadata) get languageAndMetadata {
    if (info.isEmpty) {
      return (null, null);
    }

    // We assume the info string is trimmed already.
    final firstSpaceIndex = info.indexOf(' ');
    if (firstSpaceIndex == -1) {
      // If there is no space, the whole string is the language.
      return (info, null);
    }

    return (
      info.substring(0, firstSpaceIndex),
      info.substring(firstSpaceIndex + 1),
    );
  }

  bool get hasInfo => info.isNotEmpty;
}
