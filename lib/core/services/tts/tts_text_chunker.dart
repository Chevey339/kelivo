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

    final safeMax = maxChunkLength < 40 ? maxChunkLength : maxChunkLength;
    final segments = _splitIntoSegments(normalized, safeMax);
    final chunks = <String>[];

    for (final segment in segments) {
      if (chunks.isEmpty) {
        chunks.add(segment);
        continue;
      }
      final merged = _joinForSpeech(chunks.last, segment);
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
      final value = buffer.toString().trim();
      buffer.clear();
      if (value.isEmpty) return;
      if (value.length <= maxChunkLength) {
        segments.add(value);
        return;
      }
      for (var start = 0; start < value.length; start += maxChunkLength) {
        final end = (start + maxChunkLength).clamp(0, value.length).toInt();
        segments.add(value.substring(start, end));
      }
    }

    for (final codeUnit in text.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      buffer.write(char);
      if (_isSentenceBoundary(char)) {
        flush();
      } else if (buffer.length >= maxChunkLength) {
        flush();
      }
    }
    flush();
    return segments;
  }

  static bool _isSentenceBoundary(String char) {
    return const {'。', '！', '？', '；', '!', '?', ';', '.', '\n'}.contains(char);
  }

  static String _joinForSpeech(String first, String second) {
    if (first.isEmpty) return second;
    if (second.isEmpty) return first;
    final needsSpace =
        _isAsciiBoundary(first.codeUnitAt(first.length - 1)) &&
        _isAsciiWord(second.codeUnitAt(0));
    return needsSpace ? '$first $second' : '$first$second';
  }

  static bool _isAsciiBoundary(int codeUnit) {
    return codeUnit == 0x2e ||
        codeUnit == 0x21 ||
        codeUnit == 0x3f ||
        codeUnit == 0x3b ||
        codeUnit == 0x3a ||
        codeUnit == 0x2c;
  }

  static bool _isAsciiWord(int codeUnit) {
    return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
        (codeUnit >= 0x41 && codeUnit <= 0x5a) ||
        (codeUnit >= 0x61 && codeUnit <= 0x7a);
  }
}
