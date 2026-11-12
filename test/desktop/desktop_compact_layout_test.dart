import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/desktop/desktop_translate_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import '../support/business_test_harness.dart';
import 'package:Kelivo/desktop/desktop_context_menu.dart';
import 'package:Kelivo/desktop/desktop_glass_popover.dart';
import 'package:Kelivo/desktop/widgets/desktop_labeled_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final language in ['zh-TW', 'zh-CN']) {
    testWidgets(
      'translation toolbar supports long language and model names at 360px: $language',
      (tester) async {
        final harness = await createBusinessTestHarness();
        final settings = SettingsProvider(harness.preferences);
        final assistants = AssistantProvider(preferences: harness.preferences);
        await Future.wait([settings.loaded, assistants.loaded]);
        addTearDown(settings.dispose);
        addTearDown(assistants.dispose);
        await settings.setTranslateTargetLang(language);
        await settings.setTranslateModel('Test', 'claude-sonnet-4-5-20250929');
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 640);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: settings),
              ChangeNotifierProvider.value(value: assistants),
            ],
            child: const MaterialApp(
              locale: Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: DesktopTranslatePage()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(DesktopTranslatePage)),
        )!;
        final source = find.byWidgetPredicate(
          (widget) => widget is TextField && !widget.readOnly,
        );
        await tester.enterText(source, 'Preserve translation draft');
        for (final width in [1200.0, 360.0]) {
          tester.view.physicalSize = Size(width, 640);
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(source).controller!.text,
            'Preserve translation draft',
          );
          expect(tester.takeException(), isNull);
        }
        await tester.tap(
          find.text(
            language == 'zh-TW'
                ? l10n.languageDisplayTraditionalChinese
                : l10n.languageDisplaySimplifiedChinese,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.languageDisplayEnglish));
        await tester.pumpAndSettle();
        expect(settings.translateTargetLang, 'en');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('a focused settings control retains its draft across resizing', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 640);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        home: Scaffold(
          body: ListView(
            children: [
              DesktopLabeledControl(
                label: const Text('Request URL'),
                control: TextField(controller: controller, focusNode: focus),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'https://example.test/v1');
    final state = tester.state(find.byType(TextField));
    for (final width in [360.0, 1000.0, 360.0]) {
      tester.view.physicalSize = Size(width, 640);
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(tester.state(find.byType(TextField)), same(state));
      expect(controller.text, 'https://example.test/v1');
      expect(tester.getRect(find.byType(TextField)).right, closeTo(width, .1));
      expect(tester.takeException(), isNull);
    }
  });

  for (final glass in [false, true]) {
    testWidgets(
      'an open ${glass ? 'popover' : 'context menu'} remains actionable after narrowing',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1200, 640);
        addTearDown(tester.view.reset);
        var taps = 0;
        await tester.pumpWidget(
          _app(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    if (glass) {
                      showDesktopGlassPopover(
                        context,
                        anchorRect: const Rect.fromLTWH(400, 560, 720, 40),
                        width: 720,
                        builder: (context, handle) => DesktopGlassPanel(
                          child: SizedBox(
                            height: 180,
                            child: TextButton(
                              onPressed: () {
                                taps++;
                                handle.close();
                              },
                              child: const Text('Apply'),
                            ),
                          ),
                        ),
                      );
                    } else {
                      showDesktopContextMenuAt(
                        context,
                        globalPosition: const Offset(1000, 500),
                        items: [
                          DesktopContextMenuItem(
                            label:
                                'A long settings action that must remain within the narrow window',
                            onTap: () => taps++,
                          ),
                        ],
                      );
                    }
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(360, 640);
        await tester.pumpAndSettle();
        final action = glass
            ? find.text('Apply')
            : find.text(
                'A long settings action that must remain within the narrow window',
              );
        final rect = tester.getRect(action);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _app({required Widget home}) => ChangeNotifierProvider(
  create: (_) => SettingsProvider(createBusinessTestPreferences()),
  child: MaterialApp(home: home),
);
