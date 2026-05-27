import 'package:Kelivo/core/services/tts/tts_playback_models.dart';
import 'package:Kelivo/core/services/tts/tts_text_chunker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TtsPlaybackTimeline', () {
    test('maps chunk progress into total position', () {
      final chunks = [
        const TtsTextChunk(index: 0, text: 'abcde', startOffset: 0),
        const TtsTextChunk(index: 1, text: 'fghij', startOffset: 5),
      ];
      final timeline = TtsPlaybackTimeline(chunks);

      final position = timeline.positionForChunkProgress(
        chunkIndex: 1,
        chunkPosition: const Duration(milliseconds: 500),
        chunkDuration: const Duration(seconds: 1),
      );

      expect(position, const Duration(milliseconds: 1500));
      expect(timeline.estimatedDuration, const Duration(seconds: 2));
    });

    test('clamps 15 second seek across chunk boundaries', () {
      final chunks = [
        TtsTextChunk(
          index: 0,
          text: List.filled(20, 'a').join(),
          startOffset: 0,
        ),
        TtsTextChunk(
          index: 1,
          text: List.filled(20, 'b').join(),
          startOffset: 20,
        ),
        TtsTextChunk(
          index: 2,
          text: List.filled(20, 'c').join(),
          startOffset: 40,
        ),
      ];
      final timeline = TtsPlaybackTimeline(
        chunks,
        millisecondsPerCharacter: 1000,
      );

      final forward = timeline.seekTarget(
        currentPosition: const Duration(seconds: 10),
        delta: const Duration(seconds: 15),
      );
      final backward = timeline.seekTarget(
        currentPosition: const Duration(seconds: 10),
        delta: const Duration(seconds: -15),
      );

      expect(forward.chunkIndex, 1);
      expect(forward.offsetInChunk, const Duration(seconds: 5));
      expect(backward.chunkIndex, 0);
      expect(backward.offsetInChunk, Duration.zero);
    });
  });

  group('TtsPlaybackSpeed', () {
    test('cycles through supported playback speeds', () {
      expect(TtsPlaybackSpeed.next(1.0), 1.2);
      expect(TtsPlaybackSpeed.next(1.2), 1.5);
      expect(TtsPlaybackSpeed.next(1.5), 2.0);
      expect(TtsPlaybackSpeed.next(2.0), 0.8);
      expect(TtsPlaybackSpeed.next(0.8), 1.0);
    });
  });

  group('TtsPlaybackState', () {
    test('keeps completed playback visible without marking it active', () {
      const state = TtsPlaybackState(status: TtsPlaybackStatus.ended);

      expect(state.isActive, isFalse);
      expect(state.isPlayerVisible, isTrue);
    });
  });
}
