// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'ast.dart';
import 'charcode.dart';
import 'document.dart';
import 'inline_syntaxes/autolink_syntax.dart';
import 'inline_syntaxes/code_syntax.dart';
import 'inline_syntaxes/decode_html_syntax.dart';
import 'inline_syntaxes/delimiter_syntax.dart';
import 'inline_syntaxes/email_autolink_syntax.dart';
import 'inline_syntaxes/emphasis_syntax.dart';
import 'inline_syntaxes/escape_html_syntax.dart';
import 'inline_syntaxes/escape_syntax.dart';
import 'inline_syntaxes/image_syntax.dart';
import 'inline_syntaxes/inline_syntax.dart';
import 'inline_syntaxes/line_break_syntax.dart';
import 'inline_syntaxes/link_syntax.dart';
import 'inline_syntaxes/soft_line_break_syntax.dart';
import 'inline_syntaxes/text_syntax.dart';

/// Maintains the internal state needed to parse inline span elements in
/// Markdown.
class InlineParser {
  static final List<InlineSyntax>
  _defaultSyntaxes = List<InlineSyntax>.unmodifiable(<InlineSyntax>[
    EmailAutolinkSyntax(),
    AutolinkSyntax(),
    LineBreakSyntax(),
    // Parse "**strong**" and "*emphasis*" tags.
    EmphasisSyntax.asterisk(),
    // Parse "__strong__" and "_emphasis_" tags.
    EmphasisSyntax.underscore(),
    CodeSyntax(),
    SoftLineBreakSyntax(),
    // We will add the LinkSyntax once we know about the specific link resolver.
  ]);

  /// The string of Markdown being parsed.
  final String source;

  /// The Markdown document this parser is parsing.
  final Document document;

  final syntaxes = <InlineSyntax>[];

  /// The current read position.
  int pos = 0;

  /// Starting position of the last unconsumed text.
  int start = 0;

  /// The delimiter stack tracking possible opening delimiters and closing
  /// delimiters for [DelimiterSyntax] nodes.
  final _delimiterStack = <Delimiter>[];

  /// The tree of parsed HTML nodes.
  final _tree = <Node>[];

  InlineParser(this.source, this.document) {
    // User specified syntaxes are the first syntaxes to be evaluated.
    syntaxes.addAll(document.inlineSyntaxes);

    // This first RegExp matches plain text to accelerate parsing. It's written
    // so that it does not match any prefix of any following syntaxes. Most
    // Markdown is plain text, so it's faster to match one RegExp per 'word'
    // rather than fail to match all the following RegExps at each non-syntax
    // character position.
    if (document.hasCustomInlineSyntaxes) {
      // We should be less aggressive in blowing past "words".
      syntaxes.add(TextSyntax(r'[A-Za-z0-9]+(?=\s)'));
    } else {
      syntaxes.add(TextSyntax(r'[ \tA-Za-z0-9]*[A-Za-z0-9](?=\s)'));
    }

    if (document.withDefaultInlineSyntaxes) {
      // Custom link resolvers go after the generic text syntax.
      syntaxes.addAll([
        EscapeSyntax(),
        DecodeHtmlSyntax(),
        LinkSyntax(linkResolver: document.linkResolver),
        ImageSyntax(linkResolver: document.imageLinkResolver),
      ]);

      syntaxes.addAll(_defaultSyntaxes);
    }

    if (encodeHtml) {
      syntaxes.addAll([
        EscapeHtmlSyntax(),
        // Leave already-encoded HTML entities alone. Ensures we don't turn
        // "&amp;" into "&amp;amp;"
        TextSyntax('&[#a-zA-Z0-9]*;', startCharacter: $ampersand),
      ]);
    }
  }

  List<Node> parse() {
    while (!isDone) {
      // A right bracket (']') is special. Hitting this character triggers the
      // "look for link or image" procedure.
      // See https://spec.commonmark.org/0.30/#an-algorithm-for-parsing-nested-emphasis-and-links.
      if (charAt(pos) == $rbracket) {
        writeText();
        _linkOrImage();
        continue;
      }

      // See if the current text matches any defined Markdown syntax.
      if (syntaxes.any((syntax) => syntax.tryMatch(this))) continue;

      // If we got here, it's just text.
      advanceBy(1);
    }

    // Write any trailing text content to a Text node.
    writeText();
    _processDelimiterRun(-1);
    _combineAdjacentText(_tree);
    return _tree;
  }

