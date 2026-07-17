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
      final processing = ValueNotifier(false);
      addTearDown(processing.dispose);
      var userScrollIntentCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageListView(
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
              isProcessingFiles: processing,
              onUserScrollIntent: () => userScrollIntentCount++,
            ),
          ),
        ),
      );

      final list = tester.widget<SuperListView>(find.byType(SuperListView));
      final desktop =
          platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux;
      expect(
        list.keyboardDismissBehavior,
        desktop
            ? ScrollViewKeyboardDismissBehavior.manual
            : ScrollViewKeyboardDismissBehavior.onDrag,
      );
      expect(find.byType(Scrollbar), desktop ? findsOneWidget : findsNothing);

      if (desktop) {
        await tester.tap(find.byType(SuperListView));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.pageUp);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.pageUp);
        await tester.pump();
        expect(userScrollIntentCount, greaterThanOrEqualTo(1));
      }
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
