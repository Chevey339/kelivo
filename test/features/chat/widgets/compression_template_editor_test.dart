import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/chat/compression_templates.dart';
import 'package:Kelivo/features/chat/widgets/compression_controls.dart';
import 'package:Kelivo/features/chat/widgets/compression_template_library.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/theme/theme_factory.dart';

import '../../../support/business_test_harness.dart';

void main() {
  for (final locale in ['zh', 'en']) {
    for (final template in builtInCompressionTemplatesForLocale(locale)) {
      testWidgets(
        '${template.id} $locale prompt scrolls from its text to the end and remains editable',
        (tester) async {
          const haptics = MethodChannel('haptic_feedback');
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            haptics,
            (_) async => true,
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(haptics, null),
          );
          final desktop = defaultTargetPlatform == TargetPlatform.macOS;
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = desktop
              ? const Size(1200, 800)
              : const Size(393, 852);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          late SettingsProvider settings;
          late ChatService chat;
          await tester.runAsync(() async {
            final harness = await createBusinessTestHarness();
            settings = SettingsProvider(harness.preferences);
            await settings.loaded;
            chat = ChatService(
              existingRepository: ChatDatabaseRepository(harness.database),
            );
          });
          addTearDown(settings.dispose);
          addTearDown(chat.dispose);
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: settings),
                ChangeNotifierProvider.value(value: chat),
              ],
              child: MaterialApp(
                locale: Locale(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: buildLightTheme(null),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => Center(
                      child: TextButton(
                        onPressed: () =>
                            showCompressionTemplateLibrary(context),
                        child: const Text('Open library'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open library'));
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(CompressionTemplateLibrary)),
          )!;
          final title = find.text(compressionTemplateName(l10n, template));
          for (var i = 0; i < 100 && title.evaluate().isEmpty; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump();
          }
          await tester.ensureVisible(title);
          await tester.pumpAndSettle();
          expect(title.hitTestable(), findsOneWidget);
          await tester.tap(title);
          await tester.pumpAndSettle();
          final field = find.descendant(
            of: find.widgetWithText(IosFormTextField, l10n.compressionPrompt),
            matching: find.byType(TextField),
          );
          expect(
            tester.widget<TextField>(field).controller!.text,
            template.prompt,
          );
          final page = find.ancestor(
            of: field,
            matching: find.byType(SingleChildScrollView),
          );
          final pageScroll = tester.state<ScrollableState>(
            find.descendant(of: page, matching: find.byType(Scrollable)).first,
          );
          final editable = tester
              .state<EditableTextState>(
                find.descendant(of: field, matching: find.byType(EditableText)),
              )
              .renderEditable;
          final preview = find.text(l10n.compressionLocalPreview);

          final initialVisibleText = tester
              .getRect(field)
              .intersect(tester.getRect(page));
          await tester.sendEventToBinding(
            PointerScrollEvent(
              position: initialVisibleText.center,
              scrollDelta: const Offset(0, 120),
            ),
          );
          await tester.pumpAndSettle();
          expect(pageScroll.position.pixels, greaterThan(0));

          // All gestures begin over the visible prompt, not the page margins.
          for (
            var i = 0;
            i < 40 && preview.hitTestable().evaluate().isEmpty;
            i++
          ) {
            final visibleText = tester
                .getRect(field)
                .intersect(tester.getRect(page));
            expect(visibleText.height, greaterThan(20));
            await tester.dragFrom(
              visibleText.center,
              Offset(0, -math.min(200.0, visibleText.height * .6)),
            );
            await tester.pumpAndSettle();
          }
          expect(pageScroll.position.pixels, greaterThan(0));
          expect(preview.hitTestable(), findsOneWidget);
          final lastLine = editable.localToGlobal(
            editable
                .getLocalRectForCaret(
                  TextPosition(offset: template.prompt.length),
                )
                .center,
          );
          expect(tester.getRect(page).contains(lastLine), isTrue);

          await tester.showKeyboard(field);
          if (!desktop) {
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          }
          final edited = '${template.prompt}\n滚动到底部后添加的要求。';
          tester.testTextInput.updateEditingValue(
            TextEditingValue(
              text: edited,
              selection: TextSelection.collapsed(offset: edited.length),
            ),
          );
          await tester.pumpAndSettle();
          final editedCaret = editable.localToGlobal(
            editable
                .getLocalRectForCaret(TextPosition(offset: edited.length))
                .center,
          );
          expect(tester.getRect(page).contains(editedCaret), isTrue);
          expect(
            find.text(l10n.multiKeyPageSave).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(l10n.multiKeyPageSave));
          await tester.pumpAndSettle();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          final saved = await tester.runAsync(
            () => chat.chatRepositoryOrNull!.compression.template(template.id),
          );
          expect(saved!.prompt, edited);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
        variant: TargetPlatformVariant({
          TargetPlatform.iOS,
          TargetPlatform.android,
          TargetPlatform.macOS,
        }),
      );
    }
  }
}
