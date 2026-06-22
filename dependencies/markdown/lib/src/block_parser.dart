// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// @docImport 'block_syntaxes/setext_header_syntax.dart';
library;

import 'ast.dart';
import 'block_syntaxes/block_syntax.dart';
import 'block_syntaxes/blockquote_syntax.dart';
import 'block_syntaxes/code_block_syntax.dart';
import 'block_syntaxes/dummy_block_syntax.dart';
import 'block_syntaxes/empty_block_syntax.dart';
import 'block_syntaxes/header_syntax.dart';
import 'block_syntaxes/horizontal_rule_syntax.dart';
import 'block_syntaxes/html_block_syntax.dart';
import 'block_syntaxes/link_reference_definition_syntax.dart';
import 'block_syntaxes/ordered_list_syntax.dart';
import 'block_syntaxes/paragraph_syntax.dart';
import 'block_syntaxes/setext_header_syntax.dart';
import 'block_syntaxes/unordered_list_syntax.dart';
import 'document.dart';
import 'line.dart';

/// Maintains the internal state needed to parse a series of lines into blocks
/// of Markdown suitable for further inline parsing.
class BlockParser {
  final List<Line> lines;

  /// The Markdown document this parser is parsing.
  final Document document;

  /// The enabled block syntaxes.
  ///
  /// To turn a series of lines into blocks, each of these will be tried in
  /// turn. Order matters here.
  final List<BlockSyntax> blockSyntaxes = [];

  /// Index of the current line.
  int _pos = 0;

  /// Starting line of the last unconsumed content.
  int _start = 0;

  /// The lines from [_start] to [_pos] (inclusive), it works as a buffer for
  /// some blocks, for example:
  /// When the [ParagraphSyntax] parsing process is interrupted by the
  /// [SetextHeaderSyntax], so this structure is not a paragraph but a setext
  /// heading, then the [ParagraphSyntax.parse] does not have to retreat the
  /// reading position, it only needs to return `null`, the [SetextHeaderSyntax]
  /// will pick up the lines in [linesToConsume].
  List<Line> get linesToConsume => lines.getRange(_start, _pos + 1).toList();

  /// Whether the parser has encountered a blank line between two block-level
  /// elements.
  bool encounteredBlankLine = false;

  /// The collection of built-in block parsers.
  // TODO(kevmoo): this should be static const and private!
  // The fact that it's mutable is a BUG!
  @Deprecated(
    'Implementation member. '
    'Will be removed or make static in the next release.',
  )
  final List<BlockSyntax> standardBlockSyntaxes = [
    const EmptyBlockSyntax(),
    const HtmlBlockSyntax(),
    const SetextHeaderSyntax(),
    const HeaderSyntax(),
    const CodeBlockSyntax(),
    const BlockquoteSyntax(),
    const HorizontalRuleSyntax(),
    const UnorderedListSyntax(),
    const OrderedListSyntax(),
    const LinkReferenceDefinitionSyntax(),
    const ParagraphSyntax(),
  ];

  BlockParser(this.lines, this.document) {
    blockSyntaxes.addAll(document.blockSyntaxes);

    if (document.withDefaultBlockSyntaxes) {
      blockSyntaxes.addAll(standardBlockSyntaxes);
    } else {
      blockSyntaxes.add(const DummyBlockSyntax());
    }
  }

  /// Gets the current line.
  Line get current => lines[_pos];

  /// Gets the line after the current one or `null` if there is none.
  Line? get next {
    // Don't read past the end.
    if (_pos >= lines.length - 1) return null;
    return lines[_pos + 1];
  }

  /// Gets the line that is [linesAhead] lines ahead of the current one, or
  /// `null` if there is none.
  ///
  /// `peek(0)` is equivalent to [current].
  ///
  /// `peek(1)` is equivalent to [next].
  Line? peek(int linesAhead) {
    if (linesAhead < 0) {
      throw ArgumentError('Invalid linesAhead: $linesAhead; must be >= 0.');
    }
    // Don't read past the end.
    if (_pos >= lines.length - linesAhead) return null;
    return lines[_pos + linesAhead];
  }

  /// Advances the reading position by one line.
  void advance() {
    _pos++;
  }

  /// Retreats the reading position by one line.
  void retreat() {
    _pos--;
  }

  /// Retreats the reading position by [count] lines.
  void retreatBy(int count) {
    _pos -= count;
  }

  bool get isDone => _pos >= lines.length;

  /// Gets whether or not the current line matches the given pattern.
  bool matches(RegExp regex) {
    if (isDone) return false;
    return regex.hasMatch(current.content);
  }

  /// Gets whether or not the next line matches the given pattern.
  bool matchesNext(RegExp regex) {
    if (next == null) return false;
    return regex.hasMatch(next!.content);
  }

  /// The parent [BlockSyntax] when it is running inside a nested syntax.
  BlockSyntax? get parentSyntax => _parentSyntax;
  BlockSyntax? _parentSyntax;

  /// Whether the [SetextHeaderSyntax] is disabled temporarily.
  bool get setextHeadingDisabled => _setextHeadingDisabled;
  bool _setextHeadingDisabled = false;

  /// The [BlockSyntax] which is running now.
  /// The value is `null` until we found the first matched [BlockSyntax].
  BlockSyntax? get currentSyntax => _currentSyntax;
  BlockSyntax? _currentSyntax;

  /// The [BlockSyntax] which is running before the [currentSyntax].
  BlockSyntax? get previousSyntax => _previousSyntax;
  BlockSyntax? _previousSyntax;

  List<Node> parseLines({
    BlockSyntax? parentSyntax,
    bool disabledSetextHeading = false,
  }) {
    _parentSyntax = parentSyntax;
    _setextHeadingDisabled = disabledSetextHeading;

    final blocks = <Node>[];

    // If the `_pos` does not change before and after `parse()`, never try to
    // parse the line at `_pos` with the same syntax again.
    // For example the `TableSyntax` might not advance the `_pos` in `parse`
    // method, beause of the header row does not match the delimiter row in the
    // number of cells, which makes a table like structure not be recognized.
    BlockSyntax? neverMatch;

    var iterationsWithoutProgress = 0;
    while (!isDone) {
      final positionBefore = _pos;
      for (final syntax in blockSyntaxes) {
        if (neverMatch == syntax) {
          continue;
        }

        if (syntax.canParse(this)) {
          _previousSyntax = _currentSyntax;
          _currentSyntax = syntax;
          final block = syntax.parse(this);
          if (block != null) {
            blocks.add(block);
          }
          neverMatch = _pos != positionBefore ? null : syntax;

          if (block != null ||
              syntax is EmptyBlockSyntax ||
              syntax is LinkReferenceDefinitionSyntax) {
            _start = _pos;
          }

          break;
        }
      }
      // Count the number of iterations without progress.
      // This ensures that we don't have an infinite loop. And if we have an
      // infinite loop, it's easier to gracefully recover from an error, than
      // it is to discover an kill an isolate that's stuck in an infinite loop.
      // Technically, it should be perfectly safe to remove this check
      // But as it's possible to inject custom BlockSyntax implementations and
      // combine existing ones, it is hard to promise that no combination can't
      // trigger an infinite loop
      if (positionBefore == _pos) {
        iterationsWithoutProgress++;
        if (iterationsWithoutProgress > 2) {
          // If this happens we throw an error to avoid having the parser
          // running in an infinite loop. An error is easier to handle.
          // If you see this error in production please file a bug!
          throw AssertionError('BlockParser.parseLines is not advancing');
        }
      } else {
        iterationsWithoutProgress = 0;
      }
    }

    return blocks;
  }
}
