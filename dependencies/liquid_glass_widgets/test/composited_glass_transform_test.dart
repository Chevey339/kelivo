import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/src/engine/internal/transform_aware_backdrop_filter_layer.dart';
import 'package:liquid_glass_widgets/src/engine/internal/transform_tracking_repaint_boundary_mixin.dart';

void main() {
  testWidgets('retained glass follows translation in the same scene', (
    tester,
  ) async {
    final movement = ValueNotifier<Offset>(Offset.zero);
    final fixture = _FixtureState();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned(
              left: 32,
              top: 44,
              child: ValueListenableBuilder<Offset>(
                valueListenable: movement,
                child: RepaintBoundary(
                  child: _FilterFixture(
                    state: fixture,
                    child: const SizedBox(width: 48, height: 48),
                  ),
                ),
                builder: (_, offset, child) =>
                    Transform.translate(offset: offset, child: child),
              ),
            ),
          ],
        ),
      ),
    );
    expect(fixture.sceneBounds, const Rect.fromLTWH(32, 44, 48, 48));
    final initialPaints = fixture.paints;
    for (final offset in [
      const Offset(9, 0),
      const Offset(80, 18),
      const Offset(-15, -20),
      Offset.zero,
    ]) {
      movement.value = offset;
      await tester.pump();
      expect(
        fixture.sceneBounds,
        Rect.fromLTWH(32 + offset.dx, 44 + offset.dy, 48, 48),
        reason: 'No corrective second frame may be required',
      );
      expect(fixture.paints, initialPaints);
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    movement.dispose();
  });

  testWidgets('retained glass refreshes scale without redrawing its child', (
    tester,
  ) async {
    final scale = ValueNotifier<double>(1);
    final fixture = _FixtureState();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ValueListenableBuilder<double>(
            valueListenable: scale,
            child: RepaintBoundary(
              child: _FilterFixture(
                state: fixture,
                child: const SizedBox(width: 200, height: 48),
              ),
            ),
            builder: (_, value, child) => Transform.scale(
              scale: value,
              alignment: Alignment.topLeft,
              child: child,
            ),
          ),
        ),
      ),
    );
    final initialPaints = fixture.paints;
    for (final value in [1.4, .85, 1.0]) {
      scale.value = value;
      await tester.pump();
      expect(fixture.sceneBounds!.width, closeTo(200 * value, .0001));
      expect(fixture.sceneBounds!.height, closeTo(48 * value, .0001));
      expect(fixture.paints, initialPaints);
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    scale.dispose();
  });

  testWidgets('shape geometry ignores route motion but tracks local motion', (
    tester,
  ) async {
    final route = ValueNotifier<Offset>(Offset.zero);
    final shape = ValueNotifier<Offset>(Offset.zero);
    var geometryChanges = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ValueListenableBuilder<Offset>(
            valueListenable: route,
            child: RepaintBoundary(
              child: _GeometryOwner(
                child: ValueListenableBuilder<Offset>(
                  valueListenable: shape,
                  child: _GeometryTracker(
                    onChanged: () => geometryChanges++,
                    child: const SizedBox(width: 48, height: 48),
                  ),
                  builder: (_, offset, child) =>
                      Transform.translate(offset: offset, child: child),
                ),
              ),
            ),
            builder: (_, offset, child) =>
                Transform.translate(offset: offset, child: child),
          ),
        ),
      ),
    );
    route.value = const Offset(80, 35);
    await tester.pump();
    expect(geometryChanges, 0);
    shape.value = const Offset(8, 0);
    await tester.pump();
    expect(geometryChanges, 1);
    route.value = const Offset(160, 12);
    await tester.pump();
    expect(geometryChanges, 1);
    shape.value = Offset.zero;
    await tester.pump();
    expect(geometryChanges, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    route.dispose();
    shape.dispose();
  });
}

class _FixtureState {
  int paints = 0;
  Rect? sceneBounds;
}

class _FilterFixture extends SingleChildRenderObjectWidget {
  const _FilterFixture({required this.state, required super.child});
  final _FixtureState state;

  @override
  RenderObject createRenderObject(BuildContext context) => _FilterRender(state);
}

class _FilterRender extends RenderProxyBox {
  _FilterRender(this.state);
  final _FixtureState state;
  final _handle = LayerHandle<TransformAwareBackdropFilterLayer>();

  @override
  bool get alwaysNeedsCompositing => true;

  ui.ImageFilter? _refresh() {
    final bounds = MatrixUtils.transformRect(
      getTransformTo(null),
      Offset.zero & size,
    );
    if (state.sceneBounds == bounds) return null;
    state.sceneBounds = bounds;
    return ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    state.paints++;
    _refresh();
    final layer = _handle.layer ??= TransformAwareBackdropFilterLayer(
      refreshFilter: _refresh,
    )..filter = ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1);
    context.pushLayer(layer, super.paint, offset);
  }

  @override
  void dispose() {
    _handle.layer = null;
    super.dispose();
  }
}

class _GeometryOwner extends SingleChildRenderObjectWidget {
  const _GeometryOwner({required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _GeometryOwnerRender();
}

class _GeometryOwnerRender extends RenderProxyBox {}

class _GeometryTracker extends SingleChildRenderObjectWidget {
  const _GeometryTracker({required this.onChanged, required super.child});
  final VoidCallback onChanged;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _GeometryTrackerRender(onChanged);
}

class _GeometryTrackerRender extends RenderProxyBox
    with TransformTrackingRenderObjectMixin {
  _GeometryTrackerRender(this.onChanged);
  final VoidCallback onChanged;

  @override
  RenderObject? get transformTrackingAncestor {
    RenderObject? node = parent;
    while (node != null) {
      if (node is _GeometryOwnerRender) return node;
      node = node.parent;
    }
    return null;
  }

  @override
  void onTransformChanged() => onChanged();
}