  /// Look back through the delimiter stack to see if we've found a link or
  /// image.
  ///
  /// This is the "look for link or image" routine from the CommonMark spec:
  /// https://spec.commonmark.org/0.30/#look-for-link-or-image.
  void _linkOrImage() {
    final index = _delimiterStack.lastIndexWhere(
      (d) => d.char == $lbracket || d.char == $exclamation,
    );
    if (index == -1) {
      // Never found a possible open bracket. This is just a literal "]".
      addNode(Text(']'));
      advanceBy(1);
      start = pos;
      return;
    }
    final delimiter = _delimiterStack[index] as SimpleDelimiter;
    if (!delimiter.isActive) {
      _delimiterStack.removeAt(index);
      addNode(Text(']'));
      advanceBy(1);
      start = pos;
      return;
    }
    final syntax = delimiter.syntax;
    if (syntax is LinkSyntax && syntaxes.any((e) => e is LinkSyntax)) {
      final nodeIndex = _tree.lastIndexWhere((n) => n == delimiter.node);
      final linkNodes = syntax.close(
        this,
        delimiter,
        null,
        getChildren: () {
          _processDelimiterRun(index);
          // All of the nodes which lie past [index] are children of this
          // link/image.
          final children = _tree.sublist(nodeIndex + 1, _tree.length);
          _tree.removeRange(nodeIndex + 1, _tree.length);
          return children;
        },
      );
      if (linkNodes != null) {
        _delimiterStack.removeAt(index);
        if (delimiter.char == $lbracket) {
          for (final d in _delimiterStack.sublist(0, index)) {
            if (d.char == $lbracket) d.isActive = false;
          }
        }
        _tree.replaceRange(nodeIndex, _tree.length, linkNodes);
        advanceBy(1);
        start = pos;
      } else {
        _delimiterStack.removeAt(index);
        pos = start;
        advanceBy(1);
      }
    } else {
      throw StateError(
        'Non-link syntax delimiter found with character '
        '"${delimiter.char}"',
      );
    }
  }

  /// Rules 9 and 10.
  bool _canFormEmphasis(Delimiter opener, Delimiter closer) {
    if ((opener.canOpen && opener.canClose) ||
        (closer.canOpen && closer.canClose)) {
      return (opener.length + closer.length) % 3 != 0 ||
          (opener.length % 3 == 0 && closer.length % 3 == 0);
    } else {
      return true;
    }
  }

