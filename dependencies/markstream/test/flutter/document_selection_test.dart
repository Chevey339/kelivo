import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

import 'markstream_view_test.dart' show host, paragraph, edge;
import 'rich_blocks_test.dart' show selectAll, tableSource;

Future<void> drag(
  WidgetTester tester,
  String from,
  int start,
  String to,
  int end,
) async {
  final gesture = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
  await gesture.addPointer();
  await gesture.down(edge(paragraph(from), start));
  await gesture.moveTo(edge(paragraph(to), end - 1, end: true));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'selection availability follows clear, disable and text replacement',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      });
      Future<void> pump(bool enabled, String source) async {
        final view = MarkstreamView(
          source: source,
          selectionController: controller,
        );
        await tester.pumpWidget(
          host(
            enabled ? view : SelectionContainer.disabled(child: view),
            selectable: true,
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(true, 'First **bold** 😀');
      expect(controller.hasSelection, isFalse);
      selectAll(tester);
      await tester.pumpAndSettle();
      expect(controller.hasSelection, isTrue);
      expect(controller.selectedPlainText, 'First bold 😀');
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .clearSelection();
      await tester.pumpAndSettle();
      expect(controller.hasSelection, isFalse);
      selectAll(tester);
      await tester.pumpAndSettle();
      await pump(false, 'First **bold** 😀');
      expect(controller.hasSelection, isFalse);
      await pump(true, 'Replacement');
      selectAll(tester);
      await tester.pumpAndSettle();
      expect(controller.hasSelection, isTrue);
      expect(controller.selectedMarkdown, 'Replacement');
      await pump(true, '');
      expect(controller.hasSelection, isFalse);
      expect(controller.selectedMarkdown, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'HTML folds in containers and cells expose only visible selection',
    (tester) async {
      for (final source in [
        '<div><p>Before</p><details><summary>Summary</summary>SECRET</details><p>After</p></div>',
        '| H |\n| --- |\n| <details><summary>Summary</summary>SECRET</details> |',
      ]) {
        final controller = MarkstreamSelectionController();
        await tester.pumpWidget(
          host(
            MarkstreamView(source: source, selectionController: controller),
            selectable: true,
          ),
        );
        await tester.pumpAndSettle();
        selectAll(tester);
        await tester.pumpAndSettle();
        expect(controller.selectedPlainText, contains('Summary'));
        expect(controller.selectedMarkdown, isNot(contains('SECRET')));
        await tester.tap(find.text('Summary'));
        await tester.pumpAndSettle();
        selectAll(tester);
        await tester.pumpAndSettle();
        expect(controller.selectedPlainText, contains('SECRET'));
        expect(controller.selectedMarkdown, contains('SECRET'));
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    },
  );
  testWidgets('document copy includes paragraphs and list markers', (
    tester,
  ) async {
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    String? native;
    const source =
        '# Title\n\nFirst **bold** and [site](https://example.com).\n\n- [x] Done\n- Todo\n\n> Quote\n\n```dart\n  code\n```';
    await tester.pumpWidget(
      host(
        MarkstreamView(source: source, selectionController: controller),
        selectable: true,
        onSelection: (value) => native = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    selectAll(tester);
    await tester.pumpAndSettle();
    expect(
      native,
      'Title\n\nFirst bold and site.\n\n- [x] Done\n- Todo\n\nQuote\n\n  code',
    );
    expect(controller.selectedPlainText, native);
    expect(
      controller.selectedMarkdown,
      toMarkdown(MarkdownParser().parse(source)),
    );
    expect(controller.hasSelection, isTrue);
    expect(find.byType(SelectableRegion), findsOneWidget);
  });
  testWidgets('partial selection retains emphasis and link destinations', (
    tester,
  ) async {
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        MarkstreamView(
          source: 'Start **bold words** [link label](https://example.com) end',
          selectionController: controller,
        ),
        selectable: true,
      ),
    );
    await tester.pumpAndSettle();
    await drag(tester, 'Start', 8, 'Start', 24);
    expect(controller.selectedPlainText, 'ld words link la');
    expect(
      controller.selectedMarkdown,
      '**ld words** [link la](<https://example.com>)',
    );
    expect(controller.selections.single.sourceRanges.first.start, 10);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  testWidgets('folded content and paginated rows never leak into Markdown', (
    tester,
  ) async {
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    final source =
        'Before\n\n<details>\n<summary>Summary</summary>\n\nSECRET\n\n</details>\n\n```dart\none\ntwo\nHIDDEN\n```\n\n${tableSource(45)}\n\nAfter';
    await tester.pumpWidget(
      host(
        MarkstreamView(
          source: source,
          selectionController: controller,
          codeOptions: const CodeBlockOptions(
            autoCollapse: true,
            collapsedLines: 2,
          ),
        ),
        selectable: true,
      ),
    );
    await tester.pumpAndSettle();
    selectAll(tester);
    await tester.pumpAndSettle();
    final markdown = controller.selectedMarkdown;
    expect(markdown, contains('<summary>Summary</summary>'));
    expect(markdown, isNot(contains('SECRET')));
    expect(markdown, isNot(contains('HIDDEN')));
    expect(markdown, contains('```dart\none\ntwo\n```'));
    expect(markdown, contains('row38'));
    expect(markdown, isNot(contains('row39')));
    expect(markdown, endsWith('After'));
  });
  testWidgets(
    'partial table selection uses empty cells instead of unselected data',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: '| Left | Right |\n| - | - |\n| AAA | BBB |\n| CCC | DDD |',
            selectionController: controller,
          ),
          selectable: true,
        ),
      );
      await tester.pumpAndSettle();
      await drag(tester, 'BBB', 1, 'CCC', 2);
      final markdown = controller.selectedMarkdown;
      expect(markdown, contains('BB'));
      expect(markdown, contains('CC'));
      expect(markdown, isNot(contains('AAA')));
      expect(markdown, isNot(contains('DDD')));
      expect(markdown, isNot(contains('Left')));
      expect(markdown, contains('|  | BB |'));
      expect(markdown, contains('| CC |  |'));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
  testWidgets('partial ordered lists preserve their original starting number', (
    tester,
  ) async {
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        MarkstreamView(
          source: '3. Three\n4. Four\n5. Five',
          selectionController: controller,
        ),
        selectable: true,
      ),
    );
    await tester.pumpAndSettle();
    await drag(tester, 'Four', 0, 'Five', 4);
    expect(controller.selectedMarkdown, '4. Four\n5. Five');
    expect(controller.selectedPlainText, '4. Four\n5. Five');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  testWidgets(
    'atomic projections preserve math, images and custom inline syntax',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      final extensions = MarkstreamExtensions(
        namedInlineBuilders: {
          'badge': (context, node, rendering) => RenderedInline(
            span: WidgetSpan(
              child: SelectableSpanAdapter(
                selectedText: '[3]',
                child: const Text('3'),
              ),
            ),
            segments: [
              TextSegment(text: '[3]', sourceSpan: node.span, node: node),
            ],
          ),
        },
      );
      const source =
          'Before :badge[reference] \$x^2\$ ![alt](image.png) after\n\n\$\$\ny^2\n\$\$';
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: source,
            selectionController: controller,
            extensions: extensions,
          ),
          selectable: true,
        ),
      );
      await tester.pumpAndSettle();
      selectAll(tester);
      await tester.pumpAndSettle();
      expect(controller.selectedPlainText, contains('[3]'));
      expect(
        controller.selectedMarkdown,
        toMarkdown(MarkdownParser().parse(source)),
      );
    },
  );
  testWidgets(
    'zero-length rules and images are retained only inside selected visible ranges',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      const source =
          'Before\n\n---\n\n![](image.png)\n\n<details>\n<summary>Hidden</summary>\n\n---\n\n</details>\n\nAfter';
      await tester.pumpWidget(
        host(
          MarkstreamView(source: source, selectionController: controller),
          selectable: true,
        ),
      );
      await tester.pumpAndSettle();
      selectAll(tester);
      await tester.pumpAndSettle();
      expect('---'.allMatches(controller.selectedMarkdown), hasLength(1));
      expect(controller.selectedMarkdown, contains('![](<image.png>)'));
    },
  );
  testWidgets('full HTML code and virtualized code map their actual source', (
    tester,
  ) async {
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    final code = List.generate(1100, (i) => 'line$i').join('\n');
    for (final source in [
      '<!DOCTYPE html>\n<html><body>page</body></html>',
      '```dart\n$code\n```',
    ]) {
      await tester.pumpWidget(
        host(
          MarkstreamView(source: source, selectionController: controller),
          selectable: true,
        ),
      );
      await tester.pumpAndSettle();
      selectAll(tester);
      await tester.pumpAndSettle();
      expect(
        controller.selectedMarkdown,
        toMarkdown(MarkdownParser().parse(source)),
      );
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'copy command uses the shared scope and stops after views unmount',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      String? clipboard;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData')
              clipboard = (call.arguments as Map)['text'] as String;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        host(
          MarkstreamSelectionScope(
            controller: controller,
            child: const Column(
              children: [
                MarkstreamView(source: '**First**'),
                MarkstreamView(source: '_Second_'),
              ],
            ),
          ),
          selectable: true,
        ),
      );
      await tester.pumpAndSettle();
      selectAll(tester);
      await tester.pumpAndSettle();
      await controller.copySelectionAsMarkdown();
      expect(clipboard, '**First**\n\n_Second_');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(controller.hasSelection, isFalse);
      expect(controller.selectedMarkdown, isEmpty);
    },
  );
  testWidgets(
    'forest boundaries preserve one paragraph separator and no visual line breaks',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      final paragraphs = List.generate(
        35,
        (i) =>
            'Paragraph $i ${List.filled(i == 17 ? 700 : 2, 'word').join(' ')}',
      );
      final source = paragraphs.join('\n\n');
      await tester.pumpWidget(
        host(
          MarkstreamView(source: source, selectionController: controller),
          selectable: true,
        ),
      );
      await tester.pumpAndSettle();
      selectAll(tester);
      await tester.pumpAndSettle();
      expect(controller.selectedPlainText, source);
      expect(
        controller.selectedMarkdown,
        toMarkdown(MarkdownParser().parse(source)),
      );
    },
  );
  testWidgets(
    'shared controller follows visual order after keyed view reordering',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      Future<void> pump(List<String> order) async {
        await tester.pumpWidget(
          host(
            MarkstreamSelectionScope(
              controller: controller,
              child: Column(
                children: [
                  for (final label in order)
                    MarkstreamView(key: ValueKey(label), source: '**$label**'),
                ],
              ),
            ),
            selectable: true,
          ),
        );
        await tester.pumpAndSettle();
        selectAll(tester);
        await tester.pumpAndSettle();
      }

      await pump(['First', 'Second']);
      expect(controller.selectedMarkdown, '**First**\n\n**Second**');
      await pump(['Second', 'First']);
      expect(controller.selectedMarkdown, '**Second**\n\n**First**');
      expect(controller.selections.first.document.source, '**Second**');
    },
  );
  testWidgets(
    'mobile long press and handle selection preserve inline Markdown',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: 'Before `code` middle **After**',
            selectionController: controller,
          ),
          selectable: true,
        ),
      );
      await tester.pumpAndSettle();
      final p = paragraph('Before');
      await tester.longPressAt(edge(p, 2));
      await tester.pumpAndSettle();
      expect(controller.selectedMarkdown, 'Before');
      final overlay = tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .selectionOverlay!;
      final controls = overlay.selectionControls!;
      final size = controls.getHandleSize(overlay.lineHeightAtEnd);
      final center =
          Offset(size.width / 2, size.height / 2) -
          controls.getHandleAnchor(
            overlay.endHandleType,
            overlay.lineHeightAtEnd,
          );
      final gesture = await tester.startGesture(
        overlay.endHandleLayerLink.leader!.offset + center,
      );
      final last = p.text.toPlainText().length - 1;
      final target = p
          .getBoxesForSelection(
            TextSelection(baseOffset: last, extentOffset: last + 1),
          )
          .single;
      final leading =
          (overlay.lineHeightAtEnd - (target.bottom - target.top)) / 2;
      await gesture.moveTo(
        p.localToGlobal(Offset(target.right, target.bottom + leading)) + center,
      );
      await tester.pump();
      await gesture.up();
      await gesture.removePointer();
      await tester.pumpAndSettle();
      expect(controller.selectedMarkdown, 'Before `code` middle **After**');
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'RTL inline atoms map source order under a selection controller',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(
          Directionality(
            textDirection: TextDirection.rtl,
            child: MarkstreamView(
              source: '- אבג `x` **דהו**',
              selectionController: controller,
            ),
          ),
          selectable: true,
        ),
      );
      await tester.pumpAndSettle();
      selectAll(tester);
      await tester.pumpAndSettle();
      expect(controller.selectedMarkdown, '- אבג `x` **דהו**');
      expect(controller.selectedPlainText, '- אבג x דהו');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unregistered extension partial labels cannot copy unselected source',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      final document = DocumentNode(
        source: '@{abcdef}',
        children: [
          ParagraphNode(
            span: const SourceSpan(0, 9),
            children: [
              NamedInlineNode(
                span: const SourceSpan(0, 9),
                name: 'custom',
                syntax: NamedInlineSyntax.extension,
                children: [
                  const TextNode(span: SourceSpan(2, 8), text: 'abcdef'),
                ],
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        host(
          MarkstreamView(document: document, selectionController: controller),
          selectable: true,
        ),
      );
      await tester.pumpAndSettle();
      await drag(tester, 'abcdef', 2, 'abcdef', 4);
      expect(controller.selectedMarkdown, 'cd');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
  testWidgets('complete table copy retains empty edge cells and empty rows', (
    tester,
  ) async {
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    const source =
        '| | Head | |\n| - | - | - |\n| | | |\n| | Value | |\n| | | |';
    await tester.pumpWidget(
      host(
        MarkstreamView(source: source, selectionController: controller),
        selectable: true,
      ),
    );
    await tester.pumpAndSettle();
    selectAll(tester);
    await tester.pumpAndSettle();
    expect(
      controller.selectedMarkdown,
      toMarkdown(MarkdownParser().parse(source)),
    );
    expect(controller.selectedPlainText, '\tHead\t\n\t\t\n\tValue\t\n\t\t');
  });
  testWidgets(
    'selection remains valid through streamed tail replacement and truncation',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      Future<void> pump(String source) async {
        await tester.pumpWidget(
          host(
            MarkstreamView(
              source: source,
              selectionController: controller,
              streaming: true,
            ),
            selectable: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(() => controller.selectedMarkdown, returnsNormally);
        expect(tester.takeException(), isNull);
      }

      await pump('Stable **prefix**\n\nTail');
      selectAll(tester);
      await tester.pumpAndSettle();
      for (final tail in [
        'Tail append',
        'Tail `code',
        'Tail `code` done',
        '| A | B |\n| - | - |\n| a | b |',
        '[link](https://example.com)',
      ]) {
        await pump('Stable **prefix**\n\n$tail');
        selectAll(tester);
        await tester.pumpAndSettle();
        expect(controller.selectedMarkdown, contains('Stable **prefix**'));
      }
      await pump('Short');
      selectAll(tester);
      await tester.pumpAndSettle();
      expect(controller.selectedMarkdown, 'Short');
    },
  );
}
