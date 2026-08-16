/// Allocates [StreamChunk] series ids scoped to one HTTP response.
///
/// Follow-up tool rounds construct a new decoder. Constant literals such as
/// `'text'` or `'text-0'` then collide, and a [StreamChunkHandler] merges
/// later text into the first [TextPart]. Pass a unique [sourceId] (response
/// id or `round-N`) per decoder instance.
class StreamChunkIds {
  StreamChunkIds([this.sourceId = 'stream']);

  final String sourceId;
  int _sequence = 0;
  String? _textId;
  String? _reasoningId;
  String? _searchId;

  String next(String kind) {
    final n = ++_sequence;
    if (sourceId.isEmpty) return '$kind-$n';
    return '$sourceId:$kind-$n';
  }

  String text() => _textId ??= next('text');

  String reasoning() => _reasoningId ??= next('reasoning');

  /// New id per citation burst so two searches in one answer stay distinct.
  String search() => next('search');

  /// Sticky search id for incremental grounding updates in one response.
  String searchSticky() => _searchId ??= search();

  /// Claude content_block index must stay stable for Start / Delta / End.
  String indexed(String kind, int index) {
    if (sourceId.isEmpty) return '$kind-$index';
    return '$sourceId:$kind-$index';
  }
}
