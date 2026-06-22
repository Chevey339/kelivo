// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../charcode.dart';
import '../document.dart';
import '../inline_parser.dart';
import '../util.dart';
import 'delimiter_syntax.dart';
import 'footnote_ref_syntax.dart';

/// A helper class holds params of link context.
// Footnote creation needs other info in [LinkSyntax._tryCreateReferenceLink].
// TODO(kevmoo): this type should be private. Ideally a Record.
@Deprecated('Implementation class that should not be used directly.')
class LinkContext {
  final InlineParser parser;
  final SimpleDelimiter opener;
  final List<Node> Function() getChildren;

  const LinkContext(this.parser, this.opener, this.getChildren);
}

/// Matches links like `[blah][label]` and `[blah](url)`.
class LinkSyntax extends DelimiterSyntax {
  static final _entirelyWhitespacePattern = RegExp(r'^\s*$');

  final Resolver linkResolver;

  LinkSyntax({
    Resolver? linkResolver,
    String pattern = r'\[',
    int startCharacter = $lbracket,
  }) : linkResolver = (linkResolver ?? ((String _, [String? _]) => null)),
       super(pattern, startCharacter: startCharacter);

  @override
  Iterable<Node>? close(
    InlineParser parser,
    covariant SimpleDelimiter opener,
    Delimiter? closer, {
    String? tag,
    required List<Node> Function() getChildren,
  }) {
    final context = LinkContext(parser, opener, getChildren);
    final text = parser.source.substring(opener.endPos, parser.pos);
    // The current character is the `]` that closed the link text. Examine the
    // next character, to determine what type of link we might have (a '('
    // means a possible inline link; otherwise a possible reference link).
    if (parser.pos + 1 >= parser.source.length) {
      // The `]` is at the end of the document, but this may still be a valid
      // shortcut reference link.
      return _tryCreateReferenceLink(context, text);
    }

    // Peek at the next character; don't advance, so as to avoid later stepping
    // backward.
    final char = parser.charAt(parser.pos + 1);

    if (char == $lparen) {
      // Maybe an inline link, like `[text](destination)`.
      parser.advanceBy(1);
      final leftParenIndex = parser.pos;
      final inlineLink = _parseInlineLink(parser);
      if (inlineLink != null) {
        return [
          _tryCreateInlineLink(parser, inlineLink, getChildren: getChildren),
        ];
      }
      // At this point, we've matched `[...](`, but that `(` did not pan out to
      // be an inline link. We must now check if `[...]` is simply a shortcut
      // reference link.

      // Reset the parser position.
      parser.pos = leftParenIndex;
      parser.advanceBy(-1);
      return _tryCreateReferenceLink(context, text);
    }

    if (char == $lbracket) {
      parser.advanceBy(1);
      // At this point, we've matched `[...][`. Maybe a *full* reference link,
      // like `[foo][bar]` or a *collapsed* reference link, like `[foo][]`.
      if (parser.pos + 1 < parser.source.length &&
          parser.charAt(parser.pos + 1) == $rbracket) {
        // That opening `[` is not actually part of the link. Maybe a
        // *shortcut* reference link (followed by a `[`).
        parser.advanceBy(1);
        return _tryCreateReferenceLink(context, text);
      }
      final label = _parseReferenceLinkLabel(parser);
      if (label != null) {
        return _tryCreateReferenceLink(context, label, secondary: true);
      }
      return null;
    }

    // The link text (inside `[...]`) was not followed with a opening `(` nor
    // an opening `[`. Perhaps just a simple shortcut reference link (`[...]`).
    return _tryCreateReferenceLink(context, text);
  }

