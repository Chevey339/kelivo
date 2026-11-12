import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Pixels in the union of the image footprints. A resized image never compares
/// equal just because its overlapping region is unchanged.
({int changed, int total, img.Image mask}) comparePixels(
  img.Image before,
  img.Image after,
) {
  final width = math.max(before.width, after.width);
  final height = math.max(before.height, after.height);
  final mask = img.Image(width: width, height: height, numChannels: 4);
  var changed = 0;
  var total = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final inBefore = x < before.width && y < before.height;
      final inAfter = x < after.width && y < after.height;
      if (!inBefore && !inAfter) continue;
      total++;
      var different = inBefore != inAfter;
      if (inBefore && inAfter) {
        final a = before.getPixel(x, y);
        final b = after.getPixel(x, y);
        different = a.r != b.r || a.g != b.g || a.b != b.b || a.a != b.a;
      }
      if (different) {
        changed++;
        mask.setPixelRgba(x, y, 230, 35, 80, 255);
      }
    }
  }
  return (changed: changed, total: total, mask: mask);
}

Map<String, File> _captures(Directory directory) {
  if (!directory.existsSync()) {
    throw FileSystemException(
      'Capture directory does not exist',
      directory.path,
    );
  }
  final manifestFile = File(p.join(directory.path, 'manifest.json'));
  if (manifestFile.existsSync()) {
    final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map;
    final captures = manifest['captures'] as Map;
    return {
      for (final key in captures.keys.cast<String>())
        '$key.png': File(p.join(directory.path, '$key.png')),
    };
  }
  return {
    for (final file in directory.listSync().whereType<File>())
      if (p.extension(file.path).toLowerCase() == '.png')
        p.basename(file.path): file,
  };
}

/// Generates a local report without treating intentional visual changes as a
/// test failure. Missing PNGs are explicit report entries, not silently skipped.
List<Map<String, Object?>> generateReport(
  Directory baseline,
  Directory current,
  Directory output,
) {
  final before = _captures(baseline);
  final after = _captures(current);
  final names = {...before.keys, ...after.keys}.toList()..sort();
  if (names.isEmpty) throw StateError('No PNG captures to compare');
  output.createSync(recursive: true);
  final rows = <Map<String, Object?>>[];
  final sections = StringBuffer();
  String escape(String value) => const HtmlEscape().convert(value);
  String preview(File? file, String label) {
    if (file == null || !file.existsSync()) return '<p>Missing $label</p>';
    final relative = p.relative(file.absolute.path, from: output.absolute.path);
    final url = Uri(pathSegments: p.split(relative)).toString();
    return '<figure><figcaption>$label</figcaption>'
        '<img loading="lazy" src="${escape(url)}" alt="$label"></figure>';
  }

  for (final name in names) {
    final aFile = before[name];
    final bFile = after[name];
    final missing =
        aFile == null ||
        bFile == null ||
        !aFile.existsSync() ||
        !bFile.existsSync();
    final row = <String, Object?>{'file': name};
    File? maskFile;
    if (missing) {
      row['status'] = 'missing';
    } else {
      final a = img.decodePng(aFile.readAsBytesSync());
      final b = img.decodePng(bFile.readAsBytesSync());
      if (a == null || b == null) throw FormatException('Invalid PNG: $name');
      final difference = comparePixels(a, b);
      row.addAll({
        'status': difference.changed == 0 ? 'equal' : 'changed',
        'changedPixels': difference.changed,
        'totalPixels': difference.total,
        'differenceRatio': difference.changed / difference.total,
        'baselineSize': [a.width, a.height],
        'currentSize': [b.width, b.height],
      });
      maskFile = File(p.join(output.path, 'diff_$name'));
      maskFile.writeAsBytesSync(img.encodePng(difference.mask));
    }
    rows.add(row);
    final ratio = row['differenceRatio'] as double?;
    sections.write(
      '<section data-status="${row['status']}">'
      '<h2>${escape(name)}</h2><p>${row['status']}'
      '${ratio == null ? '' : ' — ${(ratio * 100).toStringAsFixed(4)}% pixels'}'
      '</p><div class="images">${preview(aFile, 'Baseline')}'
      '${preview(bFile, 'Current')}${preview(maskFile, 'Difference')}</div>'
      '</section>',
    );
  }
  final changed = rows.where((row) => row['status'] == 'changed').length;
  final missing = rows.where((row) => row['status'] == 'missing').length;
  File(
    p.join(output.path, 'report.json'),
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
  File(p.join(output.path, 'index.html')).writeAsStringSync('''<!doctype html>
<html lang="en"><meta charset="utf-8"><title>Markdown visual comparison</title>
<style>
body{font:14px system-ui;margin:24px;background:#f3f4f6;color:#18212b}
h1{font-size:24px}h2{font:15px monospace}section{background:white;padding:16px;margin:20px 0;border-radius:8px}
.images{display:flex;gap:16px;align-items:flex-start;overflow:auto}figure{margin:0;flex:none}
figcaption{margin-bottom:8px}img{max-width:720px;border:1px solid #aaa;background:#ddd}
</style><h1>Markdown visual comparison</h1>
<p>${rows.length} captures; $changed changed; $missing missing.
Differences are exact RGBA pixel comparisons over the union of both images.</p>
<label><input type="checkbox" id="changes"> Show changed or missing only</label>
$sections
<script>document.querySelector('#changes').onchange=function(){
document.querySelectorAll('section').forEach(s=>s.hidden=this.checked&&s.dataset.status==='equal');};</script>
</html>''');
  return rows;
}

void main(List<String> arguments) {
  if (arguments.length != 3) {
    stderr.writeln(
      'Usage: dart run test_goldens/tool/diff_report.dart '
      '<baseline-directory> <current-directory> <report-directory>',
    );
    exitCode = 64;
    return;
  }
  try {
    final rows = generateReport(
      Directory(arguments[0]),
      Directory(arguments[1]),
      Directory(arguments[2]),
    );
    stdout.writeln(
      '${rows.length} captures compared: '
      '${p.join(arguments[2], 'index.html')}',
    );
    if (rows.any((row) => row['status'] == 'missing')) exitCode = 2;
  } on FileSystemException catch (error) {
    stderr.writeln(error);
    exitCode = 2;
  } on FormatException catch (error) {
    stderr.writeln(error);
    exitCode = 2;
  } on StateError catch (error) {
    stderr.writeln(error);
    exitCode = 2;
  }
}
