import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

/// Converts AST `<pre><code>` elements into custom code widgets.
///
/// Parses the tree to extract language tag and code content, then
/// delegates widget creation to [codeWidgetBuilder].
class FencedCodeElementBuilder extends MarkdownElementBuilder {
  FencedCodeElementBuilder({
    required this.codeWidgetBuilder,
    this.streaming = false,
  });

  /// Signature: (BuildContext, String language, String code, bool closed) -> Widget
  final Widget Function(BuildContext, String, String, bool) codeWidgetBuilder;
  final bool streaming;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    String language = '';
    final codeParts = <String>[];
    bool closed = true;

    for (final child in element.children ?? []) {
      if (child is md.Element && child.tag == 'code') {
        final cls = child.attributes['class'] ?? '';
        if (cls.startsWith('language-')) {
          language = cls.substring('language-'.length);
        } else {
          language = cls;
        }
        for (final textChild in child.children ?? []) {
          if (textChild is md.Text) {
            codeParts.add(textChild.text);
          }
        }
        break;
      }
    }

    final code = codeParts.join();

    // Detect unclosed fence in streaming: the raw markdown data in the
    // AST root element's last child still has trailing content.
    // This heuristic works for streaming because the parser receives
    // incomplete markdown; a trailing fence line is absent.
    if (streaming) {
      final lines = code.split('\n');
      closed = lines.last.trim().startsWith('```') || code.isEmpty;
    }

    return codeWidgetBuilder(context, language, code, closed);
  }
}
