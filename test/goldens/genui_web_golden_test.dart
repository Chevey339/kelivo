import 'package:Kelivo/features/intelligent_ui/host/gallery/web_gallery.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_web_document.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_web_preview.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_theme.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_web_card.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import '../support/genui_golden_fonts.dart';
import '../support/genui_web_platform.dart';

void main() {
  setUpAll(loadGenUiGoldenFonts);
  for (final dark in [false, true]) {
    for (final variant in [
      'cards',
      'cards-rtl',
      'cards-large',
      'mobile',
      'desktop',
    ]) {
      testWidgets('Web ${dark ? 'dark' : 'light'} $variant', (tester) async {
        final preview = variant == 'mobile' || variant == 'desktop';
        final platform = FakeGenUiWebPlatform();
        WebViewPlatform.instance = platform;
        tester.view.physicalSize = Size(
          variant == 'desktop' ? 1200 : 390,
          preview ? 844 : 1300,
        );
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final theme = dark ? buildDarkTheme(null) : buildLightTheme(null);
        final ready = UiWebDocument.parse(
          genUiWebGallerySource,
          closed: true,
          generation: UiGenerationStatus.complete,
        );
        final documents = [
          UiWebDocument.parse(
            genUiWebGallerySource,
            closed: false,
            generation: UiGenerationStatus.generating,
          ),
          ready,
          UiWebDocument.parse(
            '{"version":9}\n<body>Invalid</body>',
            closed: true,
            generation: UiGenerationStatus.complete,
          ),
          ready,
        ];
        const key = ValueKey('web-golden');
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'genui-golden'),
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  padding: variant == 'mobile'
                      ? const EdgeInsets.only(top: 44, bottom: 24)
                      : EdgeInsets.zero,
                  textScaler: TextScaler.linear(
                    variant == 'cards-large' ? 1.3 : 1,
                  ),
                ),
                child: Directionality(
                  textDirection: variant == 'cards-rtl'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: child!,
                ),
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: GenUiThemeScope(
                      child: Column(
                        children: [
                          if (preview)
                            GenUiWebCard(
                              document: ready,
                              supported: true,
                              onOpen: (value) =>
                                  showUiWebPreview(context, value),
                            )
                          else
                            for (var i = 0; i < documents.length; i++) ...[
                              GenUiWebCard(
                                document: documents[i],
                                supported: i != 3,
                                onOpen: (_) async {},
                                onExportHtml: (_) async {},
                              ),
                              const SizedBox(height: 16),
                            ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (preview) {
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(key),
          matchesGoldenFile(
            'baselines/genui/web_${dark ? 'dark' : 'light'}_$variant.png',
          ),
        );
        if (preview) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        }
        await tester.pumpWidget(const SizedBox());
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
    }
  }
}
