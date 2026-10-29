import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'dart:ui' as ui;
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/quote_ref.dart';
import 'package:Kelivo/features/chat/widgets/quote_interaction_scope.dart';
import 'package:Kelivo/features/chat/widgets/selection_quick_toolbar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:Kelivo/shared/widgets/app_text_selection_toolbar.dart';
import 'package:Kelivo/shared/widgets/ios_text_selection_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:provider/provider.dart';
import '../../support/business_test_harness.dart';
import '../../support/markdown_render_helpers.dart';

void main() {
  for (final source in [
    'Earlier target\n\n```dart\ntarget();\n```',
    'Earlier target\n\n| Column | Other |\n| --- | --- |\n| target | value |',
  ]) {
    testWidgets(
      'streaming Markdown captures original code/table offsets: $source',
      (tester) async {
        final received = <QuoteRef>[];
        final actions = QuoteInteractionController(
          onQuote: (quote) async => received.add(quote),
          onJump: (_) async => true,
          sourceExists: (_) async => true,
        );
        final text = ValueNotifier(source);
        addTearDown(actions.dispose);
        addTearDown(text.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: QuoteInteractionScope(
                  controller: actions,
                  child: Padding(
                    padding: const EdgeInsets.all(60),
                    child: ValueListenableBuilder<String>(
                      valueListenable: text,
                      builder: (context, value, _) => AppSelectionArea(
                        message: ChatMessage(
                          id: 'stream',
                          role: 'assistant',
                          conversationId: 'c',
                          content: value,
                          isStreaming: true,
                        ),
                        child: MarkdownWithCodeHighlight(
                          text: value,
                          streaming: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final paragraph = markdownParagraphs(tester).lastWhere(
          (paragraph) => paragraph.text.toPlainText().contains('target'),
        );
        Offset point(int index, bool trailing) {
          final box = paragraph
              .getBoxesForSelection(
                TextSelection(baseOffset: index, extentOffset: index + 1),
              )
              .single;
          return paragraph.localToGlobal(
            Offset(
              trailing ? box.right - 1 : box.left + 1,
              box.toRect().center.dy,
            ),
          );
        }

        final drag = await tester.startGesture(
          point(0, false),
          kind: ui.PointerDeviceKind.mouse,
        );
        await drag.moveTo(point(5, true));
        await drag.up();
        await drag.removePointer();
        await tester.pumpAndSettle();
        expect(find.byType(SelectionQuickToolbar), findsOneWidget);
        text.value += '\n\nMore generated content';
        await tester.pumpAndSettle();
        await tester.tap(find.text('Quote'));
        await tester.pumpAndSettle();
        expect(received.single.start, source.lastIndexOf('target'));
        expect(received.single.end, source.lastIndexOf('target') + 6);
        // Table projections may include a structural row separator; offsets
        // still identify exactly the selected cell text in the stored source.
        expect(received.single.text.trim(), 'target');
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }

  Future<void> mount(
    WidgetTester tester,
    List<QuoteRef> received, {
    double top = 80,
  }) async {
    final actions = QuoteInteractionController(
      onQuote: (quote) async {
        received.add(quote);
      },
      onJump: (_) async => true,
      sourceExists: (_) async => true,
    );
    addTearDown(actions.dispose);
    final message = ChatMessage(
      id: 'm',
      role: 'assistant',
      content: 'alpha beta gamma',
      conversationId: 'c',
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: QuoteInteractionScope(
            controller: actions,
            child: Padding(
              padding: EdgeInsets.only(top: top),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    AppSelectionArea(
                      message: message,
                      child: const Text(
                        'alpha beta gamma',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 1200),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'mouse selection settles before showing only Quote and Translate; scroll hides it',
    (tester) async {
      final received = <QuoteRef>[];
      await mount(tester, received);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText).first,
      );
      Offset point(int index) {
        final box = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: index, extentOffset: index + 1),
            )
            .single;
        return paragraph.localToGlobal(
          Offset(box.left + 1, box.toRect().center.dy),
        );
      }

      final gesture = await tester.startGesture(
        point(0),
        kind: ui.PointerDeviceKind.mouse,
      );
      await gesture.moveTo(point(5));
      await tester.pump();
      expect(find.byType(SelectionQuickToolbar), findsNothing);
      await gesture.up();
      await gesture.removePointer();
      await tester.pumpAndSettle();
      expect(find.byType(SelectionQuickToolbar), findsOneWidget);
      expect(find.text('Quote'), findsOneWidget);
      expect(find.text('Translate'), findsOneWidget);
      expect(find.text('Copy'), findsNothing);
      expect(received, isEmpty);
      await tester.tap(find.text('Quote'));
      await tester.pumpAndSettle();
      expect(received, hasLength(1));
      expect(received.single.text, 'alpha');
      expect(received.single.start, 0);
      expect(received.single.end, 5);
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(20);
      await tester.pump();
      expect(find.byType(SelectionQuickToolbar), findsNothing);
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets(
    'selection replacement in one frame still shows the latest quick actions',
    (tester) async {
      final received = <QuoteRef>[];
      await mount(tester, received);
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll(SelectionChangedCause.keyboard);
      // A new drag can clear and replace a selection before the queued frame.
      region.clearSelection();
      region.selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      expect(find.byType(SelectionQuickToolbar), findsOneWidget);
      await tester.tap(find.text('Quote'));
      await tester.pumpAndSettle();
      expect(received.single.text, 'alpha beta gamma');
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets(
    'mouse release schedules quick actions after the last selection frame',
    (tester) async {
      await mount(tester, []);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText).first,
      );
      Offset point(int index) {
        final box = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: index, extentOffset: index + 1),
            )
            .single;
        return paragraph.localToGlobal(
          Offset(box.left + 1, box.toRect().center.dy),
        );
      }

      final gesture = await tester.startGesture(
        point(0),
        kind: ui.PointerDeviceKind.mouse,
      );
      await gesture.moveTo(point(5));
      await tester.pumpAndSettle();
      expect(find.byType(SelectionQuickToolbar), findsNothing);
      await gesture.up();
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(SelectionQuickToolbar), findsOneWidget);
      await gesture.removePointer();
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets(
    'toolbar flips below clipped list top; keyboard shortcut quotes snapshot',
    (tester) async {
      final received = <QuoteRef>[];
      await mount(tester, received, top: 140);
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      final toolbar = tester.getRect(find.byType(SelectionQuickToolbar));
      final selected = tester.getRect(find.text('alpha beta gamma'));
      expect(toolbar.top, greaterThanOrEqualTo(selected.bottom));
      tester
          .widget<SelectionArea>(find.byType(SelectionArea))
          .focusNode!
          .requestFocus();
      await tester.pump();
      final modifier =
          Theme.of(tester.element(find.byType(SelectionArea))).platform ==
              TargetPlatform.macOS
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyUpEvent(modifier);
      await tester.pumpAndSettle();
      expect(received.single.text, 'alpha beta gamma');
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets(
    'Escape and outside clicks dismiss the quick toolbar; right click has grouped actions',
    (tester) async {
      await mount(tester, []);
      final area = tester.widget<SelectionArea>(find.byType(SelectionArea));
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      area.focusNode!.requestFocus();
      region.selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      expect(find.byType(SelectionQuickToolbar), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(SelectionQuickToolbar), findsNothing);
      region.clearSelection();
      region.selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(600, 50));
      await tester.pumpAndSettle();
      expect(find.byType(SelectionQuickToolbar), findsNothing);
      region.selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('alpha beta gamma')),
        kind: ui.PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await gesture.removePointer();
      await tester.pumpAndSettle();
      expect(find.byType(AppTextSelectionToolbar), findsOneWidget);
      final menu = tester.widget<AppTextSelectionToolbar>(
        find.byType(AppTextSelectionToolbar),
      );
      expect(menu.buttonItems.last.type, ContextMenuButtonType.selectAll);
      for (final label in [
        'Copy',
        'Copy as Markdown',
        'Copy rich text',
        'Quote',
        'Translate',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(SelectionQuickToolbar), findsNothing);
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets(
    'mobile selection preserves system actions and exposes quote with platform translation labels',
    (tester) async {
      const translation = MethodChannel('app.ios_translation');
      const nativeMenu = MethodChannel('app.ios_selection_menu');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        translation,
        (_) async => true,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        nativeMenu,
        (_) async => false,
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          translation,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          nativeMenu,
          null,
        );
        IosTextSelectionToolbar.resetAvailabilityForTesting();
      });
      final received = <QuoteRef>[];
      await mount(tester, received);
      await tester.longPress(find.text('alpha beta gamma'));
      await tester.pumpAndSettle();
      final platform = Theme.of(
        tester.element(find.byType(SelectionArea)),
      ).platform;
      if (platform == TargetPlatform.iOS) {
        final menu = tester.widget<AppTextSelectionToolbar>(
          find.byType(AppTextSelectionToolbar),
        );
        expect(
          menu.buttonItems.take(4).map((item) => item.label ?? item.type.name),
          ['copy', 'Quote', 'Translate', 'AI Translate'],
        );
      } else {
        expect(find.text('Translate'), findsOneWidget);
        expect(find.text('Copy as Markdown'), findsNothing);
        await tester.tap(
          find.byWidgetPredicate(
            (w) =>
                w is IosIconButton &&
                w.tooltip ==
                    MaterialLocalizations.of(
                      tester.element(find.byType(SelectionArea)),
                    ).moreButtonTooltip,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Copy as Markdown'), findsOneWidget);
        expect(find.text('Copy rich text'), findsOneWidget);
        await tester.tapAt(const Offset(600, 20));
        await tester.pumpAndSettle();
        await tester.longPress(find.text('alpha beta gamma'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Quote'));
      await tester.pumpAndSettle();
      expect(received, hasLength(1));
      expect(received.single.text, isNotEmpty);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
