import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/desktop/widgets/desktop_select_dropdown.dart';

void main() {
  testWidgets('mobile description menu aligns with its full width trigger', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    String? selection;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.fromLTRB(34, 100, 34, 0),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: DesktopSelectDropdown<String>(
                value: 'recent',
                options: const [
                  DesktopSelectOption(
                    value: 'recent',
                    label: '保留最近原文',
                    subtitle: '保留最近原文，压缩更早历史；此轮数也用于自动压缩。',
                  ),
                  DesktopSelectOption(
                    value: 'all',
                    label: '全部历史',
                    subtitle: '当前上下文的历史全部纳入摘要，不保留最近原文；原消息仍可查看。',
                  ),
                ],
                onSelected: (value) => selection = value,
              ),
            ),
          ),
        ),
      ),
    );
    final trigger = find.byType(DesktopSelectDropdown<String>);
    final triggerRect = tester.getRect(trigger);
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    final menuRect = tester.getRect(find.byType(SingleChildScrollView));
    expect(menuRect.left, closeTo(triggerRect.left, 1));
    expect(menuRect.right, closeTo(triggerRect.right, 1));
    expect(menuRect.center.dx, closeTo(triggerRect.center.dx, .1));
    await tester.tap(find.text('全部历史'));
    await tester.pumpAndSettle();
    expect(selection, 'all');
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'narrow language trigger shows complete options at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: SizedBox(
                    width: 110,
                    child: DesktopSelectDropdown<String>(
                      value: 'conversation',
                      options: const [
                        DesktopSelectOption(
                          value: 'conversation',
                          label: '跟随对话',
                        ),
                        DesktopSelectOption(value: 'en', label: 'English'),
                        DesktopSelectOption(value: 'zh-Hans', label: '简体中文'),
                        DesktopSelectOption(value: 'zh-Hant', label: '繁體中文'),
                        DesktopSelectOption(
                          value: 'custom',
                          label: 'Other language',
                        ),
                      ],
                      onSelected: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(DesktopSelectDropdown<String>));
        await tester.pumpAndSettle();
        for (final label in [
          '跟随对话',
          'English',
          '简体中文',
          '繁體中文',
          'Other language',
        ]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label).last,
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        }
        final menu = tester.getRect(find.byType(SingleChildScrollView));
        expect(menu.width, greaterThan(110));
        expect(menu.left, greaterThanOrEqualTo(8));
        expect(menu.right, lessThanOrEqualTo(385));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('dropdown options render optional subtitles', (tester) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DesktopSelectDropdown<String>(
              value: 'a',
              options: const [
                DesktopSelectOption(
                  value: 'a',
                  label: 'Always global',
                  subtitle: 'New memories are shared with every assistant',
                ),
                DesktopSelectOption(
                  value: 'b',
                  label: 'Always this assistant',
                  subtitle: 'New memories stay private to this assistant',
                ),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DesktopSelectDropdown<String>));
    await tester.pumpAndSettle();

    expect(
      find.text('New memories are shared with every assistant'),
      findsOneWidget,
    );
    expect(
      find.text('New memories stay private to this assistant'),
      findsOneWidget,
    );
  });
}
