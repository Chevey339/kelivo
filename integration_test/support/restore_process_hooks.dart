import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';

enum RestoreProcessEntityKind { file, directory }

enum RestoreReceiptDurabilityBoundary { tempDurable, published }

sealed class RestoreDurabilityObservation {
  const RestoreDurabilityObservation();
}

final class RestoreRenameObservation extends RestoreDurabilityObservation {
  const RestoreRenameObservation({
    required this.sourcePath,
    required this.targetPath,
    required this.sourceKind,
  });

  final String sourcePath;
  final String targetPath;
  final RestoreProcessEntityKind sourceKind;
}

final class RestoreFileSyncObservation extends RestoreDurabilityObservation {
  const RestoreFileSyncObservation({
    required this.path,
    required this.fullBarrier,
  });

  final String path;
  final bool fullBarrier;
}

final class RestoreDirectorySyncObservation
    extends RestoreDurabilityObservation {
  const RestoreDirectorySyncObservation({
    required this.path,
    required this.fullBarrier,
  });

  final String path;
  final bool fullBarrier;
}

final class RestoreReceiptDurabilityObservation
    extends RestoreDurabilityObservation {
  const RestoreReceiptDurabilityObservation({
    required this.boundary,
    required this.sequence,
    required this.state,
    required this.temporaryPath,
    this.targetPath,
  });

  final RestoreReceiptDurabilityBoundary boundary;
  final int sequence;
  final RestoreReceiptState state;
  final String temporaryPath;
  final String? targetPath;
}

abstract class RestoreDurabilityMatcher {
  const RestoreDurabilityMatcher();

  Future<RestoreDurabilityObservation?> matchRename({
    required FileSystemEntity source,
    required String targetPath,
  }) async => null;

  Future<RestoreDurabilityObservation?> matchFileSync({
    required File file,
    required bool fullBarrier,
  }) async => null;

  Future<RestoreDurabilityObservation?> matchDirectorySync({
    required Directory directory,
    required bool fullBarrier,
  }) async => null;
}

final class RestoreExactRenameMatcher extends RestoreDurabilityMatcher {
  RestoreExactRenameMatcher({
    required String sourcePath,
    required String targetPath,
    required this.sourceKind,
  }) : sourcePath = _requireAbsoluteNormalized(sourcePath, 'sourcePath'),
       targetPath = _requireAbsoluteNormalized(targetPath, 'targetPath');

  final String sourcePath;
  final String targetPath;
  final RestoreProcessEntityKind sourceKind;

  @override
  Future<RestoreDurabilityObservation?> matchRename({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    final actualKind = _entityKind(source);
    final actualSource = _normalizeObservedPath(source.path);
    final actualTarget = _normalizeObservedPath(targetPath);
    if (actualKind != sourceKind ||
        !p.equals(actualSource, sourcePath) ||
        !p.equals(actualTarget, this.targetPath)) {
      return null;
    }
    return RestoreRenameObservation(
      sourcePath: actualSource,
      targetPath: actualTarget,
      sourceKind: actualKind!,
    );
  }
}

final class RestoreExactFileSyncMatcher extends RestoreDurabilityMatcher {
  RestoreExactFileSyncMatcher({required String path, required this.fullBarrier})
    : path = _requireAbsoluteNormalized(path, 'path');

  final String path;
  final bool fullBarrier;

  @override
  Future<RestoreDurabilityObservation?> matchFileSync({
    required File file,
    required bool fullBarrier,
  }) async {
    final actualPath = _normalizeObservedPath(file.path);
    if (fullBarrier != this.fullBarrier || !p.equals(actualPath, path)) {
      return null;
    }
    return RestoreFileSyncObservation(
      path: actualPath,
      fullBarrier: fullBarrier,
    );
  }
}

final class RestoreExactDirectorySyncMatcher extends RestoreDurabilityMatcher {
  RestoreExactDirectorySyncMatcher({
    required String path,
    required this.fullBarrier,
  }) : path = _requireAbsoluteNormalized(path, 'path');

  final String path;
  final bool fullBarrier;

