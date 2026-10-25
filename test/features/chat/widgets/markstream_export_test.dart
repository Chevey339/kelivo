import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/message_export_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/shared/widgets/export_capture_scope.dart';
import 'package:Kelivo/shared/widgets/mermaid_image_cache.dart';
import '../../../support/business_test_harness.dart';
import '../../../support/markdown_render_helpers.dart';

Widget _host(SettingsProvider settings, Widget child) =>
    ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
Widget _markdown(String source, {bool streaming = false}) => ExportCaptureScope(
  enabled: true,
  child: MarkdownWithCodeHighlight(text: source, streaming: streaming),
);
RenderRepaintBoundary _boundary(WidgetTester tester, Widget root) =>
    tester.renderObject<RenderRepaintBoundary>(
      find
          .descendant(
            of: find.byWidget(root),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );

void main() {
  for (final width in [720.0, 480.0]) {
    testWidgets(
      'export $width paints the last slice of a full long code block at 3x',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        await settings.setAutoCollapseCodeBlock(true);
        await settings.setMobileCodeBlockWrap(false);
        addTearDown(settings.dispose);
        final source =
            '```text\n${List.generate(1002, (i) => 'line $i').join('\n')}\n```\n\nBOTTOM_MARKER';
        final theme = ThemeData.light();
        final root = buildExportCaptureRootForTesting(
          theme: theme,
          width: width,
          child: _markdown(source),
        );
        await tester.pumpWidget(_host(settings, root));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('markstream-virtualized-code')),
          findsNothing,
        );
        expect(find.byType(MarkstreamActionButton), findsNothing);
        expect(
          tester.getSize(find.byType(MarkstreamCodeContent)).height,
          greaterThan(14000),
        );
        expect(
          markdownParagraph(tester, 'line 1001').text.toPlainText(),
          contains('line 1001'),
        );
        final fullSize = _boundary(tester, root).size;
        expect(fullSize.width, width);
        expect(
          shouldUseFullExportCaptureForTesting(
            logicalSize: fullSize,
            pixelRatio: 3,
          ),
          isFalse,
        );
        const sliceHeight = 100.0;
        final slice = buildExportCaptureViewportRootForTesting(
          theme: theme,
          width: width,
          viewportHeight: sliceHeight,
          contentHeight: fullSize.height,
          offsetY: fullSize.height - sliceHeight,
          child: _markdown(source),
        );
        await tester.pumpWidget(_host(settings, slice));
        await tester.pumpAndSettle();
        final boundary = _boundary(tester, slice);
        final position = boundary.globalToLocal(
          markdownGlyphCenter(tester, 'BOTTOM_MARKER'),
        );
        expect(position.dy, inInclusiveRange(0, sliceHeight));
        final image = boundary.toImageSync(pixelRatio: 3);
        late final image_lib.Image png;
        try {
          final data = await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.png),
          );
          png = image_lib.decodePng(
            data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          )!;
        } finally {
          image.dispose();
        }
        expect(png.width, (width * 3).round());
        expect(png.height, (sliceHeight * 3).round());
        final centerX = (position.dx * 3).round(),
            centerY = (position.dy * 3).round();
        var dark = 0;
        for (
          var y = (centerY - 12).clamp(0, png.height - 1);
          y <= (centerY + 12).clamp(0, png.height - 1);
          y++
        ) {
          for (
            var x = (centerX - 12).clamp(0, png.width - 1);
            x <= (centerX + 12).clamp(0, png.width - 1);
            x++
          ) {
            final pixel = png.getPixel(x, y);
            if (pixel.r < 150 &&
                pixel.g < 150 &&
                pixel.b < 150 &&
                pixel.a > 0) {
              dark++;
            }
          }
        }
        expect(
          dark,
          greaterThan(20),
          reason: 'The bottom marker must be painted, not only laid out.',
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('export $width fits every wide table column and all rows', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      addTearDown(settings.dispose);
      final source =
          '| A | B | C | D | E |\n| - | - | - | - | - |\n${List.generate(55, (i) => '| $i | b | c | d | e |').join('\n')}';
      final root = buildExportCaptureRootForTesting(
        theme: ThemeData.light(),
        width: width,
        child: _markdown(source, streaming: true),
      );
      await tester.pumpWidget(_host(settings, root));
      await tester.pumpAndSettle();
      expect(tester.widget<Table>(find.byType(Table)).children, hasLength(56));
      expect(
        tester.getSize(find.byType(Table)).width,
        lessThanOrEqualTo(width),
      );
      expect(find.byType(MarkstreamActionButton), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'HTML and an uncached diagram export complete source without preview controls',
    (tester) async {
      MermaidImageCache.clear();
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      await settings.setAutoCollapseCodeBlock(true);
      addTearDown(settings.dispose);
      for (final (language, code) in [
        (
          'html',
          '<!DOCTYPE html>\n<html><body>\n${List.filled(70, '<p>line</p>').join('\n')}\n</body></html>',
        ),
        (
          'mermaid',
          'graph TD\n${List.generate(70, (i) => 'A$i-->A${i + 1}').join('\n')}',
        ),
      ]) {
        final source = '```$language\n$code\n```';
        await tester.pumpWidget(
          _host(
            settings,
            buildExportCaptureRootForTesting(
              theme: ThemeData.light(),
              child: _markdown(source),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MarkstreamCodeBlock), findsOneWidget);
        expect(
          tester.getSize(find.byType(MarkstreamCodeContent)).height,
          greaterThan(600),
        );
        expect(find.byType(MarkstreamActionButton), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
