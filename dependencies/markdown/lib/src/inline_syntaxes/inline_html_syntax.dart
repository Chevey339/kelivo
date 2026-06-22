// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// These are RegExps, always use raw strings.
// ignore_for_file: unnecessary_raw_strings

import '../../markdown.dart';
import '../charcode.dart';
import '../patterns.dart';

/// Leave inline HTML tags alone, from
/// [CommonMark 0.30](https://spec.commonmark.org/0.30/#raw-html).
///
/// This is not actually a good definition (nor CommonMark's) of an HTML tag,
/// but it is fast. It will leave text like `<a href='hi">` alone, which is
/// incorrect.
///
/// TODO(srawlins): improve accuracy while ensuring performance, once
/// Markdown benchmarking is more mature.
class InlineHtmlSyntax extends TextSyntax {
  static const _pattern =
      '(?:$namedTagDefinition)'
      // Or
      '|'
      // HTML comment, see
      // https://spec.commonmark.org/0.30/#html-comment.
      r'<!--(?!-?>)[^\-]*-(?:[^\-]+-)*?->'
      '|'
      // Processing-instruction, see
      // https://spec.commonmark.org/0.30/#processing-instruction
      r'<\?[^]*?\?>'
      '|'
      // Declaration, see
      // https://spec.commonmark.org/0.30/#declaration.
      r'(<![a-zA-Z]+[^]*?>)'
      '|'
      // CDATA section, see
      // https://spec.commonmark.org/0.30/#cdata-section.
      r'(<!\[CDATA\[[^]*?\]\]>)';

  InlineHtmlSyntax()
    : super(_pattern, startCharacter: $lt, caseSensitive: true);
}
