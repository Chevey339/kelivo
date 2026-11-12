import 'package:flutter/widgets.dart';
import 'package:markstream/markstream.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/models/quote_ref.dart';
import '../../../utils/source_text_map.dart';
import 'quote_interaction_scope.dart';

/// Registers geometry for one displayed slice of a message's original body.
class QuoteSourceAnchor extends StatefulWidget {
  const QuoteSourceAnchor({
    super.key,
    required this.message,
    required this.source,
    required this.markdown,
    required this.child,
    this.sourceMap,
  });

  final ChatMessage message;
  final String source;
  final SourceTextMap? sourceMap;
  final bool markdown;
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
    _actions = actions;
    actions?.registerSourceRect(this, _locate);
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
      if (widget.markdown && !_selection.prepareSourceRange(range)) return null;
      final root = context.findRenderObject();
      final rect = widget.markdown
          ? _selection.rectForSourceRange(range)
          : root == null
          ? null
          : textRangeRect(root, TextRange(start: range.start, end: range.end));
      if (rect != null) {
        return (
          start: mapping.sourceRange(range.start, range.end).start,
          rect: rect,
        );
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) =>
      MarkstreamSelectionScope(controller: _selection, child: widget.child);

  @override
  void dispose() {
    _actions?.unregisterSourceRect(this);
    _selection.dispose();
    super.dispose();
  }
}
