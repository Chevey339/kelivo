import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/desktop/mini_map_popover.dart';
import 'package:Kelivo/features/chat/services/conversation_find_service.dart';
import 'package:Kelivo/features/home/widgets/mini_map_search.dart';
import 'package:Kelivo/features/home/widgets/mini_map_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';

final _findButton = find.byKey(const ValueKey('miniMapSearchButton'));
final _filterButton = find.byKey(const ValueKey('miniMapPreviewSearchButton'));

Future<void> _openMap(
  WidgetTester tester, {
  required bool desktop,
  bool selecting = false,
  double textScale = 1,
  VoidCallback? onFind,
  required MiniMapSearch onSearch,
  ValueChanged<MiniMapSelection?>? onSelect,
}) async {
  final anchor = GlobalKey();
  final messages = [
    ChatMessage(role: 'user', conversationId: 'c', content: 'visible row'),
  ];
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        platform: desktop ? TargetPlatform.macOS : TargetPlatform.iOS,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Align(
            alignment: Alignment.bottomCenter,
            child: TextButton(
              key: anchor,
              onPressed: () async {
                final picked = desktop
                    ? await showDesktopMiniMapPopover(
                        context,
                        anchorKey: anchor,
                        messages: messages,
                        selecting: selecting,
                        selectedMessageIds: {},
                        onToggleSelection: (_) {},
                        onOpenConversationFind: onFind,
                        onSearch: onSearch,
                      )
                    : await showMiniMapSheet(
                        context,
                        messages,
                        selecting: selecting,
                        selectedMessageIds: {},
                        onToggleSelection: (_) {},
                        onOpenConversationFind: onFind,
                        onSearch: onSearch,
                      );
                onSelect?.call(picked);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

ConversationFindPreview _preview(
  int index,
  String word, {
  int matchCount = 1,
}) => (
  hit: (
    messageId: 'm$index',
    part: FindPart.body,
    block: 0,
    segment: null,
    range: const SourceSpan(7, 9),
    surfaceKey: null,
  ),
  role: index.isEven ? 'user' : 'assistant',
  matchCount: matchCount,
  before: 'M$index ',
  segments: [
    (text: word, highlighted: true),
    (text: ' context', highlighted: false),
  ],
);

void main() {
  for (final desktop in [false, true]) {
    for (final selecting in [false, true]) {
      testWidgets(
        'map opens chat find only in browse mode (desktop=$desktop, selecting=$selecting)',
        (tester) async {
          var opened = 0;
          await _openMap(
            tester,
            desktop: desktop,
            selecting: selecting,
            onFind: () => opened++,
            onSearch: (_, _) => const Stream.empty(),
          );
          expect(find.text('visible row'), findsOneWidget);
          expect(find.byType(EditableText), findsNothing);
          if (selecting) {
            expect(_findButton, findsNothing);
            expect(_filterButton, findsNothing);
          } else {
            expect(
              tester.widget<IosIconButton>(_findButton).icon,
              isNot(tester.widget<IosIconButton>(_filterButton).icon),
            );
            await tester.tap(_findButton);
            await tester.pumpAndSettle();
            expect(opened, 1);
            expect(find.text('visible row'), findsNothing);
          }
        },
      );
    }

    testWidgets(
      'minimap search previews and selects a match (desktop=$desktop)',
      (tester) async {
        if (!desktop) {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 720);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
        }
        final stale = StreamController<List<ConversationFindPreview>>();
        final latest = StreamController<List<ConversationFindPreview>>();
        final searched = <String>[];
        final picks = <MiniMapSelection?>[];
        bool Function()? isOldSearchCurrent;
        await _openMap(
          tester,
          desktop: desktop,
          onFind: () => fail('Minimap search must stay in the map'),
          onSelect: picks.add,
          onSearch: (query, isCurrent) {
            searched.add(query);
            if (query == 'old') {
              isOldSearchCurrent = isCurrent;
              return stale.stream;
            }
            return latest.stream;
          },
        );
        await tester.tap(_filterButton);
        await tester.pumpAndSettle();
        final field = find.byType(EditableText);
        expect(find.text('visible row'), findsOneWidget);
        if (!desktop) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
        }

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '知',
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange(start: 0, end: 1),
          ),
        );
        await tester.pump(const Duration(milliseconds: 240));
        expect(searched, isEmpty);

        await tester.enterText(field, 'old');
        await tester.pump(const Duration(milliseconds: 200));
        expect(isOldSearchCurrent!(), isTrue);
        await tester.enterText(field, '知豆');
        await tester.pump(const Duration(milliseconds: 200));
        expect(isOldSearchCurrent!(), isFalse);
        expect(searched, ['old', '知豆']);
        latest.add([_preview(0, '知豆', matchCount: 3), _preview(1, '知豆')]);
        stale.add([_preview(0, 'old')]);
        unawaited(stale.close());
        await tester.pump();
        expect(find.text('M0 old context'), findsNothing);
        expect(find.text('M0 知豆 context'), findsOneWidget);
        expect(find.text('M1 知豆 context'), findsOneWidget);
        expect(find.text('3 matches').hitTestable(), findsOneWidget);
        expect(find.text('1 match').hitTestable(), findsOneWidget);
        expect(picks, isEmpty);

        latest.add([for (var i = 2; i < 40; i++) _preview(i, '知豆')]);
        unawaited(latest.close());
        if (!desktop) tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        final result = find.text('M39 知豆 context');
        await tester.scrollUntilVisible(
          result,
          120,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('miniMapSearchResults')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(result);
        await tester.pumpAndSettle();
        expect(picks.single?.match, _preview(39, '知豆').hit);
        expect(field, findsNothing);
      },
    );
  }

  testWidgets('fully expanded minimap search stays below the status bar', (
    tester,
  ) async {
    const statusBar = 59.0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = const FakeViewPadding(top: statusBar, bottom: 34);
    tester.view.viewPadding = tester.view.padding;
    addTearDown(tester.view.reset);
    await _openMap(
      tester,
      desktop: false,
      onSearch: (query, _) =>
          Stream.value([for (var i = 0; i < 60; i++) _preview(i, query)]),
    );
    await tester.tap(_filterButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'e');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.timedDrag(
      find.byKey(const ValueKey('miniMapSearchResults')),
      const Offset(0, -650),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();
    final sheetTop = tester.getTopLeft(find.byType(BottomSheet)).dy;
    expect(sheetTop, closeTo(statusBar, 1));
  });

  testWidgets('landscape minimap scrolls above the keyboard', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(812, 375);
    addTearDown(tester.view.reset);
    await _openMap(
      tester,
      desktop: false,
      onSearch: (query, _) =>
          Stream.value([for (var i = 0; i < 12; i++) _preview(i, query)]),
    );
    await tester.tap(_filterButton);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '知豆');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('M0 知豆 context').hitTestable(), findsOneWidget);
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('miniMapSearchResults')),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    await tester.drag(scrollable, const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
  });

  testWidgets('large text keeps the highlighted keyword visible', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.reset);
    await _openMap(
      tester,
      desktop: false,
      textScale: 2,
      onSearch: (query, _) {
        final preview = _preview(0, query);
        return Stream.value([
          (
            hit: preview.hit,
            role: preview.role,
            matchCount: 7,
            before: '…${'前' * 16}',
            segments: [
              (text: query, highlighted: true),
              (text: '、', highlighted: false),
              (text: query, highlighted: true),
              (text: '后' * 42, highlighted: false),
            ],
          ),
        ]);
      },
    );
    await tester.tap(_filterButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '知豆');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    final result = find.descendant(
      of: find.byKey(const ValueKey('miniMapSearchResults')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('知豆'),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(result);
    final start = paragraph.text.toPlainText().indexOf('知豆');
    expect(start, isNonNegative);
    expect(
      paragraph.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + 2),
      ),
      isNotEmpty,
    );
    final highlighted = <String>[];
    paragraph.text.visitChildren((span) {
      if (span.style?.backgroundColor != null) {
        highlighted.add(span.toPlainText());
      }
      return true;
    });
    expect(highlighted, ['知豆', '知豆']);
    final count = find.text('7 matches').hitTestable();
    expect(count, findsOneWidget);
    expect(tester.getRect(count).height, greaterThanOrEqualTo(24));
  });
}
