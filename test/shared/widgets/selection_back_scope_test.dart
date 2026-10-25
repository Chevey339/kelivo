import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/shared/widgets/interactive_drawer.dart';
import 'package:Kelivo/shared/widgets/selection_back_scope.dart';

Future<void> _backGesture(WidgetTester tester, {bool cancel = false}) async {
  for (final call in [
    const MethodCall('startBackGesture', {
      'touchOffset': [5.0, 300.0],
      'progress': 0.0,
      'swipeEdge': 0,
    }),
    MethodCall(cancel ? 'cancelBackGesture' : 'commitBackGesture'),
  ]) {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/backgesture',
      const StandardMethodCodec().encodeMethodCall(call),
      (_) {},
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final predictive in [false, true]) {
    testWidgets(
      'Android ${predictive ? 'predictive gesture' : 'system back'} cancels root selection before exiting',
      (tester) async {
        final selecting = ValueNotifier(false);
        addTearDown(selecting.dispose);
        final platformCalls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => platformCalls.add(call),
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/lifecycle',
          const StringCodec().encodeMessage('AppLifecycleState.resumed'),
          (_) {},
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: selecting,
              builder: (_, value, _) => SelectionBackScope(
                selecting: value,
                onCancel: () => selecting.value = false,
                child: Scaffold(body: Text(value ? 'Sharing' : 'Chat')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        selecting.value = true;
        await tester.pumpAndSettle();
        expect(
          platformCalls
              .lastWhere(
                (call) =>
                    call.method == 'SystemNavigator.setFrameworkHandlesBack',
              )
              .arguments,
          isTrue,
        );

        if (predictive) {
          await _backGesture(tester, cancel: true);
          expect(find.text('Sharing'), findsOneWidget);
          await _backGesture(tester);
        } else {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }
        expect(find.text('Chat'), findsOneWidget);
        expect(
          platformCalls.where((c) => c.method == 'SystemNavigator.pop'),
          isEmpty,
        );
        expect(
          platformCalls
              .lastWhere(
                (call) =>
                    call.method == 'SystemNavigator.setFrameworkHandlesBack',
              )
              .arguments,
          isFalse,
        );

        await tester.binding.handlePopRoute();
        expect(
          platformCalls.where((c) => c.method == 'SystemNavigator.pop'),
          hasLength(1),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets('a covering dialog closes before the selection beneath it', (
    tester,
  ) async {
    final selecting = ValueNotifier(true);
    addTearDown(selecting.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: ValueListenableBuilder<bool>(
          valueListenable: selecting,
          builder: (_, value, _) => SelectionBackScope(
            selecting: value,
            onCancel: () => selecting.value = false,
            child: const Scaffold(body: Text('Selection')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.push(
      DialogRoute<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(content: Text('Export choices')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Export choices'), findsNothing);
    expect(selecting.value, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(selecting.value, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('an open drawer closes without also cancelling chat selection', (
    tester,
  ) async {
    final selecting = ValueNotifier(true);
    final drawer = InteractiveDrawerController();
    addTearDown(selecting.dispose);
    addTearDown(drawer.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: selecting,
          builder: (_, value, _) => SelectionBackScope(
            selecting: value,
            onCancel: () {
              if (drawer.isClosed) selecting.value = false;
            },
            child: InteractiveDrawer(
              controller: drawer,
              drawer: const Text('Topics'),
              child: const Scaffold(body: Text('Chat selection')),
            ),
          ),
        ),
      ),
    );
    await drawer.open();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(drawer.isClosed, isTrue);
    expect(selecting.value, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(selecting.value, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
