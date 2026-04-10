import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/providers/model_provider.dart';
import 'package:Kelivo/core/services/model_override_resolver.dart';

void main() {
  group('ModelRegistry.infer audio input support', () {
    test('marks supported Gemini and OpenAI audio-capable models', () {
      expect(
        ModelRegistry.infer(
          ModelInfo(id: 'gemini-2.5-flash', displayName: 'gemini-2.5-flash'),
        ).input,
        contains(Modality.audio),
      );
      expect(
        ModelRegistry.infer(
          ModelInfo(
            id: 'longcat-flash-omni',
            displayName: 'longcat-flash-omni',
          ),
        ).input,
        contains(Modality.audio),
      );
      expect(
        ModelRegistry.infer(
          ModelInfo(id: 'whisper-1', displayName: 'whisper-1'),
        ).input,
        contains(Modality.audio),
      );
      expect(
        ModelRegistry.infer(
          ModelInfo(
            id: 'gpt-4o-mini-transcribe',
            displayName: 'gpt-4o-mini-transcribe',
          ),
        ).input,
        contains(Modality.audio),
      );
    });

    test('does not mark regular text models as audio-capable', () {
      expect(
        ModelRegistry.infer(
          ModelInfo(id: 'gpt-4o-mini', displayName: 'gpt-4o-mini'),
        ).input,
        isNot(contains(Modality.audio)),
      );
      expect(
        ModelRegistry.infer(ModelInfo(id: '', displayName: '')).input,
        isNot(contains(Modality.audio)),
      );
    });
  });

  group('ModelOverrideResolver audio modality support', () {
    test('parses audio modality from overrides', () {
      expect(ModelOverrideResolver.parseModalities(['text', 'audio']), const [
        Modality.text,
        Modality.audio,
      ]);
    });

    test('preserves audio modality when applying overrides', () {
      final model = ModelOverrideResolver.applyModelOverride(
        ModelInfo(id: 'whisper-1', displayName: 'whisper-1'),
        {
          'input': ['text', 'audio'],
        },
      );

      expect(model.input, const [Modality.text, Modality.audio]);
    });
  });
}
