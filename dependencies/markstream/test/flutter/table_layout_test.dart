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

  testWidgets('desktop floating toolbar is clickable without moving the table', (
    tester,
  ) async {
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
      host(const MarkstreamView(source: _source), width: 390),
    );
    await tester.pumpAndSettle();
    final table = tester.getRect(find.byType(Table));
    expect(table.top, 4);
    final toolbar = find.byKey(
      const ValueKey('markstream-table-hover-toolbar'),
    );
    expect(tester.widget<AnimatedOpacity>(toolbar).opacity, 0);
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(790, 590));
    addTearDown(mouse.removePointer);
    // The invisible overlay must not catch the pointer over neighboring prose.
    await mouse.moveTo(tester.getCenter(toolbar));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(toolbar).opacity, 0);
    await mouse.moveTo(table.center);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(toolbar).opacity, 1);
    expect(tester.getRect(find.byType(Table)), table);
    expect(tester.getRect(toolbar).overlaps(table), isFalse);
    await mouse.moveTo(tester.getCenter(find.text('Copy Markdown')));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(toolbar).opacity, 1);
    await tester.tap(find.text('Copy Markdown'));
    expect(copied, contains('| :--- | :---: | ---: |'));
    await mouse.moveTo(const Offset(790, 590));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(toolbar).opacity, 0);
    expect(tester.getRect(find.byType(Table)), table);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.desktop());

  testWidgets(
    'keyboard focus reveals desktop actions without reserving space',
    (tester) async {
      await tester.pumpWidget(
        host(const MarkstreamView(source: _source), width: 390),
      );
      await tester.pumpAndSettle();
      final table = tester.getRect(find.byType(Table));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(const ValueKey('markstream-table-hover-toolbar')),
            )
            .opacity,
        1,
      );
      expect(tester.getRect(find.byType(Table)), table);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        Focus.of(tester.element(find.text('Copy Markdown'))).hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('desktop toolbar follows scrolling and clears hover off screen', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: const Column(
              children: [
                SizedBox(height: 100),
                MarkstreamView(source: '| A | B |\n| - | - |\n| x | y |'),
                SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final toolbar = find.byKey(
      const ValueKey('markstream-table-hover-toolbar'),
    );
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(790, 590));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(Table)));
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(toolbar).dy,
      tester.getTopLeft(find.byType(Table)).dy,
    );
    controller.jumpTo(40);
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(toolbar).dy,
      tester.getTopLeft(find.byType(Table)).dy,
    );
    await mouse.moveTo(tester.getCenter(find.byType(Table)));
    await tester.pumpAndSettle();
    await mouse.moveTo(tester.getCenter(toolbar));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(toolbar).opacity, 1);
    controller.jumpTo(500);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(toolbar).opacity, 0);
    await mouse.moveTo(const Offset(790, 590));
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(toolbar).opacity, 0);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('desktop toolbar survives export and accessibility changes', (
    tester,
  ) async {
    Future<void> pump({bool exporting = false, bool accessible = false}) async {
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

    final toolbar = find.byKey(
      const ValueKey('markstream-table-hover-toolbar'),
    );
    await pump();
    expect(toolbar, findsOneWidget);
    await pump(exporting: true);
    expect(toolbar, findsNothing);
    await pump();
    expect(toolbar, findsOneWidget);
    await pump(accessible: true);
    expect(toolbar, findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(toolbar).opacity, 1);
    await pump();
    expect(toolbar, findsOneWidget);
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(790, 590));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(Table)));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(toolbar).opacity, 1);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('focused toolbar stays inside its local scroll viewport', (
    tester,
  ) async {
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
                      MarkstreamView(source: '| A | B |\n| - | - |\n| x | y |'),
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
    final toolbar = find.byKey(
      const ValueKey('markstream-table-hover-toolbar'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(toolbar).opacity, 1);
    controller.jumpTo(70);
    await tester.pumpAndSettle();
    final shown = tester.getRect(toolbar);
    expect(shown.top, greaterThanOrEqualTo(viewport.top));
    expect(shown.bottom, lessThanOrEqualTo(viewport.bottom));
    expect(shown.overlaps(tester.getRect(find.byType(Table))), isFalse);
    controller.jumpTo(220);
    await tester.pumpAndSettle();
    final table = tester.getRect(find.byType(Table));
    expect(table.bottom, lessThan(viewport.top));
    expect(table.bottom, greaterThan(0));
    expect(tester.widget<AnimatedOpacity>(toolbar).opacity, 0);
    expect(find.text('Copy Markdown').hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets(
    'long table toolbar never covers cells when no outside space is available',
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
      final toolbar = find.byKey(
        const ValueKey('markstream-table-hover-toolbar'),
      );
      expect(tester.getRect(find.byType(Table)).bottom, greaterThan(600));
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(790, 590));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(const Offset(100, 100));
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedOpacity>(toolbar).opacity, 0);
      expect(find.text('Copy Markdown').hitTestable(), findsNothing);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedOpacity>(toolbar).opacity, 1);
      expect(
        tester.getRect(toolbar).overlaps(tester.getRect(find.byType(Table))),
        isFalse,
      );
      expect(find.text('Copy Markdown').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'accessible navigation reveals floating actions without reserving space',
    (tester) async {
      await tester.pumpWidget(
        host(
          MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: const MarkstreamView(source: _source),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final table = tester.getRect(find.byType(Table));
      final block = tester.getRect(find.byType(MarkstreamTableBlock));
      expect(table.top, 4);
      expect(block.height, closeTo(table.height + 8, .01));
      final toolbar = find.byKey(
        const ValueKey('markstream-table-hover-toolbar'),
      );
      expect(tester.widget<AnimatedOpacity>(toolbar).opacity, 1);
      expect(find.text('Copy Markdown').hitTestable(), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'transparent hover strip paints only buttons and passes clear-area taps in $brightness',
      (tester) async {
        const background = Color(0xff753b5a);
        final key = GlobalKey();
        var taps = 0;
        var pointerDowns = 0;
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.blue,
                  brightness: brightness,
                ),
              ),
              home: Scaffold(
                backgroundColor: background,
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 390,
                    child: Column(
                      children: [
                        const SizedBox(height: 72),
                        Listener(
                          onPointerDown: (_) => pointerDowns++,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => taps++,
                            child: const SizedBox(
                              height: 28,
                              width: 390,
                              child: Text('Underlying text remains visible'),
                            ),
                          ),
                        ),
                        MarkstreamView(
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final before = boundary.toImageSync();
        final beforeData = await tester.runAsync(
          () => before.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        final table = tester.getRect(find.byType(Table));
        final block = tester.getRect(find.byType(MarkstreamTableBlock));
        expect(block.height, closeTo(table.height + 8, .01));
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: const Offset(790, 590));
        addTearDown(mouse.removePointer);
        await mouse.moveTo(table.center);
        await tester.pumpAndSettle();
        final toolbar = find.byKey(
          const ValueKey('markstream-table-hover-toolbar'),
        );
        expect(tester.widget<AnimatedOpacity>(toolbar).opacity, 1);
        final buttons = tester.getRect(toolbar);
        expect(buttons.width, lessThan(table.width));
        expect(buttons.height, closeTo(28, .01));
        expect(buttons.right, closeTo(table.right, .01));
        expect(buttons.bottom, closeTo(table.top, .01));
        expect(tester.getRect(find.byType(Table)), table);
        expect(tester.getRect(find.byType(MarkstreamTableBlock)), block);
        final after = boundary.toImageSync();
        final afterData = await tester.runAsync(
          () => after.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        final beforePixels = beforeData!.buffer.asUint8List();
        final afterPixels = afterData!.buffer.asUint8List();
        for (var y = buttons.top.ceil(); y < buttons.bottom.floor(); y++) {
          final start = (y * after.width + table.left.ceil()) * 4;
          final end = (y * after.width + buttons.left.floor() - 2) * 4;
          expect(
            afterPixels.sublist(start, end),
            beforePixels.sublist(start, end),
            reason:
                'Transparent strip must preserve the text/background behind it at y=$y.',
          );
        }
        before.dispose();
        after.dispose();
        await mouse.moveTo(Offset(table.left + 8, buttons.center.dy));
        await tester.pumpAndSettle();
        expect(tester.widget<AnimatedOpacity>(toolbar).opacity, 1);
        await tester.tapAt(Offset(table.left + 8, buttons.center.dy));
        expect(taps, 1, reason: 'Only actual buttons may intercept clicks.');
        expect(pointerDowns, 1);
        final press = await tester.startGesture(
          tester.getCenter(find.text('Copy Markdown')),
        );
        final receivedPointerDowns = pointerDowns;
        await press.cancel();
        expect(
          receivedPointerDowns,
          1,
          reason: 'Button presses must not reach underlying listeners.',
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }
}
