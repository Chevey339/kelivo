import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:Kelivo/shared/widgets/mermaid_image_cache.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _findMathWidget() {
  return find.byType(Math);
}

List<WidgetSpan> _collectWidgetSpans(InlineSpan span) {
  final spans = <WidgetSpan>[];
  if (span is WidgetSpan) spans.add(span);
  final children = span is TextSpan ? span.children : null;
  if (children == null) return spans;
  for (final child in children) {
    spans.addAll(_collectWidgetSpans(child));
  }
  return spans;
}

List<WidgetSpan> _widgetSpansFromRichText(WidgetTester tester) {
  final spans = <WidgetSpan>[];
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    spans.addAll(_collectWidgetSpans(richText.text));
  }
  return spans;
}

const _transparentPngDataUrl =
    'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwAD'
    'hgGAWjR9awAAAABJRU5ErkJggg==';

const _transparentPngBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0xDA,
  0x63,
  0x64,
  0xFE,
  0xCF,
  0x50,
  0x0F,
  0x00,
  0x03,
  0x86,
  0x01,
  0x80,
  0x5A,
  0x34,
  0x7D,
  0x6B,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

Widget _markdownHarness(
  String text, {
  double? width,
  bool streaming = false,
  Map<String, Object>? preferences,
}) {
  SharedPreferences.setMockInitialValues(preferences ?? {});
  return ChangeNotifierProvider(
    create: (_) => SettingsProvider(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: width == null
            ? MarkdownWithCodeHighlight(text: text, streaming: streaming)
            : Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: MarkdownWithCodeHighlight(
                    text: text,
                    streaming: streaming,
                  ),
                ),
              ),
      ),
    ),
  );
}

Widget _streamingMarkdownHarness(
  ValueListenable<String> text, {
  Map<String, Object>? preferences,
}) {
  SharedPreferences.setMockInitialValues(preferences ?? {});
  return ChangeNotifierProvider(
    create: (_) => SettingsProvider(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ValueListenableBuilder<String>(
          valueListenable: text,
          builder: (context, value, _) =>
              MarkdownWithCodeHighlight(text: value, streaming: true),
        ),
      ),
    ),
  );
}

