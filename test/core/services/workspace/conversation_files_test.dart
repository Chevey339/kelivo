import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/workspace/conversation_files.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kelivo_snap_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('snapshot skips dot dirs and .l2s.* files', () async {
    File(p.join(tmp.path, 'keep.txt')).writeAsStringSync('a');
    Directory(p.join(tmp.path, '.git')).createSync();
    File(p.join(tmp.path, '.git', 'config')).writeAsStringSync('x');
    File(p.join(tmp.path, '.l2s.overlay')).writeAsStringSync('y');
    Directory(p.join(tmp.path, 'sub')).createSync();
    File(p.join(tmp.path, 'sub', 'nested.txt')).writeAsStringSync('z');

    final snap = await FileSnapshot.snapshot([tmp]);
    final names = snap.keys.map(p.basename).toSet();
    expect(names, containsAll(['keep.txt', 'nested.txt']));
    expect(names.contains('config'), isFalse);
    expect(names.any((n) => n.startsWith('.l2s.')), isFalse);
    expect(snap.length, 2);
  });

  test('changedSince reports new and modified paths', () async {
    final file = File(p.join(tmp.path, 'a.txt'))..writeAsStringSync('1');
    final before = await FileSnapshot.snapshot([tmp]);

    file.writeAsStringSync('2');
    await file.setLastModified(DateTime.now().add(const Duration(seconds: 2)));
    File(p.join(tmp.path, 'b.txt')).writeAsStringSync('new');

    final after = await FileSnapshot.snapshot([tmp]);
    final changed = FileSnapshot.changedSince(before, after);
    expect(changed.map(p.basename).toSet(), {'a.txt', 'b.txt'});
  });

  test('snapshot respects maxEntries', () async {
    for (var i = 0; i < 10; i++) {
      File(p.join(tmp.path, 'f$i.txt')).writeAsStringSync('$i');
    }
    final snap = await FileSnapshot.snapshot([tmp], maxEntries: 4);
    expect(snap.length, 4);
  });
}
