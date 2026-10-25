import 'package:Kelivo/shared/widgets/floating_ipad_padding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'non-iOS content survives a rebuild with unavailable display information',
    (tester) async {
      final view = _UnavailableDisplayView(tester.view);
      late StateSetter rebuild;
      await tester.pumpWidget(
        View(
          view: view,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return FloatingIpadPadding(
                  child: const Text('Application content'),
                );
              },
            ),
          ),
        ),
        wrapWithView: false,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Application content'), findsOneWidget);

      view.displayUnavailable = true;
      rebuild(() {});
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Application content'), findsOneWidget);
      expect(view.displayReads, 0);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
      TargetPlatform.android,
    }),
  );

  for (final topPadding in [20.0, 70.0]) {
    testWidgets(
      'floating iPad reserves window controls with $topPadding top padding',
      (tester) async {
        _configureView(
          tester,
          viewSize: const Size(800, 1000),
          displaySize: const Size(1024, 1366),
          topPadding: topPadding,
        );
        final original = MediaQueryData.fromView(tester.view);
        final actual = await _readPadding(tester);
        final expectedTop = topPadding < 56 ? 56.0 : topPadding;

        expect(
          actual,
          original.copyWith(
            padding: original.padding.copyWith(top: expectedTop),
            viewPadding: original.viewPadding.copyWith(top: expectedTop),
          ),
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }

  for (final size in [const Size(1024, 1366), const Size(390, 844)]) {
    testWidgets('full-screen iOS view keeps its system padding at $size', (
      tester,
    ) async {
      _configureView(tester, viewSize: size, displaySize: size);
      final original = MediaQueryData.fromView(tester.view);

      expect(await _readPadding(tester), original);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({TargetPlatform.iOS}));
  }
}

void _configureView(
  WidgetTester tester, {
  required Size viewSize,
  required Size displaySize,
  double topPadding = 20,
}) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = viewSize * 2;
  tester.view.display.size = displaySize * 2;
  tester.view.viewPadding = FakeViewPadding(
    top: topPadding * 2,
    left: 8,
    right: 12,
    bottom: 40,
  );
  addTearDown(tester.view.reset);
  addTearDown(tester.view.display.reset);
}

Future<MediaQueryData> _readPadding(WidgetTester tester) async {
  late MediaQueryData actual;
  await tester.pumpWidget(
    FloatingIpadPadding(
      child: Builder(
        builder: (context) {
          actual = MediaQuery.of(context);
          return const SizedBox.expand();
        },
      ),
    ),
  );
  return actual;
}

class _UnavailableDisplayView extends TestFlutterView {
  _UnavailableDisplayView(TestFlutterView view)
    : super(
        view: view,
        platformDispatcher: view.platformDispatcher,
        display: view.display,
      );

  bool displayUnavailable = false;
  int displayReads = 0;

  @override
  TestDisplay get display {
    displayReads++;
    final display = displayUnavailable ? null : super.display;
    return display!;
  }
}
