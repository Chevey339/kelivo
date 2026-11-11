import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/gallery/review_gallery.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_node.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_text_input.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_slider.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_boolean_input.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_choice_input.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_button.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_context_chip.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_draft_dialog.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';

/// Shared acceptance flow runs against real native widgets in an isolated app.
/// Native captures are artifacts for visual inspection, never automatic approval.
Future<List<String>> exerciseGenUiReview(
  WidgetTester tester, {
  Future<void> Function(String)? capture,
  bool openWeb = false,
  String? fontFamily,
}) async {
  final visited = <String>[];
  await tester.pumpWidget(GenUiReviewGalleryApp(fontFamily: fontFamily));
  await tester.pumpAndSettle();
  Future<void> shot(String name) async {
    await tester.pump(const Duration(milliseconds: 250));
    await capture?.call(name);
    expect(tester.takeException(), isNull, reason: name);
  }

  final scroll = find.byKey(const ValueKey('review-scroll'));
  ScrollPosition position() => tester
      .state<ScrollableState>(
        find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
      )
      .position;
  Future<void> top() async {
    position().jumpTo(0);
    await tester.pump(const Duration(milliseconds: 220));
  }

  Future<void> tap(Finder target, {bool disabled = false}) async {
    await tester.ensureVisible(target);
    await tester.pump(const Duration(milliseconds: 220));
    await tester.tap(target, warnIfMissed: !disabled);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> bottom() async {
    for (var j = 0; j < 12 && position().extentAfter > 1; j++) {
      final rect = tester.getRect(scroll);
      await tester.dragFrom(
        Offset(rect.center.dx, rect.bottom - 35),
        Offset(0, -rect.height * .7),
      );
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(position().extentAfter, lessThan(2));
  }

  for (var i = 0; i < genUiReviewCases.length; i++) {
    final name = genUiReviewCases[i];
    if (i > 0) {
      await tester.tap(find.byKey(const ValueKey('review-next')));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text(name).first, findsOneWidget);
    await shot('${i.toString().padLeft(2, '0')}-top');
    if (name == '表单') {
      final surface = tester
          .widget<GenUiSurface>(find.byType(GenUiSurface))
          .controller;
      for (final type in [
        GenUiTextInput,
        GenUiSlider,
        GenUiBooleanInput,
        GenUiChoiceInput,
        GenUiButton,
      ]) {
        expect(find.byType(type), findsWidgets);
      }
      final nameField = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is GenUiTextInput && w.id == 'nameField',
        ),
        matching: find.byType(EditableText),
      );
      await tap(nameField);
      await tester.enterText(nameField, 'Ada');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 300));
      await tap(
        find.byWidgetPredicate(
          (w) => w is IosIconButton && w.icon == LucideIcons.plus,
        ),
      );
      expect(surface.captureRead().inputs['amount'], 4);
      await tap(find.text('Choose a plan'));
      await shot('form-select-sheet');
      await tap(find.text('Plus'));
      expect(surface.captureRead().inputs['plan'], 'plus');
      await tap(find.text('30 years'));
      expect(surface.captureRead().inputs['period'], 30);
      await tap(find.text('I confirm these parameters *'));
      expect(surface.captureRead().inputs['agree'], true);
      await tap(find.text('Explain parameters'));
      await shot('form-valid');
      await tap(find.text('Reset'));
      expect(surface.captureRead().inputs['name'], '');
      await tap(find.text('Explain parameters'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.widget<EditableText>(nameField).focusNode.hasFocus, true);
      await shot('form-first-error-focused');
      FocusManager.instance.primaryFocus?.unfocus();
    } else if (name == '禁用输入') {
      final surface = tester
          .widget<GenUiSurface>(find.byType(GenUiSurface))
          .controller;
      await tap(
        find.byWidgetPredicate(
          (w) => w is IosIconButton && w.icon == LucideIcons.plus,
        ),
        disabled: true,
      );
      expect(surface.captureRead().inputs['amount'], 3);
    } else if (name == '预算与饼图') {
      expect(find.byType(PieChart), findsOneWidget);
      expect(find.text('5500'), findsWidgets);
      await tester.ensureVisible(find.byType(PieChart));
      await tester.pump(const Duration(milliseconds: 250));
      final rect = tester.getRect(find.byType(PieChart));
      await tester.tapAt(rect.center + const Offset(50, -35));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('房租'), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('genui-chart-canvas-chart')),
          matching: find.text('1925'),
        ),
        findsOneWidget,
      );
      await shot('pie-selected-center');
      await tap(find.text('数据'));
      await shot('pie-data-short-table');
      expect(
        find.byKey(const ValueKey('genui-table-page-size-chart')),
        findsNothing,
      );
      await top();
      await tap(find.byKey(const ValueKey('review-header')));
      expect(find.byKey(const ValueKey('genui-surface-header')), findsNothing);
      await bottom();
      await tap(find.byKey(const ValueKey('genui-immersive-more')));
      await shot('immersive-actions');
      await tap(find.text('展开'));
      await tester.pump(const Duration(milliseconds: 300));
      await shot('expanded-surface');
      await tester.tap(find.byTooltip('返回').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tap(find.byKey(const ValueKey('review-header')));
    } else if (['折线图', '面积图', '柱状图', '散点图'].contains(name)) {
      final chart = find.byKey(const ValueKey('genui-chart-canvas-root'));
      await tester.ensureVisible(chart);
      await tester.pump(const Duration(milliseconds: 250));
      final focus = find.byWidgetPredicate(
        (w) => w is Focus && w.focusNode?.debugLabel == 'GenUI chart',
      );
      tester.widget<Focus>(focus).focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.byKey(const ValueKey('genui-chart-tooltip-root')),
        findsOneWidget,
      );
      await shot('chart-$i-selected');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tap(find.byKey(const ValueKey('genui-chart-legend-root-0')));
      await shot('chart-$i-hidden-series');
      await tap(find.text('数据'));
      await shot('chart-$i-data');
      await tap(find.text('图表'));
    } else if (name == '长表格') {
      await bottom();
      await tap(find.byKey(const ValueKey('genui-table-next-table')));
      await shot('table-page-two');
      await tap(find.byKey(const ValueKey('genui-table-page-size-table')));
      await shot('table-page-size-dialog');
      await tap(find.text('20 行/页'));
      await top();
      final filter = find.byKey(const ValueKey('genui-table-filter-table'));
      await tap(filter);
      await tester.enterText(
        find.descendant(of: filter, matching: find.byType(EditableText)),
        'Pro',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await shot('table-filter');
      await tap(find.byTooltip('清除筛选'));
      await shot('table-filter-cleared');
    } else if (name == '附带状态与弹窗') {
      final chip = find.byType(GenUiContextChip).first;
      await tap(
        find.descendant(
          of: chip,
          matching: find.byKey(const ValueKey('genui-context-expand')),
        ),
      );
      await shot('chip-expanded');
      await tap(find.text('Preview replacement'));
      expect(find.byType(GenUiDraftDialog), findsOneWidget);
      await shot('replace-dialog');
      await tap(find.text('取消'));
      await tap(find.text('Preview merge'));
      await shot('merge-dialog');
      await tap(find.text('合并'));
      expect(find.byType(GenUiDraftDialog), findsNothing);
    } else if (name == '流式骨架') {
      for (var step = 0; step < 9; step++) {
        await tap(find.byKey(const ValueKey('review-stream-step')));
        if (step == 2) {
          expect(find.byType(GenUiPendingNode), findsWidgets);
          await shot('stream-forward-references');
        }
      }
      expect(find.byType(GenUiPendingNode), findsNothing);
      expect(find.text('生成中'), findsNothing);
      await shot('stream-complete');
      await tap(find.byKey(const ValueKey('review-stream-step')));
      await tap(find.byKey(const ValueKey('review-stream-step')));
      await tap(find.byKey(const ValueKey('review-stream-interrupt')));
      expect(find.text('已中断'), findsWidgets);
      await shot('stream-interrupted');
    } else if (name == '尚未保存') {
      await tap(find.byTooltip('点击重试保存'));
      expect(find.text('尚未保存'), findsOneWidget); // gallery heading only
    } else if (name == '网页预览' && openWeb) {
      await tap(find.text('打开').first);
      await tester.pump(const Duration(seconds: 2));
      await shot('web-sandbox-preview');
      await tap(find.byTooltip('预览说明'));
      await shot('web-preview-information');
      await tester.tap(find.byTooltip('关闭').last);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byTooltip('关闭').first);
      await tester.pump(const Duration(milliseconds: 350));
      await tap(find.text('打开').at(1));
      await tester.pump(const Duration(seconds: 2));
      await shot('web-dark-canvas-preview');
      await tester.tap(find.byTooltip('关闭').first);
      await tester.pump(const Duration(milliseconds: 350));
    }
    await bottom();
    await shot('${i.toString().padLeft(2, '0')}-bottom');
    if (name == '长消息') {
      expect(find.text('后续消息：已经滚动到两个完整交互界面之后。').hitTestable(), findsOneWidget);
      for (var repeat = 0; repeat < 3; repeat++) {
        await top();
        await bottom();
      }
    }
    await top();
    for (final key in ['review-theme', 'review-scale', 'review-direction']) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump(const Duration(milliseconds: 220));
    }
    await shot('${i.toString().padLeft(2, '0')}-dark-large-rtl');
    await bottom();
    await shot('${i.toString().padLeft(2, '0')}-dark-large-rtl-bottom');
    for (final key in ['review-theme', 'review-scale', 'review-direction']) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump(const Duration(milliseconds: 220));
    }
    await top();
    visited.add(name);
  }
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 300));
  return visited;
}
