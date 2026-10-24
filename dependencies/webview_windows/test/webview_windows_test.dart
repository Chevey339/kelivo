import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_windows/webview_windows.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const plugin = MethodChannel('io.jns.webview.win');
  const instance = MethodChannel('io.jns.webview.win/42');
  const events = MethodChannel('io.jns.webview.win/42/events');
  final calls = <MethodCall>[];
  final instanceCalls = <MethodCall>[];
  final eventCalls = <MethodCall>[];
  Future<Object?> Function(MethodCall)? create;

  setUp(() {
    calls.clear();
    instanceCalls.clear();
    eventCalls.clear();
    create = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(plugin,
        (call) async {
      calls.add(call);
      if (call.method.startsWith('initialize')) {
        return create == null ? {'textureId': 42} : await create!(call);
      }
      return null;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(instance,
        (call) async {
      instanceCalls.add(call);
      return null;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(events,
        (call) async {
      eventCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    for (final channel in [plugin, instance, events]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
  });

  Future<void> emit(String type, [Object? value]) async {
    final done = Completer<void>();
    binding.channelBuffers.push(
        events.name,
        const StandardMethodCodec()
            .encodeSuccessEnvelope({'type': type, 'value': value}),
        (_) => done.complete());
    await done.future;
    await Future<void>.value();
  }

  test(
      'restricted entry, immutable mode, single initialization and one document call',
      () async {
    final controller = WebviewController();
    final first = controller.initializeRestrictedPreview();
    expect(controller.value.status, WebviewStatus.initializing);
    expect(identical(first, controller.initializeRestrictedPreview()), isTrue);
    await first;
    await controller.ready;
    expect(controller.value.status, WebviewStatus.ready);
    expect(controller.isRestrictedPreview, isTrue);
    await expectLater(controller.initialize(), throwsStateError);
    await controller.loadStringContent('<html>trusted wrapper</html>');
    expect(calls.map((c) => c.method), ['initializeRestrictedPreview']);
    expect(instanceCalls.single.method, 'loadStringContent');
    await controller.dispose();
    expect(controller.value.status, WebviewStatus.disposed);
    expect(eventCalls.map((c) => c.method), ['listen', 'cancel']);
    expect(calls.last.method, 'dispose');
    expect(calls.last.arguments, 42);
  });

  test('ordinary initialization keeps its method and supports ordinary events',
      () async {
    final controller = WebviewController();
    await controller.initialize();
    expect(controller.isRestrictedPreview, isFalse);
    final title = controller.title.first;
    final message = controller.webMessage.first;
    await emit('titleChanged', 'ordinary page');
    await emit('webMessageReceived', '{"example":1}');
    expect(await title, 'ordinary page');
    expect(await message, {'example': 1});
    await controller.loadUrl('https://example.test');
    expect(instanceCalls.single.method, 'loadUrl');
    await expectLater(
        controller.initializeRestrictedPreview(), throwsStateError);
    await controller.dispose();
  });

  test('restricted decisions are observation only, with no web message bridge',
      () async {
    final controller = WebviewController();
    await controller.initializeRestrictedPreview();
    final blocked = controller.restrictedBlocked.first;
    final webMessages = <Object?>[];
    final sub = controller.webMessage.listen(webMessages.add);
    await emit('restrictedBlocked', 'frame_navigation');
    await emit('webMessageReceived', '{"untrusted":true}');
    expect(await blocked, 'frame_navigation');
    expect(webMessages, isEmpty);
    expect(instanceCalls, isEmpty);
    await emit('restrictedClosed');
    expect(controller.value.status, WebviewStatus.failed);
    expect(controller.value.isInitialized, isFalse);
    expect((controller.value.error as PlatformException).code,
        'restricted_preview_closed');
    await sub.cancel();
    await controller.dispose();
  });

  testWidgets(
      'native close removes texture and ignores pending input and resize',
      (tester) async {
    final controller = WebviewController();
    await controller.initializeRestrictedPreview();
    await tester.pumpWidget(MaterialApp(
        home: SizedBox(width: 200, height: 160, child: Webview(controller))));
    await tester.pump();
    expect(find.byType(Texture), findsOneWidget);
    instanceCalls.clear();
    await emit('restrictedClosed');
    // Before the scheduled rebuild, an already queued pointer event is inert.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(const Offset(30, 30));
    await tester.pump();
    expect(find.byType(Texture), findsNothing);
    await tester.binding.setSurfaceSize(const Size(500, 400));
    await tester.pump();
    await mouse.moveTo(const Offset(50, 50));
    expect(instanceCalls, isEmpty);
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(controller.dispose);
    await tester.binding.setSurfaceSize(null);
  });

  for (final error in [
    PlatformException(
        code: 'webview_creation_failed', message: 'Update WebView2 Runtime'),
    MissingPluginException('unsupported'),
    const FormatException('bad response'),
  ]) {
    test(
        'failed initialization exposes ${error.runtimeType}, never falls back, and disposes',
        () async {
      create = (_) async => throw error;
      final controller = WebviewController();
      Object? decodedError;
      try {
        await controller.initializeRestrictedPreview();
        fail('Creation must fail');
      } catch (caught) {
        decodedError = caught;
      }
      if (error is MissingPluginException) {
        expect(decodedError, isA<MissingPluginException>());
      } else {
        expect(
            decodedError,
            isA<PlatformException>().having((e) => e.code, 'code',
                error is PlatformException ? error.code : 'error'));
      }
      await expectLater(controller.ready, throwsA(same(decodedError)));
      expect(controller.value.status, WebviewStatus.failed);
      expect(controller.value.error, same(decodedError));
      await expectLater(controller.initialize(), throwsStateError);
      await controller.dispose().timeout(const Duration(seconds: 1));
      await controller.dispose();
      expect(calls.map((c) => c.method), ['initializeRestrictedPreview']);
      expect(eventCalls, isEmpty);
    });
  }

  test('malformed creation reply fails instead of reporting a ready view',
      () async {
    create = (_) async => {'textureId': 'not an id'};
    final controller = WebviewController();
    await expectLater(
        controller.initializeRestrictedPreview(), throwsFormatException);
    expect(controller.value.isInitialized, isFalse);
    await controller.dispose();
  });

  test(
      'dispose before initialize closes streams without native calls or hanging',
      () async {
    final controller = WebviewController();
    await controller.dispose().timeout(const Duration(seconds: 1));
    await expectLater(controller.ready, throwsStateError);
    await expectLater(
        controller.initializeRestrictedPreview(), throwsStateError);
    expect(await controller.restrictedBlocked.toList(), isEmpty);
    expect(await controller.title.toList(), isEmpty);
    expect(calls, isEmpty);
    await controller.dispose();
  });

  test(
      'dispose during creation closes the late native result without subscribing',
      () async {
    final response = Completer<Object?>();
    final started = Completer<void>();
    create = (_) {
      started.complete();
      return response.future;
    };
    final controller = WebviewController();
    final initialization = controller.initializeRestrictedPreview();
    final failed = expectLater(initialization, throwsStateError);
    await started.future;
    final disposal = controller.dispose();
    expect(controller.value.status, WebviewStatus.disposed);
    response.complete({'textureId': 42});
    await failed;
    await disposal;
    await controller.dispose();
    expect(
        calls.map((c) => c.method), ['initializeRestrictedPreview', 'dispose']);
    expect(eventCalls, isEmpty);
  });

  test('dispose during failed creation is independent of ready success',
      () async {
    final response = Completer<Object?>();
    final started = Completer<void>();
    create = (_) {
      started.complete();
      return response.future;
    };
    final controller = WebviewController();
    final initialization = controller.initializeRestrictedPreview();
    final failed =
        expectLater(initialization, throwsA(isA<PlatformException>()));
    await started.future;
    final disposal = controller.dispose();
    response.completeError(PlatformException(code: 'unsupported_runtime'));
    await failed;
    await disposal;
    expect(calls.length, 1);
    expect(controller.value.status, WebviewStatus.disposed);
  });

  test('disposal queued from initialization closes the pending native view',
      () async {
    final controller = WebviewController();
    Future<void>? disposal;
    controller.addListener(() {
      if (controller.value.status == WebviewStatus.initializing) {
        // Notifier forbids disposing within notifyListeners; schedule its
        // standard microtask handoff before native initialization resolves.
        scheduleMicrotask(() {
          disposal = controller.dispose();
        });
      }
    });
    final response = Completer<Object?>();
    create = (_) => response.future;
    final initialization = controller.initializeRestrictedPreview();
    final failed = expectLater(initialization, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    response.complete({'textureId': 42});
    await failed;
    await disposal;
    expect(calls.where((c) => c.method == 'dispose').length, 1);
  });

  test('repeat disposal shares completion and emits stream completion once',
      () async {
    final controller = WebviewController();
    await controller.initializeRestrictedPreview();
    var completed = 0;
    controller.restrictedBlocked.listen((_) {}, onDone: () {
      completed++;
    });
    final first = controller.dispose();
    expect(identical(first, controller.dispose()), isTrue);
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(completed, 1);
    expect(calls.where((c) => c.method == 'dispose').length, 1);
  });
}
