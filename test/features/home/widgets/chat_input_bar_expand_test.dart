import '../../../support/business_test_harness.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  const barKey = Key('bar');
  const bodyHeight = 600.0;

  Future<List<bool>> pumpBar(
    WidgetTester tester,
    TextEditingController controller, {
    ChatInputSubmissionResult sendResult = ChatInputSubmissionResult.rejected,
    bool showBar = true,
  }) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    final expandedEvents = <bool>[];
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
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 400,
                height: bodyHeight,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: showBar
                      ? ChatInputBar(
                          key: barKey,
                          controller: controller,
                          focusNode: FocusNode(),
                          onExpandedChanged: expandedEvents.add,
                          onSend: (_) async => sendResult,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return expandedEvents;
  }

  double barHeight(WidgetTester tester) =>
      tester.getSize(find.byKey(barKey)).height;

  testWidgets('offers expansion only once the text wraps past two lines', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'short');
    addTearDown(controller.dispose);
    await pumpBar(tester, controller);
    expect(find.byTooltip('Expand'), findsNothing);

    // A single long paragraph with no line breaks still counts.
    await tester.enterText(find.byType(TextField), 'word ' * 80);
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('Expand'), findsOneWidget);
  });

  testWidgets('expand button never flickers as the text reflows around it', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpBar(tester, controller);

    // A long unbreakable word can wrap onto fewer lines when the field is
    // narrower, which once made the button toggle itself every frame.
    for (var n = 1; n <= 60; n++) {
      await tester.enterText(find.byType(TextField), 'This is a ${'x' * n}');
      await tester.pump();
      await tester.pump();
      final visible = find.byTooltip('Expand').evaluate().isNotEmpty;
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump();
        expect(
          find.byTooltip('Expand').evaluate().isNotEmpty,
          visible,
          reason: 'n=$n',
        );
      }
    }
  });

  testWidgets('expands to the full host height and back', (tester) async {
    final controller = TextEditingController(text: 'line\n' * 6);
    addTearDown(controller.dispose);
    final events = await pumpBar(tester, controller);
    final collapsedHeight = barHeight(tester);
    expect(collapsedHeight, lessThan(bodyHeight / 2));

    await tester.tap(find.byTooltip('Expand'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final midway = barHeight(tester);
    expect(midway, greaterThan(collapsedHeight));
    expect(midway, lessThan(bodyHeight));

    await tester.pumpAndSettle();
    expect(barHeight(tester), bodyHeight);
    expect(events, [true]);

    await tester.tap(find.byTooltip('Collapse'));
    await tester.pumpAndSettle();
    expect(barHeight(tester), collapsedHeight);
    expect(events, [true, false]);
  });

  testWidgets('collapse lands on the height of text edited while expanded', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'line\n' * 2 + 'line');
    addTearDown(controller.dispose);
    await pumpBar(tester, controller);

    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'line\n' * 12);
    await tester.pump();

    await tester.tap(find.byTooltip('Collapse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 318));
    final lastAnimatedFrame = barHeight(tester);
    await tester.pumpAndSettle();
    expect((lastAnimatedFrame - barHeight(tester)).abs(), lessThan(1));
  });

  testWidgets('survives a long press and rapid toggling mid-animation', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'line\n' * 6);
    addTearDown(controller.dispose);
    await pumpBar(tester, controller);

    await tester.longPress(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      final expand = find.byTooltip('Expand');
      await tester.tap(
        expand.evaluate().isNotEmpty ? expand : find.byTooltip('Collapse'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rejected send keeps the restored draft expanded', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'line\n' * 6);
    addTearDown(controller.dispose);
    await pumpBar(tester, controller);
    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Lucide.ArrowUp));
    await tester.pumpAndSettle();
    expect(barHeight(tester), bodyHeight);
    expect(controller.text, 'line\n' * 6);
  });

  testWidgets('an accepted send collapses the editor', (tester) async {
    final controller = TextEditingController(text: 'line\n' * 6);
    addTearDown(controller.dispose);
    final events = await pumpBar(
      tester,
      controller,
      sendResult: ChatInputSubmissionResult.sent,
    );
    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Lucide.ArrowUp));
    await tester.pumpAndSettle();
    expect(barHeight(tester), lessThan(bodyHeight / 2));
    expect(events, [true, false]);
  });

  testWidgets('removing an expanded bar reports that expansion ended', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'line\n' * 6);
    addTearDown(controller.dispose);
    final events = await pumpBar(tester, controller);
    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    expect(events, [true]);

    await pumpBar(tester, controller, showBar: false);
    expect(events, [true, false]);
  });

  testWidgets('system back collapses instead of leaving the page', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'line\n' * 6);
    addTearDown(controller.dispose);
    await pumpBar(tester, controller);
    final collapsedHeight = barHeight(tester);

    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(barHeight(tester), collapsedHeight);
    expect(find.byKey(barKey), findsOneWidget);
  });
}
