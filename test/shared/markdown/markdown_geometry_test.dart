import 'dart:io';

import 'package:Kelivo/shared/markdown/diagram_chrome.dart';
import 'package:Kelivo/shared/markdown/markdown_actions.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

const _font = 'markdown-geometry-mono';
MarkstreamTheme theme(double size) => MarkstreamTheme.fromColorScheme(
  ColorScheme.fromSeed(seedColor: Colors.blue),
  bodyStyle: TextStyle(fontFamily: _font, fontSize: size, height: 1.5),
  codeFontFamily: _font,
);

Widget host(Widget child, {double scale = 1}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: SelectionArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 390,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    ),
  ),
);

RenderParagraph paragraph(String text) => find
    .byType(RichText)
    .evaluate()
    .map((element) => element.renderObject)
    .whereType<RenderParagraph>()
    .firstWhere((value) => value.text.toPlainText() == text);

double baseline(RenderParagraph p) => p
    .localToGlobal(
      Offset(0, p.computeDistanceToActualBaseline(TextBaseline.alphabetic)),
    )
    .dy;

void main() {
  setUpAll(() async {
    final bytes = File(
      'test/fixtures/fonts/JetBrainsMono-Regular.ttf',
    ).readAsBytesSync();
    await (FontLoader(
      _font,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  for (final size in [14.0, 15.7]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'inline code shares text line height and optical baseline b=$size scale=$scale',
        (tester) async {
          final tokens = theme(size);
          await tester.pumpWidget(
            host(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('before plain after', style: tokens.body),
                  MarkstreamView(source: 'before `code` after', theme: tokens),
                ],
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          final plain = paragraph('before plain after');
          final rich = paragraph('before \uFFFC after');
          final rect = tester.getRect(find.byType(InlineCodeCapsule));
          expect(
            rich
                .getPositionForOffset(
                  Offset(rich.size.width, rich.size.height / 2),
                )
                .offset,
            'before \uFFFC after'.length,
          );
          expect(rich.size.height, closeTo(plain.size.height, .5));
          expect(
            rect.center.dy,
            closeTo(baseline(rich) - .35 * size * scale, .75),
          );
          expect(rect.height, lessThanOrEqualTo(plain.size.height - 2));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'task and radio centers share text optical baseline b=$size scale=$scale',
        (tester) async {
          final tokens = theme(size);
          await tester.pumpWidget(
            host(
              MarkstreamView(
                source:
                    '- [ ] Checkbox\n- [x] Checked\n\n( ) Radio\n(x) Selected',
                theme: tokens,
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          for (final entry in [
            ('markstream-task-indicator', 'Checkbox', 0),
            ('markstream-task-indicator', 'Checked', 1),
            ('markstream-radio-indicator', 'Radio', 0),
            ('markstream-radio-indicator', 'Selected', 1),
          ]) {
            final marker = find.byKey(ValueKey(entry.$1)).at(entry.$3);
            final rect = tester.getRect(marker);
            final text = paragraph(entry.$2);
            expect(
              rect.center.dy,
              closeTo(baseline(text) - .35 * size * scale, .75),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('code, diagram and mobile table chrome all measure 36 pixels', (
    tester,
  ) async {
    final tokens = theme(15.7);
    final table =
        MarkdownParser()
                .parse('| A | B |\n| - | - |\n| x | y |')
                .children
                .single
            as TableNode;
    for (final scale in [1.0, 1.3]) {
      await tester.pumpWidget(
        host(
          Column(
            children: [
              MarkstreamView(source: '```dart\ncode\n```', theme: tokens),
              MarkstreamView(
                source: '| A | B |\n| - | - |\n| x | y |',
                theme: tokens,
              ),
              DiagramChrome(
                theme: tokens,
                imageSelected: true,
                onImage: () {},
                onCode: () {},
                actions: const [],
              ),
              Builder(
                builder: (context) => markdownMobileTableToolbar(
                  context,
                  TableActionContext(
                    table: table,
                    theme: tokens,
                    capturePng: (_) async => Uint8List(0),
                  ),
                ),
              ),
            ],
          ),
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();
      for (final key in [
        'markstream-code-header',
        'markdown-diagram-header',
        'markdown-mobile-table-toolbar',
        'markstream-table-toolbar',
      ]) {
        expect(tester.getRect(find.byKey(ValueKey(key))).height, 36);
      }
      final tabs = find.descendant(
        of: find.byType(DiagramChrome),
        matching: find.byType(TextButton),
      );
      expect(tabs, findsNWidgets(2));
      for (var index = 0; index < 2; index++) {
        expect(tester.getRect(tabs.at(index)).height, 22);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('ordered list text aligns across a digit boundary', (
    tester,
  ) async {
    for (final scale in [1.0, 1.3]) {
      await tester.pumpWidget(
        host(
          MarkstreamView(source: '9. Ninth\n10. Tenth', theme: theme(15.7)),
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        paragraph('Ninth').localToGlobal(Offset.zero).dx,
        paragraph('Tenth').localToGlobal(Offset.zero).dx,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('details summary row and body share the container inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        MarkstreamView(
          source:
              '<details open>\n<summary>Summary</summary>\n\nBody\n</details>',
          theme: theme(15.7),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final block = find.byType(MarkstreamDetailsBlock);
    final summaryRow = find
        .descendant(of: block, matching: find.byType(Row))
        .first;
    expect(
      tester.getRect(summaryRow).left,
      paragraph('Body').localToGlobal(Offset.zero).dx,
    );
    expect(tester.takeException(), isNull);
  });
}
