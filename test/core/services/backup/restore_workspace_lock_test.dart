import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_durability.dart';
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

    test('claims and resumes the exact startup cutover marker', () async {
      const runId = '0123456789abcdef0123456789abcdef';
      await lock.synchronized(() async {
        await Directory(p.join(lock.workspaceRoot.path, 'run_$runId')).create();
        await File(
          p.join(
            lock.workspaceRoot.path,
            RestoreWorkspaceLock.activeRunFileName,
          ),
        ).writeAsString(runId, flush: true);

        await lock.claimCutoverRunWhileWorkspaceLocked(
          runId: runId,
          observedMarkerFileName: RestoreWorkspaceLock.activeRunFileName,
        );
        await lock.claimCutoverRunWhileWorkspaceLocked(
          runId: runId,
          observedMarkerFileName: RestoreWorkspaceLock.publishingRunFileName,
        );

        expect(
          await File(
            p.join(
              lock.workspaceRoot.path,
              RestoreWorkspaceLock.publishingRunFileName,
            ),
          ).readAsString(),
          runId,
        );
        expect(
          await FileSystemEntity.type(
            p.join(
              lock.workspaceRoot.path,
              RestoreWorkspaceLock.activeRunFileName,
            ),
            followLinks: false,
          ),
          FileSystemEntityType.notFound,
        );
      });
    });

    test(
      'rejects a publishing marker with an archived target without mutation',
      () async {
        const runId = '0123456789abcdef0123456789abcdef';
        await lock.synchronized(() async {
          final completedRun = Directory(
            p.join(lock.completedRunsRoot.path, 'run_$runId'),
          );
          await completedRun.create(recursive: true);
          final publishing = File(
            p.join(
              lock.workspaceRoot.path,
              RestoreWorkspaceLock.publishingRunFileName,
            ),
          );
          await publishing.writeAsString(runId, flush: true);

          await expectLater(
            lock.archiveTerminalRunWhileWorkspaceLocked(
              runId: runId,
              observedMarkerFileName:
                  RestoreWorkspaceLock.publishingRunFileName,
            ),
            throwsStateError,
          );

          expect(await publishing.readAsString(), runId);
          expect(
            await FileSystemEntity.type(
              p.join(
                lock.workspaceRoot.path,
                RestoreWorkspaceLock.archivingRunFileName,
              ),
              followLinks: false,
            ),
            FileSystemEntityType.notFound,
          );
          expect(await completedRun.exists(), isTrue);
        });
      },
    );

    test(
      'rejects simultaneous active and archived terminal runs without mutation',
      () async {
        const runId = '0123456789abcdef0123456789abcdef';
        await lock.synchronized(() async {
          final activeRun = Directory(
            p.join(lock.workspaceRoot.path, 'run_$runId'),
          );
          await activeRun.create();
          final completedRun = Directory(
            p.join(lock.completedRunsRoot.path, 'run_$runId'),
          );
          await completedRun.create(recursive: true);
          final publishing = File(
            p.join(
              lock.workspaceRoot.path,
              RestoreWorkspaceLock.publishingRunFileName,
            ),
          );
          await publishing.writeAsString(runId, flush: true);

          await expectLater(
            lock.archiveTerminalRunWhileWorkspaceLocked(
              runId: runId,
              observedMarkerFileName:
                  RestoreWorkspaceLock.publishingRunFileName,
            ),
            throwsStateError,
          );

          expect(await publishing.readAsString(), runId);
          expect(await activeRun.exists(), isTrue);
          expect(await completedRun.exists(), isTrue);
          expect(await lock.completedRunsRoot.exists(), isTrue);
          expect(
            await FileSystemEntity.type(
              p.join(
                lock.workspaceRoot.path,
                RestoreWorkspaceLock.archivingRunFileName,
              ),
              followLinks: false,
            ),
            FileSystemEntityType.notFound,
          );
        });
      },
    );

    test(
      'rejects a terminal run missing from active and completed without mutation',
      () async {
        const runId = '0123456789abcdef0123456789abcdef';
        await lock.synchronized(() async {
          final activeRun = Directory(
            p.join(lock.workspaceRoot.path, 'run_$runId'),
          );
          final completedRun = Directory(
            p.join(lock.completedRunsRoot.path, 'run_$runId'),
          );
          final archiving = File(
            p.join(
              lock.workspaceRoot.path,
              RestoreWorkspaceLock.archivingRunFileName,
            ),
          );
          await archiving.writeAsString(runId, flush: true);
          expect(await lock.completedRunsRoot.exists(), isFalse);

          await expectLater(
            lock.archiveTerminalRunWhileWorkspaceLocked(
              runId: runId,
              observedMarkerFileName: RestoreWorkspaceLock.archivingRunFileName,
            ),
            throwsStateError,
          );

          expect(await archiving.readAsString(), runId);
          expect(await activeRun.exists(), isFalse);
          expect(await completedRun.exists(), isFalse);
          expect(await lock.completedRunsRoot.exists(), isFalse);
        });
      },
    );

    test(
      'durably stages a markerless archiving marker before canonical publish',
      () async {
        const runId = '0123456789abcdef0123456789abcdef';
        final durability = _InterruptingArchivingMarkerDurability(
          delegate: RestorePlatformDurability(),
          workspaceRoot: lock.workspaceRoot,
          runId: runId,
          boundary: _ArchivingMarkerBoundary.temporaryDurable,
        );
        final guardedLock = RestoreWorkspaceLock(
          appDataDirectory: appDataDirectory,
          durability: durability,
        );
        final activeRun = Directory(
          p.join(guardedLock.workspaceRoot.path, 'run_$runId'),
        );

        await expectLater(
          guardedLock.synchronized(() async {
            await activeRun.create();
            await guardedLock.archiveTerminalRunWhileWorkspaceLocked(
              runId: runId,
              observedMarkerFileName: null,
            );
          }),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'injected_archiving_marker_temporary_durable',
            ),
          ),
        );

        expect(durability.didInterrupt, isTrue);
        expect(durability.temporaryPath, isNotNull);
        expect(_isArchivingMarkerTemporary(durability.temporaryPath!), isTrue);
        expect(durability.temporaryTypeAtBoundary, FileSystemEntityType.file);
        expect(durability.temporaryContentsAtBoundary, runId);
        expect(
          durability.canonicalTypeAtBoundary,
          FileSystemEntityType.notFound,
        );
        expect(await File(durability.temporaryPath!).readAsString(), runId);
        expect(await activeRun.exists(), isTrue);
      },
    );

    test(
      'publishes a complete markerless archiving marker before moving the run',
      () async {
        const runId = '0123456789abcdef0123456789abcdef';
        final durability = _InterruptingArchivingMarkerDurability(
          delegate: RestorePlatformDurability(),
          workspaceRoot: lock.workspaceRoot,
          runId: runId,
          boundary: _ArchivingMarkerBoundary.canonicalPublished,
        );
        final guardedLock = RestoreWorkspaceLock(
          appDataDirectory: appDataDirectory,
          durability: durability,
        );
        final activeRun = Directory(
          p.join(guardedLock.workspaceRoot.path, 'run_$runId'),
        );
        final completedRun = Directory(
          p.join(guardedLock.completedRunsRoot.path, 'run_$runId'),
        );
        final canonical = File(
          p.join(
            guardedLock.workspaceRoot.path,
            RestoreWorkspaceLock.archivingRunFileName,
          ),
        );

        await expectLater(
          guardedLock.synchronized(() async {
            await activeRun.create();
            await guardedLock.archiveTerminalRunWhileWorkspaceLocked(
              runId: runId,
              observedMarkerFileName: null,
            );
          }),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'injected_archiving_marker_canonical_published',
            ),
          ),
        );

        expect(durability.didInterrupt, isTrue);
        expect(await canonical.readAsString(), runId);
        expect(await activeRun.exists(), isTrue);
        expect(await completedRun.exists(), isFalse);
        expect(
          await _archivingMarkerTemporaries(guardedLock.workspaceRoot),
          isEmpty,
        );
      },
    );

    test(
      'stops after legacy artifact deletion when its directory barrier fails',
      () async {
        const runId = '0123456789abcdef0123456789abcdef';
        final temporary = File(
          p.join(
            lock.workspaceRoot.path,
            RestoreWorkspaceLock.archivingRunTemporaryFileName,
          ),
        );
        final activeRun = Directory(
          p.join(lock.workspaceRoot.path, 'run_$runId'),
        );
        final durability = _FailingArtifactDeleteBarrierDurability(
          delegate: RestorePlatformDurability(),
          workspaceRoot: lock.workspaceRoot,
          artifact: temporary,
        );
        final guardedLock = RestoreWorkspaceLock(
          appDataDirectory: appDataDirectory,
          durability: durability,
        );

        await expectLater(
          guardedLock.synchronized(() async {
            await activeRun.create();
            await temporary.writeAsString(runId, flush: true);
            durability.arm();
            await guardedLock
                .reconcileLegacyArchivingArtifactWhileWorkspaceLocked(
                  runId: runId,
                  artifactFileName:
                      RestoreWorkspaceLock.archivingRunTemporaryFileName,
                );
          }),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'injected_archiving_artifact_delete_barrier',
            ),
          ),
        );

        expect(durability.didInterrupt, isTrue);
        expect(await temporary.exists(), isFalse);
        expect(await activeRun.exists(), isTrue);
        expect(await lock.completedRunsRoot.exists(), isFalse);

        late Directory archivedRun;
        await lock.synchronized(() async {
          archivedRun = await lock.archiveTerminalRunWhileWorkspaceLocked(
            runId: runId,
            observedMarkerFileName: null,
          );
        });
        expect(await activeRun.exists(), isFalse);
        expect(await archivedRun.exists(), isTrue);
      },
    );

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

