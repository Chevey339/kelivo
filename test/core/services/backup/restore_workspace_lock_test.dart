import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

void main() {
  group('RestoreWorkspaceLock', () {
    late Directory appDataDirectory;
    late RestoreWorkspaceLock lock;

    setUp(() async {
      appDataDirectory = await Directory.systemTemp.createTemp(
        'kelivo_restore_workspace_lock_test_',
      );
      lock = RestoreWorkspaceLock(appDataDirectory: appDataDirectory);
    });

    tearDown(() async {
      if (await appDataDirectory.exists()) {
        await appDataDirectory.delete(recursive: true);
      }
    });

    test(
      'creates a persistent lock file and returns the action result',
      () async {
        final result = await lock.synchronized(() async => 42);
        final lockFile = File(
          p.join(lock.workspaceRoot.path, RestoreWorkspaceLock.lockFileName),
        );

        expect(result, 42);
        expect(
          await FileSystemEntity.type(
            lock.workspaceRoot.path,
            followLinks: false,
          ),
          FileSystemEntityType.directory,
        );
        expect(
          await FileSystemEntity.type(lockFile.path, followLinks: false),
          FileSystemEntityType.file,
        );
        expect(await lock.synchronized(() async => 'next'), 'next');
        expect(await lockFile.exists(), isTrue);
      },
    );

    test('serializes same-root Future.wait calls in FIFO order', () async {
      final firstEntered = Completer<void>();
      final releaseFirst = Completer<void>();
      final events = <String>[];
      var activeActions = 0;
      var maximumActiveActions = 0;

      Future<void> run(int index, {Future<void>? waitFor}) {
        final sameRootLock = RestoreWorkspaceLock(
          appDataDirectory: appDataDirectory,
        );
        return sameRootLock.synchronized(() async {
          events.add('start$index');
          activeActions++;
          maximumActiveActions = maximumActiveActions < activeActions
              ? activeActions
              : maximumActiveActions;
          if (index == 0) firstEntered.complete();
          if (waitFor != null) await waitFor;
          activeActions--;
          events.add('end$index');
        });
      }

      final futures = <Future<void>>[
        run(0, waitFor: releaseFirst.future),
        run(1),
        run(2),
      ];
      await firstEntered.future;
      await Future<void>.delayed(Duration.zero);

      expect(events, ['start0']);
      releaseFirst.complete();
      await Future.wait(futures);

      expect(maximumActiveActions, 1);
      expect(events, ['start0', 'end0', 'start1', 'end1', 'start2', 'end2']);
    });

    test('releases the queue and file lock when the action fails', () async {
      await expectLater(
        lock.synchronized<void>(() async => throw StateError('action_failed')),
        throwsStateError,
      );

      expect(await lock.synchronized(() async => 'recovered'), 'recovered');
    });

    test(
      'rejects a linked workspace root without running the action',
      () async {
        final linkedTarget = Directory(p.join(appDataDirectory.path, 'target'));
        await linkedTarget.create();
        await Link(lock.workspaceRoot.path).create(linkedTarget.path);
        var actionRan = false;

        await expectLater(
          lock.synchronized<void>(() async {
            actionRan = true;
          }),
          throwsStateError,
        );
        expect(actionRan, isFalse);
      },
      skip: Platform.isWindows
          ? 'Symlink setup is not portable on Windows.'
          : false,
    );

    test(
      'rejects a linked lock file without running the action',
      () async {
        await lock.workspaceRoot.create();
        final linkedTarget = File(p.join(appDataDirectory.path, 'target.lock'));
        await linkedTarget.create();
        final lockPath = p.join(
          lock.workspaceRoot.path,
          RestoreWorkspaceLock.lockFileName,
        );
        await Link(lockPath).create(linkedTarget.path);
        var actionRan = false;

        await expectLater(
          lock.synchronized<void>(() async {
            actionRan = true;
          }),
          throwsStateError,
        );
        expect(actionRan, isFalse);
      },
      skip: Platform.isWindows
          ? 'Symlink setup is not portable on Windows.'
          : false,
    );

    test('rejects workspace and lock paths with the wrong type', () async {
      await File(lock.workspaceRoot.path).writeAsString('not a directory');
      await expectLater(lock.synchronized<void>(() async {}), throwsStateError);

      await File(lock.workspaceRoot.path).delete();
      await lock.workspaceRoot.create();
      await Directory(
        p.join(lock.workspaceRoot.path, RestoreWorkspaceLock.lockFileName),
      ).create();
      await expectLater(lock.synchronized<void>(() async {}), throwsStateError);
    });
  });
}
