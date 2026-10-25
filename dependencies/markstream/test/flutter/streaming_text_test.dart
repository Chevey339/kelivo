import 'dart:io';
import 'dart:ui' as ui;

import 'package:markstream/markstream.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'long styled chunks preserve speech locale without repeating its range',
    (tester) async {
      final spans = List.generate(
        320,
        (i) => TextSpan(
          text: 'fragment $i 中文 ',
          style: TextStyle(
            fontWeight: i.isEven ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 320,
                child: StreamingText(
                  cullToViewport: false,
                  text: Text.rich(
                    TextSpan(children: spans),
                    locale: const Locale('zh', 'CN'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final paragraphs = tester
          .renderObjectList<RenderParagraph>(find.byType(RichText))
          .toList();
      expect(paragraphs.length, greaterThan(1));
      for (final paragraph in paragraphs) {
        final information = paragraph.text.getSemanticsInformation();
        expect(information, hasLength(1));
        final info = information.single;
        expect(info.text, paragraph.text.toPlainText());
        final attributes = info.stringAttributes
            .whereType<ui.LocaleStringAttribute>();
        expect(attributes, hasLength(1));
        expect(attributes.single.locale, const Locale('zh', 'CN'));
        expect(
          attributes.single.range,
          TextRange(start: 0, end: info.text.length),
        );
        final spelled = <InlineSpanSemanticsInformation>[];
        (paragraph.text as TextSpan).computeSemanticsInformation(
          spelled,
          inheritedSpellOut: true,
        );
        final spelling = spelled.single.stringAttributes
            .whereType<ui.SpellOutStringAttribute>();
        expect(spelling, hasLength(1));
        expect(
          spelling.single.range,
          TextRange(start: 0, end: info.text.length),
        );
      }
      expect(
        paragraphs.map((p) => p.text.toPlainText()).join(),
        spans.map((s) => s.text).join(),
      );
    },
  );

  testWidgets(
    'explicit inline speech languages keep their original attributes',
    (tester) async {
      final text = Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'English ' * 100, locale: const Locale('en')),
            TextSpan(text: '日本語 ' * 100, locale: const Locale('ja')),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: StreamingText(text: text)),
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText).first,
      );
      final languages = paragraph.text
          .getSemanticsInformation()
          .expand((info) => info.stringAttributes)
          .whereType<ui.LocaleStringAttribute>()
          .map((attribute) => attribute.locale)
          .toList();
      expect(languages, [const Locale('en'), const Locale('ja')]);
      expect(paragraph.text.toPlainText(), text.textSpan!.toPlainText());
    },
  );

  testWidgets('completed medium paragraphs keep native text geometry', (
    tester,
  ) async {
    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '中文 English paragraph ' * 25),
          TextSpan(
            text: 'bold 中文 ' * 40,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: '尾部 text ' * 40),
        ],
      ),
      style: const TextStyle(fontSize: 16, height: 1.5),
    );
    Future<(Size, List<Rect>)> measure(bool optimized) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 300,
                child: optimized
                    ? StreamingText(text: text, streaming: false)
                    : text,
              ),
            ),
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText).first,
      );
      return (
        paragraph.size,
        paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 20, extentOffset: 1200),
            )
            .map((box) => box.toRect())
            .toList(),
      );
    }

    final before = await measure(false);
    final after = await measure(true);
    expect(after.$1, before.$1);
    expect(after.$2, before.$2);
  });

  testWidgets('ancestor repaint reuses the unchanged paragraph drawing', (
    tester,
  ) async {
    final background = ValueNotifier(Colors.white);
    var paints = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<Color>(
          valueListenable: background,
          builder: (_, color, child) => ColoredBox(color: color, child: child),
          child: StreamingText(
            text: _PaintObservedText('中文 paragraph', onPaint: () => paints++),
          ),
        ),
      ),
    );
    expect(paints, greaterThan(0));
    paints = 0;
    background.value = Colors.blue;
    await tester.pump();
    expect(paints, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    background.dispose();
  });
  const visualFont = String.fromEnvironment('KELIVO_VISUAL_FONT');
  const emojiFont = String.fromEnvironment('KELIVO_VISUAL_EMOJI_FONT');
  setUpAll(() async {
    if (visualFont.isNotEmpty) {
      final loader = FontLoader('VisualFont');
      loader.addFont(
        File(visualFont)
            .readAsBytes()
            .then((data) => ByteData.sublistView(data)),
      );
      await loader.load();
    }
    if (emojiFont.isNotEmpty) {
      final loader = FontLoader('VisualEmoji');
      loader.addFont(File(emojiFont).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  testWidgets(
    'restoring an older span does not reuse a different text prefix',
    (tester) async {
      final first = TextSpan(text: 'original 中文 words ' * 300);
      final extended = TextSpan(text: '${first.text} appended');
      final replacement = TextSpan(
        text: 'different prefix ${first.text} appended',
      );
      final source = ValueNotifier(first);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder<TextSpan>(
                valueListenable: source,
                builder: (_, span, _) => StreamingText(text: Text.rich(span)),
              ),
            ),
          ),
        ),
      );
      for (final span in [extended, replacement, extended]) {
        source.value = span;
        await tester.pump();
        final rendered = tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.textSpan?.toPlainText() ?? text.data ?? '')
            .join();
        expect(rendered, span.toPlainText());
      }
      await tester.pumpWidget(const SizedBox.shrink());
      source.dispose();
    },
  );
  testWidgets('short and contextual text keep incoming tight constraints', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      for (final align in [
        TextAlign.start,
        TextAlign.center,
        TextAlign.right,
      ]) {
        Future<(Size, Rect)> measure(bool optimized) async {
          final text = Text(
            'Short 中文',
            textDirection: direction,
            textAlign: align,
            style: const TextStyle(fontSize: 16),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 300,
                  height: 120,
                  child: optimized ? StreamingText(text: text) : text,
                ),
              ),
            ),
          );
          final paragraph = tester.renderObject<RenderParagraph>(
            find.byType(RichText).first,
          );
          final rect = paragraph
              .getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 5),
              )
              .first
              .toRect()
              .shift(paragraph.localToGlobal(Offset.zero));
          return (paragraph.size, rect);
        }

        final before = await measure(false);
        expect(await measure(true), before);
      }
    }
  });
  testWidgets('copy includes every visual chunk without added line breaks', (
    tester,
  ) async {
    final source = ValueNotifier(
      List.generate(200, (i) => 'Line $i 中文 content for selection.').join('\n'),
    );
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            onSelectionChanged: (value) => selected = value?.plainText,
            child: SingleChildScrollView(
              child: SizedBox(
                width: 300,
                child: ValueListenableBuilder<String>(
                  valueListenable: source,
                  builder: (_, text, _) => StreamingText(
                    text: Text(
                      text,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pumpAndSettle();
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      expect(selected, source.value);
      region.clearSelection();
      source.value += '\nMore content 😀 ' * 20;
    }
    await tester.pumpWidget(const SizedBox.shrink());
    source.dispose();
  });
  for (final selectable in [false, true]) {
    for (final dark in [false, true]) {
      for (final hardBreaks in [false, true]) {
        testWidgets(
          'rich text preserves pixels dark=$dark breaks=$hardBreaks selectable=$selectable',
          (tester) async {
            final spans = <InlineSpan>[
              for (var i = 0; i < 100; i++) ...[
                TextSpan(text: '段落 $i English words 😀 继续思考。'),
                const TextSpan(
                  text: '粗体 bold',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                  text: ' italic 内容',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                TextSpan(text: hardBreaks ? '\n' : ' '),
              ],
            ];
            final text = Text.rich(
              TextSpan(children: spans),
              style: TextStyle(
                fontFamily: visualFont.isEmpty ? null : 'VisualFont',
                fontFamilyFallback: emojiFont.isEmpty ? null : ['VisualEmoji'],
                fontSize: selectable ? 13 : 15.5,
                height: selectable ? 1.5 : 1.55,
                color: dark ? Colors.white : Colors.black,
              ),
            );
            final boundaryKey = GlobalKey();
            final contentKey = GlobalKey();
            final scroll = ScrollController();
            Future<void> show(bool optimized) async {
              Widget rendered = KeyedSubtree(
                key: contentKey,
                child: optimized
                    ? selectable
                          ? Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: StreamingText(text: text),
                            )
                          : StreamingText(text: text)
                    : selectable
                    ? SelectableText.rich(
                        text.textSpan! as TextSpan,
                        style: text.style,
                      )
                    : text,
              );
              if (selectable && hardBreaks) {
                rendered = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: rendered,
                );
              }
              await tester.pumpWidget(
                MaterialApp(
                  theme: dark ? ThemeData.dark() : ThemeData.light(),
                  home: Scaffold(
                    body: Center(
                      child: SizedBox(
                        width: 360,
                        height: 500,
                        child: RepaintBoundary(
                          key: boundaryKey,
                          child: ColoredBox(
                            color: dark ? Colors.black : Colors.white,
                            child: SingleChildScrollView(
                              controller: scroll,
                              child: rendered,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
            }

            Future<List<int>> pixels(String name) async {
              final image = await tester.runAsync(
                () =>
                    (boundaryKey.currentContext!.findRenderObject()!
                            as RenderRepaintBoundary)
                        .toImage(),
              );
              final raw = (await tester.runAsync(
                () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
              ))!;
              final png = (await tester.runAsync(
                () => image!.toByteData(format: ui.ImageByteFormat.png),
              ))!;
              await tester.runAsync(() async {
                final file = File('build/long-streaming-visual/$name.png');
                await file.parent.create(recursive: true);
                await file.writeAsBytes(png.buffer.asUint8List());
              });
              image!.dispose();
              return raw.buffer.asUint8List();
            }

            await show(false);
            final originalHeight = tester
                .getSize(find.byKey(contentKey))
                .height;
            scroll.jumpTo(480.0.clamp(0.0, scroll.position.maxScrollExtent));
            await tester.pump();
            final before = await pixels(
              '${selectable ? 'selectable' : 'rich'}-before-$dark-$hardBreaks',
            );
            await show(true);
            expect(
              tester.getSize(find.byKey(contentKey)).height,
              closeTo(originalHeight, .01),
            );
            final after = await pixels(
              '${selectable ? 'selectable' : 'rich'}-after-$dark-$hardBreaks',
            );
            var different = 0;
            for (var i = 0; i < before.length; i++) {
              if ((before[i] - after[i]).abs() > 2) different++;
            }
            expect(
              different,
              0,
              reason: 'Changed raster channels: $different / ${before.length}',
            );
            await tester.pumpWidget(const SizedBox.shrink());
            scroll.dispose();
          },
        );
      }
    }
  }
}

class _PaintObservedText extends Text {
  const _PaintObservedText(super.data, {required this.onPaint});
  final VoidCallback onPaint;

  @override
  Widget build(BuildContext context) =>
      _PaintObserver(onPaint: onPaint, child: super.build(context));
}

class _PaintObserver extends SingleChildRenderObjectWidget {
  const _PaintObserver({required this.onPaint, required super.child});
  final VoidCallback onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaintObserver(onPaint);
}

class _RenderPaintObserver extends RenderProxyBox {
  _RenderPaintObserver(this.onPaint);
  final VoidCallback onPaint;

  @override
  void paint(PaintingContext context, Offset offset) {
    onPaint();
    super.paint(context, offset);
  }
}
