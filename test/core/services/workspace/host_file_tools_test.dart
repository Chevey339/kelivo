import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/workspace/host_file_tools.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';

void main() {
  late Directory tmp;
  late HostFileTools tools;
  late String cwd;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kelivo_host_tools_');
    final workspace = Directory(p.join(tmp.path, 'ws'))..createSync();
    final session = Directory(p.join(tmp.path, 'session'))..createSync();
    final skills = Directory(p.join(tmp.path, 'skills'))..createSync();
    cwd = workspace.path;
    tools = HostFileTools(
      WorkspacePaths.native(
        workspaceHostRoot: workspace.path,
        sessionHostDir: session.path,
        skillsHostDir: skills.path,
      ),
    );
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test(
    'readFile numbers lines and reports next_offset past the 32 KB cap',
    () async {
      final lines = <String>[
        for (var i = 1; i <= 80; i++)
          'L${i.toString().padLeft(3, '0')} ${'x' * 500}',
      ];
      File(p.join(cwd, 'big.txt')).writeAsStringSync(lines.join('\n'));

      final page1 = await tools.readFile('big.txt', cwd: cwd);
      expect(page1.text, isNotNull);
      expect(page1.text!, startsWith('     1|'));
      expect(page1.nextOffset, isNotNull);
      expect(page1.nextOffset, greaterThan(1));

      final page2 = await tools.readFile(
        'big.txt',
        offset: page1.nextOffset,
        cwd: cwd,
      );
      expect(page2.text, isNotNull);
      expect(page2.text!, startsWith(page1.nextOffset.toString().padLeft(6)));
    },
  );

  test(
    'oversized UTF-8 lines stay bounded and explicitly mark truncation',
    () async {
      File(
        p.join(cwd, 'minified.txt'),
      ).writeAsStringSync('${'😀中' * 20000}\r\nnext\rlast\n');
      final first = await tools.readFile('minified.txt', cwd: cwd);
      expect(
        utf8.encode(first.text!).length,
        lessThanOrEqualTo(HostFileTools.readCapBytes),
      );
      expect(first.text, contains('[line truncated]'));
      expect(first.text, isNot(contains('�')));
      expect(first.nextOffset, 2);
      final rest = await tools.readFile('minified.txt', cwd: cwd, offset: 2);
      expect(rest.text, '     2|next\n     3|last\n');
      expect(rest.nextOffset, isNull);
    },
  );

  test('readFile offset/limit slices lines', () async {
    File(p.join(cwd, 'n.txt')).writeAsStringSync('a\nb\nc\nd\n');
    final result = await tools.readFile('n.txt', offset: 2, limit: 2, cwd: cwd);
    expect(result.text, '     2|b\n     3|c\n');
    expect(result.nextOffset, 4);
  });

  test('readFile detects binary via NUL and returns a hex preview', () async {
    File(
      p.join(cwd, 'blob.bin'),
    ).writeAsBytesSync(Uint8List.fromList([0x00, 0x01, 0x02, 0xFF]));
    final result = await tools.readFile('blob.bin', cwd: cwd);
    expect(result.binary, isTrue);
    expect(result.hexPreview, '00 01 02 ff');
    expect(result.text, isNull);
  });

  test('readFile returns image bytes for image extensions', () async {
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);
    File(p.join(cwd, 'pic.png')).writeAsBytesSync(png);
    final result = await tools.readFile('pic.png', cwd: cwd);
    expect(result.imageBytes, png);
    expect(result.imageMime, 'image/png');
  });

  test('writeFile creates parent directories', () async {
    final result = await tools.writeFile(
      'nested/dir/file.txt',
      'hello',
      cwd: cwd,
    );
    expect(result.created, isTrue);
    expect(result.bytes, 5);
    expect(
      File(p.join(cwd, 'nested', 'dir', 'file.txt')).readAsStringSync(),
      'hello',
    );
    final again = await tools.writeFile(
      'nested/dir/file.txt',
      'world',
      cwd: cwd,
    );
    expect(again.created, isFalse);
  });

  test('editFile applies a replacement and returns a unified diff', () async {
    File(p.join(cwd, 'edit.txt')).writeAsStringSync('hello world\n');
    final result = await tools.editFile('edit.txt', 'world', 'there', cwd: cwd);
    expect(result.replacements, 1);
    expect(result.strategy, 'exact');
    expect(result.updated, 'hello there\n');
    expect(result.diff.added, 1);
    expect(result.diff.removed, 1);
    expect(result.diff.text, contains('-hello world'));
    expect(result.diff.text, contains('+hello there'));
    expect(File(p.join(cwd, 'edit.txt')).readAsStringSync(), 'hello there\n');
  });

  test('listDir puts directories first and caps at 500', () async {
    Directory(p.join(cwd, 'zdir')).createSync();
    File(p.join(cwd, 'a.txt')).writeAsStringSync('x');
    File(p.join(cwd, '.l2s.skip')).writeAsStringSync('nope');
    final listed = await tools.listDir('.', cwd: cwd);
    expect(listed.entries.first.isDirectory, isTrue);
    expect(listed.entries.first.name, 'zdir');
    expect(listed.entries.any((e) => e.name.startsWith('.l2s.')), isFalse);
    expect(listed.entries.any((e) => e.name == 'a.txt'), isTrue);

    for (var i = 0; i < 510; i++) {
      File(p.join(cwd, 'f$i.txt')).writeAsStringSync('x');
    }
    final capped = await tools.listDir('.', cwd: cwd);
    expect(capped.entries.length, 500);
    expect(capped.truncated, isTrue);
  });

  test('glob matches and caps at 500, skipping dot-directories', () async {
    Directory(p.join(cwd, 'src')).createSync();
    Directory(p.join(cwd, '.hidden')).createSync();
    File(p.join(cwd, 'src', 'a.dart')).writeAsStringSync('a');
    File(p.join(cwd, '.hidden', 'b.dart')).writeAsStringSync('b');
    File(p.join(cwd, '.l2s.meta')).writeAsStringSync('m');

    final found = await tools.glob('**/*.dart', cwd: cwd);
    expect(found.paths.length, 1);
    expect(found.paths.single, endsWith('src/a.dart'));

    for (var i = 0; i < 510; i++) {
      File(p.join(cwd, 'g$i.dart')).writeAsStringSync('x');
    }
    final capped = await tools.glob('*.dart', cwd: cwd);
    expect(capped.paths.length, 500);
    expect(capped.truncated, isTrue);
  });

  test('grep returns path:line: text and respects the limit', () async {
    File(
      p.join(cwd, 'hit.txt'),
    ).writeAsStringSync('alpha\nbeta\nalpha again\n');
    Directory(p.join(cwd, '.skip')).createSync();
    File(p.join(cwd, '.skip', 'no.txt')).writeAsStringSync('alpha\n');
    File(p.join(cwd, 'bin.dat')).writeAsBytesSync([0, 1, 2]);

    final result = await tools.grep('alpha', cwd: cwd);
    expect(result.matches.length, 2);
    expect(result.matches.first.display, contains(':1: alpha'));
    expect(result.matches.every((m) => m.path.contains('.skip')), isFalse);

    final limited = await tools.grep('alpha', cwd: cwd, limit: 1);
    expect(limited.matches.length, 1);
    expect(limited.truncated, isTrue);
  });
}
