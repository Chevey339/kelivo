import 'package:Kelivo/shared/widgets/android_text_selection_toolbar.dart';
import 'package:Kelivo/shared/widgets/app_text_selection_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final rtl in [false, true]) {
    testWidgets('all actions remain reachable with keyboard open (RTL $rtl)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var invoked = -1;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Builder(
            builder: (context) => MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                viewInsets: EdgeInsets.only(bottom: 330),
                viewPadding: EdgeInsets.only(top: 30),
              ),
              child: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: AppTextSelectionToolbar(
                  anchors: const TextSelectionToolbarAnchors(
                    primaryAnchor: Offset(195, 480),
                  ),
                  buttonItems: List.generate(
                    24,
                    (i) => ContextMenuButtonItem(
                      label: 'Action $i',
                      onPressed: () => invoked = i,
                    ),
                  ),
                  selectionContext: context,
                  onDismiss: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(AndroidTextSelectionToolbar), findsOneWidget);
      expect(tester.takeException(), isNull);
      final scroll = find.byType(SingleChildScrollView);
      final bounds = tester.getRect(scroll);
      expect(bounds.left, greaterThanOrEqualTo(8));
      expect(bounds.right, lessThanOrEqualTo(382));
      expect(bounds.top, greaterThanOrEqualTo(38));
      expect(bounds.bottom, lessThanOrEqualTo(506));
      expect(bounds.height, lessThan(80));
      await tester.drag(scroll, Offset(rtl ? 6000 : -6000, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Action 23'));
      expect(invoked, 23);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'long labels and large text stay inside a small usable viewport',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(240, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(240, 320),
              viewPadding: EdgeInsets.only(top: 24, left: 12, right: 12),
              viewInsets: EdgeInsets.only(bottom: 200),
              textScaler: TextScaler.linear(3),
            ),
            child: AndroidTextSelectionToolbar(
              anchors: const TextSelectionToolbarAnchors(
                primaryAnchor: Offset(120, 110),
              ),
              buttonItems: [
                ContextMenuButtonItem(
                  label: 'A very long processing action ' * 8,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      final bounds = tester.getRect(find.byType(SingleChildScrollView));
      expect(bounds.left, greaterThanOrEqualTo(20));
      expect(bounds.right, lessThanOrEqualTo(220));
      expect(bounds.top, greaterThanOrEqualTo(32));
      expect(bounds.bottom, lessThanOrEqualTo(112));
      expect(tester.takeException(), isNull);
    },
  );
}
