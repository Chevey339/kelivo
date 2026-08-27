import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/backup_isolate_runner.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';

void main() {
  test(
    'keeps workDir while isolateExited is false and deletes it on exit',
    () async {
      final workDir = await Directory.systemTemp.createTemp(
        'kelivo_backup_alive_',
      );
      final sentinel = File('${workDir.path}/sentinel');
      await sentinel.writeAsString('held', flush: true);
      final isolateExit = Completer<void>();

      await DataSync.deleteTempDirectoryWhenIsolateSafe(
        workDir,
        error: BackupCancelledException(
          isolateExited: false,
          isolateExit: isolateExit.future,
        ),
      );

      expect(await sentinel.exists(), isTrue);
      expect(await workDir.exists(), isTrue);

      isolateExit.complete();
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (await workDir.exists() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(await workDir.exists(), isFalse);
    },
  );

  test(
    'deletes workDir immediately when the isolate has already exited',
    () async {
      final workDir = await Directory.systemTemp.createTemp(
        'kelivo_backup_exited_',
      );
      await File('${workDir.path}/sentinel').writeAsString('gone', flush: true);

      await DataSync.deleteTempDirectoryWhenIsolateSafe(
        workDir,
        error: const BackupCancelledException(),
      );

      expect(await workDir.exists(), isFalse);
    },
  );

  test('timeout with isolateExited false is treated as still-alive', () {
    expect(
      DataSync.shouldDeleteTempPathsAfterIsolateError(
        BackupIsolateTimeoutException(isolateExited: false),
      ),
      isFalse,
    );
    expect(
      DataSync.shouldDeleteTempPathsAfterIsolateError(
        BackupIsolateTimeoutException(isolateExited: true),
      ),
      isTrue,
    );
  });

  test('age cleaner skips a registered work dir older than 6 hours', () async {
    final tmp = await Directory.systemTemp.createTemp('kelivo_backup_tmp_');
    addTearDown(() async {
      DataSync.unregisterLiveTempPath(
        '${tmp.path}/kelivo_backup_2000-01-01T00-00-00.000000',
      );
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final stale = Directory(
      '${tmp.path}/kelivo_backup_2000-01-01T00-00-00.000000',
    );
    await stale.create(recursive: true);
    await File('${stale.path}/orphan.zip').writeAsString('old', flush: true);
    DataSync.registerLiveTempPath(stale.path);

    await DataSync.debugCleanupPreviousBackupTempFiles(tmp);

    expect(await stale.exists(), isTrue);
    expect(await File('${stale.path}/orphan.zip').exists(), isTrue);

    DataSync.unregisterLiveTempPath(stale.path);
    await DataSync.debugCleanupPreviousBackupTempFiles(tmp);

    expect(await stale.exists(), isFalse);
  });

  test(
    'local export helper deletes the temp zip on every persist outcome',
    () async {
      Future<void> expectCleaned({
        required Future<void> Function(File exported) persist,
      }) async {
        final workDir = await Directory.systemTemp.createTemp(
          'kelivo_backup_export_',
        );
        final exported = File('${workDir.path}/kelivo_backup_demo.zip');
        await exported.writeAsBytes([1, 2, 3], flush: true);

        try {
          await DataSync.completeLocalFileExport(
            exported: exported,
            persist: persist,
          );
        } catch (_) {}

        expect(await exported.exists(), isFalse);
      }

      await expectCleaned(persist: (_) async {});
      await expectCleaned(
        persist: (exported) async {
          throw StateError('copy_failed');
        },
      );
      await expectCleaned(
        persist: (exported) async {
          final dest = File('${exported.parent.path}/saved.zip');
          await exported.copy(dest.path);
        },
      );
    },
  );
}
