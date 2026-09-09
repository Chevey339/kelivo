import 'dart:io';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/workspace/widgets/preview/code_file_preview.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:Kelivo/features/workspace/widgets/preview/preview_text_document.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../../support/business_test_harness.dart';

Widget _app(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => SettingsProvider(createBusinessTestPreferences()),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

final Finder _gutter = find.byKey(CodeFilePreview.gutterKey);
final Finder _code = find.byKey(CodeFilePreview.codeKey);

String _codeText(WidgetTester tester) =>
    tester.widget<SelectableText>(_code).textSpan!.toPlainText();

String _gutterText(WidgetTester tester) =>
    tester.widget<SelectableText>(_gutter).textSpan!.toPlainText();

Future<void> _loadPreview(WidgetTester tester) async {
  await tester.pump();
  final state = tester.state<CodeFilePreviewState>(
    find.byType(CodeFilePreview),
  );
  await tester.runAsync(state.load);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kelivo_code_preview_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('code preview renders the line count', (tester) async {
    final file = File(p.join(tempDir.path, 'lines.txt'))
      ..writeAsStringSync('one\ntwo\nthree\n');

    await tester.pumpWidget(_app(CodeFilePreview(file: file, autoLoad: false)));
    await _loadPreview(tester);

    expect(find.byKey(CodeFilePreview.lineCountKey), findsOneWidget);
    expect(find.textContaining('4'), findsWidgets);
  });

  testWidgets('code preview lazily displays files above the old size limit', (
    tester,
  ) async {
    final file = File(p.join(tempDir.path, 'huge.txt'))
      ..writeAsStringSync('0123456789' * (220 * 1024));

    await tester.pumpWidget(_app(CodeFilePreview(file: file, autoLoad: false)));
    await _loadPreview(tester);

    expect(find.byKey(CodeFilePreview.plainTextListKey), findsOneWidget);
    expect(find.byKey(CodeFilePreview.codeKey), findsNothing);
    expect(find.byType(SelectableText).evaluate().length, lessThan(10));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long files reach the final chunk and copy the original source', (
    tester,
  ) async {
    final source = '${'first 神谕 😀\r\n' * 32098}LAST-LINE\r\n';
    final file = File(p.join(tempDir.path, 'long.txt'))
      ..writeAsStringSync(source);
    final document = (await tester.runAsync(
      () => loadPreviewTextDocument(file),
    ))!;
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
      _app(CodeFilePreview(file: file, document: document)),
    );
    await tester.pump();

    expect(document.source, isNull);
    expect(find.byType(SelectableText).evaluate().length, lessThan(10));
    expect(find.textContaining('LAST-LINE'), findsNothing);
    final list = find.byKey(CodeFilePreview.plainTextListKey);
    final scrollable = find
        .descendant(of: list, matching: find.byType(Scrollable))
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    for (
      var i = 0;
      i < 8 && find.textContaining('LAST-LINE').evaluate().isEmpty;
      i++
    ) {
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    expect(find.textContaining('LAST-LINE'), findsOneWidget);
    expect(find.byType(SelectableText).evaluate().length, lessThan(10));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Copy'));
    for (var i = 0; i < 100 && copied == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(copied, source);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('code preview header shows the language and toggles wrap', (
    tester,
  ) async {
    final file = File(p.join(tempDir.path, 'main.dart'))
      ..writeAsStringSync('void main() {}\n');

    await tester.pumpWidget(_app(CodeFilePreview(file: file, autoLoad: false)));
    await _loadPreview(tester);

    expect(find.byKey(CodeFilePreview.languageLabelKey), findsOneWidget);
    expect(find.text('dart'), findsOneWidget);

    final wrap = find.byKey(CodeFilePreview.wrapToggleKey);
    expect(wrap, findsOneWidget);
    await tester.tap(wrap);
    await tester.pump();
    expect(find.byKey(CodeFilePreview.wrapToggleKey), findsOneWidget);
  });

  test('extension and rc filenames map to language labels', () {
    expect(languageForPath('/home/user/.bashrc'), 'shell');
    expect(languageForPath('/home/user/.bash_profile'), 'shell');
    expect(languageForPath('/home/user/.zshrc'), 'shell');
    expect(languageForPath('/home/user/.profile'), 'shell');
    expect(languageForPath('/etc/bash.bashrc'), 'shell');
    expect(languageForPath('/tmp/data.csv'), 'csv');
    expect(languageForPath('/tmp/config.toml'), 'toml');
    expect(languageForPath('/tmp/app.ini'), 'ini');
    expect(languageForPath('/tmp/nginx.conf'), 'conf');
    expect(languageForPath('/tmp/unknown.xyz'), 'text');
    expect(languageForPath('/tmp/noext'), 'text');
    expect(languageForExtension('.py'), 'python');
    expect(highlightLanguageFor('shell'), 'bash');
    expect(highlightLanguageFor('csv'), 'plaintext');
    expect(highlightLanguageFor('toml'), 'ini');
    expect(highlightLanguageFor('text'), 'plaintext');
  });

  testWidgets('non-wrap mode uses one horizontal scroll for all lines', (
    tester,
  ) async {
    final long = List.filled(80, 'M').join();
    final file = File(p.join(tempDir.path, 'wide.py'))
      ..writeAsStringSync('$long\nshort\n$long\n');

    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 240,
          height: 400,
          child: CodeFilePreview(file: file, autoLoad: false),
        ),
      ),
    );
    await _loadPreview(tester);

    expect(find.byKey(CodeFilePreview.horizontalScrollKey), findsOneWidget);
    final horizontals = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontals, findsOneWidget);
  });

  testWidgets('non-wrap width follows the rendered text scale', (tester) async {
    // The test font renders every glyph at the same width, so the only way to
    // make the rendered line wider than a naive measurement is text scaling.
    // A real CJK file hits the same path: rendered width != code-unit count.
    final long = List.filled(60, 'M').join();
    final file = File(p.join(tempDir.path, 'signs.json'))
      ..writeAsStringSync('$long\nshort\n');

    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: SizedBox(
            width: 240,
            height: 400,
            child: CodeFilePreview(file: file, autoLoad: false),
          ),
        ),
      ),
    );
    await _loadPreview(tester);

    expect(tester.takeException(), isNull);
    expect(_codeText(tester), contains(long));
  });

  testWidgets('the whole file is one selectable paragraph', (tester) async {
    // Per-line widgets cannot be selected across, and copying them back drops
    // the line breaks, so the code column has to stay a single paragraph.
    final file = File(p.join(tempDir.path, 'many.py'))
      ..writeAsStringSync('first\nsecond\nthird\n');

    await tester.pumpWidget(_app(CodeFilePreview(file: file, autoLoad: false)));
    await _loadPreview(tester);

    // Two: the code and the gutter, which share a widget type so their line
    // boxes match. Only the code one is selectable.
    expect(find.byType(SelectableText), findsNWidgets(2));
    expect(find.byKey(CodeFilePreview.codeKey), findsOneWidget);
    expect(
      tester.widget<SelectableText>(_code).enableInteractiveSelection,
      isTrue,
    );
    expect(
      tester.widget<SelectableText>(_gutter).enableInteractiveSelection,
      isFalse,
    );
    expect(_codeText(tester), 'first\nsecond\nthird\n');
  });

  testWidgets('non-wrap gutter stays pinned while code scrolls horizontally', (
    tester,
  ) async {
    // The code paragraph covers the whole scroll view, and on Android its own
    // gesture detector claims horizontal drags before the scroll view sees
    // them, so this only describes the iOS behaviour.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final long = List.filled(80, 'M').join();
    final file = File(p.join(tempDir.path, 'pinned.py'))
      ..writeAsStringSync('$long\nshort\n');

    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 240,
          height: 400,
          child: CodeFilePreview(file: file, autoLoad: false),
        ),
      ),
    );
    await _loadPreview(tester);

    final gutterBefore = tester.getTopLeft(_gutter);
    final codeBefore = tester.getTopLeft(_code);

    await tester.dragFrom(
      codeBefore + const Offset(40, 20),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();

    final gutterAfter = tester.getTopLeft(_gutter);
    final codeAfter = tester.getTopLeft(_code);
    // Reset before the expects: the binding checks this is unset when the test
    // body returns, and a failed expect would leak it into the next test.
    debugDefaultTargetPlatformOverride = null;

    expect(gutterAfter.dx, gutterBefore.dx);
    expect(codeAfter.dx, lessThan(codeBefore.dx));
  });

  testWidgets('non-wrap vertical scroll keeps gutter and code aligned', (
    tester,
  ) async {
    final lines = List<String>.generate(40, (i) => 'line_$i');
    final file = File(p.join(tempDir.path, 'tall.py'))
      ..writeAsStringSync(lines.join('\n'));

    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 240,
          height: 280,
          child: CodeFilePreview(file: file, autoLoad: false),
        ),
      ),
    );
    await _loadPreview(tester);

    final gutterBefore = tester.getTopLeft(_gutter);
    final codeBefore = tester.getTopLeft(_code);

    // Drag inside the viewport: the paragraph is taller than the window, so its
    // centre is off screen.
    await tester.dragFrom(
      codeBefore + const Offset(40, 20),
      const Offset(0, -48),
    );
    await tester.pumpAndSettle();

    final gutterDelta = tester.getTopLeft(_gutter).dy - gutterBefore.dy;
    final codeDelta = tester.getTopLeft(_code).dy - codeBefore.dy;
    expect(gutterDelta, isNot(0));
    expect(codeDelta, gutterDelta);
  });

  testWidgets('wrap and non-wrap gutters share the same unstyled column', (
    tester,
  ) async {
    final long = List.filled(40, '神谕').join();
    final file = File(p.join(tempDir.path, 'signs.json'))
      ..writeAsStringSync('$long\nshort\n$long\n');

    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 240,
          height: 400,
          child: CodeFilePreview(file: file, autoLoad: false),
        ),
      ),
    );
    await _loadPreview(tester);

    final nonWrapGutter = tester.getTopLeft(_gutter);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(CodeFilePreview.wrapToggleKey));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(_gutter).dx, nonWrapGutter.dx);
    expect(find.byKey(CodeFilePreview.horizontalScrollKey), findsNothing);
  });

  testWidgets('gutter and code occupy the same rows in both modes', (
    tester,
  ) async {
    // Mixed scripts on one line make the code side taller than the latin-only
    // line numbers unless both paragraphs force the same strut height, and a
    // wrapped line has to push the following numbers down with it.
    final long = List.filled(60, 'M').join();
    final file = File(p.join(tempDir.path, 'mixed.json'))
      ..writeAsStringSync('{"a": "神谕 skill"}\n$long\n{"b": 1}\n');

    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 240,
          height: 400,
          child: CodeFilePreview(file: file, autoLoad: false),
        ),
      ),
    );
    await _loadPreview(tester);

    final gutter = tester.widget<SelectableText>(_gutter);
    final code = tester.widget<SelectableText>(_code);
    expect(gutter.strutStyle?.forceStrutHeight, isTrue);
    expect(code.strutStyle?.forceStrutHeight, isTrue);
    expect(code.strutStyle?.fontSize, gutter.strutStyle?.fontSize);
    expect(_gutterText(tester), '1\n2\n3\n4');
    expect(tester.getSize(_gutter).height, tester.getSize(_code).height);

    await tester.tap(find.byKey(CodeFilePreview.wrapToggleKey));
    await tester.pump();

    // The long line now spans several rows, so its number is followed by that
    // many blank rows and the numbers after it stay beside their own code.
    final wrapped = _gutterText(tester).split('\n');
    expect(wrapped.first, '1');
    expect(wrapped.indexOf('3'), greaterThan(2));
    expect(tester.getSize(_gutter).height, tester.getSize(_code).height);
  });

  testWidgets('bashrc preview shows the shell language label', (tester) async {
    final file = File(p.join(tempDir.path, '.bashrc'))
      ..writeAsStringSync('export PATH=/usr/bin\n');

    await tester.pumpWidget(_app(CodeFilePreview(file: file, autoLoad: false)));
    await _loadPreview(tester);

    expect(find.text('shell'), findsOneWidget);
  });
}
