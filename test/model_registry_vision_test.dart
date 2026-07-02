import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/core/providers/model_provider.dart';

void main() {
  group('ModelRegistry.infer — Qwen 3.x vision detection', () {
    test('qwen3.5-plus has vision', () {
      final info = ModelRegistry.infer(
        ModelInfo(id: 'qwen3.5-plus', displayName: 'qwen3.5-plus'),
      );
      expect(info.input, contains(Modality.image));
    });

    test('qwen3.6-plus has vision', () {
      final info = ModelRegistry.infer(
        ModelInfo(id: 'qwen3.6-plus', displayName: 'qwen3.6-plus'),
      );
      expect(info.input, contains(Modality.image));
    });

    test('qwen3.6-flash has vision', () {
      final info = ModelRegistry.infer(
        ModelInfo(id: 'qwen3.6-flash', displayName: 'qwen3.6-flash'),
      );
      expect(info.input, contains(Modality.image));
    });

    test('qwen3.6-35b-a3b has vision', () {
      final info = ModelRegistry.infer(
        ModelInfo(id: 'qwen3.6-35b-a3b', displayName: 'qwen3.6-35b-a3b'),
      );
      expect(info.input, contains(Modality.image));
    });

    test('qwen3.7-max does NOT have vision', () {
      final info = ModelRegistry.infer(
        ModelInfo(id: 'qwen3.7-max', displayName: 'qwen3.7-max'),
      );
      expect(info.input, isNot(contains(Modality.image)));
    });

    test('qwen3-plus does NOT have vision', () {
      final info = ModelRegistry.infer(
        ModelInfo(id: 'qwen3-plus', displayName: 'qwen3-plus'),
      );
      expect(info.input, isNot(contains(Modality.image)));
    });
  });

  group('ModelRegistry.infer — Doubao seed-2 vision/tool/reasoning', () {
    test('doubao-seed-2.0-pro has vision, tool, and reasoning', () {
      final info = ModelRegistry.infer(
        ModelInfo(
          id: 'doubao-seed-2.0-pro',
          displayName: 'doubao-seed-2.0-pro',
        ),
      );
      expect(info.input, contains(Modality.image));
      expect(info.abilities, contains(ModelAbility.tool));
      expect(info.abilities, contains(ModelAbility.reasoning));
    });

    test('doubao-seed-2.1-turbo has vision, tool, and reasoning', () {
      final info = ModelRegistry.infer(
        ModelInfo(
          id: 'doubao-seed-2.1-turbo',
          displayName: 'doubao-seed-2.1-turbo',
        ),
      );
      expect(info.input, contains(Modality.image));
      expect(info.abilities, contains(ModelAbility.tool));
      expect(info.abilities, contains(ModelAbility.reasoning));
    });
  });

  group('ModelRegistry.infer — existing 1.x doubao still works', () {
    test('doubao-pro-1.6 keeps vision, tool, and reasoning', () {
      final info = ModelRegistry.infer(
        ModelInfo(id: 'doubao-pro-1.6', displayName: 'doubao-pro-1.6'),
      );
      expect(info.input, contains(Modality.image));
      expect(info.abilities, contains(ModelAbility.tool));
      expect(info.abilities, contains(ModelAbility.reasoning));
    });

    test('doubao-seed-1.8 keeps vision, tool, and reasoning', () {
      final info = ModelRegistry.infer(
        ModelInfo(id: 'doubao-seed-1.8', displayName: 'doubao-seed-1.8'),
      );
      expect(info.input, contains(Modality.image));
      expect(info.abilities, contains(ModelAbility.tool));
      expect(info.abilities, contains(ModelAbility.reasoning));
    });
  });
}
