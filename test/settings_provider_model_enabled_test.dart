import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/reasoning_request.dart';

import 'support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'model choices persist per account without removing catalog metadata',
    () async {
      final config = ProviderConfig(
        id: 'chatgpt',
        enabled: true,
        name: 'ChatGPT',
        apiKey: '',
        baseUrl: OAuthProvider.chatgpt.baseUrl,
        oauthProvider: OAuthProvider.chatgpt,
        models: ['keep', 'hide'],
        modelOverrides: const {
          'hide': {'temperature': .7},
        },
      );
      final harness = await createBusinessTestHarness(
        initial: {
          'provider_configs_v1': jsonEncode({
            config.id: config.toJson(),
            'other': config.copyWith(id: 'other', enabled: false).toJson(),
          }),
        },
      );
      final settings = SettingsProvider(harness.preferences);
      addTearDown(settings.dispose);
      await settings.loaded;
      await settings.setCurrentModel(config.id, 'hide');
      await settings.setTitleModel(config.id, 'keep');
      const reasoning = ReasoningRequest(ReasoningLevel.max);
      await settings.setReasoningChoice(config.id, 'hide', reasoning);
      await settings.togglePinModel(config.id, 'hide');
      await settings.setModelEnabled(config.id, 'hide', false);

      final saved = settings.getProviderConfig(config.id);
      expect(saved.models, ['keep', 'hide']);
      expect(saved.enabledModels, ['keep']);
      expect(saved.modelOverrides['hide'], {'temperature': .7});
      expect(settings.currentModelId, isNull);
      expect(settings.titleModelId, 'keep');
      expect(settings.reasoningChoiceFor(config.id, 'hide'), reasoning);
      expect(settings.pinnedModels, contains('${config.id}::hide'));
      expect(settings.getProviderConfig('other').enabledModels, [
        'keep',
        'hide',
      ]);
      expect(settings.hasAnyActiveModel, isTrue);

      await settings.setModelEnabled(config.id, 'keep', false);
      expect(settings.hasAnyActiveModel, isFalse);
      final reloaded = SettingsProvider(harness.preferences);
      addTearDown(reloaded.dispose);
      await reloaded.loaded;
      expect(reloaded.getProviderConfig(config.id).enabledModels, isEmpty);
      expect(reloaded.hasAnyActiveModel, isFalse);
      expect(reloaded.reasoningChoiceFor(config.id, 'hide'), reasoning);
      expect(reloaded.pinnedModels, contains('${config.id}::hide'));

      await reloaded.setModelEnabled(config.id, 'hide', true);
      expect(reloaded.getProviderConfig(config.id).enabledModels, ['hide']);
      expect(reloaded.getProviderConfig(config.id).modelOverrides['hide'], {
        'temperature': .7,
      });
      expect(reloaded.hasAnyActiveModel, isTrue);
      expect(reloaded.reasoningChoiceFor(config.id, 'hide'), reasoning);
      await reloaded.setModelEnabled(config.id, 'unknown', false);
      expect(reloaded.getProviderConfig(config.id).disabledModels, {'keep'});
      await reloaded.deleteModels(config.id, {'hide'});
      expect(reloaded.reasoningChoiceFor(config.id, 'hide'), isNull);
      expect(reloaded.pinnedModels, isNot(contains('${config.id}::hide')));
    },
  );
}
