import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_settings_cold_ack.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

enum RestoreProcessEntityKind { file, directory }

enum RestoreReceiptDurabilityBoundary { tempDurable, published }

enum RestoreColdAckDurabilityBoundary { tempDurable, published }

enum RestoreLegacyArchivingMarkerBoundary {
  emptyRestricted,
  tempDurable,
  published,
}

enum RestoreTerminalWorkspaceSyncBoundary {
  completedRunsRootDurable,
  archivingMarkerRemovedDurable,
}

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

final class RestoreColdAckDurabilityObservation
    extends RestoreDurabilityObservation {
  const RestoreColdAckDurabilityObservation({
    required this.boundary,
    required this.runId,
    required this.terminalReceiptChecksum,
    required this.expected,
    required this.processId,
    required this.leaseInstanceId,
    required this.ackChecksum,
    required this.temporaryPath,
    this.targetPath,
  });

  final RestoreColdAckDurabilityBoundary boundary;
  final String runId;
  final String terminalReceiptChecksum;
  final RestoreSettingsColdAckExpected expected;
  final int processId;
  final String leaseInstanceId;
  final String ackChecksum;
  final String temporaryPath;
  final String? targetPath;
}

final class RestoreLegacyArchivingMarkerObservation
    extends RestoreDurabilityObservation {
  const RestoreLegacyArchivingMarkerObservation({
    required this.boundary,
    required this.runId,
    required this.workspaceRootPath,
    required this.temporaryPath,
    required this.canonicalPath,
    required this.activeRunPath,
    required this.temporaryContents,
  });

  final RestoreLegacyArchivingMarkerBoundary boundary;
  final String runId;
  final String workspaceRootPath;
  final String temporaryPath;
  final String canonicalPath;
  final String activeRunPath;
  final String temporaryContents;
}

final class RestoreTerminalWorkspaceSyncObservation
    extends RestoreDurabilityObservation {
  const RestoreTerminalWorkspaceSyncObservation({
    required this.boundary,
    required this.workspaceRootPath,
    required this.publishingMarkerPath,
    required this.archivingMarkerPath,
    required this.activeRunPath,
    required this.completedRunPath,
    required this.fullBarrier,
  });

  final RestoreTerminalWorkspaceSyncBoundary boundary;
  final String workspaceRootPath;
  final String publishingMarkerPath;
  final String archivingMarkerPath;
  final String activeRunPath;
  final String completedRunPath;
  final bool fullBarrier;
}

abstract class RestoreDurabilityMatcher {
  const RestoreDurabilityMatcher();

