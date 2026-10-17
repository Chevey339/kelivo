import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';

Widget _harness(String source) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: AppSelectionArea(child: Text(source))),
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
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

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
