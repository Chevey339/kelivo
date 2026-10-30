import 'package:flutter/widgets.dart';

import '../../../core/ast/nodes.dart';
import '../../../core/text_index/text_index.dart';
import '../../../core/serialize/to_plain_text.dart';
import '../../interfaces/renderers.dart';
import '../../selection/selectable_span_adapter.dart';
import '../../selection/selection_controller.dart';
import '../../theme/markstream_theme.dart';
import '../source_highlights.dart';

class MarkstreamMathBlock extends StatelessWidget {
  const MarkstreamMathBlock({
    super.key,
    required this.node,
    required this.tex,
    required this.theme,
    this.renderer,
  });
  final BlockNode node;
  final String tex;
  final MarkstreamTheme theme;
  final MathRenderer? renderer;
  @override
  Widget build(BuildContext context) => MarkstreamSelectionFragment(
    node: node,
    segments: [
      TextSegment(text: toPlainText(node), sourceSpan: node.span, node: node),
    ],
    child: SourceHighlightScope.of(context).atom(
      node.span,
      SelectableSpanAdapter(
        selectedText: toPlainText(node),
        child: SelectionContainer.disabled(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              primary: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.hasBoundedWidth
                      ? constraints.maxWidth
                      : 0,
                ),
                child: Padding(
                  // Glyphs can paint slightly beyond their TeX layout bounds.
                  // Keep their vertical breathing room inside the scroll clip.
                  padding: theme.mathPadding,
                  child: Center(
                    child:
                        renderer?.build(
                          context,
                          tex,
                          style: theme.body,
                          displayMode: true,
                        ) ??
                        Text(tex, style: theme.body),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
