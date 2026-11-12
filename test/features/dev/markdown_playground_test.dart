import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/setting/about_pane.dart';
import 'package:Kelivo/features/dev/models/markdown_playground_model.dart';
import 'package:Kelivo/features/dev/pages/markdown_playground_page.dart';
import 'package:Kelivo/features/settings/pages/about_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

Widget _app({
  Widget child = const MarkdownPlaygroundPage(),
  double scale = 1,
}) => ChangeNotifierProvider(
  create: (_) => SettingsProvider(createBusinessTestPreferences()),
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: child,
  ),
);

void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _key(String name) => find.byKey(ValueKey('markdown-playground-$name'));
Finder _tab(String label) =>
    find.descendant(of: find.byType(TabBar), matching: find.text(label));

void main() {
  testWidgets(
    'streaming advances Unicode scalars and pause resumes the same document',
    (tester) async {
      final model = MarkdownPlaygroundModel('A😀B');
      addTearDown(model.dispose);
      expect(model.total, 3);
      model.play();
      expect(model.displayed, isEmpty);
      await tester.pump(const Duration(milliseconds: 30));
      expect(model.displayed, 'A');
      model.pause();
      await tester.pump(const Duration(seconds: 1));
      expect(model.displayed, 'A');
      expect(model.streaming, isTrue);
      model.play();
      await tester.pump(const Duration(milliseconds: 30));
      expect(model.displayed, 'A😀');
      expect(model.shown, 2);
      await tester.pump(const Duration(milliseconds: 30));
      expect(model.displayed, 'A😀B');
      expect(model.streaming, isFalse);
      expect(model.playing, isFalse);
    },
  );

  testWidgets('editing, show all and disposal cancel pending stream ticks', (
    tester,
  ) async {
    final model = MarkdownPlaygroundModel('**one**');
    model.play();
    await tester.pump(const Duration(milliseconds: 60));
    model.showAll();
    expect(toPlainText(model.document), 'one');
    model.play();
    model.setSource('replacement');
    await tester.pump(const Duration(seconds: 1));
    expect(model.displayed, 'replacement');
    expect(model.playing, isFalse);
    model.play();
    model.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile editor, AST, stream controls and selection preview share source',
    (tester) async {
      _size(tester, const Size(390, 844));
      await tester.pumpWidget(_app());
      await tester.enterText(_key('editor'), '**Bold** normal');
      await tester.tap(_tab('AST'));
      await tester.pumpAndSettle();
      expect(find.text('paragraph [0, 15)'), findsOneWidget);
      await tester.tap(find.text('paragraph [0, 15)'));
      await tester.pumpAndSettle();
      expect(find.text('strong [0, 8)'), findsOneWidget);
      await tester.tap(_key('play'));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Pause'), findsOneWidget);
      await tester.tap(_key('play'));
      await tester.pumpAndSettle();
      expect(find.text('Resume'), findsOneWidget);
      await tester.tap(_key('show-all'));
      await tester.pumpAndSettle();
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(_key('selected-plain')).data, 'Bold normal');
      expect(
        tester.widget<Text>(_key('selected-markdown')).data,
        '**Bold** normal',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop width and theme controls update the preview and resizing retains edits',
    (tester) async {
      _size(tester, const Size(1280, 800));
      await tester.pumpWidget(_app());
      await tester.enterText(_key('editor'), 'persistent source');
      await tester.pumpAndSettle();
      expect(_key('desktop'), findsOneWidget);
      final before = tester.widget<Slider>(_key('width')).value;
      await tester.drag(_key('width'), const Offset(150, 0));
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(_key('width')).value, greaterThan(before));
      await tester.tap(_key('theme'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(MarkstreamView))).brightness,
        Brightness.dark,
      );
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(_key('mobile'), findsOneWidget);
      expect(
        tester.widget<TextField>(_key('editor')).controller!.text,
        'persistent source',
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(844, 300),
    const Size(1000, 500),
  ]) {
    testWidgets('all panes fit $size at 1.3 text scale', (tester) async {
      _size(tester, size);
      await tester.pumpWidget(_app(scale: 1.3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label in ['Preview', 'AST']) {
        await tester.tap(_tab(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
    });
  }

  for (final desktop in [false, true]) {
    testWidgets(
      'debug ${desktop ? 'desktop' : 'mobile'} About entry opens Playground',
      (tester) async {
        _size(tester, desktop ? const Size(1280, 1000) : const Size(390, 844));
        PackageInfo.setMockInitialValues(
          appName: 'Kelivo',
          packageName: 'Kelivo',
          version: '1.0',
          buildNumber: '1',
          buildSignature: '',
        );
        await tester.pumpWidget(
          _app(
            child: desktop
                ? const Scaffold(body: DesktopAboutPane())
                : const AboutPage(),
          ),
        );
        await tester.pumpAndSettle();
        final entry = find.text('Markdown Playground');
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.byType(MarkdownPlaygroundPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
