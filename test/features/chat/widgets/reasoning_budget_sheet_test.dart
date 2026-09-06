import "../../../support/business_test_harness.dart";
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/reasoning_budget_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

Future<SettingsProvider> _settingsForClaudeModel(
  WidgetTester tester,
  String modelId,
) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsProvider(createBusinessTestPreferences());
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();

  await settings.setProviderConfig(
    'Claude',
    ProviderConfig(
      id: 'Claude',
      enabled: true,
      name: 'Claude',
      apiKey: 'test-key',
      baseUrl: 'https://api.anthropic.com/v1',
      providerType: ProviderKind.claude,
      models: <String>[modelId],
    ),
  );
  await settings.setCurrentModel('Claude', modelId);
  return settings;
}

Future<void> _pumpSheetLauncher(
  WidgetTester tester, {
  required SettingsProvider settings,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<AssistantProvider>(
          create: (_) =>
              AssistantProvider(preferences: createBusinessTestPreferences()),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                key: const ValueKey('open-reasoning-sheet'),
                onPressed: () => showReasoningBudgetSheet(context),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-reasoning-sheet')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReasoningBudgetSheet', () {
    testWidgets('shows max reasoning stop for Claude Fable 5', (tester) async {
      final settings = await _settingsForClaudeModel(tester, 'claude-fable-5');
      await _pumpSheetLauncher(tester, settings: settings);

      await _openSheet(tester);

      expect(
        find.byKey(const ValueKey('reasoning-stop-64000')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reasoning-stop-128000')),
        findsOneWidget,
      );

      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('reasoning-stop-128000'))),
      );
      await tester.pumpAndSettle();

      expect(settings.thinkingBudget, 128000);
      expect(find.text('Max'), findsOneWidget);
    });

    testWidgets('keeps max reasoning stop hidden for older Claude models', (
      tester,
    ) async {
      final settings = await _settingsForClaudeModel(
        tester,
        'claude-sonnet-4-5',
      );
      await _pumpSheetLauncher(tester, settings: settings);

      await _openSheet(tester);

      expect(find.byKey(const ValueKey('reasoning-stop-64000')), findsNothing);
      expect(find.byKey(const ValueKey('reasoning-stop-128000')), findsNothing);
    });

    testWidgets(
      'seeds from initialBudget without notifying global settings on open',
      (tester) async {
        final settings = await _settingsForClaudeModel(
          tester,
          'claude-sonnet-4-5',
        );
        var notifies = 0;
        settings.addListener(() => notifies++);
        int? changed;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<AssistantProvider>(
                create: (_) => AssistantProvider(
                  preferences: createBusinessTestPreferences(),
                ),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    key: const ValueKey('open-reasoning-sheet'),
                    onPressed: () => showReasoningBudgetSheet(
                      context,
                      initialBudget: 32000,
                      onChanged: (v) => changed = v,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await _openSheet(tester);

        // Opening must not mutate or notify global settings — that rebuilds
        // the caller's page during the entrance animation.
        expect(notifies, 0);
        expect(settings.thinkingBudget, isNull);
        // The sheet still displays the seeded selection.
        expect(find.text('High'), findsOneWidget);

        await tester.tapAt(
          tester.getCenter(find.byKey(const ValueKey('reasoning-stop-16000'))),
        );
        await tester.pumpAndSettle();

        expect(changed, 16000);
        expect(settings.thinkingBudget, 16000);
      },
    );

    testWidgets('animates label layout when the level changes', (
      tester,
    ) async {
      final settings = await _settingsForClaudeModel(
        tester,
        'claude-sonnet-4-5',
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<AssistantProvider>(
              create: (_) =>
                  AssistantProvider(preferences: createBusinessTestPreferences()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  key: const ValueKey('open-reasoning-sheet'),
                  onPressed: () =>
                      showReasoningBudgetSheet(context, initialBudget: 16000),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _openSheet(tester);
      expect(find.text('Medium'), findsOneWidget);

      double iconX() =>
          tester.getCenter(find.byType(SvgPicture).first).dx;
      final xs = <double>[iconX()];

      // Medium -> Low shrinks the title; the row must re-center over many
      // frames, not in a single jump.
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('reasoning-stop-1024'))),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        xs.add(iconX());
      }
      await tester.pumpAndSettle();

      expect(find.text('Low'), findsOneWidget);
      final movedFrames = <double>[];
      for (var i = 1; i < xs.length; i++) {
        if ((xs[i] - xs[i - 1]).abs() > 0.01) movedFrames.add(xs[i]);
      }
      expect(xs.first, isNot(closeTo(xs.last, 0.5)));
      // A jump would move exactly once; an animation moves over many frames.
      expect(movedFrames.length, greaterThan(3));
    });
  });
}
