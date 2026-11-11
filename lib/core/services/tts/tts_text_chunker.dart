class TtsTextChunk {
  const TtsTextChunk({
    required this.index,
    required this.text,
    required this.startOffset,
  });

  final int index;
  final String text;
  final int startOffset;

  int get endOffset => startOffset + text.length;
}

class TtsTextChunker {
  const TtsTextChunker._();

  static List<TtsTextChunk> split(String text, {int maxChunkLength = 220}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return const <TtsTextChunk>[];

    if (maxChunkLength < 2) {
      throw RangeError.range(maxChunkLength, 2, null, 'maxChunkLength');
    }
    final safeMax = maxChunkLength;
    final segments = _splitIntoSegments(normalized, safeMax);
    final chunks = <String>[];

    for (final segment in segments) {
      if (chunks.isEmpty) {
        chunks.add(segment);
        continue;
      }
      final merged = chunks.last + segment;
      if (merged.length <= safeMax) {
        chunks[chunks.length - 1] = merged;
      } else {
        chunks.add(segment);
      }
    }

    var offset = 0;
    final result = <TtsTextChunk>[];
    for (var i = 0; i < chunks.length; i++) {
      final value = chunks[i];
      result.add(TtsTextChunk(index: i, text: value, startOffset: offset));
      offset += value.length;
    }
    return result;
  }

  static List<String> _splitIntoSegments(String text, int maxChunkLength) {
    final segments = <String>[];
    final buffer = StringBuffer();

    void flush() {
      final value = buffer.toString();
      buffer.clear();
      if (value.isEmpty) return;
      segments.add(value);
    }

    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (buffer.length + char.length > maxChunkLength) flush();
      buffer.write(char);
      if (_isSentenceBoundary(char) || buffer.length >= maxChunkLength) flush();
    }
    flush();
    return segments;
  }

  static bool _isSentenceBoundary(String char) {
    return const {'。', '！', '？', '；', '!', '?', ';', '.', '\n'}.contains(char);
  }
}
