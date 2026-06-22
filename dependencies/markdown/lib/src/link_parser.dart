// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'charcode.dart';
import 'text_parser.dart';
import 'util.dart';

class LinkParser extends TextParser {
  /// If there is a valid link formed.
  bool get valid => _valid;
  bool _valid = false;

  /// Link label.
  String? get label => _label;
  String? _label;

  /// Link destination.
  String? get destination => _destination;
  String? _destination;

  /// Link title.
  String? get title => _title;
  String? _title;

  LinkParser(super.source);

  /// How many lines of the [source] have been consumed by link reference
  /// definition.
  int get unconsumedLines => _unconsumedLines;
  int _unconsumedLines = 0;

  /// Parses [source] to a link reference definition.
  void parseDefinition() {
    if (!parseLabel() || isDone || charAt() != $colon) {
      return;
    }

    // Advance to the next character after the colon.
    advance();
    if (!_parseDestination()) {
      return;
    }

    var precedingWhitespaces = moveThroughWhitespace();
    if (isDone) {
      _valid = true;
      return;
    }

    final multiline = charAt() == $lf;
    precedingWhitespaces += moveThroughWhitespace(multiLine: true);

    // The title must be preceded by whitespaces.
    if (precedingWhitespaces == 0 || isDone) {
      _valid = isDone;
      return;
    }

    final hasValidTitle = _parseTitle();
    // For example: `[foo]: <bar> "baz` is a invalid definition, but this one is
    // valid:
    // ```
    // [foo]: <bar>
    // "baz
    // ```
    if (!hasValidTitle && !multiline) {
      return;
    }

    if (hasValidTitle) {
      moveThroughWhitespace();
      if (!isDone && charAt() != $lf) {
        // It is not a valid definition if the title is followed by
        // non-whitespace characters, for example: `[foo]: <bar> "baz" hello`.
        // See https://spec.commonmark.org/0.30/#example-209.
        if (!multiline) {
          return;
        }
        // But it is a valid link reference definition if this definition is
        // multiline, see https://spec.commonmark.org/0.30/#example-210.
        _title = null;
      }
    }

    final linesUnconsumed = source.substring(pos).split('\n');
    if (linesUnconsumed.isNotEmpty && linesUnconsumed.first.isBlank) {
      linesUnconsumed.removeAt(0);
    }
    _unconsumedLines = linesUnconsumed.length;

    _valid = true;
  }

  /// Parses the link label, returns `true` if there is a valid link label.
  bool parseLabel() {
    moveThroughWhitespace(multiLine: true);

    if (length - pos < 2) {
      return false;
    }

    if (charAt() != $lbracket) {
      return false;
    }

    // Advance past the opening `[`.
    advance();
    final start = pos;

    // A link label can have at most 999 characters inside the square brackets.
    // See https://spec.commonmark.org/0.30/#link-label.
    var maxLoop = 999;
    while (true) {
      if (maxLoop-- < 0) {
        return false;
      }
      final char = charAt(pos);
      if (char == $backslash) {
        advance();
      } else if (char == $lbracket) {
        return false;
      } else if (char == $rbracket) {
        break;
      }
      advance();
      if (isDone) {
        return false;
      }
    }

    final text = substring(start, pos);
    if (text.isBlank) {
      return false;
    }

    // Advance past the closing `]`.
    advance();
    _label = text;
    return true;
  }

  /// Parses the link destination, returns `true` there is a valid link
  /// destination.
  bool _parseDestination() {
    moveThroughWhitespace(multiLine: true);
    if (isDone) {
      return false;
    }

    final isValidDestination = charAt() == $lt
        ? _parseBracketedDestination()
        : _parseBareDestination();

    return isValidDestination;
  }

  /// Parses bracketed destinations (destinations wrapped in `<...>`). The
  /// current position of the parser must be the first character of the
  /// destination.
  ///
  /// Returns `true` if there is a valid link destination.
  bool _parseBracketedDestination() {
    // Walk past the opening `<`.
    advance();

    final start = pos;
    while (true) {
      final char = charAt();
      if (char == $backslash) {
        advance();
      } else if (char == $lf || char == $cr || char == $ff) {
        return false;
      } else if (char == $gt) {
        break;
      }
      advance();
      if (isDone) {
        return false;
      }
    }

    _destination = substring(start, pos);

    // Advance past the closing `>`.
    advance();
    return true;
  }

  /// Parse "bare" destinations (destinations _not_ wrapped in `<...>`). The
  /// current position of the parser must be the first character of the
  /// destination.
  ///
  /// Returns `true` if there is a valid link destination.
  bool _parseBareDestination() {
    var parenCount = 0;
    final start = pos;

    while (true) {
      final char = charAt();
      if (char == $backslash) {
        advance();
      } else if (char == $space || char == $lf || char == $cr || char == $ff) {
        break;
      } else if (char == $lparen) {
        parenCount++;
      } else if (char == $rparen) {
        parenCount--;
        if (parenCount == 0) {
          advance();
          break;
        }
      }
      advance();

      // There is no ending delimiter, so `isDone` also means it is at the end
      // of a link destination.
      if (isDone) {
        break;
      }
    }

    _destination = substring(start, pos);
    return true;
  }

  /// Parses the **optional** link title, returns `true` if there is a valid
  /// link title.
  bool _parseTitle() {
    // See: https://spec.commonmark.org/0.30/#link-title
    // The whitespace should be followed by a title delimiter.
    final delimiter = charAt();
    if (delimiter != $apostrophe &&
        delimiter != $quote &&
        delimiter != $lparen) {
      return false;
    }

    final closeDelimiter = delimiter == $lparen ? $rparen : delimiter;
    advance();
    if (isDone) {
      return false;
    }
    final start = pos;

    // Looking for an un-escaped closing delimiter.
    while (true) {
      final char = charAt();
      if (char == $backslash) {
        advance();
      } else if (char == closeDelimiter) {
        break;
      }
      advance();
      if (isDone) {
        return false;
      }
    }

    if (isDone) {
      return false;
    }

    _title = substring(start, pos);

    // Advance past the closing delimiter.
    advance();
    return true;
  }
}
