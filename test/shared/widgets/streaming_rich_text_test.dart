import 'dart:io';
import 'dart:ui' as ui;

import 'package:Kelivo/shared/widgets/streaming_rich_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const visualFont = String.fromEnvironment('KELIVO_VISUAL_FONT');
  const emojiFont = String.fromEnvironment('KELIVO_VISUAL_EMOJI_FONT');
  setUpAll(() async {
    if (visualFont.isNotEmpty) {
      final loader = FontLoader('VisualFont');
      loader.addFont(
        File(
          visualFont,
        ).readAsBytes().then((data) => ByteData.sublistView(data)),
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
                builder: (_, span, _) =>
                    StreamingRichText(text: Text.rich(span)),
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
                  child: optimized ? StreamingRichText(text: text) : text,
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
                  builder: (_, text, _) => StreamingRichText(
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
                              child: StreamingRichText(text: text),
                            )
                          : StreamingRichText(text: text)
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
            scroll.jumpTo(480);
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
