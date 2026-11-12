import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/browser/browser_engine.dart';
import 'package:Kelivo/core/services/browser/browser_native_scroll_observer.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  const bridge = MethodChannel('app.browser_scroll');
  const codec = StandardMethodCodec();
  late List<MethodCall> calls;
  late String owner;
  late BrowserNativeScrollObserver observer;
  late List<BrowserScrollState> events;

  Future<void> send(
    int sequence, {
    bool touching = true,
    double delta = 12,
    String viewId = 'native-one',
  }) async {
    final complete = Completer<void>();
    await messenger.handlePlatformMessage(
      'app.browser_scroll/$owner',
      codec.encodeMethodCall(
        MethodCall('scroll', {
          'sequence': sequence,
          'viewId': viewId,
          'phase': 'update',
          'offset': 100.0,
          'viewportExtent': 844.0,
          'contentExtent': 3200.0,
          'isUserInteracting': touching,
          'gestureDelta': delta,
        }),
      ),
      (_) => complete.complete(),
    );
    await complete.future;
  }

  setUp(() {
    calls = [];
    events = [];
    messenger.setMockMethodCallHandler(bridge, (call) async {
      calls.add(call);
      owner = (call.arguments as Map)['owner'] as String;
      return call.method == 'attach' ? true : null;
    });
    observer = BrowserNativeScrollObserver(onUpdate: events.add);
  });
  tearDown(() async {
    await observer.dispose();
    messenger.setMockMethodCallHandler(bridge, null);
  });

  test(
    'ordered native pan events do not depend on a document handshake',
    () async {
      await observer.attach(viewId: 'native-one', visible: true);
      await send(1);
      expect(events.single.gestureDelta, 12);
      expect(events.single.viewportExtent, 844);
      expect(events.single.supportsScrollEnd, isFalse);
      await send(1, delta: -12);
      await send(0, delta: -12);
      expect(events, hasLength(1));
      await send(2, touching: false, delta: 0);
      expect(events.last.isUserInteracting, isFalse);
      observer.reset();
      expect(events.last.phase, BrowserScrollPhase.reset);
      await send(3, delta: -12);
      expect(events.last.gestureDelta, -12);
    },
  );

  test('headless engines do not scan or retry native attachment', () async {
    await observer.attach(viewId: 'native-one', visible: false);
    expect(calls, isEmpty);
    await observer.attach(viewId: 'native-one', visible: true);
    expect(calls.where((call) => call.method == 'attach'), hasLength(1));
    calls.clear();
    await observer.attach(viewId: 'native-one', visible: false);
    expect(calls.map((call) => call.method), ['visibility']);
  });

  test('hidden and disposed engines ignore queued native messages', () async {
    await observer.attach(viewId: 'native-one', visible: true);
    await observer.setVisible(false);
    await send(1);
    expect(events, isEmpty);
    await observer.setVisible(true);
    await send(2);
    expect(events, hasLength(1));
    await observer.dispose();
    await send(3);
    expect(events, hasLength(1));
    expect(calls.where((call) => call.method == 'detach'), hasLength(1));
  });

  testWidgets(
    'attachment retry cancels and completes when engine is disposed',
    (tester) async {
      messenger.setMockMethodCallHandler(bridge, (call) async {
        calls.add(call);
        return false;
      });
      final attaching = observer.attach(viewId: 'native-one', visible: true);
      await tester.pump();
      expect(calls.where((call) => call.method == 'attach'), hasLength(1));
      await observer.dispose();
      await attaching;
      await tester.pump(const Duration(seconds: 2));
      expect(calls.where((call) => call.method == 'attach'), hasLength(1));
      expect(calls.last.method, 'detach');
    },
  );

  testWidgets('latest visibility wins while attachment is waiting', (
    tester,
  ) async {
    final reply = Completer<bool>();
    messenger.setMockMethodCallHandler(bridge, (call) async {
      calls.add(call);
      return call.method == 'attach' ? reply.future : null;
    });
    final attaching = observer.attach(viewId: 'native-one', visible: true);
    await observer.setVisible(false);
    reply.complete(true);
    await attaching;
    expect(calls.last.method, 'visibility');
    expect((calls.last.arguments as Map)['visible'], isFalse);
  });

  testWidgets('hiding during a missing-host reply does not start a retry', (
    tester,
  ) async {
    final reply = Completer<bool>();
    messenger.setMockMethodCallHandler(bridge, (call) async {
      calls.add(call);
      return call.method == 'attach' ? reply.future : null;
    });
    var finished = false;
    final attaching = observer
        .attach(viewId: 'native-one', visible: true)
        .then((_) => finished = true);
    await observer.setVisible(false);
    reply.complete(false);
    await tester.pump();
    expect(finished, isTrue);
    await attaching;
    expect(calls.where((call) => call.method == 'attach'), hasLength(1));
  });

  testWidgets(
    'late visible hosts keep bounded-rate retries beyond one second',
    (tester) async {
      var available = false;
      messenger.setMockMethodCallHandler(bridge, (call) async {
        calls.add(call);
        return call.method == 'attach' ? available : null;
      });
      final attaching = observer.attach(viewId: 'native-one', visible: true);
      await tester.pump();
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        calls.where((call) => call.method == 'attach').length,
        lessThan(7),
      );
      available = true;
      await tester.pump(const Duration(seconds: 1));
      await attaching;
      expect(calls.last.method, 'visibility');
      final count = calls.length;
      await tester.pump(const Duration(seconds: 5));
      expect(
        calls,
        hasLength(count),
        reason: 'No polling after native attachment',
      );
    },
  );

  testWidgets('hiding a missing host cancels its pending retry immediately', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(bridge, (call) async {
      calls.add(call);
      return false;
    });
    final attaching = observer.attach(viewId: 'native-one', visible: true);
    await tester.pump();
    await observer.setVisible(false);
    await attaching;
    await tester.pump(const Duration(seconds: 5));
    expect(calls.where((call) => call.method == 'attach'), hasLength(1));
  });

  test('concrete controller identity replaces an in-flight old host', () async {
    final reply = Completer<bool>();
    messenger.setMockMethodCallHandler(bridge, (call) async {
      calls.add(call);
      owner = (call.arguments as Map)['owner'] as String;
      if (call.method != 'attach') return null;
      return (call.arguments as Map)['viewId'] == 'native-one'
          ? reply.future
          : true;
    });
    final attaching = observer.attach(viewId: 'native-one', visible: true);
    final replacing = observer.attach(viewId: 'native-popup', visible: true);
    reply.complete(true);
    await Future.wait([attaching, replacing]);
    expect(
      calls
          .where((call) => call.method == 'attach')
          .map((call) => (call.arguments as Map)['viewId']),
      ['native-one', 'native-popup'],
    );
    await send(100, viewId: 'native-one');
    expect(events, isEmpty);
    await send(1, viewId: 'native-popup');
    expect(events, hasLength(1));
  });

  for (final stage in ['shown', 'hidden', 'replacement']) {
    testWidgets('final visibility reply reconciles a $stage transition', (
      tester,
    ) async {
      final attachReply = Completer<bool>();
      final visibilityReplies = <Completer<void>>[];
      var nativeVisible = false;
      String? nativeViewId;
      messenger.setMockMethodCallHandler(bridge, (call) async {
        calls.add(call);
        final values = call.arguments as Map;
        if (call.method == 'attach') {
          nativeViewId = values['viewId'] as String;
          nativeVisible = values['visible'] as bool;
          if (stage == 'hidden' && !attachReply.isCompleted) {
            return await attachReply.future;
          }
          return true;
        }
        if (call.method == 'visibility') {
          nativeVisible = values['visible'] as bool;
          final reply = Completer<void>();
          visibilityReplies.add(reply);
          await reply.future;
        }
        return null;
      });
      final attaching = observer.attach(viewId: 'native-one', visible: true);
      await tester.pump();
      Future<void>? hiding;
      if (stage == 'hidden') {
        await observer.setVisible(false);
        attachReply.complete(true);
        await tester.pump();
        expect(nativeVisible, isFalse);
      } else if (stage == 'shown') {
        expect(nativeVisible, isTrue);
        hiding = observer.setVisible(false);
        await tester.pump();
        expect(nativeVisible, isFalse);
      }
      expect(visibilityReplies, isNotEmpty);
      final viewId = stage == 'replacement' ? 'native-popup' : 'native-one';
      final showing = observer.attach(viewId: viewId, visible: true);
      for (var turn = 0; turn < 4; turn++) {
        for (final reply in [...visibilityReplies]) {
          if (!reply.isCompleted) reply.complete();
        }
        await tester.pump();
      }
      await Future.wait([attaching, showing, if (hiding != null) hiding]);
      expect(nativeVisible, isTrue);
      expect(nativeViewId, viewId);
    });
  }
}
