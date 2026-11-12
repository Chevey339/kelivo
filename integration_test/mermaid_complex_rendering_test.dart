import 'dart:io';

import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/diagram_code_blocks.dart';
import 'package:Kelivo/shared/widgets/mermaid_image_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:markstream/markstream.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/issue_1322_complex_mermaid.dart';

String _caseName = '';

class _DiagnosticWebViewPlatform extends AndroidWebViewPlatform {
  @override
  AndroidWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _DiagnosticController(params, _caseName);
}

class _DiagnosticController extends AndroidWebViewController {
  _DiagnosticController(super.params, this.label) {
    setOnConsoleMessage((message) {
      debugPrint('MERMAID_PROBE [$label] ${message.message}');
    });
  }

  final String label;

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    html = html.replaceFirst(
      'mermaid.run({',
      "console.log(navigator.userAgent); mermaid.run({",
    );
    html = html.replaceFirst(
      '}).catch(function(){\n          postHeight();',
      "}).catch(function(error){\n console.error(error.stack || String(error));\n postHeight();",
    );
    await super.loadHtmlString(html, baseUrl: baseUrl);
  }
}

Widget _host(Iterable<String> codes) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        child: MarkstreamView(
          cullToViewport: false,
          source: codes.map((code) => '```mermaid\n$code\n```').join('\n\n'),
          extensions: MarkstreamExtensions(
            codeBlockBuilders: {
              'mermaid': (context, node, rendering) => KelivoDiagramBlock(
                key: ValueKey(node.code),
                node: node,
                theme: rendering.theme,
                streaming: false,
              ),
            },
          ),
        ),
      ),
    ),
  ),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final cases = {
    for (final entry in complexMermaidExamples.entries)
      entry.key: [entry.value],
    'all twelve in one message': complexMermaidExamples.values.toList(),
  };
  for (final entry in cases.entries) {
    testWidgets('complex Mermaid ${entry.key}', (tester) async {
      _caseName = entry.key;
      final original = WebViewPlatform.instance;
      WebViewPlatform.instance = _DiagnosticWebViewPlatform();
      addTearDown(() => WebViewPlatform.instance = original);
      MermaidImageCache.clear();
      addTearDown(MermaidImageCache.clear);
      final timer = Stopwatch()..start();
      debugPrint('MERMAID_PROBE start ${entry.key}');
      await tester.pumpWidget(_host(entry.value));
      final error = find.byKey(const ValueKey('mermaid-error-body'));
      while (timer.elapsed < const Duration(seconds: 45) &&
          find.byType(Image).evaluate().length < entry.value.length &&
          error.evaluate().isEmpty) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      debugPrint(
        'MERMAID_PROBE end ${entry.key}: images=${find.byType(Image).evaluate().length} '
        'errors=${error.evaluate().length} ms=${timer.elapsedMilliseconds}',
      );
      expect(error, findsNothing);
      expect(find.byType(Image), findsNWidgets(entry.value.length));
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        final bytes = (image.image as MemoryImage).bytes;
        expect(bytes.length, greaterThan(100));
        final header = bytes.buffer.asByteData(bytes.offsetInBytes);
        final width = header.getUint32(16);
        final height = header.getUint32(20);
        debugPrint('MERMAID_PROBE PNG ${entry.key} ${width}x$height');
        expect(width, lessThanOrEqualTo(4096));
        expect(height, lessThanOrEqualTo(4096));
        expect(width * height, lessThanOrEqualTo(4 * 1024 * 1024));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
    }, skip: !Platform.isAndroid);
  }
}
