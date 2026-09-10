import 'dart:convert';

import 'package:Kelivo/utils/svg_preview_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('many XML preamble events are scanned without backtracking', () {
    final comments = '<!-- x -->' * 26;
    final processing = '<?step next?>' * 26;
    final watch = Stopwatch()..start();
    for (final preamble in [comments, processing]) {
      expect(isSvgCodeBlock('xml', '$preamble<config/>'), isFalse);
      expect(isSvgCodeBlock('xml', '$preamble<svg/>'), isTrue);
      expect(isSvgCodeBlock('xml', preamble), isFalse);
    }
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('root detection stops before an incomplete SVG body', () {
    expect(isSvgCodeBlock('xml', '<svg><path d="'), isTrue);
    expect(isSvgCodeBlock('xml', '<config><svg/>'), isFalse);
    expect(isSvgCodeBlock('xml', '<!-- unfinished'), isFalse);
    expect(isSvgCodeBlock('xml', '<?xml version="1.0"'), isFalse);
    expect(isSvgCodeBlock('xml', 'not XML <svg/>'), isFalse);
  });

  test('XML preamble may contain a doctype internal subset', () {
    expect(
      isSvgCodeBlock(
        'xml',
        '<?xml version="1.0"?><!DOCTYPE svg [<!ENTITY label "diagram">]><svg/>',
      ),
      isTrue,
    );
  });

  test('SVG fences and XML SVG documents use inline diagrams', () {
    expect(isSvgCodeBlock('SVG', '<svg'), isTrue);
    expect(isSvgCodeBlock(' xml ', '<svg viewBox="0 0 10 10">'), isTrue);
    expect(
      isSvgCodeBlock('xml', '<?xml version="1.0"?>\n<!-- diagram -->\n<svg/>'),
      isTrue,
    );
    expect(
      isSvgCodeBlock('xml', '<s:svg xmlns:s="http://www.w3.org/2000/svg"/>'),
      isTrue,
    );
    expect(isSvgCodeBlock('xml', '<config><svg/></config>'), isFalse);
    expect(isSvgCodeBlock('xml', '<svgConfig/>'), isFalse);
    expect(isSvgCodeBlock('html', '<svg/>'), isFalse);
  });

  test('SVG image preserves text, gradients and namespace', () {
    const source =
        '<?xml version="1.0"?><svg viewBox="0 0 240 140">'
        '<defs><linearGradient id="bg"><stop stop-color="#123456"/></linearGradient></defs>'
        '<rect width="240" height="140" fill="url(#bg)"/>'
        '<text x="20" y="30">你好</text></svg>';
    final uri = Uri.parse(svgPreviewDataUri(source)!);
    final root = XmlDocument.parse(
      utf8.decode(uri.data!.contentAsBytes()),
    ).rootElement;
    expect(root.namespaceUri, 'http://www.w3.org/2000/svg');
    expect(root.getAttribute('viewBox'), '0 0 240 140');
    expect(root.getElement('text')!.innerText, '你好');
    expect(root.getElement('rect')!.getAttribute('fill'), 'url(#bg)');
  });

  test('prefixed SVG remains valid', () {
    final uri = svgPreviewDataUri(
      '<s:svg xmlns:s="http://www.w3.org/2000/svg"><s:rect/></s:svg>',
    )!;
    final root = XmlDocument.parse(
      utf8.decode(Uri.parse(uri).data!.contentAsBytes()),
    ).rootElement;
    expect(root.name.qualified, 's:svg');
    expect(root.namespaceUri, 'http://www.w3.org/2000/svg');
  });

  test('invalid, incomplete and non-SVG XML cannot be rasterized', () {
    for (final source in [
      '',
      '<svg><path',
      '<config/>',
      '<svg xmlns="urn:config"/>',
    ]) {
      expect(svgPreviewDataUri(source), isNull);
      expect(() => buildSvgPreviewHtml(source), returnsNormally);
    }
  });

  test('SVG content is isolated in an image data URI', () {
    const source =
        '<svg><script>alert("untrusted")</script><text>中文</text></svg>';
    final html = buildSvgPreviewHtml(source);
    expect(html, contains(svgPreviewDataUri(source)!));
    expect(html, isNot(contains('alert("untrusted")')));
    expect(html, isNot(contains('<svg>')));
  });
}
