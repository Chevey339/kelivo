import '../../../support/business_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/reasoning_request.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/assistant/widgets/assistant_reasoning_picker.dart';
import 'package:Kelivo/features/chat/widgets/reasoning_level_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/custom_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('assistant picker offers follow-default and every level', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    ReasoningRequest? picked = const ReasoningRequest(ReasoningLevel.low);
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AssistantReasoningPicker(
              current: const ReasoningRequest(ReasoningLevel.low),
              onSelected: (value) => picked = value,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('assistant-reasoning-follow-default')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('assistant-reasoning-auto')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('assistant-reasoning-off')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('assistant-reasoning-max')),
      findsOneWidget,
    );
    final off = tester.getCenter(
      find.byKey(const ValueKey('assistant-reasoning-off')),
    );
    final auto = tester.getCenter(
      find.byKey(const ValueKey('assistant-reasoning-auto')),
    );
    expect(off.dx, lessThan(auto.dx));
    expect(
      find.text('The actual level is clamped to what each model supports'),
      findsNothing,
    );
    expect(find.text('mid'), findsNothing);
    expect(find.text('xhigh'), findsNothing);

    await tester.tapAt(
      tester.getCenter(
        find.byKey(const ValueKey('assistant-reasoning-follow-default')),
      ),
    );
    await tester.pump();
    expect(picked, isNull);

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('assistant-reasoning-high'))),
    );
    await tester.pump();
    expect(picked, const ReasoningRequest(ReasoningLevel.high));
  });

  testWidgets('mobile assistant sheet wraps short content', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  key: const ValueKey('open-assistant-sheet'),
                  onPressed: () => showReasoningPickerSheet<void>(
                    context: context,
                    builder: (_) => AssistantReasoningPicker(
                      current: null,
                      onSelected: (_) {},
                    ),
                  ),
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-assistant-sheet')));
    await tester.pumpAndSettle();

    expect(find.byType(CustomBottomSheet), findsNothing);
    expect(find.byKey(ReasoningPickerSheet.panelKey), findsOneWidget);
    expect(find.text('Thinking'), findsNothing);
    expect(
      tester.getSize(find.byKey(ReasoningPickerSheet.panelKey)).height,
      lessThan(tester.getSize(find.byType(MaterialApp)).height * 0.60),
    );
  });
}
