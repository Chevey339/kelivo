import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_user_context_parts.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_web_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_context_chip.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_expansion.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_slider.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_text_input.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'genui_scenario_host.dart';
import 'message_test_services.dart';

/// Run identically in widget tests and native integration executables. Text
/// replacement here is test input; real Chinese/English IME has its own probe.
Future<List<String>> exerciseGenUiScenarios(
  WidgetTester tester, {
  bool checkSemantics = true,
}) async {
  final directory = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('genui-scenes-'),
  ))!;
  final services = (await tester.runAsync(MessageTestServices.open))!;
  final file = File('${directory.path}/scenes.sqlite');
  var session = (await tester.runAsync(() => GenUiScenarioSession.open(file)))!;
  // Native runs leave enablement to the OS. Widget runs explicitly own a
  // handle for deterministic tree assertions independently of screen readers.
  final semantics = checkSemantics ? tester.ensureSemantics() : null;
  final completed = <String>[];
  final nativeViews = UiWebController.createdNativeViews;
  GlobalKey<GenUiScenarioHostState>? key;

  Future<void> settle() async {
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> until(bool Function() ready) async {
    for (var n = 0; n < 200 && !ready(); n++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    expect(ready(), isTrue);
  }

  Finder field(String id) => find.descendant(
    of: find.byWidgetPredicate((w) => w is GenUiTextInput && w.id == id),
    matching: find.byType(TextField),
  );
  UiSurfaceController surface() =>
      tester.widget<GenUiSurface>(find.byType(GenUiSurface)).controller;
  Future<void> tap(Finder target) async {
    await tester.ensureVisible(target);
    await settle();
    await tester.tap(target);
    await settle();
  }

  Future<void> type(String id, String value) async {
    await tester.ensureVisible(field(id));
    await tester.enterText(field(id), value);
    await settle();
  }

  Future<void> mount(String scene, {bool expanded = true}) async {
    await tester.pumpWidget(const SizedBox());
    await settle();
    key = GlobalKey<GenUiScenarioHostState>();
    await tester.pumpWidget(
      GenUiScenarioHost(
        key: key,
        session: session,
        services: services,
        scene: scene,
      ),
    );
    await settle();
    expect(find.byType(GenUiSurface), findsOneWidget);
    expect(surface().parsed.program.diagnostics, isEmpty);
    expect(surface().nodes.values.every((node) => node.valid), isTrue);
    if (expanded) {
      await tap(
        find.byWidgetPredicate(
          (w) => w is IosIconButton && w.tooltip == 'Expand',
        ),
      );
      expect(
        find.descendant(
          of: find.byType(GenUiExpansion, skipOffstage: false),
          matching: find.byType(RawImage, skipOffstage: false),
        ),
        findsOneWidget,
      );
      expect(find.byType(GenUiExpandedStub, skipOffstage: false), findsNothing);
      expect(find.byType(GenUiSurface, skipOffstage: false), findsOneWidget);
    }
  }

  Future<void> collapse() async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle();
    expect(find.text('Being edited in expanded view'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(GenUiExpansion),
        matching: find.byType(RawImage),
      ),
      findsNothing,
    );
  }

  void done(String scene) {
    expect(UiWebController.createdNativeViews, nativeViews);
    expect(
      session.sent,
      isEmpty,
      reason: 'Local interaction and Ask never send',
    );
    completed.add(scene);
  }

  try {
    await mount('S1');
    await type('hoursInput', '3');
    await type('initialInput', '7');
    final slider = find.byType(GenUiSlider);
    await tap(slider);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle();
    expect(surface().captureRead().inputs, {
      'speed': 1.0,
      'hours': 3.0,
      'initial': 7.0,
    });
    expect(surface().nodes['result']!.properties['value'], 10);
    if (checkSemantics) {
      final sliderNode = tester.getSemantics(
        find.bySemanticsLabel('Speed').first,
      );
      expect(
        sliderNode.getSemanticsData().hasAction(ui.SemanticsAction.increase),
        isTrue,
      );
    }
    await tester.runAsync(session.repository.genUiStates.flush);
    await collapse();
    final saved = surface().state.json;
    await tester.pumpWidget(
      GenUiScenarioHost(
        key: key,
        session: session,
        services: services,
        scene: 'S1',
        dark: true,
        scale: 1.3,
        rtl: true,
      ),
    );
    await settle();
    expect(surface().state.json, saved);
    await tester.pumpWidget(const SizedBox());
    await settle();
    await tester.runAsync(session.close);
    session = (await tester.runAsync(() => GenUiScenarioSession.open(file)))!;
    await mount('S1');
    await until(() => surface().state.json == saved);
    expect(surface().nodes['result']!.properties['value'], 10);
    done('S1');

    await mount('S2');
    final c2 = surface();
    expect(c2.nodes['chart']!.chartData!.domainRows, isNotEmpty);
    expect(
      c2.nodes['chart']!.properties['data'],
      c2.nodes['table']!.properties['data'],
    );
    await tap(find.byType(GenUiSlider));
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await settle();
    expect(c2.nodes['chart']!.chartData!.domainRows, isEmpty);
    expect(
      c2.nodes['chart']!.properties['data'],
      c2.nodes['table']!.properties['data'],
    );
    await tap(
      find.descendant(
        of: find.byKey(const ValueKey('genui-chart-view-chart')),
        matching: find.text('Data'),
      ),
    );
    expect(c2.state.view['chart']?['dataView'], isTrue);
    expect(key!.currentState!.requests, 0);
    done('S2');

    await mount('S3');
    expect(surface().nodes['chart']!.chartData!.missingCount, 1);
    if (checkSemantics) {
      expect(
        find.bySemanticsLabel(RegExp('3 series, 4 data rows, 1 missing value')),
        findsOneWidget,
      );
    }
    await tap(find.byKey(const ValueKey('genui-chart-legend-chart-1')));
    expect(surface().state.view['chart']?['hiddenSeries'], [1]);
    await tap(find.byKey(const ValueKey('genui-chart-legend-chart-1')));
    await tap(find.byKey(const ValueKey('genui-chart-canvas-chart')));
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await settle();
    expect(
      find.byKey(const ValueKey('genui-chart-tooltip-chart')),
      findsOneWidget,
    );
    await tap(
      find.descendant(
        of: find.byKey(const ValueKey('genui-chart-view-chart')),
        matching: find.text('Data'),
      ),
    );
    expect(surface().state.view['chart']?['dataView'], isTrue);
    done('S3');

    await mount('S4');
    await tap(find.byKey(const ValueKey('genui-table-next-table')));
    expect(surface().state.view['table']?['page'], 1);
    expect(find.text('11–12 / 12'), findsOneWidget);
    await tap(find.byKey(const ValueKey('genui-table-page-size-table')));
    await tap(find.text('20/page'));
    final sort = find.byKey(const ValueKey('genui-table-sort-table-price'));
    List<String> rowNames() => tester
        .widgetList<Text>(
          find.descendant(of: find.byType(Table), matching: find.byType(Text)),
        )
        .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
        .where((text) => text.startsWith('Plan '))
        .toList();
    await tap(sort);
    expect(rowNames().take(3), ['Plan 03', 'Plan 01', 'Plan 02']);
    expect(rowNames().last, 'Plan 04');
    await tap(sort);
    expect(rowNames().first, 'Plan 12');
    expect(rowNames().last, 'Plan 04');
    final filter = find.descendant(
      of: find.byKey(const ValueKey('genui-table-filter-table')),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(filter);
    await tester.enterText(filter, 'Plan 12');
    await settle();
    expect(rowNames(), ['Plan 12']);
    done('S4');

    await mount('S5');
    await tap(find.text('Review invoice'));
    expect(key!.currentState!.requests, 0);
    expect(
      tester.widget<TextField>(field('nameInput')).focusNode!.hasFocus,
      isTrue,
    );
    await type('nameInput', 'Ada');
    final modifier = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => LogicalKeyboardKey.metaLeft,
      _ => LogicalKeyboardKey.controlLeft,
    };
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(modifier);
    await settle();
    expect(
      tester.widget<TextField>(field('nameInput')).controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 3),
      reason:
          'The surrounding Markdown selection area must not steal Select All',
    );
    expect(field('detailInput'), findsNothing);
    await tap(find.text('Company invoice'));
    await type('detailInput', '');
    await tap(find.text('Review invoice'));
    expect(key!.currentState!.requests, 0);
    expect(
      tester.widget<TextField>(field('detailInput')).focusNode!.hasFocus,
      isTrue,
    );
    await tap(find.text('Company invoice'));
    expect(field('detailInput'), findsNothing);
    expect(surface().captureRead().inputs['detail'], '');
    await tap(find.text('Review invoice'));
    expect(key!.currentState!.requests, 1);
    await tap(find.text('Company invoice'));
    await type('detailInput', 'Kept draft');
    await tap(find.text('Company invoice'));
    expect(field('detailInput'), findsNothing);
    expect(surface().captureRead().inputs['detail'], 'Kept draft');
    done('S5');

    await mount('S6');
    await type('offsetInput', '2');
    final c6 = surface();
    expect(c6.nodes['result']!.properties['value'], 7);
    expect(
      c6.nodes['chart']!.properties['data'],
      c6.nodes['table']!.properties['data'],
    );
    await tap(find.text('Explain parameters'));
    expect(key!.currentState!.requests, 1);
    expect(session.sent, isEmpty);
    await collapse();
    expect(find.byType(GenUiContextChip), findsOneWidget);
    final frozen = tester
        .widget<GenUiContextChip>(find.byType(GenUiContextChip))
        .content;
    expect(jsonDecode('{${frozen.body.replaceAll('\n', ',')}}'), {
      'slope': 1,
      'offset': 2,
      'useOffset': true,
      'result': 7,
    });
    await tap(find.byKey(const ValueKey('genui-context-expand')));
    expect(find.text(frozen.exactText), findsOneWidget);
    await tap(find.byKey(const ValueKey('genui-context-expand')));
    expect(surface(), same(c6));
    expect(
      c6.setInputs({'offset': 8}, token: c6.token),
      UiMutationResult.accepted,
    );
    expect(c6.captureRead().inputs['offset'], 8);
    expect(c6.nodes['result']!.properties['value'], 13);
    await settle();
    expect(
      tester.widget<GenUiContextChip>(find.byType(GenUiContextChip)).content,
      frozen,
    );
    key!.currentState!.text.text = 'My editable question';
    await settle();
    await tap(find.byKey(const ValueKey('send')));
    await until(() => session.sent.length == 1);
    final sent = (await tester.runAsync(
      () => session.repository.getMessage(session.sent.single.id),
    ))!;
    expect(UiUserContextParts.read(sent.parts).context, frozen);
    expect(
      UiUserContextParts.read(sent.parts).bodyText,
      'My editable question',
    );
    expect(
      c6.setInputs({'offset': 9}, token: c6.token),
      UiMutationResult.accepted,
    );
    expect(c6.captureRead().inputs['offset'], 9);
    expect(c6.nodes['result']!.properties['value'], 14);
    final reread = (await tester.runAsync(
      () => session.repository.getMessage(sent.id),
    ))!;
    expect(UiUserContextParts.read(reread.parts).context, frozen);
    expect(UiWebController.createdNativeViews, nativeViews);
    completed.add('S6');
    return completed;
  } finally {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    semantics?.dispose();
    await tester.runAsync(session.close);
    await tester.runAsync(services.close);
    await tester.runAsync(() => directory.delete(recursive: true));
  }
}
