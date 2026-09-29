import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:Kelivo/features/workspace/widgets/files/file_browser_ops.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late Directory source;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('workspace_zip_test_');
    source = await Directory(p.join(temp.path, 'source')).create();
  });

  tearDown(() => temp.delete(recursive: true));

  test('ZIP round trips nested, empty and incompressible files', () async {
    final random = Random(1117);
    final bytes = Uint8List.fromList(
      List.generate(2 * 1024 * 1024 + 37, (_) => random.nextInt(256)),
    );
    await File(p.join(source.path, 'large.bin')).writeAsBytes(bytes);
    final nested = await Directory(p.join(source.path, '子目录')).create();
    await File(p.join(nested.path, '内容.txt')).writeAsString('hello 世界');
    await File(p.join(nested.path, 'empty')).create();
    // A link outside the workspace must not be followed into the export.
    final outside = await File(
      p.join(temp.path, 'private'),
    ).writeAsString('no');
    if (!Platform.isWindows) {
      await Link(p.join(source.path, 'link')).create(outside.path);
    }

    final dest = File(p.join(temp.path, 'output.zip'));
    await FileBrowserOps.zipDirectory(
      rootPath: source.path,
      source: source,
      dest: dest,
    );
    final archive = ZipDecoder().decodeBytes(
      await dest.readAsBytes(),
      verify: true,
    );
    expect(
      archive.files.map((file) => file.name),
      unorderedEquals(['large.bin', '子目录/内容.txt', '子目录/empty']),
    );
    expect(archive.findFile('large.bin')!.content, bytes);
    expect(utf8.decode(archive.findFile('子目录/内容.txt')!.content), 'hello 世界');
    expect(archive.findFile('子目录/empty')!.content, isEmpty);
    expect(
      temp.listSync().whereType<Directory>().map((dir) => p.basename(dir.path)),
      ['source'],
    );
  });

  test('empty source produces a valid empty ZIP', () async {
    final dest = await FileBrowserOps.zipDirectory(
      rootPath: source.path,
      source: source,
      dest: File(p.join(temp.path, 'empty.zip')),
    );
    expect(ZipDecoder().decodeBytes(await dest.readAsBytes()).files, isEmpty);
  });

  test('rejects a destination inside the source before writing', () async {
    final file = await File(
      p.join(source.path, 'keep.txt'),
    ).writeAsString('keep');
    await expectLater(
      FileBrowserOps.zipDirectory(
        rootPath: source.path,
        source: source,
        dest: file,
      ),
      throwsStateError,
    );
    expect(await file.readAsString(), 'keep');
  });

  test('failed export removes its partial ZIP and scratch directory', () async {
    final dest = File(p.join(temp.path, 'failed.zip'));
    await expectLater(
      FileBrowserOps.zipDirectory(
        rootPath: source.path,
        source: Directory(p.join(source.path, 'missing')),
        dest: dest,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await dest.exists(), isFalse);
    expect(temp.listSync().map((entity) => p.basename(entity.path)), [
      'source',
    ]);
  });
}
