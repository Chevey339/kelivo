import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

import 'markstream_view_test.dart' show host, paragraph;

const _source =
    '''| Left heading<br>L | Center heading<br>C | Right heading<br>R |
| :--- | :---: | ---: |
| Left content that wraps onto several lines<br>l | Center content that wraps onto several lines<br>c | Right content that wraps onto several lines<br>r |''';

Rect _lastLine(RenderParagraph p) => p
    .getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: p.text.toPlainText().length),
    )
    .where((box) => box.right > box.left)
    .last
    .toRect()
    .shift(p.localToGlobal(Offset.zero));

void main() {
  for (final width in [390.0, 720.0]) {
    for (final streaming in [false, true]) {
      testWidgets(
        'wrapped table headings and cells align at $width streaming=$streaming',
        (tester) async {
          await tester.pumpWidget(
            host(
              MarkstreamView(source: _source, streaming: streaming),
              width: width,
              selectable: true,
            ),
          );
          await tester.pumpAndSettle();
          final table = tester.getRect(find.byType(Table));
          for (final row in ['heading', 'content']) {
            for (var col = 0; col < 3; col++) {
              final p = paragraph('${['Left', 'Center', 'Right'][col]} $row');
              final line = _lastLine(p);
              switch (col) {
                case 0:
                  expect(line.left, closeTo(table.left + 12, .1));
                case 1:
                  expect(line.center.dx, closeTo(table.center.dx, .1));
                case 2:
                  expect(line.right, closeTo(table.right - 12, .1));
              }
            }
          }
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }),
      );
    }
  }

  testWidgets(
    'natural wrapping and rich inline content preserve column alignment',
    (tester) async {
      const text =
          'A long description that wraps onto several lines in this cell.';
      await tester.pumpWidget(
        host(
          const MarkstreamView(
            source:
                '| Center | Right |\n| :---: | ---: |\n| $text | **$text** |\n| `code`<br>c | `code`<br>r |',
          ),
          width: 300,
          selectable: true,
        ),
      );
      await tester.pumpAndSettle();
      final table = tester.getRect(find.byType(Table));
      final prose = find
          .byType(RichText)
          .evaluate()
          .map((element) => element.renderObject)
          .whereType<RenderParagraph>()
          .where((p) => p.text.toPlainText() == text)
          .toList();
      expect(prose, hasLength(2));
      expect(
        _lastLine(prose[0]).center.dx,
        closeTo(table.left + table.width / 4, .1),
      );
      expect(_lastLine(prose[1]).right, closeTo(table.right - 12, .1));
      expect(
        _lastLine(paragraph('\uFFFC\nc')).center.dx,
        closeTo(table.left + table.width / 4, .1),
      );
      expect(
        _lastLine(paragraph('\uFFFC\nr')).right,
        closeTo(table.right - 12, .1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('HTML cell alignment applies to every line', (tester) async {
    await tester.pumpWidget(
      host(
        const MarkstreamView(
          source:
              '<table><tr><th align="center">Center heading<br>C</th><th align="right">Right heading<br>R</th></tr><tr><td align="center">Center content<br>c</td><td align="right">Right content<br>r</td></tr></table>',
        ),
        width: 300,
        selectable: true,
      ),
    );
    await tester.pumpAndSettle();
    final table = tester.getRect(find.byType(Table));
    for (final row in ['heading', 'content']) {
      expect(
        _lastLine(paragraph('Center $row')).center.dx,
        closeTo(table.left + table.width / 4, .1),
      );
      expect(
        _lastLine(paragraph('Right $row')).right,
        closeTo(table.right - 12, .1),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop actions stay below the table and never cover neighbors',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        host(
          const MarkstreamView(source: 'Before\n\n$_source\n\nAfter'),
          width: 390,
        ),
      );
      await tester.pumpAndSettle();
      final table = tester.getRect(find.byType(Table));
      final toolbar = find.byKey(const ValueKey('markstream-table-toolbar'));
      final footer = tester.getRect(toolbar);
      expect(
        table.top,
        closeTo(
          tester.getTopLeft(find.byType(MarkstreamTableBlock)).dy + 4,
          .1,
        ),
      );
      expect(footer.top, closeTo(table.bottom + 4, .1));
      expect(footer.height, 28);
      expect(
        paragraph(
          'Before',
        ).localToGlobal(Offset(0, paragraph('Before').size.height)).dy,
        lessThan(table.top),
      );
      expect(
        paragraph('After').localToGlobal(Offset.zero).dy,
        greaterThan(footer.bottom),
      );
      expect(find.text('Copy Markdown').hitTestable(), findsOneWidget);
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(790, 590));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(table.center);
      await tester.pumpAndSettle();
      expect(tester.getRect(toolbar), footer);
      expect(tester.getRect(find.byType(Table)), table);
      await tester.tap(find.text('Copy Markdown'));
      expect(copied, contains('| :--- | :---: | ---: |'));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets('desktop table actions remain directly keyboard accessible', (
    tester,
  ) async {
    await tester.pumpWidget(host(const MarkstreamView(source: _source)));
    await tester.pumpAndSettle();
    final table = tester.getRect(find.byType(Table));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      Focus.of(tester.element(find.text('Copy Markdown'))).hasFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('Copy CSV'))).hasFocus, isTrue);
    expect(tester.getRect(find.byType(Table)), table);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets(
    'focused actions scroll out with the table inside a local viewport',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      const viewportKey = ValueKey('table-test-viewport');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 200),
                SizedBox(
                  key: viewportKey,
                  width: 320,
                  height: 250,
                  child: SingleChildScrollView(
                    controller: controller,
                    child: const Column(
                      children: [
                        SizedBox(height: 100),
                        MarkstreamView(
                          source: '| A | B |\n| - | - |\n| x | y |',
                        ),
                        SizedBox(height: 500),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byKey(viewportKey));
      final toolbar = find.byKey(const ValueKey('markstream-table-toolbar'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('Copy Markdown').hitTestable(), findsOneWidget);
      controller.jumpTo(240);
      await tester.pumpAndSettle();
      expect(tester.getRect(toolbar).bottom, lessThan(viewport.top));
      expect(find.text('Copy Markdown').hitTestable(), findsNothing);
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Copy Markdown').hitTestable(), findsOneWidget);
      expect(
        tester.getRect(toolbar).overlaps(tester.getRect(find.byType(Table))),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'long tables keep their actions after the cells instead of over them',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final source =
          '| A | B |\n| - | - |\n${List.generate(40, (i) => '| row$i | value$i |').join('\n')}';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  MarkstreamView(source: source),
                  const SizedBox(height: 200),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final toolbar = find.byKey(const ValueKey('markstream-table-toolbar'));
      final table = tester.getRect(find.byType(Table));
      expect(table.bottom, greaterThan(600));
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(100, 100));
      addTearDown(mouse.removePointer);
      await tester.pumpAndSettle();
      expect(tester.getRect(toolbar).top, greaterThan(table.bottom));
      expect(find.text('Copy Markdown').hitTestable(), findsNothing);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('Copy Markdown').hitTestable(), findsOneWidget);
      expect(
        tester.getRect(toolbar).overlaps(tester.getRect(find.byType(Table))),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'desktop actions are excluded from export and available with accessibility',
    (tester) async {
      Future<void> pump({
        bool exporting = false,
        bool accessible = false,
      }) async {
        await tester.pumpWidget(
          host(
            MediaQuery(
              data: MediaQueryData(accessibleNavigation: accessible),
              child: MarkstreamView(source: _source, exporting: exporting),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      final toolbar = find.byKey(const ValueKey('markstream-table-toolbar'));
      await pump();
      final table = tester.getRect(find.byType(Table));
      expect(toolbar, findsOneWidget);
      await pump(exporting: true);
      expect(toolbar, findsNothing);
      expect(tester.getRect(find.byType(Table)), table);
      await pump(accessible: true);
      expect(find.text('Copy Markdown').hitTestable(), findsOneWidget);
      expect(tester.getRect(toolbar).top, greaterThan(table.bottom));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'desktop action row leaves backdrop pixels unchanged in $brightness',
      (tester) async {
        const background = Color(0xff753b5a);
        final key = GlobalKey();
        await tester.pumpWidget(
          host(
            RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: background,
                child: MarkstreamView(
                  source: '| A | B |\n| - | - |\n| x | y |',
                  theme: MarkstreamTheme.fromColorScheme(
                    ColorScheme.fromSeed(
                      seedColor: Colors.blue,
                      brightness: brightness,
                    ),
                    backdrop: MarkstreamBackdrop.wallpaper,
                    desktop: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final footer = tester.getRect(
          find.byKey(const ValueKey('markstream-table-toolbar')),
        );
        final sample = boundary.globalToLocal(
          Offset(footer.left + 8, footer.center.dy),
        );
        final image = boundary.toImageSync();
        final data = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        final offset =
            (sample.dy.floor() * image.width + sample.dx.floor()) * 4;
        final pixels = data!.buffer.asUint8List();
        expect(
          Color.fromARGB(
            pixels[offset + 3],
            pixels[offset],
            pixels[offset + 1],
            pixels[offset + 2],
          ),
          background,
        );
        image.dispose();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }
}
