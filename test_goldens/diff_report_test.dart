import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'tool/diff_report.dart';

void main() {
  test('pixel difference detects one channel including alpha', () {
    final a = img.Image(width: 2, height: 2, numChannels: 4);
    final b = img.Image.from(a)..setPixelRgba(1, 0, 0, 0, 0, 1);
    final difference = comparePixels(a, b);
    expect(difference.total, 4);
    expect(difference.changed, 1);
    expect(difference.mask.getPixel(1, 0).a, 255);
    expect(difference.mask.getPixel(0, 0).a, 0);
  });

  test('dimension changes count missing pixels over the footprint union', () {
    final a = img.Image(width: 1, height: 2, numChannels: 4);
    final b = img.Image(width: 2, height: 1, numChannels: 4);
    final difference = comparePixels(a, b);
    expect(difference.total, 3);
    expect(difference.changed, 2);
  });

  test('report emits comparison, missing entries and escaped HTML', () {
    final root = Directory.systemTemp.createTempSync('markdown-diff-');
    addTearDown(() => root.deleteSync(recursive: true));
    final before = Directory('${root.path}/before')..createSync();
    final after = Directory('${root.path}/after')..createSync();
    final output = Directory('${root.path}/report');
    final pixel = img.Image(width: 1, height: 1, numChannels: 4);
    const name = '<quoted>.png';
    for (final directory in [before, after]) {
      File('${directory.path}/$name').writeAsBytesSync(img.encodePng(pixel));
    }
    File('${before.path}/missing.png').writeAsBytesSync(img.encodePng(pixel));
    final rows = generateReport(before, after, output);
    expect(rows.map((row) => row['status']), ['equal', 'missing']);
    final html = File('${output.path}/index.html').readAsStringSync();
    expect(html, contains('&lt;quoted&gt;.png'));
    expect(html, isNot(contains('<h2><quoted>')));
    expect(html, contains('%3Cquoted%3E.png'));
    expect(File('${output.path}/report.json').existsSync(), isTrue);
    expect(
      img.decodePng(File('${output.path}/diff_$name').readAsBytesSync()),
      isNotNull,
    );
  });

  test('manifest excludes stale captures and preserves missing files', () {
    final root = Directory.systemTemp.createTempSync('markdown-manifest-');
    addTearDown(() => root.deleteSync(recursive: true));
    final before = Directory('${root.path}/before')..createSync();
    final after = Directory('${root.path}/after')..createSync();
    for (final directory in [before, after]) {
      File('${directory.path}/manifest.json').writeAsStringSync(
        jsonEncode({
          'captures': {'expected': <String, Object>{}},
        }),
      );
      File(
        '${directory.path}/stale.png',
      ).writeAsBytesSync(img.encodePng(img.Image(width: 1, height: 1)));
    }
    final rows = generateReport(
      before,
      after,
      Directory('${root.path}/report'),
    );
    expect(rows, [
      <String, Object?>{'file': 'expected.png', 'status': 'missing'},
    ]);
  });
}
