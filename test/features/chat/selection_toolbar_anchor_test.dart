import 'dart:ui' as ui;

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/selection_quick_toolbar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:Kelivo/shared/widgets/app_text_selection_toolbar.dart';
import 'package:Kelivo/shared/widgets/selection_scroll_container.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';
import '../../support/markdown_render_helpers.dart';

const _source = '''## Heading

> First quoted paragraph.
>
> > Nested quoted paragraph.
>
> Back to outer quote with `code`.

> Tip with a list:
> - Item one
> - Item two''';

Future<ScrollController> _mount(WidgetTester tester) async {
  final scroll = ScrollController();
  addTearDown(scroll.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(createBusinessTestPreferences()),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(40),
            child: SingleChildScrollView(
              controller: scroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSelectionArea(
                    message: ChatMessage(
                      id: 'm',
                      role: 'assistant',
                      conversationId: 'c',
                      content: _source,
                    ),
                    child: const MarkdownWithCodeHighlight(text: _source),
                  ),
                  const SizedBox(height: 800),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return scroll;
}

Offset _point(WidgetTester tester, String text, {bool end = false}) {
  final paragraph = markdownParagraph(tester, text);
  final start = paragraph.text.toPlainText().indexOf(text);
  final index = end ? start + text.length - 1 : start;
  final box = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: index, extentOffset: index + 1),
      )
      .first;
  return paragraph.localToGlobal(
    Offset(end ? box.right - 1 : box.left + 1, box.toRect().center.dy),
  );
}

Future<void> _select(
  WidgetTester tester, {
  required bool reverse,
  String first = 'Heading',
}) async {
  await tester.pump(const Duration(milliseconds: 600));
  final a = _point(tester, first);
  final b = _point(tester, 'Item two', end: true);
  final drag = await tester.startGesture(
    reverse ? b : a,
    kind: ui.PointerDeviceKind.mouse,
  );
  await drag.moveTo(reverse ? a : b);
  await tester.pump();
  await drag.up();
  await drag.removePointer();
  await tester.pumpAndSettle();
}

void main() {
  for (final reverse in [false, true]) {
    testWidgets(
      'quick actions anchor to selected text before and after scrolling: reverse=$reverse',
      (tester) async {
        final scroll = await _mount(tester);
        for (final first in ['Heading', 'Back to outer quote']) {
          if (first != 'Heading') {
            final selected = tester
                .state<SelectionScrollContainerState>(
                  find.byType(SelectionScrollContainer),
                )
                .selectedText;
            scroll.jumpTo(_point(tester, first).dy - 120);
            await tester.pumpAndSettle();
            expect(find.byType(SelectionQuickToolbar), findsNothing);
            final state = tester.state<SelectionScrollContainerState>(
              find.byType(SelectionScrollContainer),
            );
            expect(state.selectedText, selected);
            expect(state.globalSelectionRects, isNotEmpty);
            for (final rect in state.globalSelectionRects) {
              expect(rect.top, greaterThanOrEqualTo(state.globalViewport!.top));
              expect(
                rect.bottom,
                lessThanOrEqualTo(state.globalViewport!.bottom),
              );
            }
          }
          await _select(tester, reverse: reverse, first: first);
          final state = tester.state<SelectionScrollContainerState>(
            find.byType(SelectionScrollContainer),
          );
          expect(state.selectedText, startsWith(first));
          expect(state.selectedText, endsWith('Item two'));
          expect(state.globalSelectionRects, isNotEmpty);
          expect(
            find.byType(SelectionQuickToolbar),
            findsOneWidget,
            reason: first,
          );
          final position = tester
              .widgetList<CustomSingleChildLayout>(
                find.byType(CustomSingleChildLayout),
              )
              .map((widget) => widget.delegate)
              .whereType<SelectionToolbarPositionDelegate>()
              .single;
          // Verify the selection anchor, not the toolbar's visual dimensions.
          expect(position.anchor.contains(_point(tester, first)), isTrue);
        }
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      'message context menu retains the right-click position: reverse=$reverse',
      (tester) async {
        await _mount(tester);
        await _select(tester, reverse: reverse);
        final state = tester.state<SelectionScrollContainerState>(
          find.byType(SelectionScrollContainer),
        );
        final selected = state.selectedText;
        // Reopen at different selected paragraphs to detect stale anchors too.
        for (final target in ['Nested quoted paragraph', 'Item one']) {
          final click = _point(tester, target) + const Offset(2, 0);
          final right = await tester.startGesture(
            click,
            kind: ui.PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          );
          await right.up();
          await right.removePointer();
          await tester.pumpAndSettle();
          final menu = tester.widget<AppTextSelectionToolbar>(
            find.byType(AppTextSelectionToolbar),
          );
          expect(menu.anchors.primaryAnchor, click);
          expect(state.selectedText, selected);
          menu.onDismiss();
          await tester.pumpAndSettle();
        }
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.desktop(),
    );
  }
}
