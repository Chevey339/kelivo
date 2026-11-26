import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

void main() {
  const platforms = <TargetPlatform>[
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ];

  for (final platform in platforms) {
    testWidgets('$platform uses its timeline input surface contract', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final listController = ListController();
      addTearDown(listController.dispose);
      final processing = ValueNotifier<String?>(null);
      addTearDown(processing.dispose);
      final inputFocus = FocusNode();
      addTearDown(inputFocus.dispose);
      var userScrollIntentCount = 0;
      final desktop =
          platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: MessageListView(
                    scrollController: scrollController,
                    listController: listController,
                    messages: const [],
                    byGroup: const {},
                    versionSelections: const {},
                    reasoning: const {},
                    reasoningSegments: const {},
                    contentSplits: const {},
                    toolParts: const {},
                    translations: const {},
                    selecting: false,
                    selectedItems: const {},
                    dividerPadding: EdgeInsets.zero,
                    processingFilesMessageId: processing,
                    onUserScrollIntent: () => userScrollIntentCount++,
                    footer: const SizedBox(height: 1200),
                  ),
                ),
                TextField(focusNode: inputFocus),
              ],
            ),
          ),
        ),
      );

      final list = find.byType(SuperListView);
      expect(find.byType(Scrollbar), desktop ? findsOneWidget : findsNothing);

      if (desktop) {
        await tester.tap(list);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.pageUp);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.pageUp);
        await tester.pump();
        expect(userScrollIntentCount, greaterThanOrEqualTo(1));
      } else {
        await tester.showKeyboard(find.byType(TextField));
        expect(inputFocus.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.drag(list, const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(scrollController.offset, greaterThan(0));
        expect(inputFocus.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
      }
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
