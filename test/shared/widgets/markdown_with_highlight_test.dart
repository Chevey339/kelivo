import 'dart:async';

import 'package:Kelivo/features/chat/pages/image_viewer_page.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:Kelivo/shared/widgets/export_capture_scope.dart';
import 'package:Kelivo/shared/widgets/mermaid_image_cache.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/palettes.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart' show TexEncoderExt;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _findMathWidget() {
  return find.byType(Math);
}

List<Math> _mathWidgets(WidgetTester tester) {
  return tester.widgetList<Math>(_findMathWidget()).toList();
}

List<String> _encodedMathTex(WidgetTester tester) {
  return _mathWidgets(
    tester,
  ).map((widget) => widget.ast?.greenRoot.encodeTeX() ?? '').toList();
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

class _ResolvedTextSpan {
  const _ResolvedTextSpan(this.text, this.style);

  final String text;
  final TextStyle style;
}

List<_ResolvedTextSpan> _collectResolvedTextSpans(
  InlineSpan span, [
  TextStyle? inheritedStyle,
]) {
  if (span is! TextSpan) return const [];

  final effectiveStyle =
      inheritedStyle?.merge(span.style) ?? span.style ?? const TextStyle();
  final spans = <_ResolvedTextSpan>[];
  final text = span.text;
  if (text != null && text.isNotEmpty) {
    spans.add(_ResolvedTextSpan(text, effectiveStyle));
  }
  final children = span.children;
  if (children != null) {
    for (final child in children) {
      spans.addAll(_collectResolvedTextSpans(child, effectiveStyle));
    }
  }
  return spans;
}

List<_ResolvedTextSpan> _resolvedTextSpansFromRichText(WidgetTester tester) {
  final spans = <_ResolvedTextSpan>[];
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    spans.addAll(_collectResolvedTextSpans(richText.text));
  }
  return spans;
}

RenderParagraph _paragraphContaining(String text) {
  return find
      .byType(RichText)
      .evaluate()
      .map((element) => element.renderObject)
      .whereType<RenderParagraph>()
      .firstWhere((paragraph) => paragraph.text.toPlainText().contains(text));
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

const _secondPngBytes = <int>[
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
  0xFC,
  0xCF,
  0xC0,
  0xF0,
  0x9F,
  0x81,
  0x81,
  0x01,
  0x00,
  0x07,
  0x18,
  0x02,
  0x03,
  0x51,
  0xBA,
  0xC4,
  0xDD,
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

List<int> _displayedImageBytes(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image));
  final provider = image.image;
  expect(provider, isA<MemoryImage>());
  return (provider as MemoryImage).bytes;
}

Widget _markdownHarness(
  String text, {
  double? width,
  bool streaming = false,
  Map<String, Object>? preferences,
  void Function(String id)? onCitationTap,
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode? themeMode,
}) {
  SharedPreferences.setMockInitialValues(preferences ?? {});
  return ChangeNotifierProvider(
    create: (_) => SettingsProvider(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: Scaffold(
        body: width == null
            ? MarkdownWithCodeHighlight(
                text: text,
                streaming: streaming,
                onCitationTap: onCitationTap,
              )
            : Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: MarkdownWithCodeHighlight(
                    text: text,
                    streaming: streaming,
                    onCitationTap: onCitationTap,
                  ),
                ),
              ),
      ),
    ),
  );
}

void _overrideMarkdownTablePlatform(TargetPlatform platform) {
  markdownTableTargetPlatformOverride = platform;
  addTearDown(() => markdownTableTargetPlatformOverride = null);
}

