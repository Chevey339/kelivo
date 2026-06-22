// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'ast.dart';
import 'block_parser.dart';
import 'block_syntaxes/block_syntax.dart';
import 'extension_set.dart';
import 'inline_parser.dart';
import 'inline_syntaxes/inline_syntax.dart';
import 'line.dart';
import 'util.dart';

/// Maintains the context needed to parse a Markdown document.
class Document {
  final Map<String, LinkReference> linkReferences = {};

  /// Footnote ref count, keys are case-sensitive and added by define syntax.
  final footnoteReferences = <String, int>{};

  /// Footnote labels by appearing order.
  ///
  /// They are case-insensitive and added by ref syntax.
  final footnoteLabels = <String>[];
  final Resolver? linkResolver;
  final Resolver? imageLinkResolver;
  final bool encodeHtml;

  /// Whether to use default block syntaxes.
  final bool withDefaultBlockSyntaxes;

  /// Whether to use default inline syntaxes.
  ///
  /// Need to set both [withDefaultInlineSyntaxes] and [encodeHtml] to
  /// `false` to disable all inline syntaxes including html encoding syntaxes.
  final bool withDefaultInlineSyntaxes;

  final _blockSyntaxes = <BlockSyntax>{};
  final _inlineSyntaxes = <InlineSyntax>{};
  final bool hasCustomInlineSyntaxes;

  Iterable<BlockSyntax> get blockSyntaxes => _blockSyntaxes;

  Iterable<InlineSyntax> get inlineSyntaxes => _inlineSyntaxes;

  Document({
    Iterable<BlockSyntax>? blockSyntaxes,
    Iterable<InlineSyntax>? inlineSyntaxes,
    ExtensionSet? extensionSet,
    this.linkResolver,
    this.imageLinkResolver,
    this.encodeHtml = true,
    this.withDefaultBlockSyntaxes = true,
    this.withDefaultInlineSyntaxes = true,
  }) : hasCustomInlineSyntaxes =
           (inlineSyntaxes?.isNotEmpty ?? false) ||
           (extensionSet?.inlineSyntaxes.isNotEmpty ?? false) {
    if (blockSyntaxes != null) {
      _blockSyntaxes.addAll(blockSyntaxes);
    }
    if (inlineSyntaxes != null) {
      _inlineSyntaxes.addAll(inlineSyntaxes);
    }

    if (extensionSet == null) {
      if (withDefaultBlockSyntaxes) {
        _blockSyntaxes.addAll(ExtensionSet.commonMark.blockSyntaxes);
      }

      if (withDefaultInlineSyntaxes) {
        _inlineSyntaxes.addAll(ExtensionSet.commonMark.inlineSyntaxes);
      }
    } else {
      _blockSyntaxes.addAll(extensionSet.blockSyntaxes);
      _inlineSyntaxes.addAll(extensionSet.inlineSyntaxes);
    }
  }

  /// Parses the given [lines] of Markdown to a series of AST nodes.
  List<Node> parseLines(List<String> lines) =>
      parseLineList(lines.map(Line.new).toList());

  /// Parses the given [text] to a series of AST nodes.
  List<Node> parse(String text) => parseLineList(text.toLines());

  /// Parses the given [lines] of [Line] to a series of AST nodes.
  List<Node> parseLineList(List<Line> lines) {
    final nodes = BlockParser(lines, this).parseLines();
    _parseInlineContent(nodes);
    // Do filter after parsing inline as we need ref count.
    return _filterFootnotes(nodes);
  }

  /// Parses the given inline Markdown [text] to a series of AST nodes.
  List<Node> parseInline(String text) => InlineParser(text, this).parse();

  void _parseInlineContent(List<Node> nodes) {
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is UnparsedContent) {
        final inlineNodes = parseInline(node.textContent);
        nodes.removeAt(i);
        nodes.insertAll(i, inlineNodes);
        i += inlineNodes.length - 1;
      } else if (node is Element && node.children != null) {
        _parseInlineContent(node.children!);
      }
    }
  }

  /// Footnotes could be defined in arbitrary positions of a document, we need
  /// to distinguish them and put them behind; and every footnote definition
  /// may have multiple backrefs, we need to append backrefs for it.
  List<Node> _filterFootnotes(List<Node> nodes) {
    final footnotes = <Element>[];
    final blocks = <Node>[];
    for (final node in nodes) {
      if (node is Element &&
          node.tag == 'li' &&
          footnoteReferences.containsKey(node.footnoteLabel)) {
        final label = node.footnoteLabel;
        var count = 0;
        if (label != null && (count = footnoteReferences[label] ?? 0) > 0) {
          footnotes.add(node);
          final children = node.children;
          if (children != null) {
            _appendBackref(children, Uri.encodeComponent(label), count);
          }
        }
      } else {
        blocks.add(node);
      }
    }

    if (footnotes.isNotEmpty) {
      // Sort footnotes by appearing order.
      final ordinal = {
        for (var i = 0; i < footnoteLabels.length; i++)
          'fn-${footnoteLabels[i]}': i,
      };
      footnotes.sort((l, r) {
        final idl = l.attributes['id']?.toLowerCase() ?? '';
        final idr = r.attributes['id']?.toLowerCase() ?? '';
        return (ordinal[idl] ?? 0) - (ordinal[idr] ?? 0);
      });
      final list = Element('ol', footnotes);

      // Ignore GFM attribute: <data-footnotes>.
      final section = Element('section', [list])
        ..attributes['class'] = 'footnotes';
      blocks.add(section);
    }
    return blocks;
  }

  /// Generate backref nodes, append them to footnote definition's last child.
  void _appendBackref(List<Node> children, String ref, int count) {
    final refs = [
      for (var i = 0; i < count; i++) ...[
        Text(' '),
        _ElementExt.footnoteAnchor(ref, i),
      ],
    ];
    if (children.isEmpty) {
      children.addAll(refs);
    } else {
      final last = children.last;
      if (last is Element) {
        last.children?.addAll(refs);
      } else {
        children.last = Element('p', [last, ...refs]);
      }
    }
  }
}

extension _ElementExt on Element {
  static Element footnoteAnchor(String ref, int i) {
    final num = '${i + 1}';
    final suffix = i > 0 ? '-$num' : '';
    final e = Element.empty('tag');
    e.match;
    return Element('a', [
        Text('\u21a9'),
        if (i > 0)
          Element('sup', [Text(num)])..attributes['class'] = 'footnote-ref',
      ])
      // Ignore GFM's attributes:
      // <data-footnote-backref aria-label="Back to content">.
      ..attributes['href'] = '#fnref-$ref$suffix'
      ..attributes['class'] = 'footnote-backref';
  }

  String get match => tag;
}

/// A [link reference
/// definition](https://spec.commonmark.org/0.30/#link-reference-definitions).
class LinkReference {
  /// The [link label](https://spec.commonmark.org/0.30/#link-label).
  ///
  /// Temporarily, this class is also being used to represent the link data for
  /// an inline link (the destination and title), but this should change before
  /// the package is released.
  final String label;

  /// The [link destination](https://spec.commonmark.org/0.30/#link-destination).
  final String destination;

  /// The [link title](https://spec.commonmark.org/0.30/#link-title).
  final String? title;

  /// Construct a new [LinkReference], with all necessary fields.
  ///
  /// If the parsed link reference definition does not include a title, use
  /// `null` for the [title] parameter.
  LinkReference(this.label, this.destination, this.title);
}
