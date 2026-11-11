import 'dart:convert';

import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_web_document.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;

void main() {
  const header =
      '{"version":1,"title":"Local demo","summary":"Use the control"}';
  const body = '<button onclick="this.textContent=1">0</button>';
  UiWebDocument parse(
    String source, {
    bool closed = true,
    UiGenerationStatus generation = UiGenerationStatus.complete,
  }) => UiWebDocument.parse(source, closed: closed, generation: generation);

  test('only a closed fence plus actual host completion may open', () {
    for (final generation in UiGenerationStatus.values) {
      for (final closed in [false, true]) {
        final document = parse(
          '$header\n$body',
          closed: closed,
          generation: generation,
        );
        expect(document.title, 'Local demo');
        expect(document.summary, 'Use the control');
        expect(document.html, body);
        expect(
          document.canOpen,
          closed && generation == UiGenerationStatus.complete,
        );
      }
    }
  });

  test(
    'metadata only commits at a complete physical first line while streaming',
    () {
      for (var end = 0; end <= header.length; end++) {
        final document = parse(
          header.substring(0, end),
          closed: false,
          generation: UiGenerationStatus.generating,
        );
        expect(document.phase, UiWebPhase.streaming);
        expect(document.hasMetadata, isFalse);
      }
      expect(
        parse(
          '$header\n',
          closed: false,
          generation: UiGenerationStatus.generating,
        ).hasMetadata,
        isTrue,
      );
    },
  );

  for (final invalid in [
    '',
    '[]',
    'null',
    '"string"',
    '1',
    '{',
    '{"version":2,"title":"x","summary":"y"}',
    '{"version":1.0,"title":"x","summary":"y"}',
    '{"version":"1","title":"x","summary":"y"}',
    '{"version":1,"title":null,"summary":"y"}',
    '{"version":1,"title":" ","summary":"y"}',
    '{"version":1,"title":"x","summary":[]}',
    '{"version":1,"title":"x"}',
    '{"version":1,"title":"x","summary":"y","url":"https://example.test"}',
    '$header trailing',
    '\n$header',
    '<!doctype html>',
  ]) {
    test('invalid finite metadata never loads: $invalid', () {
      final document = parse('$invalid\n$body');
      expect(document.phase, UiWebPhase.invalid);
      expect(document.error, UiWebError.metadata);
      expect(document.canOpen, isFalse);
    });
  }

  test('CRLF header and exact body bytes are retained', () {
    final document = parse('$header\r\n$body\r\n');
    expect(document.canOpen, isTrue);
    expect(document.html, '$body\r\n');
    expect(document.source, '$header\r\n$body\r\n');
  });

  test('empty closed document and UTF-8 budget violations remain source', () {
    expect(parse(header).error, UiWebError.emptyDocument);
    expect(parse('$header\n \n').error, UiWebError.emptyDocument);
    final prefix = '$header\n';
    final exact =
        prefix + 'x' * (UiBudgets.sourceBytes - utf8.encode(prefix).length);
    expect(parse(exact).canOpen, isTrue);
    expect(parse('$exact界').error, UiWebError.sourceBudget);
    expect(
      parse(
        '${jsonEncode({'version': 1, 'title': '界' * 171, 'summary': ''})}\n$body',
      ).error,
      UiWebError.metadata,
    );
  });

  for (final generated in [
    body,
    '</iframe><script>parent.attack=true</script><iframe srcdoc="',
    '"\'&<>&quot;&#34;&amp;\n\r\t<script>window.x="</body>"</script>',
    '<meta http-equiv="Content-Security-Policy" content="default-src *">'
        '<iframe srcdoc="<script>parent.escape=true</script>"></iframe>',
    '<base href="file:///private"><img src="https://example.test">',
    '<script>/* emoji 🧪 / CJK 你好 */</script>',
  ]) {
    test('srcdoc stays one encoded attribute: ${generated.length}', () {
      final wrapped = UiWebSandbox.wrap(generated);
      final document = html.parse(wrapped);
      final csp = document.head!.querySelector(
        'meta[http-equiv="Content-Security-Policy"]',
      );
      expect(csp!.attributes['content'], UiWebSandbox.csp);
      expect(document.querySelectorAll('iframe'), hasLength(1));
      final frame = document.querySelector('iframe')!;
      expect(frame.id, UiWebSandbox.frameId);
      expect(frame.attributes['sandbox'], 'allow-scripts');
      // HTML parsers normalize literal CR in attributes to LF.
      expect(
        frame.attributes['srcdoc'],
        generated.replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
      );
      expect(frame.attributes.containsKey('src'), isFalse);
      expect(document.body!.children, [frame]);
      expect(document.querySelectorAll('script'), isEmpty);
      expect(document.querySelectorAll('base'), isEmpty);
      expect(
        wrapped.indexOf('Content-Security-Policy'),
        lessThan(wrapped.indexOf('<iframe')),
      );
    });
  }

  test(
    'CSP has only the planned inline/data allowances and no network sources',
    () {
      final directives = {
        for (final part in UiWebSandbox.csp.split(';'))
          if (part.trim().isNotEmpty)
            part.trim().split(' ').first: part
                .trim()
                .split(' ')
                .skip(1)
                .toList(),
      };
      for (final key in [
        'default-src',
        'connect-src',
        'worker-src',
        'frame-src',
        'object-src',
        'form-action',
        'base-uri',
      ]) {
        expect(directives[key], ["'none'"]);
      }
      expect(directives['script-src'], ["'unsafe-inline'"]);
      expect(directives['style-src'], ["'unsafe-inline'"]);
      expect(directives['img-src'], ['data:']);
      expect(directives['font-src'], ['data:']);
      expect(directives.length, 11);
    },
  );
}
