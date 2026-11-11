import 'package:Kelivo/core/services/tts/tts_text_chunker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TtsTextChunker', () {
    test('splits long text on sentence boundaries', () {
      final chunks = TtsTextChunker.split(
        '第一句很短。第二句也不长！Third sentence is readable. '
        'Fourth sentence should start a new chunk.',
        maxChunkLength: 32,
      );

      expect(chunks, hasLength(greaterThan(1)));
      expect(chunks.every((chunk) => chunk.text.length <= 32), isTrue);
      expect(chunks.first.text, '第一句很短。第二句也不长！');
      expect(chunks.first.startOffset, 0);
      expect(chunks[1].startOffset, chunks.first.text.length);
    });

    test('hard-splits unpunctuated text without dropping characters', () {
      final source = List.filled(95, 'a').join();
      final chunks = TtsTextChunker.split(source, maxChunkLength: 30);

      expect(chunks.map((chunk) => chunk.text).join(), source);
      expect(chunks.map((chunk) => chunk.text.length), [30, 30, 30, 5]);
      expect(chunks.last.startOffset, 90);
    });

    test('punctuation and Unicode remain exact across normalized chunks', () {
      const text = '-3.14 https://example.invalid 1,000.5 😀🧪 end.';
      for (final limit in [4, 12, 220]) {
        final chunks = TtsTextChunker.split(text, maxChunkLength: limit);
        expect(chunks.map((c) => c.text).join(), text);
        expect(chunks.every((c) => c.text.length <= limit), isTrue);
        for (final chunk in chunks) {
          expect(String.fromCharCodes(chunk.text.runes), chunk.text);
          expect(
            chunk.text.codeUnits.first,
            isNot(inInclusiveRange(0xdc00, 0xdfff)),
          );
          expect(
            chunk.text.codeUnits.last,
            isNot(inInclusiveRange(0xd800, 0xdbff)),
          );
        }
        expect(chunks.last.endOffset, text.length);
      }
    });

    test('returns no chunks for blank input', () {
      expect(TtsTextChunker.split('   \n\n  '), isEmpty);
    });
  });
}
