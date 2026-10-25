import '../support/business_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/model_spec_edit_dialog.dart';
import 'package:Kelivo/desktop/widgets/desktop_form_dialog.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';

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

  Future<SettingsProvider> pumpApp(
    WidgetTester tester, {
    required Future<bool?> Function(BuildContext context) open,
    required ValueChanged<bool?> onPopped,
  }) async {
    final harness = await createBusinessTestHarness(initial: {});
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    await settings.setProviderConfig('Test', _config());

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              return TextButton(
                key: const ValueKey('open-model-spec-dialog'),
                onPressed: () async {
                  onPopped(await open(context));
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    return settings;
  }

  testWidgets('edit dialog saves context window and pops true', (tester) async {
    bool? popped;
    final settings = await pumpApp(
      tester,
      open: (context) => showDesktopModelSpecEditDialog(
        context,
        providerKey: 'Test',
        modelKey: 'plain-model',
      ),
      onPopped: (value) => popped = value,
    );

    await tester.tap(find.byKey(const ValueKey('open-model-spec-dialog')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('model-spec-edit-dialog')),
      findsOneWidget,
    );
    expect(find.byType(DesktopFormDialog), findsOneWidget);
    expect(find.byType(DesktopFormDialogHeader), findsOneWidget);
    expect(find.byType(DesktopFormDialogFooter), findsOneWidget);
    expect(find.byType(DesktopFormDialogNavItem), findsWidgets);

    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.textAlignVertical, TextAlignVertical.center);
    }
    expect(find.byType(IosFormTextField), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('model-spec-nav-limits')));
    await tester.pumpAndSettle();

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

    expect(
      fieldAlign(const ValueKey('model-spec-context-window')),
      TextAlign.right,
    );
    expect(
      fieldAlign(const ValueKey('model-spec-max-output')),
      TextAlign.right,
    );
    expect(
      fieldAlign(const ValueKey('model-spec-pricing-input')),
      TextAlign.right,
    );
    expect(fieldAlign(const ValueKey('model-spec-currency')), TextAlign.right);

    TextAlignVertical? fieldVertical(Key key) {
      return tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(TextField),
            ),
          )
          .textAlignVertical;
    }

    expect(
      fieldVertical(const ValueKey('model-spec-context-window')),
      TextAlignVertical.center,
    );
    expect(
      fieldVertical(const ValueKey('model-spec-max-output')),
      TextAlignVertical.center,
    );
    expect(
      fieldVertical(const ValueKey('model-spec-pricing-input')),
      TextAlignVertical.center,
    );

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('model-spec-context-window')),
        matching: find.byType(TextField),
      ),
      '128000',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('model-spec-confirm')));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    final ov =
        settings.getProviderConfig('Test').modelOverrides['plain-model'] as Map;
    expect(ov['contextWindow'], 128000);
  });

  testWidgets('create dialog stays open when id is empty', (tester) async {
    bool? popped;
    await pumpApp(
      tester,
      open: (context) =>
          showDesktopCreateModelSpecDialog(context, providerKey: 'Test'),
      onPopped: (value) => popped = value,
    );

    await tester.tap(find.byKey(const ValueKey('open-model-spec-dialog')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('model-spec-edit-dialog')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('model-spec-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('model-spec-edit-dialog')),
      findsOneWidget,
    );
    expect(popped, isNull);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
