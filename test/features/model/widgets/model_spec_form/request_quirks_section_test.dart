import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/model/widgets/model_spec_form/model_spec_form_controller.dart';
import 'package:Kelivo/features/model/widgets/model_spec_form/request_quirks_section.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';

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
