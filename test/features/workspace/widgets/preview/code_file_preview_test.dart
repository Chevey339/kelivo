import 'dart:io';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/workspace/widgets/preview/code_file_preview.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('code preview shows the large-file state', (tester) async {
    final file = File(p.join(tempDir.path, 'huge.txt'))
      ..writeAsStringSync('0123456789' * 20);

    await tester.pumpWidget(
      _app(CodeFilePreview(file: file, maxBytes: 16, autoLoad: false)),
    );
    await _loadPreview(tester);

    expect(find.byKey(CodeFilePreview.tooLargeKey), findsOneWidget);
    expect(
      find.text(
        'This file is too large to preview. Open it externally instead.',
      ),
      findsOneWidget,
    );
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
    expect(find.text(long, findRichText: true), findsOneWidget);
  });

  testWidgets('non-wrap gutter stays pinned while code scrolls horizontally', (
    tester,
  ) async {
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

    final gutterBefore = tester.getTopLeft(find.text('1'));
    final codeBefore = tester.getTopLeft(find.byType(SelectableText).first);

    await tester.drag(
      find.byKey(CodeFilePreview.horizontalScrollKey),
      const Offset(-150, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('1')).dx, gutterBefore.dx);
    expect(
      tester.getTopLeft(find.byType(SelectableText).first).dx,
      lessThan(codeBefore.dx),
    );
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

    final gutterBefore = tester.getTopLeft(find.text('1'));
    final codeBefore = tester.getTopLeft(find.byType(SelectableText).first);

    // Slow drag so the list does not fling line 1 out of the builder cache.
    await tester.timedDrag(
      find.byType(ListView).first,
      const Offset(0, -48),
      const Duration(milliseconds: 400),
    );
    await tester.pump();

    final gutterDelta = tester.getTopLeft(find.text('1')).dy - gutterBefore.dy;
    final codeDelta =
        tester.getTopLeft(find.byType(SelectableText).first).dy - codeBefore.dy;
    expect(gutterDelta, isNot(0));
    expect(codeDelta, gutterDelta);
  });

  testWidgets('bashrc preview shows the shell language label', (tester) async {
    final file = File(p.join(tempDir.path, '.bashrc'))
      ..writeAsStringSync('export PATH=/usr/bin\n');

    await tester.pumpWidget(_app(CodeFilePreview(file: file, autoLoad: false)));
    await _loadPreview(tester);

    expect(find.text('shell'), findsOneWidget);
  });
}
