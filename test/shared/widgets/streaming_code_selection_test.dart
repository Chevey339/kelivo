import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long code keeps cross-chunk copying and iOS translation', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const translation = MethodChannel('app.ios_translation');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(translation, (call) async {
      calls.add(call);
      return call.method == 'isAvailable' ? true : null;
    });
    String? copied;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(translation, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final source = ValueNotifier(
      List.generate(200, (i) => 'final value$i = "中文 $i";').join('\n'),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ValueListenableBuilder<String>(
                valueListenable: source,
                builder: (_, value, _) => SelectableHighlightView(
                  value,
                  language: 'dart',
                  textStyle: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 2; i++) {
      await tester.pumpAndSettle();
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      final area = tester.widget<SelectionArea>(find.byType(SelectionArea));
      final menu =
          area.contextMenuBuilder!(
                tester.element(find.byType(SelectionArea)),
                region,
              )
              as AdaptiveTextSelectionToolbar;
      menu.buttonItems!
          .singleWhere((item) => item.type == ContextMenuButtonType.copy)
          .onPressed!();
      await tester.pump();
      expect(copied, source.value);
      // Copy can clear selection, so restore it before opening the menu again.
      region.selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      final translationMenu =
          area.contextMenuBuilder!(
                tester.element(find.byType(SelectionArea)),
                region,
              )
              as AdaptiveTextSelectionToolbar;
      translationMenu.buttonItems!
          .singleWhere((item) => item.label == 'Translate')
          .onPressed!();
      await tester.pump();
      expect((calls.last.arguments as Map)['text'], source.value);
      region.clearSelection();
      source.value += '\nfinal appended = "more";';
    }
    await tester.pumpWidget(const SizedBox.shrink());
    source.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
