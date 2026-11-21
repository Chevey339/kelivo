import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'backup_cancel_token.dart';
import 'backup_task_progress.dart';
import 'backup_staging.dart';
import 'backup_folder_access.dart';

/// Publishes a finished archive at the desktop file picker's destination.
Future<void> saveBackupToPath(
  File archive,
  String path, {
  required BackupCancelToken cancelToken,
  required BackupProgressSink onProgress,
}) async {
  cancelToken.throwIfCancelled();
  final destination = File(path);
  await destination.parent.create(recursive: true);
  final parent = await destination.parent.resolveSymbolicLinks();
  final staging = await (await BackupStaging.root()).resolveSymbolicLinks();
  if (p.equals(parent, staging) || p.isWithin(staging, parent)) {
    throw BackupFolderError.invalid;
  }
  final size = await archive.length();
  void report(int bytes) => onProgress(
    BackupProgress(
      phase: BackupPhase.saving,
      processed: bytes,
      total: size,
      unit: BackupProgressUnit.bytes,
    ),
  );
  report(0);
  // Keep a previous export intact until the new one is ready to replace it.
  Directory? work;
  try {
    work = await destination.parent.createTemp('.kelivo-export-');
  } on FileSystemException {
    // A single-file portal grant allows a temporary sibling and a rename,
    // but cannot grant a new subdirectory beside the chosen document.
  }
  final partial = work == null
      ? await File(
          p.join(
            destination.parent.path,
            '.kelivo-${const Uuid().v4()}.partial',
          ),
        ).create(exclusive: true)
      : File(p.join(work.path, 'archive.partial'));
  try {
    cancelToken.throwIfCancelled();
    try {
      await archive.rename(partial.path);
    } on FileSystemException catch (error) {
      // EXDEV / ERROR_NOT_SAME_DEVICE.
      if (error.osError?.errorCode != (Platform.isWindows ? 17 : 18)) rethrow;
      final output = await partial.open(mode: FileMode.writeOnly);
      try {
        final input = await archive.open();
        try {
          final buffer = Uint8List(1024 * 1024);
          final clock = Stopwatch()..start();
          var written = 0;
          while (true) {
            cancelToken.throwIfCancelled();
            final count = await input.readInto(buffer);
            if (count == 0) break;
            await output.writeFrom(buffer, 0, count);
            written += count;
            if (written == count ||
                clock.elapsedMilliseconds >= 100 ||
                written == size) {
              report(written);
              clock.reset();
            }
          }
          if (written != size) {
            throw FileSystemException('Incomplete backup copy', path);
          }
        } finally {
          await input.close();
        }
        await output.flush();
      } finally {
        await output.close();
      }
    }
    cancelToken.throwIfCancelled();
    cancelToken.setCancellable(false);
    onProgress(
      const BackupProgress(
        phase: BackupPhase.finalizing,
        processed: 0,
        cancellable: false,
      ),
    );
    await partial.rename(path);
  } finally {
    try {
      if (await partial.exists()) await partial.delete();
      await work?.delete();
    } on FileSystemException {
      // A cleanup failure must not hide the publication result.
    }
  }
}
