import 'package:Kelivo/desktop/widgets/desktop_menu.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/features/chat/widgets/conversation_find_highlights.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';
import 'package:Kelivo/features/chat/controllers/conversation_find_controller.dart';
import 'package:Kelivo/features/chat/services/conversation_find_service.dart';
import 'package:Kelivo/features/chat/widgets/conversation_find_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

ConversationFindHit _hit(int i) => (
  messageId: 'm',
  part: FindPart.body,
  block: 0,
  segment: null,
  range: SourceSpan(i, i + 1),
  surfaceKey: null,
);
void main() {
  test(
    'the active occurrence is painted beyond the per-row decoration budget',
    () {
      final hits = List.generate(1000, _hit);
      final widget = ConversationFindHighlights(
        hits: hits,
        current: hits.last,
        child: const SizedBox(),
      );
      final painted = widget.ranges(FindPart.body, 0);
      expect(painted, contains(hits.last.range));
      expect(painted.length, lessThan(hits.length));
    },
  );

  testWidgets(
    'bar cycles both directions, ignores IME keys, remembers options and closes cleanly',
    (tester) async {
      final field = TextEditingController();
      final focus = FocusNode();
      final queries = <String>[];
      final findController = ConversationFindController(
        search: (q, options, _) async {
          queries.add(q);
          return {
            'm': q == 'missing' ? [] : [_hit(1), _hit(2), _hit(3)],
          };
        },
        onReveal: (_, _) {},
      );
      void open() {
        findController.open();
        field.value = TextEditingValue(
          text: findController.query,
          selection: TextSelection(
            baseOffset: 0,
            extentOffset: findController.query.length,
          ),
        );
        focus.requestFocus();
      }

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                    open,
              },
              child: Focus(
                autofocus: true,
                child: ListenableBuilder(
                  listenable: findController,
                  builder: (_, _) => findController.opened
                      ? ConversationFindBar(
                          find: findController,
                          field: field,
                          focusNode: focus,
                          onClose: findController.close,
                          compact: true,
                        )
                      : const SizedBox(),
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> shortcut() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
      }

      await tester.pump();
      await shortcut();
      expect(focus.hasFocus, isTrue);
      await tester.enterText(find.byType(EditableText), 'match');
      await tester.pump(const Duration(milliseconds: 199));
      expect(queries, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.text('1/3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text('2/3'), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(find.text('3/3'), findsOneWidget);
      field.value = field.value.copyWith(
        composing: const TextRange(start: 0, end: 2),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('3/3'), findsOneWidget);
      field.clearComposing();
      await shortcut();
      expect(field.selection.textInside(field.text), 'match');
      await tester.tap(find.byTooltip('Find options'));
      await tester.pumpAndSettle();
      expect(find.byType(DesktopMenuSurface), findsOneWidget);
      expect(find.byType(DesktopMenuRow), findsNWidgets(3));
      expect(tester.getSize(find.byType(DesktopMenuRow).first).height, 32);
      expect(find.byIcon(LucideIcons.check), findsNothing);
      await tester.tap(find.text('Match case'));
      await tester.pumpAndSettle();
      expect(findController.options.matchCase, isTrue);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(findController.index, 0);
      await tester.tapAt(const Offset(5, 200));
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(findController.hits, isEmpty);
      expect(find.byType(ConversationFindBar), findsNothing);
      open();
      await tester.pump();
      expect(findController.options.matchCase, isTrue);
      expect(field.selection.textInside(field.text), 'match');
      await tester.enterText(find.byType(EditableText), 'missing');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.tap(find.byTooltip('Next match'));
      expect(findController.index, 0);
      await tester.pump(ConversationFindController.debounce);
      await tester.pump();
      expect(find.text('0/0'), findsOneWidget);
      await tester.tap(find.byTooltip('Next match'));
      expect(findController.index, -1);
      findController.setConversation('new');
      expect(findController.query, isEmpty);
      expect(findController.options, defaultFindOptions);
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
      field.dispose();
      findController.dispose();
    },
  );

  testWidgets(
    'phone header fits a narrow screen with the keyboard, scales its count and keeps touch targets',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.reset);
      final field = TextEditingController(text: 'x'), focus = FocusNode();
      final controller = ConversationFindController(
        search: (_, _, _) async => {'m': List.generate(12345, _hit)},
        onReveal: (_, _) {},
      );
      controller.open(selection: 'x');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: kToolbarHeight,
                  child: ConversationFindBar(
                    find: controller,
                    field: field,
                    focusNode: focus,
                    compact: false,
                    onClose: controller.close,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      for (final label in [
        'Close',
        'Previous match',
        'Next match',
        'Find options',
      ]) {
        final button = tester.getRect(find.byTooltip(label));
        expect(button.width, greaterThanOrEqualTo(44), reason: label);
        expect(button.height, greaterThanOrEqualTo(44), reason: label);
        expect(button.bottom, lessThanOrEqualTo(kToolbarHeight));
      }
      expect(find.text('1/12345'), findsOneWidget);
      expect(find.byIcon(LucideIcons.chevronLeft), findsOneWidget);
      await tester.tap(find.byTooltip('Next match'));
      await tester.pump();
      expect(find.text('2/12345'), findsOneWidget);
      await tester.tap(find.byTooltip('Find options'));
      await tester.pumpAndSettle();
      expect(find.byType(DesktopMenuSurface), findsNothing);
      await tester.tap(find.text('Whole word'));
      await tester.pumpAndSettle();
      expect(controller.options.wholeWord, isTrue);
      await tester.tapAt(const Offset(5, 180));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      field.dispose();
      focus.dispose();
      controller.dispose();
    },
  );

  testWidgets(
    'stale reads, stream reconciliation and version resets keep navigation consistent',
    (tester) async {
      final pending = <Completer<Map<String, List<ConversationFindHit>>>>[];
      final reveals = <int>[];
      final c = ConversationFindController(
        search: (_, _, _) {
          final next = Completer<Map<String, List<ConversationFindHit>>>();
          pending.add(next);
          return next.future;
        },
        onReveal: (h, _) => reveals.add(h.range.start),
      );
      addTearDown(c.dispose);
      c.setConversation('c');
      c.open();
      c.setQuery('a');
      await tester.pump(ConversationFindController.debounce);
      c.setQuery('ab');
      pending.first.complete({
        'm': [_hit(9)],
      });
      await tester.pump();
      expect(c.hits, isEmpty);
      await tester.pump(ConversationFindController.debounce);
      pending.last.complete({
        'm': [_hit(1), _hit(2)],
      });
      await tester.pump();
      c.move(1);
      var reads = 0;
      for (var i = 0; i < 50; i++) {
        c.streamChanged('m', () async {
          reads++;
          return [_hit(1), _hit(2), _hit(3)];
        });
      }
      await tester.pump(ConversationFindController.debounce);
      expect(reads, 1);
      expect(c.index, 1);
      expect(reveals, [1, 2]);
      c.refresh();
      final firstRefresh = pending.last;
      c.refresh();
      final latestRefresh = pending.last;
      firstRefresh.complete({
        'm': [_hit(99)],
      });
      latestRefresh.complete({
        'm': [_hit(1), _hit(2), _hit(3)],
      });
      await tester.pump();
      expect(c.current, _hit(2));
      expect(reveals, [1, 2]);
      c.streamChanged('m', () async => [_hit(1), _hit(3)]);
      await tester.pump(ConversationFindController.debounce);
      expect(c.current, _hit(3));
      expect(reveals.last, 3);
      c.refresh(preserve: false);
      pending.last.complete({
        'm': [_hit(1), _hit(3)],
      });
      await tester.pump();
      expect(c.index, 0);
      c.setQuery(' ');
      expect(c.hits, isEmpty);
      expect(c.opened, isTrue);
    },
  );
}
