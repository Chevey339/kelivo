import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import 'inline_math_scrollable.dart';

class LatexElementBuilder extends MarkdownElementBuilder {
  LatexElementBuilder({this.baseStyle});

  final TextStyle? baseStyle;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final tex = element.textContent;
    if (tex.isEmpty) return const SizedBox();

    final isDisplay = element.attributes['displayMode'] == 'true';

    if (isDisplay) {
      final math = renderMath(tex, style: parentStyle, displayMode: true);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SelectionContainer.disabled(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                primary: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                  ),
                  child: Center(child: math),
                ),
              ),
            );
          },
        ),
      );
    }

    // Inline math — flutter_markdown_plus places this in a Wrap.
    // Use the scrollable render object to preserve baseline alignment
    // in case the containing Wrap uses baseline cross-axis alignment.
    final math = renderMath(
      tex,
      style: inlineMathTextStyle(baseStyle ?? parentStyle),
      displayMode: false,
    );
    return SelectionContainer.disabled(
      child: InlineMathScrollable(child: math),
    );
  }
}
