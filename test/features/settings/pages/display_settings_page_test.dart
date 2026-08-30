import "../../../support/business_test_harness.dart";
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/settings/pages/display_settings_page.dart';
import 'package:Kelivo/features/settings/widgets/memory_ui.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  testWidgets('input background opacity sheet shows light and dark controls', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DisplaySettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('82%'), findsOneWidget);
    expect(find.textContaining('Light 82% / Dark 74%'), findsNothing);

    final opacityRow = find.text('Input Box Background Opacity');
    await tester.scrollUntilVisible(opacityRow, 240);
    await tester.pumpAndSettle();

    await tester.tap(opacityRow);
    await tester.pumpAndSettle();

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.byType(SfSlider), findsNWidgets(2));
  });

  testWidgets(
    'chat item display page shows thinking and tool card switches with tips',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      addTearDown(settings.dispose);
      await settings.loaded;

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChatItemDisplaySettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final thinkingTitle = find.text('Show Thinking Cards');
      await tester.scrollUntilVisible(
        thinkingTitle,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(thinkingTitle, findsOneWidget);
      expect(find.text('Show Tool Cards'), findsOneWidget);
      expect(
        find.text('When off, thinking-process cards are hidden in chat.'),
        findsNothing,
      );
      expect(
        find.text('When off, tool-use cards are hidden in chat.'),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is MemoryTipIcon &&
              widget.message ==
                  'When off, thinking-process cards are hidden in chat.',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is MemoryTipIcon &&
              widget.message == 'When off, tool-use cards are hidden in chat.',
        ),
        findsOneWidget,
      );
      expect(settings.showThinkingCards, isTrue);
      expect(settings.showToolCards, isTrue);

      await tester.tap(thinkingTitle);
      await tester.pumpAndSettle();
      expect(settings.showThinkingCards, isFalse);

      await tester.tap(find.text('Show Tool Cards'));
      await tester.pumpAndSettle();
      expect(settings.showToolCards, isFalse);
    },
  );

  testWidgets('behavior page shows long-paste threshold only when enabled', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await settings.loaded;

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BehaviorStartupSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Show Thinking Cards'), findsNothing);
    expect(find.text('Show Tool Cards'), findsNothing);

    final keepCardsToggle = find.text(
      'Keep thinking and tool cards when editing assistant',
    );
    await tester.scrollUntilVisible(
      keepCardsToggle,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(keepCardsToggle, findsOneWidget);
    expect(settings.keepThinkingAndToolCardsWhenEditingAssistant, isFalse);

    await tester.tap(keepCardsToggle);
    await tester.pumpAndSettle();
    expect(settings.keepThinkingAndToolCardsWhenEditingAssistant, isTrue);

    final toggle = find.text('Paste long text as file');
    await tester.scrollUntilVisible(
      toggle,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(toggle, findsOneWidget);
    expect(find.text('Conversion threshold'), findsOneWidget);
    expect(find.text('5000'), findsOneWidget);

    await settings.setLongPasteAsFile(false);
    await tester.pumpAndSettle();
    expect(find.text('Conversion threshold'), findsNothing);
  });

  testWidgets('mobile threshold saves while typing and survives back', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await settings.loaded;

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BehaviorStartupSettingsPage(),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final thresholdLabel = find.text('Conversion threshold');
    await tester.scrollUntilVisible(
      thresholdLabel,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '8000');
    await tester.pump();
    expect(settings.longPasteAsFileThreshold, 8000);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(settings.longPasteAsFileThreshold, 8000);
  });

  testWidgets(
    'mobile threshold keeps a typed value when the switch turns off',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      addTearDown(settings.dispose);
      await settings.loaded;

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BehaviorStartupSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Conversion threshold'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1200');
      await tester.pump();
      expect(settings.longPasteAsFileThreshold, 1200);

      await tester.tap(find.text('Paste long text as file'));
      await tester.pumpAndSettle();
      expect(find.text('Conversion threshold'), findsNothing);
      expect(settings.longPasteAsFile, isFalse);
      expect(settings.longPasteAsFileThreshold, 1200);
    },
  );
}
