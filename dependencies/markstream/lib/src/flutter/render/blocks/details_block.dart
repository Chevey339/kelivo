import 'package:flutter/material.dart';

import '../../../core/ast/nodes.dart';
import '../../theme/markstream_theme.dart';

class MarkstreamDetailsBlock extends StatefulWidget {
  const MarkstreamDetailsBlock({
    super.key,
    required this.node,
    required this.source,
    required this.open,
    required this.theme,
    required this.summary,
    required this.body,
  });
  final MarkdownNode node;
  final bool open;
  final String source;
  final MarkstreamTheme theme;
  final Widget summary;
  final WidgetBuilder body;
  @override
  State<MarkstreamDetailsBlock> createState() => _MarkstreamDetailsBlockState();
}

class _MarkstreamDetailsBlockState extends State<MarkstreamDetailsBlock> {
  bool? _manual;
  @override
  void didUpdateWidget(MarkstreamDetailsBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node.span.start != oldWidget.node.span.start ||
        !widget.source.startsWith(oldWidget.source)) {
      _manual = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final expanded = _manual ?? widget.open;
    final theme = widget.theme.details;
    return Container(
      key: const ValueKey('markstream-details-surface'),
      margin: theme.margin,
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(theme.radius),
        border: Border.all(
          color: theme.borderColor,
          width: MarkstreamTheme.stroke,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        alignment: Alignment.topCenter,
        duration: theme.chevronDuration,
        curve: Curves.easeOutCubic,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              expanded: expanded,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _manual = !expanded),
                child: Padding(
                  padding: theme.summaryPadding,
                  child: Row(
                    children: [
                      SelectionContainer.disabled(
                        child: AnimatedRotation(
                          turns: expanded ? .25 : 0,
                          duration: theme.chevronDuration,
                          child: SizedBox.square(
                            dimension: theme.chevronSize,
                            child: CustomPaint(
                              painter: _Chevron(
                                widget.theme.chrome.actionColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: widget.summary),
                    ],
                  ),
                ),
              ),
            ),
            if (expanded)
              Padding(
                key: const ValueKey('markstream-details-body'),
                padding: theme.contentPadding,
                child: widget.body(context),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chevron extends CustomPainter {
  const _Chevron(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    Path()
      ..moveTo(size.width * .35, size.height * .2)
      ..lineTo(size.width * .65, size.height * .5)
      ..lineTo(size.width * .35, size.height * .8),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round,
  );
  @override
  bool shouldRepaint(_Chevron oldDelegate) => oldDelegate.color != color;
}