Widget _settingsHarness({
  required Widget child,
  Map<String, Object>? preferences,
  required void Function(SettingsProvider settings) onSettingsReady,
}) {
  SharedPreferences.setMockInitialValues(preferences ?? {});
  return ChangeNotifierProvider(
    create: (_) {
      final settings = SettingsProvider();
      onSettingsReady(settings);
      return settings;
    },
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  test('markdown table CSV export escapes boundary cell values', () {
    final csv = markdownTableRowsToCsvForTesting([
      ['Name', 'Note', 'Multiline'],
      ['Alice', 'plain', 'first\nsecond'],
      ['Bob, Jr.', 'said "hello"', ''],
    ]);

    expect(
      csv,
      'Name,Note,Multiline\r\n'
      'Alice,plain,"first\nsecond"\r\n'
      '"Bob, Jr.","said ""hello""",',
    );
  });

  testWidgets('MarkdownWithCodeHighlight applies markdown image dimensions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _markdownHarness('![42x24]($_transparentPngDataUrl)', width: 160),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, 42.0);
    expect(image.height, 24.0);
  });

  testWidgets(
    'MarkdownWithCodeHighlight keeps undimensioned images full width',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness('![]($_transparentPngDataUrl)', width: 160),
      );
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 160.0);
      expect(image.height, isNull);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight shows broken image for invalid source',
    (tester) async {
      await tester.pumpWidget(_markdownHarness('![42x24](missing-image.png)'));
      await tester.pump();

      expect(find.byIcon(Icons.broken_image), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );

  testWidgets('MarkdownWithCodeHighlight renders mobile table export action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _markdownHarness('''
| Name | Value |
| - | -: |
| Alpha | 42 |
''', width: 360),
    );
    await tester.pump();

    expect(find.text('Table'), findsOneWidget);
    expect(find.byTooltip('Copy'), findsOneWidget);
    expect(find.byTooltip('Export CSV'), findsOneWidget);
    expect(find.byTooltip('Export as Image'), findsOneWidget);
    final tableBlock = find.byKey(const ValueKey('markdown-table-block'));
    final plainText = tester
        .widgetList<RichText>(
          find.descendant(of: tableBlock, matching: find.byType(RichText)),
        )
        .map((widget) => widget.text.toPlainText())
        .join('\n');
    expect(plainText, contains('Name'));
    expect(plainText, contains('42'));
  });

  testWidgets('MarkdownWithCodeHighlight keeps table actions out of body', (
    tester,
  ) async {
    await tester.pumpWidget(
      _markdownHarness('''
| Name | Value |
| - | - |
| Alpha | Beta |
''', width: 360),
    );
    await tester.pump();

    final body = find.byKey(const ValueKey('markdown-table-body'));
    expect(body, findsOneWidget);
    expect(
      find.descendant(of: body, matching: find.byTooltip('Export CSV')),
      findsNothing,
    );
    expect(
      find.descendant(of: body, matching: find.byTooltip('Copy')),
      findsNothing,
    );
    expect(
      find.descendant(of: body, matching: find.byTooltip('Export as Image')),
      findsNothing,
    );
  });

  testWidgets('MarkdownWithCodeHighlight does not scroll narrow table', (
    tester,
  ) async {
    await tester.pumpWidget(
      _markdownHarness('''
| Name | Value |
| - | - |
| Alpha | Beta |
''', width: 360),
    );
    await tester.pump();

    final tableBlock = find.byKey(const ValueKey('markdown-table-block'));
    expect(tableBlock, findsOneWidget);
    final tableBlockWidget = tester.widget<Container>(tableBlock);
    expect(tableBlockWidget.foregroundDecoration, isA<BoxDecoration>());
    final foregroundDecoration =
        tableBlockWidget.foregroundDecoration! as BoxDecoration;
    expect(foregroundDecoration.border, isNotNull);
    expect(
      find.descendant(
        of: tableBlock,
        matching: find.byKey(
          const ValueKey('markdown-table-horizontal-scroll'),
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('MarkdownWithCodeHighlight scrolls only overflowing table', (
    tester,
  ) async {
    await tester.pumpWidget(
      _markdownHarness('''
| Very long header | Another very long header | Third very long header | Fourth very long header |
| - | - | - | - |
| A very long value that should wrap inside the cell | Second long value | Third long value | Fourth long value |
''', width: 320),
    );
    await tester.pump();

    final tableBlock = find.byKey(const ValueKey('markdown-table-block'));
    expect(tableBlock, findsOneWidget);
    expect(tester.getSize(tableBlock).width, lessThanOrEqualTo(320));
    expect(
      find.descendant(
        of: tableBlock,
        matching: find.byKey(
          const ValueKey('markdown-table-horizontal-scroll'),
        ),
      ),
      findsOneWidget,
    );
    final scrollView = tester.widget<SingleChildScrollView>(
      find.descendant(
        of: tableBlock,
        matching: find.byKey(
          const ValueKey('markdown-table-horizontal-scroll'),
        ),
      ),
    );
    expect(scrollView.physics, isA<ClampingScrollPhysics>());
  });

  testWidgets(
    'MarkdownWithCodeHighlight does not add a bottom fade while streaming',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(
          'This answer is still arriving without a message-local fade mask.',
          streaming: true,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('streaming-markdown-tail-fade')),
        findsNothing,
      );
    },
  );

  testWidgets('MarkdownWithCodeHighlight debounces long streaming reparses', (
    tester,
  ) async {
    final baseLines = List<String>.filled(
      260,
      'streaming markdown keeps a rich rendered frame',
    ).join('\n');
    final text = ValueNotifier<String>('$baseLines\nold-tail');

    await tester.pumpWidget(_streamingMarkdownHarness(text));
    await tester.pump();

    expect(find.textContaining('old-tail'), findsOneWidget);

    text.value = '$baseLines\nnew-tail';
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.textContaining('old-tail'), findsOneWidget);
    expect(find.textContaining('new-tail'), findsNothing);

    await tester.pump(const Duration(milliseconds: 180));

    expect(find.textContaining('new-tail'), findsOneWidget);
  });

  testWidgets(
    'MarkdownWithCodeHighlight keeps refreshing during continuous long streams',
    (tester) async {
      final baseLines = List<String>.filled(
        260,
        'continuous streaming markdown keeps rendered frames moving',
      ).join('\n');
      final text = ValueNotifier<String>('$baseLines\nframe-0');

      await tester.pumpWidget(_streamingMarkdownHarness(text));
      await tester.pump();

      text.value = '$baseLines\nframe-1';
      await tester.pump(const Duration(milliseconds: 50));
      text.value = '$baseLines\nframe-2';
      await tester.pump(const Duration(milliseconds: 50));
      text.value = '$baseLines\nframe-3';
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 40));

      expect(find.textContaining('frame-3'), findsOneWidget);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight caps rendered rows for streaming long tables',
    (tester) async {
      final rows = List<String>.generate(40, (i) => '| row$i | value$i |');
      await tester.pumpWidget(
        _markdownHarness(
          '''
| Name | Value |
| - | - |
${rows.join('\n')}
''',
          width: 360,
          streaming: true,
        ),
      );
      await tester.pump();

      final body = find.byKey(const ValueKey('markdown-table-body'));
      final plainText = tester
          .widgetList<RichText>(
            find.descendant(of: body, matching: find.byType(RichText)),
          )
          .map((widget) => widget.text.toPlainText())
          .join('\n');

      expect(plainText, contains('row0'));
      expect(plainText, contains('row29'));
      expect(plainText, isNot(contains('row30')));
      expect(plainText, isNot(contains('row39')));
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps an unfinished streaming table row in table layout',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(
          '''
| 水果 | 颜色 | 价格 |
| - | - | - |
| 苹果 | 红色 | ¥9.9 |
| 葡萄 🍇 | 紫色 | ¥12.8
''',
          width: 360,
          streaming: true,
        ),
      );
      await tester.pump();

      final body = find.byKey(const ValueKey('markdown-table-body'));
      expect(body, findsOneWidget);
      final tableText = tester
          .widgetList<RichText>(
            find.descendant(of: body, matching: find.byType(RichText)),
          )
          .map((widget) => widget.text.toPlainText())
          .join('\n');
      final allText = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((widget) => widget.text.toPlainText())
          .join('\n');

      expect(tableText, contains('葡萄 🍇'));
      expect(tableText, contains('¥12.8'));
      expect(allText, isNot(contains('| 葡萄 🍇 | 紫色 | ¥12.8')));
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps a just-started streaming table row in table layout',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(
          '''
| 水果 | 颜色 | 价格 |
| - | - | - |
| 葡萄 🍇''',
          width: 360,
          streaming: true,
        ),
      );
      await tester.pump();

      final body = find.byKey(const ValueKey('markdown-table-body'));
      expect(body, findsOneWidget);
      final tableText = tester
          .widgetList<RichText>(
            find.descendant(of: body, matching: find.byType(RichText)),
          )
          .map((widget) => widget.text.toPlainText())
          .join('\n');
      final allText = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((widget) => widget.text.toPlainText())
          .join('\n');

      expect(tableText, contains('葡萄 🍇'));
      expect(allText, isNot(contains('| 葡萄 🍇')));
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight shows cached Mermaid bitmap while streaming',
    (tester) async {
      addTearDown(MermaidImageCache.clear);
      const code = 'graph TD\nA-->B';
      MermaidImageCache.put(code, Uint8List.fromList(_transparentPngBytes));

      await tester.pumpWidget(
        _markdownHarness('''
```mermaid
$code
''', streaming: true),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.textContaining('graph TD'), findsNothing);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps Mermaid bitmap visible while streaming code grows',
    (tester) async {
      addTearDown(MermaidImageCache.clear);
      const firstCode = 'graph TD\nA-->B';
      MermaidImageCache.put(
        firstCode,
        Uint8List.fromList(_transparentPngBytes),
      );
      final text = ValueNotifier<String>('''
```mermaid
$firstCode
''');

      await tester.pumpWidget(_streamingMarkdownHarness(text));
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);

      text.value =
          '''
```mermaid
$firstCode
B-->C
''';
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.textContaining('graph TD'), findsNothing);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps table body clipped inside shell',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness('''
| Very long header | Another very long header | Third very long header |
| - | - | - |
| A very long value that should wrap inside the cell | Second long value | Third long value |
''', width: 320),
      );
      await tester.pump();

      final tableBlock = find.byKey(const ValueKey('markdown-table-block'));
      final body = find.byKey(const ValueKey('markdown-table-body'));
      final blockRect = tester.getRect(tableBlock);
      final bodyRect = tester.getRect(body);

      expect(bodyRect.left, greaterThanOrEqualTo(blockRect.left));
      expect(bodyRect.right, lessThanOrEqualTo(blockRect.right));
    },
  );

  testWidgets('MarkdownWithCodeHighlight applies app font to table text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _markdownHarness(
        '''
| Name | Value |
| - | - |
| Alpha | Beta |
''',
        width: 360,
        preferences: const {'display_app_font_family_v1': 'Courier'},
      ),
    );
    await tester.pump();

    final tableBlock = find.byKey(const ValueKey('markdown-table-block'));
    final richTexts = tester.widgetList<RichText>(
      find.descendant(of: tableBlock, matching: find.byType(RichText)),
    );

    expect(
      richTexts.any((widget) => widget.text.style?.fontFamily == 'Courier'),
      isTrue,
    );
  });

  testWidgets(
    'MarkdownWithCodeHighlight uses flutter_math_fork for inline and block math',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness('Inline \\(a^2+b^2=c^2\\)\n\n\\[E=mc^2\\]'),
      );
      await tester.pump();

      expect(_findMathWidget(), findsNWidgets(2));
    },
  );

  testWidgets('MarkdownWithCodeHighlight vertically centers inline math', (
    tester,
  ) async {
    await tester.pumpWidget(
      _markdownHarness(r'Text before \(a+b\) text after'),
    );
    await tester.pump();

    final mathSpans = _widgetSpansFromRichText(tester)
        .where(
          (span) => find
              .descendant(
                of: find.byWidget(span.child),
                matching: _findMathWidget(),
              )
              .evaluate()
              .isNotEmpty,
        )
        .toList();

    expect(mathSpans, hasLength(1));
    expect(mathSpans.single.alignment, PlaceholderAlignment.middle);
    expect(
      find.ancestor(
        of: _findMathWidget(),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
  });

  testWidgets('MarkdownWithCodeHighlight keeps dollar math switch scoped', (
    tester,
  ) async {
    await tester.pumpWidget(
      _markdownHarness(
        r'Inline $a+b$ and \(c+d\)',
        preferences: const {'display_enable_dollar_latex_v1': false},
      ),
    );
    await tester.pump();

    expect(_findMathWidget(), findsOneWidget);
    expect(find.textContaining(r'$a+b$'), findsOneWidget);
  });

  testWidgets(
    r'MarkdownWithCodeHighlight renders escaped-pipe dollar math as math',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(
          r'已知 $q$ 是 $\mathbb{R}^n$ 上的多项式。对所有满足 $\|x\|=1$ 的 $x$，有 $p(x)=q(x)$。',
        ),
      );
      await tester.pump();

      expect(_findMathWidget(), findsNWidgets(5));
      expect(find.textContaining(r'\|x\|=1'), findsNothing);
      expect(find.textContaining(r'\lVert x \rVert'), findsNothing);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight follows GitHub-like dollar math boundaries',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(r'''
分别$10和$20

分别 $10和$ 20

分别$10$和$20$

分别 $10$ 和$20$
'''),
      );
      await tester.pump();

      expect(_findMathWidget(), findsNWidgets(2));
      expect(find.textContaining(r'分别$10和$20'), findsOneWidget);
      expect(find.textContaining(r'分别$10$和$20$'), findsOneWidget);
      expect(find.textContaining(r'和$20$'), findsOneWidget);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight renders dollar math after prose punctuation',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(r'''
## 九、数学公式测试（需渲染器支持）

行内公式：$E = mc^2$

块级公式：

$$
\int_{a}^{b} f(x) \, dx = F(b) - F(a)
$$
'''),
      );
      await tester.pump();

      expect(_findMathWidget(), findsNWidgets(2));
      expect(find.textContaining(r'$E = mc^2$'), findsNothing);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps unfinished streaming dollar math in math layout',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(r'公式正在输出：$E = mc', streaming: true),
      );
      await tester.pump();

      expect(_findMathWidget(), findsOneWidget);
      expect(find.textContaining(r'$E = mc'), findsNothing);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps table pipes from widening dollar math',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(r'''
| A | B |
| - | - |
| $a$ | b |
| $a|b$ | c |
'''),
      );
      await tester.pump();

      expect(_findMathWidget(), findsOneWidget);
      expect(find.textContaining(r'$a'), findsOneWidget);
      expect(find.textContaining(r'b$'), findsOneWidget);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight disables all math rendering by setting',
    (tester) async {
      late SettingsProvider settings;

      await tester.pumpWidget(
        _settingsHarness(
          onSettingsReady: (value) => settings = value,
          child: const MarkdownWithCodeHighlight(
            text: r'Inline \(a+b\) and $$c+d$$',
          ),
        ),
      );
      await tester.pump();

      expect(_findMathWidget(), findsWidgets);

      await settings.setEnableMathRendering(false);
      await tester.pumpAndSettle();

      expect(_findMathWidget(), findsNothing);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight does not render math inside code blocks',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(r'''
```dart
final price = "$12";
```
'''),
      );
      await tester.pump();

      expect(_findMathWidget(), findsNothing);
      expect(find.textContaining(r'final price = "$12";'), findsOneWidget);
    },
  );

  testWidgets('SelectableHighlightView 为已注册语言生成高亮 span', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SelectableHighlightView(
            'final value = 1;',
            language: 'dart',
            theme: {},
          ),
        ),
      ),
    );

    final richText = tester.widget<SelectableText>(find.byType(SelectableText));
    final root = richText.textSpan!;
    final children = root.children ?? const <InlineSpan>[];

    expect(children, isNotEmpty);
    expect(children.length, greaterThan(1));
  });

  testWidgets('SelectableHighlightView 同内容父级重建时复用高亮 span', (tester) async {
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return const SelectableHighlightView(
                'final value = 1;',
                language: 'dart',
                theme: {},
              );
            },
          ),
        ),
      ),
    );

    final before = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .textSpan!
        .children;

    rebuild(() {});
    await tester.pump();

    final after = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .textSpan!
        .children;

    expect(identical(before, after), isTrue);
  });

  testWidgets(
    'SelectableHighlightView skips synchronous highlighting on demand',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SelectableHighlightView(
              'final value = 1;',
              language: 'dart',
              theme: {},
              enableHighlight: false,
            ),
          ),
        ),
      );

      final richText = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      final root = richText.textSpan!;
      final children = root.children ?? const <InlineSpan>[];

      expect(children, hasLength(1));
      expect((children.single as TextSpan).text, 'final value = 1;');
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight highlights unclosed code fences after streaming stops',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness('''
```dart
final value = 1;
'''),
      );
      await tester.pump();

      final richText = tester.widget<SelectableText>(
        find.descendant(
          of: find.byType(SelectableHighlightView),
          matching: find.byType(SelectableText),
        ),
      );
      final root = richText.textSpan!;
      final children = root.children ?? const <InlineSpan>[];

      expect(children.length, greaterThan(1));
    },
  );

  testWidgets('MarkdownWithCodeHighlight renders code block actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _markdownHarness('''
```dart
void main() {}
```
'''),
    );
    await tester.pump();

    expect(find.byTooltip('Save as file'), findsOneWidget);
    expect(find.byTooltip('Copy'), findsOneWidget);
    expect(find.text('dart'), findsOneWidget);
  });

  testWidgets('MarkdownWithCodeHighlight toggles auto-collapsed code block', (
    tester,
  ) async {
    await tester.pumpWidget(
      _markdownHarness(
        '''
```dart
line1
line2
line3
```
''',
        preferences: const {
          'display_auto_collapse_code_block_v1': true,
          'display_auto_collapse_code_block_lines_v1': 2,
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.text('Expand'), findsOneWidget);
    expect(find.textContaining('line3'), findsNothing);
    expect(find.textContaining('folded'), findsNothing);

    await tester.tap(find.text('Expand'));
    await tester.pumpAndSettle();

    expect(find.text('Collapse'), findsOneWidget);
    expect(find.textContaining('line3'), findsOneWidget);
  });

  testWidgets(
    'MarkdownWithCodeHighlight shows full code after auto-collapse is disabled',
    (tester) async {
      late SettingsProvider settings;

      await tester.pumpWidget(
        _settingsHarness(
          onSettingsReady: (value) => settings = value,
          child: const MarkdownWithCodeHighlight(
            text: '''
```dart
disable1
disable2
disable3
```
''',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('disable3'), findsOneWidget);

      await settings.setAutoCollapseCodeBlockLines(2);
      await settings.setAutoCollapseCodeBlock(true);
      await tester.pumpAndSettle();

      expect(find.text('Expand'), findsOneWidget);
      expect(find.textContaining('disable3'), findsNothing);

      await settings.setAutoCollapseCodeBlock(false);
      await tester.pumpAndSettle();

      expect(find.text('Expand'), findsNothing);
      expect(find.text('Collapse'), findsNothing);
      expect(find.textContaining('disable3'), findsOneWidget);
    },
  );

  testWidgets('MarkdownWithCodeHighlight keeps manual toggle while streaming', (
    tester,
  ) async {
    final streamText = ValueNotifier<String>('''
```dart
alpha1
alpha2
alpha3
```
''');

    await tester.pumpWidget(
      _streamingMarkdownHarness(
        streamText,
        preferences: const {
          'display_auto_collapse_code_block_v1': true,
          'display_auto_collapse_code_block_lines_v1': 2,
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.text('Expand'), findsOneWidget);
    expect(find.textContaining('alpha3'), findsNothing);

    await tester.tap(find.text('Expand'));
    await tester.pumpAndSettle();

    streamText.value = '''
```dart
alpha1
alpha2
alpha3
alpha4
```
''';
    await tester.pumpAndSettle();

    expect(find.text('Collapse'), findsOneWidget);
    expect(find.textContaining('alpha4'), findsOneWidget);

    await tester.tap(find.text('Collapse'));
    await tester.pumpAndSettle();

    streamText.value = '''
```dart
beta1
alpha2
alpha3
alpha4
alpha5
```
''';
    await tester.pumpAndSettle();

    expect(find.text('Expand'), findsOneWidget);
    expect(find.textContaining('alpha5'), findsNothing);
  });

  testWidgets(
    'MarkdownWithCodeHighlight accepts fold tap during streaming rebuild',
    (tester) async {
      final streamText = ValueNotifier<String>('''
```dart
press1
press2
press3
```
''');

      await tester.pumpWidget(
        _streamingMarkdownHarness(
          streamText,
          preferences: const {
            'display_auto_collapse_code_block_v1': true,
            'display_auto_collapse_code_block_lines_v1': 2,
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      final expandGesture = await tester.startGesture(
        tester.getCenter(find.text('Expand')),
      );
      streamText.value = '''
```dart
press1
press2
press3
press4
```
''';
      await tester.pump();
      await expandGesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Collapse'), findsOneWidget);
      expect(find.textContaining('press4'), findsOneWidget);

      final collapseGesture = await tester.startGesture(
        tester.getCenter(find.text('Collapse')),
      );
      streamText.value = '''
```dart
press1
press2
press3
press4
press5
```
''';
      await tester.pump();
      await collapseGesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Expand'), findsOneWidget);
      expect(find.textContaining('press5'), findsNothing);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight renders details collapsed then expands',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness('<details><summary>更多信息</summary>隐藏内容</details>'),
      );
      await tester.pump();

      expect(find.text('更多信息'), findsOneWidget);
      expect(find.text('隐藏内容', findRichText: true), findsNothing);

      await tester.tap(find.text('更多信息'));
      await tester.pumpAndSettle();

      expect(find.text('隐藏内容', findRichText: true), findsOneWidget);

      await tester.tap(find.text('更多信息'));
      await tester.pumpAndSettle();

      expect(find.text('隐藏内容', findRichText: true), findsNothing);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight renders nested details independently',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness('''
开头文本

<details>
<summary>第一层折叠</summary>

普通内容...

<details>
<summary>第二层折叠</summary>

深藏的内容在这里！

</details>

</details>

结尾文本
'''),
      );
      await tester.pump();

      var richTexts = tester.widgetList<RichText>(find.byType(RichText));
      var plainText = richTexts.map((w) => w.text.toPlainText()).join('\n');

      expect(plainText, contains('开头文本'));
      expect(find.text('第一层折叠'), findsOneWidget);
      expect(find.text('第二层折叠'), findsNothing);
      expect(find.text('普通内容...', findRichText: true), findsNothing);
      expect(find.text('深藏的内容在这里！', findRichText: true), findsNothing);

      await tester.tap(find.text('第一层折叠'));
      await tester.pumpAndSettle();

      richTexts = tester.widgetList<RichText>(find.byType(RichText));
      plainText = richTexts.map((w) => w.text.toPlainText()).join('\n');

      expect(plainText, contains('普通内容...'));
      expect(find.text('第二层折叠'), findsOneWidget);
      expect(find.text('深藏的内容在这里！', findRichText: true), findsNothing);

      await tester.tap(find.text('第二层折叠'));
      await tester.pumpAndSettle();

      richTexts = tester.widgetList<RichText>(find.byType(RichText));
      plainText = richTexts.map((w) => w.text.toPlainText()).join('\n');

      expect(plainText, contains('深藏的内容在这里！'));
      expect(plainText, contains('结尾文本'));
      expect(plainText, isNot(contains('</details>')));
    },
  );

  testWidgets('MarkdownWithCodeHighlight renders basic inline HTML tags', (
    tester,
  ) async {
    await tester.pumpWidget(
      _markdownHarness(
        '<p>第一段<br>第二行</p><p><a href="https://example.com">链接</a></p>',
      ),
    );
    await tester.pump();

    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    final plainText = richTexts.map((w) => w.text.toPlainText()).join('\n');

    expect(plainText, contains('第一段\n第二行'));
    expect(plainText, isNot(contains('<p>')));
    expect(plainText, isNot(contains('<br>')));
    expect(plainText, isNot(contains('<a href=')));
    expect(find.text('链接'), findsOneWidget);
  });

  testWidgets('MarkdownWithCodeHighlight keeps p tag spacing compact', (
    tester,
  ) async {
    await tester.pumpWidget(
      _markdownHarness('''
<p>这是一个 HTML 段落。</p>

<p>同一个 HTML 段落里的第一行<br>这里应该换到第二行。</p>
'''),
    );
    await tester.pump();

    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    final plainText = richTexts.map((w) => w.text.toPlainText()).join('\n');

    expect(plainText, contains('这是一个 HTML 段落。\n\n同一个 HTML 段落里的第一行'));
    expect(plainText, isNot(contains('这是一个 HTML 段落。\n\n\n同一个 HTML 段落里的第一行')));
  });

  testWidgets('MarkdownWithCodeHighlight keeps p to markdown spacing compact', (
    tester,
  ) async {
    await tester.pumpWidget(
      _markdownHarness('''
<p>同一个 HTML 段落里的第一行<br>这里应该换到第二行。</p>

这里是普通 Markdown 链接：[Kelivo GitHub](https://github.com/kelivo/Kelivo)
'''),
    );
    await tester.pump();

    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    final plainText = richTexts.map((w) => w.text.toPlainText()).join('\n');

    expect(plainText, contains('这里应该换到第二行。\n\n这里是普通 Markdown 链接'));
    expect(plainText, isNot(contains('这里应该换到第二行。\n\n\n这里是普通 Markdown 链接')));
  });

  testWidgets('MarkdownWithCodeHighlight animates details collapse', (
    tester,
  ) async {
    await tester.pumpWidget(
      _markdownHarness('<details><summary>更多信息</summary>隐藏内容</details>'),
    );
    await tester.pump();

    expect(find.text('隐藏内容', findRichText: true), findsNothing);

    await tester.tap(find.text('更多信息'));
    await tester.pumpAndSettle();

    expect(find.text('隐藏内容', findRichText: true), findsOneWidget);

    await tester.tap(find.text('更多信息'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('隐藏内容', findRichText: true), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('隐藏内容', findRichText: true), findsNothing);
  });

  testWidgets('MarkdownWithCodeHighlight stretches short details body', (
    tester,
  ) async {
    await tester.pumpWidget(
      _markdownHarness(
        '<details open><summary>短内容</summary>短</details>',
        width: 360,
      ),
    );
    await tester.pump();

    final expandedSize = tester.getSize(
      find.byKey(const ValueKey('details-expanded')),
    );

    expect(expandedSize.width, closeTo(360, 2));
  });

  testWidgets(
    'MarkdownWithCodeHighlight keeps full details around code blocks',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness('''
这里是 HTML 链接：<a href="https://example.com">Example HTML link</a>

<details>
<summary>点击展开：次要信息</summary>

这里是折叠内容的第一段。

- details 内的 Markdown 列表
- details 内的 **加粗文本**

```dart
void main() {
  print('code block inside details');
}
```
</details>

<details open>
<summary>默认展开：open 属性</summary>

这一块带有 `open` 属性，初始状态应该直接展开。
</details>
'''),
      );
      await tester.pump();

      expect(find.text('Example HTML link'), findsOneWidget);
      expect(find.text('点击展开：次要信息'), findsOneWidget);
      expect(find.text('默认展开：open 属性'), findsOneWidget);
      expect(find.text('这一块带有 ', findRichText: true), findsNothing);
      expect(find.text('这里是折叠内容的第一段。', findRichText: true), findsNothing);

      await tester.tap(find.text('点击展开：次要信息'));
      await tester.pumpAndSettle();

      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final plainText = richTexts.map((w) => w.text.toPlainText()).join('\n');

      expect(plainText, contains('这里是折叠内容的第一段。'));
      expect(plainText, contains('details 内的 Markdown 列表'));
      expect(
        find.textContaining("print('code block inside details');"),
        findsOneWidget,
      );
      expect(plainText, isNot(contains('<details>')));
      expect(plainText, isNot(contains('<a href=')));
    },
  );
}
