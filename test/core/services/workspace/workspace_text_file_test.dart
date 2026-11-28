import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/services/workspace/workspace_text_file.dart';
import 'package:Kelivo/core/services/workspace/workspace_file_permissions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late File file;
  setUp(() {
    root = Directory.systemTemp.createTempSync('kelivo-text-');
    file = File(p.join(root.path, 'note.md'));
  });
  tearDown(() => root.deleteSync(recursive: true));
  Future<WorkspaceTextSnapshot> open() =>
      WorkspaceTextSnapshot.open(root.path, file.path);
  Future<String> save(
    WorkspaceTextSnapshot snapshot,
    String text, {
    bool copy = false,
  }) => snapshot.save(
    path: file.path,
    draft: text,
    writableRoot: (_) async => root.path,
    copy: copy,
  );

  test('round trips BOM, CRLF, trailing spaces and inserted lines', () async {
    file.writeAsBytesSync([0xef, 0xbb, 0xbf, ...utf8.encode('事项  \r\n二\r\n')]);
    final snapshot = await open();
    expect(snapshot.text, '事项  \n二\n');
    await save(snapshot, '事项  \n二\n三  \n');
    expect(file.readAsBytesSync(), [
      0xef,
      0xbb,
      0xbf,
      ...utf8.encode('事项  \r\n二\r\n三  \r\n'),
    ]);
  });
  test(
    'preserves mixed separators, empty content and an explicit replacement character',
    () async {
      file.writeAsStringSync('一\r\n二\r三\n\uFFFD');
      final snapshot = await open();
      await save(snapshot, '${snapshot.text}!');
      expect(file.readAsStringSync(), '一\r\n二\r三\n\uFFFD!');
      await save(await open(), '');
      expect(file.lengthSync(), 0);
    },
  );
  test(
    'rejects non-text and enforces each preview limit when entering editing',
    () async {
      for (final data in [
        [0xff],
        [65, 0, 66],
      ]) {
        file.writeAsBytesSync(data);
        await expectLater(open(), throwsA(WorkspaceTextProblem.encoding));
      }
      for (final text in [
        'a' * (WorkspaceTextLimits.bytes + 1),
        'a' * (WorkspaceTextLimits.lineLength + 1),
        '\n' * WorkspaceTextLimits.lines,
      ]) {
        file.writeAsStringSync(text);
        await expectLater(open(), throwsA(WorkspaceTextProblem.large));
      }
    },
  );
  test(
    'two editors cannot overwrite each other; conflicting drafts can be copied twice',
    () async {
      file.writeAsStringSync('08:30');
      final first = await open(), second = await open();
      await save(first, '09:15');
      await expectLater(
        save(second, '09:00'),
        throwsA(WorkspaceTextProblem.conflict),
      );
      expect(file.readAsStringSync(), '09:15');
      final copies = await Future.wait([
        save(second, '09:00', copy: true),
        save(second, '09:30', copy: true),
      ]);
      expect(copies.toSet(), hasLength(2));
      expect(copies.map((path) => File(path).readAsStringSync()), [
        '09:00',
        '09:30',
      ]);
      expect(file.readAsStringSync(), '09:15');
      expect(root.listSync().whereType<Directory>(), isEmpty);
    },
  );
  test(
    'revoked permission between staging and publication leaves no partial file',
    () async {
      file.writeAsStringSync('before');
      final snapshot = await open();
      var checks = 0;
      await expectLater(
        snapshot.save(
          path: file.path,
          draft: 'after',
          writableRoot: (_) async {
            if (++checks == 2) throw WorkspaceTextProblem.readOnly;
            return root.path;
          },
        ),
        throwsA(WorkspaceTextProblem.readOnly),
      );
      expect(file.readAsStringSync(), 'before');
      expect(root.listSync().map((e) => p.basename(e.path)), ['note.md']);
    },
  );

  test('the active workspace cannot grant edits to another root', () async {
    final other = Directory.systemTemp.createTempSync('kelivo-other-');
    addTearDown(() => other.deleteSync(recursive: true));
    file.writeAsStringSync('before');
    await expectLater(
      WorkspaceTextSnapshot.open(other.path, file.path),
      throwsA(WorkspaceTextProblem.readOnly),
    );
    final snapshot = await open();
    await expectLater(
      snapshot.save(
        path: file.path,
        draft: 'after',
        writableRoot: (_) async => other.path,
      ),
      throwsA(WorkspaceTextProblem.readOnly),
    );
    expect(file.readAsStringSync(), 'before');
  });

  test(
    'a type change offers a copy without editing the new link target',
    () async {
      file.writeAsStringSync('original');
      final snapshot = await open();
      final current = File(p.join(root.path, 'current.md'))
        ..writeAsStringSync('current');
      file.deleteSync();
      Link(file.path).createSync(current.path);
      await expectLater(
        save(snapshot, 'draft'),
        throwsA(WorkspaceTextProblem.conflict),
      );
      final copy = await save(snapshot, 'draft', copy: true);
      expect(File(copy).readAsStringSync(), 'draft');
      expect(current.readAsStringSync(), 'current');
      expect(FileSystemEntity.isLinkSync(file.path), isTrue);
      current.deleteSync();
      await expectLater(
        save(snapshot, 'second draft'),
        throwsA(WorkspaceTextProblem.conflict),
      );
      final second = await save(snapshot, 'second draft', copy: true);
      expect(File(second).readAsStringSync(), 'second draft');
      expect(current.existsSync(), isFalse);
      expect(FileSystemEntity.isLinkSync(file.path), isTrue);
    },
    skip: Platform.isWindows,
  );

  test(
    'a broken directory alias recovers only into an authorized root',
    () async {
      final version = Directory(p.join(root.path, 'v1'))..createSync();
      final current = Link(p.join(root.path, 'current'))
        ..createSync(version.path);
      file = File(p.join(current.path, 'note.md'))..writeAsStringSync('before');
      final snapshot = await open();
      version.renameSync(p.join(root.path, 'archived'));
      await expectLater(
        save(snapshot, 'draft'),
        throwsA(WorkspaceTextProblem.conflict),
      );
      await expectLater(
        snapshot.save(
          path: file.path,
          draft: 'draft',
          copy: true,
          writableRoot: (_) async => throw WorkspaceTextProblem.readOnly,
        ),
        throwsA(WorkspaceTextProblem.readOnly),
      );
      final checked = <String>[];
      final copy = await snapshot.save(
        path: file.path,
        draft: 'draft',
        copy: true,
        writableRoot: (directory) async {
          checked.add(directory);
          return root.path;
        },
      );
      expect(checked, List.filled(2, root.resolveSymbolicLinksSync()));
      expect(File(copy).readAsStringSync(), 'draft');
      expect(p.dirname(copy), root.resolveSymbolicLinksSync());
      expect(
        File(p.join(root.path, 'archived', 'note.md')).readAsStringSync(),
        'before',
      );
      expect(FileSystemEntity.isLinkSync(current.path), isTrue);
      final next = Directory(p.join(root.path, 'v2'))..createSync();
      final replacement = File(p.join(next.path, 'note.md'))
        ..writeAsStringSync('new version');
      current.updateSync(next.path);
      await expectLater(
        save(snapshot, 'more edits'),
        throwsA(WorkspaceTextProblem.conflict),
      );
      final redirected = await save(snapshot, 'more edits', copy: true);
      expect(p.dirname(redirected), root.resolveSymbolicLinksSync());
      expect(File(redirected).readAsStringSync(), 'more edits');
      expect(replacement.readAsStringSync(), 'new version');
    },
    skip: Platform.isWindows,
  );

  test(
    'partial Windows replacements restore the original or keep its recovery path',
    () {
      final backup = File(p.join(root.path, 'content.original'))
        ..writeAsStringSync('original');
      expect(
        () => finishWindowsWorkspaceReplacement(file.path, backup.path, 1177),
        throwsA(isA<FileSystemException>()),
      );
      expect(file.readAsStringSync(), 'original');
      expect(backup.existsSync(), isFalse);
      file.writeAsStringSync('new occupant');
      backup.writeAsStringSync('original');
      expect(
        () => finishWindowsWorkspaceReplacement(file.path, backup.path, 1177),
        throwsA(
          isA<FileSystemException>().having(
            (e) => e.path,
            'recovery path',
            backup.path,
          ),
        ),
      );
      expect(file.readAsStringSync(), 'new occupant');
      expect(backup.readAsStringSync(), 'original');
    },
  );

  test(
    'a removed original is not recreated; permissions are rechecked at save',
    () async {
      file.writeAsStringSync('original');
      final snapshot = await open();
      await expectLater(
        snapshot.save(
          path: file.path,
          draft: 'changed',
          writableRoot: (_) async => throw WorkspaceTextProblem.readOnly,
        ),
        throwsA(WorkspaceTextProblem.readOnly),
      );
      expect(file.readAsStringSync(), 'original');
      file.deleteSync();
      await expectLater(
        save(snapshot, 'changed'),
        throwsA(WorkspaceTextProblem.conflict),
      );
      final copy = await save(snapshot, 'changed', copy: true);
      expect(File(copy).readAsStringSync(), 'changed');
      expect(file.existsSync(), isFalse);
    },
  );
  test(
    'a file which grew to 1 GiB is classified as a conflict without materializing it',
    () async {
      file.writeAsStringSync('small');
      final snapshot = await open();
      final handle = file.openSync(mode: FileMode.write);
      handle.truncateSync(1 << 30);
      handle.closeSync();
      await expectLater(
        save(snapshot, 'draft'),
        throwsA(WorkspaceTextProblem.conflict),
      );
      expect(file.lengthSync(), 1 << 30);
      await expectLater(open(), throwsA(WorkspaceTextProblem.large));
    },
  );
  test(
    'preserves POSIX permissions for a private executable and its copy',
    () async {
      file.writeAsStringSync('echo 1');
      expect((await Process.run('chmod', ['700', file.path])).exitCode, 0);
      final original = await open();
      await save(original, 'echo 2');
      expect(file.statSync().mode & 0x1ff, 0x1c0);
      final copy = await save(original, 'echo 3', copy: true);
      expect(File(copy).statSync().mode & 0x1ff, 0x1c0);
      expect((await Process.run('chmod', ['400', file.path])).exitCode, 0);
      await expectLater(open(), throwsA(WorkspaceTextProblem.readOnly));
    },
    skip: Platform.isWindows,
  );

  test('requires actual file and parent write access', () async {
    if ((await Process.run('id', ['-u'])).stdout.toString().trim() == '0') {
      return;
    }
    file.writeAsStringSync('before');
    final original = await open();
    // The owner cannot write, even though the group write bit is set.
    expect((await Process.run('chmod', ['460', file.path])).exitCode, 0);
    await expectLater(open(), throwsA(WorkspaceTextProblem.readOnly));
    await expectLater(
      save(original, 'after'),
      throwsA(WorkspaceTextProblem.readOnly),
    );
    expect(file.readAsStringSync(), 'before');
    expect((await Process.run('chmod', ['600', file.path])).exitCode, 0);
    expect((await Process.run('chmod', ['500', root.path])).exitCode, 0);
    try {
      await expectLater(open(), throwsA(WorkspaceTextProblem.readOnly));
    } finally {
      await Process.run('chmod', ['700', root.path]);
    }
  }, skip: Platform.isWindows);

  test(
    'a replacement retains the macOS file ACL and Finder metadata',
    () async {
      file.writeAsStringSync('before');
      expect(
        (await Process.run('chmod', [
          '+a',
          'everyone deny execute',
          file.path,
        ])).exitCode,
        0,
      );
      expect(
        (await Process.run('xattr', [
          '-w',
          'org.kelivo.fixture',
          'preserve',
          file.path,
        ])).exitCode,
        0,
      );
      final snapshot = await open();
      await save(snapshot, 'after');
      expect(
        (await Process.run('ls', ['-le', file.path])).stdout,
        contains('everyone deny execute'),
      );
      expect(
        (await Process.run('xattr', [
          '-p',
          'org.kelivo.fixture',
          file.path,
        ])).stdout.toString().trim(),
        'preserve',
      );
    },
    skip: !Platform.isMacOS,
  );

  test(
    'recovers a draft after the parent moved or a directory replaced the file',
    () async {
      final parent = Directory(p.join(root.path, 'notes'))..createSync();
      file = File(p.join(parent.path, 'note.md'))..writeAsStringSync('before');
      final snapshot = await open();
      parent.renameSync(p.join(root.path, 'moved'));
      await expectLater(
        save(snapshot, 'draft'),
        throwsA(WorkspaceTextProblem.conflict),
      );
      final recovered = await save(snapshot, 'draft', copy: true);
      expect(p.basename(recovered), 'note (1).md');
      expect(File(recovered).readAsStringSync(), 'draft');
      expect(
        FileSystemEntity.identicalSync(File(recovered).parent.path, root.path),
        isTrue,
      );
      parent.createSync();
      Directory(file.path).createSync();
      await expectLater(
        save(snapshot, 'draft'),
        throwsA(WorkspaceTextProblem.conflict),
      );
      final sibling = await save(snapshot, 'draft', copy: true);
      expect(
        FileSystemEntity.identicalSync(File(sibling).parent.path, parent.path),
        isTrue,
      );
    },
  );

  test('exclusive copy writes the whole file and refuses an occupied name', () {
    file.writeAsStringSync('new content' * 4096);
    final target = p.join(root.path, 'copy');
    copyWorkspaceFileExclusively(file.path, target);
    expect(File(target).readAsBytesSync(), file.readAsBytesSync());
    file.writeAsStringSync('another version');
    expect(
      () => copyWorkspaceFileExclusively(file.path, target),
      throwsStateError,
    );
    expect(File(target).readAsStringSync(), startsWith('new content'));
  }, skip: Platform.isWindows);
}
