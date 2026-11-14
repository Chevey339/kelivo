import 'package:flutter/widgets.dart';
import 'package:markstream/markstream_core.dart';
import '../../../utils/source_text_map.dart';
import '../services/conversation_find_service.dart';

/// Only mounted rows subscribe. The selection scopes keep their own native
/// selection and quote highlights; these offsets are local to a rendered part.
class ConversationFindHighlights extends InheritedWidget {
  const ConversationFindHighlights({
    super.key,
    required this.hits,
    required this.current,
    required super.child,
  });
  final List<ConversationFindHit> hits;
  final ConversationFindHit? current;
  static ConversationFindHighlights? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ConversationFindHighlights>();
  List<SourceSpan> ranges(
    FindPart part,
    int block, {
    SourceTextMap? paragraph,
  }) {
    // The counter and navigation retain every occurrence. Bound rich-text span
    // allocation for e.g. a single frequent character in a very long message.
    const paintLimit = 512;
    final result = <SourceSpan>[];
    void add(ConversationFindHit hit) {
      if (paragraph == null) {
        result.add(hit.range);
      } else {
        result.addAll(paragraph.displayRanges(hit.range));
      }
    }

    for (final hit in hits) {
      if (hit.part != part || hit.block != block) continue;
      add(hit);
      if (result.length >= paintLimit) break;
    }
    final active = current;
    if (result.length >= paintLimit &&
        active != null &&
        active.part == part &&
        active.block == block) {
      add(active);
    }
    return result;
  }

  @override
  bool updateShouldNotify(ConversationFindHighlights old) =>
      old.hits != hits || old.current != current;
}
