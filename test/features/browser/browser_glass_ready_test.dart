import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:Kelivo/features/browser/widgets/native_browser_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget scene({
    VoidCallback? onReady,
    double radius = 24,
    double opacity = 1,
    BrowserSurfaceStyle style = BrowserSurfaceStyle.solid,
    GlobalKey? contentKey,
    bool reducedMotion = false,
    bool highContrast = false,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reducedMotion,
        highContrast: highContrast,
      ),
      child: Center(
        child: BrowserGlassScope(
          style: style,
          child: BrowserGlass(
            radius: radius,
            opacity: opacity,
            onReady: onReady,
            child: SizedBox(key: contentKey, width: 120, height: 48),
          ),
        ),
      ),
    ),
  );

  testWidgets('Flutter material reports after a host frame and only once', (
    tester,
  ) async {
    final contentKey = GlobalKey();
    var calls = 0;
    void ready() {
      calls++;
      expect(
        SchedulerBinding.instance.schedulerPhase,
        isNot(SchedulerPhase.persistentCallbacks),
      );
      final box = contentKey.currentContext!.findRenderObject()! as RenderBox;
      expect(box.hasSize, isTrue);
      expect(box.size, const Size(120, 48));
    }

    await tester.pumpWidget(scene(onReady: ready, contentKey: contentKey));
    expect(calls, 0);
    await tester.pump();
    expect(calls, 1);
    final state = tester.state(find.byType(BrowserGlass));
    for (final opacity in [.5, 0.0, 1.0]) {
      await tester.pumpWidget(
        scene(
          onReady: ready,
          radius: 1000,
          opacity: opacity,
          contentKey: contentKey,
        ),
      );
      await tester.pump();
      expect(tester.state(find.byType(BrowserGlass)), same(state));
      expect(calls, 1);
    }
  });

  testWidgets('adding readiness callback after mounting reports once', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(scene());
    await tester.pump();
    await tester.pumpWidget(scene(onReady: () => calls++));
    expect(calls, 0);
    await tester.pump();
    expect(calls, 1);
    await tester.pumpWidget(scene(onReady: () => calls += 100));
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('hidden optical material stops painting without remounting', (
    tester,
  ) async {
    await tester.pumpWidget(scene(style: BrowserSurfaceStyle.frosted));
    await tester.pumpAndSettle();
    final filter = tester.element(find.byType(BackdropFilter));
    final paintGate = find.descendant(
      of: find.byKey(const ValueKey('browserMaterialSurface')),
      matching: find.byType(Visibility),
    );
    for (final opacity in [0.0, .4, 1.0]) {
      await tester.pumpWidget(
        scene(style: BrowserSurfaceStyle.frosted, opacity: opacity),
      );
      expect(tester.element(find.byType(BackdropFilter)), same(filter));
      expect(tester.widget<Visibility>(paintGate).visible, opacity > 0);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('removal before the prepared frame suppresses readiness', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(scene(onReady: () => calls++));
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transparent solid needs neither platform view nor backdrop', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(scene(opacity: 0, onReady: () => calls++));
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(NativeBrowserGlass), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(Opacity), findsOneWidget);
  });

  double coverAlpha(WidgetTester tester) {
    final cover = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('browserMaterialCover')),
    );
    return (cover.decoration as BoxDecoration).color!.a;
  }

  testWidgets('new optical surfaces never start as opaque plates', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      scene(style: BrowserSurfaceStyle.frosted, onReady: () => calls++),
    );
    expect(coverAlpha(tester), 0);
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.pump();
    expect(calls, 1);
    await tester.pump(const Duration(milliseconds: 80));
    expect(coverAlpha(tester), 0);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('solid cover waits for the prepared glass then fades for 160ms', (
    tester,
  ) async {
    final contentKey = GlobalKey();
    await tester.pumpWidget(scene(contentKey: contentKey));
    await tester.pump();
    final content = contentKey.currentContext;
    expect(coverAlpha(tester), 1);
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.pumpWidget(
      scene(style: BrowserSurfaceStyle.frosted, contentKey: contentKey),
    );
    expect(coverAlpha(tester), 1);
    expect(find.byType(BackdropFilter), findsOneWidget);
    // The backdrop is a sibling of the fading Flutter paint, never its child.
    expect(
      find.ancestor(
        of: find.byType(BackdropFilter),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    await tester.pump();
    expect(coverAlpha(tester), 1);
    // Readiness resumes after the frame; anchor the newly scheduled ticker.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(coverAlpha(tester), closeTo(.5, .01));
    await tester.pump(const Duration(milliseconds: 80));
    expect(coverAlpha(tester), 0);
    expect(contentKey.currentContext, same(content));
    expect(find.byKey(contentKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning to solid covers the backdrop before releasing it', (
    tester,
  ) async {
    final contentKey = GlobalKey();
    await tester.pumpWidget(
      scene(style: BrowserSurfaceStyle.frosted, contentKey: contentKey),
    );
    await tester.pumpAndSettle();
    final content = contentKey.currentContext;
    expect(coverAlpha(tester), 0);
    await tester.pumpWidget(scene(contentKey: contentKey));
    expect(coverAlpha(tester), 0);
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 80));
    expect(coverAlpha(tester), closeTo(.5, .01));
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 80));
    expect(coverAlpha(tester), 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(NativeBrowserGlass), findsNothing);
    expect(contentKey.currentContext, same(content));
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching back before readiness ignores the abandoned surface', (
    tester,
  ) async {
    var readyCalls = 0;
    void ready() => readyCalls++;
    await tester.pumpWidget(scene(onReady: ready));
    await tester.pump();
    expect(readyCalls, 1);
    await tester.pumpWidget(
      scene(style: BrowserSurfaceStyle.frosted, onReady: ready),
    );
    expect(coverAlpha(tester), 1);
    await tester.pumpWidget(scene(onReady: ready));
    await tester.pumpAndSettle();
    expect(coverAlpha(tester), 1);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(readyCalls, 1);
    await tester.pumpWidget(
      scene(style: BrowserSurfaceStyle.frosted, onReady: ready),
    );
    await tester.pumpAndSettle();
    expect(coverAlpha(tester), 0);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(readyCalls, 1);
  });

  testWidgets('reversing the cover reuses its optical host and current alpha', (
    tester,
  ) async {
    await tester.pumpWidget(scene(style: BrowserSurfaceStyle.frosted));
    await tester.pumpAndSettle();
    final host = tester.element(find.byType(BackdropFilter));
    await tester.pumpWidget(scene());
    await tester.pump(const Duration(milliseconds: 64));
    final intermediate = coverAlpha(tester);
    expect(intermediate, closeTo(.4, .01));
    await tester.pumpWidget(scene(style: BrowserSurfaceStyle.frosted));
    expect(coverAlpha(tester), intermediate);
    expect(tester.element(find.byType(BackdropFilter)), same(host));
    await tester.pump(const Duration(milliseconds: 80));
    expect(coverAlpha(tester), closeTo(intermediate / 2, .01));
    await tester.pumpAndSettle();
    expect(coverAlpha(tester), 0);
    expect(tester.element(find.byType(BackdropFilter)), same(host));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion still waits for preparation but skips fading', (
    tester,
  ) async {
    await tester.pumpWidget(scene(reducedMotion: true));
    await tester.pump();
    await tester.pumpWidget(
      scene(style: BrowserSurfaceStyle.frosted, reducedMotion: true),
    );
    expect(coverAlpha(tester), 1);
    await tester.pumpAndSettle();
    expect(coverAlpha(tester), 0);
    await tester.pumpWidget(scene(reducedMotion: true));
    expect(coverAlpha(tester), 1);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('high contrast immediately releases optics and retains content', (
    tester,
  ) async {
    final contentKey = GlobalKey();
    await tester.pumpWidget(
      scene(style: BrowserSurfaceStyle.frosted, contentKey: contentKey),
    );
    await tester.pumpAndSettle();
    final content = contentKey.currentContext;
    await tester.pumpWidget(
      scene(
        style: BrowserSurfaceStyle.frosted,
        highContrast: true,
        contentKey: contentKey,
      ),
    );
    expect(coverAlpha(tester), 1);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(contentKey.currentContext, same(content));
    await tester.pumpWidget(
      scene(style: BrowserSurfaceStyle.frosted, contentKey: contentKey),
    );
    expect(coverAlpha(tester), 1);
    await tester.pumpAndSettle();
    expect(coverAlpha(tester), 0);
    expect(contentKey.currentContext, same(content));
  });

  testWidgets(
    'removal during preparation or fading leaves no callback or ticker',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        scene(style: BrowserSurfaceStyle.frosted, onReady: () => calls++),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.pumpWidget(scene(style: BrowserSurfaceStyle.frosted));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(coverAlpha(tester), 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cover follows parent opacity without duplicating the foreground',
    (tester) async {
      final contentKey = GlobalKey();
      await tester.pumpWidget(scene(contentKey: contentKey, opacity: .4));
      expect(coverAlpha(tester), closeTo(.4, .001));
      final content = contentKey.currentContext;
      await tester.pumpWidget(
        scene(
          contentKey: contentKey,
          opacity: .4,
          style: BrowserSurfaceStyle.frosted,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(coverAlpha(tester), closeTo(.2, .01));
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('browserGlassForeground')),
            )
            .opacity,
        .4,
      );
      expect(contentKey.currentContext, same(content));
      expect(find.byKey(contentKey), findsOneWidget);
    },
  );

  testWidgets(
    'hidden preparation removes cover before a menu becomes visible',
    (tester) async {
      var calls = 0;
      void ready() => calls++;
      await tester.pumpWidget(
        scene(style: BrowserSurfaceStyle.frosted, opacity: 0, onReady: ready),
      );
      expect(calls, 0);
      await tester.pump();
      expect(calls, 1);
      await tester.pumpWidget(
        scene(style: BrowserSurfaceStyle.frosted, opacity: 1, onReady: ready),
      );
      expect(coverAlpha(tester), 0);
      expect(find.byType(BackdropFilter), findsOneWidget);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(coverAlpha(tester), 0);
    },
  );
}
