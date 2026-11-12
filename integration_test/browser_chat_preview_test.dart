import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:window_manager/window_manager.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';

// Uses only a temporary browser store and local HTML, never user conversations.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('chat snapshots work before and after native view presentation', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp('chat-preview-');
    final browser = BrowserService(store: BrowserStore(directory: directory));
    VoidCallback? release;
    final results = <Map<String, Object?>>[];
    try {
      if (Platform.isMacOS) {
        // This isolated entrypoint does not run main.dart's window bootstrap.
        await windowManager.ensureInitialized();
        await windowManager.show();
        await windowManager.focus();
      }
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Chat preview probe'))),
      );
      await tester.pumpAndSettle();
      await browser.initialize();
      final tab = await browser.createTab(ownerSessionId: 'preview-probe');
      release = browser.watchTabPreview(tab.id);
      expect(browser.liveViewCount, 0);

      Future<void> render(String color) => browser.runAgentAction<void>(
        sessionId: 'preview-probe',
        label: 'render',
        tabId: tab.id,
        action: () async {
          await browser.loadHtml(
            '<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">'
            '<style>html,body{margin:0;background:$color}header{height:120px;background:#123456}</style>'
            '<header></header><h1>Local preview</h1>',
            tabId: tab.id,
          );
          await browser.waitForLoad(tabId: tab.id);
        },
      );
      Future<Uint8List> preview(String state) async {
        final clock = Stopwatch()..start();
        while (browser.previewForTab(tab.id) == null) {
          if (clock.elapsed > const Duration(seconds: 10)) {
            fail('$state thumbnail missing');
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        final bytes = browser.previewForTab(tab.id)!;
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        codec.dispose();
        final image = frame.image;
        try {
          expect(image.width, inInclusiveRange(430, 440));
          expect(image.height, greaterThan(100));
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final top = pixels.getUint32((10 * image.width + 10) * 4);
          final middle = pixels.getUint32(
            ((image.height ~/ 2) * image.width + 10) * 4,
          );
          expect(
            top,
            isNot(middle),
            reason: 'A real page, not an empty/solid snapshot',
          );
          results.add({
            'state': state,
            'width': image.width,
            'height': image.height,
            'bytes': bytes.length,
          });
        } finally {
          image.dispose();
        }
        return bytes;
      }

      await render('#e8c04a');
      final headless = await preview('headless');
      expect(browser.liveViewCount, 1);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: browser.buildView(tab.id))),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Back in chat'))),
      );
      await tester.pumpAndSettle();
      expect(browser.isTabPresented(tab.id), isFalse);
      await render('#62c59b');
      final detached = await preview('detached');
      expect(identical(headless, detached), isFalse);
      binding.reportData = {'chatPreview': results};
    } finally {
      release?.call();
      await tester.pumpWidget(const SizedBox.shrink());
      browser.dispose();
      await directory.delete(recursive: true);
    }
  });
}