  @override
  Future<RestoreDurabilityObservation?> matchDirectorySync({
    required Directory directory,
    required bool fullBarrier,
  }) async {
    final actualPath = _normalizeObservedPath(directory.path);
    if (fullBarrier != this.fullBarrier || !p.equals(actualPath, path)) {
      return null;
    }
    return RestoreDirectorySyncObservation(
      path: actualPath,
      fullBarrier: fullBarrier,
    );
  }
}

final class RestoreReceiptTempDurableMatcher extends RestoreDurabilityMatcher {
  RestoreReceiptTempDurableMatcher({
    required String receiptDirectoryPath,
    required this.sequence,
    required this.state,
  }) : receiptDirectoryPath = _requireAbsoluteNormalized(
         receiptDirectoryPath,
         'receiptDirectoryPath',
       ) {
    _requireReceiptExpectation(sequence: sequence, state: state);
  }

  final String receiptDirectoryPath;
  final int sequence;
  final RestoreReceiptState state;

  @override
  Future<RestoreDurabilityObservation?> matchFileSync({
    required File file,
    required bool fullBarrier,
  }) async {
    if (!fullBarrier) return null;
    final receipt = await _readTemporaryReceipt(
      file,
      receiptDirectoryPath: receiptDirectoryPath,
    );
    if (receipt == null ||
        receipt.sequence != sequence ||
        receipt.state != state) {
      return null;
    }
    return RestoreReceiptDurabilityObservation(
      boundary: RestoreReceiptDurabilityBoundary.tempDurable,
      sequence: receipt.sequence,
      state: receipt.state,
      temporaryPath: _normalizeObservedPath(file.path),
    );
  }
}

final class RestoreReceiptPublishedMatcher extends RestoreDurabilityMatcher {
  RestoreReceiptPublishedMatcher({
    required String receiptDirectoryPath,
    required this.sequence,
    required this.state,
  }) : receiptDirectoryPath = _requireAbsoluteNormalized(
         receiptDirectoryPath,
         'receiptDirectoryPath',
       ) {
    _requireReceiptExpectation(sequence: sequence, state: state);
  }

  final String receiptDirectoryPath;
  final int sequence;
  final RestoreReceiptState state;

  String get targetPath => p.join(
    receiptDirectoryPath,
    'receipt_${sequence.toString().padLeft(16, '0')}.json',
  );

  @override
  Future<RestoreDurabilityObservation?> matchRename({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    if (source is! File ||
        !p.equals(_normalizeObservedPath(targetPath), this.targetPath)) {
      return null;
    }
    final receipt = await _readTemporaryReceipt(
      source,
      receiptDirectoryPath: receiptDirectoryPath,
    );
    if (receipt == null ||
        receipt.sequence != sequence ||
        receipt.state != state) {
      return null;
    }
    return RestoreReceiptDurabilityObservation(
      boundary: RestoreReceiptDurabilityBoundary.published,
      sequence: receipt.sequence,
      state: receipt.state,
      temporaryPath: _normalizeObservedPath(source.path),
      targetPath: this.targetPath,
    );
  }
}

final class OneShotBlockingRestoreDurability implements RestoreDurability {
  OneShotBlockingRestoreDurability({
    required this.delegate,
    required this.matcher,
    required this.onMatched,
  });

  final RestoreDurability delegate;
  final RestoreDurabilityMatcher matcher;
  final Future<void> Function(RestoreDurabilityObservation observation)
  onMatched;
  bool _didMatch = false;

  bool get didMatch => _didMatch;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    final observation = await matcher.matchRename(
      source: source,
      targetPath: targetPath,
    );
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    if (observation != null) await _notifyAndBlock(observation);
  }

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
    final observation = await matcher.matchDirectorySync(
      directory: directory,
      fullBarrier: fullBarrier,
    );
    await delegate.syncDirectory(directory, fullBarrier: fullBarrier);
    if (observation != null) await _notifyAndBlock(observation);
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) async {
    final observation = await matcher.matchFileSync(
      file: file,
      fullBarrier: fullBarrier,
    );
    await delegate.syncFile(file, fullBarrier: fullBarrier);
    if (observation != null) await _notifyAndBlock(observation);
  }

  Future<void> _notifyAndBlock(RestoreDurabilityObservation observation) async {
    if (_didMatch) throw StateError('restore_harness_durability_match_twice');
    _didMatch = true;
    await onMatched(observation);
    await Completer<void>().future;
  }
}

enum RestorePreferenceMutationKind { remove, set }

