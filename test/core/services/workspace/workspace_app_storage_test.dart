import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/workspace/workspace_app_storage.dart';
import 'package:Kelivo/core/services/workspace/workspace_file_coordinator.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';

import '../../../support/workspace_test_access.dart';

void main() {
  late Directory temp;
  late String root;
  late WorkspaceAppStorage storage;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('workspace-app-storage-');
    root = await temp.resolveSymbolicLinks();
    storage = WorkspaceAppStorage(
      root: root,
      directory: 'notes.app.html.data',
      authorize: (_, __) async {},
    );
  });
  tearDown(() => temp.delete(recursive: true));

  Matcher code(String code) =>
      throwsA(isA<StateError>().having((e) => e.message, 'code', code));

  test(
    'create, exact UTF-8 read, versioned replace and missing file',
    () async {
      expect(await storage.read('state.json'), {
        'content': null,
        'version': null,
      });
      final saved = await storage.write('state.json', '{"中文":"🙂"}', null);
      final loaded = await storage.read('state.json');
      expect(loaded['content'], '{"中文":"🙂"}');
      expect(loaded['version'], saved['version']);
      final updated = await storage.write(
        'state.json',
        'updated',
        loaded['version'] as String,
      );
      expect(updated['version'], isNot(loaded['version']));
      expect((await storage.read('state.json'))['content'], 'updated');
    },
  );

  test('workers do not capture the UI authorization closure', () async {
    final port = RawReceivePort();
    addTearDown(port.close);
    storage = WorkspaceAppStorage(
      root: root,
      directory: 'notes.app.html.data',
      authorize: (_, __) async {
        expect(port.sendPort, isNotNull);
      },
    );
    await storage.write('state.txt', 'ok', null);
    expect((await storage.read('state.txt'))['content'], 'ok');
  });

  test(
    'stale versions and simultaneous tab creates cannot overwrite',
    () async {
      final results = await Future.wait([
        storage
            .write('state.txt', 'first', null)
            .then<Object>((v) => v, onError: (Object e) => e),
        storage
            .write('state.txt', 'second', null)
            .then<Object>((v) => v, onError: (Object e) => e),
      ]);
      expect(results.whereType<Map>().length, 1);
      expect(
        results.whereType<StateError>().single.message,
        'storage_conflict',
      );
      final current = await storage.read('state.txt');
      await expectLater(
        storage.write('state.txt', 'bad', '0' * 64),
        code('storage_conflict'),
      );
      expect(await storage.read('state.txt'), current);
    },
  );

  test(
    'rejects traversal, system paths, device names and executable extensions',
    () async {
      for (final path in [
        '',
        '../a.json',
        '/a.json',
        'a/../../b.json',
        r'a\b.json',
        'C:/a.json',
        'a.js',
        'a.html',
        'CON.txt',
        'CON .txt',
        r'CONIN$.txt',
        'COM¹.txt',
        'x/aux.json',
        'a. /b.json',
        'a\u0000.json',
      ]) {
        await expectLater(
          storage.write(path, 'bad', null),
          code('storage_invalid_path'),
          reason: path,
        );
      }
      expect(await temp.list().length, 0);
    },
  );

  test('refuses parent and leaf symbolic links on reads and writes', () async {
    if (Platform.isWindows) return;
    final outside = await Directory.systemTemp.createTemp('storage-outside-');
    addTearDown(() => outside.delete(recursive: true));
    final secret = File('${outside.path}/secret.txt')
      ..writeAsStringSync('secret');
    final data = Directory('$root/notes.app.html.data')..createSync();
    await Link('${data.path}/link.txt').create(secret.path);
    await Link('${data.path}/dir').create(outside.path);
    for (final path in ['link.txt', 'dir/new.txt']) {
      await expectLater(storage.read(path), code('storage_symlink_denied'));
      await expectLater(
        storage.write(path, 'bad', null),
        code('storage_symlink_denied'),
      );
    }
    expect(secret.readAsStringSync(), 'secret');
  });

  test('UTF-8 and byte limits do not corrupt existing content', () async {
    final saved = await storage.write('x.txt', 'original', null);
    await expectLater(
      storage.write('x.txt', '中' * 800000, saved['version'] as String),
      code('storage_too_large'),
    );
    await expectLater(
      storage.write(
        'x.txt',
        String.fromCharCode(0xd800),
        saved['version'] as String,
      ),
      code('storage_invalid_utf8'),
    );
    expect((await storage.read('x.txt'))['content'], 'original');
    await File('$root/notes.app.html.data/bad.txt').writeAsBytes([0xff]);
    await expectLater(storage.read('bad.txt'), code('storage_invalid_utf8'));
    final large = await File(
      '$root/notes.app.html.data/large.txt',
    ).open(mode: FileMode.write);
    await large.truncate(WorkspaceAppStorage.maxBytes + 1);
    await large.close();
    await expectLater(storage.read('large.txt'), code('storage_too_large'));
  });

  test(
    'revocation between staging and publication preserves the original',
    () async {
      final saved = await storage.write('x.txt', 'original', null);
      var checks = 0;
      storage = WorkspaceAppStorage(
        root: root,
        directory: 'notes.app.html.data',
        authorize: (_, __) async {
          if (++checks == 2) throw StateError('revoked');
        },
      );
      await expectLater(
        storage.write('x.txt', 'replacement', saved['version'] as String),
        code('revoked'),
      );
      expect(
        await File('$root/notes.app.html.data/x.txt').readAsString(),
        'original',
      );
      expect(
        (await Directory('$root/notes.app.html.data').list().toList()).length,
        1,
      );
    },
  );

  test('AI writes share exclusion and invalidate a page version', () async {
    final saved = await storage.write('x.txt', 'original', null);
    final skills = Directory('$root/skills')..createSync();
    final tools = authorizedHostFileTools(
      WorkspacePaths.native(
        workspaceHostRoot: root,
        sessionHostDir: root,
        skillsHostDir: skills.path,
      ),
    );
    final entered = Completer<void>(), release = Completer<void>();
    final lock = WorkspaceFileCoordinator.run(
      '$root/notes.app.html.data/x.txt',
      () async {
        entered.complete();
        await release.future;
      },
    );
    await entered.future;
    var done = false;
    final write = tools
        .writeFile('notes.app.html.data/x.txt', 'AI update', cwd: root)
        .then((v) {
          done = true;
          return v;
        });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(done, false);
    release.complete();
    await lock;
    await write;
    await expectLater(
      storage.write('x.txt', 'stale page', saved['version'] as String),
      code('storage_conflict'),
    );
    expect((await storage.read('x.txt'))['content'], 'AI update');
  });

  test('busy workspace requests fail without delayed storage writes', () async {
    final saved = await storage.write('state.txt', 'original', null);
    final started = Completer<void>();
    final release = Completer<void>();
    final shell = WorkspaceFileCoordinator.run(root, () async {
      started.complete();
      await release.future;
    });
    await started.future;
    try {
      await Future.wait([
        expectLater(storage.read('state.txt'), code('storage_busy')),
        expectLater(
          storage.write('state.txt', 'late write', saved['version'] as String),
          code('storage_busy'),
        ),
      ]).timeout(const Duration(seconds: 8));
    } finally {
      release.complete();
      await shell;
    }
    // Await another acquisition so even a mistakenly queued late write would
    // have finished before checking that the original data is preserved.
    await WorkspaceFileCoordinator.run(root, () async {});
    expect((await storage.read('state.txt'))['content'], 'original');
  });
}
