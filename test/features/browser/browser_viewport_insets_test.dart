import 'dart:async';

import 'package:Kelivo/core/services/browser/browser_engine.dart';
import 'package:Kelivo/features/browser/widgets/browser_viewport_insets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('app.browser_window');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  Widget scene(String? id, {int version = 0, double top = 80, Key? key}) =>
      MaterialApp(
        home: BrowserViewportInsets(
          key: key,
          tabId: id,
          viewIdentity: version,
          top: top,
          builder: (_, underlap) => Text(underlap ? 'underlap' : 'below'),
        ),
      );

  void viewportTest(String name, WidgetTesterCallback body) {
    for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
      testWidgets('$name on ${platform.name}', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        calls.clear();
        try {
          await body(tester);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }

  Widget accessibilityScene(List<String> ids) => MaterialApp(
    home: Column(
      children: [
        for (final id in ids)
          BrowserViewportInsets(
            key: ValueKey(id),
            tabId: id,
            top: 59,
            builder: (_, underlap) => ValueListenableBuilder<bool>(
              valueListenable: BrowserViewportInsets.reduceTransparency,
              builder: (_, reduced, _) => Text(
                '$id:${underlap ? 'underlap' : 'below'}:'
                '${reduced ? 'protected' : 'fade'}',
              ),
            ),
          ),
      ],
    ),
  );

  void accessibilityTest(String name, WidgetTesterCallback body) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      calls.clear();
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  void accessibilityHost(FutureOr<bool> Function() read) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return switch (call.method) {
        'supportsBrowserViewportInsets' || 'setBrowserViewportInsets' => true,
        'getBrowserReduceTransparency' => await read(),
        _ => null,
      };
    });
  }

  Future<void> notifyTransparency(WidgetTester tester, bool reduced) async {
    final delivery = binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        MethodCall('browserReduceTransparencyChanged', reduced),
      ),
      null,
    );
    await tester.pump();
    await delivery;
  }

  accessibilityTest(
    'native transparency preference updates without changing insets',
    (tester) async {
      accessibilityHost(() => true);
      await tester.pumpWidget(accessibilityScene(['a']));
      await tester.pumpAndSettle();
      expect(find.text('a:underlap:protected'), findsOneWidget);
      final callCount = calls.length;
      await notifyTransparency(tester, false);
      expect(find.text('a:underlap:fade'), findsOneWidget);
      await notifyTransparency(tester, true);
      expect(find.text('a:underlap:protected'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(calls.length, callCount);
      expect(
        calls.where((call) => call.method == 'getBrowserReduceTransparency'),
        hasLength(1),
      );
    },
  );

  accessibilityTest('a native change supersedes a pending transparency query', (
    tester,
  ) async {
    final initial = Completer<bool>();
    accessibilityHost(() => initial.future);
    await tester.pumpWidget(accessibilityScene(['a']));
    await tester.pumpAndSettle();
    expect(find.text('a:underlap:protected'), findsOneWidget);
    await notifyTransparency(tester, true);
    initial.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('a:underlap:protected'), findsOneWidget);
  });

  accessibilityTest('viewport hosts share the native preference subscription', (
    tester,
  ) async {
    accessibilityHost(() => false);
    await tester.pumpWidget(accessibilityScene(['a', 'b']));
    await tester.pumpAndSettle();
    expect(find.text('a:underlap:fade'), findsOneWidget);
    expect(find.text('b:underlap:fade'), findsOneWidget);
    await tester.pumpWidget(accessibilityScene(['b']));
    await tester.pumpAndSettle();
    await notifyTransparency(tester, true);
    expect(find.text('b:underlap:protected'), findsOneWidget);
    expect(
      calls.where((call) => call.method == 'getBrowserReduceTransparency'),
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await notifyTransparency(tester, false);
    expect(BrowserViewportInsets.reduceTransparency.value, isTrue);
    await tester.pumpWidget(accessibilityScene(['b']));
    await tester.pumpAndSettle();
    expect(find.text('b:underlap:fade'), findsOneWidget);
    expect(
      calls.where((call) => call.method == 'getBrowserReduceTransparency'),
      hasLength(2),
    );
  });

  accessibilityTest(
    'a disposed subscription cannot overwrite a new host query',
    (tester) async {
      final queries = <Completer<bool>>[];
      accessibilityHost(() {
        final query = Completer<bool>();
        queries.add(query);
        return query.future;
      });
      await tester.pumpWidget(accessibilityScene(['old']));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(accessibilityScene(['new']));
      await tester.pumpAndSettle();
      expect(queries, hasLength(2));
      queries.last.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('new:underlap:fade'), findsOneWidget);
      queries.first.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('new:underlap:fade'), findsOneWidget);
    },
  );

  testWidgets('macOS keeps the existing window channel callback', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    calls.clear();
    var callbacks = 0;
    channel.setMethodCallHandler((_) async => callbacks++);
    accessibilityHost(() => false);
    try {
      await tester.pumpWidget(scene('a'));
      await tester.pumpAndSettle();
      await notifyTransparency(tester, false);
      await tester.pumpWidget(const SizedBox.shrink());
      await notifyTransparency(tester, true);
      expect(callbacks, 2);
      expect(
        calls.where((call) => call.method == 'getBrowserReduceTransparency'),
        isEmpty,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      channel.setMethodCallHandler(null);
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('native marker cannot execute a restored tab ID as JavaScript', () {
    final marker = browserTabUserScriptMarker('tab*/ alert(1); /*');
    expect(marker.startsWith('/* kelivo-browser-tab:'), isTrue);
    expect(marker.endsWith(' */'), isTrue);
    expect(marker.split('*/').length, 2);
    expect(marker, isNot(contains('alert')));
  });

  viewportTest(
    'header underlap waits for native view and retains leases until disposal',
    (tester) async {
      var attempts = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'supportsBrowserViewportInsets') return true;
        if (call.method == 'setBrowserViewportInsets') return ++attempts >= 2;
        return null;
      });
      await tester.pumpWidget(scene('a'));
      await tester.pump();
      expect(find.text('below'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.text('underlap'), findsOneWidget);
      final sets = calls
          .where((call) => call.method == 'setBrowserViewportInsets')
          .toList();
      expect(sets.length, 2);
      expect(sets.last.arguments['marker'], browserTabUserScriptMarker('a'));
      expect(sets.last.arguments['top'], 80);
      final owner = sets.last.arguments['owner'];
      await tester.pump(const Duration(seconds: 1));
      expect(
        calls.where((call) => call.method == 'setBrowserViewportInsets').length,
        2,
      );
      await tester.pumpWidget(scene('b'));
      await tester.pump();
      expect(
        calls.where((call) => call.method == 'releaseBrowserViewportInsets'),
        isEmpty,
      );
      expect(calls.last.arguments['marker'], browserTabUserScriptMarker('b'));
      await tester.pumpWidget(scene('b', version: 1));
      await tester.pump();
      expect(
        calls.where((call) => call.method == 'releaseBrowserViewportInsets'),
        isEmpty,
      );
      expect(calls.last.arguments['marker'], browserTabUserScriptMarker('b'));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(calls.last.method, 'releaseBrowserViewportInsets');
      expect(calls.last.arguments, owner);
    },
  );

  viewportTest('tab attachment keeps the established viewport geometry', (
    tester,
  ) async {
    final next = Completer<bool>();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'supportsBrowserViewportInsets') return true;
      if (call.method == 'setBrowserViewportInsets') {
        return call.arguments['marker'] == browserTabUserScriptMarker('a')
            ? true
            : next.future;
      }
      return null;
    });
    await tester.pumpWidget(scene('a'));
    await tester.pumpAndSettle();
    expect(find.text('underlap'), findsOneWidget);
    await tester.pumpWidget(scene('b'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('underlap'), findsOneWidget);
    next.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('underlap'), findsOneWidget);
  });

  viewportTest('start-page round trip retains viewport and native leases', (
    tester,
  ) async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return call.method == 'releaseBrowserViewportInsets' ? null : true;
    });
    await tester.pumpWidget(scene('a'));
    await tester.pumpAndSettle();
    expect(find.text('underlap'), findsOneWidget);
    final owner = calls.last.arguments['owner'];
    final beforeBlank = calls.length;
    await tester.pumpWidget(scene(null));
    await tester.pumpAndSettle();
    expect(find.text('underlap'), findsOneWidget);
    expect(
      calls.length,
      beforeBlank,
      reason: 'start page must not reset retained WK insets',
    );
    await tester.pumpWidget(scene('a'));
    await tester.pumpAndSettle();
    expect(find.text('underlap'), findsOneWidget);
    expect(calls.last.arguments['owner'], owner);
    expect(
      calls.where((call) => call.method == 'releaseBrowserViewportInsets'),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(
      calls.where((call) => call.method == 'releaseBrowserViewportInsets'),
      hasLength(1),
    );
    expect(calls.last.arguments, owner);
  });

  viewportTest('unsupported systems never place content under the header', (
    tester,
  ) async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return false;
    });
    await tester.pumpWidget(scene('a'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('below'), findsOneWidget);
    expect(calls.map((call) => call.method), ['supportsBrowserViewportInsets']);
  });

  viewportTest(
    'safe-area changes replace the inset without repeated steady-state calls',
    (tester) async {
      final acknowledgements = <Completer<bool>>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'supportsBrowserViewportInsets') return true;
        if (call.method == 'setBrowserViewportInsets') {
          final acknowledgement = Completer<bool>();
          acknowledgements.add(acknowledgement);
          return acknowledgement.future;
        }
        return null;
      });
      await tester.pumpWidget(scene('a', top: 59));
      await tester.pump();
      // Native attachment runs after a frame, and underlap must wait for its
      // asynchronous acknowledgement before a subsequent frame can render it.
      expect(find.text('below'), findsOneWidget);
      final owner = calls.last.arguments['owner'];
      expect(calls.last.arguments['top'], 59);
      expect(acknowledgements, hasLength(1));
      acknowledgements.single.complete(true);
      await tester.pump(); // Deliver the channel reply and schedule the build.
      await tester.pump();
      expect(find.text('underlap'), findsOneWidget);
      await tester.pumpWidget(scene('a', top: 20));
      await tester.pump();
      expect(find.text('below'), findsOneWidget);
      expect(calls.last.arguments['top'], 20);
      expect(calls.last.arguments['owner'], owner);
      expect(acknowledgements, hasLength(2));
      acknowledgements.last.complete(true);
      await tester.pump(); // Deliver the channel reply and schedule the build.
      await tester.pump();
      expect(find.text('underlap'), findsOneWidget);
      expect(
        calls.where((call) => call.method == 'releaseBrowserViewportInsets'),
        isEmpty,
      );
      final callCount = calls.length;
      await tester.pump(const Duration(seconds: 2));
      expect(calls.length, callCount);
    },
  );

  viewportTest('replacement hosts release only their own native lease', (
    tester,
  ) async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return call.method == 'releaseBrowserViewportInsets' ? null : true;
    });
    await tester.pumpWidget(scene('a', key: const ValueKey('old')));
    await tester.pump();
    final oldOwner = calls.last.arguments['owner'];
    await tester.pumpWidget(scene('a', key: const ValueKey('new')));
    await tester.pump();
    final newOwner = calls.last.arguments['owner'];
    expect(newOwner, isNot(oldOwner));
    expect(
      calls
          .where((call) => call.method == 'releaseBrowserViewportInsets')
          .single
          .arguments,
      oldOwner,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(calls.last.method, 'releaseBrowserViewportInsets');
    expect(calls.last.arguments, newOwner);
  });

  viewportTest(
    'disposal cancels attach retries and ignores late native completion',
    (tester) async {
      final pending = Completer<bool>();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'supportsBrowserViewportInsets') return true;
        if (call.method == 'setBrowserViewportInsets') return pending.future;
        return null;
      });
      await tester.pumpWidget(scene('a'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(true);
      await tester.pump(const Duration(seconds: 2));
      expect(
        calls.where((call) => call.method == 'setBrowserViewportInsets').length,
        1,
      );
      expect(calls.last.method, 'releaseBrowserViewportInsets');
      expect(tester.takeException(), isNull);
    },
  );
}
