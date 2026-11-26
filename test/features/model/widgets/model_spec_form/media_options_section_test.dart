import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/media/media_model_overrides.dart';
import 'package:Kelivo/desktop/widgets/desktop_select_dropdown.dart';
import 'package:Kelivo/features/model/widgets/model_spec_form/media_options_section.dart';
import 'package:Kelivo/features/model/widgets/model_spec_form/model_spec_form_controller.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../../support/business_test_harness.dart';

void main() {
  for (final desktop in [true, false]) {
    testWidgets(
      'selecting an image protocol in the ${desktop ? "desktop dropdown" : "mobile sheet"}',
      (tester) async {
        final settings = SettingsProvider(createBusinessTestPreferences());
        await tester.runAsync(() => settings.loaded);
        addTearDown(settings.dispose);
        final controller = ModelSpecFormController(
          config: ProviderConfig.defaultsFor('OpenAI'),
          modelKey: 'gpt-image-1',
          isNew: false,
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: settings,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (_, _) =>
                        MediaOptionsSection(controller: controller),
                  ),
                ),
              ),
            ),
          ),
        );
        final dropdown = find.byType(DesktopSelectDropdown<MediaApiProtocol>);
        expect(dropdown, desktop ? findsOneWidget : findsNothing);
        await tester.tap(desktop ? dropdown : find.text('Auto').first);
        await tester.pumpAndSettle();
        expect(
          find.byType(BottomSheet),
          desktop ? findsNothing : findsOneWidget,
        );
        expect(find.text('OpenAI Videos / Sora'), findsNothing);
        final option = find.text('Gemini generateContent');
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pumpAndSettle();
        expect(controller.mediaProtocol, MediaApiProtocol.geminiImage);
        expect(find.text('Gemini generateContent'), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
      },
      variant: TargetPlatformVariant({
        desktop ? TargetPlatform.macOS : TargetPlatform.iOS,
      }),
    );
  }
}
