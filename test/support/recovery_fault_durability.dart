import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:Kelivo/core/services/backup/restore_durability.dart';

class FaultDurability implements RestoreDurability {
  final delegate = RestorePlatformDurability();
  bool failPublish = false;
  Future<void> Function(String)? afterRename;
  Future<void> Function(File)? onSync;
  @override
  Future<void> restrictFile(File f) => delegate.restrictFile(f);
  @override
  Future<void> restrictDirectory(Directory d) => delegate.restrictDirectory(d);
  @override
  Future<void> syncDirectory(Directory d, {bool fullBarrier = false}) =>
      delegate.syncDirectory(d, fullBarrier: fullBarrier);
  @override
  Future<void> syncFile(File f, {bool fullBarrier = false}) async {
    await onSync?.call(f);
    await delegate.syncFile(f, fullBarrier: fullBarrier);
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    if (failPublish &&
        source is Directory &&
        p.basename(targetPath) == 'kelivo-data') {
      throw const FileSystemException('injected publication interruption');
    }
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    await afterRename?.call(targetPath);
  }
}
