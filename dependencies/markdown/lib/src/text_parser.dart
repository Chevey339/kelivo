// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'charcode.dart';

/// A parser to parse a segment of source text.
class TextParser {
  final String source;

  TextParser(this.source);

  /// The current read position.
  var _position = 0;
  int get pos => _position;

  /// Whether the read position has reached the end of [source].
  bool get isDone => _position == length;

  /// The length of [source].
  int get length => source.length;

  /// Walk the parser forward through any whitespace.
  ///
  /// Set [multiLine] `true` to support multiline, otherwise it will stop before
  /// the line feed [$lf].
  int moveThroughWhitespace({bool multiLine = false}) {
    var i = 0;
    while (!isDone) {
      final char = charAt();
      if (char != $space &&
          char != $tab &&
          char != $vt &&
          char != $cr &&
          char != $ff &&
          !(multiLine && char == $lf)) {
        return i;
      }

      i++;
      advance();
    }
    return i;
  }

  int charAt([int? position]) => source.codeUnitAt(position ?? _position);

  /// Moves the read position one character ahead.
  void advance() => advanceBy(1);

  /// Moves the read position for [length] characters. [length] can be negative.
  void advanceBy(int length) {
    _position += length;
  }

  /// Substrings the [source] and returns a [String].
  String substring(int start, [int? end]) => source.substring(start, end);
}
