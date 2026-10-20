import 'dart:convert';
import 'dart:typed_data';

import 'package:Kelivo/core/services/browser/browser_engine.dart';
import 'package:Kelivo/core/services/browser/browser_favicon_loader.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/features/browser/widgets/browser_favicon.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'browser_service_test.dart' show FakeBrowserEngine;

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';

class _Store extends BrowserStore {
  Map<String, Object?> data = {};
  @override
  Future<Map<String, dynamic>> read() async => Map<String, dynamic>.from(data);
  @override
  Future<void> write(Map<String, Object?> state) async => data = state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Store store;
  late BrowserService service;
  late FakeBrowserEngine engine;
  setUp(() {
    store = _Store();
    service = BrowserService(
      store: store,
      supported: true,
      engineFactory:
          ({
            required tab,
            required settings,
            required onChanged,
            required onDownload,
            required onNewWindow,
            required isAgentActive,
          }) async {
            return engine = FakeBrowserEngine(tab, onChanged);
          },
    );
  });
  tearDown(() => service.dispose());

  Future<String> open(String url) async {
    final tab = await service.createTab(url: url);
    await service.evaluateJavascript('1', tabId: tab.id);
    return tab.id;
  }

  void icon(String url, [Uint8List? bytes]) => engine.onChanged(
    BrowserPageState(favicon: bytes ?? base64Decode(_png), faviconPageUrl: url),
  );

  test('favicons persist locally and share only the same web origin', () async {
    const page = 'https://site.example/page#section';
    await open(page);
    icon('https://site.example/page');
    expect(
      service.faviconForUrl('https://site.example/bookmark'),
      base64Decode(_png),
    );
    expect(service.faviconForUrl('http://site.example'), isNull);
    expect(service.faviconForUrl('https://site.example:444'), isNull);
    expect(service.faviconForUrl('https://other.example'), isNull);
    await service.flush();
    final restored = BrowserService(store: store, supported: false);
    try {
      await restored.initialize();
      expect(restored.faviconForUrl(page), base64Decode(_png));
    } finally {
      restored.dispose();
    }
  });

  test(
    'new navigation rejects icons from the old URL or while loading',
    () async {
      final tab = await open('https://old.example');
      await service.navigate('https://new.example', tabId: tab);
      icon('https://old.example');
      icon('https://new.example');
      expect(service.faviconForUrl('https://old.example'), isNull);
      expect(service.faviconForUrl('https://new.example'), isNull);
      engine.onChanged(const BrowserPageState(isLoading: false));
      icon('https://old.example');
      expect(service.faviconForUrl('https://old.example'), isNull);
      icon('https://new.example');
      expect(service.faviconForUrl('https://new.example'), isNotNull);
    },
  );

  test(
    'cache is bounded and malformed or oversized image payloads are refused',
    () async {
      final tab = await open('https://site0.example');
      for (var i = 0; i < browserFaviconMaxSites + 4; i++) {
        final url = 'https://site$i.example';
        await service.navigate(url, tabId: tab);
        engine.onChanged(
          const BrowserPageState(isLoading: false, completedNavigation: true),
        );
        icon(url);
      }
      await service.flush();
      expect((store.data['favicons'] as List).length, browserFaviconMaxSites);
      expect(service.faviconForUrl('https://site0.example'), isNull);
      expect(service.faviconForUrl('https://site51.example'), isNotNull);
      expect(decodeBrowserFavicon('invalid base64'), isNull);
      expect(isBrowserFavicon(Uint8List(browserFaviconMaxBytes + 1)), isFalse);
      final giant = base64Decode(_png);
      ByteData.sublistView(giant).setUint32(16, 100000);
      expect(isBrowserFavicon(giant), isFalse);
      expect(browserFaviconSite('https://user:secret@site.example'), isNull);
      expect(browserFaviconSite('data:image/png;base64,AAAA'), isNull);
    },
  );

  test(
    'icon persistence does not retain an otherwise unsaved browsing origin',
    () async {
      await service.initialize();
      await service.updateSettings(
        const BrowserSettings(saveHistory: false, restoreTabs: false),
      );
      const url = 'https://private.example/page';
      await open(url);
      icon(url);
      expect(service.faviconForUrl(url), isNotNull);
      await service.flush();
      expect(store.data['favicons'], isEmpty);
      await service.addBookmark(url: url, title: 'Saved');
      expect((store.data['favicons'] as List).length, 1);
      await service.removeBookmark(url);
      expect(store.data['favicons'], isEmpty);
    },
  );

  test(
    'document matching removes a hash without introducing an empty hash suffix',
    () {
      expect(
        browserFaviconDocument('https://site.example/path#one'),
        'https://site.example/path',
      );
      expect(
        browserFaviconDocument('https://site.example/path'),
        'https://site.example/path',
      );
    },
  );

  testWidgets(
    'favicon changes from local glyph to decoded image without requests',
    (tester) async {
      try {
        const page = 'https://site.example';
        await open(page);
        await tester.pumpWidget(
          MaterialApp(
            home: BrowserFavicon(url: page, service: service, size: 24),
          ),
        );
        expect(find.byIcon(LucideIcons.globe), findsOneWidget);
        icon(page);
        await tester.pump();
        expect(find.byType(Image), findsOneWidget);
        final image = tester.widget<Image>(find.byType(Image));
        await tester.runAsync(
          () => precacheImage(image.image, tester.element(find.byType(Image))),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(LucideIcons.globe), findsNothing);
        final frame = tester.widget<RawImage>(find.byType(RawImage)).image;
        expect(frame, isNotNull);
        expect(frame!.width, 1);
        expect(frame.height, 1);
        final pixels = await tester.runAsync(frame.toByteData);
        expect(pixels!.buffer.asUint8List(), [255, 0, 0, 255]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          MaterialApp(
            home: BrowserFavicon(url: 'about:blank', service: service),
          ),
        );
        expect(find.byType(Image), findsNothing);
        expect(find.byIcon(LucideIcons.compass), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        // Widget-test invariants run before package:test tearDown. Retire the
        // service's idle/save timers while still inside the test's fake clock.
        service.dispose();
      }
    },
  );

  testWidgets('corrupt cached image uses the local fallback without throwing', (
    tester,
  ) async {
    const page = 'https://broken.example';
    store.data = {
      'favicons': [
        {'site': page, 'png': base64Encode(base64Decode(_png).sublist(0, 24))},
      ],
    };
    await service.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: BrowserFavicon(url: page, service: service),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    var failed = false;
    await tester.runAsync(
      () => precacheImage(
        image.image,
        tester.element(find.byType(Image)),
        onError: (_, __) => failed = true,
      ),
    );
    await tester.pumpAndSettle();
    expect(failed, isTrue);
    expect(find.byIcon(LucideIcons.globe), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
