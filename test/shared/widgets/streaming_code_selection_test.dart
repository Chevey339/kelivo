import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:Kelivo/shared/widgets/app_text_selection_toolbar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:markstream/markstream.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long code keeps cross-chunk copying and iOS translation', (
    tester,
  ) async {
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
          body: AppSelectionArea(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ValueListenableBuilder<String>(
                  valueListenable: source,
                  builder: (_, value, _) => MarkstreamCodeContent(
                    wrap: false,
                    node: CodeBlockNode(
                      span: SourceSpan(0, value.length),
                      children: [
                        TextNode(
                          span: SourceSpan(0, value.length),
                          text: value,
                        ),
                      ],
                      info: 'dart',
                    ),
                    theme: MarkstreamTheme.fromColorScheme(
                      ThemeData.light().colorScheme,
                    ),
                  ),
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
              as AppTextSelectionToolbar;
      menu.buttonItems
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
              as AppTextSelectionToolbar;
      translationMenu.buttonItems
          .singleWhere((item) => item.label == 'Translate')
          .onPressed!();
      await tester.pump();
      expect((calls.last.arguments as Map)['text'], source.value);
      region.clearSelection();
      source.value += '\nfinal appended = "more";';
    }
    await tester.pumpWidget(const SizedBox.shrink());
    source.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
