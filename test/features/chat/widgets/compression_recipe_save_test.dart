import '../../../support/compression_options_pump.dart';
import 'package:Kelivo/core/models/compress_context_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/compression_config.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/chat/widgets/compress_context_options_dialog.dart';
import 'package:Kelivo/features/chat/widgets/context_dialog.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/l10n/app_localizations_en.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/theme/theme_factory.dart';

import '../../../support/business_test_harness.dart';

void check(String name, WidgetTesterCallback body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  final l10n = AppLocalizationsEn();
  late BusinessTestHarness harness;
  late SettingsProvider settings;
  late AssistantProvider assistants;
  late ChatService chat;

  Future<void> prepare(WidgetTester tester, TargetPlatform platform) async {
    debugDefaultTargetPlatformOverride = platform;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = platform == TargetPlatform.macOS
        ? const Size(1100, 800)
        : const Size(393, 852);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('haptic_feedback'),
          (_) async => null,
        );
    await tester.runAsync(() async {
      harness = await createBusinessTestHarness();
      settings = SettingsProvider(harness.preferences);
      assistants = AssistantProvider(preferences: harness.preferences);
      await settings.loaded;
      await assistants.loaded;
      await settings.setCompressionDefaults(
        const CompressionConfig(providerId: 'provider', modelId: 'model'),
      );
      chat = ChatService(
        existingRepository: ChatDatabaseRepository(harness.database),
      );
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      chat.dispose();
      settings.dispose();
      assistants.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('haptic_feedback'),
            null,
          );
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: assistants),
          ChangeNotifierProvider.value(value: chat),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildLightTheme(null),
          home: Scaffold(
            body: Builder(
              builder: (context) => IosTextButton(
                label: 'Open compression',
                onPressed: () => showCompressContextOptions(
                  context: context,
                  builder: (sheet) => CompressContextOptionsDialog(
                    sheet: sheet,
                    loadHistory: () async =>
                        CompressionHistory.fromMessages(const [], const []),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open compression'));
    await settleCompressionOptions(tester);
    await tester.ensureVisible(find.text(l10n.compressionMore));
    await tester.tap(find.text(l10n.compressionMore));
    await settleCompressionOptions(tester);
  }

  Finder recipeDialog() => find.ancestor(
    of: find.text(l10n.compressionSaveRecipe),
    matching: find.byType(ContextDialog),
  );

  Finder nameField() =>
      find.descendant(of: recipeDialog(), matching: find.byType(TextField));

  Finder recipeButton(String label) =>
      find.descendant(of: recipeDialog(), matching: find.text(label));

  Future<void> openRecipe(WidgetTester tester) async {
    await tester.ensureVisible(find.text(l10n.compressionSaveRecipeAction));
    await tester.tap(find.text(l10n.compressionSaveRecipeAction));
    await settleCompressionOptions(tester);
    expect(recipeDialog(), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done(), isTrue);
    await settleCompressionOptions(tester);
    expect(tester.takeException(), isNull);
  }

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
  ]) {
    check('recipe cancellation survives route animation on $platform', (
      tester,
    ) async {
      await prepare(tester, platform);
      for (final dismissal in ['cancel', 'close', 'barrier']) {
        await openRecipe(tester);
        await tester.enterText(nameField(), 'Unsaved recipe');
        await tester.pump();
        if (dismissal == 'cancel') {
          await tester.tap(recipeButton(l10n.homePageCancel));
        } else if (dismissal == 'close') {
          await tester.tap(
            find.descendant(
              of: recipeDialog(),
              matching: find.byTooltip(l10n.commonClose),
            ),
          );
        } else {
          await tester.tapAt(const Offset(4, 4));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.takeException(), isNull);
        await settleCompressionOptions(tester);
        expect(recipeDialog(), findsNothing);
        expect(find.byType(CompressContextOptionsDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      final recipes = await tester.runAsync(
        () => chat.chatRepositoryOrNull!.compression.recipes(),
      );
      expect(recipes, isEmpty);
    });

    check('recipe saves once and can be reopened on $platform', (tester) async {
      await prepare(tester, platform);
      Finder numberField(String label) => find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is IosFormTextField && widget.label == label,
        ),
        matching: find.byType(TextField),
      );
      final target = numberField(l10n.compressionLength);
      final output = numberField(l10n.compressionOutputBudget);
      await tester.ensureVisible(target);
      await tester.enterText(target, '512');
      await tester.ensureVisible(output);
      await tester.enterText(output, '8192');
      await tester.pump();
      expect(tester.widget<TextField>(target).controller!.text, '512');
      for (final bindModel in [false, true]) {
        await openRecipe(tester);
        final actions = find.descendant(
          of: recipeDialog(),
          matching: find.byType(FormSheetActions),
        );
        expect(tester.widget<FormSheetActions>(actions).onConfirm, isNull);
        await tester.enterText(nameField(), '   ');
        await tester.pump();
        expect(tester.widget<FormSheetActions>(actions).onConfirm, isNull);
        await tester.enterText(nameField(), '  Saved $bindModel  ');
        if (bindModel) {
          await tester.tap(
            find.descendant(
              of: recipeDialog(),
              matching: find.byType(IosSwitch),
            ),
          );
        }
        await tester.pump();
        final save = recipeButton(l10n.multiKeyPageSave);
        await tester.tap(save);
        await tester.tap(save);
        await waitFor(tester, () => recipeDialog().evaluate().isEmpty);
        final recipes = await tester.runAsync(
          () => chat.chatRepositoryOrNull!.compression.recipes(),
        );
        final recipe = recipes!.singleWhere(
          (r) => r.name == 'Saved $bindModel',
        );
        expect(recipe.settings.providerId, bindModel ? 'provider' : isNull);
        expect(recipe.settings.modelId, bindModel ? 'model' : isNull);
        expect(recipe.settings.summaryTokens, 512);
        expect(recipe.settings.maxOutputTokens, 8192);
        expect(recipe.template.id, 'general');
        expect(recipes, hasLength(bindModel ? 2 : 1));
      }
    });
  }

  check('recipe save failure keeps the name and supports retry', (
    tester,
  ) async {
    await prepare(tester, TargetPlatform.iOS);
    await tester.runAsync(
      () => harness.database.customStatement('''
      CREATE TRIGGER reject_recipe BEFORE INSERT ON extension_entity_rows
      WHEN NEW.kind = 'compressionRecipe'
      BEGIN SELECT RAISE(FAIL, 'recipe write blocked'); END
    '''),
    );
    await openRecipe(tester);
    await tester.enterText(nameField(), 'Retry recipe');
    await tester.pump();
    await tester.tap(recipeButton(l10n.multiKeyPageSave));
    await waitFor(
      tester,
      () => find.textContaining('recipe write blocked').evaluate().isNotEmpty,
    );
    expect(
      tester.widget<TextField>(nameField()).controller!.text,
      'Retry recipe',
    );
    await tester.runAsync(
      () => harness.database.customStatement('DROP TRIGGER reject_recipe'),
    );
    await tester.tap(recipeButton(l10n.multiKeyPageSave));
    await waitFor(tester, () => recipeDialog().evaluate().isEmpty);
    final recipes = await tester.runAsync(
      () => chat.chatRepositoryOrNull!.compression.recipes(),
    );
    expect(recipes!.single.name, 'Retry recipe');
  });

  check('recipe stays usable with the keyboard on a small phone', (
    tester,
  ) async {
    await prepare(tester, TargetPlatform.iOS);
    tester.view.physicalSize = const Size(320, 640);
    await settleCompressionOptions(tester);
    await openRecipe(tester);
    await tester.enterText(nameField(), 'Keyboard recipe');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await settleCompressionOptions(tester);
    expect(tester.takeException(), isNull);
    expect(recipeButton(l10n.multiKeyPageSave).hitTestable(), findsOneWidget);
    await tester.tap(recipeButton(l10n.multiKeyPageSave));
    // The keyboard can remain inset while the route animates away.
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await waitFor(tester, () => recipeDialog().evaluate().isEmpty);
    final recipes = await tester.runAsync(
      () => chat.chatRepositoryOrNull!.compression.recipes(),
    );
    expect(recipes!.single.name, 'Keyboard recipe');
  });
}
