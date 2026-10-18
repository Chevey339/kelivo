import 'package:flutter/widgets.dart';

import '../../../core/ast/nodes.dart';
import '../../interfaces/renderers.dart';
import '../../selection/selectable_span_adapter.dart';
import '../../theme/markstream_theme.dart';

class MarkstreamMathBlock extends StatelessWidget {
  const MarkstreamMathBlock({
    super.key,
    required this.node,
    required this.theme,
    this.renderer,
  });
  final MathBlockNode node;
  final MarkstreamTheme theme;
  final MathRenderer? renderer;
  @override
  Widget build(BuildContext context) => Padding(
    padding: theme.mathPadding,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        primary: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
          ),
          child: Center(
            child: SelectableSpanAdapter(
              selectedText: node.tex,
              child: SelectionContainer.disabled(
                child:
                    renderer?.build(
                      context,
                      node.tex,
                      style: theme.body,
                      displayMode: true,
                    ) ??
                    Text(node.tex, style: theme.body),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
