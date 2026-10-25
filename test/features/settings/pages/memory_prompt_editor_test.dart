import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/memory/memory_prompts.dart';
import 'package:Kelivo/features/settings/pages/memory_settings_page.dart';
import 'package:Kelivo/shared/widgets/tip_icon.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

import '../../../support/business_test_harness.dart';

Future<SettingsProvider> _createSettings() async {
  SharedPreferences.setMockInitialValues({});
  final harness = await createBusinessTestHarness();
  final settings = SettingsProvider(harness.preferences);
  await settings.loaded;
  return settings;
}

Widget _wrap(SettingsProvider settings, {required Locale locale}) {
  return ChangeNotifierProvider.value(
    value: settings,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: MemorySettingsContent()),
    ),
  );
}

/// Opens the "memory rules" template editor from the settings list.
Future<void> _openRulesEditor(WidgetTester tester, String title) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpAndSettle();
  final target = find.text(title);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target.hitTestable());
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('injection count uses a tip icon instead of a subtitle', (
    tester,
  ) async {
    final settings = await _createSettings();
    await tester.pumpWidget(_wrap(settings, locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Items injected per type'), findsOneWidget);
    expect(find.textContaining('When a type exceeds this limit'), findsNothing);
    expect(find.byType(TipIcon), findsOneWidget);
  });

  testWidgets('editor shows one field, in the language the model is sent', (
    tester,
  ) async {
    final settings = await _createSettings();
    await settings.setMemoryPromptLang('zh');

    await tester.pumpWidget(_wrap(settings, locale: const Locale('zh')));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    await _openRulesEditor(tester, l10n.memoryPromptEditRulesTitle);

    // A single editor, holding the Chinese template — no language tabs.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, MemoryPrompts.rulesZh);
  });

  testWidgets('editor follows an explicit English prompt language', (
    tester,
  ) async {
    final settings = await _createSettings();
    await settings.setMemoryPromptLang('en');

    // Interface is Chinese, but prompts were pinned to English, so the editor
    // must edit the template that actually reaches the model.
    await tester.pumpWidget(_wrap(settings, locale: const Locale('zh')));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    await _openRulesEditor(tester, l10n.memoryPromptEditRulesTitle);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, MemoryPrompts.rulesEn);
  });

  testWidgets('saving writes only the active language template', (
    tester,
  ) async {
    final settings = await _createSettings();
    await settings.setMemoryPromptLang('zh');

    await tester.pumpWidget(_wrap(settings, locale: const Locale('zh')));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    await _openRulesEditor(tester, l10n.memoryPromptEditRulesTitle);

    await tester.enterText(find.byType(TextField), '自定义规则');
    await tester.tap(find.byTooltip(l10n.memoryPromptEditSave));
    await tester.pumpAndSettle();

    expect(settings.memoryRulesPromptZh, '自定义规则');
    expect(settings.memoryRulesPromptEn, MemoryPrompts.rulesEn);
  });

  testWidgets('legacy mode exposes and saves the legacy rules template', (
    tester,
  ) async {
    final settings = await _createSettings();
    await settings.setLegacyMemoryMode(true);
    await settings.setMemoryPromptLang('zh');

    await tester.pumpWidget(_wrap(settings, locale: const Locale('zh')));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    await _openRulesEditor(tester, l10n.memorySettingsLegacyPromptTitle);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, MemoryPrompts.legacyRulesZh);

    await tester.enterText(find.byType(TextField), '自定义旧版规则');
    await tester.tap(find.byTooltip(l10n.memoryPromptEditSave));
    await tester.pumpAndSettle();

    expect(settings.legacyMemoryPromptZh, '自定义旧版规则');
    expect(settings.legacyMemoryPromptEn, MemoryPrompts.legacyRulesEn);
  });

  testWidgets('legacy mode hides settings for the new memory system', (
    tester,
  ) async {
    final settings = await _createSettings();
    await settings.setLegacyMemoryMode(true);

    await tester.pumpWidget(_wrap(settings, locale: const Locale('zh')));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.text(l10n.memorySettingsLegacyPromptTitle), findsOneWidget);
    expect(find.text(l10n.memorySettingsModelSection), findsNothing);
    expect(find.text(l10n.memorySettingsPromptLangSection), findsOneWidget);
    expect(find.text(l10n.memoryPromptEditRulesTitle), findsNothing);
    expect(find.text(l10n.memorySettingsEntriesTitle), findsNothing);
    expect(find.text(l10n.memorySettingsProfileTitle), findsNothing);
    expect(find.text(l10n.memoryTraceSettingsTitle), findsNothing);
  });

  testWidgets('legacy editor follows an explicit English prompt language', (
    tester,
  ) async {
    final settings = await _createSettings();
    await settings.setLegacyMemoryMode(true);
    await settings.setMemoryPromptLang('en');

    await tester.pumpWidget(_wrap(settings, locale: const Locale('zh')));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    await _openRulesEditor(tester, l10n.memorySettingsLegacyPromptTitle);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, MemoryPrompts.legacyRulesEn);

    await tester.enterText(find.byType(TextField), 'Custom legacy rules');
    await tester.tap(find.byTooltip(l10n.memoryPromptEditSave));
    await tester.pumpAndSettle();

    expect(settings.legacyMemoryPromptEn, 'Custom legacy rules');
    expect(settings.legacyMemoryPromptZh, MemoryPrompts.legacyRulesZh);
  });
}
