import 'dart:io';
import 'dart:ui' as ui;

import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/diagram_code_blocks.dart';
import 'package:Kelivo/shared/widgets/mermaid_image_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:markstream/markstream.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class _SlowAndroidWebViewPlatform extends AndroidWebViewPlatform {
  @override
  AndroidWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _SlowAndroidWebViewController(params);
}

class _SlowAndroidWebViewController extends AndroidWebViewController {
  _SlowAndroidWebViewController(super.params);

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    // Exercise slow cold initialization without replacing the native renderer.
    await Future<void>.delayed(const Duration(seconds: 5));
    await super.loadHtmlString(html, baseUrl: baseUrl);
  }
}

const _examples = {
  'flowchart': '''graph TD
    A([Start]) --> B{Decision?}
    B -->|Yes| C[Take Action]
    B -->|No| D[Do Nothing]
    C --> E([End])
    D --> E''',
  'subgraphs': '''graph LR
    subgraph cluster_A
        a1[A]
        a2[B]
    end
    subgraph cluster_B
        b1[C]
        b2[D]
    end
    a1 --> b1
    a2 --> b2''',
  'sequence': '''sequenceDiagram
    participant Alice
    participant Bob
    Alice->>Bob: Hello Bob
    Bob-->>Alice: Hi Alice
    Alice->>Bob: How are you?
    Bob-->>Alice: Great!''',
};

Widget _host(List<String> codes, {String language = 'mermaid'}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        child: MarkstreamView(
          cullToViewport: false,
          source: codes.map((code) => '```$language\n$code\n```').join('\n\n'),
          extensions: MarkstreamExtensions(
            codeBlockBuilders: {
              language: (context, node, rendering) => KelivoDiagramBlock(
                node: node,
                theme: rendering.theme,
                streaming: false,
                isSvg: language == 'svg',
              ),
            },
          ),
        ),
      ),
    ),
  ),
);

Future<void> _expectDiagramPixels(WidgetTester tester, Image widget) async {
  final provider = widget.image as MemoryImage;
  final ink = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(
      provider.bytes,
      targetWidth: 320,
    );
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        expect(image.width, greaterThan(32));
        expect(image.height, greaterThan(32));
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var contrasting = 0;
        for (var i = 0; i < pixels.lengthInBytes; i += 4) {
          final difference =
              (pixels.getUint8(i) - pixels.getUint8(0)).abs() +
              (pixels.getUint8(i + 1) - pixels.getUint8(1)).abs() +
              (pixels.getUint8(i + 2) - pixels.getUint8(2)).abs();
          if (difference > 24) contrasting++;
        }
        return contrasting;
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  });
  expect(
    ink,
    greaterThan(100),
    reason: 'The exported PNG must contain a diagram',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final cases = {
    for (final example in _examples.entries) example.key: [example.value],
    'all three in one message': _examples.values.toList(),
    if (Platform.isAndroid) 'slow initialization': _examples.values.toList(),
  };
  for (final example in cases.entries) {
    testWidgets(
      'Mermaid renders issue 1322 ${example.key} through the native WebView',
      (tester) async {
        if (example.key == 'slow initialization') {
          final original = WebViewPlatform.instance;
          WebViewPlatform.instance = _SlowAndroidWebViewPlatform();
          addTearDown(() => WebViewPlatform.instance = original);
        }
        MermaidImageCache.clear();
        addTearDown(MermaidImageCache.clear);
        await tester.pumpWidget(_host(example.value));
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        final error = find.byKey(const ValueKey('mermaid-error-body'));
        while (DateTime.now().isBefore(deadline) &&
            find.byType(Image).evaluate().length < example.value.length &&
            error.evaluate().isEmpty) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(error, findsNothing);
        expect(find.byType(Image), findsNWidgets(example.value.length));
        for (final image in tester.widgetList<Image>(find.byType(Image))) {
          await _expectDiagramPixels(tester, image);
        }
        expect(tester.takeException(), isNull);
      },
      skip: !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS),
    );
  }
  testWidgets('invalid Mermaid reports failure without waiting for a PNG', (
    tester,
  ) async {
    MermaidImageCache.clear();
    await tester.pumpWidget(_host(['graph TD\nA --> B[']));
    final error = find.byKey(const ValueKey('mermaid-error-body'));
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (DateTime.now().isBefore(deadline) && error.evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(error, findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS));

  testWidgets('SVG export still paints through the shared native bridge', (
    tester,
  ) async {
    MermaidImageCache.clear();
    addTearDown(MermaidImageCache.clear);
    await tester.pumpWidget(
      _host([
        '<svg xmlns="http://www.w3.org/2000/svg" width="160" height="100">'
            '<rect x="10" y="10" width="140" height="80" fill="#3267ab" />'
            '</svg>',
      ], language: 'svg'),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline) &&
        find.byType(Image).evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(Image), findsOneWidget);
    await _expectDiagramPixels(
      tester,
      tester.widget<Image>(find.byType(Image)),
    );
    expect(tester.takeException(), isNull);
  }, skip: !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS));
}
