import "support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

ProviderConfig _configWithModels() {
  return ProviderConfig(
    id: 'TestProvider',
    enabled: true,
    name: 'Test Provider',
    apiKey: 'test-key',
    baseUrl: 'https://example.test',
    models: const ['keep', 'remove-a', 'remove-b'],
    modelOverrides: const {
      'keep': {'name': 'Keep'},
      'remove-a': {'name': 'Remove A'},
      'remove-b': {'name': 'Remove B'},
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider model deletion', () {
    test('deleteModels removes selected models and their overrides', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setProviderConfig('TestProvider', _configWithModels());

      final deleted = await settings.deleteModels('TestProvider', const {
        'remove-a',
        'remove-b',
      });

      final cfg = settings.getProviderConfig('TestProvider');
      expect(deleted, 2);
      expect(cfg.models, const ['keep']);
      expect(cfg.modelOverrides.keys, const ['keep']);
    });

    test('deleteModels does nothing for empty selection', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setProviderConfig('TestProvider', _configWithModels());

      final deleted = await settings.deleteModels(
        'TestProvider',
        const <String>{},
      );

      final cfg = settings.getProviderConfig('TestProvider');
      expect(deleted, 0);
      expect(cfg.models, const ['keep', 'remove-a', 'remove-b']);
      expect(cfg.modelOverrides.keys, const ['keep', 'remove-a', 'remove-b']);
    });

    test('deleteModels clears selections for deleted models only', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setProviderConfig('TestProvider', _configWithModels());
      await settings.setCurrentModel('TestProvider', 'remove-a');
      await settings.setTitleModel('TestProvider', 'keep');

      final deleted = await settings.deleteModels('TestProvider', const {
        'remove-a',
      });

      expect(deleted, 1);
      expect(settings.currentModelProvider, isNull);
      expect(settings.currentModelId, isNull);
      expect(settings.titleModelProvider, 'TestProvider');
      expect(settings.titleModelId, 'keep');
    });

    test(
      'deleteModels clears orphan overrides when every model is removed',
      () async {
        final harness = await createBusinessTestHarness(initial: {});
        final settings = SettingsProvider(harness.preferences);

        await settings.loaded;
        await settings.setProviderConfig(
          'TestProvider',
          _configWithModels().copyWith(
            modelOverrides: const {
              'keep': {'name': 'Keep'},
              'remove-a': {'name': 'Remove A'},
              'remove-b': {'name': 'Remove B'},
              'orphan': {'name': 'Orphan'},
            },
          ),
        );

        final deleted = await settings.deleteModels('TestProvider', const {
          'keep',
          'remove-a',
          'remove-b',
        });

        final cfg = settings.getProviderConfig('TestProvider');
        expect(deleted, 3);
        expect(cfg.models, isEmpty);
        expect(cfg.modelOverrides, isEmpty);
      },
    );
  });
}
