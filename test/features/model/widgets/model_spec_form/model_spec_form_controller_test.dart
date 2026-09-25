import '../../../../support/business_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/builtin_tools.dart';
import 'package:Kelivo/core/services/model_spec/model_spec_resolver.dart';
import 'package:Kelivo/features/model/widgets/model_spec_form/model_spec_form_controller.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

ProviderConfig _cfg({
  String id = 'Test',
  ProviderKind kind = ProviderKind.openai,
  List<String> models = const ['plain-model'],
  Map<String, dynamic> overrides = const {},
}) {
  return ProviderConfig(
    id: id,
    enabled: true,
    name: 'Test',
    apiKey: 'test-key',
    baseUrl: 'https://example.test/v1',
    providerType: kind,
    models: models,
    modelOverrides: overrides,
  );
}

Future<SettingsProvider> _settings(ProviderConfig cfg) async {
  final harness = await createBusinessTestHarness(initial: {});
  final settings = SettingsProvider(harness.preferences);
  await settings.loaded;
  await settings.setProviderConfig(cfg.id, cfg);
  return settings;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('initial values match resolve spec', () {
    final cfg = _cfg(
      overrides: const {
        'plain-model': {
          'name': 'Plain',
          'type': 'chat',
          'abilities': ['reasoning'],
        },
      },
    );
    final controller = ModelSpecFormController(
      config: cfg,
      modelKey: 'plain-model',
      isNew: false,
    );
    addTearDown(controller.dispose);
    final resolved = ModelSpecResolver.instance.resolve(cfg, 'plain-model');
    expect(controller.spec, resolved.spec);
    expect(controller.base, resolved.base);
  });

  test('setter marks the field overridden and spec reflects it', () {
    final cfg = _cfg();
    final controller = ModelSpecFormController(
      config: cfg,
      modelKey: 'plain-model',
      isNew: false,
    );
    addTearDown(controller.dispose);
    expect(controller.isOverridden(ModelSpecField.type), isFalse);
    controller.setType(ModelType.image);
    expect(controller.isOverridden(ModelSpecField.type), isTrue);
    expect(controller.spec.type, ModelType.image);
    expect(controller.sourceOf(ModelSpecField.type), SpecSource.override);
  });

  test('reset restores the base value and drops the field from toJson', () {
    final cfg = _cfg();
    final controller = ModelSpecFormController(
      config: cfg,
      modelKey: 'plain-model',
      isNew: false,
    );
    addTearDown(controller.dispose);
    final baseType = controller.base.type;
    controller.setType(ModelType.embedding);
    controller.reset(ModelSpecField.type);
    expect(controller.spec.type, baseType);
    expect(controller.isOverridden(ModelSpecField.type), isFalse);
    expect(controller.draft.toJson().containsKey('type'), isFalse);
  });

  test(
    'save preserves extra keys, oauth reasoning, and other models',
    () async {
      final cfg = _cfg(
        models: const ['plain-model', 'other'],
        overrides: const {
          'plain-model': {
            'name': 'Plain',
            'webSearch': {'enabled': true, 'max': 3},
            'oauthProtocol': 'claude',
            'reasoning': {'dialect': 'anthropicBudget', 'canDisable': true},
          },
          'other': {'name': 'Other'},
        },
      );
      final settings = await _settings(cfg);
      final controller = ModelSpecFormController(
        config: settings.getProviderConfig(cfg.id),
        modelKey: 'plain-model',
        isNew: false,
      );
      addTearDown(controller.dispose);
      controller.setInput(const [Modality.text, Modality.image]);
      expect(await controller.save(settings), isTrue);
      final saved = settings.getProviderConfig(cfg.id);
      final ov = saved.modelOverrides['plain-model'] as Map;
      expect(ov['webSearch'], {'enabled': true, 'max': 3});
      expect(ov['oauthProtocol'], 'claude');
      expect((ov['reasoning'] as Map)['dialect'], 'anthropicBudget');
      expect((ov['reasoning'] as Map)['canDisable'], isTrue);
      expect((saved.modelOverrides['other'] as Map)['name'], 'Other');
    },
  );

  test('new-model key generation with a clash yields id#2', () async {
    final cfg = _cfg(
      models: const ['foo'],
      overrides: const {
        'foo': {'name': 'Foo'},
      },
    );
    final settings = await _settings(cfg);
    final controller = ModelSpecFormController(
      config: settings.getProviderConfig(cfg.id),
      modelKey: '',
      isNew: true,
    );
    addTearDown(controller.dispose);
    controller.setApiModelId('foo');
    controller.setDisplayName('Foo 2');
    expect(await controller.save(settings), isTrue);
    final saved = settings.getProviderConfig(cfg.id);
    expect(saved.models, contains('foo#2'));
    expect(saved.modelOverrides.containsKey('foo#2'), isTrue);
    expect((saved.modelOverrides['foo#2'] as Map)['apiModelId'], 'foo');
  });

  test('validation blocks empty id and invalid custom JSON', () async {
    final cfg = _cfg(models: const []);
    final settings = await _settings(cfg);
    final controller = ModelSpecFormController(
      config: settings.getProviderConfig(cfg.id),
      modelKey: '',
      isNew: true,
    );
    addTearDown(controller.dispose);
    expect(controller.validate(l10n), l10n.modelDetailSheetInvalidIdError);
    expect(await controller.save(settings), isFalse);

    controller.setApiModelId('ab');
    controller.setDialect(ReasoningDialect.custom);
    controller.setLevels(const [ReasoningLevel.high]);
    controller.setCustomPatchText(ReasoningLevel.high, '{not-json');
    expect(controller.validate(l10n), l10n.modelSpecFormInvalidJson);
    expect(await controller.save(settings), isFalse);
  });

  test('builtInTools round-trip through the helper', () async {
    final cfg = _cfg(
      id: 'Gemini',
      kind: ProviderKind.google,
      overrides: const {
        'plain-model': {
          'name': 'Plain',
          'type': 'chat',
          'tools': {'search': true},
        },
      },
    );
    final settings = await _settings(cfg);
    final controller = ModelSpecFormController(
      config: settings.getProviderConfig(cfg.id),
      modelKey: 'plain-model',
      isNew: false,
    );
    addTearDown(controller.dispose);
    controller.setBuiltInTools(const [BuiltInToolNames.urlContext]);
    expect(await controller.save(settings), isTrue);
    final ov =
        settings.getProviderConfig(cfg.id).modelOverrides['plain-model'] as Map;
    expect(ov['builtInTools'], contains(BuiltInToolNames.urlContext));
    expect(
      BuiltInToolNames.parseFromOverride(ov),
      contains(BuiltInToolNames.urlContext),
    );
  });

  test('request quirks override, persist and reset', () async {
    final cfg = _cfg(models: const ['kimi-k3']);
    final settings = await _settings(cfg);
    final controller = ModelSpecFormController(
      config: cfg,
      modelKey: 'kimi-k3',
      isNew: false,
    );
    addTearDown(controller.dispose);
    expect(controller.spec.remoteImageUrls, isFalse);
    expect(
      controller.sourceOf(ModelSpecField.remoteImageUrls),
      SpecSource.guess,
    );

    controller.setRemoteImageUrls(true);
    expect(controller.spec.remoteImageUrls, isTrue);
    expect(controller.isOverridden(ModelSpecField.remoteImageUrls), isTrue);
    expect(await controller.save(settings), isTrue);
    final saved = settings.getProviderConfig(cfg.id);
    expect((saved.modelOverrides['kimi-k3'] as Map)['remoteImageUrls'], isTrue);
    expect(
      ModelSpecResolver.instance.spec(saved, 'kimi-k3').remoteImageUrls,
      isTrue,
    );

    controller.reset(ModelSpecField.remoteImageUrls);
    expect(controller.spec.remoteImageUrls, isFalse);
  });
}
