import 'dart:ui' show ClipOp, SemanticsAction, SemanticsActionEvent;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/shared/widgets/effort_slider.dart';

Future<void> _pumpSlider(
  WidgetTester tester, {
  required ValueChanged<int> onCommit,
  int selectedIndex = 0,
  bool customSelected = false,
  bool compact = false,
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
              compact: compact,
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

class _TrackCanvas extends Fake implements Canvas {
  final circles = <({Offset center, double radius})>[];
  final _clips = <Rect>[];
  Rect _clip = Rect.largest;

  @override
  void save() => _clips.add(_clip);

  @override
  void restore() => _clip = _clips.removeLast();

  @override
  void clipRect(
    Rect rect, {
    ClipOp clipOp = ClipOp.intersect,
    bool doAntiAlias = true,
  }) => _clip = _clip.intersect(rect);

  @override
  void clipRRect(RRect rrect, {bool doAntiAlias = true}) =>
      _clip = _clip.intersect(rrect.outerRect);

  @override
  void drawCircle(Offset center, double radius, Paint paint) {
    if (paint.color.a > 0 && _clip.contains(center)) {
      circles.add((center: center, radius: radius));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUp(() {
    final hapticsEnabled = Haptics.enabled;
    Haptics.setEnabled(false);
    addTearDown(() => Haptics.setEnabled(hapticsEnabled));
  });

  for (final compact in [false, true]) {
    testWidgets('semantics adjusts one stop at a time, compact=$compact', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        final commits = <int>[];
        await _pumpSlider(tester, onCommit: commits.add, compact: compact);
        final slider = find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.slider == true,
        );
        void adjust(SemanticsAction action) {
          final node = tester.getSemantics(slider);
          tester.binding.performSemanticsAction(
            SemanticsActionEvent(
              type: action,
              nodeId: node.id,
              viewId: tester.view.viewId,
            ),
          );
        }

        final initial = tester.getSemantics(slider).getSemanticsData();
        expect(initial.value, 'Level 0');
        expect(initial.increasedValue, 'Level 1');
        expect(initial.hasAction(SemanticsAction.increase), isTrue);
        expect(initial.hasAction(SemanticsAction.decrease), isFalse);
        expect(initial.hasAction(SemanticsAction.tap), isFalse);
        expect(initial.hasAction(SemanticsAction.scrollLeft), isFalse);
        expect(initial.hasAction(SemanticsAction.scrollRight), isFalse);

        for (var index = 1; index <= 4; index++) {
          adjust(SemanticsAction.increase);
          // Repeated actions use committed values even before the snap settles.
          await tester.pump();
          expect(tester.getSemantics(slider).value, 'Level $index');
        }
        final last = tester.getSemantics(slider).getSemanticsData();
        expect(last.hasAction(SemanticsAction.increase), isFalse);
        expect(last.decreasedValue, 'Level 3');
        for (var index = 3; index >= 0; index--) {
          adjust(SemanticsAction.decrease);
          await tester.pump();
          expect(tester.getSemantics(slider).value, 'Level $index');
        }
        expect(commits, [1, 2, 3, 4, 3, 2, 1, 0]);
        expect(
          tester
              .getSemantics(slider)
              .getSemanticsData()
              .hasAction(SemanticsAction.decrease),
          isFalse,
        );
        await tester.pumpAndSettle();
      } finally {
        handle.dispose();
      }
    });
  }

  testWidgets('semantics can select the first preset from a custom budget', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      final commits = <int>[];
      await _pumpSlider(
        tester,
        onCommit: commits.add,
        customSelected: true,
        compact: true,
      );
      final slider = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.slider == true,
      );
      final node = tester.getSemantics(slider);
      expect(node.value, 'Custom');
      expect(node.getSemanticsData().decreasedValue, 'Level 0');
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.decrease,
          nodeId: node.id,
          viewId: tester.view.viewId,
        ),
      );
      await tester.pumpAndSettle();
      expect(commits, [0]);
      expect(tester.getSemantics(slider).value, 'Level 0');
    } finally {
      handle.dispose();
    }
  });

  testWidgets('opening in Fast skips entry, toggling Fast still animates', (
    tester,
  ) async {
    final position = ValueNotifier<double>(3);
    addTearDown(position.dispose);
    Widget slider(bool accelerated, {bool reducedMotion = false}) =>
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: Center(
              child: SizedBox(
                width: 360,
                child: EffortSlider(
                  position: position,
                  stopCount: 5,
                  stopKeys: const [],
                  dragging: false,
                  onDragStart: () {},
                  onDragCancel: () {},
                  onPositionChanged: (_) {},
                  onSnap: (_) {},
                  animatedTrack: accelerated,
                ),
              ),
            ),
          ),
        );
    _TrackCanvas paintedTrack() {
      final track = find.descendant(
        of: find.byType(EffortSlider),
        matching: find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter != null,
        ),
      );
      final canvas = _TrackCanvas();
      tester
          .widget<CustomPaint>(track)
          .painter!
          .paint(canvas, tester.getSize(track));
      return canvas;
    }

    void expectSettledFast() {
      final circles = paintedTrack().circles;
      // Only the unfilled stop remains; the filled segment already has small
      // particles, even before the first animation tick.
      expect(circles.where((circle) => circle.radius > 2), hasLength(1));
      expect(circles.where((circle) => circle.radius < 2), isNotEmpty);
    }

    await tester.pumpWidget(slider(true));
    expectSettledFast();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(slider(true));
    expectSettledFast();

    await tester.pumpWidget(slider(false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(slider(true));
    expect(
      paintedTrack().circles.where((circle) => circle.radius > 2),
      hasLength(5),
    );
    for (var frame = 0; frame < 80; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expectSettledFast();

    await tester.pumpWidget(slider(true, reducedMotion: true));
    await tester.pumpAndSettle();
    expect(
      paintedTrack().circles.where((circle) => circle.radius > 2),
      hasLength(5),
    );
    await tester.pumpWidget(slider(true));
    expectSettledFast();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('accelerated track schedules motion only while enabled', (
    tester,
  ) async {
    final position = ValueNotifier<double>(3);
    addTearDown(position.dispose);
    Widget slider(bool accelerated, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Center(
          child: SizedBox(
            width: 360,
            child: EffortSlider(
              position: position,
              stopCount: 5,
              stopKeys: const [],
              dragging: false,
              onDragStart: () {},
              onDragCancel: () {},
              onPositionChanged: (_) {},
              onSnap: (_) {},
              animatedTrack: accelerated,
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(slider(true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    final rebuilds = <Type, int>{};
    final previousCallback = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      rebuilds.update(
        element.widget.runtimeType,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previousCallback);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(rebuilds[CustomPaint] ?? 0, 0);
    expect(rebuilds[EffortSlider] ?? 0, 0);
    debugOnRebuildDirtyWidget = previousCallback;
    await tester.pumpWidget(slider(false));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(slider(true, reduceMotion: true));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
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

  testWidgets(
    'crossing stops rebuilds labels without rebuilding the slider group',
    (tester) async {
      final commits = <int>[];
      await _pumpSlider(tester, onCommit: commits.add);
      final gesture = await tester.startGesture(_position(tester, 0));
      await gesture.moveTo(_position(tester, 1));
      await tester.pumpAndSettle();
      var groupBuilds = 0;
      final previousCallback = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        if (element.widget is EffortSliderGroup) groupBuilds++;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previousCallback);
      for (final index in [2, 3, 4, 3, 2, 1, 0, 4]) {
        await gesture.moveTo(_position(tester, index.toDouble()));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(groupBuilds, 0);
      expect(_title(tester), 'Level 4');
      expect(commits, isEmpty);
      debugOnRebuildDirtyWidget = previousCallback;
      await gesture.up();
      await tester.pumpAndSettle();
      expect(commits, [4]);
    },
  );

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
    expect(rebuilds[Transform] ?? 0, 0);
    expect(rebuilds[CustomPaint] ?? 0, 0);
    expect(tester.getCenter(thumb).dx, closeTo(initialCenter.dx + 10, 0.01));
    debugOnRebuildDirtyWidget = previousCallback;
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
