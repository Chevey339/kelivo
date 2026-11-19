import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/model/widgets/model_spec_form/model_spec_form_controller.dart';
import 'package:Kelivo/features/model/widgets/model_spec_form/request_quirks_section.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';

ProviderConfig _cfg({
  required String id,
  required ProviderKind kind,
  required String baseUrl,
  List<String> models = const [],
}) {
  return ProviderConfig(
    id: id,
    enabled: true,
    name: id,
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: kind,
    models: models,
  );
}

Future<void> _pump(WidgetTester tester, ModelSpecFormController c) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: RequestQuirksSection(controller: c)),
    ),
  );
}

void main() {
  testWidgets('response speed tiers can be selected separately and reset', (
    tester,
  ) async {
    final controller = ModelSpecFormController(
      config: _cfg(
        id: 'Relay',
        kind: ProviderKind.openai,
        baseUrl: 'https://relay.example/v1',
      ),
      modelKey: 'mychat-gpt62',
      isNew: false,
    );
    addTearDown(controller.dispose);
    await _pump(tester, controller);
    final custom = find.byKey(
      const ValueKey('model-spec-response-speed-tiers'),
    );
    final fast = find.byKey(const ValueKey('model-spec-response-speed-fast'));
    final ultra = find.byKey(
      const ValueKey('model-spec-response-speed-ultrafast'),
    );
    expect(tester.widget<IosSwitch>(custom).value, isFalse);
    expect(fast, findsNothing);
    await tester.tap(custom);
    await tester.pumpAndSettle();
    expect(controller.draft.responseSpeedTiers, isEmpty);
    await tester.tap(fast);
    await tester.pumpAndSettle();
    expect(controller.draft.responseSpeedTiers, [ResponseSpeed.fast]);
    await tester.tap(ultra);
    await tester.pumpAndSettle();
    await tester.tap(fast);
    await tester.pumpAndSettle();
    expect(controller.draft.responseSpeedTiers, [ResponseSpeed.ultrafast]);
    expect(find.text('UltraFast requires the Responses API.'), findsOneWidget);
    await tester.tap(find.byType(IosIconButton));
    await tester.pumpAndSettle();
    expect(controller.draft.responseSpeedTiers, isNull);
    expect(tester.widget<IosSwitch>(custom).value, isFalse);
  });

  testWidgets('non-reasoning image model still gets the remote image switch', (
    tester,
  ) async {
    final c = ModelSpecFormController(
      config: _cfg(
        id: 'OpenAI',
        kind: ProviderKind.openai,
        baseUrl: 'https://api.openai.com/v1',
        models: const ['gpt-4o'],
      ),
      modelKey: 'gpt-4o',
      isNew: false,
    );
    addTearDown(c.dispose);
    expect(c.spec.supportsReasoning, isFalse);
    await _pump(tester, c);
    expect(
      find.byKey(const ValueKey('model-spec-remoteImageUrls')),
      findsOneWidget,
    );
  });

  testWidgets('new Claude model shows the dynamic search switch from draft', (
    tester,
  ) async {
    final c = ModelSpecFormController(
      config: _cfg(
        id: 'Claude',
        kind: ProviderKind.claude,
        baseUrl: 'https://api.anthropic.com/v1',
      ),
      modelKey: '',
      isNew: true,
    );
    addTearDown(c.dispose);
    c.setApiModelId('claude-opus-5-5');
    await _pump(tester, c);
    expect(
      find.byKey(const ValueKey('model-spec-dynamicWebSearch')),
      findsOneWidget,
    );
    final sw = tester.widget<IosSwitch>(
      find.byKey(const ValueKey('model-spec-dynamicWebSearch')),
    );
    expect(sw.value, isTrue);
  });
}