  /// Resolve a possible reference link.
  ///
  /// Uses [linkReferences], [linkResolver], and [createNode] to try to
  /// resolve [label] into a [Node]. If [label] is defined in
  /// [linkReferences] or can be resolved by [linkResolver], returns a [Node]
  /// that links to the resolved URL.
  ///
  /// Otherwise, returns `null`.
  ///
  /// [label] does not need to be normalized.
  Node? _resolveReferenceLink(
    String label,
    Map<String, LinkReference> linkReferences, {
    required List<Node> Function() getChildren,
  }) {
    final linkReference = linkReferences[normalizeLinkLabel(label)];
    if (linkReference != null) {
      return createNode(
        linkReference.destination,
        linkReference.title,
        getChildren: getChildren,
      );
    } else {
      // This link has no reference definition. But we allow users of the
      // library to specify a custom resolver function ([linkResolver]) that
      // may choose to handle this. Otherwise, it's just treated as plain
      // text.

      // Normally, label text does not get parsed as inline Markdown. However,
      // for the benefit of the link resolver, we need to at least escape
      // brackets, so that, e.g. a link resolver can receive `[\[\]]` as `[]`.
      final resolved = linkResolver(
        label
            .replaceAll(r'\\', r'\')
            .replaceAll(r'\[', '[')
            .replaceAll(r'\]', ']'),
      );
      if (resolved != null) {
        getChildren();
      }
      return resolved;
    }
  }

  /// Create the node represented by a Markdown link.
  Node createNode(
    String destination,
    String? title, {
    required List<Node> Function() getChildren,
  }) {
    final children = getChildren();
    final element = Element('a', children);
    element.attributes['href'] = normalizeLinkDestination(
      escapePunctuation(destination),
    );
    if (title != null && title.isNotEmpty) {
      element.attributes['title'] = normalizeLinkTitle(
        escapePunctuation(title),
      );
    }
    return element;
  }

  /// Tries to create a reference link node.
  ///
  /// Returns the nodes if it was successfully created, `null` otherwise.
  Iterable<Node>? _tryCreateReferenceLink(
    LinkContext context,
    String label, {
    bool? secondary,
  }) {
    final parser = context.parser;
    final getChildren = context.getChildren;
    final link = _resolveReferenceLink(
      label,
      parser.document.linkReferences,
      getChildren: getChildren,
    );
    if (link != null) {
      return [link];
    }
    return FootnoteRefSyntax.tryCreateFootnoteLink(
      context,
      label,
      secondary: secondary,
    );
  }

  // Tries to create an inline link node.
  //
  /// Returns the link if it was successfully created, `null` otherwise.
  Node _tryCreateInlineLink(
    InlineParser parser,
    InlineLink link, {
    required List<Node> Function() getChildren,
  }) {
    return createNode(link.destination, link.title, getChildren: getChildren);
  }

  /// Parse a reference link label at the current position.
  ///
  /// Specifically, [InlineParser.pos] is expected to be pointing at the
  /// `[` which opens the link label.
  ///
  /// Returns the label if it could be parsed, or `null` if not.
  String? _parseReferenceLinkLabel(InlineParser parser) {
    // Walk past the opening `[`.
    parser.advanceBy(1);
    if (parser.isDone) return null;

    final buffer = StringBuffer();
    while (true) {
      final char = parser.charAt(parser.pos);
      if (char == $backslash) {
        parser.advanceBy(1);
        if (parser.isDone) return null;
        final next = parser.charAt(parser.pos);
        if (next != $backslash && next != $rbracket) {
          buffer.writeCharCode(char);
        }
        buffer.writeCharCode(next);
      } else if (char == $lbracket) {
        return null;
      } else if (char == $rbracket) {
        break;
      } else {
        buffer.writeCharCode(char);
      }
      parser.advanceBy(1);
      if (parser.isDone) return null;
      // TODO(srawlins): only check 999 characters, for performance reasons?
    }

    final label = buffer.toString();

    // A link label must contain at least one non-whitespace character.
    if (_entirelyWhitespacePattern.hasMatch(label)) return null;

    return label;
  }

  /// Parse an inline [InlineLink] at the current position.
  ///
  /// At this point, we have parsed a link's (or image's) opening `[`, and then
  /// a matching closing `]`, and [InlineParser.pos] is pointing at an opening
  /// `(`.
  /// This method will then attempt to parse a link destination wrapped in `<>`,
  /// such as `(<http://url>)`, or a bare link destination, such as
  /// `(http://url)`, or a link destination with a title, such as
  /// `(http://url "title")`.
  ///
  /// Returns the [InlineLink] if one was parsed, or `null` if not.
  InlineLink? _parseInlineLink(InlineParser parser) {
    // Start walking to the character just after the opening `(`.
    parser.advanceBy(1);

    _moveThroughWhitespace(parser);
    if (parser.isDone) return null; // EOF. Not a link.

    if (parser.charAt(parser.pos) == $lt) {
      // Maybe a `<...>`-enclosed link destination.
      return _parseInlineBracketedLink(parser);
    } else {
      return _parseInlineBareDestinationLink(parser);
    }
  }

  /// Parse an inline link with a bracketed destination (a destination wrapped
  /// in `<...>`). The current position of the parser must be the first
  /// character of the destination.
  ///
  /// Returns the link if it was successfully created, `null` otherwise.
  InlineLink? _parseInlineBracketedLink(InlineParser parser) {
    parser.advanceBy(1);
    if (parser.isDone) return null;

    final buffer = StringBuffer();
    while (true) {
      final char = parser.charAt(parser.pos);
      if (char == $backslash) {
        parser.advanceBy(1);
        if (parser.isDone) return null;
        final next = parser.charAt(parser.pos);
        // TODO: Follow the backslash spec better here.
        // https://spec.commonmark.org/0.30/#backslash-escapes
        if (next != $backslash && next != $gt) {
          buffer.writeCharCode(char);
        }
        buffer.writeCharCode(next);
      } else if (char == $lf || char == $cr || char == $ff) {
        // Not a link (no line breaks allowed within `<...>`).
        return null;
      } else if (char == $space) {
        buffer.write('%20');
      } else if (char == $gt) {
        break;
      } else {
        buffer.writeCharCode(char);
      }
      parser.advanceBy(1);
      if (parser.isDone) return null;
    }
    final destination = buffer.toString();

    parser.advanceBy(1);
    if (parser.isDone) return null;
    final char = parser.charAt(parser.pos);
    if (char == $space || char == $lf || char == $cr || char == $ff) {
      final title = _parseTitle(parser);
      if (title == null &&
          (parser.isDone || parser.charAt(parser.pos) != $rparen)) {
        // This looked like an inline link, until we found this $space
        // followed by mystery characters; no longer a link.
        return null;
      }
      return InlineLink(destination, title: title);
    } else if (char == $rparen) {
      return InlineLink(destination);
    } else {
      // We parsed something like `[foo](<url>X`. Not a link.
      return null;
    }
  }

  /// Parse an inline link with a "bare" destination (a destination _not_
  /// wrapped in `<...>`). The current position of the parser must be the first
  /// character of the destination.
  ///
  /// Returns the link if it was successfully created, `null` otherwise.
  InlineLink? _parseInlineBareDestinationLink(InlineParser parser) {
    // According to
    // [CommonMark](https://spec.commonmark.org/0.30/#link-destination):
    //
    // > A link destination consists of [...] a nonempty sequence of
    // > characters [...], and includes parentheses only if (a) they are
    // > backslash-escaped or (b) they are part of a balanced pair of
    // > unescaped parentheses.
    //
    // We need to count the open parens. We start with 1 for the paren that
    // opened the destination.
    var parenCount = 1;
    final buffer = StringBuffer();

    while (true) {
      final char = parser.charAt(parser.pos);
      switch (char) {
        case $backslash:
          parser.advanceBy(1);
          if (parser.isDone) return null; // EOF. Not a link.
          final next = parser.charAt(parser.pos);
          // Parentheses may be escaped.
          //
          // https://spec.commonmark.org/0.30/#example-494
          if (next != $backslash && next != $lparen && next != $rparen) {
            buffer.writeCharCode(char);
          }
          buffer.writeCharCode(next);
          break;

        case $space:
        case $lf:
        case $cr:
        case $ff:
          final destination = buffer.toString();
          final title = _parseTitle(parser);
          if (title == null &&
              (parser.isDone || parser.charAt(parser.pos) != $rparen)) {
            // This looked like an inline link, until we found this $space
            // followed by mystery characters; no longer a link.
            return null;
          }
          // [_parseTitle] made sure the title was follwed by a closing `)`
          // (but it's up to the code here to examine the balance of
          // parentheses).
          parenCount--;
          if (parenCount == 0) {
            return InlineLink(destination, title: title);
          }
          break;

        case $lparen:
          parenCount++;
          buffer.writeCharCode(char);
          break;

        case $rparen:
          parenCount--;
          if (parenCount == 0) {
            final destination = buffer.toString();
            return InlineLink(destination);
          }
          buffer.writeCharCode(char);
          break;

        default:
          buffer.writeCharCode(char);
      }
      parser.advanceBy(1);
      if (parser.isDone) return null; // EOF. Not a link.
    }
  }

  // Walk the parser forward through any whitespace.
  void _moveThroughWhitespace(InlineParser parser) {
    while (!parser.isDone) {
      final char = parser.charAt(parser.pos);
      if (char != $space &&
          char != $tab &&
          char != $lf &&
          char != $vt &&
          char != $cr &&
          char != $ff) {
        return;
      }
      parser.advanceBy(1);
    }
  }

  /// Parses a link title in [parser] at it's current position. The parser's
  /// current position should be a whitespace character that followed a link
  /// destination.
  ///
  /// Returns the title if it was successfully parsed, `null` otherwise.
  String? _parseTitle(InlineParser parser) {
    _moveThroughWhitespace(parser);
    if (parser.isDone) return null;

    // The whitespace should be followed by a title delimiter.
    final delimiter = parser.charAt(parser.pos);
    if (delimiter != $apostrophe &&
        delimiter != $quote &&
        delimiter != $lparen) {
      return null;
    }

    final closeDelimiter = delimiter == $lparen ? $rparen : delimiter;
    parser.advanceBy(1);
    if (parser.isDone) return null;

    // Now we look for an un-escaped closing delimiter.
    final buffer = StringBuffer();
    while (true) {
      final char = parser.charAt(parser.pos);
      if (char == $backslash) {
        parser.advanceBy(1);
        if (parser.isDone) return null;
        final next = parser.charAt(parser.pos);
        if (next != $backslash && next != closeDelimiter) {
          buffer.writeCharCode(char);
        }
        buffer.writeCharCode(next);
      } else if (char == closeDelimiter) {
        break;
      } else {
        buffer.writeCharCode(char);
      }
      parser.advanceBy(1);
      if (parser.isDone) return null;
    }
    final title = buffer.toString();

    // Advance past the closing delimiter.
    parser.advanceBy(1);
    if (parser.isDone) return null;
    _moveThroughWhitespace(parser);
    if (parser.isDone) return null;
    if (parser.charAt(parser.pos) != $rparen) return null;
    return title;
  }
}

class InlineLink {
  final String destination;
  final String? title;

  InlineLink(this.destination, {this.title});
}
