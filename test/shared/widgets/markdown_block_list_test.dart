import 'dart:ui' as ui;

import 'package:Kelivo/shared/widgets/export_capture_scope.dart';
import 'package:Kelivo/shared/widgets/incremental_markdown_document.dart';
import 'package:Kelivo/shared/widgets/markdown_block_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final nested in [false, true]) {
    testWidgets(
      'collapse paints every visible block in the current frame (nested: $nested)',
      (tester) async {
        final capture = GlobalKey();
        final top = ValueNotifier(1000.0);
        final scroll = ScrollController();
        addTearDown(top.dispose);
        addTearDown(scroll.dispose);
        final painted = <int>[];
        final blocks = IncrementalMarkdownDocument().update(
          List.generate(80, (i) => 'block $i').join('\n\n'),
        );
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: top,
              builder: (_, value, _) => AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: const Cubic(0.2, 0.8, 0.2, 1),
                alignment: Alignment.topLeft,
                child: SizedBox(height: value),
              ),
            ),
            RepaintBoundary(
              child: MarkdownBlockList(
                blocks: blocks,
                signature: 0,
                itemBuilder: (_, i) => _PaintProbe(
                  index: i,
                  painted: painted,
                  child: SizedBox(
                    key: ValueKey('animated-$i'),
                    width: 200,
                    height: 40,
                    child: const ColoredBox(color: Color(0xff0000ff)),
                  ),
                ),
              ),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 200,
                  height: 600,
                  child: RepaintBoundary(
                    key: capture,
                    child: ColoredBox(
                      color: const Color(0xffffffff),
                      child: SingleChildScrollView(
                        controller: scroll,
                        child: nested
                            ? MarkdownBlockList(
                                blocks: const [
                                  IncrementalMarkdownBlock(
                                    start: 0,
                                    text: '',
                                    stable: true,
                                  ),
                                ],
                                signature: 0,
                                // The outer observer's size and position stay
                                // fixed while cached descendants move inside.
                                itemBuilder: (_, _) => SizedBox(
                                  height: 6000,
                                  child: RepaintBoundary(child: content),
                                ),
                              )
                            : content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(painted, isEmpty);
        top.value = 0;
        await tester.pump();
        for (var frame = 0; frame < 21; frame++) {
          painted.clear();
          await tester.pump(const Duration(milliseconds: 16));
          expect(scroll.offset, 0);
          final visible = <Rect>[];
          for (var i = 0; i < blocks.length; i++) {
            final rect = tester.getRect(find.byKey(ValueKey('animated-$i')));
            if (rect.top < 598 && rect.bottom > 2) visible.add(rect);
          }
          // Capture the layer that was actually displayed, without settling
          // or pumping an extra frame to honour a late cache invalidation.
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = (boundary.debugLayer! as OffsetLayer).toImageSync(
            Offset.zero & boundary.size,
          );
          try {
            final bytes = await tester.runAsync(
              () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
            );
            for (final rect in visible) {
              final y =
                  ((rect.top.clamp(2, 598) + rect.bottom.clamp(2, 598)) / 2)
                      .floor();
              final offset = (y * image.width + 10) * 4;
              expect(
                bytes!.buffer.asUint8List(offset, 4),
                [0, 0, 255, 255],
                reason: 'Frame $frame must paint visible block $rect',
              );
            }
          } finally {
            image.dispose();
          }
          expect(painted, isNot(contains(79)));
        }
        painted.clear();
        for (var i = 0; i < 3; i++) {
          tester.binding.scheduleFrame();
          await tester.pump();
        }
        expect(painted, isEmpty);
        expect(tester.binding.hasScheduledFrame, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final scenario in [
    (name: 'ancestor collapse', resize: false, nested: false, top: 80.0),
    (name: 'viewport growth', resize: true, nested: false, top: 0.0),
    (name: 'nested repaint boundary', resize: false, nested: true, top: 80.0),
    (
      name: 'offscreen ancestor collapse',
      resize: false,
      nested: false,
      top: 600.0,
    ),
  ]) {
    testWidgets('cached Markdown refreshes after ${scenario.name}', (
      tester,
    ) async {
      final top = ValueNotifier(scenario.top);
      final height = ValueNotifier(scenario.resize ? 80.0 : 120.0);
      final scroll = ScrollController();
      final semantics = tester.ensureSemantics();
      try {
        addTearDown(top.dispose);
        addTearDown(height.dispose);
        addTearDown(scroll.dispose);
        final capture = GlobalKey();
        final painted = <int>[];
        final blocks = IncrementalMarkdownDocument().update(
          List.generate(20, (i) => 'block $i').join('\n\n'),
        );
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: top,
              builder: (_, value, _) => SizedBox(height: value),
            ),
            RepaintBoundary(
              child: MarkdownBlockList(
                blocks: blocks,
                signature: 0,
                itemBuilder: (_, i) => _PaintProbe(
                  index: i,
                  painted: painted,
                  child: SizedBox(
                    key: ValueKey('block-$i'),
                    width: 200,
                    height: 40,
                    child: Semantics(
                      container: true,
                      label: 'block $i',
                      child: const ColoredBox(color: Color(0xff0000ff)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: ValueListenableBuilder<double>(
                  valueListenable: height,
                  builder: (_, value, child) =>
                      SizedBox(width: 200, height: value, child: child),
                  child: RepaintBoundary(
                    key: capture,
                    child: ColoredBox(
                      color: const Color(0xffffffff),
                      child: SingleChildScrollView(
                        controller: scroll,
                        child: scenario.nested
                            ? MarkdownBlockList(
                                blocks: const [
                                  IncrementalMarkdownBlock(
                                    start: 0,
                                    text: '',
                                    stable: true,
                                  ),
                                ],
                                signature: 0,
                                itemBuilder: (_, _) => content,
                              )
                            : content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final target = scenario.resize ? 5 : 2;
        expect(painted, isNot(contains(target)));
        painted.clear();
        if (scenario.resize) {
          height.value = 240;
        } else {
          top.value = 0;
        }
        await tester.pump();
        expect(scroll.offset, 0);
        expect(
          tester.getTopLeft(find.byKey(ValueKey('block-$target'))).dy,
          target * 40,
        );
        expect(
          await _pixel(tester, capture, 10, scenario.resize ? 220 : 100),
          0xff0000ff,
          reason: 'Newly visible content is painted in the current frame',
        );
        expect(painted, contains(target));
        expect(painted, isNot(contains(19)));
        expect(
          tester.semantics.simulatedAccessibilityTraversal().map(
            (node) => node.getSemanticsData().label,
          ),
          contains('block $target'),
        );
        painted.clear();
        for (var i = 0; i < 3; i++) {
          tester.binding.scheduleFrame();
          await tester.pump();
        }
        expect(
          painted,
          isEmpty,
          reason: 'Unchanged geometry keeps the paint cache',
        );
        expect(tester.binding.hasScheduledFrame, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        tester.binding.scheduleFrame();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.binding.hasScheduledFrame, isFalse);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('viewport observers share and release their rendering pipeline', (
    tester,
  ) async {
    final capture = GlobalKey();
    final document = IncrementalMarkdownDocument().update('one\n\ntwo');
    Widget build(int count) => MaterialApp(
      home: RepaintBoundary(
        key: capture,
        child: SingleChildScrollView(
          // Also exercise registration from a build during layout.
          child: LayoutBuilder(
            builder: (_, _) => Column(
              children: [
                for (var i = 0; i < count; i++)
                  MarkdownBlockList(
                    key: ValueKey(i),
                    blocks: document,
                    signature: 0,
                    itemBuilder: (_, index) => Text(document[index].text),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(build(0));
    final owner = capture.currentContext!.findRenderObject()!.owner!;
    Set<PipelineOwner> children() {
      final result = <PipelineOwner>{};
      owner.visitChildren(result.add);
      return result;
    }

    final original = children();
    for (var i = 0; i < 2; i++) {
      await tester.pumpWidget(build(3));
      expect(children().difference(original), hasLength(1));
      expect(find.text('one'), findsNWidgets(3));
      await tester.pumpWidget(build(1));
      expect(children().difference(original), hasLength(1));
      await tester.pumpWidget(build(0));
      expect(children(), original);
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    expect(children(), original);
  });

  testWidgets('nested viewports refresh their own cached Markdown paint', (
    tester,
  ) async {
    final scroll = ScrollController();
    final painted = <int>[];
    final blocks = IncrementalMarkdownDocument().update(
      List.generate(128, (i) => 'block $i').join('\n\n'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarkdownBlockList(
              blocks: const [
                IncrementalMarkdownBlock(start: 0, text: '', stable: true),
              ],
              signature: 0,
              itemBuilder: (_, _) => SizedBox(
                height: 120,
                child: SingleChildScrollView(
                  controller: scroll,
                  child: RepaintBoundary(
                    child: MarkdownBlockList(
                      blocks: blocks,
                      signature: 0,
                      itemBuilder: (_, i) => _PaintProbe(
                        index: i,
                        painted: painted,
                        child: SizedBox(height: 24, child: Text('block $i')),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(painted, contains(0));
    expect(painted, isNot(contains(127)));
    painted.clear();
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    expect(painted, contains(127));
    expect(painted, isNot(contains(0)));
    await tester.pumpWidget(const SizedBox.shrink());
    scroll.dispose();
  });

  testWidgets('appends rebuild the tail and scrolls paint only nearby blocks', (
    tester,
  ) async {
    final document = IncrementalMarkdownDocument();
    var source = List.generate(2048, (i) => 'block $i').join('\n\n');
    final blocks = ValueNotifier(document.update(source));
    final exporting = ValueNotifier(false);
    final scroll = ScrollController();
    final built = <int>[];
    final painted = <int>[];
    final semantics = tester.ensureSemantics();
    Iterable<String> labels() => tester.semantics
        .simulatedAccessibilityTraversal()
        .map((node) => node.getSemanticsData().label);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 120,
            child: SingleChildScrollView(
              controller: scroll,
              child: RepaintBoundary(
                child: ValueListenableBuilder<bool>(
                  valueListenable: exporting,
                  builder: (_, export, _) => ExportCaptureScope(
                    enabled: export,
                    child:
                        ValueListenableBuilder<List<IncrementalMarkdownBlock>>(
                          valueListenable: blocks,
                          builder: (_, value, _) => MarkdownBlockList(
                            blocks: value,
                            signature: 0,
                            itemBuilder: (_, i) {
                              built.add(i);
                              return _PaintProbe(
                                index: i,
                                painted: painted,
                                child: SizedBox(
                                  height: 24,
                                  child: Semantics(
                                    container: true,
                                    child: Text(value[i].text),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(built.length, 2048);
    expect(painted.length, lessThan(32));
    expect(labels(), contains('block 0'));
    expect(labels(), isNot(contains('block 2047')));

    built.clear();
    painted.clear();
    source += ' grows';
    blocks.value = document.update(source);
    await tester.pump();
    expect(built, [2047]);
    expect(painted, isNot(contains(2047)));

    painted.clear();
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    expect(painted, contains(2047));
    expect(painted.length, lessThan(32));
    expect(labels(), contains('block 2047 grows'));
    expect(labels(), isNot(contains('block 0')));

    painted.clear();
    scroll.jumpTo(0);
    await tester.pump();
    expect(painted, contains(0));
    expect(labels(), contains('block 0'));

    painted.clear();
    exporting.value = true;
    await tester.pump();
    expect(
      painted.toSet().length,
      2048,
      reason: 'Exports include offscreen content',
    );
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    blocks.dispose();
    exporting.dispose();
    scroll.dispose();
  });

  testWidgets('branch growth and tail replacement retain earlier state', (
    tester,
  ) async {
    final document = IncrementalMarkdownDocument();
    var source = List.generate(15, (i) => 'block $i').join('\n\n');
    final blocks = ValueNotifier(document.update(source));
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: ValueListenableBuilder<List<IncrementalMarkdownBlock>>(
            valueListenable: blocks,
            builder: (_, value, _) => MarkdownBlockList(
              blocks: value,
              signature: 0,
              itemBuilder: (_, i) => _StateProbe(
                key: ValueKey(value[i].start),
                text: value[i].text,
              ),
            ),
          ),
        ),
      ),
    );
    final first = tester.state<_StateProbeState>(
      find.byType(_StateProbe).first,
    );
    for (final count in [17, 273, 4369]) {
      source = List.generate(count, (i) => 'block $i').join('\n\n');
      blocks.value = document.update(source);
      await tester.pump();
      expect(tester.state(find.byType(_StateProbe).first), same(first));
      expect(find.text('block ${count - 1}'), findsOneWidget);
    }
    expect(
      first.activations,
      0,
      reason: 'Capacity growth must not reactivate historical content',
    );
    source += '\n\n  continued';
    blocks.value = document.update(source);
    await tester.pump();
    expect(tester.state(find.byType(_StateProbe).first), same(first));
    expect(find.text('block 4368\n\n  continued'), findsOneWidget);
    blocks.value = document.update('replacement');
    await tester.pump();
    expect(find.text('replacement'), findsOneWidget);
    expect(find.byType(_StateProbe), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    blocks.dispose();
  });
}

Future<int> _pixel(WidgetTester tester, GlobalKey key, int x, int y) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = boundary.toImageSync();
  try {
    final bytes = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final offset = (y * image.width + x) * 4;
    return (bytes!.getUint8(offset + 3) << 24) |
        (bytes.getUint8(offset) << 16) |
        (bytes.getUint8(offset + 1) << 8) |
        bytes.getUint8(offset + 2);
  } finally {
    image.dispose();
  }
}

class _StateProbe extends StatefulWidget {
  const _StateProbe({super.key, required this.text});
  final String text;
  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  int activations = 0;
  @override
  void activate() {
    super.activate();
    activations++;
  }

  @override
  Widget build(BuildContext context) => Text(widget.text);
}

class _PaintProbe extends SingleChildRenderObjectWidget {
  const _PaintProbe({
    required this.index,
    required this.painted,
    required super.child,
  });
  final int index;
  final List<int> painted;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaintProbe(index, painted);
}

class _RenderPaintProbe extends RenderProxyBox {
  _RenderPaintProbe(this.index, this.painted);
  final int index;
  final List<int> painted;
  @override
  void paint(PaintingContext context, Offset offset) {
    painted.add(index);
    super.paint(context, offset);
  }
}
