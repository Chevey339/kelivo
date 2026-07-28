import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_archive_pruner.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

void main() {
  late Directory root;
  late Directory completedRun;
  late int coldStarts;
  const runId = '0123456789abcdef0123456789abcdef';

  RestoreArchivePruner buildPruner({
    int coldStartsThreshold = 3,
    Future<void> Function()? clearArchive,
  }) {
    return RestoreArchivePruner(
      appDataDirectory: root,
      coldStartsThreshold: coldStartsThreshold,
      readColdStarts: () async => coldStarts,
      writeColdStarts: (count) async => coldStarts = count,
      clearArchive: clearArchive,
    );
  }

  setUp(() async {
    coldStarts = 0;
    root = await Directory.systemTemp.createTemp('kelivo_restore_prune_');
    completedRun = Directory(
      p.join(
        root.path,
        RestoreWorkspaceLock.workspaceRootName,
        RestoreWorkspaceLock.completedRunsDirectoryName,
        'run_$runId',
      ),
    );
    await completedRun.create(recursive: true);
    await File(
      p.join(completedRun.path, 'database.sqlite'),
    ).writeAsString('data');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'keeps the archive and counts cold starts below the threshold',
    () async {
      final pruner = buildPruner();
      await pruner.pruneAfterSuccessfulColdStart();
      await pruner.pruneAfterSuccessfulColdStart();

      expect(coldStarts, 2);
      expect(await completedRun.exists(), isTrue);
    },
  );

  test('clears the archive once the threshold is reached and resets', () async {
    final pruner = buildPruner();
    for (var index = 0; index < 3; index++) {
      await pruner.pruneAfterSuccessfulColdStart();
    }

    expect(await completedRun.exists(), isFalse);
    expect(coldStarts, 0);
  });

  test('resets the counter when no archive remains', () async {
    coldStarts = 2;
    await completedRun.delete(recursive: true);

    await buildPruner().pruneAfterSuccessfulColdStart();

    expect(coldStarts, 0);
  });

  test('keeps the archive and counter when clearing fails', () async {
    coldStarts = 2;
    final pruner = buildPruner(
      clearArchive: () => throw StateError('restore_trace_active_run'),
    );

    // Must not throw into startup; the next cold start retries.
    await pruner.pruneAfterSuccessfulColdStart();

    expect(await completedRun.exists(), isTrue);
    expect(coldStarts, 2);
  });
}
