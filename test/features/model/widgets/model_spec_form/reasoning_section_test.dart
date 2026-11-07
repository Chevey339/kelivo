import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/model/widgets/model_spec_form/model_spec_form_controller.dart';
import 'package:Kelivo/features/model/widgets/model_spec_form/reasoning_section.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

import '../../../../support/business_test_harness.dart';

ProviderConfig _mistralConfig() {
  return ProviderConfig(
    id: 'Mistral',
    enabled: true,
    name: 'Mistral',
    apiKey: 'test-key',
    baseUrl: 'https://api.mistral.ai/v1',
    providerType: ProviderKind.openai,
    models: const ['mistral-large-latest'],
  );
}

ModelSpecFormController _mistralController() {
  return ModelSpecFormController(
    config: _mistralConfig(),
    modelKey: 'mistral-large-latest',
    isNew: false,
  );
}

Future<void> _pump(WidgetTester tester, ModelSpecFormController c) {
  return tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>(
      create: (_) => SettingsProvider(createBusinessTestPreferences()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: ReasoningSection(controller: c)),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Mistral provider shows the Mistral dialect without a warning', (
    tester,
  ) async {
    final c = _mistralController();
    addTearDown(c.dispose);
    expect(c.spec.reasoning.dialect, ReasoningDialect.mistral);
    expect(c.spec.reasoning.replayField, ReasoningReplayField.mistralThinking);

    await _pump(tester, c);

    expect(find.text('Mistral reasoning effort'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('model-spec-mistral-dialect-warning')),
      findsNothing,
    );
  });

  testWidgets('unpaired replay field warns without changing the selection', (
    tester,
  ) async {
    final c = _mistralController();
    addTearDown(c.dispose);
    c.setReplayField(ReasoningReplayField.reasoningContent);

    await _pump(tester, c);

    expect(
      find.byKey(const ValueKey('model-spec-mistral-dialect-warning')),
      findsOneWidget,
    );
    expect(
      find.text(
        'History is sent with the selected replay field; official Mistral '
        'may reject that format.',
      ),
      findsOneWidget,
    );
    expect(c.spec.reasoning.replayField, ReasoningReplayField.reasoningContent);
  });

  testWidgets('dialect option sheet offers the Mistral dialect', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final c = _mistralController();
    addTearDown(c.dispose);
    c.setDialect(ReasoningDialect.openaiReasoningEffort);

    await _pump(tester, c);
    await tester.tap(find.text('OpenAI reasoning effort'));
    await tester.pumpAndSettle();

    expect(find.text('Mistral reasoning effort'), findsOneWidget);
    expect(
      find.text('reasoning_effort; Auto → high, Off omits it'),
      findsOneWidget,
    );

    final option = find.text('Mistral reasoning effort');
    await tester.ensureVisible(option);
    await tester.pumpAndSettle();
    await tester.tap(option);
    await tester.pumpAndSettle();

    expect(c.spec.reasoning.dialect, ReasoningDialect.mistral);
    debugDefaultTargetPlatformOverride = null;
  });
}
