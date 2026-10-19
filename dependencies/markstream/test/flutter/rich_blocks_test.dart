import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

import 'markstream_view_test.dart' show host, paragraph, paragraphs, edge;

class _Highlighter implements CodeHighlighter {
  final requests = <(String, Completer<TextSpan>)>[];
  @override
  Future<TextSpan> highlight(
    String source, {
    required String language,
    required TextStyle style,
    required Brightness brightness,
  }) {
    final done = Completer<TextSpan>();
    requests.add((source, done));
    return done.future;
  }
}

class _DisplayMath implements MathRenderer {
  bool? display;
  @override
  Widget build(
    BuildContext context,
    String tex, {
    required TextStyle style,
    required bool displayMode,
  }) {
    display = displayMode;
    return const SizedBox(
      width: 1200,
      height: 50,
      child: ColoredBox(color: Colors.blue),
    );
  }
}

String tableSource(int rows) =>
    '| Name | Value |\n| :--- | ---: |\n${List.generate(rows, (i) => '| row$i | value$i |').join('\n')}';
void selectAll(WidgetTester tester) => tester
    .state<SelectableRegionState>(find.byType(SelectableRegion))
    .selectAll(SelectionChangedCause.keyboard);
void main() {
  for (final brightness in Brightness.values) {
    testWidgets('collapsed code preserves translucent $brightness backdrop', (
      tester,
    ) async {
      final base = MarkstreamTheme.fromColorScheme(
        ColorScheme.fromSeed(seedColor: Colors.blue, brightness: brightness),
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        host(
          RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: brightness == Brightness.light
                  ? Colors.orange
                  : Colors.indigo,
              child: MarkstreamView(
                source: '```text\nMMMM\nMMMM\nMMMM\nMMMM\n```',
                theme: base.copyWith(
                  code: base.code.copyWith(
                    backgroundColor: base.code.backgroundColor.withValues(
                      alpha: .3,
                    ),
                  ),
                ),
                codeOptions: const CodeBlockOptions(
                  autoCollapse: true,
                  collapsedLines: 3,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bounds = tester.getRect(find.byType(MarkstreamCodeContent));
      final origin = tester.getTopLeft(find.byKey(key));
      final local = bounds.shift(-origin);
      Future<(ByteData, int)> pixels() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = boundary.toImageSync();
        try {
          final bytes = await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
          );
          return (bytes!, image.width);
        } finally {
          image.dispose();
        }
      }

      final (collapsed, width) = await pixels();
      await tester.tap(find.byKey(const ValueKey('markstream-code-toggle')));
      await tester.pumpAndSettle();
      final (expanded, expandedWidth) = await pixels();
      expect(expandedWidth, width);
      var fadedTextDifference = 0;
      for (
        var y = (local.bottom - base.code.fadeHeight).ceil();
        y < local.bottom.floor();
        y++
      ) {
        final blank = (y * width + local.right.floor() - 4) * 4;
        for (var channel = 0; channel < 4; channel++) {
          expect(
            collapsed.getUint8(blank + channel),
            expanded.getUint8(blank + channel),
          );
        }
        for (var x = local.left.ceil(); x < local.left + 50; x++) {
          final pixel = (y * width + x) * 4;
          for (var channel = 0; channel < 3; channel++) {
            fadedTextDifference +=
                (collapsed.getUint8(pixel + channel) -
                        expanded.getUint8(pixel + channel))
                    .abs();
          }
        }
      }
      expect(fadedTextDifference, greaterThan(100));
      expect(
        find.byKey(const ValueKey('markstream-code-collapse-fade')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('desktop code wraps even when mobile wrapping is disabled', (
    tester,
  ) async {
    final code = List.filled(30, 'longword').join(' ');
    await tester.pumpWidget(
      host(MarkstreamView(source: '```text\n$code\n```'), width: 180),
    );
    await tester.pumpAndSettle();
    expect(paragraph('longword').size.width, lessThan(180));
    expect(
      find.descendant(
        of: find.byType(MarkstreamCodeContent),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('async highlighter cannot replace newer source or corrupt text', (
    tester,
  ) async {
    final highlighter = _Highlighter();
    Widget view(String source) => host(
      MarkstreamView(
        source: '```dart\n$source\n```',
        codeHighlighter: highlighter,
      ),
    );
    await tester.pumpWidget(view('old'));
    await tester.pumpWidget(view('new'));
    highlighter.requests.first.$2.complete(
      const TextSpan(
        text: 'old',
        style: TextStyle(color: Colors.red),
      ),
    );
    await tester.pump();
    expect(paragraph('new').text.toPlainText(), 'new');
    highlighter.requests.last.$2.complete(const TextSpan(text: 'CORRUPTED'));
    await tester.pump();
    expect(paragraph('new').text.toPlainText(), 'new');
    await tester.pumpWidget(view('latest'));
    highlighter.requests.last.$2.complete(
      const TextSpan(
        text: 'latest',
        style: TextStyle(color: Colors.green),
      ),
    );
    await tester.pump();
    final colors = <Color?>[];
    paragraph('latest').text.visitChildren((span) {
      if (span is TextSpan && span.text == 'latest')
        colors.add(span.style?.color);
      return true;
    });
    expect(colors, contains(Colors.green));
    await tester.pumpWidget(view('disposed'));
    await tester.pumpWidget(const SizedBox());
    highlighter.requests.last.$2.completeError(
      StateError('highlighter failed'),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'highlight work is bounded while streaming and resumes on finish',
    (tester) async {
      final highlighter = _Highlighter();
      final source = '```dart\n${List.filled(301, 'x').join('\n')}\n```';
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: source,
            streaming: true,
            codeHighlighter: highlighter,
          ),
        ),
      );
      expect(highlighter.requests, isEmpty);
      await tester.pumpWidget(
        host(MarkstreamView(source: source, codeHighlighter: highlighter)),
      );
      expect(highlighter.requests, hasLength(1));
      highlighter.requests.single.$2.complete(
        TextSpan(text: highlighter.requests.single.$1),
      );
      await tester.pumpAndSettle();
    },
  );
  testWidgets('manual code expansion survives append, finish and remount', (
    tester,
  ) async {
    final store = CodeExpansionState();
    final options = CodeBlockOptions(
      autoCollapse: true,
      collapsedLines: 2,
      expansionState: store,
    );
    Widget view(String tail, {bool streaming = true}) => host(
      MarkstreamView(
        source: '```dart\nfirst line\nsecond line\nthird line$tail',
        streaming: streaming,
        codeOptions: options,
      ),
    );
    await tester.pumpWidget(view(''));
    expect(paragraph('first').text.toPlainText(), 'first line\nsecond line');
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.key == const ValueKey('markstream-code-toggle') &&
            w.properties.expanded == false,
      ),
    );
    await tester.pumpAndSettle();
    expect(paragraph('first').text.toPlainText(), contains('third line'));
    await tester.pumpWidget(view(' appended'));
    await tester.pumpAndSettle();
    expect(
      paragraph('first').text.toPlainText(),
      contains('third line appended'),
    );
    await tester.pumpWidget(view(' appended\n```', streaming: false));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.key == const ValueKey('markstream-code-toggle') &&
            w.properties.expanded == true,
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(view(' appended\n```', streaming: false));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.key == const ValueKey('markstream-code-toggle') &&
            w.properties.expanded == true,
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.key == const ValueKey('markstream-code-toggle') &&
            w.properties.expanded == true,
      ),
    );
    await tester.pumpAndSettle();
    expect(paragraph('first').text.toPlainText(), 'first line\nsecond line');
    final bounded = CodeExpansionState(capacity: 1)
      ..remember('DART', ' a   b', true)
      ..remember('js', 'x', false);
    expect(bounded.read('dart', 'a b'), isNull);
    expect(
      store.read(' dart ', 'first line\nsecond line\nthird changed'),
      isFalse,
    );
  });
  testWidgets(
    'an early expansion follows a growing code anchor across remount',
    (tester) async {
      final store = CodeExpansionState();
      final options = CodeBlockOptions(
        autoCollapse: true,
        collapsedLines: 1,
        expansionState: store,
      );
      Widget view(String source, {bool streaming = true}) => host(
        MarkstreamView(
          source: source,
          streaming: streaming,
          codeOptions: options,
        ),
      );
      await tester.pumpWidget(view('```text\na\nb'));
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.key == const ValueKey('markstream-code-toggle') &&
              w.properties.expanded == false,
        ),
      );
      await tester.pumpAndSettle();
      const completed = '```text\na\nb\nthis completes the prefix\n```';
      await tester.pumpWidget(view(completed, streaming: false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(view(completed, streaming: false));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.key == const ValueKey('markstream-code-toggle') &&
              w.properties.expanded == true,
        ),
        findsOneWidget,
      );
      expect(
        paragraph('a').text.toPlainText(),
        contains('this completes the prefix'),
      );
    },
  );

  testWidgets('code chrome actions are injectable and copy complete raw code', (
    tester,
  ) async {
    String? clipboard, selected;
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
    final kinds = <MarkstreamActionKind>[];
    final extensions = MarkstreamExtensions(
      actionButtonBuilder: (context, action) {
        kinds.add(action.kind);
        return TextButton(
          onPressed: action.onInvoke,
          child: Text(action.label),
        );
      },
      codeExtraActions: (context, code) => [Text('extra:${code.code.info}')],
    );
    await tester.pumpWidget(
      host(
        MarkstreamView(
          source: '```dart\n  alpha\n\n beta\n```',
          extensions: extensions,
          codeOptions: const CodeBlockOptions(
            autoCollapse: true,
            collapsedLines: 1,
          ),
        ),
        selectable: true,
        onSelection: (value) => selected = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    selectAll(tester);
    await tester.pumpAndSettle();
    expect(selected, '  alpha');
    await tester.ensureVisible(find.text('Copy code'));
    await tester.tap(find.text('Copy code'));
    await tester.pumpAndSettle();
    expect(clipboard, '  alpha\n\n beta\n');
    expect(kinds, contains(MarkstreamActionKind.copyCode));
    expect(find.byType(SelectableRegion), findsOneWidget);
  });
  testWidgets(
    'long virtual code select all includes unmounted lines after scrolling',
    (tester) async {
      final code = List.generate(1400, (i) => '  line$i').join('\n');
      String? selected;
      await tester.pumpWidget(
        host(
          MarkstreamView(source: '```text\n$code\n```'),
          selectable: true,
          onSelection: (value) => selected = value?.plainText,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('markstream-virtualized-code')),
        findsOneWidget,
      );
      expect(
        paragraphs().where((p) => p.text.toPlainText().contains('line1399')),
        isEmpty,
      );
      final scrollable = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(4500);
      await tester.pumpAndSettle();
      selectAll(tester);
      await tester.pumpAndSettle();
      expect(selected, code);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('code fragments preserve newline across virtual chunk boundary', (
    tester,
  ) async {
    final code = List.generate(1200, (i) => 'line$i').join('\n');
    String? selected;
    await tester.pumpWidget(
      host(
        MarkstreamView(source: '```\n$code\n```'),
        selectable: true,
        onSelection: (value) => selected = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    // The first chunk has 200 lines; place its last line and the next first
    // line together inside the 420 px viewport.
    final first = paragraph('line0');
    final height = first.preferredLineHeight;
    position.jumpTo(height * 195);
    await tester.pumpAndSettle();
    final fragments = paragraphs();
    final before = fragments.firstWhere(
      (p) => p.text.toPlainText().contains('line199'),
    );
    final after = fragments.firstWhere(
      (p) => p.text.toPlainText().startsWith('line200'),
    );
    final start = before.text.toPlainText().indexOf('line199');
    final gesture = await tester.createGesture(
      kind: ui.PointerDeviceKind.mouse,
    );
    await gesture.addPointer();
    await gesture.down(edge(before, start));
    await gesture.moveTo(edge(after, 6, end: true));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, 'line199\nline200');
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  testWidgets(
    'drag across scrolled virtual code includes its complete source',
    (tester) async {
      final code = List.generate(1200, (i) => 'line$i').join('\n');
      String? selected;
      await tester.pumpWidget(
        host(
          MarkstreamView(source: 'Before\n\n```\n$code\n```\n\nAfter'),
          selectable: true,
          onSelection: (value) => selected = value?.plainText,
        ),
      );
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(4500);
      await tester.pumpAndSettle();
      final gesture = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await gesture.addPointer();
      await gesture.down(edge(paragraph('Before'), 0));
      await gesture.moveTo(edge(paragraph('After'), 4, end: true));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selected, contains(code));
      expect(selected, endsWith('After'));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
  testWidgets('rich blocks fit narrow widths with enlarged text', (
    tester,
  ) async {
    const source =
        '```dart\n1\n2\n3\n```\n\n| A | B | C | D |\n| - | - | - | - |\n| a | b | c | d |\n\n<details open>\n<summary>Summary title</summary>\n\nBody\n\n</details>';
    for (final width in [180.0, 390.0, 720.0]) {
      await tester.pumpWidget(
        host(const MarkstreamView(source: source), width: width, scale: 1.3),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('table selection is TSV and actions serialize all hidden rows', (
    tester,
  ) async {
    String? selected, clipboard;
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
    final source = tableSource(45);
    await tester.pumpWidget(
      host(
        MarkstreamView(source: source),
        selectable: true,
        onSelection: (value) => selected = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Table>(find.byType(Table)).children, hasLength(40));
    selectAll(tester);
    await tester.pumpAndSettle();
    expect(selected, startsWith('Name\tValue\nrow0\tvalue0'));
    expect(selected, endsWith('row38\tvalue38'));
    await tester.tap(find.text('Copy CSV'));
    await tester.pumpAndSettle();
    expect(clipboard, endsWith('row44,value44'));
    expect(clipboard, contains('\r\n'));
    await tester.tap(find.text('Copy Markdown'));
    await tester.pumpAndSettle();
    expect(
      clipboard,
      toMarkdown(MarkdownParser().parse(source).children.single),
    );
  });
  testWidgets('table pagination and streaming limits retain user page state', (
    tester,
  ) async {
    final source = tableSource(150);
    Future<void> pump({bool streaming = false, bool exporting = false}) async {
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: source,
            streaming: streaming,
            exporting: exporting,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump();
    expect(tester.widget<Table>(find.byType(Table)).children, hasLength(40));
    final more = find.text('Show 111 more rows');
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(tester.widget<Table>(find.byType(Table)).children, hasLength(140));
    await pump(streaming: true);
    expect(tester.widget<Table>(find.byType(Table)).children, hasLength(30));
    await pump();
    expect(tester.widget<Table>(find.byType(Table)).children, hasLength(140));
    await pump(exporting: true);
    expect(tester.widget<Table>(find.byType(Table)).children, hasLength(151));
    await pump();
    expect(tester.widget<Table>(find.byType(Table)).children, hasLength(140));
  });
  testWidgets('table capture includes hidden rows and restores pagination', (
    tester,
  ) async {
    late TableActionContext actions;
    final extensions = MarkstreamExtensions(
      tableExtraActions: (context, value) {
        actions = value;
        return [const Text('extra')];
      },
    );
    await tester.pumpWidget(
      host(MarkstreamView(source: tableSource(45), extensions: extensions)),
    );
    await tester.pumpAndSettle();
    final before = tester.getSize(find.byType(Table)).height;
    await expectLater(actions.capturePng(double.nan), throwsArgumentError);
    final future = actions.capturePng(1);
    await tester.pump();
    expect(tester.widget<Table>(find.byType(Table)).children, hasLength(46));
    await tester.runAsync(() async {
      final bytes = await future;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.height, greaterThan(before));
      final rgba = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final offset =
          ((frame.image.height - 5) * frame.image.width +
              frame.image.width ~/ 2) *
          4;
      expect(rgba!.getUint8(offset + 3), 255);
      frame.image.dispose();
      codec.dispose();
    });
    await tester.pumpAndSettle();
    expect(tester.widget<Table>(find.byType(Table)).children, hasLength(40));
    final tooLarge = expectLater(actions.capturePng(1000), throwsStateError);
    await tester.pump();
    await tooLarge;
    await tester.pumpAndSettle();
    expect(tester.widget<Table>(find.byType(Table)).children, hasLength(40));
  });
  testWidgets('details hide body from selection and retain manual folding', (
    tester,
  ) async {
    String? selected;
    Widget view(String body) => host(
      MarkstreamView(
        source: '<details>\n<summary>Summary **strong**</summary>\n\n$body',
      ),
      selectable: true,
      onSelection: (value) => selected = value?.plainText,
    );
    await tester.pumpWidget(view('Secret body'));
    await tester.pumpAndSettle();
    selectAll(tester);
    await tester.pumpAndSettle();
    expect(selected, 'Summary strong');
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.expanded == false,
      ),
    );
    await tester.pumpAndSettle();
    selectAll(tester);
    await tester.pumpAndSettle();
    expect(selected, contains('Secret body'));
    await tester.pumpWidget(view('Secret body appended'));
    await tester.pumpAndSettle();
    expect(paragraph('Secret').text.toPlainText(), 'Secret body appended');
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.expanded == true,
      ),
    );
    await tester.pumpAndSettle();
    selectAll(tester);
    await tester.pumpAndSettle();
    expect(selected, 'Summary strong');
    expect(find.byType(SelectableRegion), findsOneWidget);
  });
  testWidgets('display math scrolls wide visuals and copies delimited LaTeX', (
    tester,
  ) async {
    String? selected;
    final math = _DisplayMath();
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        MarkstreamView(
          source: '\$\$\nx^2 + y^2\n\$\$',
          mathRenderer: math,
          selectionController: controller,
        ),
        width: 180,
        selectable: true,
        onSelection: (value) => selected = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    selectAll(tester);
    await tester.pumpAndSettle();
    expect(math.display, isTrue);
    expect(selected, '\$\$\nx^2 + y^2\n\$\$');
    expect(controller.selectedPlainText, selected);
    expect(controller.selectedMarkdown, '\$\$\nx^2 + y^2\n\$\$');
    expect(tester.takeException(), isNull);
  });
  testWidgets('full HTML documents dispatch through the html code extension', (
    tester,
  ) async {
    String? code;
    final extensions = MarkstreamExtensions(
      codeBlockBuilders: {
        'html': (context, node, rendering) {
          code = node.code;
          return const Text('HTML preview');
        },
      },
    );
    const source = '<!DOCTYPE html>\n<html><body>Page</body></html>';
    await tester.pumpWidget(
      host(MarkstreamView(source: source, extensions: extensions)),
    );
    expect(code, contains('<html>'));
    expect(find.text('HTML preview'), findsOneWidget);
  });
}
