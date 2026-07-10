import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'package:Kelivo/core/services/backup/restore_durability.dart';

final class BlockAfterCandidateDatabaseInstallDurability
    implements RestoreDurability {
  BlockAfterCandidateDatabaseInstallDurability({
    required this.delegate,
    required String candidateDatabasePath,
    required String liveDatabasePath,
    required this.onInstalled,
  }) : candidateDatabasePath = p.normalize(p.absolute(candidateDatabasePath)),
       liveDatabasePath = p.normalize(p.absolute(liveDatabasePath));

  final RestoreDurability delegate;
  final String candidateDatabasePath;
  final String liveDatabasePath;
  final Future<void> Function() onInstalled;
  bool _blocked = false;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    final matches =
        source is File &&
        p.equals(p.normalize(p.absolute(source.path)), candidateDatabasePath) &&
        p.equals(p.normalize(p.absolute(targetPath)), liveDatabasePath);
    if (!matches) {
      return delegate.renameAndSync(source: source, targetPath: targetPath);
    }
    if (_blocked) throw StateError('restore_harness_database_block_twice');
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    _blocked = true;
    await onInstalled();
    await Completer<void>().future;
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
  Future<void> syncFile(File file, {bool fullBarrier = false}) =>
      delegate.syncFile(file, fullBarrier: fullBarrier);
}

final class RejectingMutationPreferencesStore
    extends SharedPreferencesStorePlatform {
  RejectingMutationPreferencesStore(this.delegate);

  final SharedPreferencesStorePlatform delegate;
  int mutationAttempts = 0;

  Never _reject() {
    mutationAttempts++;
    throw StateError('restore_harness_settings_mutation');
  }

  @override
  Future<bool> clear() async => _reject();

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async =>
      _reject();

  @override
  Future<Map<String, Object>> getAll() => delegate.getAll();

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) => delegate.getAllWithParameters(parameters);

  @override
  Future<bool> remove(String key) async => _reject();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      _reject();
}
