import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/diagram_code_blocks.dart';
import 'package:Kelivo/shared/widgets/mermaid_image_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

const _first = 'graph TD\nA-->B';
const _second = 'graph TD\nC-->D';
const _replacement = 'graph TD\nE-->F';

MermaidBitmapRenderResult _image() => MermaidBitmapRenderResult.success(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  ),
);

Widget _host(List<String> codes, {bool streaming = false}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SingleChildScrollView(
      child: MarkstreamView(
        cullToViewport: false,
        source: codes.map((code) => '```mermaid\n$code\n```').join('\n\n'),
        extensions: MarkstreamExtensions(
          codeBlockBuilders: {
            'mermaid': (context, node, rendering) => KelivoDiagramBlock(
              node: node,
              theme: rendering.theme,
              streaming: streaming,
            ),
          },
        ),
      ),
    ),
  ),
);

void main() {
  setUp(MermaidImageCache.clear);
  tearDown(() {
    debugMermaidBitmapRenderOverride = null;
    MermaidImageCache.clear();
  });

  testWidgets(
    'serializes previews, releases failures and reuses queued duplicates',
    (tester) async {
      final first = Completer<MermaidBitmapRenderResult>();
      final second = Completer<MermaidBitmapRenderResult>();
      final started = <String>[];
      var active = 0;
      var peak = 0;
      debugMermaidBitmapRenderOverride = (code, _, __) {
        code = code.trim();
        started.add(code);
        active++;
        if (active > peak) peak = active;
        return (code == _first ? first : second).future.whenComplete(
          () => active--,
        );
      };
      try {
        await tester.pumpWidget(_host([_first, _second, _second]));
        await tester.pump(const Duration(milliseconds: 240));
        expect(started, [_first]);
        first.completeError(StateError('render failure'));
        await tester.pump();
        expect(started, [_first, _second]);
        second.complete(_image());
        await tester.pump();
        await tester.pump();
        expect(started, [_first, _second]);
        expect(peak, 1);
        expect(find.byType(Image), findsNWidgets(2));
        expect(
          find.byKey(const ValueKey('mermaid-error-body')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        if (!first.isCompleted) {
          first.complete(MermaidBitmapRenderResult.failed());
        }
        if (!second.isCompleted) {
          second.complete(MermaidBitmapRenderResult.failed());
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  testWidgets('discarded queued previews do not start a native renderer', (
    tester,
  ) async {
    final first = Completer<MermaidBitmapRenderResult>();
    final started = <String>[];
    debugMermaidBitmapRenderOverride = (code, _, __) {
      started.add(code.trim());
      return first.future;
    };
    try {
      await tester.pumpWidget(_host([_first, _second]));
      await tester.pump(const Duration(milliseconds: 240));
      expect(started, [_first]);
      await tester.pumpWidget(const SizedBox.shrink());
      first.complete(_image());
      await tester.pump();
      expect(started, [_first]);
      expect(tester.takeException(), isNull);
    } finally {
      if (!first.isCompleted) {
        first.complete(MermaidBitmapRenderResult.failed());
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets(
    'queued source changes discard stale work and render the new code',
    (tester) async {
      final first = Completer<MermaidBitmapRenderResult>();
      final started = <String>[];
      debugMermaidBitmapRenderOverride = (code, _, __) {
        code = code.trim();
        started.add(code);
        return code == _first ? first.future : Future.value(_image());
      };
      try {
        await tester.pumpWidget(_host([_first, _second]));
        await tester.pump(const Duration(milliseconds: 240));
        await tester.pumpWidget(_host([_first, _replacement]));
        await tester.pump(const Duration(milliseconds: 240));
        expect(started, [_first]);
        first.complete(_image());
        await tester.pump();
        await tester.pump();
        expect(started, [_first, _replacement]);
        expect(find.byType(Image), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      } finally {
        if (!first.isCompleted) {
          first.complete(MermaidBitmapRenderResult.failed());
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  testWidgets('finishing a stream keeps its replacement render pending', (
    tester,
  ) async {
    final first = Completer<MermaidBitmapRenderResult>();
    final second = Completer<MermaidBitmapRenderResult>();
    var calls = 0;
    debugMermaidBitmapRenderOverride = (_, __, ___) {
      return ++calls == 1 ? first.future : second.future;
    };
    try {
      await tester.pumpWidget(_host([_first], streaming: true));
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 1);
      // Completing the stream cancels its live WebView and queues a final
      // render with the same code/cache key. The cancelled job can finish later.
      await tester.pumpWidget(_host([_first]));
      await tester.pump(const Duration(milliseconds: 240));
      first.complete(MermaidBitmapRenderResult.failed());
      await tester.pump();
      expect(calls, 2);
      expect(find.byKey(const ValueKey('mermaid-error-body')), findsNothing);
      second.complete(_image());
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      if (!first.isCompleted) {
        first.complete(MermaidBitmapRenderResult.failed());
      }
      if (!second.isCompleted) {
        second.complete(MermaidBitmapRenderResult.failed());
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
