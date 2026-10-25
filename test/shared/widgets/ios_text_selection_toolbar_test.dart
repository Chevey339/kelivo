import 'dart:async';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:Kelivo/shared/widgets/app_text_selection_toolbar.dart';
import 'package:Kelivo/shared/widgets/ios_text_selection_toolbar.dart';
import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';

import '../../support/business_test_harness.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  const channel = MethodChannel('app.ios_selection_menu');
  const codec = StandardMethodCodec();
  final calls = <MethodCall>[];
  var supported = true;
  var shown = true;
  String? clipboard;

  setUp(() {
    IosTextSelectionToolbar.resetAvailabilityForTesting();
    calls.clear();
    supported = true;
    shown = true;
    clipboard = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'isAvailable' => supported,
        'show' => shown,
        _ => null,
      };
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      if (call.method == 'Clipboard.getData') return {'text': clipboard};
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Map<dynamic, dynamic> lastMenu() =>
      calls.lastWhere((call) => call.method == 'show').arguments as Map;
  List<String> labels(Map<dynamic, dynamic> menu) => [
    for (final item in menu['items'] as List) (item as Map)['title'] as String,
  ];
  Future<void> event(
    String method,
    Map<dynamic, dynamic> menu, {
    int? index,
  }) async {
    await messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(
        MethodCall(method, {
          'session': menu['session'],
          'revision': menu['revision'],
          'index': index,
        }),
      ),
      (_) {},
    );
  }

  Future<void> press(String label) async {
    final menu = lastMenu();
    final index = labels(menu).indexOf(label);
    expect(index, greaterThanOrEqualTo(0));
    await event('action', menu, index: index);
  }

  Widget harness(Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
  Widget toolbar({
    VoidCallback? action,
    VoidCallback? dismissed,
    String label = 'Custom',
    double y = 160,
  }) => Builder(
    builder: (context) => AppTextSelectionToolbar(
      anchors: TextSelectionToolbarAnchors(primaryAnchor: Offset(120, y)),
      selectionContext: context,
      onDismiss: dismissed ?? () {},
      buttonItems: [
        ContextMenuButtonItem(label: label, onPressed: action ?? () {}),
      ],
    ),
  );
  const ios = TargetPlatformVariant({TargetPlatform.iOS});

  testWidgets(
    'other platforms never contact the native menu bridge',
    (tester) async {
      await tester.pumpWidget(harness(toolbar()));
      await tester.pumpAndSettle();
      expect(find.text('Custom'), findsOneWidget);
      expect(calls, isEmpty);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );

  testWidgets('older iOS retains Flutter menus and checks availability once', (
    tester,
  ) async {
    supported = false;
    for (var i = 0; i < 2; i++) {
      await tester.pumpWidget(harness(toolbar()));
      await tester.pumpAndSettle();
      expect(find.text('Custom'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(calls.map((call) => call.method), ['isAvailable']);
  }, variant: ios);

  testWidgets(
    'disabling an open native menu retires it and restores Flutter actions',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      addTearDown(settings.dispose);
      await settings.loaded;
      var actions = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: harness(toolbar(action: () => actions++)),
        ),
      );
      await tester.pumpAndSettle();
      final retiredMenu = lastMenu();
      await settings.setIosNativeSelectionMenuEnabled(false);
      await tester.pumpAndSettle();
      expect(find.text('Custom'), findsOneWidget);
      expect(calls.map((call) => call.method), ['isAvailable', 'show', 'hide']);
      await event('action', retiredMenu, index: 0);
      expect(actions, 0);
      await tester.tap(find.text('Custom'));
      expect(actions, 1);

      await settings.setIosNativeSelectionMenuEnabled(true);
      await tester.pumpAndSettle();
      expect(find.text('Custom'), findsNothing);
      expect(calls.map((call) => call.method), [
        'isAvailable',
        'show',
        'hide',
        'show',
      ]);
      await press('Custom');
      expect(actions, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: ios,
  );

  testWidgets(
    'unchanged rebuilds send no native updates and use current callbacks',
    (tester) async {
      var value = 0;
      for (var i = 0; i < 20; i++) {
        final next = i;
        await tester.pumpWidget(harness(toolbar(action: () => value = next)));
        await tester.pumpAndSettle();
      }
      expect(calls.map((call) => call.method), ['isAvailable', 'show']);
      expect(find.text('Custom'), findsNothing);
      await press('Custom');
      expect(value, 19);
      await press('Custom');
      expect(value, 19);
      expect(calls.where((call) => call.method == 'hide'), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: ios,
  );

  testWidgets(
    'stale actions and stale dismissals cannot affect another selection',
    (tester) async {
      var actions = 0;
      var dismissals = 0;
      await tester.pumpWidget(
        harness(
          toolbar(action: () => actions++, dismissed: () => dismissals++),
        ),
      );
      await tester.pumpAndSettle();
      final old = lastMenu();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        harness(
          toolbar(action: () => actions++, dismissed: () => dismissals++),
        ),
      );
      await tester.pumpAndSettle();
      await event('action', old, index: 0);
      await event('dismissed', old);
      expect(actions, 0);
      expect(dismissals, 0);
      await press('Custom');
      expect(actions, 1);
      expect(dismissals, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: ios,
  );

  testWidgets(
    'replaced menu items reject callbacks from the previous revision',
    (tester) async {
      var actions = 0;
      await tester.pumpWidget(harness(toolbar(action: () => actions++)));
      await tester.pumpAndSettle();
      final previous = lastMenu();
      await tester.pumpWidget(
        harness(toolbar(label: 'Changed', action: () => actions++)),
      );
      await tester.pumpAndSettle();
      expect(lastMenu()['session'], previous['session']);
      await event('action', previous, index: 0);
      expect(actions, 0);
      await press('Changed');
      expect(actions, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: ios,
  );

  testWidgets('disposing while availability is pending cannot present a menu', (
    tester,
  ) async {
    final ready = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'isAvailable') return ready.future;
      return true;
    });
    await tester.pumpWidget(harness(toolbar()));
    await tester.pumpWidget(const SizedBox.shrink());
    ready.complete(true);
    await tester.pumpAndSettle();
    expect(calls.map((call) => call.method), ['isAvailable']);
  }, variant: ios);

  testWidgets('failed native presentation leaves the Flutter actions usable', (
    tester,
  ) async {
    shown = false;
    var invoked = false;
    await tester.pumpWidget(harness(toolbar(action: () => invoked = true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    expect(invoked, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: ios);

  testWidgets('long editor offscreen primary uses only its secondary anchor', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        Builder(
          builder: (context) => AppTextSelectionToolbar(
            anchors: const TextSelectionToolbarAnchors(
              primaryAnchor: Offset(-10000, -10000),
              secondaryAnchor: Offset(240, 320),
            ),
            selectionContext: context,
            onDismiss: () {},
            buttonItems: [
              ContextMenuButtonItem(label: 'Copy', onPressed: () {}),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(lastMenu()['rect'], [240.0, 320.0, 1.0, 1.0]);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: ios);

  testWidgets('parent programmatic scrolling retires the native menu once', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var dismissed = 0;
    await tester.pumpWidget(
      harness(
        SingleChildScrollView(
          controller: scroll,
          child: SizedBox(
            height: 1200,
            child: toolbar(dismissed: () => dismissed++),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    scroll.jumpTo(10);
    scroll.jumpTo(20);
    await tester.pump();
    expect(dismissed, 1);
    expect(calls.where((call) => call.method == 'hide'), hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: ios);

  testWidgets('backgrounding and UIKit dismissal close the menu', (
    tester,
  ) async {
    var dismissed = 0;
    await tester.pumpWidget(harness(toolbar(dismissed: () => dismissed++)));
    await tester.pumpAndSettle();
    await event('dismissed', lastMenu());
    expect(dismissed, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(harness(toolbar(dismissed: () => dismissed++)));
    await tester.pumpAndSettle();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(dismissed, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }, variant: ios);

  testWidgets(
    'unchanged UIKit metrics preserve menu actions; resizing dismisses',
    (tester) async {
      var actions = 0;
      var dismissals = 0;
      await tester.pumpWidget(
        harness(
          toolbar(action: () => actions++, dismissed: () => dismissals++),
        ),
      );
      await tester.pumpAndSettle();
      binding.handleMetricsChanged();
      binding.handleMetricsChanged();
      await tester.pumpAndSettle();
      expect(dismissals, 0);
      expect(calls.where((call) => call.method == 'show'), hasLength(1));
      await press('Custom');
      expect(actions, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(harness(toolbar(dismissed: () => dismissals++)));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(900, 600);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pump();
      expect(dismissals, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: ios,
  );

  for (final nativeMenus in [true, false]) {
    testWidgets(
      'read-only Markdown preserves copy without opening text input (native: $nativeMenus)',
      (tester) async {
        final settings = SettingsProvider(createBusinessTestPreferences());
        addTearDown(settings.dispose);
        await settings.loaded;
        await settings.setIosNativeSelectionMenuEnabled(nativeMenus);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: settings,
            child: harness(
              const AppSelectionArea(
                child: MarkstreamView(
                  source: '**Bold** 中文\n\n| A | B |\n| - | - |\n| 1 | 2 |',
                  cullToViewport: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final region = tester.state<SelectableRegionState>(
          find.byType(SelectableRegion),
        );
        region.selectAll(SelectionChangedCause.toolbar);
        await tester.pumpAndSettle();
        expect(tester.testTextInput.hasAnyClients, isFalse);
        if (nativeMenus) {
          expect(
            labels(lastMenu()),
            containsAll(['Copy', 'Copy Markdown', 'Copy rich text']),
          );
          expect(
            lastMenu().keys,
            unorderedEquals(['session', 'revision', 'rect', 'items']),
          );
          await press('Copy Markdown');
        } else {
          expect(calls, isEmpty);
          await tester.tap(
            find.descendant(
              of: find.byType(AppTextSelectionToolbar),
              matching: find.text('Copy Markdown'),
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(clipboard, contains('**Bold**'));
        expect(clipboard, contains('| A | B |'));
        if (!nativeMenus) expect(calls, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: ios,
    );

    for (final long in [false, true]) {
      testWidgets(
        'input preserves custom newline and copy actions (long: $long, native: $nativeMenus)',
        (tester) async {
          final source = long ? '中文 line\n' * 500 : '中文 short';
          final controller = TextEditingController(text: source);
          final focus = FocusNode();
          addTearDown(controller.dispose);
          addTearDown(focus.dispose);
          final settings = SettingsProvider(createBusinessTestPreferences());
          addTearDown(settings.dispose);
          await settings.loaded;
          await settings.setIosNativeSelectionMenuEnabled(nativeMenus);
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: settings),
                ChangeNotifierProvider.value(
                  value: AssistantProvider(
                    preferences: createBusinessTestPreferences(),
                  ),
                ),
              ],
              child: harness(
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ChatInputBar(controller: controller, focusNode: focus),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          focus.requestFocus();
          await tester.pumpAndSettle();
          if (!long) {
            await tester.tap(find.byType(TextField));
            await tester.pumpAndSettle();
          }
          Future<void> open() async {
            controller.selection = const TextSelection(
              baseOffset: 0,
              extentOffset: 2,
            );
            await tester.pump();
            if (!long) {
              tester
                  .state<EditableTextState>(find.byType(EditableText))
                  .showToolbar();
            } else {
              final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
              final target = find
                  .descendant(
                    of: find.byType(CodeEditor),
                    matching: find.byType(CompositedTransformTarget),
                  )
                  .first;
              // Use the same controller and builder that the mobile long-press
              // path calls and its real layer link so Flutter buttons are hittable.
              editor.toolbarController!.show(
                context: tester.element(find.byType(CodeEditor)),
                controller: editor.controller!,
                anchors: const TextSelectionToolbarAnchors(
                  primaryAnchor: Offset(120, 200),
                ),
                renderRect: tester.getRect(target),
                layerLink: tester
                    .widget<CompositedTransformTarget>(target)
                    .link,
                visibility: ValueNotifier(true),
              );
            }
            await tester.pumpAndSettle();
          }

          Future<void> invokeAction(String label) async {
            if (nativeMenus) {
              await press(label);
            } else {
              expect(calls, isEmpty);
              await tester.tap(find.text(label));
            }
          }

          await open();
          if (nativeMenus) {
            expect(labels(lastMenu()), [
              'Cut',
              'Copy',
              'Paste',
              'Newline',
              'Select all',
            ]);
          }
          await invokeAction('Copy');
          await tester.pumpAndSettle();
          expect(clipboard, '中文');
          expect(controller.text, source);
          if (!long) {
            final editable = tester.state<EditableTextState>(
              find.byType(EditableText),
            );
            final render = editable.renderEditable;
            final textPoint = render.localToGlobal(
              render.getLocalRectForCaret(const TextPosition(offset: 1)).center,
            );
            await tester.tapAt(textPoint);
            await tester.pump(const Duration(milliseconds: 100));
            await tester.tapAt(textPoint);
            await tester.pumpAndSettle();
            expect(editable.selectionOverlay!.handlesAreVisible, isTrue);
            final before = controller.selection;
            expect(before.isCollapsed, isFalse);
            final end = render.getEndpointsForSelection(before).last.point;
            final gesture = await tester.startGesture(
              render.localToGlobal(end) + const Offset(1, 1),
            );
            await tester.pump();
            expect(
              editable.selectionOverlay!.handlesAreVisible,
              isTrue,
              reason:
                  'Dismissing the native menu must keep the touched handle alive',
            );
            await gesture.moveTo(
              render.localToGlobal(
                render
                    .getLocalRectForCaret(TextPosition(offset: source.length))
                    .center,
              ),
            );
            await tester.pump();
            await gesture.up();
            await tester.pumpAndSettle();
            expect(
              controller.selection.extentOffset,
              greaterThan(before.extentOffset),
            );
          }
          await open();
          await invokeAction('Newline');
          await tester.pumpAndSettle();
          expect(controller.text, '\n${source.substring(2)}');
          expect(focus.hasFocus, isTrue);
          expect(find.byType(LongMessageEditor), findsOneWidget);
          if (!nativeMenus) expect(calls, isEmpty);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: ios,
      );
    }
  }
}