Widget _streamingMarkdownHarness(
  ValueListenable<String> text, {
  double? width,
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
          builder: (context, value, _) {
            final child = MarkdownWithCodeHighlight(
              text: value,
              streaming: true,
            );
            return width == null
                ? child
                : Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(width: width, child: child),
                  );
          },
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
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('markdown table markdown copy keeps pipe table syntax', () {
    final markdown = markdownTableRowsToMarkdownForTesting([
      ['Name', 'Note', 'Multiline'],
      ['Alice', 'plain', 'first\nsecond'],
      ['Bob | Jr.', 'said "hello"', ''],
    ]);

    expect(
      markdown,
      '| Name | Note | Multiline |\n'
      '| --- | --- | --- |\n'
      '| Alice | plain | first<br>second |\n'
      '| Bob \\| Jr. | said "hello" |  |',
    );
  });

  testWidgets(
    'MarkdownWithCodeHighlight renders grouped raw citation metadata as separate capsules',
    (tester) async {
      final tapped = <String>[];

      await tester.pumpWidget(
        _markdownHarness(
          '包含 3,000 万毫秒/月 [citation:1:96d0ed, 4:5675a3]',
          width: 360,
          onCitationTap: tapped.add,
        ),
      );
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.textContaining('citation:1:96d0ed'), findsNothing);

      await tester.tap(find.text('1'));
      await tester.tap(find.text('4'));

      expect(tapped, ['96d0ed', '5675a3']);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight renders shorthand raw citation metadata by index',
    (tester) async {
      final tapped = <String>[];

      await tester.pumpWidget(
        _markdownHarness(
          '参考这个结论 [citation:2]',
          width: 360,
          onCitationTap: tapped.add,
        ),
      );
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.textContaining('citation:2'), findsNothing);

      await tester.tap(find.text('2'));

      expect(tapped, ['2']);
    },
  );

  testWidgets('MarkdownWithCodeHighlight keeps citation metadata inside code', (
    tester,
  ) async {
    await tester.pumpWidget(
      _markdownHarness('`[citation:1:96d0ed]`', width: 360),
    );
    await tester.pump();

    expect(find.textContaining('citation:1:96d0ed'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets(
    'MarkdownWithCodeHighlight keeps citation-labeled normal links as links',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness('[citation](https://example.com)', width: 360),
      );
      await tester.pump();

      expect(find.text('citation'), findsOneWidget);
      expect(find.text('https'), findsNothing);
    },
  );

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
    _overrideMarkdownTablePlatform(TargetPlatform.android);
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
    expect(find.byTooltip('Save to Gallery'), findsOneWidget);
    final tableBlock = find.byKey(const ValueKey('markdown-table-block'));
    final richTextPlainText = tester
        .widgetList<RichText>(
          find.descendant(of: tableBlock, matching: find.byType(RichText)),
        )
        .map((widget) => widget.text.toPlainText());
    final selectablePlainText = tester
        .widgetList<SelectableText>(
          find.descendant(
            of: tableBlock,
            matching: find.byType(SelectableText),
          ),
        )
        .map((widget) => widget.textSpan?.toPlainText() ?? widget.data ?? '');
    final plainText = [...richTextPlainText, ...selectablePlainText].join('\n');
    expect(plainText, contains('Name'));
    expect(plainText, contains('42'));
  });

  testWidgets('MarkdownWithCodeHighlight expands compact tables for export', (
    tester,
  ) async {
    _overrideMarkdownTablePlatform(TargetPlatform.android);
    await tester.pumpWidget(
      _settingsHarness(
        onSettingsReady: (_) {},
        child: const SizedBox(
          width: 320,
          child: ExportCaptureScope(
            enabled: true,
            child: MarkdownWithCodeHighlight(
              text: '''
| One | Two | Three | Four | Five |
| - | - | - | - | - |
| Alpha | Beta | Gamma | Delta | Epsilon |
''',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('markdown-table-horizontal-scroll')),
      findsNothing,
    );
  });

  testWidgets('MarkdownWithCodeHighlight keeps table actions out of body', (
    tester,
  ) async {
    _overrideMarkdownTablePlatform(TargetPlatform.android);
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

  testWidgets('MarkdownWithCodeHighlight copies markdown table syntax', (
    tester,
  ) async {
    _overrideMarkdownTablePlatform(TargetPlatform.android);
    String? clipboardText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final data = Map<String, dynamic>.from(call.arguments as Map);
            clipboardText = data['text'] as String?;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      _markdownHarness('''
| Name | Value |
| - | - |
| Alpha | Beta |
''', width: 360),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Copy'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    expect(
      clipboardText,
      '| Name | Value |\n'
      '| --- | --- |\n'
      '| Alpha | Beta |',
    );
  });

  testWidgets('MarkdownWithCodeHighlight centers padded table cells', (
    tester,
  ) async {
    _overrideMarkdownTablePlatform(TargetPlatform.android);
    await tester.pumpWidget(
      _markdownHarness('''
| 项目 | 状态 |
| :---: | :---: |
| 单字 |   中   |
''', width: 360),
    );
    await tester.pump();

    final body = find.byKey(const ValueKey('markdown-table-body'));
    expect(body, findsOneWidget);
    final bodyRect = tester.getRect(body);
    final expectedSecondColumnCenter = bodyRect.left + bodyRect.width * 0.75;
    final centeredCellText = find.descendant(
      of: body,
      matching: find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText() == '中',
        description: 'centered table cell text',
      ),
    );
    expect(centeredCellText, findsOneWidget);

    expect(
      (tester.getCenter(centeredCellText).dx - expectedSecondColumnCenter)
          .abs(),
      lessThan(1.0),
    );
  });

  testWidgets('MarkdownWithCodeHighlight does not scroll narrow table', (
    tester,
  ) async {
    _overrideMarkdownTablePlatform(TargetPlatform.android);
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

  testWidgets(
    'MarkdownWithCodeHighlight does not scroll three-column narrow table',
    (tester) async {
      _overrideMarkdownTablePlatform(TargetPlatform.android);
      await tester.pumpWidget(
        _markdownHarness('''
| Name | Value | Note |
| - | - | - |
| A | B | C |
''', width: 320),
      );
      await tester.pump();

      final tableBlock = find.byKey(const ValueKey('markdown-table-block'));
      expect(tableBlock, findsOneWidget);
      expect(
        find.descendant(
          of: tableBlock,
          matching: find.byKey(
            const ValueKey('markdown-table-horizontal-scroll'),
          ),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight saves table image on image action tap',
    (tester) async {
      _overrideMarkdownTablePlatform(TargetPlatform.android);
      var savedToGallery = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('image_gallery_saver_plus'),
            (call) async {
              if (call.method == 'saveImageToGallery') {
                savedToGallery = true;
                return <String, Object>{'isSuccess': true};
              }
              return null;
            },
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('image_gallery_saver_plus'),
              null,
            );
      });

      await tester.pumpWidget(
        _markdownHarness('''
| Name | Value |
| - | - |
| Alpha | 42 |
''', width: 360),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Save to Gallery'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(seconds: 4));

      expect(savedToGallery, isTrue);
    },
  );

  testWidgets('MarkdownWithCodeHighlight scrolls only overflowing table', (
    tester,
  ) async {
    _overrideMarkdownTablePlatform(TargetPlatform.android);
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
    'MarkdownWithCodeHighlight keeps a streaming table stable while a row grows',
    (tester) async {
      const prefix = '''
| 类型 | 示例 | 说明 |
| :--- | :--- | :--- |
| 链接 | [点击](https://example.com) | 表格内链接 |
| 代码 | `code` | 表格内行内代码 |
| 加粗 | **重要** | 表格内加粗文字 |
| 混合 | `代码` 和 **加粗** | 表格内混合样式 |

| 测试类别 | 项目数 | 状态 |
| :------- | :----: | :--: |
| 标题层级 |   6    |  ⬜  |''';
      final text = ValueNotifier<String>('$prefix\n| 文本样式 |');
      addTearDown(text.dispose);

      await tester.pumpWidget(_streamingMarkdownHarness(text, width: 360));
      await tester.pump();
      text.value = '$prefix\n| 文本样式 |   7';
      await tester.pump();

      final bodies = find.byKey(const ValueKey('markdown-table-body'));
      expect(bodies, findsNWidgets(2));
      final secondBody = bodies.last;
      final tableText = tester
          .widgetList<RichText>(
            find.descendant(of: secondBody, matching: find.byType(RichText)),
          )
          .map((widget) => widget.text.toPlainText())
          .join('\n');
      final allText = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((widget) => widget.text.toPlainText())
          .join('\n');

      expect(tableText, contains('文本样式'));
      expect(tableText, contains('7'));
      expect(allText, isNot(contains('| 文本样式 |   7')));
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps a bare streaming table row pipe in table layout',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(
          '''
| 测试类别 | 项目数 | 状态 |
| :------- | :----: | :--: |
| 标题层级 |   6    |  ⬜  |
|''',
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

      expect(tableText, isNot(contains('|')));
      expect(allText.replaceAll(tableText, ''), isNot(contains('|')));
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps a following streaming table header in table layout',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(
          '''
| 类型 | 示例 | 说明 |
| :--- | :--- | :--- |
| 链接 | [点击](https://example.com) | 表格内链接 |

| 测试类别 | 项目数 | 状态 |''',
          width: 360,
          streaming: true,
        ),
      );
      await tester.pump();

      final bodies = find.byKey(const ValueKey('markdown-table-body'));
      expect(bodies, findsNWidgets(2));
      final allText = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((widget) => widget.text.toPlainText())
          .join('\n');

      expect(allText, isNot(contains('| 测试类别 | 项目数 | 状态 |')));
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps a following streaming table partial divider in table layout',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(
          '''
| 类型 | 示例 | 说明 |
| :--- | :--- | :--- |
| 链接 | [点击](https://example.com) | 表格内链接 |

| 测试类别 | 项目数 | 状态 |
| :------- | :----''',
          width: 360,
          streaming: true,
        ),
      );
      await tester.pump();

      final bodies = find.byKey(const ValueKey('markdown-table-body'));
      expect(bodies, findsNWidgets(2));
      final allText = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((widget) => widget.text.toPlainText())
          .join('\n');

      expect(allText, isNot(contains('| 测试类别 | 项目数 | 状态 |')));
      expect(allText, isNot(contains('| :------- | :----')));
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps streaming table starts out of plain markdown text',
    (tester) async {
      const firstTable = '''
| 类型 | 示例 | 说明 |
| :--- | :--- | :--- |
| 链接 | [点击](https://example.com) | 表格内链接 |
| 代码 | `code` | 表格内行内代码 |
| 加粗 | **重要** | 表格内加粗文字 |
| 混合 | `代码` 和 **加粗** | 表格内混合样式 |''';
      final text = ValueNotifier<String>('|');
      addTearDown(text.dispose);

      await tester.pumpWidget(_streamingMarkdownHarness(text, width: 360));
      for (final frame in <String>[
        '| 类型',
        '| 类型 |',
        '| 类型 | 示例',
        '| 类型 | 示例 |',
        firstTable,
        '$firstTable\n\n|',
        '$firstTable\n\n| 测试类别',
        '$firstTable\n\n| 测试类别 |',
        '$firstTable\n\n| 测试类别 | 项目数',
        '$firstTable\n\n| 测试类别 | 项目数 |',
        '$firstTable\n\n| 测试类别 | 项目数 | 状态',
        '$firstTable\n\n| 测试类别 | 项目数 | 状态 |',
      ]) {
        text.value = frame;
        await tester.pump();

        final allText = tester
            .widgetList<RichText>(find.byType(RichText))
            .map((widget) => widget.text.toPlainText())
            .join('\n');

        expect(
          allText,
          isNot(contains('|')),
          reason: 'streaming frame should not expose markdown pipes: $frame',
        );
      }
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps rich table rows stable while inline markdown grows',
    (tester) async {
      const prefix = '''
### 4. 表格中的特殊内容

| 类型 | 示例 | 说明 |
| :--- | :--- | :--- |
| 链接 | [点击](https://example.com) | 表格内链接 |
| 代码 | `code` | 表格内行内代码 |
| 加粗 | **重要** | 表格内加粗文字 |''';
      final text = ValueNotifier<String>('$prefix\n| 混合 |');
      addTearDown(text.dispose);

      await tester.pumpWidget(_streamingMarkdownHarness(text, width: 360));
      for (final frame in <String>[
        '$prefix\n| 混合 | `',
        '$prefix\n| 混合 | `代码',
        '$prefix\n| 混合 | `代码`',
        '$prefix\n| 混合 | `代码` 和 **',
        '$prefix\n| 混合 | `代码` 和 **加粗',
        '$prefix\n| 混合 | `代码` 和 **加粗**',
        '$prefix\n| 混合 | `代码` 和 **加粗** |',
        '$prefix\n| 混合 | `代码` 和 **加粗** | 表格内混合样式',
      ]) {
        text.value = frame;
        await tester.pump();

        final body = find.byKey(const ValueKey('markdown-table-body'));
        expect(body, findsOneWidget, reason: frame);
        final allText = tester
            .widgetList<RichText>(find.byType(RichText))
            .map((widget) => widget.text.toPlainText())
            .join('\n');

        expect(
          allText,
          isNot(contains('| 混合')),
          reason: 'rich table row should not leak markdown pipes: $frame',
        );
      }
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight renders light default blockquote line as gray',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(
          '> 引用内容\n> 第二行',
          width: 320,
          theme: buildLightThemeForScheme(ThemePalettes.defaultPalette.light),
        ),
      );
      await tester.pump();

      final blockquote = find.byKey(const ValueKey('markdown-blockquote'));
      expect(blockquote, findsOneWidget);

      final blockquoteWidget = tester.widget<Container>(blockquote);
      expect(blockquoteWidget.color, isNull);
      expect(blockquoteWidget.decoration, isNull);

      final line = find.descendant(
        of: blockquote,
        matching: find.byKey(const ValueKey('markdown-blockquote-line')),
      );
      expect(line, findsOneWidget);
      expect(tester.getSize(line).width, 3);

      final lineDecoration =
          tester.widget<DecoratedBox>(line).decoration as BoxDecoration;
      final cs = Theme.of(tester.element(blockquote)).colorScheme;
      expect(lineDecoration.color, cs.onSurfaceVariant.withValues(alpha: 0.36));
      expect(
        lineDecoration.color,
        isNot(cs.outlineVariant.withValues(alpha: 0.82)),
      );
      expect(lineDecoration.borderRadius, BorderRadius.circular(2));
      expect(lineDecoration.border, isNull);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps dark default blockquote line gray',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(
          '> 引用内容\n> 第二行',
          width: 320,
          theme: buildLightThemeForScheme(ThemePalettes.defaultPalette.light),
          darkTheme: buildDarkThemeForScheme(ThemePalettes.defaultPalette.dark),
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pump();

      final blockquote = find.byKey(const ValueKey('markdown-blockquote'));
      expect(blockquote, findsOneWidget);

      final line = find.descendant(
        of: blockquote,
        matching: find.byKey(const ValueKey('markdown-blockquote-line')),
      );
      expect(line, findsOneWidget);

      final lineDecoration =
          tester.widget<DecoratedBox>(line).decoration as BoxDecoration;
      final cs = Theme.of(tester.element(blockquote)).colorScheme;
      expect(lineDecoration.color, cs.onSurfaceVariant.withValues(alpha: 0.48));
      expect(lineDecoration.borderRadius, BorderRadius.circular(2));
      expect(lineDecoration.border, isNull);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps late document tables stable after code blocks',
    (tester) async {
      const prefix = r'''
# Markdown 渲染能力测试文档

## 七、代码与语法高亮

```python
def fibonacci(n):
    return n
```

```javascript
const greet = (name) => {
  return `Hello, ${name}!`;
};
```

```html
<div class="container">
  <p>这是一个段落。</p>
</div>
```

```json
{
  "features": ["headings", "lists", "tables", "code"]
}
```

## 十、复杂混合布局

### 3. 引用中的代码

> 在引用中插入代码：
>
> ```bash
> echo "Hello from inside a blockquote!"
> ```

### 4. 表格中的特殊内容

| 类型 | 示例 | 说明 |
| :--- | :--- | :--- |
| 链接 | [点击](https://example.com) | 表格内链接 |
| 代码 | `code` | 表格内行内代码 |
| 加粗 | **重要** | 表格内加粗文字 |''';
      final text = ValueNotifier<String>('$prefix\n| 混合 |');
      addTearDown(text.dispose);

      await tester.pumpWidget(_streamingMarkdownHarness(text, width: 360));
      for (final frame in <String>[
        '$prefix\n| 混合 | `代码` 和 **加粗** |',
        '$prefix\n| 混合 | `代码` 和 **加粗** | 表格内混合样式',
        '$prefix\n| 混合 | `代码` 和 **加粗** | 表格内混合样式 |',
        '$prefix\n| 混合 | `代码` 和 **加粗** | 表格内混合样式 |\n\n## 总结\n\n| 测试类别',
        '$prefix\n| 混合 | `代码` 和 **加粗** | 表格内混合样式 |\n\n## 总结\n\n| 测试类别 | 项目数 | 状态 |\n| :------- | :----: | :--: |\n| 特殊符号 |   4',
      ]) {
        text.value = frame;
        await tester.pump();

        final allText = tester
            .widgetList<RichText>(find.byType(RichText))
            .map((widget) => widget.text.toPlainText())
            .join('\n');
        final codeText = tester
            .widgetList<SelectableText>(
              find.descendant(
                of: find.byType(SelectableHighlightView),
                matching: find.byType(SelectableText),
              ),
            )
            .map((widget) => widget.textSpan?.toPlainText() ?? widget.data)
            .join('\n');
        final blockquote = find.byKey(const ValueKey('markdown-blockquote'));
        final blockquoteCodeText = tester
            .widgetList<SelectableText>(
              find.descendant(
                of: blockquote,
                matching: find.byType(SelectableText),
              ),
            )
            .map((widget) => widget.textSpan?.toPlainText() ?? widget.data)
            .join('\n');

        expect(allText, isNot(contains('| 混合')), reason: frame);
        expect(allText, isNot(contains('| 测试类别')), reason: frame);
        expect(allText, isNot(contains('| 特殊符号')), reason: frame);
        expect(
          find.descendant(
            of: blockquote,
            matching: find.byType(SelectableHighlightView),
          ),
          findsOneWidget,
          reason: frame,
        );
        expect(
          blockquoteCodeText,
          contains('echo "Hello from inside a blockquote!"'),
        );
        expect(blockquoteCodeText, isNot(contains('表格中的特殊内容')), reason: frame);
        expect(codeText, isNot(contains('表格中的特殊内容')), reason: frame);
        expect(codeText, isNot(contains('## 总结')), reason: frame);
      }
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps quoted fences literal inside normal code blocks',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(r'''
```markdown
> ```bash
> echo "inside example"
> ```
```
'''),
      );
      await tester.pump();

      final codeText = tester
          .widgetList<SelectableText>(
            find.descendant(
              of: find.byType(SelectableHighlightView),
              matching: find.byType(SelectableText),
            ),
          )
          .map((widget) => widget.textSpan?.toPlainText() ?? widget.data)
          .join('\n');

      expect(codeText, contains('> ```bash'));
      expect(codeText, contains('> ```'));
      expect(codeText, isNot(contains('\uE000')));
      expect(codeText, isNot(contains('\uE001')));
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps list-started code fences protected',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(r'''
- ```dart
final value = "$foo$";
```
'''),
      );
      await tester.pump();

      final codeText = tester
          .widgetList<SelectableText>(
            find.descendant(
              of: find.byType(SelectableHighlightView),
              matching: find.byType(SelectableText),
            ),
          )
          .map((widget) => widget.textSpan?.toPlainText() ?? widget.data)
          .join('\n');

      expect(_findMathWidget(), findsNothing);
      expect(codeText, contains(r'final value = "$foo$";'));
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
    'MarkdownWithCodeHighlight frames cached Mermaid image in preview shell',
    (tester) async {
      addTearDown(MermaidImageCache.clear);
      const code = 'graph TD\nA-->B';
      MermaidImageCache.put(code, Uint8List.fromList(_transparentPngBytes));

      await tester.pumpWidget(
        _markdownHarness('''
```mermaid
$code
```'''),
      );
      await tester.pump();

      expect(find.text('Image'), findsOneWidget);
      expect(find.text('Code'), findsOneWidget);
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Export PNG'), findsNothing);
      expect(find.text('Full screen'), findsNothing);
      expect(find.byTooltip('Copy'), findsOneWidget);
      expect(find.byTooltip('Export PNG'), findsOneWidget);
      expect(find.byTooltip('Full screen'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('mermaid-preview-body')))
            .height,
        406,
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.textContaining('graph TD'), findsNothing);
    },
  );

  testWidgets('MarkdownWithCodeHighlight disables selection for Mermaid tabs', (
    tester,
  ) async {
    addTearDown(MermaidImageCache.clear);
    const code = 'graph TD\nA-->B';
    MermaidImageCache.put(code, Uint8List.fromList(_transparentPngBytes));

    await tester.pumpWidget(
      _markdownHarness('''
```mermaid
$code
```'''),
    );
    await tester.pump();

    for (final label in ['Image', 'Code']) {
      final selectionContainers = find.ancestor(
        of: find.text(label),
        matching: find.byType(SelectionContainer),
      );

      expect(
        tester
            .widgetList<SelectionContainer>(selectionContainers)
            .any((widget) => widget.delegate == null),
        isTrue,
      );
    }
  });

  testWidgets(
    'MarkdownWithCodeHighlight opens Mermaid image from preview tap',
    (tester) async {
      addTearDown(MermaidImageCache.clear);
      const code = 'graph TD\nA-->B';
      MermaidImageCache.put(code, Uint8List.fromList(_transparentPngBytes));

      await tester.pumpWidget(
        _markdownHarness('''
```mermaid
$code
```'''),
      );
      await tester.pump();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      expect(find.byType(ImageViewerPage), findsOneWidget);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight pins Mermaid actions to trailing edge on wide layouts',
    (tester) async {
      addTearDown(MermaidImageCache.clear);
      const code = 'graph TD\nA-->B';
      MermaidImageCache.put(code, Uint8List.fromList(_transparentPngBytes));

      await tester.pumpWidget(
        _markdownHarness('''
```mermaid
$code
```''', width: 800),
      );
      await tester.pump();

      final bodyRight = tester
          .getTopRight(find.byKey(const ValueKey('mermaid-preview-body')))
          .dx;
      final fullScreenRight = tester
          .getTopRight(find.byTooltip('Full screen'))
          .dx;

      expect(bodyRight - fullScreenRight, lessThanOrEqualTo(14));
    },
  );

  testWidgets('MarkdownWithCodeHighlight toggles Mermaid image and code tabs', (
    tester,
  ) async {
    addTearDown(MermaidImageCache.clear);
    const code = 'graph TD\nA-->B';
    MermaidImageCache.put(code, Uint8List.fromList(_transparentPngBytes));

    await tester.pumpWidget(
      _markdownHarness('''
```mermaid
$code
```'''),
    );
    await tester.pump();

    await tester.tap(find.text('Code'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('graph TD'), findsOneWidget);

    await tester.tap(find.text('Image'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('graph TD'), findsNothing);
  });

  testWidgets(
    'MarkdownWithCodeHighlight shows fixed Mermaid loading state while rendering',
    (tester) async {
      addTearDown(MermaidImageCache.clear);
      addTearDown(() => debugMermaidBitmapRenderOverride = null);
      debugMermaidBitmapRenderOverride = (code, isDark, themeVars) {
        return Completer<MermaidBitmapRenderResult>().future;
      };

      await tester.pumpWidget(
        _markdownHarness('''
```mermaid
graph TD
A-->B
```'''),
      );
      await tester.pump(const Duration(milliseconds: 240));

      expect(
        tester
            .getSize(find.byKey(const ValueKey('mermaid-preview-body')))
            .height,
        406,
      );
      expect(find.text('Generating image'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('graph TD'), findsNothing);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight shows Mermaid error preview after render failure',
    (tester) async {
      addTearDown(MermaidImageCache.clear);
      addTearDown(() => debugMermaidBitmapRenderOverride = null);
      debugMermaidBitmapRenderOverride = (code, isDark, themeVars) async {
        return MermaidBitmapRenderResult.failed();
      };

      await tester.pumpWidget(
        _markdownHarness('''
```mermaid
graph TD
A-->
```'''),
      );
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pump();

      expect(
        find.text('Generation failed. Try asking another way.'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('graph TD'), findsNothing);

      await tester.tap(find.text('Code'));
      await tester.pumpAndSettle();

      expect(find.textContaining('graph TD'), findsOneWidget);
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
    'MarkdownWithCodeHighlight keeps previous Mermaid bitmap visible until streaming render succeeds',
    (tester) async {
      addTearDown(MermaidImageCache.clear);
      addTearDown(() => debugMermaidBitmapRenderOverride = null);
      const firstCode = 'graph TD\nA-->B';
      MermaidImageCache.put(
        firstCode,
        Uint8List.fromList(_transparentPngBytes),
      );
      final renderStarted = Completer<void>();
      final renderCanFinish = Completer<void>();
      debugMermaidBitmapRenderOverride = (code, isDark, themeVars) async {
        if (!renderStarted.isCompleted) renderStarted.complete();
        await renderCanFinish.future;
        return MermaidBitmapRenderResult.success(
          Uint8List.fromList(_secondPngBytes),
        );
      };
      final text = ValueNotifier<String>('''
```mermaid
$firstCode
''');

      await tester.pumpWidget(_streamingMarkdownHarness(text));
      await tester.pump();
      expect(_displayedImageBytes(tester), _transparentPngBytes);

      text.value =
          '''
```mermaid
$firstCode
B-->C
''';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await renderStarted.future;

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(_displayedImageBytes(tester), _transparentPngBytes);

      renderCanFinish.complete();
      await tester.pump();
      await tester.pump();

      expect(_displayedImageBytes(tester), _secondPngBytes);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps previous Mermaid bitmap when streaming render fails',
    (tester) async {
      addTearDown(MermaidImageCache.clear);
      addTearDown(() => debugMermaidBitmapRenderOverride = null);
      const firstCode = 'graph TD\nA-->B';
      MermaidImageCache.put(
        firstCode,
        Uint8List.fromList(_transparentPngBytes),
      );
      debugMermaidBitmapRenderOverride = (code, isDark, themeVars) async {
        return MermaidBitmapRenderResult.failed();
      };
      final text = ValueNotifier<String>('''
```mermaid
$firstCode
''');

      await tester.pumpWidget(_streamingMarkdownHarness(text));
      await tester.pump();
      expect(_displayedImageBytes(tester), _transparentPngBytes);

      text.value =
          '''
```mermaid
$firstCode
B-->
''';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(_displayedImageBytes(tester), _transparentPngBytes);

      text.value = String.fromCharCodes(text.value.codeUnits);
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(_displayedImageBytes(tester), _transparentPngBytes);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight shows Mermaid code when bitmap rendering is unsupported',
    (tester) async {
      addTearDown(MermaidImageCache.clear);
      addTearDown(() => debugMermaidBitmapRenderOverride = null);
      MermaidImageCache.clear();
      debugMermaidBitmapRenderOverride = (code, isDark, themeVars) async {
        return MermaidBitmapRenderResult.unsupported();
      };

      await tester.pumpWidget(
        _markdownHarness('''
```mermaid
graph TD
A-->B
''', streaming: true),
      );
      await tester.pump();
      expect(find.text('Generating image'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('Generating image'), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('graph TD'), findsOneWidget);
      expect(find.text('Open Preview'), findsNothing);
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
    'MarkdownWithCodeHighlight keeps escaped and math pipes inside table cells',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(r'''
| 项目 | 左对齐 | 居中 | 右对齐 |
| :--- | :--- | :---: | ---: |
| 普通文本 | alpha | beta | 123 |
| 粗斜代码 | **bold** | *italic* | `code` |
| 转义竖线 | a \| b | c \| d | 456 |
| 行内数学 | $a+b$ | $\|x\|=1$ | $P(A\mid B)$ |
'''),
      );
      await tester.pump();

      final table = tester.widget<Table>(find.byType(Table).first);
      expect(table.children, hasLength(5));
      expect(table.children.map((row) => row.children.length), everyElement(4));
      expect(_findMathWidget(), findsNWidgets(3));

      final richTextPlainText = tester
          .widgetList<RichText>(
            find.descendant(
              of: find.byType(Table),
              matching: find.byType(RichText),
            ),
          )
          .map((widget) => widget.text.toPlainText());
      final selectablePlainText = tester
          .widgetList<SelectableText>(
            find.descendant(
              of: find.byType(Table),
              matching: find.byType(SelectableText),
            ),
          )
          .map((widget) => widget.textSpan?.toPlainText() ?? widget.data ?? '');
      final tableText = [
        ...richTextPlainText,
        ...selectablePlainText,
      ].join('\n');

      expect(tableText, contains('a | b'));
      expect(tableText, contains('c | d'));
      expect(tableText, isNot(contains(r'a \| b')));
      expect(tableText, isNot(contains(r'c \| d')));
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps dollar signs inside table code',
    (tester) async {
      _overrideMarkdownTablePlatform(TargetPlatform.android);
      await tester.pumpWidget(
        _markdownHarness(r'''
| 对比点 | 行内 `$...$` | 行间 `$$...$$` |
|--------|-------------|---------------|
| 是否换行 | 不换行 | 换行 |
''', width: 360),
      );
      await tester.pump();

      final tableBlock = find.byKey(const ValueKey('markdown-table-block'));
      expect(tableBlock, findsOneWidget);
      final richTextPlainText = tester
          .widgetList<RichText>(
            find.descendant(of: tableBlock, matching: find.byType(RichText)),
          )
          .map((widget) => widget.text.toPlainText());
      final selectablePlainText = tester
          .widgetList<SelectableText>(
            find.descendant(
              of: tableBlock,
              matching: find.byType(SelectableText),
            ),
          )
          .map((widget) => widget.textSpan?.toPlainText() ?? widget.data ?? '');
      final plainText = [
        ...richTextPlainText,
        ...selectablePlainText,
      ].join('\n');

      expect(plainText, contains(r'$...$'));
      expect(plainText, contains(r'$$...$$'));
      expect(plainText, isNot(contains('___CODE_DOLLAR_MASK___')));
    },
  );

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

  testWidgets('MarkdownWithCodeHighlight baseline-aligns inline math', (
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
    expect(mathSpans.single.alignment, PlaceholderAlignment.baseline);
    expect(mathSpans.single.baseline, TextBaseline.alphabetic);
    expect(
      find.ancestor(
        of: _findMathWidget(),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'MarkdownWithCodeHighlight expands line height for tall inline math',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(
          r'相对论动量公式：$p = \frac{mv}{\sqrt{1 - \frac{v^2}{c^2}}}$',
        ),
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
      expect(mathSpans.single.alignment, PlaceholderAlignment.baseline);
      expect(mathSpans.single.baseline, TextBaseline.alphabetic);

      final paragraph = _paragraphContaining('相对论动量公式');
      final mathBox = tester.renderObject<RenderBox>(_findMathWidget());
      expect(mathBox.size.height, greaterThan(30));
      expect(paragraph.size.height, greaterThanOrEqualTo(mathBox.size.height));
    },
  );

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
    'MarkdownWithCodeHighlight renders list dollar math with literal pipes',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(r'''
- 向量点积：$\mathbf{a} \cdot \mathbf{b} = |\mathbf{a}||\mathbf{b}|\cos\theta$
- 矢量叉乘：$\mathbf{a} \times \mathbf{b} = |\mathbf{a}||\mathbf{b}|\sin\theta \, \hat{n}$
- Bayes 公式：$P(A|B) = \frac{P(B|A)P(A)}{P(B)}$
- 向量模长：$|\mathbf{v}| = \sqrt{v_x^2 + v_y^2 + v_z^2}$
'''),
      );
      await tester.pump();

      expect(_findMathWidget(), findsNWidgets(4));
      expect(find.textContaining(r'$\mathbf{a} \cdot'), findsNothing);
      expect(find.textContaining(r'$P(A|B)'), findsNothing);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight follows GitHub-like dollar math boundaries',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(r'''
价格 $10 不渲染。

范围$\pm 2$ 有效。

标点：$x+y$。

空格 $a+b$ 有效。
'''),
      );
      await tester.pump();

      expect(_findMathWidget(), findsNWidgets(3));
      expect(find.textContaining(r'$10'), findsOneWidget);
      expect(find.textContaining(r'$\pm 2$'), findsNothing);
      expect(find.textContaining(r'$x+y$'), findsNothing);
      expect(find.textContaining(r'$a+b$'), findsNothing);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight renders compact dollar math next to Chinese prose',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(r'（$PaCO_2$ 降至 30）范围$\pm 2$，目标$SpO_2$。'),
      );
      await tester.pump();

      expect(_findMathWidget(), findsNWidgets(3));
      expect(find.textContaining(r'$PaCO_2$'), findsNothing);
      expect(find.textContaining(r'$\pm 2$'), findsNothing);
      expect(find.textContaining(r'$SpO_2$'), findsNothing);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight renders numeric TeX dollar math without spanning prose',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(
          r'蕴含的能量高达 $9 \times 10^{16} \, \text{J}$，相当于约 2100 万吨 TNT 炸药的爆炸当量。太阳每秒将约 $4.3 \times 10^9 \, \text{kg}$ 的质量转化为能量',
        ),
      );
      await tester.pump();

      expect(_findMathWidget(), findsNWidgets(2));
      expect(find.textContaining(r'$9 \times'), findsNothing);
      expect(find.textContaining(r'$4.3 \times'), findsNothing);
      expect(find.textContaining('相当于约 2100 万吨 TNT'), findsOneWidget);
      expect(
        find.textContaining(r'，相当于约 2100 万吨 TNT 炸药的爆炸当量。太阳每秒将约 $4.3'),
        findsNothing,
      );
    },
  );

  testWidgets(r'MarkdownWithCodeHighlight renders paren math with set braces', (
    tester,
  ) async {
    await tester.pumpWidget(
      _markdownHarness(r'集合\(A = {x \in \mathbb{R} : x^2 < 4}\)等价于开区间。'),
    );
    await tester.pump();

    expect(_findMathWidget(), findsOneWidget);
    expect(find.textContaining(r'\(A ='), findsNothing);
    expect(find.textContaining('等价于开区间'), findsOneWidget);
  });

  testWidgets(
    r'MarkdownWithCodeHighlight renders dollar math with escaped set braces',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(r'集合$A = \{x \in \mathbb{R} : x^2 < 4\}$等价于开区间。'),
      );
      await tester.pump();

      final mathWidgets = _mathWidgets(tester);
      expect(mathWidgets, hasLength(1));
      expect(mathWidgets.single.parseError, isNull);
      final encoded = _encodedMathTex(tester).single;
      expect(encoded, contains(r'\{'));
      expect(encoded, contains(r'\}'));
      expect(encoded, contains(r'\mathbb{R}'));
      expect(find.textContaining(r'\(A ='), findsNothing);
      expect(find.textContaining(r'$A ='), findsNothing);
      expect(find.textContaining('等价于开区间'), findsOneWidget);
    },
  );

  testWidgets(
    r'MarkdownWithCodeHighlight keeps escaped inline delimiters literal',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(
          r'*literal\* and **strong\** and `code\` and [label\](https://example.com)',
        ),
      );
      await tester.pump();

      final spans = _resolvedTextSpansFromRichText(tester);
      final plainText = spans.map((span) => span.text).join();

      expect(
        plainText,
        contains(
          r'*literal* and **strong** and `code` and [label](https://example.com)',
        ),
      );
      expect(
        spans.where(
          (span) =>
              span.text.contains('literal') &&
              span.style.fontStyle == FontStyle.italic,
        ),
        isEmpty,
      );
      expect(
        spans.where(
          (span) =>
              span.text.contains('strong') &&
              span.style.fontWeight == FontWeight.bold,
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    r'MarkdownWithCodeHighlight renders paren math with literal special characters',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(r'''
在Markdown中#表示标题，但在公式中\(#\)是符号。
集合\({1, 2, 3}\)有三个元素。注意在LaTeX中花括号需要转义\({}\)。
序列\({a_n}_{n=1}^{\infty}\)收敛。
集合\(A = {x \in \mathbb{R} : x^2 < 4}\)等价于开区间。
'''),
      );
      await tester.pump();

      final mathWidgets = _mathWidgets(tester);
      expect(mathWidgets, hasLength(5));
      expect(
        mathWidgets.map((widget) => widget.parseError),
        everyElement(isNull),
      );
      final encoded = _encodedMathTex(tester);
      expect(encoded[0], contains(r'\#'));
      expect(encoded[1], contains(r'\{'));
      expect(encoded[1], contains(r'\}'));
      expect(encoded[2], contains(r'\{\}'));
      expect(encoded[3], contains(r'\{'));
      expect(encoded[3], contains(r'\}'));
      expect(encoded[3], contains(r'_{n=1}^{\infty}'));
      expect(encoded[4], contains(r'\{'));
      expect(encoded[4], contains(r'\}'));
      expect(encoded[4], contains(r'\mathbb{R}'));
      expect(find.textContaining(r'\(#\)'), findsNothing);
      expect(find.textContaining(r'\({1, 2, 3}\)'), findsNothing);
      expect(find.textContaining(r'\({}\)'), findsNothing);
      expect(find.textContaining(r'\({a_n}_{n=1}^{\infty}\)'), findsNothing);
      expect(find.textContaining(r'\(A = {x \in'), findsNothing);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps literal double dollars from spanning prose',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(
          r'$\&$在LaTeX中需要转义，而$$符号通常用于块级公式。后文$a$$b$$c$。$x$$=$$1$。结束',
        ),
      );
      await tester.pump();

      expect(_findMathWidget(), findsNWidgets(7));
      expect(find.textContaining('在LaTeX中需要转义'), findsOneWidget);
      expect(find.textContaining(r'$$符号通常用于块级公式。后文'), findsOneWidget);
      expect(find.textContaining(r'b$$c'), findsNothing);
      expect(find.textContaining(r'x$$=$$1'), findsNothing);
      expect(find.textContaining('结束'), findsOneWidget);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight keeps long inline math stress document stable',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(r'''
集合\(A = {x \in \mathbb{R} : x^2 < 4}\)等价于开区间$(-2, 2)$。

$\&$在LaTeX中需要转义，而$$符号通常用于块级公式。

> 费马大定理指出：当整数$n > 2$时，方程$x^n + y^n = z^n$没有正整数解。

$a$$b$$c$。$x$$=$$1$。

$f((x))$，$g([x])$，$h(\{x\})$，$\langle a, b \rangle$。
'''),
      );
      await tester.pump();

      expect(_findMathWidget(), findsAtLeastNWidgets(14));
      expect(find.textContaining(r'\(A ='), findsNothing);
      expect(find.textContaining(r'$$符号通常用于块级公式'), findsOneWidget);
      expect(find.textContaining(r'b$$c'), findsNothing);
      expect(find.textContaining(r'x$$=$$1'), findsNothing);
      expect(find.textContaining(r'$n > 2$'), findsNothing);
      expect(find.textContaining(r'$f((x))$'), findsNothing);
      expect(find.textContaining('费马大定理指出'), findsOneWidget);
      expect(find.textContaining('在LaTeX中需要转义'), findsOneWidget);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight avoids common dollar math false positives',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(r'''
价格是 $50 到 $100。
开头空格：$ PaCO_2$。
结尾空格：$PaCO_2 $。
跨行：$PaCO_2
$。
有效：$PaCO_2$。
'''),
      );
      await tester.pump();

      expect(_findMathWidget(), findsOneWidget);
      expect(find.textContaining(r'$50 到 $100'), findsOneWidget);
      expect(find.textContaining(r'$ PaCO_2$'), findsOneWidget);
      expect(find.textContaining(r'$PaCO_2 $'), findsOneWidget);
      expect(find.textContaining(r'有效：$PaCO_2$'), findsNothing);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight does not span malformed dollar math on one line',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(r'价格 $10 到 $100；开头空格 $ PaCO_2$；结尾空格 $PaCO_2 $。'),
      );
      await tester.pump();

      expect(_findMathWidget(), findsNothing);
      expect(find.textContaining(r'$10 到 $100'), findsOneWidget);
      expect(find.textContaining(r'$ PaCO_2$'), findsOneWidget);
      expect(find.textContaining(r'$PaCO_2 $'), findsOneWidget);
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
    'MarkdownWithCodeHighlight renders dollar math after Chinese punctuation',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(
          r'热力学第一定律本质上就是能量守恒定律：$\Delta U = Q - W$。其中 $Q$ 是系统吸收的热量，$W$ 是系统对外做的功，$\Delta U$ 是内能的变化。对于理想气体，其内能只与温度有关，即 $\Delta U = nC_v\Delta T$，其中 $n$ 为物质的量，$C_v$ 为定容摩尔热容。',
        ),
      );
      await tester.pump();

      expect(_findMathWidget(), findsNWidgets(7));
      expect(find.textContaining(r'$\Delta U$'), findsNothing);
      expect(find.textContaining(r'$C_v$'), findsNothing);
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
    'MarkdownWithCodeHighlight does not stall on closed streaming inline dollar math',
    (tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        _markdownHarness(r'''
**举例对比：**

- 行内：$\sum_{i=1}^{n} i$
''', streaming: true),
      );
      await tester.pump();

      stopwatch.stop();
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
      expect(_findMathWidget(), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  testWidgets(
    'MarkdownWithCodeHighlight does not stall on many unmatched inline dollar math openers',
    (tester) async {
      final text = List<String>.filled(
        2200,
        r' prose $unfinished_math_expression',
      ).join();
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(_markdownHarness(text));
      await tester.pump();

      stopwatch.stop();
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
      expect(_findMathWidget(), findsNothing);
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  testWidgets(
    r'MarkdownWithCodeHighlight does not stall on many unmatched inline paren math openers',
    (tester) async {
      final text = List<String>.filled(
        2200,
        r' prose \(unfinished_math_expression',
      ).join();
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(_markdownHarness(text));
      await tester.pump();

      stopwatch.stop();
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
      expect(_findMathWidget(), findsNothing);
    },
    timeout: const Timeout(Duration(seconds: 10)),
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

  testWidgets(
    'MarkdownWithCodeHighlight toggles auto-collapsed code block from header',
    (tester) async {
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

      expect(find.text('Expand'), findsNothing);
      expect(find.text('Collapse'), findsNothing);
      expect(
        find.byKey(const ValueKey('code-block-collapse-icon-switcher')),
        findsOneWidget,
      );
      expect(find.byIcon(Lucide.ChevronRight), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('dart')).dx,
        lessThan(tester.getTopLeft(find.byIcon(Lucide.ChevronRight)).dx),
      );
      expect(find.textContaining('line3'), findsNothing);
      expect(find.textContaining('folded'), findsNothing);

      await tester.tap(find.text('dart'));
      await tester.pumpAndSettle();

      expect(find.text('Expand'), findsNothing);
      expect(find.text('Collapse'), findsNothing);
      expect(find.byIcon(Lucide.ChevronRight), findsNothing);
      expect(find.textContaining('line3'), findsOneWidget);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight shows collapsed code tail fade when hidden lines exist',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness(
          '''
```dart
fade1
fade2
fade3
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

      expect(
        find.byKey(const ValueKey('code-block-collapsed-tail-fade')),
        findsOneWidget,
      );
      expect(find.textContaining('fade3'), findsNothing);

      await tester.tap(find.text('dart'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('code-block-collapsed-tail-fade')),
        findsNothing,
      );
      expect(find.textContaining('fade3'), findsOneWidget);
    },
  );

  testWidgets(
    'MarkdownWithCodeHighlight omits collapsed code tail fade without hidden lines',
    (tester) async {
      await tester.pumpWidget(
        _markdownHarness('''
```dart
exact1
exact2
```
'''),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('dart'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Lucide.ChevronRight), findsOneWidget);
      expect(
        find.byKey(const ValueKey('code-block-collapsed-tail-fade')),
        findsNothing,
      );
      expect(find.textContaining('exact2'), findsOneWidget);
    },
  );

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

      expect(find.text('Expand'), findsNothing);
      expect(find.text('Collapse'), findsNothing);
      expect(find.textContaining('disable3'), findsNothing);

      await settings.setAutoCollapseCodeBlock(false);
      await tester.pumpAndSettle();

      expect(find.text('Expand'), findsNothing);
      expect(find.text('Collapse'), findsNothing);
      expect(find.textContaining('disable3'), findsOneWidget);

      await tester.tap(find.text('dart'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Lucide.ChevronRight), findsOneWidget);
      expect(find.textContaining('disable3'), findsNothing);

      await tester.tap(find.text('dart'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Lucide.ChevronRight), findsNothing);
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

    expect(find.text('Expand'), findsNothing);
    expect(find.text('Collapse'), findsNothing);
    expect(find.textContaining('alpha3'), findsNothing);

    await tester.tap(find.text('dart'));
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

    expect(find.text('Expand'), findsNothing);
    expect(find.text('Collapse'), findsNothing);
    expect(find.textContaining('alpha4'), findsOneWidget);

    await tester.tap(find.text('dart'));
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

    expect(find.text('Expand'), findsNothing);
    expect(find.text('Collapse'), findsNothing);
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
        tester.getCenter(find.text('dart')),
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

      expect(find.text('Expand'), findsNothing);
      expect(find.text('Collapse'), findsNothing);
      expect(find.textContaining('press4'), findsOneWidget);

      final collapseGesture = await tester.startGesture(
        tester.getCenter(find.text('dart')),
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

      expect(find.text('Expand'), findsNothing);
      expect(find.text('Collapse'), findsNothing);
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

  testWidgets('MarkdownWithCodeHighlight normalizes strong weight on Android', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(_markdownHarness('这是 **粗体** 文本'));
      await tester.pump();

      final spans = _resolvedTextSpansFromRichText(tester);
      final strongSpan = spans.singleWhere((span) => span.text == '粗体');

      expect(strongSpan.style.fontWeight, FontWeight.w500);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
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
