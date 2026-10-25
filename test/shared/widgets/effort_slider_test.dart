import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/shared/widgets/effort_slider.dart';

Future<void> _pumpSlider(
  WidgetTester tester, {
  required ValueChanged<int> onCommit,
  int selectedIndex = 0,
  bool customSelected = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            child: EffortSliderGroup(
              selectedIndex: selectedIndex,
              onCommit: onCommit,
              customSelected: customSelected,
              customIcon: const SizedBox(width: 18, height: 18),
              customTitle: 'Custom',
              customSubtitle: '2048 tokens',
              stops: [
                for (var i = 0; i < 5; i++)
                  EffortSliderStop(
                    stopKey: 'stop-$i',
                    icon: const SizedBox(width: 18, height: 18),
                    iconKey: i,
                    title: 'Level $i',
                    subtitle: 'Description $i',
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Offset _position(WidgetTester tester, double index) {
  final rect = tester.getRect(find.byType(EffortSlider));
  return Offset(rect.left + 19 + (rect.width - 38) * index / 4, rect.center.dy);
}

String _title(WidgetTester tester) => tester
    .widget<EffortSliderLabelPill>(find.byType(EffortSliderLabelPill))
    .title;

void main() {
  setUp(() {
    final hapticsEnabled = Haptics.enabled;
    Haptics.setEnabled(false);
    addTearDown(() => Haptics.setEnabled(hapticsEnabled));
  });

  testWidgets('drag previews levels and commits only the final stop', (
    tester,
  ) async {
    final commits = <int>[];
    await _pumpSlider(tester, onCommit: commits.add);
    final gesture = await tester.startGesture(_position(tester, 0));
    await gesture.moveTo(_position(tester, 1));
    await tester.pump();
    for (var index = 2; index <= 4; index++) {
      await gesture.moveTo(_position(tester, index.toDouble()));
      await tester.pump();
    }

    expect(_title(tester), 'Level 4');
    expect(commits, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(commits, [4]);
  });

  testWidgets('holding the track does not commit before the tap completes', (
    tester,
  ) async {
    final commits = <int>[];
    await _pumpSlider(tester, onCommit: commits.add);
    final gesture = await tester.startGesture(_position(tester, 3));
    await tester.pump(const Duration(milliseconds: 150));
    expect(commits, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(commits, [3]);
    expect(_title(tester), 'Level 3');
  });

  testWidgets('returning to the selected stop does not commit', (tester) async {
    final commits = <int>[];
    await _pumpSlider(tester, selectedIndex: 2, onCommit: commits.add);
    final gesture = await tester.startGesture(_position(tester, 2));
    await gesture.moveTo(_position(tester, 3));
    await tester.pump();
    await gesture.moveTo(_position(tester, 4));
    await tester.pump();
    await gesture.moveTo(_position(tester, 2));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(commits, isEmpty);
    expect(_title(tester), 'Level 2');
  });

  testWidgets('release uses the latest pointer position before another frame', (
    tester,
  ) async {
    final commits = <int>[];
    await _pumpSlider(tester, onCommit: commits.add);
    final gesture = await tester.startGesture(_position(tester, 0));
    await gesture.moveTo(_position(tester, 1));
    await tester.pump();
    await gesture.moveTo(_position(tester, 2));
    await gesture.moveTo(_position(tester, 4));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(commits, [4]);
    expect(_title(tester), 'Level 4');
  });

  testWidgets('dragging from a custom budget previews and commits a preset', (
    tester,
  ) async {
    final commits = <int>[];
    await _pumpSlider(tester, customSelected: true, onCommit: commits.add);
    expect(_title(tester), 'Custom');
    final gesture = await tester.startGesture(_position(tester, 0));
    await gesture.moveTo(_position(tester, 1));
    await tester.pump();
    await gesture.moveTo(_position(tester, 0));
    await tester.pump();
    expect(_title(tester), 'Level 0');
    expect(commits, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(commits, [0]);
    expect(_title(tester), 'Level 0');
  });

  testWidgets('tapping from a custom budget commits only the tapped preset', (
    tester,
  ) async {
    final commits = <int>[];
    await _pumpSlider(tester, customSelected: true, onCommit: commits.add);
    await tester.tapAt(_position(tester, 4));
    await tester.pumpAndSettle();
    expect(commits, [4]);
    expect(_title(tester), 'Level 4');
  });

  testWidgets('cancelling an unstarted drag preserves a custom budget', (
    tester,
  ) async {
    final commits = <int>[];
    await _pumpSlider(tester, customSelected: true, onCommit: commits.add);
    final gesture = await tester.startGesture(_position(tester, 3));
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(commits, isEmpty);
    expect(_title(tester), 'Custom');
  });

  testWidgets('cancelling an active drag commits the latest preview once', (
    tester,
  ) async {
    final commits = <int>[];
    await _pumpSlider(tester, onCommit: commits.add);
    final gesture = await tester.startGesture(_position(tester, 0));
    await gesture.moveTo(_position(tester, 1));
    await gesture.moveTo(_position(tester, 4));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(commits, [4]);
    expect(_title(tester), 'Level 4');
    expect(
      tester.widget<EffortSlider>(find.byType(EffortSlider)).dragging,
      isFalse,
    );
  });

  testWidgets('moving within a stop does not rebuild the label or group', (
    tester,
  ) async {
    await _pumpSlider(tester, selectedIndex: 2, onCommit: (_) {});
    final gesture = await tester.startGesture(_position(tester, 2));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pumpAndSettle();
    final thumb = find.descendant(
      of: find.byType(EffortSlider),
      matching: find.byType(AnimatedScale),
    );
    final initialCenter = tester.getCenter(thumb);
    final rebuilds = <Type, int>{};
    final previousCallback = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      final type = element.widget.runtimeType;
      rebuilds.update(type, (count) => count + 1, ifAbsent: () => 1);
      previousCallback?.call(element, builtOnce);
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previousCallback);

    for (var frame = 0; frame < 20; frame++) {
      await gesture.moveBy(const Offset(0.5, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(rebuilds[EffortSliderGroup] ?? 0, 0);
    expect(rebuilds[EffortSliderLabelPill] ?? 0, 0);
    expect(rebuilds[AnimatedWidthText] ?? 0, 0);
    expect(tester.getCenter(thumb).dx, closeTo(initialCenter.dx + 10, 0.01));
    debugOnRebuildDirtyWidget = previousCallback;
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
