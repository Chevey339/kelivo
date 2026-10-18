import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../support/markdown_render_helpers.dart';
import 'package:markstream/markstream.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';

Widget _harness(String source) => _widgetHarness(Text(source));

Widget _widgetHarness(
  Widget child, {
  MarkstreamSelectionController? controller,
}) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(
    body: controller == null
        ? AppSelectionArea(child: child)
        : MarkstreamSelectionScope(
            controller: controller,
            child: AppSelectionArea(child: child),
          ),
  ),
);

AdaptiveTextSelectionToolbar _menu(WidgetTester tester) {
  final area = tester.widget<SelectionArea>(find.byType(SelectionArea));
  return area.contextMenuBuilder!(
        tester.element(find.byType(SelectionArea)),
        tester.state<SelectableRegionState>(find.byType(SelectableRegion)),
      )
      as AdaptiveTextSelectionToolbar;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.ios_translation');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> selectAll(WidgetTester tester) async {
    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
  }

  testWidgets('Markdown menu copies structured selection and keeps native Copy', (
    tester,
  ) async {
    final writes = <String>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        writes.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    const source =
        '**Bold** [Link](https://example.com)\n\n```dart\n  code();\n\nend();\n```\n\n| A | B |\n| - | - |\n|  | value |';
    await tester.pumpWidget(
      _widgetHarness(
        const MarkstreamView(source: source, cullToViewport: false),
      ),
    );
    await tester.pumpAndSettle();
    await selectAll(tester);
    _menu(tester).buttonItems!
        .singleWhere((item) => item.type == ContextMenuButtonType.copy)
        .onPressed!();
    await tester.pumpAndSettle();
    expect(writes.last, contains('Bold Link'));
    expect(writes.last, contains('A\tB\n\tvalue'));
    expect(writes.last, isNot(contains('**Bold**')));
    await selectAll(tester);
    _menu(tester).buttonItems!
        .singleWhere((item) => item.label == 'Copy Markdown')
        .onPressed!();
    await tester.pumpAndSettle();
    expect(writes.last, contains('**Bold** [Link](<https://example.com>)'));
    expect(writes.last, contains('```dart\n  code();\n\nend();\n```'));
    expect(writes.last, contains('|  | value |'));
    expect(find.byType(SelectableRegion), findsOneWidget);
  }, variant: TargetPlatformVariant.desktop());

  testWidgets(
    'Markdown menu clips partial text while retaining emphasis and links',
    (tester) async {
      String? copied;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      await tester.pumpWidget(
        _widgetHarness(
          const MarkstreamView(
            source: '**Bold** [Link](https://example.com) finish',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final paragraph = markdownParagraph(tester, 'Bold Link');
      Offset edge(int index, {bool end = false}) {
        final box = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: index, extentOffset: index + 1),
            )
            .first
            .toRect();
        return paragraph.localToGlobal(
          Offset(end ? box.right - .1 : box.left + .1, box.center.dy),
        );
      }

      final drag = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await drag.addPointer();
      await drag.down(edge(1));
      await drag.moveTo(edge(6, end: true));
      await drag.up();
      await tester.pumpAndSettle();
      _menu(tester).buttonItems!
          .singleWhere((item) => item.label == 'Copy Markdown')
          .onPressed!();
      await tester.pumpAndSettle();
      expect(copied, '**old** [Li](<https://example.com>)');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'shared selection controller copies views in visual order and survives unmount',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _widgetHarness(
          const Column(
            children: [
              MarkstreamView(source: '**First**'),
              MarkstreamView(source: '*Second*'),
            ],
          ),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();
      await selectAll(tester);
      expect(controller.selectedMarkdown, '**First**\n\n*Second*');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(controller.hasSelection, isFalse);
      expect(() => controller.addListener(() {}), returnsNormally);
    },
  );

  testWidgets('plain text selection does not offer Markdown copy', (
    tester,
  ) async {
    await tester.pumpWidget(_harness('Plain text'));
    await tester.pumpAndSettle();
    await selectAll(tester);
    expect(
      _menu(tester).buttonItems!.any((item) => item.label == 'Copy Markdown'),
      isFalse,
    );
  });

  testWidgets('iOS keeps Translate beside Markdown copy', (tester) async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'isAvailable' ? true : null,
    );
    await tester.pumpWidget(
      _widgetHarness(const MarkstreamView(source: '**Selected** prose')),
    );
    await tester.pumpAndSettle();
    await selectAll(tester);
    final labels = _menu(tester).buttonItems!.map((item) => item.label);
    expect(labels, containsAll(['Translate', 'Copy Markdown']));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS translates selected prose through the message menu', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'isAvailable' ? true : null;
    });
    await tester.pumpWidget(_harness('Selected prose'));
    await tester.pumpAndSettle();
    final region = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    region.selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    final menu = _menu(tester);
    expect(
      menu.buttonItems!.any((item) => item.type == ContextMenuButtonType.copy),
      isTrue,
    );
    menu.buttonItems!
        .singleWhere((item) => item.label == 'Translate')
        .onPressed!();
    await tester.pumpAndSettle();
    final args =
        calls.singleWhere((call) => call.method == 'present').arguments
            as Map<Object?, Object?>;
    expect(args['text'], 'Selected prose');
    expect(args['anchorX'], isA<double>());
    expect(args['anchorY'], isA<double>());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final failure in [false, true]) {
    testWidgets(
      'iOS keeps stock selection when translation is unavailable ($failure)',
      (tester) async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (failure) throw PlatformException(code: 'unavailable');
          return false;
        });
        await tester.pumpWidget(_harness('Selected prose'));
        await tester.pumpAndSettle();
        tester
            .state<SelectableRegionState>(find.byType(SelectableRegion))
            .selectAll(SelectionChangedCause.keyboard);
        await tester.pumpAndSettle();
        expect(
          _menu(tester).buttonItems!.any((item) => item.label == 'Translate'),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
  testWidgets('Android does not query the iOS bridge', (tester) async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    await tester.pumpWidget(_harness('Selected prose'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  testWidgets('iOS does not offer translation for whitespace only', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (call) async => true);
    await tester.pumpWidget(_harness('   '));
    await tester.pumpAndSettle();
    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(
      _menu(tester).buttonItems!.any((item) => item.label == 'Translate'),
      isFalse,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('native presentation failure leaves message selection usable', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isAvailable') return true;
      throw PlatformException(code: 'presentation_failed');
    });
    await tester.pumpWidget(_harness('Selected prose'));
    await tester.pumpAndSettle();
    final region = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    region.selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    _menu(tester).buttonItems!
        .singleWhere((item) => item.label == 'Translate')
        .onPressed!();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      _menu(
        tester,
      ).buttonItems!.any((item) => item.type == ContextMenuButtonType.copy),
      isTrue,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
