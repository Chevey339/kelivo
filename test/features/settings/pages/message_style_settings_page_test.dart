import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/frosted/frosted_surface.dart';
import 'package:Kelivo/features/settings/pages/message_style_settings_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/theme/chat_bubble_style.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPage(
    WidgetTester tester, {
    required SettingsProvider settings,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider(
            create: (_) =>
                AssistantProvider(preferences: createBusinessTestPreferences()),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MessageStyleSettingsPage(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'default style keeps preview next to the picker and hides knobs',
    (tester) async {
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;

      await pumpPage(tester, settings: settings);

      expect(find.text('Message Style'), findsOneWidget);
      expect(find.text('Show assistant reply bubbles'), findsNothing);
      expect(find.text('Split paragraphs into bubbles'), findsOneWidget);
      expect(find.text('Customize thinking and tool cards'), findsNothing);
      expect(find.text('This is a user message'), findsWidgets);
      expect(
        find.text(
          'Default style follows the current theme and has no extra controls.',
        ),
        findsOneWidget,
      );
      expect(find.text('Blur'), findsNothing);
      expect(find.text('Background'), findsNothing);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    },
  );

  testWidgets('frosted style reveals knobs under the preview', (tester) async {
    final harness = await createBusinessTestHarness();
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;

    await pumpPage(tester, settings: settings);

    await tester.tap(find.text('Frosted Glass'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Default style follows the current theme and has no extra controls.',
      ),
      findsNothing,
    );
    expect(find.text('Blur'), findsOneWidget);
    expect(find.text('Background'), findsOneWidget);
    expect(find.text('This is a user message'), findsWidgets);
  });

  testWidgets('reply bubble switch updates the preview and layout controls', (
    tester,
  ) async {
    final harness = await createBusinessTestHarness();
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    await settings.setChatMessageBackgroundStyle(
      ChatMessageBackgroundStyle.frosted,
    );
    await pumpPage(tester, settings: settings);

    final toggle = find.byWidgetPredicate(
      (w) =>
          w is IosSwitch && w.semanticLabel == 'Show assistant reply bubbles',
    );
    Finder previewBubble(String text) => find.ancestor(
      of: find.text(text),
      matching: find.byType(FrostedSurface),
    );
    expect(previewBubble('This is an assistant reply.'), findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(previewBubble('This is an assistant reply.'), findsNothing);
    expect(previewBubble('Thinking'), findsOneWidget);
    expect(previewBubble('This is a user message'), findsOneWidget);
    expect(find.text('Fit assistant bubble to content'), findsNothing);
    expect(find.text('Split paragraphs into bubbles'), findsNothing);
    expect(find.text('Customize thinking and tool cards'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(previewBubble('This is an assistant reply.'), findsOneWidget);
    expect(find.text('Fit assistant bubble to content'), findsOneWidget);
    expect(find.text('Split paragraphs into bubbles'), findsOneWidget);
  });

  testWidgets('single reply bubble supports a separate card style preview', (
    tester,
  ) async {
    final harness = await createBusinessTestHarness();
    final settings = SettingsProvider(harness.preferences);
    addTearDown(settings.dispose);
    await settings.loaded;
    await settings.setChatMessageBackgroundStyle(
      ChatMessageBackgroundStyle.frosted,
    );
    await settings.setChatBubbleStyleOverrides(
      const ChatBubbleStyleOverrides(cornerRadius: 6, blurSigma: 12),
    );
    await pumpPage(tester, settings: settings);
    await tester.pumpAndSettle();

    Finder switchFor(String label) => find.byWidgetPredicate(
      (widget) => widget is IosSwitch && widget.semanticLabel == label,
    );
    Future<void> toggle(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    final cardSwitch = switchFor('Customize thinking and tool cards');
    expect(settings.assistantBubbleSplitParagraphs, isFalse);
    expect(cardSwitch, findsOneWidget);
    expect(find.text('Cards'), findsNothing);
    await toggle(cardSwitch);
    expect(find.text('Cards'), findsOneWidget);

    final blurSlider = find.byType(SfSlider).first;
    await tester.ensureVisible(blurSlider);
    await tester.tapAt(tester.getTopLeft(blurSlider) + const Offset(30, 20));
    await tester.pumpAndSettle();

    FrostedSurface surfaceFor(String label) => tester.widget<FrostedSurface>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(FrostedSurface),
      ),
    );
    expect(surfaceFor('Thinking').style.blurSigma, isNot(12));
    expect(surfaceFor('This is an assistant reply.').style.blurSigma, 12);

    await toggle(cardSwitch);
    expect(find.text('Cards'), findsNothing);
    expect(surfaceFor('Thinking').style.blurSigma, 12);
  });

  testWidgets('light and dark preview labels stay after switching', (
    tester,
  ) async {
    final harness = await createBusinessTestHarness();
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;

    await pumpPage(tester, settings: settings);

    expect(
      tester
          .widget<Theme>(find.byKey(const ValueKey<bool>(false)))
          .data
          .brightness,
      Brightness.light,
    );

    await tester.tap(find.text('Dark'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('This is a user message'), findsOneWidget);
    expect(
      tester
          .widget<Theme>(find.byKey(const ValueKey<bool>(true)))
          .data
          .brightness,
      Brightness.dark,
    );
  });
}
