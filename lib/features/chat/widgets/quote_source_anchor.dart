import 'package:flutter/material.dart';
import 'conversation_find_highlights.dart';
import 'package:markstream/markstream.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/models/quote_ref.dart';
import '../../../utils/source_text_map.dart';
import 'quote_interaction_scope.dart';
import '../services/conversation_find_service.dart';

/// Registers geometry for one displayed slice of a message's original body.
class QuoteSourceAnchor extends StatefulWidget {
  const QuoteSourceAnchor({
    super.key,
    required this.message,
    required this.source,
    required this.markdown,
    required this.child,
    this.sourceMap,
    this.findPart = FindPart.body,
    this.findBlock = 0,
    this.findParagraph,
  });

  final ChatMessage message;
  final String source;
  final SourceTextMap? sourceMap;
  final bool markdown;
  final FindPart findPart;
  final int findBlock;
  final SourceTextMap? findParagraph;
  final Widget child;

  @override
  State<QuoteSourceAnchor> createState() => _QuoteSourceAnchorState();
}

class _QuoteSourceAnchorState extends State<QuoteSourceAnchor> {
  final _selection = MarkstreamSelectionController();
  QuoteInteractionController? _actions;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final actions = QuoteInteractionScope.maybeOf(context);
    if (actions == _actions) return;
    _actions?.unregisterSourceRect(this);
    _actions?.unregisterFindRect(this);
    _actions = actions;
    if (widget.findPart == FindPart.body) {
      actions?.registerSourceRect(this, _locate);
    }
    actions?.registerFindRect(this, _locateFind);
  }

  Rect? _locateFind(ConversationFindHit hit, {bool prepare = true}) {
    if (hit.messageId != widget.message.id ||
        hit.part != widget.findPart ||
        hit.block != widget.findBlock) {
      return null;
    }
    final ranges =
        widget.findParagraph?.displayRanges(hit.range) ?? [hit.range];
    for (final range in ranges) {
      if (range.end <= widget.source.length) {
        final rect = _rect(range, prepare: prepare);
        if (rect != null) return rect;
      }
    }
    return null;
  }

  Rect? _rect(SourceSpan range, {bool prepare = true}) {
    if (widget.markdown) {
      if (prepare && !_selection.prepareSourceRange(range)) return null;
      return _selection.rectForSourceRange(range);
    }
    final root = context.findRenderObject();
    return root == null
        ? null
        : textRangeRect(root, TextRange(start: range.start, end: range.end));
  }

  ({int start, Rect rect})? _locate(QuoteRef quote) {
    if (!mounted || quote.messageId != widget.message.id) return null;
    final map = widget.sourceMap;
    final base = map == null
        ? widget.message.content.indexOf(widget.source)
        : 0;
    if (base < 0) return null;
    final mapping =
        map ?? SourceTextMap.identity(widget.source.length, offset: base);
    final ranges = mapping.displayRanges(SourceSpan(quote.start, quote.end));
    for (final range in ranges) {
      final rect = _rect(range);
      if (rect != null) {
        return (
          start: mapping.sourceRange(range.start, range.end).start,
          rect: rect,
        );
      }
    }
    return null;
  }

  Rect? _localFindRect(ConversationFindHit hit) {
    final rect = _locateFind(hit, prepare: false);
    if (rect == null) return null;
    final root = context.findRenderObject()! as RenderBox;
    return Rect.fromPoints(
      root.globalToLocal(rect.topLeft),
      root.globalToLocal(rect.bottomRight),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = ConversationFindHighlights.of(context)?.current;
    final active =
        target?.part == widget.findPart && target?.block == widget.findBlock
        ? target
        : null;
    return MarkstreamSelectionScope(
      controller: _selection,
      child: CustomPaint(
        foregroundPainter: active == null
            ? null
            : _CurrentFindPainter(
                active,
                _localFindRect,
                Theme.of(context).colorScheme.primary,
              ),
        child: widget.child,
      ),
    );
  }

  @override
  void dispose() {
    _actions?.unregisterSourceRect(this);
    _actions?.unregisterFindRect(this);
    _selection.dispose();
    super.dispose();
  }
}

/// Paint the active fragment after its native text geometry is available.
/// Painting leaves selection, semantics and the underlying quote decoration intact.
class _CurrentFindPainter extends CustomPainter {
  const _CurrentFindPainter(this.hit, this.locate, this.color);
  final ConversationFindHit hit;
  final Rect? Function(ConversationFindHit) locate;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = locate(hit);
    if (rect == null) return;
    final outline = RRect.fromRectAndRadius(
      rect.inflate(.75),
      const Radius.circular(3),
    );
    canvas.drawRRect(outline, Paint()..color = color.withValues(alpha: .15));
    canvas.drawRRect(
      outline,
      Paint()
        ..color = color.withValues(alpha: .85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_CurrentFindPainter old) =>
      old.hit != hit || old.locate != locate || old.color != color;
  @override
  bool? hitTest(Offset position) => false;
}
