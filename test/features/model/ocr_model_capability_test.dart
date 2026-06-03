import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/model/utils/ocr_model_capability.dart';

Future<void> _waitForSettingsLoad() async {
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

ProviderConfig _configWithOcrCandidates() {
  return ProviderConfig(
    id: 'OcrProvider',
    enabled: true,
    name: 'OCR Provider',
    apiKey: 'test-key',
    baseUrl: 'https://example.test',
    models: const [
      'vision-model',
      'text-model',
      'gpt-4.1',
      'gpt-4.1-text-only',
    ],
    modelOverrides: const {
      'vision-model': {
        'name': 'Vision Model',
        'input': ['text', 'image'],
      },
      'text-model': {
        'name': 'Text Model',
        'input': ['text'],
      },
      'gpt-4.1-text-only': {
        'apiModelId': 'gpt-4.1',
        'input': ['text'],
      },
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('modelSupportsOcrImageInput', () {
    test('accepts models tagged with image input', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setProviderConfig(
        'OcrProvider',
        _configWithOcrCandidates(),
      );

      expect(
        modelSupportsOcrImageInput(settings, 'OcrProvider', 'vision-model'),
        isTrue,
      );
    });

    test('rejects models tagged as text-only', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setProviderConfig(
        'OcrProvider',
        _configWithOcrCandidates(),
      );

      expect(
        modelSupportsOcrImageInput(settings, 'OcrProvider', 'text-model'),
        isFalse,
      );
    });

    test('accepts models whose current inferred tag has image input', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setProviderConfig(
        'OcrProvider',
        _configWithOcrCandidates(),
      );

      expect(
        modelSupportsOcrImageInput(settings, 'OcrProvider', 'gpt-4.1'),
        isTrue,
      );
    });

    test('honors text-only tag overrides over inferred vision tags', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setProviderConfig(
        'OcrProvider',
        _configWithOcrCandidates(),
      );

      expect(
        modelSupportsOcrImageInput(
          settings,
          'OcrProvider',
          'gpt-4.1-text-only',
        ),
        isFalse,
      );
    });
  });
}
