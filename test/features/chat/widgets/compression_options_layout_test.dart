import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/chat/compression_templates.dart';
import 'package:Kelivo/desktop/widgets/desktop_select_dropdown.dart';
import 'package:Kelivo/features/chat/widgets/compress_context_options_dialog.dart';
import 'package:Kelivo/features/chat/widgets/compression_controls.dart';
import 'package:Kelivo/features/chat/widgets/compression_template_library.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../../../support/business_test_harness.dart';

void main() {
  for (final mobile in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets('compression layout mobile=$mobile dark=$dark', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = mobile
            ? TargetPlatform.android
            : TargetPlatform.macOS;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = mobile
            ? const Size(393, 852)
            : const Size(1200, 800);
        late SettingsProvider settings;
        late AssistantProvider assistants;
        late ChatService chat;
        final capture = Platform.environment['KELIVO_COMPRESSION_PREVIEW_DIR'];
        await tester.runAsync(() async {
          final harness = await createBusinessTestHarness();
          settings = SettingsProvider(harness.preferences);
          await settings.loaded;
          assistants = AssistantProvider(preferences: harness.preferences);
          await assistants.loaded;
          chat = ChatService(
            existingRepository: ChatDatabaseRepository(harness.database),
          );
          await settings.setProviderConfig(
            'preview',
            ProviderConfig(
              id: 'preview',
              name: 'Anthropic',
              enabled: true,
              apiKey: '',
              baseUrl: 'https://example.test',
              models: const ['Claude Sonnet 4', 'Claude Haiku 4.5'],
            ),
          );
          await settings.setCurrentModel('preview', 'Claude Sonnet 4');
          if (capture != null) {
            final loader = FontLoader('CompressionPreview')
              ..addFont(
                File(
                  '/System/Library/Fonts/STHeiti Light.ttc',
                ).readAsBytes().then((b) => ByteData.sublistView(b)),
              );
            await loader.load();
            final icons = FontLoader('packages/lucide_icons_flutter/Lucide')
              ..addFont(
                rootBundle.load(
                  'packages/lucide_icons_flutter/assets/lucide.ttf',
                ),
              );
            await icons.load();
          }
        });
        addTearDown(() {
          settings.dispose();
          assistants.dispose();
          chat.dispose();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          debugDefaultTargetPlatformOverride = null;
        });
        final key = GlobalKey();
        final theme = dark ? buildDarkTheme(null) : buildLightTheme(null);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: settings),
              ChangeNotifierProvider.value(value: assistants),
              ChangeNotifierProvider.value(value: chat),
            ],
            child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: Locale(capture == null ? 'en' : 'zh'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: capture == null
                    ? theme
                    : theme.copyWith(
                        textTheme: theme.textTheme.apply(
                          fontFamily: 'CompressionPreview',
                        ),
                      ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => Center(
                      child: TextButton(
                        child: const Text('Open compression'),
                        onPressed: () => showCompressContextOptions(
                          context: context,
                          builder: (sheet) => CompressContextOptionsDialog(
                            sheet: sheet,
                            previewRequest: (options, config) async => (
                              prompt: 'Preview',
                              estimatedRequests: 1,
                              maxRequestAttempts: config.maxRequestAttempts,
                            ),
                            messages: [
                              for (var i = 0; i < 10; i++)
                                ChatMessage(
                                  id: 'u$i',
                                  role: 'user',
                                  content: 'Example $i',
                                  conversationId: 'c',
                                ),
                            ],
                            operations: const [],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open compression'));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(CompressContextOptionsDialog)),
        )!;
        Future<void> waitFor(Finder finder) async {
          for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump();
          }
          await tester.pumpAndSettle();
          expect(finder, findsOneWidget);
          expect(tester.takeException(), isNull);
        }

        Finder field(String label) => find.descendant(
          of: find.widgetWithText(IosFormTextField, label),
          matching: find.byType(TextField),
        );
        final library = find.byType(CompressionTemplateLibrary);
        final createdTemplate = find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'Project notes',
        );

        Future<void> saveForm() async {
          await tester.tap(
            find.descendant(
              of: find.byType(FormSheetActions).last,
              matching: find.text(l10n.multiKeyPageSave),
            ),
          );
          await tester.pump();
        }

        expect(
          find.byType(BottomSheet),
          mobile ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        Future<void> screenshot(String stage) async {
          if (capture == null) return;
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            image.dispose();
            await Directory(capture).create(recursive: true);
            await File(
              '$capture/${mobile ? 'mobile' : 'desktop'}-${dark ? 'dark' : 'light'}-$stage.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          });
        }

        await screenshot('manual');
        // Both daily controls must be usable directly from the first screen.
        await tester.tap(find.text('Claude Sonnet 4'));
        await waitFor(find.text('Claude Haiku 4.5'));
        await tester.tap(find.text('Claude Haiku 4.5'));
        await tester.pumpAndSettle();
        expect(find.text('Claude Haiku 4.5'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(l10n.compressionManage));
        await waitFor(
          find.descendant(
            of: library,
            matching: find.text(l10n.compressionGeneralDescription),
          ),
        );
        expect(find.byType(CompressionTemplateLibrary), findsOneWidget);
        await screenshot('library');
        final lastTemplate = find.descendant(
          of: library,
          matching: find.text(l10n.compressionRoleplay),
        );
        await tester.ensureVisible(lastTemplate);
        await tester.pumpAndSettle();
        expect(lastTemplate.hitTestable(), findsOneWidget);
        await tester.ensureVisible(
          find.descendant(
            of: library,
            matching: find.text(l10n.compressionGeneral),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> openBuiltInEditor() async {
          await tester.tap(
            find
                .descendant(
                  of: library,
                  matching: find.byTooltip(l10n.compressionMore),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.compressionEditTemplate));
          await tester.pumpAndSettle();
        }

        await openBuiltInEditor();
        expect(
          tester
              .widget<TextField>(field(l10n.compressionTemplateName))
              .readOnly,
          isFalse,
        );
        expect(
          tester.widget<TextField>(field(l10n.compressionPrompt)).readOnly,
          isFalse,
        );
        const editedPrompt = 'Keep project constraints and verified results.';
        await tester.enterText(field(l10n.compressionPrompt), editedPrompt);
        final language = find.byWidgetPredicate(
          (widget) =>
              widget is DesktopSelectDropdown<String> &&
              widget.semanticLabel == l10n.compressionLanguage,
        );
        await tester.ensureVisible(language);
        await tester.tap(language);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('English').last);
        await tester.tap(find.text('English').last);
        await tester.pumpAndSettle();
        await saveForm();
        await waitFor(
          find.descendant(of: library, matching: find.text(editedPrompt)),
        );
        final savedBuiltIn = await tester.runAsync(
          () => chat.chatRepositoryOrNull!.compression.template('general'),
        );
        expect(savedBuiltIn!.prompt, editedPrompt);
        expect(savedBuiltIn.outputLanguage, 'en');
        expect(savedBuiltIn.builtIn, isTrue);
        await openBuiltInEditor();
        expect(
          tester
              .widget<TextField>(field(l10n.compressionPrompt))
              .controller!
              .text,
          editedPrompt,
        );
        await tester.tap(find.text(l10n.compressionRestoreDefault));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(field(l10n.compressionPrompt))
              .controller!
              .text,
          builtInCompressionTemplatesForLocale(l10n.localeName).first.prompt,
        );
        await tester.tap(
          find.descendant(
            of: find.byType(FormSheetActions).last,
            matching: find.text(l10n.homePageCancel),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          (await tester.runAsync(
            () => chat.chatRepositoryOrNull!.compression.template(
              'general',
              locale: l10n.localeName,
            ),
          ))!.prompt,
          editedPrompt,
        );
        await openBuiltInEditor();
        await tester.tap(find.text(l10n.compressionRestoreDefault));
        await saveForm();
        await waitFor(
          find.descendant(
            of: library,
            matching: find.text(l10n.compressionGeneralDescription),
          ),
        );
        expect(
          (await tester.runAsync(
            () => chat.chatRepositoryOrNull!.compression.template(
              'general',
              locale: l10n.localeName,
            ),
          ))!.toJson(),
          builtInCompressionTemplatesForLocale(l10n.localeName).first.toJson(),
        );
        // Changing the inherited global template inside the library updates
        // the outer form even without selecting a template for this chat.
        await tester.enterText(
          find.descendant(of: library, matching: find.byType(TextField)),
          l10n.compressionCode,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: library,
            matching: find.byTooltip(l10n.compressionMore),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.compressionSetGlobal));
        await tester.pumpAndSettle();
        for (
          var i = 0;
          i < 100 && settings.compressionDefaults.templateId != 'code';
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(settings.compressionDefaults.templateId, 'code');
        await tester.tap(
          find.descendant(
            of: library,
            matching: find.byTooltip(l10n.commonClose),
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 30; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is CompressionTemplateChoice &&
                w.selected &&
                w.label == l10n.compressionCode,
          ),
          findsOneWidget,
        );
        await tester.tap(find.text(l10n.compressionManage));
        await waitFor(library);
        await tester.tap(find.text(l10n.compressionNewTemplate));
        await tester.pumpAndSettle();
        await tester.enterText(
          field(l10n.compressionTemplateName),
          'Project notes',
        );
        await tester.enterText(
          field(l10n.compressionPrompt),
          'Summarize decisions and next steps:\n{content}',
        );
        await tester.pumpAndSettle();
        await screenshot('editor');
        if (mobile) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text(l10n.multiKeyPageSave).hitTestable(),
            findsOneWidget,
          );
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
        }
        await saveForm();
        await waitFor(find.byType(CompressionTemplateLibrary));
        await tester.enterText(
          find.descendant(of: library, matching: find.byType(TextField)),
          'Project notes',
        );
        await waitFor(createdTemplate);
        await tester.tap(createdTemplate);
        await tester.pumpAndSettle();
        expect(find.byType(CompressionTemplateLibrary), findsNothing);
        expect(find.text('Project notes'), findsOneWidget);
        // Cover both a persisted default and a selection not saved yet.
        if (dark) {
          await tester.ensureVisible(find.text(l10n.compressionMore));
          await tester.tap(find.text(l10n.compressionMore));
          await tester.pumpAndSettle();
          await saveForm();
          await waitFor(find.text(l10n.compressionManage));
        }
        await tester.ensureVisible(find.text(l10n.compressionManage));
        await tester.tap(find.text(l10n.compressionManage));
        await waitFor(library);
        await tester.enterText(
          find.descendant(of: library, matching: find.byType(TextField)),
          'Project notes',
        );
        final libraryTemplate = find.descendant(
          of: library,
          matching: createdTemplate,
        );
        await waitFor(libraryTemplate);
        await tester.tap(
          find.descendant(
            of: library,
            matching: find.byTooltip(l10n.compressionMore),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.homePageDelete));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byWidgetPredicate(
            (w) =>
                w is DesktopSelectDropdown<String> &&
                w.semanticLabel == l10n.compressionReplacementTemplate,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.compressionCode).last);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(FormSheetActions).last,
            matching: find.text(l10n.homePageDelete),
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 100 && libraryTemplate.evaluate().isNotEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(libraryTemplate, findsNothing);
        await tester.tap(
          find.descendant(
            of: library,
            matching: find.byTooltip(l10n.commonClose),
          ),
        );
        final selectedReplacement = find.byWidgetPredicate(
          (w) =>
              w is CompressionTemplateChoice &&
              w.selected &&
              (w.label == l10n.compressionGeneral ||
                  w.label == l10n.compressionCode),
        );
        await waitFor(selectedReplacement);
        expect(
          tester.widget<CompressionTemplateChoice>(selectedReplacement).label,
          l10n.compressionCode,
        );
        expect(find.byType(ChoiceChip), findsNothing);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        await tester.ensureVisible(field(l10n.compressionKeepTurns));
        await tester.tap(find.text(l10n.compressionKeepTurns));
        await tester.pumpAndSettle();
        final keepField = tester.widget<TextField>(
          field(l10n.compressionKeepTurns),
        );
        expect(keepField.focusNode!.hasFocus, isTrue);
        expect(
          keepField.controller!.selection,
          TextSelection(
            baseOffset: 0,
            extentOffset: keepField.controller!.text.length,
          ),
        );
        await tester.ensureVisible(find.text(l10n.compressionMore));
        await tester.tap(find.text(l10n.compressionMore));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(field(l10n.compressionKeepTurns), findsNothing);
        await screenshot('settings');
        expect(field(l10n.compressionTrigger), findsNothing);
        expect(field(l10n.compressionTarget), findsNothing);
        await tester.tap(find.text(l10n.compressionAutoNotify));
        await tester.pumpAndSettle();
        expect(field(l10n.compressionTrigger), findsOneWidget);
        expect(field(l10n.compressionTarget), findsNothing);
        await tester.enterText(field(l10n.compressionTrigger), '75');
        await tester.tap(find.text(l10n.compressionAutoOn));
        await tester.pumpAndSettle();
        await tester.ensureVisible(field(l10n.compressionTarget));
        await tester.enterText(field(l10n.compressionTarget), '55');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await screenshot('settings-auto');
        await tester.ensureVisible(find.text(l10n.compressionAutoOff));
        await tester.tap(find.text(l10n.compressionAutoOff));
        await tester.pumpAndSettle();
        expect(field(l10n.compressionTrigger), findsNothing);
        await tester.ensureVisible(find.text(l10n.compressionAdvancedOptions));
        await tester.tap(find.text(l10n.compressionAdvancedOptions));
        await tester.pumpAndSettle();
        await screenshot('settings-details');
        await tester.ensureVisible(field(l10n.compressionWindow));
        await tester.enterText(field(l10n.compressionWindow), '64000');
        await tester.ensureVisible(find.text(l10n.compressionAdvancedOptions));
        await tester.tap(find.text(l10n.compressionAdvancedOptions));
        await tester.pumpAndSettle();
        expect(field(l10n.compressionWindow), findsNothing);
        await saveForm();
        await waitFor(find.text(l10n.compressionManage));
        expect(settings.compressionDefaults.modelId, 'Claude Haiku 4.5');
        expect(settings.compressionDefaults.providerId, 'preview');
        expect(settings.compressionDefaults.triggerInputRatio, .75);
        expect(settings.compressionDefaults.targetInputRatio, .55);
        expect(settings.compressionDefaults.planningWindow, 64000);
        final selected = await tester.runAsync(
          () => chat.chatRepositoryOrNull!.compression.templates(),
        );
        expect(settings.compressionDefaults.templateId, 'code');
        expect(selected!.where((t) => t.name == 'Project notes'), isEmpty);
        // Resetting the override immediately restores the current chat model.
        await tester.tap(find.text(l10n.compressionChatModel).first);
        await tester.pumpAndSettle();
        expect(find.text('Claude Sonnet 4'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }
}