  /// Processes [DelimiterRun] type delimiters from [bottomIndex] and up.
  ///
  /// This is the same strategy as "process emphasis" routine according to the
  /// CommonMark spec: https://spec.commonmark.org/0.30/#phase-2-inline-structure.
  void _processDelimiterRun(int bottomIndex) {
    var currentIndex = bottomIndex + 1;
    // Track the lowest index where we might find an open delimiter given a
    // closing delimiter length modulo 3.
    // Each key in this map is an open delimiter character. Each value is a
    // 3-element list. Each value in the list is the lowest index for the given
    // delimiter length modulo 3 (0, 1, 2).
    final openersBottom = <int, List<int>>{};
    while (currentIndex < _delimiterStack.length) {
      final closer = _delimiterStack[currentIndex];
      if (!closer.canClose || closer is! DelimiterRun) {
        currentIndex++;
        continue;
      }
      openersBottom.putIfAbsent(closer.char, () => List.filled(3, bottomIndex));
      final openersBottomPerCloserLength = openersBottom[closer.char]!;
      final openerBottom = openersBottomPerCloserLength[closer.length % 3];
      final openerIndex = _delimiterStack.lastIndexWhere(
        (d) =>
            d.char == closer.char && d.canOpen && _canFormEmphasis(d, closer),
        currentIndex - 1,
      );
      if (openerIndex > bottomIndex && openerIndex > openerBottom) {
        // Found an opener for [closer].
        final opener = _delimiterStack[openerIndex];
        if (opener is! DelimiterRun) {
          currentIndex++;
          continue;
        }
        final matchedTagIndex = opener.tags.lastIndexWhere(
          (e) =>
              opener.length >= e.indicatorLength &&
              closer.length >= e.indicatorLength,
        );
        if (matchedTagIndex == -1) {
          currentIndex++;
          continue;
        }
        final matchedTag = opener.tags[matchedTagIndex];
        final indicatorLength = matchedTag.indicatorLength;
        final openerTextNode = opener.node;
        final openerTextNodeIndex = _tree.indexOf(openerTextNode);
        final closerTextNode = closer.node;
        var closerTextNodeIndex = _tree.indexOf(closerTextNode);
        final nodes = opener.syntax.close(
          this,
          opener,
          closer,
          tag: matchedTag.tag,
          getChildren: () =>
              _tree.sublist(openerTextNodeIndex + 1, closerTextNodeIndex),
        );
        // Replace all of the nodes between the opener and the closer (which
        // are now the new emphasis node's children) with the emphasis node.
        _tree.replaceRange(
          openerTextNodeIndex + 1,
          closerTextNodeIndex,
          nodes!,
        );
        // Slide [closerTextNodeIndex] back accordingly.
        closerTextNodeIndex = openerTextNodeIndex + 2;

        _delimiterStack.removeRange(openerIndex + 1, currentIndex);
        // Slide [currentIndex] back accordingly.
        currentIndex = openerIndex + 1;

        // Remove delimiter characters, possibly removing nodes from the tree
        // and Delimiters from the delimiter stack.
        if (opener.length == indicatorLength) {
          _tree.removeAt(openerTextNodeIndex);
          _delimiterStack.removeAt(openerIndex);
          // Slide [currentIndex] and [closerTextNodeIndex] back accordingly.
          currentIndex--;
          closerTextNodeIndex--;
        } else {
          final newOpenerTextNode = Text(
            openerTextNode.text.substring(indicatorLength),
          );
          _tree[openerTextNodeIndex] = newOpenerTextNode;
          opener.node = newOpenerTextNode;
        }

        if (closer.length == indicatorLength) {
          _tree.removeAt(closerTextNodeIndex);
          _delimiterStack.removeAt(currentIndex);
          // [currentIndex] has just moved to point at the next delimiter;
          // leave it.
        } else {
          final newCloserTextNode = Text(
            closerTextNode.text.substring(indicatorLength),
          );
          _tree[closerTextNodeIndex] = newCloserTextNode;
          closer.node = newCloserTextNode;
          // [currentIndex] needs to be considered again; leave it.
        }
      } else {
        // No opener is found.
        openersBottomPerCloserLength[closer.length % 3] = currentIndex - 1;
        if (!closer.canOpen) {
          _delimiterStack.removeAt(currentIndex);
          // This advances [currentIndex] to the next delimiter.
        } else {
          currentIndex++;
        }
      }
    }

    _delimiterStack.removeRange(bottomIndex + 1, _delimiterStack.length);
  }

  // Combine any remaining adjacent Text nodes. This is important to produce
  // correct output across newlines, where whitespace is sometimes compressed.
  void _combineAdjacentText(List<Node> nodes) {
    for (var i = 0; i < nodes.length - 1; i++) {
      final node = nodes[i];
      if (node is Element && node.children != null) {
        _combineAdjacentText(node.children!);
        continue;
      }
      if (node is Text && nodes[i + 1] is Text) {
        final buffer = StringBuffer(
          '${node.textContent}${nodes[i + 1].textContent}',
        );
        var j = i + 2;
        while (j < nodes.length && nodes[j] is Text) {
          buffer.write(nodes[j].textContent);
          j++;
        }
        nodes[i] = Text(buffer.toString());
        nodes.removeRange(i + 1, j);
      }
    }
  }

  int charAt(int index) => source.codeUnitAt(index);

  void writeText() {
    if (pos == start) {
      return;
    }
    final text = source.substring(start, pos);
    _tree.add(Text(text));
    start = pos;
  }

  /// Add [node] to the current tree.
  void addNode(Node node) {
    _tree.add(node);
  }

  /// Push [delimiter] onto the stack of [Delimiter]s.
  void pushDelimiter(Delimiter delimiter) => _delimiterStack.add(delimiter);

  bool get isDone => pos == source.length;

  void advanceBy(int length) {
    pos += length;
  }

  void consume(int length) {
    pos += length;
    start = pos;
  }

  bool get encodeHtml => document.encodeHtml;
}