final class RestorePreferenceMutationObservation {
  const RestorePreferenceMutationObservation({
    required this.kind,
    required this.prefixedKey,
    this.valueType,
  });

  final RestorePreferenceMutationKind kind;
  final String prefixedKey;
  final String? valueType;
}

final class OneShotBlockingPreferencesStore
    extends SharedPreferencesStorePlatform {
  OneShotBlockingPreferencesStore({
    required this.delegate,
    required this.prefixedKey,
    required this.mutationKind,
    required this.onMatched,
  }) {
    if (prefixedKey.isEmpty) {
      throw ArgumentError.value(prefixedKey, 'prefixedKey');
    }
  }

  final SharedPreferencesStorePlatform delegate;
  final String prefixedKey;
  final RestorePreferenceMutationKind mutationKind;
  final Future<void> Function(RestorePreferenceMutationObservation observation)
  onMatched;
  bool _didMatch = false;

  bool get didMatch => _didMatch;

  @override
  Future<bool> clear() => delegate.clear();

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) =>
      delegate.clearWithParameters(parameters);

  @override
  Future<Map<String, Object>> getAll() => delegate.getAll();

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) => delegate.getAllWithParameters(parameters);

  @override
  Future<bool> remove(String key) async {
    final removed = await delegate.remove(key);
    if (removed &&
        mutationKind == RestorePreferenceMutationKind.remove &&
        key == prefixedKey) {
      await _notifyAndBlock(
        RestorePreferenceMutationObservation(
          kind: RestorePreferenceMutationKind.remove,
          prefixedKey: key,
        ),
      );
    }
    return removed;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final written = await delegate.setValue(valueType, key, value);
    if (written &&
        mutationKind == RestorePreferenceMutationKind.set &&
        key == prefixedKey) {
      await _notifyAndBlock(
        RestorePreferenceMutationObservation(
          kind: RestorePreferenceMutationKind.set,
          prefixedKey: key,
          valueType: valueType,
        ),
      );
    }
    return written;
  }

  Future<void> _notifyAndBlock(
    RestorePreferenceMutationObservation observation,
  ) async {
    if (_didMatch) throw StateError('restore_harness_settings_match_twice');
    _didMatch = true;
    await onMatched(observation);
    await Completer<void>().future;
  }
}

final _receiptTemporaryPattern = RegExp(
  r'^receipt_([0-9]{16})\.json\.([1-9][0-9]*)_([1-9][0-9]*)\.tmp$',
);

String _requireAbsoluteNormalized(String path, String name) {
  if (!p.isAbsolute(path) || p.normalize(path) != path) {
    throw ArgumentError.value(path, name);
  }
  return path;
}

String _normalizeObservedPath(String path) => p.normalize(p.absolute(path));

RestoreProcessEntityKind? _entityKind(FileSystemEntity entity) {
  if (entity is File) return RestoreProcessEntityKind.file;
  if (entity is Directory) return RestoreProcessEntityKind.directory;
  return null;
}

void _requireReceiptExpectation({
  required int sequence,
  required RestoreReceiptState state,
}) {
  final expectedSequence = switch (state) {
    RestoreReceiptState.prepared => 1,
    RestoreReceiptState.oldRenamed => 2,
    RestoreReceiptState.newInstalled => 3,
    RestoreReceiptState.verified => 4,
    RestoreReceiptState.committed => 5,
    RestoreReceiptState.rollingBack || RestoreReceiptState.rolledBack => null,
  };
  if (sequence < 1 ||
      (expectedSequence != null && sequence != expectedSequence)) {
    throw ArgumentError('restore_harness_receipt_expectation');
  }
}

Future<RestoreReceipt?> _readTemporaryReceipt(
  File file, {
  required String receiptDirectoryPath,
}) async {
  final path = _normalizeObservedPath(file.path);
  if (!p.equals(p.dirname(path), receiptDirectoryPath)) return null;
  final match = _receiptTemporaryPattern.firstMatch(p.basename(path));
  if (match == null) return null;
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map) {
    throw const FormatException('restore_harness_receipt_temp');
  }
  final receipt = RestoreReceipt.fromJson(decoded);
  if (receipt.sequence != int.parse(match[1]!)) {
    throw const FormatException('restore_harness_receipt_temp_sequence');
  }
  return receipt;
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
