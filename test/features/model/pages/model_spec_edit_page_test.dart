import '../../../support/business_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/model/pages/model_spec_edit_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

ProviderConfig _config() {
  return ProviderConfig(
    id: 'Test',
    enabled: true,
    name: 'Test',
    apiKey: 'test-key',
    baseUrl: 'https://example.test/v1',
    providerType: ProviderKind.openai,
    models: const ['plain-model'],
    modelOverrides: const {
      'plain-model': {'name': 'Plain', 'type': 'chat', 'abilities': <String>[]},
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edit page shows source capsule, saves ability, and pops true', (
    tester,
  ) async {
    final harness = await createBusinessTestHarness(initial: {});
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    await settings.setProviderConfig('Test', _config());

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool? popped;
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              return TextButton(
                key: const ValueKey('open-model-spec'),
                onPressed: () async {
                  popped = await showModelSpecEditPage(
                    context,
                    providerKey: 'Test',
                    modelKey: 'plain-model',
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-model-spec')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('spec-source-capsule')), findsWidgets);

    TextAlign fieldAlign(Key key) {
      return tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(TextField),
            ),
          )
          .textAlign;
    }

    await tester.ensureVisible(
      find.byKey(const ValueKey('model-spec-context-window')),
    );
    expect(
      fieldAlign(const ValueKey('model-spec-context-window')),
      TextAlign.right,
    );
    expect(
      fieldAlign(const ValueKey('model-spec-max-output')),
      TextAlign.right,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('model-spec-pricing-input')),
    );
    expect(
      fieldAlign(const ValueKey('model-spec-pricing-input')),
      TextAlign.right,
    );
    expect(
      fieldAlign(const ValueKey('model-spec-pricing-output')),
      TextAlign.right,
    );
    expect(
      fieldAlign(const ValueKey('model-spec-pricing-cache-read')),
      TextAlign.right,
    );
    expect(
      fieldAlign(const ValueKey('model-spec-pricing-cache-write')),
      TextAlign.right,
    );
    expect(fieldAlign(const ValueKey('model-spec-currency')), TextAlign.right);

    final tool = find.byKey(const ValueKey('model-spec-ability-tool'));
    await tester.ensureVisible(tool);
    await tester.tap(tool);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('model-spec-save')));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    final ov =
        settings.getProviderConfig('Test').modelOverrides['plain-model'] as Map;
    expect(ov['abilities'], contains('tool'));
  });
}