enum _ArchivingMarkerBoundary { temporaryDurable, canonicalPublished }

final class _InterruptingArchivingMarkerDurability
    implements RestoreDurability {
  _InterruptingArchivingMarkerDurability({
    required this.delegate,
    required Directory workspaceRoot,
    required this.runId,
    required this.boundary,
  }) : workspaceRootPath = p.normalize(p.absolute(workspaceRoot.path));

  final RestoreDurability delegate;
  final String workspaceRootPath;
  final String runId;
  final _ArchivingMarkerBoundary boundary;

  bool didInterrupt = false;
  String? temporaryPath;
  FileSystemEntityType? temporaryTypeAtBoundary;
  String? temporaryContentsAtBoundary;
  FileSystemEntityType? canonicalTypeAtBoundary;

  String get _canonicalPath =>
      p.join(workspaceRootPath, RestoreWorkspaceLock.archivingRunFileName);

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    final normalizedSource = p.normalize(p.absolute(source.path));
    final normalizedTarget = p.normalize(p.absolute(targetPath));
    final shouldInterrupt =
        boundary == _ArchivingMarkerBoundary.canonicalPublished &&
        source is File &&
        _isArchivingMarkerTemporary(normalizedSource) &&
        p.equals(p.dirname(normalizedSource), workspaceRootPath) &&
        p.equals(normalizedTarget, _canonicalPath);

    await delegate.renameAndSync(source: source, targetPath: targetPath);
    if (!shouldInterrupt) return;

    didInterrupt = true;
    temporaryPath = normalizedSource;
    throw StateError('injected_archiving_marker_canonical_published');
  }

  @override
  Future<void> restrictDirectory(Directory directory) =>
      delegate.restrictDirectory(directory);

  @override
  Future<void> restrictFile(File file) => delegate.restrictFile(file);

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) =>
      delegate.syncDirectory(directory, fullBarrier: fullBarrier);

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) async {
    await delegate.syncFile(file, fullBarrier: fullBarrier);
    final normalizedPath = p.normalize(p.absolute(file.path));
    if (boundary != _ArchivingMarkerBoundary.temporaryDurable ||
        !fullBarrier ||
        !_isArchivingMarkerTemporary(normalizedPath) ||
        !p.equals(p.dirname(normalizedPath), workspaceRootPath)) {
      return;
    }

    didInterrupt = true;
    temporaryPath = normalizedPath;
    temporaryTypeAtBoundary = await FileSystemEntity.type(
      normalizedPath,
      followLinks: false,
    );
    temporaryContentsAtBoundary = await File(normalizedPath).readAsString();
    canonicalTypeAtBoundary = await FileSystemEntity.type(
      _canonicalPath,
      followLinks: false,
    );
    if (temporaryContentsAtBoundary != runId) {
      throw StateError('unexpected_archiving_marker_temporary_contents');
    }
    throw StateError('injected_archiving_marker_temporary_durable');
  }
}

