// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'assets/case_folding.dart';
import 'assets/html_entities.dart';
import 'charcode.dart';
import 'line.dart';
import 'patterns.dart';

/// One or more whitespace, for compressing.
final _oneOrMoreWhitespacePattern = RegExp('[ \n\r\t]+');

/// Escapes (`"`), (`<`), (`>`) and (`&`) characters.
/// Escapes (`'`) if [escapeApos] is `true`.
String escapeHtml(String html, {bool escapeApos = true}) => HtmlEscape(
  HtmlEscapeMode(escapeApos: escapeApos, escapeLtGt: true, escapeQuot: true),
).convert(html);

/// Escapes (`"`), (`<`) and (`>`) characters.
String escapeHtmlAttribute(String text) =>
    const HtmlEscape(HtmlEscapeMode.attribute).convert(text);

/// "Normalizes" a link label, according to the [CommonMark spec].
///
/// [CommonMark spec] https://spec.commonmark.org/0.30/#link-label
String normalizeLinkLabel(String label) {
  var text = label.trim().replaceAll(_oneOrMoreWhitespacePattern, ' ');
  for (var i = 0; i < text.length; i++) {
    final mapped = caseFoldingMap[text[i]];
    if (mapped != null) {
      text = text.replaceRange(i, i + 1, mapped);
    }
  }
  return text;
}

/// Normalizes a link destination, including the process of HTML characters
/// decoding and percent encoding.
// See the description of these examples:
// https://spec.commonmark.org/0.30/#example-501
// https://spec.commonmark.org/0.30/#example-502
String normalizeLinkDestination(String destination) {
  // Split by url escaping characters
  // Concatenate them with unmodified URL-escaping.
  // URL-escaping should be left alone inside the destination
  // Refer: https://spec.commonmark.org/0.30/#example-502.

  final regex = RegExp('%[0-9A-Fa-f]{2}');

  return destination.splitMapJoin(
    regex,
    onMatch: (m) => m.match,
    onNonMatch: (e) {
      try {
        e = Uri.decodeFull(e);
      } catch (_) {}
      return Uri.encodeFull(decodeHtmlCharacters(e));
    },
  );
}

/// Normalizes a link title, including the process of HTML characters decoding
/// and HTML characters escaping.
// See the description of these examples:
// https://spec.commonmark.org/0.30/#example-505
// https://spec.commonmark.org/0.30/#example-506
// https://spec.commonmark.org/0.30/#example-507
// https://spec.commonmark.org/0.30/#example-508
String normalizeLinkTitle(String title) =>
    escapeHtmlAttribute(decodeHtmlCharacters(title));

///  Decodes HTML entity and numeric character references, for example decode
/// `&#35` to `#`.
String decodeHtmlCharacters(String input) =>
    input.replaceAllMapped(htmlCharactersPattern, decodeHtmlCharacterFromMatch);

/// Decodes HTML entity and numeric character references from the given [match].
String decodeHtmlCharacterFromMatch(Match match) {
  final text = match.match;
  final entity = match[1];
  final decimalNumber = match[2];
  final hexadecimalNumber = match[3];

  // Entity references, see
  // https://spec.commonmark.org/0.30/#entity-references.
  if (entity != null) {
    return htmlEntitiesMap[text] ?? text;
  }
  // Decimal numeric character references, see
  // https://spec.commonmark.org/0.30/#decimal-numeric-character-references.
  else if (decimalNumber != null) {
    final decimalValue = int.parse(decimalNumber);
    int hexValue;
    if (decimalValue < 1114112 && decimalValue > 1) {
      hexValue = int.parse(decimalValue.toRadixString(16), radix: 16);
    } else {
      hexValue = 0xFFFd;
    }

    return String.fromCharCode(hexValue);
  }
  // Hexadecimal numeric character references, see
  // https://spec.commonmark.org/0.30/#hexadecimal-numeric-character-references.
  else if (hexadecimalNumber != null) {
    var hexValue = int.parse(hexadecimalNumber, radix: 16);
    if (hexValue > 0x10ffff || hexValue == 0) {
      hexValue = 0xFFFd;
    }
    return String.fromCharCode(hexValue);
  }

  return text;
}

extension MatchExtensions on Match {
  /// Returns the whole match String
  String get match => this[0]!;
}

/// Escapes the ASCII punctuation characters after backslash(`\`).
String escapePunctuation(String input) {
  final buffer = StringBuffer();

  for (var i = 0; i < input.length; i++) {
    if (input.codeUnitAt(i) == $backslash) {
      final next = i + 1 < input.length ? input[i + 1] : null;
      if (next != null && asciiPunctuationCharacters.contains(next)) {
        i++;
      }
    }
    buffer.write(input[i]);
  }

  return buffer.toString();
}

extension StringExtensions on String {
  /// Calculates the length of indentation a `String` has.
  ///
  // The behavior of tabs: https://spec.commonmark.org/0.30/#tabs
  int indentation() {
    var length = 0;
    for (final char in codeUnits) {
      if (char != $space && char != $tab) {
        break;
      }
      length += char == $tab ? 4 - (length % 4) : 1;
    }
    return length;
  }

  /// Removes up to [length] characters of leading whitespace.
  // The way of handling tabs: https://spec.commonmark.org/0.30/#tabs
  DedentedText dedent([int length = 4]) {
    final whitespaceMatch = RegExp('^[ \t]{0,$length}').firstMatch(this);
    const tabSize = 4;

    int? tabRemaining;
    var start = 0;
    final whitespaces = whitespaceMatch?[0];
    if (whitespaces != null) {
      var indentLength = 0;
      for (; start < whitespaces.length; start++) {
        final isTab = whitespaces[start] == '\t';
        if (isTab) {
          indentLength += tabSize;
          tabRemaining = 4;
        } else {
          indentLength += 1;
        }
        if (indentLength >= length) {
          if (tabRemaining != null) {
            tabRemaining = indentLength - length;
          }
          if (indentLength == length || isTab) {
            start += 1;
          }
          break;
        }
        if (tabRemaining != null) {
          tabRemaining = 0;
        }
      }
    }
    return DedentedText(substring(start), tabRemaining);
  }

  /// Adds [width] of spaces to the beginning of this string.
  String prependSpace(int width) => '${" " * width}$this';

  /// Whether this string contains only whitespaces.
  bool get isBlank => trim().isEmpty;

  /// Converts this string to a list of [Line].
  List<Line> toLines() => LineSplitter.split(this).map(Line.new).toList();

  /// Returns the last character.
  String last([int n = 1]) => substring(length - n);
}

/// A class that describes a dedented text.
class DedentedText {
  /// The dedented text.
  final String text;

  /// How many spaces of a tab that remains after part of it has been consumed.
  ///
  /// `null` means we did not read a `tab`.
  final int? tabRemaining;

  DedentedText(this.text, this.tabRemaining);
}