  Future<RestoreDurabilityObservation?> matchFileRestriction({
    required File file,
  }) async => null;

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

/// Matches the explicit full barrier after rollback has removed the empty
/// previous database parent, but only after both the restored live database
/// and returned candidate database are present.
final class RestoreRollbackDatabaseParentSyncMatcher
    extends RestoreDurabilityMatcher {
  RestoreRollbackDatabaseParentSyncMatcher({
    required String previousDirectoryPath,
    required String previousDatabaseDirectoryPath,
    required String candidateDatabasePath,
    required String liveDatabasePath,
  }) : previousDirectoryPath = _requireAbsoluteNormalized(
         previousDirectoryPath,
         'previousDirectoryPath',
       ),
       previousDatabaseDirectoryPath = _requireAbsoluteNormalized(
         previousDatabaseDirectoryPath,
         'previousDatabaseDirectoryPath',
       ),
       candidateDatabasePath = _requireAbsoluteNormalized(
         candidateDatabasePath,
         'candidateDatabasePath',
       ),
       liveDatabasePath = _requireAbsoluteNormalized(
         liveDatabasePath,
         'liveDatabasePath',
       ) {
    if (!p.equals(
      p.dirname(this.previousDatabaseDirectoryPath),
      this.previousDirectoryPath,
    )) {
      throw ArgumentError.value(
        previousDatabaseDirectoryPath,
        'previousDatabaseDirectoryPath',
      );
    }
  }

  final String previousDirectoryPath;
  final String previousDatabaseDirectoryPath;
  final String candidateDatabasePath;
  final String liveDatabasePath;

  @override
  Future<RestoreDurabilityObservation?> matchDirectorySync({
    required Directory directory,
    required bool fullBarrier,
  }) async {
    if (!fullBarrier ||
        !p.equals(
          _normalizeObservedPath(directory.path),
          previousDirectoryPath,
        )) {
      return null;
    }
    final types = await Future.wait([
      FileSystemEntity.type(previousDirectoryPath, followLinks: false),
      FileSystemEntity.type(previousDatabaseDirectoryPath, followLinks: false),
      FileSystemEntity.type(candidateDatabasePath, followLinks: false),
      FileSystemEntity.type(liveDatabasePath, followLinks: false),
    ]);
    if (types[0] != FileSystemEntityType.directory ||
        types[1] != FileSystemEntityType.notFound ||
        types[2] != FileSystemEntityType.file ||
        types[3] != FileSystemEntityType.file) {
      return null;
    }
    return RestoreDirectorySyncObservation(
      path: previousDirectoryPath,
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

final class RestoreColdAckTempDurableMatcher extends RestoreDurabilityMatcher {
  RestoreColdAckTempDurableMatcher({
    required String runDirectoryPath,
    required String terminalReceiptChecksum,
    required RestoreSettingsColdAckExpected expected,
    required int processId,
    required String leaseInstanceId,
  }) : _expectation = _RestoreColdAckExpectation(
         runDirectoryPath: runDirectoryPath,
         terminalReceiptChecksum: terminalReceiptChecksum,
         expected: expected,
         processId: processId,
         leaseInstanceId: leaseInstanceId,
       );

  final _RestoreColdAckExpectation _expectation;

  String get runDirectoryPath => _expectation.runDirectoryPath;
  String get targetPath => _expectation.targetPath;

  @override
  Future<RestoreDurabilityObservation?> matchFileSync({
    required File file,
    required bool fullBarrier,
  }) async {
    if (!fullBarrier) return null;
    final ack = await _expectation.readMatchingTemporary(file);
    if (ack == null) return null;
    return _expectation.observation(
      ack: ack,
      boundary: RestoreColdAckDurabilityBoundary.tempDurable,
      temporaryPath: _normalizeObservedPath(file.path),
    );
  }
}

final class RestoreColdAckPublishedMatcher extends RestoreDurabilityMatcher {
  RestoreColdAckPublishedMatcher({
    required String runDirectoryPath,
    required String terminalReceiptChecksum,
    required RestoreSettingsColdAckExpected expected,
    required int processId,
    required String leaseInstanceId,
  }) : _expectation = _RestoreColdAckExpectation(
         runDirectoryPath: runDirectoryPath,
         terminalReceiptChecksum: terminalReceiptChecksum,
         expected: expected,
         processId: processId,
         leaseInstanceId: leaseInstanceId,
       );

  final _RestoreColdAckExpectation _expectation;

  String get runDirectoryPath => _expectation.runDirectoryPath;
  String get targetPath => _expectation.targetPath;

  @override
  Future<RestoreDurabilityObservation?> matchRename({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    if (source is! File ||
        !p.equals(_normalizeObservedPath(targetPath), this.targetPath)) {
      return null;
    }
    final ack = await _expectation.readMatchingTemporary(source);
    if (ack == null) return null;
    return _expectation.observation(
      ack: ack,
      boundary: RestoreColdAckDurabilityBoundary.published,
      temporaryPath: _normalizeObservedPath(source.path),
      targetPath: this.targetPath,
    );
  }
}

final class RestoreLegacyArchivingMarkerMatcher
    extends RestoreDurabilityMatcher {
  factory RestoreLegacyArchivingMarkerMatcher({
    required String workspaceRootPath,
    required String runId,
    required RestoreLegacyArchivingMarkerBoundary boundary,
  }) {
    return RestoreLegacyArchivingMarkerMatcher._(
      workspaceRootPath: _requireWorkspaceRootPath(workspaceRootPath),
      runId: _requireRunId(runId),
      boundary: boundary,
    );
  }

  RestoreLegacyArchivingMarkerMatcher._({
    required this.workspaceRootPath,
    required this.runId,
    required this.boundary,
  }) : temporaryPath = p.join(
         workspaceRootPath,
         RestoreWorkspaceLock.archivingRunTemporaryFileName,
       ),
       canonicalPath = p.join(
         workspaceRootPath,
         RestoreWorkspaceLock.archivingRunFileName,
       ),
       activeRunPath = p.join(workspaceRootPath, 'run_$runId'),
       completedRunsRootPath = p.join(
         workspaceRootPath,
         RestoreWorkspaceLock.completedRunsDirectoryName,
       ),
       completedRunPath = p.join(
         workspaceRootPath,
         RestoreWorkspaceLock.completedRunsDirectoryName,
         'run_$runId',
       );

  final String workspaceRootPath;
  final String runId;
  final RestoreLegacyArchivingMarkerBoundary boundary;
  final String temporaryPath;
  final String canonicalPath;
  final String activeRunPath;
  final String completedRunsRootPath;
  final String completedRunPath;

  @override
  Future<RestoreDurabilityObservation?> matchFileRestriction({
    required File file,
  }) async {
    if (boundary != RestoreLegacyArchivingMarkerBoundary.emptyRestricted ||
        !p.equals(_normalizeObservedPath(file.path), temporaryPath)) {
      return null;
    }
    return _matchExpectedTopology(expectedTemporaryContents: '');
  }

  @override
  Future<RestoreDurabilityObservation?> matchFileSync({
    required File file,
    required bool fullBarrier,
  }) async {
    if (boundary != RestoreLegacyArchivingMarkerBoundary.tempDurable ||
        !fullBarrier ||
        !p.equals(_normalizeObservedPath(file.path), temporaryPath)) {
      return null;
    }
    return _matchExpectedTopology(expectedTemporaryContents: runId);
  }

  @override
  Future<RestoreDurabilityObservation?> matchRename({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    if (boundary != RestoreLegacyArchivingMarkerBoundary.published ||
        source is! File ||
        !p.equals(_normalizeObservedPath(source.path), temporaryPath) ||
        !p.equals(_normalizeObservedPath(targetPath), canonicalPath)) {
      return null;
    }
    return _matchExpectedTopology(expectedTemporaryContents: runId);
  }

  Future<RestoreLegacyArchivingMarkerObservation?> _matchExpectedTopology({
    required String expectedTemporaryContents,
  }) async {
    final activeMarkerPath = p.join(
      workspaceRootPath,
      RestoreWorkspaceLock.activeRunFileName,
    );
    final publishingMarkerPath = p.join(
      workspaceRootPath,
      RestoreWorkspaceLock.publishingRunFileName,
    );
    final discardingMarkerPath = p.join(
      workspaceRootPath,
      RestoreWorkspaceLock.discardingRunFileName,
    );
    final types = await Future.wait([
      FileSystemEntity.type(workspaceRootPath, followLinks: false),
      FileSystemEntity.type(temporaryPath, followLinks: false),
      FileSystemEntity.type(canonicalPath, followLinks: false),
      FileSystemEntity.type(activeMarkerPath, followLinks: false),
      FileSystemEntity.type(publishingMarkerPath, followLinks: false),
      FileSystemEntity.type(discardingMarkerPath, followLinks: false),
      FileSystemEntity.type(activeRunPath, followLinks: false),
      FileSystemEntity.type(completedRunsRootPath, followLinks: false),
      FileSystemEntity.type(completedRunPath, followLinks: false),
    ]);
    if (types[0] != FileSystemEntityType.directory ||
        types[1] != FileSystemEntityType.file ||
        types[2] != FileSystemEntityType.notFound ||
        types[3] != FileSystemEntityType.notFound ||
        types[4] != FileSystemEntityType.notFound ||
        types[5] != FileSystemEntityType.notFound ||
        types[6] != FileSystemEntityType.directory ||
        types[7] != FileSystemEntityType.directory ||
        types[8] != FileSystemEntityType.notFound) {
      return null;
    }
    final contents = await _readStableRegularFile(File(temporaryPath));
    if (contents == null || contents != expectedTemporaryContents) return null;
    return RestoreLegacyArchivingMarkerObservation(
      boundary: boundary,
      runId: runId,
      workspaceRootPath: workspaceRootPath,
      temporaryPath: temporaryPath,
      canonicalPath: canonicalPath,
      activeRunPath: activeRunPath,
      temporaryContents: contents,
    );
  }
}

final class RestoreTerminalWorkspaceSyncMatcher
    extends RestoreDurabilityMatcher {
  factory RestoreTerminalWorkspaceSyncMatcher({
    required String workspaceRootPath,
    required String runId,
    required RestoreTerminalWorkspaceSyncBoundary boundary,
  }) {
    return RestoreTerminalWorkspaceSyncMatcher._(
      workspaceRootPath: _requireWorkspaceRootPath(workspaceRootPath),
      runId: _requireRunId(runId),
      boundary: boundary,
    );
  }

  RestoreTerminalWorkspaceSyncMatcher._({
    required this.workspaceRootPath,
    required this.runId,
    required this.boundary,
  }) : publishingMarkerPath = p.join(
         workspaceRootPath,
         RestoreWorkspaceLock.publishingRunFileName,
       ),
       archivingMarkerPath = p.join(
         workspaceRootPath,
         RestoreWorkspaceLock.archivingRunFileName,
       ),
       activeRunPath = p.join(workspaceRootPath, 'run_$runId'),
       completedRunPath = p.join(
         workspaceRootPath,
         RestoreWorkspaceLock.completedRunsDirectoryName,
         'run_$runId',
       );

  final String workspaceRootPath;
  final String runId;
  final RestoreTerminalWorkspaceSyncBoundary boundary;
  final String publishingMarkerPath;
  final String archivingMarkerPath;
  final String activeRunPath;
  final String completedRunPath;

  Directory get completedRunsRoot => Directory(
    p.join(workspaceRootPath, RestoreWorkspaceLock.completedRunsDirectoryName),
  );

  @override
  Future<RestoreDurabilityObservation?> matchDirectorySync({
    required Directory directory,
    required bool fullBarrier,
  }) async {
    if (!fullBarrier ||
        !p.equals(_normalizeObservedPath(directory.path), workspaceRootPath) ||
        !await _matchesExpectedTopology()) {
      return null;
    }
    return RestoreTerminalWorkspaceSyncObservation(
      boundary: boundary,
      workspaceRootPath: workspaceRootPath,
      publishingMarkerPath: publishingMarkerPath,
      archivingMarkerPath: archivingMarkerPath,
      activeRunPath: activeRunPath,
      completedRunPath: completedRunPath,
      fullBarrier: fullBarrier,
    );
  }

  Future<bool> _matchesExpectedTopology() async {
    final activeMarkerPath = p.join(
      workspaceRootPath,
      RestoreWorkspaceLock.activeRunFileName,
    );
    final discardingMarkerPath = p.join(
      workspaceRootPath,
      RestoreWorkspaceLock.discardingRunFileName,
    );
    final types = await Future.wait([
      FileSystemEntity.type(workspaceRootPath, followLinks: false),
      FileSystemEntity.type(completedRunsRoot.path, followLinks: false),
      FileSystemEntity.type(activeMarkerPath, followLinks: false),
      FileSystemEntity.type(discardingMarkerPath, followLinks: false),
      FileSystemEntity.type(publishingMarkerPath, followLinks: false),
      FileSystemEntity.type(archivingMarkerPath, followLinks: false),
      FileSystemEntity.type(activeRunPath, followLinks: false),
      FileSystemEntity.type(completedRunPath, followLinks: false),
    ]);
    if (types[0] != FileSystemEntityType.directory ||
        types[1] != FileSystemEntityType.directory ||
        types[2] != FileSystemEntityType.notFound ||
        types[3] != FileSystemEntityType.notFound) {
      return false;
    }
    return switch (boundary) {
      RestoreTerminalWorkspaceSyncBoundary.completedRunsRootDurable =>
        types[4] == FileSystemEntityType.file &&
            types[5] == FileSystemEntityType.notFound &&
            types[6] == FileSystemEntityType.directory &&
            types[7] == FileSystemEntityType.notFound &&
            await _markerContainsRunId(File(publishingMarkerPath)),
      RestoreTerminalWorkspaceSyncBoundary.archivingMarkerRemovedDurable =>
        types[4] == FileSystemEntityType.notFound &&
            types[5] == FileSystemEntityType.notFound &&
            types[6] == FileSystemEntityType.notFound &&
            types[7] == FileSystemEntityType.directory,
    };
  }

  Future<bool> _markerContainsRunId(File marker) async {
    if (await marker.length() != runId.length) return false;
    return await marker.readAsString() == runId;
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
  Future<void> restrictFile(File file) async {
    await delegate.restrictFile(file);
    final observation = await matcher.matchFileRestriction(file: file);
    if (observation != null) await _notifyAndBlock(observation);
  }

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

/// Fails exactly once after [failOnMatch] - 1 successful writes to one exact
/// prefixed key. Calls after the injected failure delegate normally so the
/// same wrapper can remain installed while rollback restores the before state.
final class NthExactSetFailurePreferencesStore
    extends SharedPreferencesStorePlatform {
  NthExactSetFailurePreferencesStore({
    required this.delegate,
    required this.prefixedKey,
    required this.failOnMatch,
  }) {
    if (prefixedKey.isEmpty) {
      throw ArgumentError.value(prefixedKey, 'prefixedKey');
    }
    if (failOnMatch < 1) {
      throw ArgumentError.value(failOnMatch, 'failOnMatch');
    }
  }

  final SharedPreferencesStorePlatform delegate;
  final String prefixedKey;
  final int failOnMatch;
  var _successfulMatches = 0;
  var _didFail = false;

  int get successfulMatches => _successfulMatches;
  bool get didFail => _didFail;

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
  Future<bool> remove(String key) => delegate.remove(key);

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key != prefixedKey || _didFail) {
      return delegate.setValue(valueType, key, value);
    }
    if (_successfulMatches + 1 == failOnMatch) {
      _didFail = true;
      return false;
    }
    final written = await delegate.setValue(valueType, key, value);
    if (written) _successfulMatches++;
    return written;
  }
}

final class OneShotBlockingPreferencesStore
    extends SharedPreferencesStorePlatform {
  OneShotBlockingPreferencesStore({
    required this.delegate,
    required this.prefixedKey,
    required this.mutationKind,
    required this.onMatched,
    this.isArmed,
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
  final bool Function()? isArmed;
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
        key == prefixedKey &&
        (isArmed?.call() ?? true)) {
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
        key == prefixedKey &&
        (isArmed?.call() ?? true)) {
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
final _coldAckTemporaryPattern = RegExp(
  '^${RegExp.escape(RestoreSettingsColdAckStore.fileName)}\\.'
  r'([1-9][0-9]*)_([1-9][0-9]*)_([0-9]+)\.tmp$',
);
final _runIdPattern = RegExp(r'^[a-f0-9]{32}$');
final _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');

final class _RestoreColdAckExpectation {
  _RestoreColdAckExpectation({
    required String runDirectoryPath,
    required String terminalReceiptChecksum,
    required this.expected,
    required int processId,
    required String leaseInstanceId,
  }) : runDirectoryPath = _requireRunDirectoryPath(runDirectoryPath),
       runId = _runIdFromRunDirectoryPath(runDirectoryPath),
       terminalReceiptChecksum = _requireSha256(
         terminalReceiptChecksum,
         'terminalReceiptChecksum',
       ),
       processId = _requireProcessId(processId),
       leaseInstanceId = _requireIdentifier(leaseInstanceId, 'leaseInstanceId');

  final String runDirectoryPath;
  final String runId;
  final String terminalReceiptChecksum;
  final RestoreSettingsColdAckExpected expected;
  final int processId;
  final String leaseInstanceId;

  String get targetPath =>
      p.join(runDirectoryPath, RestoreSettingsColdAckStore.fileName);

  Future<RestoreSettingsColdAck?> readMatchingTemporary(File file) async {
    final path = _normalizeObservedPath(file.path);
    if (!p.equals(p.dirname(path), runDirectoryPath)) return null;
    final match = _coldAckTemporaryPattern.firstMatch(p.basename(path));
    if (match == null || int.tryParse(match[2]!) != processId) return null;
    final ack = await _readCanonicalColdAck(file);
    if (ack.runId != runId ||
        ack.terminalReceiptChecksum != terminalReceiptChecksum ||
        ack.expected != expected ||
        ack.processId != processId ||
        ack.leaseInstanceId != leaseInstanceId) {
      return null;
    }
    return ack;
  }

  RestoreColdAckDurabilityObservation observation({
    required RestoreSettingsColdAck ack,
    required RestoreColdAckDurabilityBoundary boundary,
    required String temporaryPath,
    String? targetPath,
  }) {
    return RestoreColdAckDurabilityObservation(
      boundary: boundary,
      runId: ack.runId,
      terminalReceiptChecksum: ack.terminalReceiptChecksum,
      expected: ack.expected,
      processId: ack.processId,
      leaseInstanceId: ack.leaseInstanceId,
      ackChecksum: ack.checksum,
      temporaryPath: temporaryPath,
      targetPath: targetPath,
    );
  }
}

Future<RestoreSettingsColdAck> _readCanonicalColdAck(File file) async {
  if (await FileSystemEntity.type(file.path, followLinks: false) !=
      FileSystemEntityType.file) {
    throw const FormatException('restore_harness_cold_ack_temp_file');
  }
  const maximumBytes = 16 * 1024;
  final expectedLength = await file.length();
  if (expectedLength <= 0 || expectedLength > maximumBytes) {
    throw const FormatException('restore_harness_cold_ack_temp_size');
  }
  final handle = await file.open(mode: FileMode.read);
  final builder = BytesBuilder(copy: false);
  try {
    while (builder.length <= maximumBytes) {
      final chunk = await handle.read(maximumBytes + 1 - builder.length);
      if (chunk.isEmpty) break;
      builder.add(chunk);
    }
  } finally {
    await handle.close();
  }
  final bytes = builder.takeBytes();
  if (bytes.length != expectedLength ||
      bytes.length > maximumBytes ||
      await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
    throw const FormatException('restore_harness_cold_ack_temp_changed');
  }
  final dynamic decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const FormatException('restore_harness_cold_ack_temp_json');
  }
  if (decoded is! Map) {
    throw const FormatException('restore_harness_cold_ack_temp_json');
  }
  final ack = RestoreSettingsColdAck.fromJson(decoded);
  final canonical = utf8.encode(jsonEncode(ack.toJson()));
  if (!_sameBytes(bytes, canonical)) {
    throw const FormatException('restore_harness_cold_ack_temp_canonical');
  }
  return ack;
}

Future<String?> _readStableRegularFile(File file) async {
  if (await FileSystemEntity.type(file.path, followLinks: false) !=
      FileSystemEntityType.file) {
    return null;
  }
  final expectedLength = await file.length();
  final contents = await file.readAsString();
  if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file ||
      await file.length() != expectedLength ||
      contents.length != expectedLength) {
    return null;
  }
  return contents;
}

String _requireRunDirectoryPath(String path) {
  final normalized = _requireAbsoluteNormalized(path, 'runDirectoryPath');
  if (RegExp(r'^run_[a-f0-9]{32}$').firstMatch(p.basename(normalized)) ==
      null) {
    throw ArgumentError.value(path, 'runDirectoryPath');
  }
  return normalized;
}

String _runIdFromRunDirectoryPath(String path) {
  final normalized = _requireRunDirectoryPath(path);
  return p.basename(normalized).substring('run_'.length);
}

String _requireWorkspaceRootPath(String path) {
  final normalized = _requireAbsoluteNormalized(path, 'workspaceRootPath');
  if (p.basename(normalized) != RestoreWorkspaceLock.workspaceRootName) {
    throw ArgumentError.value(path, 'workspaceRootPath');
  }
  return normalized;
}

String _requireRunId(String runId) {
  if (!_runIdPattern.hasMatch(runId)) {
    throw ArgumentError.value(runId, 'runId');
  }
  return runId;
}

String _requireSha256(String value, String name) {
  if (!_sha256Pattern.hasMatch(value)) {
    throw ArgumentError.value(value, name);
  }
  return value;
}

String _requireIdentifier(String value, String name) {
  if (!_runIdPattern.hasMatch(value)) {
    throw ArgumentError.value(value, name);
  }
  return value;
}

int _requireProcessId(int processId) {
  if (processId <= 0) {
    throw ArgumentError.value(processId, 'processId');
  }
  return processId;
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

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

final class CountingMutationPreferencesStore
    extends SharedPreferencesStorePlatform {
  CountingMutationPreferencesStore(this.delegate);

  final SharedPreferencesStorePlatform delegate;
  int mutationAttempts = 0;

  @override
  Future<bool> clear() {
    mutationAttempts++;
    return delegate.clear();
  }

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) {
    mutationAttempts++;
    return delegate.clearWithParameters(parameters);
  }

  @override
  Future<Map<String, Object>> getAll() => delegate.getAll();

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) => delegate.getAllWithParameters(parameters);

  @override
  Future<bool> remove(String key) {
    mutationAttempts++;
    return delegate.remove(key);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    mutationAttempts++;
    return delegate.setValue(valueType, key, value);
  }
}