final class _FailingArtifactDeleteBarrierDurability
    implements RestoreDurability {
  _FailingArtifactDeleteBarrierDurability({
    required this.delegate,
    required Directory workspaceRoot,
    required File artifact,
  }) : workspaceRootPath = p.normalize(p.absolute(workspaceRoot.path)),
       artifactPath = p.normalize(p.absolute(artifact.path));

  final RestoreDurability delegate;
  final String workspaceRootPath;
  final String artifactPath;

  bool _armed = false;
  bool didInterrupt = false;

  void arm() => _armed = true;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) => delegate.renameAndSync(source: source, targetPath: targetPath);

  @override
  Future<void> restrictDirectory(Directory directory) =>
      delegate.restrictDirectory(directory);

  @override
  Future<void> restrictFile(File file) => delegate.restrictFile(file);

  @override
  Future<void> syncDirectory(
    Directory directory, {
    bool fullBarrier = false,
  }) async {
    if (_armed &&
        !didInterrupt &&
        fullBarrier &&
        p.equals(p.normalize(p.absolute(directory.path)), workspaceRootPath) &&
        await FileSystemEntity.type(artifactPath, followLinks: false) ==
            FileSystemEntityType.notFound) {
      didInterrupt = true;
      throw StateError('injected_archiving_artifact_delete_barrier');
    }
    await delegate.syncDirectory(directory, fullBarrier: fullBarrier);
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) =>
      delegate.syncFile(file, fullBarrier: fullBarrier);
}

bool _isArchivingMarkerTemporary(String path) {
  return p.basename(path) == RestoreWorkspaceLock.archivingRunTemporaryFileName;
}

Future<List<String>> _archivingMarkerTemporaries(
  Directory workspaceRoot,
) async {
  final names = <String>[];
  await for (final entity in workspaceRoot.list(followLinks: false)) {
    if (_isArchivingMarkerTemporary(entity.path)) {
      names.add(p.basename(entity.path));
    }
  }
  names.sort();
  return names;
}
