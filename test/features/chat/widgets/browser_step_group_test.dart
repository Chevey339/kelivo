import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/browser/widgets/browser_page_card.dart';
import 'package:Kelivo/features/browser/widgets/browser_favicon.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/chat/widgets/chat_surface.dart';
import 'package:Kelivo/features/chat/widgets/tool_detail_text_section.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../../../support/business_test_harness.dart';

const _image =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

ToolUIPart _tool(
  String id, {
  String action = 'open',
  bool loading = false,
  String? error,
  String url = 'https://example.com/page',
  Map<String, dynamic> args = const {},
  Map<String, dynamic> page = const {},
  String? image,
}) => ToolUIPart(
  id: id,
  toolName: LocalToolNames.browser,
  arguments: {'action': action, ...args},
  loading: loading,
  metadata: const {
    'browser': {'tabId': 'historical-tab'},
  },
  content: loading
      ? null
      : '${jsonEncode({
          'ok': error == null,
          if (error != null) 'error': error,
          'page': {'url': url, 'title': 'Result $id', ...page},
        })}${image == null ? '' : '\n![]($image)'}',
);

void main() {
  late SettingsProvider settings;
  setUp(() async {
    final harness = await createBusinessTestHarness();
    settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    await settings.setCollapseThinkingSteps(false);
    // Keep this fixture focused on the timeline, not the message timestamp row.
    await settings.setShowModelTimestamp(false);
    debugTimelineToolStepBuilds = 0;
  });
  tearDown(() => settings.dispose());

  Future<void> pump(
    WidgetTester tester,
    List<ToolUIPart> tools, {
    String conversationId = 'chat',
    bool narrow = false,
    double scale = 1,
    bool reduceMotion = false,
    bool? streaming,
  }) async {
    tester.view.physicalSize = Size(narrow ? 320 : 800, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider(create: (_) => ToolApprovalService()),
          ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
          ChangeNotifierProvider(
            create: (_) =>
                TtsProvider(preferences: createBusinessTestPreferences()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduceMotion,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatMessageWidget(
                message: ChatMessage(
                  id: 'message',
                  conversationId: conversationId,
                  role: 'assistant',
                  isStreaming: streaming ?? tools.any((tool) => tool.loading),
                ),
                toolParts: tools,
                showModelIcon: false,
                showTokenStats: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  Finder step(String id) => find.byKey(ValueKey('browser-step-$id'));
  Finder steps() => find.byWidgetPredicate(
    (widget) =>
        widget is KeyedSubtree &&
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('browser-step-'),
  );
  Future<void> toggle(WidgetTester tester) async {
    await tester.tap(
      find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(
                  'browser-group-header-',
                ),
          )
          .first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets(
    'group header expands real shells with one final card and shared lines',
    (tester) async {
      await pump(tester, [_tool('a'), _tool('b'), _tool('c')]);
      expect(steps(), findsNothing);
      expect(find.byType(BrowserPageCard), findsOneWidget);
      final collapsedY = tester.getTopLeft(find.byType(BrowserPageCard)).dy;
      await toggle(tester);
      expect(steps(), findsNWidgets(3));
      expect(
        tester.getBottomLeft(step('c')).dy,
        lessThan(tester.getTopLeft(find.byType(BrowserPageCard)).dy),
      );
      expect(
        tester.getTopLeft(find.byType(BrowserPageCard)).dy,
        greaterThan(collapsedY),
      );
      expect(
        tester.getTopLeft(find.byType(BrowserPageCard)).dy,
        greaterThan(tester.getTopLeft(step('c')).dy),
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString() == '_TimelineLinePainter',
        ),
        findsNWidgets(4),
      );
      expect(
        find.byKey(const ValueKey('browser-actions-toggle')),
        findsNothing,
      );
      expect(find.text('3 actions'), findsNothing);
      expect(find.text('Collapse'), findsNothing);
      final paints = tester.widgetList<CustomPaint>(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString() == '_TimelineLinePainter',
        ),
      );
      final positions = paints
          .map((w) => tester.getTopLeft(find.byWidget(w)).dx)
          .toSet();
      expect(positions, hasLength(1));
      await toggle(tester);
      expect(steps(), findsNothing);
      expect(find.byType(BrowserPageCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview stays mounted and moves continuously in both directions',
    (tester) async {
      await pump(tester, [_tool('a'), _tool('b'), _tool('c')]);
      final preview = find.byType(BrowserStepGroupBody);
      final card = find.byType(BrowserPageCard);
      final state = tester.state(preview);
      final element = tester.element(card);
      final widget = tester.widget<BrowserPageCard>(card);
      double y() => tester.getTopLeft(card).dy;
      final collapsedY = y();
      await tester.tap(find.text('Browsing'));
      await tester.pump();
      expect(
        y(),
        closeTo(collapsedY, .01),
        reason: 'Do not teleport the preview on the first frame',
      );
      var previousY = y();
      for (final ms in [16, 32, 48, 80, 140]) {
        await tester.pump(Duration(milliseconds: ms));
        expect(y(), greaterThanOrEqualTo(previousY));
        expect(tester.state(preview), same(state));
        expect(tester.element(card), same(element));
        expect(tester.widget<BrowserPageCard>(card), same(widget));
        previousY = y();
      }
      final expandedY = y();
      expect(expandedY, greaterThan(collapsedY + 60));
      await tester.tap(find.text('Browsing'));
      await tester.pump();
      expect(y(), closeTo(expandedY, .01));
      await tester.pump(const Duration(milliseconds: 70));
      expect(
        steps(),
        findsNWidgets(3),
        reason: 'Closing keeps the existing rows until the clip closes',
      );
      final closingY = y();
      expect(closingY, inExclusiveRange(collapsedY, expandedY));
      await tester.tap(find.text('Browsing'));
      await tester.pump();
      expect(
        y(),
        closeTo(closingY, .01),
        reason: 'Mid-flight reversal must preserve the current position',
      );
      await tester.pumpAndSettle();
      expect(y(), closeTo(expandedY, .01));
      await toggle(tester);
      expect(y(), closeTo(collapsedY, .01));
      expect(steps(), findsNothing);
      expect(tester.state(preview), same(state));
      expect(tester.element(card), same(element));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing a long expanded list keeps its rows until settled then resets the tail',
    (tester) async {
      await pump(tester, [for (var i = 0; i < 12; i++) _tool('$i')]);
      await toggle(tester);
      await tester.tap(find.text('7 earlier steps'));
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(find.byType(BrowserPageCard)).dy;
      await tester.tap(find.text('Browsing'));
      await tester.pump();
      expect(steps(), findsNWidgets(12));
      expect(
        tester.getTopLeft(find.byType(BrowserPageCard)).dy,
        closeTo(before, .01),
      );
      await tester.pumpAndSettle();
      expect(steps(), findsNothing);
      await toggle(tester);
      expect(steps(), findsNWidgets(5));
      expect(find.text('7 earlier steps'), findsOneWidget);
    },
  );

  testWidgets(
    'reduced motion applies the new layout immediately and keeps the preview',
    (tester) async {
      await pump(tester, [_tool('a'), _tool('b')], reduceMotion: true);
      final state = tester.state(find.byType(BrowserStepGroupBody));
      await tester.tap(find.text('Browsing'));
      await tester.pump();
      expect(steps(), findsNWidgets(2));
      await tester.tap(find.text('Browsing'));
      await tester.pump();
      expect(steps(), findsNothing);
      expect(tester.state(find.byType(BrowserStepGroupBody)), same(state));
      await pump(
        tester,
        [_tool('a'), _tool('b', loading: true)],
        conversationId: 'new-chat',
        reduceMotion: true,
      );
      expect(steps(), findsNothing);
      await pump(
        tester,
        [_tool('a'), _tool('b')],
        conversationId: 'new-chat',
        reduceMotion: true,
      );
      expect(steps(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failure expands by default and remains counted when collapsed', (
    tester,
  ) async {
    await pump(tester, [
      _tool('a'),
      _tool('b', action: 'click', error: 'stale_ref:e12'),
    ]);
    expect(steps(), findsNWidgets(2));
    expect(find.text('Click failed'), findsOneWidget);
    expect(
      find.text('Element is stale; page needs re-reading'),
      findsOneWidget,
    );
    expect(find.text('· 1 failed'), findsOneWidget);
    await toggle(tester);
    expect(steps(), findsNothing);
    expect(find.text('· 1 failed'), findsOneWidget);
  });

  testWidgets('running actions share the header without expanding the list', (
    tester,
  ) async {
    await pump(tester, [
      _tool('a'),
      _tool('b', action: 'click', loading: true),
    ]);
    expect(steps(), findsNothing);
    expect(find.text('Click'), findsOneWidget);
    expect(find.text('step 2'), findsOneWidget);
    final card = tester.element(find.byType(BrowserPageCard));
    final y = tester.getTopLeft(find.byType(BrowserPageCard)).dy;
    await pump(tester, [
      _tool('a'),
      _tool('b', action: 'click'),
    ], streaming: true);
    expect(find.text('Click'), findsOneWidget);
    expect(steps(), findsNothing);
    await pump(tester, [
      _tool('a'),
      _tool('b'),
      _tool('c', action: 'scroll', loading: true),
    ]);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Scroll'), findsOneWidget);
    expect(tester.element(find.byType(BrowserPageCard)), same(card));
    expect(tester.getTopLeft(find.byType(BrowserPageCard)).dy, closeTo(y, .01));
    await pump(tester, [_tool('a'), _tool('b'), _tool('c')]);
    await tester.pumpAndSettle();
    expect(find.text('Browsing'), findsOneWidget);
    expect(steps(), findsNothing);
    // Users may still inspect steps while the agent runs; keep their choice.
    await pump(tester, [_tool('a'), _tool('b', loading: true)]);
    await toggle(tester);
    expect(steps(), findsNWidgets(2));
    await pump(tester, [_tool('a'), _tool('b')]);
    expect(steps(), findsNWidgets(2));
  });

  testWidgets('hiding webpage cards preserves the group and its details', (
    tester,
  ) async {
    await pump(tester, [_tool('a'), _tool('b')]);
    expect(find.byType(BrowserPageCard), findsOneWidget);
    await tester.runAsync(() => settings.setShowBrowserPageCards(false));
    await tester.pumpAndSettle();
    expect(find.byType(BrowserStepGroupBody), findsNothing);
    expect(find.text('Browsing'), findsOneWidget);
    await toggle(tester);
    expect(steps(), findsNWidgets(2));
    await tester.runAsync(() => settings.setShowBrowserPageCards(true));
    await tester.pumpAndSettle();
    expect(find.byType(BrowserPageCard), findsOneWidget);
  });

  testWidgets(
    'long groups show five recent steps and resolve folded snapshot refs',
    (tester) async {
      await pump(tester, [
        _tool(
          '0',
          action: 'snapshot',
          page: {
            'elements': [
              {'ref': 'e12', 'name': 'Releases'},
            ],
          },
        ),
        for (var i = 1; i < 12; i++)
          _tool('$i', action: 'click', args: {'ref': 'e12'}),
      ]);
      await toggle(tester);
      expect(steps(), findsNWidgets(5));
      expect(find.text('7 earlier steps'), findsOneWidget);
      expect(find.text('「Releases」'), findsNWidgets(5));
      await tester.tap(find.text('7 earlier steps'));
      await tester.pumpAndSettle();
      expect(steps(), findsNWidgets(12));
      expect(tester.takeException(), isNull);
      await toggle(tester);
      await toggle(tester);
      expect(steps(), findsNWidgets(5));
    },
  );

  for (final desktop in [false, true]) {
    testWidgets(
      '${desktop ? 'desktop dialog' : 'mobile sheet'} shows the tapped step and closed tab header',
      (tester) async {
        debugDefaultTargetPlatformOverride = desktop
            ? TargetPlatform.macOS
            : TargetPlatform.iOS;
        try {
          await pump(tester, [
            _tool('a'),
            _tool('b', action: 'click', args: {'ref': 'e12'}),
            _tool('c', action: 'type', args: {'text': 'last-step-only'}),
          ], narrow: !desktop);
          await toggle(tester);
          await tester.tap(
            find.descendant(of: step('b'), matching: find.text('Click')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('tool_detail_desktop_dialog')),
            desktop ? findsOneWidget : findsNothing,
          );
          final sections = tester
              .widgetList<ToolDetailTextSection>(
                find.byType(ToolDetailTextSection),
              )
              .toList();
          expect(
            sections.map((section) => section.label),
            containsAll(['Arguments', 'Result']),
          );
          expect(sections.first.text, contains('"ref": "e12"'));
          expect(sections.first.text, isNot(contains('last-step-only')));
          expect(
            find.byKey(const ValueKey('browser-step-detail-page')),
            findsOneWidget,
          );
          final button = tester.widget<TextButton>(
            find.byKey(const ValueKey('browser-step-detail-open')),
          );
          expect(button.onPressed, isNull);
          final pageRect = tester.getRect(
            find.byKey(const ValueKey('browser-step-detail-page')),
          );
          final buttonRect = tester.getRect(
            find.byKey(const ValueKey('browser-step-detail-open')),
          );
          expect(
            buttonRect.right,
            closeTo(pageRect.right - 10, 1),
            reason: 'The action must align with the trailing page inset',
          );
          expect(find.text('Tab was closed'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }

  for (final (action, resultPage) in [
    (
      'list_tabs',
      {
        'scope': 'conversation',
        'tabs': [
          {'tab_id': 'a'},
          {'tab_id': 'b'},
        ],
      },
    ),
    ('close_tab', {'closed_tab_id': 'old-tab'}),
  ]) {
    testWidgets(
      '$action result does not invent a closed-page information bar',
      (tester) async {
        await pump(tester, [
          ToolUIPart(
            id: 'list',
            toolName: LocalToolNames.browser,
            arguments: {'action': action},
            content: jsonEncode({
              'ok': true,
              'action': action,
              'page': resultPage,
            }),
          ),
        ]);
        await toggle(tester);
        await tester.tap(
          find.descendant(
            of: step('list'),
            matching: find.text(
              action == 'list_tabs' ? 'List tabs' : 'Close tab',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('browser-step-detail-page')),
          findsNothing,
        );
        expect(find.text('Tab was closed'), findsNothing);
        expect(find.byType(ToolDetailTextSection), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('failed detail keeps raw error beside its readable explanation', (
    tester,
  ) async {
    await pump(tester, [_tool('a', action: 'click', error: 'stale_ref:e12')]);
    await tester.tap(find.text('Click failed'));
    await tester.pumpAndSettle();
    final header = find.byKey(const ValueKey('browser-step-detail-error'));
    expect(
      find.descendant(of: header, matching: find.text('stale_ref:e12')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: header,
        matching: find.text('Element is stale; page needs re-reading'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'screenshots are per-step, bounded and follow the image setting',
    (tester) async {
      await tester.runAsync(() => settings.setShowToolResultSummary(false));
      await pump(tester, [_tool('a', image: _image), _tool('b')]);
      await toggle(tester);
      final shot = find.byKey(const ValueKey('tool-image-thumbnails:a'));
      expect(find.descendant(of: step('a'), matching: shot), findsOneWidget);
      expect(tester.getSize(shot).height, 64);
      expect(find.byType(BrowserPageCard), findsOneWidget);
      await tester.runAsync(() => settings.setHideToolResultImages(true));
      await tester.pumpAndSettle();
      expect(shot, findsNothing);
      expect(find.byType(BrowserPageCard), findsOneWidget);
    },
  );

  testWidgets('only changed page results add row favicons', (tester) async {
    await pump(tester, [
      _tool('a'),
      _tool('b'),
      _tool('c', url: 'https://example.org'),
    ]);
    await toggle(tester);
    expect(
      find.descendant(of: step('a'), matching: find.byType(BrowserFavicon)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: step('b'), matching: find.byType(BrowserFavicon)),
      findsNothing,
    );
    expect(
      find.descendant(of: step('c'), matching: find.byType(BrowserFavicon)),
      findsOneWidget,
    );
  });

  testWidgets('local expansion does not rebuild other tool steps', (
    tester,
  ) async {
    await pump(tester, [
      const ToolUIPart(
        id: 'other',
        toolName: 'example_tool',
        arguments: {},
        content: 'done',
      ),
      _tool('a'),
      _tool('b'),
    ]);
    final before = debugTimelineToolStepBuilds;
    await toggle(tester);
    await toggle(tester);
    expect(debugTimelineToolStepBuilds, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow large-text rows fit and use chat foreground tokens', (
    tester,
  ) async {
    await pump(
      tester,
      [
        _tool('a', action: 'snapshot'),
        _tool('b', action: 'click', error: 'stale_ref'),
      ],
      narrow: true,
      scale: 1.6,
    );
    final label = find.text('Browsing');
    final fg = chatSurfaceForegroundPalette(tester.element(label));
    expect(tester.widget<Text>(label).style!.color, fg.strong);
    expect(tester.widget<Text>(find.text('2 steps')).style!.color, fg.medium);
  });
}
