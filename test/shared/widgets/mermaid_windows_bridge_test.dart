import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/shared/widgets/mermaid_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.directory);
  final String directory;

  @override
  Future<String?> getTemporaryPath() async => directory;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const plugin = MethodChannel('io.jns.webview.win');
  late MethodChannel instance;
  late MethodChannel events;
  var textureId = 41;
  const imageBytes = [137, 80, 78, 71];
  late Directory directory;
  late PathProviderPlatform originalPaths;
  late Completer<Object?> initialization;
  late Completer<String> loadedUrl;
  final scripts = <String>[];
  PlatformException? scriptError;

  setUp(() async {
    // Do not retain an asset Future from a previous test's FakeAsync zone.
    rootBundle.evict('assets/mermaid.min.js');
    textureId++;
    instance = MethodChannel('io.jns.webview.win/$textureId');
    events = MethodChannel('io.jns.webview.win/$textureId/events');
    directory = await Directory.systemTemp.createTemp('mermaid-windows-test-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(directory.path);
    initialization = Completer<Object?>();
    loadedUrl = Completer<String>();
    scripts.clear();
    scriptError = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(plugin, (
      call,
    ) async {
      if (call.method == 'initialize') return initialization.future;
      return null;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(instance, (
      call,
    ) async {
      if (call.method == 'loadUrl' && !loadedUrl.isCompleted) {
        loadedUrl.complete(call.arguments as String);
      } else if (call.method == 'executeScript') {
        scripts.add(call.arguments as String);
        if (scriptError != null) throw scriptError!;
        return 'null';
      }
      return null;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      events,
      (_) async => null,
    );
  });

  tearDown(() async {
    for (final channel in [plugin, instance, events]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
    PathProviderPlatform.instance = originalPaths;
    await directory.delete(recursive: true);
  });

  Future<void> emit(Map<String, Object> message) async {
    final done = Completer<void>();
    // JS posts a JSON string; WebView2 then serializes that string for Dart.
    binding.channelBuffers.push(
      events.name,
      const StandardMethodCodec().encodeSuccessEnvelope({
        'type': 'webMessageReceived',
        'value': jsonEncode(jsonEncode(message)),
      }),
      (_) => done.complete(),
    );
    await done.future;
    await Future<void>.value();
  }

  Future<void> loadDocument(WidgetTester tester) async {
    initialization.complete({'textureId': textureId});
    for (var attempt = 0; attempt < 500 && !loadedUrl.isCompleted; attempt++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(loadedUrl.isCompleted, isTrue);
    await tester.runAsync(() async {
      final url = await loadedUrl.future;
      expect(await File.fromUri(Uri.parse(url)).exists(), isTrue);
    });
    await tester.pump();
  }

  for (final svg in [false, true]) {
    testWidgets(
      'Windows ${svg ? 'SVG' : 'Mermaid'} waits for rendering before export',
      (tester) async {
        final handle = createMermaidView(
          svg
              ? '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" />'
              : 'graph TD; A-->B',
          false,
          isSvg: svg,
        )!;
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(width: 200, height: 160, child: handle.widget),
          ),
        );
        final result = handle.exportPngBytes!();
        var completed = false;
        result.then((_) => completed = true);
        await tester.pump(const Duration(seconds: 2));
        expect(completed, isFalse);
        expect(scripts, isEmpty);

        await loadDocument(tester);
        await tester.pump(const Duration(seconds: 1));
        expect(
          scripts,
          isEmpty,
          reason: 'An initialized WebView is not a rendered diagram',
        );
        await emit({'type': 'ready', 'generation': 999, 'success': true});
        await tester.pump();
        expect(scripts, isEmpty, reason: 'Ignore stale document notifications');
        await emit({'type': 'ready', 'generation': 1, 'success': true});
        await tester.pump();
        expect(scripts, ['exportSvgToPng();']);
        await emit({'type': 'export', 'data': base64Encode(imageBytes)});
        await tester.pump();
        expect(await result, imageBytes);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        expect(tester.takeException(), isNull);
      },
      variant: const TargetPlatformVariant({TargetPlatform.windows}),
    );
  }

  testWidgets(
    'Windows script errors finish the export without an uncaught future',
    (tester) async {
      final handle = createMermaidView('graph TD; A-->B', false)!;
      await tester.pumpWidget(MaterialApp(home: handle.widget));
      await loadDocument(tester);
      await emit({'type': 'ready', 'generation': 1, 'success': true});
      scriptError = PlatformException(code: 'webview_closed');
      final result = handle.exportPngBytes!();
      await tester.pump();
      expect(await result, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets(
    'disposing a Windows diagram cancels an export waiting for rendering',
    (tester) async {
      final handle = createMermaidView('graph TD; A-->B', false)!;
      await tester.pumpWidget(MaterialApp(home: handle.widget));
      await loadDocument(tester);
      final result = handle.exportPngBytes!();
      await tester.pumpWidget(const SizedBox());
      expect(await result, isNull);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(scripts, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );
}
