import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/browser/browser_management_route.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('management navigation follows $platform', (tester) async {
      late PageRoute<void> route;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) {
              route = browserManagementRoute<void>(
                context: context,
                builder: (_) => const SizedBox(),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        route,
        platform == TargetPlatform.iOS
            ? isA<BrowserManagementRoute<void>>()
            : isA<MaterialPageRoute<void>>(),
      );
      route.dispose();
    });
  }

  const underlayKey = ValueKey('nativeBrowserBounds');
  const managementKey = ValueKey('managementPage');

  Future<
    ({
      PageRoute<dynamic> underlay,
      BrowserManagementRoute<String> route,
      Future<String?> result,
    })
  >
  mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final navigator = GlobalKey<NavigatorState>();
    late PageRoute<dynamic> underlay;
    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: navigator,
        home: Builder(
          builder: (context) {
            underlay = ModalRoute.of(context)! as PageRoute<dynamic>;
            return const CupertinoPageScaffold(
              child: SizedBox.expand(
                key: underlayKey,
                child: Text('Native browser viewport'),
              ),
            );
          },
        ),
      ),
    );
    final route = BrowserManagementRoute<String>(
      builder: (context) => CupertinoPageScaffold(
        key: managementKey,
        child: Center(
          child: CupertinoButton(
            onPressed: () => Navigator.of(context).pop('saved'),
            child: const Text('Finish'),
          ),
        ),
      ),
    );
    final result = navigator.currentState!.push<String>(route);
    await tester.pump();
    return (underlay: underlay, route: route, result: result);
  }

  void expectStationary(WidgetTester tester, PageRoute<dynamic> underlay) {
    expect(underlay.secondaryAnimation!.value, 0);
    expect(underlay.secondaryAnimation!.status, AnimationStatus.dismissed);
    expect(
      tester.getRect(find.byKey(underlayKey, skipOffstage: false)),
      const Rect.fromLTWH(0, 0, 390, 844),
    );
  }

  testWidgets(
    'Android management motion leaves the native viewport stationary',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final navigator = GlobalKey<NavigatorState>();
      late PageRoute<dynamic> underlay;
      late BuildContext browserContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          navigatorKey: navigator,
          home: Builder(
            builder: (context) {
              browserContext = context;
              underlay = ModalRoute.of(context)! as PageRoute<dynamic>;
              return const SizedBox.expand(key: underlayKey);
            },
          ),
        ),
      );
      final route = browserManagementRoute<String>(
        context: browserContext,
        builder: (_) => const Scaffold(body: Text('Settings')),
      );
      final result = navigator.currentState!.push(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(route.animation!.value, inExclusiveRange(0, 1));
      expectStationary(tester, underlay);
      await tester.pumpAndSettle();
      navigator.currentState!.pop('saved');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(route.animation!.value, inExclusiveRange(0, 1));
      expectStationary(tester, underlay);
      await tester.pumpAndSettle();
      expect(await result, 'saved');
    },
  );

  testWidgets('enter and cancelled edge swipe keep native page stationary', (
    tester,
  ) async {
    final mounted = await mount(tester);
    await tester.pump(const Duration(milliseconds: 150));
    expect(mounted.route.animation!.value, inExclusiveRange(0, 1));
    expectStationary(tester, mounted.underlay);
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(const Offset(2, 400));
    await gesture.moveTo(const Offset(40, 400));
    await tester.pump();
    await gesture.moveTo(const Offset(110, 400));
    await tester.pump(const Duration(milliseconds: 80));
    expect(mounted.route.popGestureInProgress, isTrue);
    expect(mounted.route.animation!.value, inExclusiveRange(0, 1));
    expectStationary(tester, mounted.underlay);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(mounted.route.isCurrent, isTrue);
    expect(mounted.route.animation!.value, 1);
    expect(mounted.route.popGestureInProgress, isFalse);
    expect(find.byKey(managementKey), findsOneWidget);

    await tester.tap(find.text('Finish'));
    await tester.pump(const Duration(milliseconds: 100));
    expectStationary(tester, mounted.underlay);
    await tester.pumpAndSettle();
    expect(await mounted.result, 'saved');
    expect(find.byKey(managementKey), findsNothing);
  });

  testWidgets('completed edge swipe dismisses only management page', (
    tester,
  ) async {
    final mounted = await mount(tester);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(2, 400));
    await gesture.moveTo(const Offset(40, 400));
    await tester.pump();
    await gesture.moveTo(const Offset(320, 400));
    await tester.pump(const Duration(milliseconds: 80));
    expect(mounted.route.popGestureInProgress, isTrue);
    expectStationary(tester, mounted.underlay);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(await mounted.result, isNull);
    expect(find.byKey(managementKey), findsNothing);
    expect(find.byKey(underlayKey), findsOneWidget);
    expect(mounted.underlay.isCurrent, isTrue);
    expectStationary(tester, mounted.underlay);
    expect(tester.takeException(), isNull);
  });
}
