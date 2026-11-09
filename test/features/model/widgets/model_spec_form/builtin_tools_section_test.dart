import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/model/widgets/model_spec_form/builtin_tools_section.dart';
import 'package:Kelivo/features/model/widgets/model_spec_form/model_spec_form_controller.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../../support/business_test_harness.dart';

void main() {
  testWidgets(
    'image model and complexity picker',
    (tester) async {
      final platform = defaultTargetPlatform;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      addTearDown(settings.dispose);
      final cfg = ProviderConfig(
        id: 'codex',
        enabled: true,
        name: 'Codex',
        apiKey: '',
        baseUrl: OAuthProvider.chatgpt.baseUrl,
        providerType: ProviderKind.openai,
        oauthProvider: OAuthProvider.chatgpt,
        useResponseApi: true,
        models: const ['gpt-6-astra'],
        modelOverrides: const {
          'gpt-6-astra': {
            'builtInTools': ['image_generation'],
          },
        },
      );
      await settings.setProviderConfig(cfg.id, cfg);
      final controller = ModelSpecFormController(
        config: cfg,
        modelKey: 'gpt-6-astra',
        isNew: false,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: SingleChildScrollView(
                child: BuiltinToolsSection(controller: controller),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('image-generation-complexity')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('image-generation-model')));
      await tester.pumpAndSettle();
      if (platform == TargetPlatform.macOS) {
        expect(find.byType(BottomSheet), findsNothing);
      }
      await tester.tap(find.text('gpt-image-2.6-sunburst'));
      await tester.pumpAndSettle();
      expect(controller.imageGeneration.model, 'gpt-image-2.6-sunburst');
      final complexity = find.byKey(
        const ValueKey('image-generation-complexity'),
      );
      await tester.ensureVisible(complexity);
      await tester.tap(complexity);
      await tester.pumpAndSettle();
      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();
      expect(controller.imageGeneration.complexity, 'high');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('image-generation-model')),
      );
      await tester.tap(find.byKey(const ValueKey('image-generation-model')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();
      expect(controller.imageGeneration.model, isNull);
      expect(controller.imageGeneration.complexity, isNull);
      expect(complexity, findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.macOS,
    }),
  );
}
