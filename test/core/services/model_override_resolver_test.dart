import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/model_types.dart';
import 'package:Kelivo/core/services/model_override_resolver.dart';

void main() {
  group('ModelOverrideResolver.applyModelOverride', () {
    test('chat -> embedding clears abilities and forces text-only output', () {
      final base = ModelInfo(
        id: 'm',
        displayName: 'm',
        type: ModelType.chat,
        input: const [Modality.text],
        output: const [Modality.text, Modality.image],
        abilities: const [ModelAbility.tool, ModelAbility.reasoning],
      );

      final next = ModelOverrideResolver.applyModelOverride(base, {
        'type': 'embedding',
        'input': ['image'],
        'output': ['image'],
        'abilities': ['tool', 'reasoning'],
      });

      expect(next.type, ModelType.embedding);
      expect(next.abilities, isEmpty);
      expect(next.output, const [Modality.text]);
      // Embeddings still allow explicit input modalities (image should be preserved)
      expect(next.input, const [Modality.image]);
    });

    test('embedding -> chat applies output/abilities overrides', () {
      final base = ModelInfo(
        id: 'm',
        displayName: 'm',
        type: ModelType.embedding,
        input: const [Modality.text],
        output: const [Modality.text],
        abilities: const [],
      );

      final next = ModelOverrideResolver.applyModelOverride(base, {
        'type': 'chat',
        'input': ['text', 'image'],
        'output': ['text', 'image'],
        'abilities': ['tool'],
      });

      expect(next.type, ModelType.chat);
      expect(next.input, const [Modality.text, Modality.image]);
      expect(next.output, const [Modality.text, Modality.image]);
      expect(next.abilities, const [ModelAbility.tool]);
    });

    test('unknown override values clear list overrides', () {
      final base = ModelInfo(
        id: 'm',
        displayName: 'm',
        type: ModelType.chat,
        input: const [Modality.text],
        output: const [Modality.text],
        abilities: const [ModelAbility.reasoning],
      );

      final next = ModelOverrideResolver.applyModelOverride(base, {
        'type': 'chat',
        'input': ['bogus'],
        'output': ['bogus'],
        'abilities': ['bogus'],
      });

      // input/output cleared -> default back to [text]
      expect(next.input, const [Modality.text]);
      expect(next.output, const [Modality.text]);
      // abilities cleared because unknown values are ignored, leaving an empty parsed result
      expect(next.abilities, isEmpty);
    });

    test('unknown type value is ignored', () {
      final base = ModelInfo(
        id: 'm',
        displayName: 'm',
        type: ModelType.chat,
        input: const [Modality.text],
        output: const [Modality.text],
        abilities: const [],
      );

      final next = ModelOverrideResolver.applyModelOverride(base, {
        'type': 'bogus',
      });

      expect(next.type, base.type);
    });

    test('applyDisplayName controls name override behavior', () {
      final base = ModelInfo(
        id: 'm',
        displayName: 'base',
        type: ModelType.chat,
        input: const [Modality.text],
        output: const [Modality.text],
        abilities: const [],
      );

      final ov = {'name': 'override'};

      final withName = ModelOverrideResolver.applyModelOverride(base, ov, applyDisplayName: true);
      final withoutName = ModelOverrideResolver.applyModelOverride(base, ov, applyDisplayName: false);

      expect(withName.displayName, 'override');
      expect(withoutName.displayName, 'base');
    });

    test('non-model override keys are a no-op', () {
      final base = ModelInfo(
        id: 'm',
        displayName: 'base',
        type: ModelType.chat,
        input: const [Modality.text],
        output: const [Modality.text],
        abilities: const [ModelAbility.tool],
      );

      final next = ModelOverrideResolver.applyModelOverride(base, {
        'apiModelId': 'gpt-x',
        'headers': [
          {'name': 'x', 'value': '1'}
        ],
        'body': [
          {'key': 'k', 'value': 'v'}
        ],
      });

      expect(next.type, base.type);
      expect(next.input, base.input);
      expect(next.output, base.output);
      expect(next.abilities, base.abilities);
      expect(next.displayName, base.displayName);
    });
  });
}

