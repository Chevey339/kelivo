import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';

void main() {
  group('supportsGeminiNativeAudioInputModelId', () {
    test('returns true for supported Gemini chat models', () {
      expect(supportsGeminiNativeAudioInputModelId('gemini-2.5-flash'), isTrue);
      expect(
        supportsGeminiNativeAudioInputModelId('gemini-3-flash-preview'),
        isTrue,
      );
      expect(
        supportsGeminiNativeAudioInputModelId('gemini-3.1-pro-preview'),
        isTrue,
      );
    });

    test('returns false for excluded Gemini audio-adjacent models', () {
      expect(
        supportsGeminiNativeAudioInputModelId('gemini-3.1-flash-live-preview'),
        isFalse,
      );
      expect(
        supportsGeminiNativeAudioInputModelId('gemini-2.5-flash-preview-tts'),
        isFalse,
      );
      expect(
        supportsGeminiNativeAudioInputModelId('gemini-3-pro-image-preview'),
        isFalse,
      );
    });

    test('returns false for non-Gemini models and empty ids', () {
      expect(supportsGeminiNativeAudioInputModelId('gpt-4o-mini'), isFalse);
      expect(supportsGeminiNativeAudioInputModelId(''), isFalse);
    });
  });
}
