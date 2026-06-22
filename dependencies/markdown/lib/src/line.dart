// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'patterns.dart';

/// A [Line] is a sequence of zero or more characters other than line feed
/// (`U+000A`) or carriage return (`U+000D`), followed by a line ending or by
/// the end of file.
// See https://spec.commonmark.org/0.30/#line.
class Line {
  /// A sequence of zero or more characters other than the line ending.
  final String content;

  /// How many spaces of a tab that remains after part of it has been consumed.
  // See: https://spec.commonmark.org/0.30/#example-6
  // We cannot simply expand the `tabRemaining` to spaces, for example
  //
  // `>\t\tfoo`
  //
  // If we expand the 2 space width `tabRemaining` from blockquote block into 2
  // spaces, so the string segment for the indented code block is:
  //
  // `  \tfoo`,
  //
  // then the output will be:
  // ```html
  // <pre><code>foo
  // </code></pre>
  // ```
  // instead of the expected:
  // ```html
  // <pre><code>  foo
  // </code></pre>
  // ```
  final int? tabRemaining;

  // A line containing no characters, or a line containing only spaces
  // (`U+0020`) or tabs (`U+0009`), is called a blank line.
  // https://spec.commonmark.org/0.30/#blank-line
  final bool isBlankLine;

  Line(this.content, {this.tabRemaining})
    : isBlankLine = emptyPattern.hasMatch(content);
}
