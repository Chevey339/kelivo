import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/intelligent_ui/models/ui_context_attachment.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/gallery/context_gallery.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_context_chip.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_draft_dialog.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../support/business_test_harness.dart';
import '../support/genui_golden_fonts.dart';
import '../support/markdown_backdrop_host.dart';

void main() {
  setUpAll(loadGenUiGoldenFonts);
  for (final dark in [false, true]) {
    for (final variant in [
      'chip',
      'expanded',
      'stale',
      'history',
      'replace',
      'merge',
      'rtl',
      'large',
      'wallpaper',
      'desktop-replace',
      'replace-rtl',
      'replace-large',
      'merge-large',
    ]) {
      testWidgets('Context ${dark ? 'dark' : 'light'} $variant', (
        tester,
      ) async {
        final width = variant == 'desktop-replace' ? 900.0 : 390.0;
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final theme = dark ? buildDarkTheme(null) : buildLightTheme(null);
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        addTearDown(settings.dispose);
        const key = ValueKey('context-golden');
        final dialog =
            variant.contains('replace') || variant.startsWith('merge');
        Widget content() => Padding(
          padding: const EdgeInsets.all(16),
          child: Builder(
            builder: (context) => dialog
                ? IosTextButton(
                    label: 'Preview',
                    onPressed: () {
                      if (variant.startsWith('merge')) {
                        confirmGenUiMerge(context, genUiContextGalleryDraft);
                      } else {
                        confirmGenUiReplacement(
                          context,
                          current: UiContextAttachment.history(
                            genUiContextGalleryText,
                          ),
                          replacement: UiContextAttachment.history(
                            genUiContextGalleryReplacement,
                          ),
                        );
                      }
                    },
                  )
                : GenUiContextChip(
                    content: genUiContextGalleryText,
                    stale: variant == 'stale',
                    readOnly: variant == 'history',
                    onRemove: () {},
                  ),
          ),
        );
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: settings,
            child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme.copyWith(
                  textTheme: theme.textTheme.apply(fontFamily: 'genui-golden'),
                ),
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    textScaler: TextScaler.linear(
                      variant.endsWith('large') ? 1.3 : 1,
                    ),
                  ),
                  child: Directionality(
                    textDirection: variant.endsWith('rtl')
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: child!,
                  ),
                ),
                home: Scaffold(
                  body: variant == 'wallpaper'
                      ? MarkdownWallpaperTestHost(child: content())
                      : Align(alignment: Alignment.topCenter, child: content()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (dialog) {
          await tester.tap(find.text('Preview'));
          await tester.pumpAndSettle();
        } else if (variant == 'expanded' || variant == 'large') {
          await tester.tap(find.byKey(const ValueKey('genui-context-expand')));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(key),
          matchesGoldenFile(
            'baselines/genui/context_${dark ? 'dark' : 'light'}_$variant.png',
          ),
        );
      });
    }
  }
}
