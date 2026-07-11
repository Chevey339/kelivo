import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/backup/restore_bundle_preparation.dart';
import 'package:Kelivo/core/services/backup/restore_business_lease.dart';
import 'package:Kelivo/core/services/backup/restore_cutover_executor.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_previous_store.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_settings_cold_ack.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

import 'restore_cold_process_test_helper.dart';

final class _FailingNthSetPreferencesStore
    extends InMemorySharedPreferencesStore {
  _FailingNthSetPreferencesStore(super.data, {required this.failOnCall})
    : super.withData();

  final int failOnCall;
  var _setCalls = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    _setCalls++;
    if (_setCalls == failOnCall) return false;
    return super.setValue(valueType, key, value);
  }
}

final class _FailVerifiedRetryPreferencesStore
    extends InMemorySharedPreferencesStore {
  _FailVerifiedRetryPreferencesStore(super.data) : super.withData();

  var _failNextVerifiedTarget = false;
  var verifiedTargetFailures = 0;
  var mutationAttempts = 0;

  void armVerifiedTargetFailure() {
    if (_failNextVerifiedTarget) {
      throw StateError('restore_test_verified_failure_already_armed');
    }
    _failNextVerifiedTarget = true;
  }

  void resetMutationAttempts() => mutationAttempts = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    mutationAttempts++;
    if (_failNextVerifiedTarget &&
        valueType == 'String' &&
        key == 'flutter.theme' &&
        value == 'new') {
      _failNextVerifiedTarget = false;
      verifiedTargetFailures++;
      return false;
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    mutationAttempts++;
    return super.remove(key);
  }
}

final class _CompleteRollbackBundleFixture {
  const _CompleteRollbackBundleFixture({
    required this.prepared,
    required this.liveDatabase,
    required this.liveOldUpload,
    required this.liveNewUpload,
  });

  final PreparedRestoreBundle prepared;
  final File liveDatabase;
  final File liveOldUpload;
  final File liveNewUpload;
}

enum _LogicalCutoverInterruption {
  claimed,
  previousReady,
  oldRenamedPublished,
  candidateInstalled,
  newInstalledPublished,
  liveVerified,
  verifiedPublished,
  committedPublished,
  rollingBackPublished,
  rollbackVerified,
  rolledBackPublished,
}

/// Interrupts at real durable boundaries instead of exposing a production
/// failpoint callback. Throwing before a receipt rename models work ahead of
/// the journal; throwing after it models a published state awaiting restart.
final class _InterruptingCutoverDurability implements RestoreDurability {
  _InterruptingCutoverDurability(this.delegate, this.point);

  final RestoreDurability delegate;
  final _LogicalCutoverInterruption point;
  var didInterrupt = false;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    final targetName = p.basename(targetPath);
    if (point == _LogicalCutoverInterruption.claimed &&
        targetName == RestoreWorkspaceLock.publishingRunFileName) {
      await delegate.renameAndSync(source: source, targetPath: targetPath);
      _interrupt();
    }

    final receipt = await _receiptBeingPublished(source, targetPath);
    if (receipt != null && _beforeReceipt(receipt.state) == point) {
      _interrupt();
    }
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    if (receipt != null && _afterReceipt(receipt.state) == point) {
      _interrupt();
    }
  }

  Future<RestoreReceipt?> _receiptBeingPublished(
    FileSystemEntity source,
    String targetPath,
  ) async {
    if (source is! File ||
        p.basename(p.dirname(targetPath)) != 'receipts' ||
        !RegExp(
          r'^receipt_[0-9]{16}\.json$',
        ).hasMatch(p.basename(targetPath))) {
      return null;
    }
    final decoded = jsonDecode(await source.readAsString());
    if (decoded is! Map) throw const FormatException('test_receipt');
    return RestoreReceipt.fromJson(decoded);
  }

  Never _interrupt() {
    didInterrupt = true;
    throw StateError('injected_${point.name}');
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

_LogicalCutoverInterruption? _beforeReceipt(RestoreReceiptState state) {
  return switch (state) {
    RestoreReceiptState.oldRenamed => _LogicalCutoverInterruption.previousReady,
    RestoreReceiptState.newInstalled =>
      _LogicalCutoverInterruption.candidateInstalled,
    RestoreReceiptState.verified => _LogicalCutoverInterruption.liveVerified,
    RestoreReceiptState.rolledBack =>
      _LogicalCutoverInterruption.rollbackVerified,
    RestoreReceiptState.prepared ||
    RestoreReceiptState.committed ||
    RestoreReceiptState.rollingBack => null,
  };
}

_LogicalCutoverInterruption? _afterReceipt(RestoreReceiptState state) {
  return switch (state) {
    RestoreReceiptState.oldRenamed =>
      _LogicalCutoverInterruption.oldRenamedPublished,
    RestoreReceiptState.newInstalled =>
      _LogicalCutoverInterruption.newInstalledPublished,
    RestoreReceiptState.verified =>
      _LogicalCutoverInterruption.verifiedPublished,
    RestoreReceiptState.committed =>
      _LogicalCutoverInterruption.committedPublished,
    RestoreReceiptState.rollingBack =>
      _LogicalCutoverInterruption.rollingBackPublished,
    RestoreReceiptState.rolledBack =>
      _LogicalCutoverInterruption.rolledBackPublished,
    RestoreReceiptState.prepared => null,
  };
}

final class _ThrowAfterArchivingMarkerDurability implements RestoreDurability {
  _ThrowAfterArchivingMarkerDurability(this.delegate);

  final RestoreDurability delegate;
  var didThrow = false;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    if (!didThrow &&
        p.basename(targetPath) == RestoreWorkspaceLock.archivingRunFileName) {
      didThrow = true;
      throw StateError('injected_terminal_archive');
    }
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

/// Models a process/filesystem failure after the terminal run rename changed
/// the visible namespace but before either parent-directory barrier completed.
final class _InterruptAfterTerminalRunRawRenameDurability
    implements RestoreDurability {
  _InterruptAfterTerminalRunRawRenameDurability(
    this.delegate, {
    required Directory source,
    required Directory target,
  }) : sourcePath = p.normalize(p.absolute(source.path)),
       targetPath = p.normalize(p.absolute(target.path));

  final RestoreDurability delegate;
  final String sourcePath;
  final String targetPath;
  var didInterrupt = false;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    if (!didInterrupt &&
        source is Directory &&
        p.equals(p.normalize(p.absolute(source.path)), sourcePath) &&
        p.equals(p.normalize(p.absolute(targetPath)), this.targetPath)) {
      await source.rename(targetPath);
      didInterrupt = true;
      throw StateError('injected_terminal_run_raw_rename');
    }
    await delegate.renameAndSync(source: source, targetPath: targetPath);
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

final class _FailingArchiveParentSyncDurability implements RestoreDurability {
  _FailingArchiveParentSyncDurability(
    this.delegate, {
    required Directory completedRunsRoot,
    required Directory workspaceRoot,
  }) : completedRunsRootPath = p.normalize(p.absolute(completedRunsRoot.path)),
       workspaceRootPath = p.normalize(p.absolute(workspaceRoot.path));

  final RestoreDurability delegate;
  final String completedRunsRootPath;
  final String workspaceRootPath;
  final observedParentSyncs = <String>[];
  var didFail = false;

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
    final path = p.normalize(p.absolute(directory.path));
    if (fullBarrier &&
        (p.equals(path, completedRunsRootPath) ||
            p.equals(path, workspaceRootPath))) {
      observedParentSyncs.add(path);
      if (!didFail && p.equals(path, workspaceRootPath)) {
        didFail = true;
        throw StateError('injected_terminal_archive_source_parent_sync');
      }
    }
    await delegate.syncDirectory(directory, fullBarrier: fullBarrier);
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) =>
      delegate.syncFile(file, fullBarrier: fullBarrier);
}

final class _ThrowAfterDiscardingMarkerDurability implements RestoreDurability {
  _ThrowAfterDiscardingMarkerDurability(this.delegate);

  final RestoreDurability delegate;
  var didThrow = false;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    if (!didThrow &&
        p.basename(targetPath) == RestoreWorkspaceLock.discardingRunFileName) {
      didThrow = true;
      throw StateError('injected_unpublished_discard');
    }
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

Future<({Directory directory, String manifestSha256})> _createBundle(
  Directory root, {
  String theme = 'dark',
  bool secretsIncluded = false,
  String directoryName = 'extracted',
}) async {
  final directory = Directory(p.join(root.path, directoryName));
  await directory.create();
  final settings = File(p.join(directory.path, 'settings.json'));
  await settings.writeAsString(jsonEncode({'theme': theme}), flush: true);
  final manifest = File(p.join(directory.path, 'manifest.json'));
  await manifest.writeAsString(
    jsonEncode({
      'format': 'kelivo-backup',
      'formatVersion': 2,
      'payloadKind': 'settings-only',
      'createdAtUtc': '2026-07-09T00:00:00.000Z',
      'appVersion': 'test',
      'includeChats': false,
      'includeFiles': false,
      'secretsIncluded': secretsIncluded,
      'entries': {
        'settings.json': {
          'bytes': await settings.length(),
          'sha256': (await sha256.bind(settings.openRead()).first).toString(),
        },
      },
    }),
    flush: true,
  );
  return (
    directory: directory,
    manifestSha256: (await sha256.bind(manifest.openRead()).first).toString(),
  );
}

Future<_CompleteRollbackBundleFixture> _prepareCompleteRollbackBundle({
  required Directory root,
  required String directoryName,
}) async {
  final liveDatabase = File(p.join(root.path, 'kelivo.sqlite'));
  await _createRollbackDatabase(liveDatabase, conversationId: 'old');
  final liveOldUpload = File(p.join(root.path, 'upload', 'old.txt'));
  await liveOldUpload.parent.create();
  await liveOldUpload.writeAsString('old asset', flush: true);
  await Directory(p.join(root.path, 'images')).create();

  final extracted = Directory(p.join(root.path, directoryName));
  await extracted.create();
  final settings = File(p.join(extracted.path, 'settings.json'));
  await settings.writeAsString('{"theme":"new"}', flush: true);
  final candidateDatabase = File(
    p.join(extracted.path, 'database', 'kelivo.sqlite'),
  );
  await candidateDatabase.parent.create(recursive: true);
  await _createRollbackDatabase(candidateDatabase, conversationId: 'new');
  final databaseInfo = await ChatDatabaseRepository.prepareSnapshotForRestore(
    candidateDatabase,
  );
  final candidateUpload = File(p.join(extracted.path, 'upload', 'new.txt'));
  await candidateUpload.parent.create();
  await candidateUpload.writeAsString('new asset', flush: true);
  final manifest = File(p.join(extracted.path, 'manifest.json'));
  await manifest.writeAsString(
    jsonEncode({
      'format': 'kelivo-backup',
      'formatVersion': 2,
      'payloadKind': 'sqlite',
      'createdAtUtc': '2026-07-09T00:00:00.000Z',
      'appVersion': 'test',
      'includeChats': true,
      'includeFiles': true,
      'secretsIncluded': true,
      'database': {
        'entry': 'database/kelivo.sqlite',
        'schemaVersion': databaseInfo.schemaVersion,
        'conversationCount': databaseInfo.conversationCount,
        'messageCount': databaseInfo.messageCount,
      },
      'entries': {
        'settings.json': await _rollbackFileDescriptor(settings),
        'database/kelivo.sqlite': await _rollbackFileDescriptor(
          candidateDatabase,
        ),
        'upload/new.txt': await _rollbackFileDescriptor(candidateUpload),
      },
    }),
    flush: true,
  );
  final prepared = await RestoreBundlePreparation.prepare(
    appDataDirectory: root,
    extractedDirectory: extracted,
    sourceManifestSha256: (await sha256.bind(manifest.openRead()).first)
        .toString(),
    bundleIncludesChats: true,
    bundleIncludesFiles: true,
    restoreChats: true,
    restoreFiles: true,
    createdAtUtc: DateTime.utc(2026, 7, 9, 12),
  );
  return _CompleteRollbackBundleFixture(
    prepared: prepared,
    liveDatabase: liveDatabase,
    liveOldUpload: liveOldUpload,
    liveNewUpload: File(p.join(root.path, 'upload', 'new.txt')),
  );
}

Future<void> _createRollbackDatabase(
  File file, {
  required String conversationId,
}) async {
  final repository = ChatDatabaseRepository.open(file: file);
  try {
    await repository.ensureReady();
    await repository.putMigrationBatch(
      conversations: [Conversation(id: conversationId, title: conversationId)],
      messages: const [],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );
    await repository.markMigrationComplete();
    await repository.checkpoint();
  } finally {
    await repository.close();
  }
}

Future<Map<String, dynamic>> _rollbackFileDescriptor(File file) async {
  return {
    'bytes': await file.length(),
    'sha256': (await sha256.bind(file.openRead()).first).toString(),
  };
}

Future<List<String>> _rollbackConversationIds(File file) async {
  final database = sqlite.sqlite3.open(
    file.path,
    mode: sqlite.OpenMode.readOnly,
  );
  try {
    return database
        .select('SELECT id FROM conversation_rows ORDER BY id;')
        .map((row) => row['id'] as String)
        .toList(growable: false);
  } finally {
    database.close();
  }
}

Future<Directory> _createStrictUnpublishedRun({
  required Directory root,
  required String runId,
  required String markerFileName,
  bool includeReceiptTemp = true,
}) async {
  final workspace = Directory(
    p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
  );
  await workspace.create(recursive: true);
  await File(
    p.join(workspace.path, markerFileName),
  ).writeAsString(runId, flush: true);
  final runDirectory = Directory(p.join(workspace.path, 'run_$runId'));
  final candidate = Directory(p.join(runDirectory.path, 'candidate'));
  await candidate.create(recursive: true);
  await File(
    p.join(candidate.path, 'settings.json'),
  ).writeAsString('{"partial":', flush: true);
  await Directory(p.join(candidate.path, 'database')).create();
  final nestedAsset = File(
    p.join(candidate.path, 'upload', 'nested', 'partial.bin'),
  );
  await nestedAsset.parent.create(recursive: true);
  await nestedAsset.writeAsBytes([1, 2, 3], flush: true);
  if (includeReceiptTemp) {
    final receipts = Directory(p.join(runDirectory.path, 'receipts'));
    await receipts.create();
    await File(
      p.join(receipts.path, 'receipt_0000000000000001.json.123456_789.tmp'),
    ).writeAsString('{"partial":', flush: true);
  }
  return runDirectory;
}

Future<RestoreReceipt?> _recoverAcrossColdRestart({
  required Directory appDataDirectory,
  required SharedPreferences preferences,
}) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      return await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: appDataDirectory,
        preferences: preferences,
      );
    } on RestoreColdRestartRequired {
      await simulateRestoreColdProcessBoundary(appDataDirectory);
    }
  }
  throw StateError('restore_test_cold_restart_limit');
}

typedef _MarkerlessRestoreFixture = ({
  Directory activeRun,
  PreparedRestoreBundle prepared,
  SharedPreferences preferences,
  RestoreWorkspaceLock workspaceLock,
});

Future<_MarkerlessRestoreFixture> _prepareMarkerlessTerminalFixture({
  required Directory root,
  required String directoryName,
}) async {
  SharedPreferences.setMockInitialValues({'theme': 'old'});
  final preferences = await SharedPreferences.getInstance();
  final bundle = await _createBundle(
    root,
    theme: 'new',
    secretsIncluded: true,
    directoryName: directoryName,
  );
  final prepared = await RestoreBundlePreparation.prepare(
    appDataDirectory: root,
    extractedDirectory: bundle.directory,
    sourceManifestSha256: bundle.manifestSha256,
    bundleIncludesChats: false,
    bundleIncludesFiles: false,
    restoreChats: false,
    restoreFiles: false,
    createdAtUtc: DateTime.utc(2026, 7, 9, 12),
  );

  await expectLater(
    RestoreStartupGate.recoverAndRequireBusinessReady(
      appDataDirectory: root,
      preferences: preferences,
    ),
    throwsA(isA<RestoreColdRestartRequired>()),
  );
  await simulateRestoreColdProcessBoundary(root);

  final workspaceLock = RestoreWorkspaceLock(appDataDirectory: root);
  await _removeMarkerAndSync(
    workspaceLock: workspaceLock,
    markerFileName: RestoreWorkspaceLock.publishingRunFileName,
    runId: prepared.runId,
  );
  final activeRun = Directory(
    p.join(workspaceLock.workspaceRoot.path, 'run_${prepared.runId}'),
  );
  expect(await activeRun.exists(), isTrue);
  final markerless = await RestoreStartupGate.inspect(appDataDirectory: root);
  expect(markerless?.runId, prepared.runId);
  expect(markerless?.receipt.state, RestoreReceiptState.committed);
  expect(markerless?.markerFileName, isNull);

  return (
    activeRun: activeRun,
    prepared: prepared,
    preferences: preferences,
    workspaceLock: workspaceLock,
  );
}

Future<_MarkerlessRestoreFixture> _prepareMarkerlessNonterminalFixture({
  required Directory root,
  required String directoryName,
}) async {
  SharedPreferences.setMockInitialValues({'theme': 'old'});
  final preferences = await SharedPreferences.getInstance();
  final bundle = await _createBundle(
    root,
    theme: 'new',
    secretsIncluded: true,
    directoryName: directoryName,
  );
  final prepared = await RestoreBundlePreparation.prepare(
    appDataDirectory: root,
    extractedDirectory: bundle.directory,
    sourceManifestSha256: bundle.manifestSha256,
    bundleIncludesChats: false,
    bundleIncludesFiles: false,
    restoreChats: false,
    restoreFiles: false,
    createdAtUtc: DateTime.utc(2026, 7, 9, 12),
  );
  final workspaceLock = RestoreWorkspaceLock(appDataDirectory: root);
  await _removeMarkerAndSync(
    workspaceLock: workspaceLock,
    markerFileName: RestoreWorkspaceLock.activeRunFileName,
    runId: prepared.runId,
  );
  final activeRun = Directory(
    p.join(workspaceLock.workspaceRoot.path, 'run_${prepared.runId}'),
  );
  expect(await activeRun.exists(), isTrue);
  expect(
    (await RestoreReceiptStore(
      appDataDirectory: root,
      runId: prepared.runId,
    ).readLatest())?.state,
    RestoreReceiptState.prepared,
  );
  return (
    activeRun: activeRun,
    prepared: prepared,
    preferences: preferences,
    workspaceLock: workspaceLock,
  );
}

Future<void> _removeMarkerAndSync({
  required RestoreWorkspaceLock workspaceLock,
  required String markerFileName,
  required String runId,
}) => workspaceLock.synchronized(() async {
  final marker = File(p.join(workspaceLock.workspaceRoot.path, markerFileName));
  expect(await marker.readAsString(), runId);
  await marker.delete();
  await RestorePlatformDurability().syncDirectory(
    workspaceLock.workspaceRoot,
    fullBarrier: true,
  );
});

String _markerPayload(String kind, String runId) => switch (kind) {
  'empty' => '',
  'truncated' => runId.substring(0, runId.length ~/ 2),
  'full' => runId,
  'wrongPrefix' => _differentRunId(runId).substring(0, runId.length ~/ 2),
  'wrongId' => _differentRunId(runId),
  _ => throw ArgumentError.value(kind, 'kind'),
};

String _differentRunId(String runId) =>
    '${runId.startsWith('0') ? '1' : '0'}${runId.substring(1)}';

Future<void> _writeDurableMarkerArtifact({
  required File file,
  required String contents,
  required Directory workspaceRoot,
}) async {
  final durability = RestorePlatformDurability();
  await file.create(exclusive: true);
  await durability.restrictFile(file);
  await file.writeAsString(contents, flush: true);
  await durability.syncFile(file, fullBarrier: true);
  await durability.syncDirectory(workspaceRoot, fullBarrier: true);
}

Future<void> _expectMarkerlessTerminalConverges({
  required Directory root,
  required _MarkerlessRestoreFixture fixture,
}) async {
  final recovered = await RestoreStartupGate.recoverAndRequireBusinessReady(
    appDataDirectory: root,
    preferences: fixture.preferences,
  );

  expect(recovered?.state, RestoreReceiptState.committed);
  await fixture.preferences.reload();
  expect(fixture.preferences.getString('theme'), 'new');
  expect(await RestoreStartupGate.inspect(appDataDirectory: root), isNull);
  expect(await fixture.activeRun.exists(), isFalse);
  expect(
    (await RestoreReceiptStore(
      appDataDirectory: root,
      runId: fixture.prepared.runId,
      archived: true,
    ).readLatest())?.state,
    RestoreReceiptState.committed,
  );
}

Future<void> _expectMarkerArtifactsRemainFailClosed({
  required Directory root,
  required _MarkerlessRestoreFixture fixture,
  required RestoreReceiptState expectedReceiptState,
  required Map<File, String> artifacts,
}) async {
  await expectLater(
    RestoreStartupGate.recoverAndRequireBusinessReady(
      appDataDirectory: root,
      preferences: fixture.preferences,
    ),
    throwsA(isA<StateError>()),
  );

  for (final entry in artifacts.entries) {
    expect(await entry.key.exists(), isTrue, reason: entry.key.path);
    expect(await entry.key.readAsString(), entry.value, reason: entry.key.path);
  }
  expect(await fixture.activeRun.exists(), isTrue);
  expect(await fixture.prepared.candidateDirectory.exists(), isTrue);
  expect(
    (await RestoreReceiptStore(
      appDataDirectory: root,
      runId: fixture.prepared.runId,
    ).readLatest())?.state,
    expectedReceiptState,
  );
  expect(
    await RestoreReceiptStore(
      appDataDirectory: root,
      runId: fixture.prepared.runId,
      archived: true,
    ).runDirectory.exists(),
    isFalse,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RestoreStartupGate', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'kelivo_restore_startup_gate_test_',
      );
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('allows startup when no restore run exists', () async {
      expect(await RestoreStartupGate.inspect(appDataDirectory: root), isNull);

      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      await File(
        p.join(workspace.path, RestoreWorkspaceLock.lockFileName),
      ).create();

      expect(await RestoreStartupGate.inspect(appDataDirectory: root), isNull);
      expect(
        await RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
        ),
        isNull,
      );
    });

    test('keeps a caller-owned business lease after gate admission', () async {
      final lease = await RestoreBusinessLease.acquire(appDataDirectory: root);
      addTearDown(lease.close);

      expect(
        await RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          businessLease: lease,
        ),
        isNull,
      );
      expect(lease.isClosed, isFalse);
      await expectLater(
        RestoreBusinessLease.acquire(appDataDirectory: root),
        throwsA(isA<RestoreBusinessLeaseUnavailable>()),
      );
    });

    test(
      'does not touch a prepared run while another process lease is held',
      () async {
        SharedPreferences.setMockInitialValues({'theme': 'old'});
        final bundle = await _createBundle(
          root,
          theme: 'new',
          secretsIncluded: true,
          directoryName: 'leased_prepared_bundle',
        );
        final prepared = await RestoreBundlePreparation.prepare(
          appDataDirectory: root,
          extractedDirectory: bundle.directory,
          sourceManifestSha256: bundle.manifestSha256,
          bundleIncludesChats: false,
          bundleIncludesFiles: false,
          restoreChats: false,
          restoreFiles: false,
          createdAtUtc: DateTime.utc(2026, 7, 9, 12),
        );
        final lease = await RestoreBusinessLease.acquire(
          appDataDirectory: root,
        );
        addTearDown(lease.close);

        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
          ),
          throwsA(isA<RestoreBusinessLeaseUnavailable>()),
        );

        final pending = await RestoreStartupGate.inspect(
          appDataDirectory: root,
        );
        expect(pending?.receipt.checksum, prepared.receipt.checksum);
        expect(pending?.receipt.state, RestoreReceiptState.prepared);
        expect(pending?.markerFileName, RestoreWorkspaceLock.activeRunFileName);
        final preferences = await SharedPreferences.getInstance();
        await preferences.reload();
        expect(preferences.getString('theme'), 'old');
      },
    );

    test('discards marker-only and empty-run staging windows', () async {
      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      for (final withRunDirectory in const [false, true]) {
        final runId = withRunDirectory
            ? '12121212121212121212121212121212'
            : '34343434343434343434343434343434';
        final marker = File(
          p.join(workspace.path, RestoreWorkspaceLock.activeRunFileName),
        );
        await marker.writeAsString(runId, flush: true);
        final runDirectory = Directory(p.join(workspace.path, 'run_$runId'));
        if (withRunDirectory) await runDirectory.create();

        expect(
          await RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
          ),
          isNull,
        );
        expect(await marker.exists(), isFalse);
        expect(await runDirectory.exists(), isFalse);
      }
    });

    test(
      'durably discards strict unpublished runs from recoverable markers',
      () async {
        final markerFileNames = [
          RestoreWorkspaceLock.activeRunFileName,
          RestoreWorkspaceLock.publishingRunFileName,
          RestoreWorkspaceLock.discardingRunFileName,
        ];
        for (var index = 0; index < markerFileNames.length; index++) {
          final runId = index.toRadixString(16).padLeft(32, '0');
          final runDirectory = await _createStrictUnpublishedRun(
            root: root,
            runId: runId,
            markerFileName: markerFileNames[index],
          );

          expect(
            await RestoreStartupGate.recoverAndRequireBusinessReady(
              appDataDirectory: root,
            ),
            isNull,
          );
          expect(await runDirectory.exists(), isFalse);
          for (final marker in markerFileNames) {
            expect(
              await File(
                p.join(
                  root.path,
                  RestoreWorkspaceLock.workspaceRootName,
                  marker,
                ),
              ).exists(),
              isFalse,
            );
          }
          expect(
            await RestoreStartupGate.recoverAndRequireBusinessReady(
              appDataDirectory: root,
            ),
            isNull,
          );
        }
      },
    );

    test('resumes unpublished discard after each marker-only window', () async {
      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      for (final entry in const [
        (marker: RestoreWorkspaceLock.activeRunFileName, contents: ''),
        (
          marker: RestoreWorkspaceLock.discardingRunFileName,
          contents: 'torn-marker',
        ),
      ]) {
        final marker = File(p.join(workspace.path, entry.marker));
        await marker.writeAsString(entry.contents, flush: true);

        expect(
          await RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
          ),
          isNull,
        );
        expect(await marker.exists(), isFalse);
      }
    });

    test('resumes after the durable discarding claim is interrupted', () async {
      const runId = 'cccccccccccccccccccccccccccccccc';
      final runDirectory = await _createStrictUnpublishedRun(
        root: root,
        runId: runId,
        markerFileName: RestoreWorkspaceLock.activeRunFileName,
      );
      final durability = _ThrowAfterDiscardingMarkerDurability(
        RestorePlatformDurability(),
      );

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          durability: durability,
        ),
        throwsA(isA<StateError>()),
      );
      expect(durability.didThrow, isTrue);
      expect(await runDirectory.exists(), isTrue);
      expect(
        await File(
          p.join(
            root.path,
            RestoreWorkspaceLock.workspaceRootName,
            RestoreWorkspaceLock.discardingRunFileName,
          ),
        ).readAsString(),
        runId,
      );

      expect(
        await RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
        ),
        isNull,
      );
      expect(await runDirectory.exists(), isFalse);
    });

    test('preserves an unpublished run with an unknown entry', () async {
      const runId = 'dddddddddddddddddddddddddddddddd';
      final runDirectory = await _createStrictUnpublishedRun(
        root: root,
        runId: runId,
        markerFileName: RestoreWorkspaceLock.activeRunFileName,
      );
      final unknown = File(p.join(runDirectory.path, 'unknown'));
      await unknown.writeAsString('do not delete', flush: true);

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
        ),
        throwsA(isA<StateError>()),
      );
      expect(await unknown.readAsString(), 'do not delete');
      expect(await runDirectory.exists(), isTrue);
    });

    test('never discards cold-ack evidence without a final receipt', () async {
      const runId = 'acacacacacacacacacacacacacacacac';
      final runDirectory = await _createStrictUnpublishedRun(
        root: root,
        runId: runId,
        markerFileName: RestoreWorkspaceLock.activeRunFileName,
      );
      await File(
        p.join(runDirectory.path, RestoreSettingsColdAckStore.fileName),
      ).writeAsString('{}', flush: true);

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'restore_workspace_unpublished_cold_ack',
          ),
        ),
      );

      expect(await runDirectory.exists(), isTrue);
    });

    test('preserves a run whose marker identity is unreadable', () async {
      const runId = 'abababababababababababababababab';
      final runDirectory = await _createStrictUnpublishedRun(
        root: root,
        runId: runId,
        markerFileName: RestoreWorkspaceLock.activeRunFileName,
      );
      final marker = File(
        p.join(
          root.path,
          RestoreWorkspaceLock.workspaceRootName,
          RestoreWorkspaceLock.activeRunFileName,
        ),
      );
      await marker.writeAsString('torn-marker', flush: true);

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
        ),
        throwsA(isA<StateError>()),
      );
      expect(await marker.readAsString(), 'torn-marker');
      expect(await runDirectory.exists(), isTrue);
    });

    test(
      'preserves an unpublished run containing a linked asset entry',
      () async {
        const runId = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        final runDirectory = await _createStrictUnpublishedRun(
          root: root,
          runId: runId,
          markerFileName: RestoreWorkspaceLock.activeRunFileName,
        );
        final outside = File(p.join(root.path, 'outside'));
        await outside.writeAsString('outside', flush: true);
        final link = Link(
          p.join(runDirectory.path, 'candidate', 'images', 'linked'),
        );
        await link.parent.create(recursive: true);
        await link.create(outside.path);

        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
          ),
          throwsA(isA<StateError>()),
        );
        expect(await outside.readAsString(), 'outside');
        expect(await link.exists(), isTrue);
      },
      skip: Platform.isWindows
          ? 'Symlink setup is not portable on Windows.'
          : false,
    );

    test('never discards a run containing a final receipt file', () async {
      const runId = 'ffffffffffffffffffffffffffffffff';
      final runDirectory = await _createStrictUnpublishedRun(
        root: root,
        runId: runId,
        markerFileName: RestoreWorkspaceLock.activeRunFileName,
        includeReceiptTemp: false,
      );
      final finalReceipt = File(
        p.join(runDirectory.path, 'receipts', 'receipt_0000000000000001.json'),
      );
      await finalReceipt.parent.create();
      await finalReceipt.writeAsString('{broken', flush: true);

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await finalReceipt.exists(), isTrue);
      expect(await runDirectory.exists(), isTrue);
    });

    test('resumes a published run with a later exact receipt temp', () async {
      SharedPreferences.setMockInitialValues({'theme': 'old'});
      final preferences = await SharedPreferences.getInstance();
      final bundle = await _createBundle(
        root,
        theme: 'new',
        secretsIncluded: true,
        directoryName: 'later_receipt_temp_bundle',
      );
      final prepared = await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: bundle.directory,
        sourceManifestSha256: bundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );
      final store = RestoreReceiptStore(
        appDataDirectory: root,
        runId: prepared.runId,
      );
      final temporary = File(
        p.join(
          store.receiptDirectory.path,
          'receipt_0000000000000002.json.123456_789.tmp',
        ),
      );
      await temporary.writeAsString(
        jsonEncode(
          prepared.receipt
              .advance(
                RestoreReceiptState.oldRenamed,
                previousManifestSha256:
                    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              )
              .toJson(),
        ),
        flush: true,
      );

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
        ),
        throwsA(isA<RestoreColdRestartRequired>()),
      );
      expect(await temporary.exists(), isTrue);
      expect((await store.readHistory()).map((receipt) => receipt.state), [
        RestoreReceiptState.prepared,
        RestoreReceiptState.oldRenamed,
        RestoreReceiptState.newInstalled,
        RestoreReceiptState.verified,
        RestoreReceiptState.committed,
      ]);
    });

    test(
      'never discards a later receipt temp without a final receipt',
      () async {
        const runId = 'edededededededededededededededed';
        final runDirectory = await _createStrictUnpublishedRun(
          root: root,
          runId: runId,
          markerFileName: RestoreWorkspaceLock.activeRunFileName,
          includeReceiptTemp: false,
        );
        final temporary = File(
          p.join(
            runDirectory.path,
            'receipts',
            'receipt_0000000000000002.json.123456_789.tmp',
          ),
        );
        await temporary.parent.create();
        await temporary.writeAsString('{"partial":', flush: true);

        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'restore_workspace_unpublished_receipt_entry',
            ),
          ),
        );
        expect(await temporary.exists(), isTrue);
        expect(await runDirectory.exists(), isTrue);
      },
    );

    test('rejects a publishing marker without its run directory', () async {
      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      final marker = File(
        p.join(workspace.path, RestoreWorkspaceLock.publishingRunFileName),
      );
      await marker.writeAsString(
        '99999999999999999999999999999999',
        flush: true,
      );

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
        ),
        throwsA(isA<StateError>()),
      );
      expect(await marker.exists(), isTrue);
    });

    test(
      'recognizes a valid prepared run and blocks business startup',
      () async {
        SharedPreferences.setMockInitialValues(const {});
        final preferences = await SharedPreferences.getInstance();
        final bundle = await _createBundle(root);
        final prepared = await RestoreBundlePreparation.prepare(
          appDataDirectory: root,
          extractedDirectory: bundle.directory,
          sourceManifestSha256: bundle.manifestSha256,
          bundleIncludesChats: false,
          bundleIncludesFiles: false,
          restoreChats: false,
          restoreFiles: false,
          createdAtUtc: DateTime.utc(2026, 7, 9, 12),
        );

        final pending = await RestoreStartupGate.inspect(
          appDataDirectory: root,
        );

        expect(pending?.runId, prepared.runId);
        expect(pending?.receipt.checksum, prepared.receipt.checksum);
        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
            preferences: preferences,
          ),
          throwsA(isA<RestoreColdRestartRequired>()),
        );
      },
    );

    test('recovers a prepared run through committed before business', () async {
      SharedPreferences.setMockInitialValues({'theme': 'old'});
      final preferences = await SharedPreferences.getInstance();
      final bundle = await _createBundle(
        root,
        theme: 'new',
        secretsIncluded: true,
        directoryName: 'recovery_bundle',
      );
      final prepared = await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: bundle.directory,
        sourceManifestSha256: bundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
        ),
        throwsA(isA<RestoreColdRestartRequired>()),
      );
      await simulateRestoreColdProcessBoundary(root);
      expect(
        (await RestoreStartupGate.inspect(
          appDataDirectory: root,
        ))?.receipt.state,
        RestoreReceiptState.committed,
      );
      final result = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: root,
        preferences: preferences,
      );
      expect(result?.state, RestoreReceiptState.committed);
      await preferences.reload();

      expect(preferences.getString('theme'), 'new');
      final receiptStore = RestoreReceiptStore(
        appDataDirectory: root,
        runId: prepared.runId,
        archived: true,
      );
      expect(
        (await receiptStore.readHistory()).map((receipt) => receipt.state),
        [
          RestoreReceiptState.prepared,
          RestoreReceiptState.oldRenamed,
          RestoreReceiptState.newInstalled,
          RestoreReceiptState.verified,
          RestoreReceiptState.committed,
        ],
      );
      final previousSettings = File(
        p.join(
          receiptStore.runDirectory.path,
          RestorePreviousStore.previousDirectoryName,
          RestorePreviousStore.settingsFileName,
        ),
      );
      expect(jsonDecode(await previousSettings.readAsString()), {
        'theme': 'old',
      });

      await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: root,
        preferences: preferences,
      );
      expect((await receiptStore.readHistory()), hasLength(5));
    });

    test(
      'same process cannot acknowledge after closing and reacquiring lease',
      () async {
        SharedPreferences.setMockInitialValues({'theme': 'old'});
        final preferences = await SharedPreferences.getInstance();
        final bundle = await _createBundle(
          root,
          theme: 'new',
          secretsIncluded: true,
          directoryName: 'same_lease_cold_ack',
        );
        await RestoreBundlePreparation.prepare(
          appDataDirectory: root,
          extractedDirectory: bundle.directory,
          sourceManifestSha256: bundle.manifestSha256,
          bundleIncludesChats: false,
          bundleIncludesFiles: false,
          restoreChats: false,
          restoreFiles: false,
          createdAtUtc: DateTime.utc(2026, 7, 9, 12),
        );
        final lease = await RestoreBusinessLease.acquire(
          appDataDirectory: root,
        );
        addTearDown(lease.close);

        for (var attempt = 0; attempt < 2; attempt++) {
          await expectLater(
            RestoreStartupGate.recoverAndRequireBusinessReady(
              appDataDirectory: root,
              preferences: preferences,
              businessLease: lease,
            ),
            throwsA(isA<RestoreColdRestartRequired>()),
          );
        }
        expect(
          (await RestoreStartupGate.inspect(
            appDataDirectory: root,
          ))?.receipt.state,
          RestoreReceiptState.committed,
        );

        await lease.close();
        final reacquired = await RestoreBusinessLease.acquire(
          appDataDirectory: root,
        );
        expect(reacquired.processId, lease.processId);
        expect(reacquired.instanceId, isNot(lease.instanceId));
        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
            preferences: preferences,
            businessLease: reacquired,
          ),
          throwsA(isA<RestoreColdRestartRequired>()),
        );
        await reacquired.close();
        expect(
          await RestoreStartupGate.inspect(appDataDirectory: root),
          isNotNull,
        );

        await simulateRestoreColdProcessBoundary(root);
        final admitted =
            await RestoreStartupGate.recoverAndRequireBusinessReady(
              appDataDirectory: root,
              preferences: preferences,
            );
        expect(admitted?.state, RestoreReceiptState.committed);
        expect(
          await RestoreStartupGate.inspect(appDataDirectory: root),
          isNull,
        );
      },
    );

    test(
      'terminal run rejects unknown top-level files, directories, and links',
      () async {
        SharedPreferences.setMockInitialValues({'theme': 'old'});
        final preferences = await SharedPreferences.getInstance();
        final bundle = await _createBundle(
          root,
          theme: 'new',
          secretsIncluded: true,
          directoryName: 'terminal_unknown_entry',
        );
        final prepared = await RestoreBundlePreparation.prepare(
          appDataDirectory: root,
          extractedDirectory: bundle.directory,
          sourceManifestSha256: bundle.manifestSha256,
          bundleIncludesChats: false,
          bundleIncludesFiles: false,
          restoreChats: false,
          restoreFiles: false,
          createdAtUtc: DateTime.utc(2026, 7, 9, 12),
        );
        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
            preferences: preferences,
          ),
          throwsA(isA<RestoreColdRestartRequired>()),
        );
        final runDirectory = RestoreReceiptStore(
          appDataDirectory: root,
          runId: prepared.runId,
        ).runDirectory;
        final archivedDirectory = RestoreReceiptStore(
          appDataDirectory: root,
          runId: prepared.runId,
          archived: true,
        ).runDirectory;

        Future<void> expectRejected(FileSystemEntity unknown) async {
          await expectLater(
            RestoreStartupGate.inspect(appDataDirectory: root),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                'restore_startup_run_entry',
              ),
            ),
          );
          await expectLater(
            RestoreStartupGate.recoverAndRequireBusinessReady(
              appDataDirectory: root,
              preferences: preferences,
            ),
            throwsA(isA<StateError>()),
          );
          expect(
            await FileSystemEntity.type(unknown.path, followLinks: false),
            isNot(FileSystemEntityType.notFound),
          );
          expect(await runDirectory.exists(), isTrue);
          expect(await archivedDirectory.exists(), isFalse);
        }

        final unknownFile = File(p.join(runDirectory.path, 'unknown_file'));
        await unknownFile.writeAsString('preserve', flush: true);
        await expectRejected(unknownFile);
        await unknownFile.delete();

        final unknownDirectory = Directory(
          p.join(runDirectory.path, 'unknown_directory'),
        );
        await unknownDirectory.create();
        await expectRejected(unknownDirectory);
        await unknownDirectory.delete();

        if (!Platform.isWindows) {
          final outside = File(p.join(root.path, 'outside_terminal'));
          await outside.writeAsString('outside', flush: true);
          final unknownLink = Link(p.join(runDirectory.path, 'unknown_link'));
          await unknownLink.create(outside.path);
          await expectRejected(unknownLink);
          expect(await outside.readAsString(), 'outside');
        }
      },
    );

    test('rewritten terminal settings require another cold readback', () async {
      SharedPreferences.setMockInitialValues({'theme': 'old'});
      final preferences = await SharedPreferences.getInstance();
      final bundle = await _createBundle(
        root,
        theme: 'new',
        secretsIncluded: true,
        directoryName: 'rewritten_cold_ack',
      );
      await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: bundle.directory,
        sourceManifestSha256: bundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
        ),
        throwsA(isA<RestoreColdRestartRequired>()),
      );
      await simulateRestoreColdProcessBoundary(root);
      expect(await preferences.setString('theme', 'old'), isTrue);
      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
        ),
        throwsA(isA<RestoreColdRestartRequired>()),
      );
      await simulateRestoreColdProcessBoundary(root);
      expect(preferences.getString('theme'), 'new');
      expect(
        await RestoreStartupGate.inspect(appDataDirectory: root),
        isNotNull,
      );

      final admitted = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: root,
        preferences: preferences,
      );
      expect(admitted?.state, RestoreReceiptState.committed);
      expect(await RestoreStartupGate.inspect(appDataDirectory: root), isNull);
    });

    test('resumes terminal archival and admits the next restore run', () async {
      SharedPreferences.setMockInitialValues({'theme': 'old'});
      final preferences = await SharedPreferences.getInstance();
      final firstBundle = await _createBundle(
        root,
        theme: 'first',
        secretsIncluded: true,
        directoryName: 'first_terminal_bundle',
      );
      final first = await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: firstBundle.directory,
        sourceManifestSha256: firstBundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );
      final durability = _ThrowAfterArchivingMarkerDurability(
        RestorePlatformDurability(),
      );

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
        ),
        throwsA(isA<RestoreColdRestartRequired>()),
      );
      await simulateRestoreColdProcessBoundary(root);
      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
          durability: durability,
        ),
        throwsA(isA<StateError>()),
      );
      final interrupted = await RestoreStartupGate.inspect(
        appDataDirectory: root,
      );
      expect(interrupted?.receipt.state, RestoreReceiptState.committed);
      expect(
        interrupted?.markerFileName,
        RestoreWorkspaceLock.archivingRunFileName,
      );
      expect(await preferences.setString('theme', 'old'), isTrue);

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
        ),
        throwsA(isA<RestoreColdRestartRequired>()),
      );
      await simulateRestoreColdProcessBoundary(root);
      final resumed = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: root,
        preferences: preferences,
      );
      expect(resumed?.state, RestoreReceiptState.committed);
      await preferences.reload();
      expect(preferences.getString('theme'), 'first');
      expect(await RestoreStartupGate.inspect(appDataDirectory: root), isNull);
      expect(
        (await RestoreReceiptStore(
          appDataDirectory: root,
          runId: first.runId,
          archived: true,
        ).readLatest())?.state,
        RestoreReceiptState.committed,
      );

      final secondBundle = await _createBundle(
        root,
        theme: 'second',
        secretsIncluded: true,
        directoryName: 'second_bundle',
      );
      final second = await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: secondBundle.directory,
        sourceManifestSha256: secondBundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 13),
      );
      final pending = await RestoreStartupGate.inspect(appDataDirectory: root);
      expect(pending?.runId, second.runId);
      expect(pending?.receipt.state, RestoreReceiptState.prepared);
    });

    test(
      'keeps terminal admission after the run rename but before its barriers',
      () async {
        SharedPreferences.setMockInitialValues({'theme': 'old'});
        final preferences = await SharedPreferences.getInstance();
        final bundle = await _createBundle(
          root,
          theme: 'new',
          secretsIncluded: true,
          directoryName: 'raw_terminal_archive_rename',
        );
        final prepared = await RestoreBundlePreparation.prepare(
          appDataDirectory: root,
          extractedDirectory: bundle.directory,
          sourceManifestSha256: bundle.manifestSha256,
          bundleIncludesChats: false,
          bundleIncludesFiles: false,
          restoreChats: false,
          restoreFiles: false,
          createdAtUtc: DateTime.utc(2026, 7, 9, 12),
        );

        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
            preferences: preferences,
          ),
          throwsA(isA<RestoreColdRestartRequired>()),
        );
        await simulateRestoreColdProcessBoundary(root);
        final workspaceLock = RestoreWorkspaceLock(appDataDirectory: root);
        final activeRun = Directory(
          p.join(workspaceLock.workspaceRoot.path, 'run_${prepared.runId}'),
        );
        final completedRun = Directory(
          p.join(workspaceLock.completedRunsRoot.path, 'run_${prepared.runId}'),
        );
        final durability = _InterruptAfterTerminalRunRawRenameDurability(
          RestorePlatformDurability(),
          source: activeRun,
          target: completedRun,
        );
        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
            preferences: preferences,
            durability: durability,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'injected_terminal_run_raw_rename',
            ),
          ),
        );
        expect(durability.didInterrupt, isTrue);
        expect(await activeRun.exists(), isFalse);
        expect(await completedRun.exists(), isTrue);
        expect(
          await File(
            p.join(
              workspaceLock.workspaceRoot.path,
              RestoreWorkspaceLock.archivingRunFileName,
            ),
          ).readAsString(),
          prepared.runId,
        );

        final interrupted = await RestoreStartupGate.inspect(
          appDataDirectory: root,
        );
        expect(interrupted, isNotNull);
        expect(interrupted!.runId, prepared.runId);
        expect(interrupted.receipt.state, RestoreReceiptState.committed);
        expect(
          interrupted.markerFileName,
          RestoreWorkspaceLock.archivingRunFileName,
        );

        final syncFailure = _FailingArchiveParentSyncDurability(
          RestorePlatformDurability(),
          completedRunsRoot: workspaceLock.completedRunsRoot,
          workspaceRoot: workspaceLock.workspaceRoot,
        );
        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
            preferences: preferences,
            durability: syncFailure,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'injected_terminal_archive_source_parent_sync',
            ),
          ),
        );
        expect(syncFailure.didFail, isTrue);
        expect(syncFailure.observedParentSyncs, [
          p.normalize(p.absolute(workspaceLock.completedRunsRoot.path)),
          p.normalize(p.absolute(workspaceLock.workspaceRoot.path)),
        ]);
        expect(
          await File(
            p.join(
              workspaceLock.workspaceRoot.path,
              RestoreWorkspaceLock.archivingRunFileName,
            ),
          ).readAsString(),
          prepared.runId,
        );
        expect(
          (await RestoreStartupGate.inspect(
            appDataDirectory: root,
          ))?.runInCompletedDirectory,
          isTrue,
        );

        final resumed = await RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
        );
        expect(resumed?.state, RestoreReceiptState.committed);
        expect(
          await RestoreStartupGate.inspect(appDataDirectory: root),
          isNull,
        );
        expect(
          (await RestoreReceiptStore(
            appDataDirectory: root,
            runId: prepared.runId,
            archived: true,
          ).readLatest())?.state,
          RestoreReceiptState.committed,
        );
      },
    );

    test(
      'reclaims a legacy markerless terminal run before archiving it',
      () async {
        SharedPreferences.setMockInitialValues({'theme': 'old'});
        final preferences = await SharedPreferences.getInstance();
        final bundle = await _createBundle(
          root,
          theme: 'new',
          secretsIncluded: true,
          directoryName: 'legacy_markerless_terminal',
        );
        final prepared = await RestoreBundlePreparation.prepare(
          appDataDirectory: root,
          extractedDirectory: bundle.directory,
          sourceManifestSha256: bundle.manifestSha256,
          bundleIncludesChats: false,
          bundleIncludesFiles: false,
          restoreChats: false,
          restoreFiles: false,
          createdAtUtc: DateTime.utc(2026, 7, 9, 12),
        );

        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
            preferences: preferences,
          ),
          throwsA(isA<RestoreColdRestartRequired>()),
        );
        await simulateRestoreColdProcessBoundary(root);

        final workspaceLock = RestoreWorkspaceLock(appDataDirectory: root);
        await workspaceLock.synchronized(() async {
          final publishing = File(
            p.join(
              workspaceLock.workspaceRoot.path,
              RestoreWorkspaceLock.publishingRunFileName,
            ),
          );
          expect(await publishing.readAsString(), prepared.runId);
          await publishing.delete();
          await RestorePlatformDurability().syncDirectory(
            workspaceLock.workspaceRoot,
            fullBarrier: true,
          );
        });
        final markerless = await RestoreStartupGate.inspect(
          appDataDirectory: root,
        );
        expect(markerless?.runId, prepared.runId);
        expect(markerless?.markerFileName, isNull);

        final activeRun = Directory(
          p.join(workspaceLock.workspaceRoot.path, 'run_${prepared.runId}'),
        );
        final completedRun = Directory(
          p.join(workspaceLock.completedRunsRoot.path, 'run_${prepared.runId}'),
        );
        final durability = _InterruptAfterTerminalRunRawRenameDurability(
          RestorePlatformDurability(),
          source: activeRun,
          target: completedRun,
        );
        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
            preferences: preferences,
            durability: durability,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'injected_terminal_run_raw_rename',
            ),
          ),
        );
        expect(durability.didInterrupt, isTrue);
        expect(await activeRun.exists(), isFalse);
        expect(await completedRun.exists(), isTrue);
        expect(
          await File(
            p.join(
              workspaceLock.workspaceRoot.path,
              RestoreWorkspaceLock.archivingRunFileName,
            ),
          ).readAsString(),
          prepared.runId,
        );

        final interrupted = await RestoreStartupGate.inspect(
          appDataDirectory: root,
        );
        expect(interrupted?.runId, prepared.runId);
        expect(
          interrupted?.markerFileName,
          RestoreWorkspaceLock.archivingRunFileName,
        );
        expect(interrupted?.runInCompletedDirectory, isTrue);

        final resumed = await RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
        );
        expect(resumed?.state, RestoreReceiptState.committed);
        expect(
          await RestoreStartupGate.inspect(appDataDirectory: root),
          isNull,
        );
      },
    );

    group('legacy archiving marker recovery', () {
      for (final payloadKind in const ['empty', 'truncated', 'full']) {
        test('discards an exact $payloadKind archiving temp beside an active '
            'terminal run and converges', () async {
          final fixture = await _prepareMarkerlessTerminalFixture(
            root: root,
            directoryName: 'archiving_temp_$payloadKind',
          );
          final temporary = File(
            p.join(
              fixture.workspaceLock.workspaceRoot.path,
              RestoreWorkspaceLock.archivingRunTemporaryFileName,
            ),
          );
          final canonical = File(
            p.join(
              fixture.workspaceLock.workspaceRoot.path,
              RestoreWorkspaceLock.archivingRunFileName,
            ),
          );
          await _writeDurableMarkerArtifact(
            file: temporary,
            contents: _markerPayload(payloadKind, fixture.prepared.runId),
            workspaceRoot: fixture.workspaceLock.workspaceRoot,
          );
          expect(await canonical.exists(), isFalse);

          await _expectMarkerlessTerminalConverges(
            root: root,
            fixture: fixture,
          );

          expect(await temporary.exists(), isFalse);
          expect(await canonical.exists(), isFalse);
        });
      }

      for (final payloadKind in const ['empty', 'truncated']) {
        test(
          'downgrades a malformed $payloadKind canonical archiving marker '
          'to markerless only for one active terminal run and converges',
          () async {
            final fixture = await _prepareMarkerlessTerminalFixture(
              root: root,
              directoryName: 'archiving_canonical_$payloadKind',
            );
            final canonical = File(
              p.join(
                fixture.workspaceLock.workspaceRoot.path,
                RestoreWorkspaceLock.archivingRunFileName,
              ),
            );
            await _writeDurableMarkerArtifact(
              file: canonical,
              contents: _markerPayload(payloadKind, fixture.prepared.runId),
              workspaceRoot: fixture.workspaceLock.workspaceRoot,
            );

            await _expectMarkerlessTerminalConverges(
              root: root,
              fixture: fixture,
            );

            expect(await canonical.exists(), isFalse);
          },
        );
      }

      for (final scenario in const [
        (
          name: 'wrong-prefix exact temp',
          temporaryPayload: 'wrongPrefix',
          canonicalPayload: null,
        ),
        (
          name: 'wrong-prefix truncated canonical',
          temporaryPayload: null,
          canonicalPayload: 'wrongPrefix',
        ),
        (
          name: 'wrong-ID full canonical',
          temporaryPayload: null,
          canonicalPayload: 'wrongId',
        ),
        (
          name: 'coexisting exact temp and canonical',
          temporaryPayload: 'full',
          canonicalPayload: 'full',
        ),
      ]) {
        test(
          'keeps ${scenario.name} beside an active terminal run fail-closed',
          () async {
            final fixture = await _prepareMarkerlessTerminalFixture(
              root: root,
              directoryName: 'archiving_strict_${scenario.name}',
            );
            final temporary = File(
              p.join(
                fixture.workspaceLock.workspaceRoot.path,
                RestoreWorkspaceLock.archivingRunTemporaryFileName,
              ),
            );
            final canonical = File(
              p.join(
                fixture.workspaceLock.workspaceRoot.path,
                RestoreWorkspaceLock.archivingRunFileName,
              ),
            );
            final artifacts = <File, String>{};
            final temporaryPayload = scenario.temporaryPayload;
            if (temporaryPayload != null) {
              final contents = _markerPayload(
                temporaryPayload,
                fixture.prepared.runId,
              );
              await _writeDurableMarkerArtifact(
                file: temporary,
                contents: contents,
                workspaceRoot: fixture.workspaceLock.workspaceRoot,
              );
              artifacts[temporary] = contents;
            }
            final canonicalPayload = scenario.canonicalPayload;
            if (canonicalPayload != null) {
              final contents = _markerPayload(
                canonicalPayload,
                fixture.prepared.runId,
              );
              await _writeDurableMarkerArtifact(
                file: canonical,
                contents: contents,
                workspaceRoot: fixture.workspaceLock.workspaceRoot,
              );
              artifacts[canonical] = contents;
            }

            await _expectMarkerArtifactsRemainFailClosed(
              root: root,
              fixture: fixture,
              expectedReceiptState: RestoreReceiptState.committed,
              artifacts: artifacts,
            );
          },
        );
      }

      test('keeps an exact archiving temp and its active nonterminal run '
          'fail-closed without deleting evidence', () async {
        final fixture = await _prepareMarkerlessNonterminalFixture(
          root: root,
          directoryName: 'archiving_temp_nonterminal',
        );
        final temporary = File(
          p.join(
            fixture.workspaceLock.workspaceRoot.path,
            RestoreWorkspaceLock.archivingRunTemporaryFileName,
          ),
        );
        final contents = fixture.prepared.runId;
        await _writeDurableMarkerArtifact(
          file: temporary,
          contents: contents,
          workspaceRoot: fixture.workspaceLock.workspaceRoot,
        );

        await _expectMarkerArtifactsRemainFailClosed(
          root: root,
          fixture: fixture,
          expectedReceiptState: RestoreReceiptState.prepared,
          artifacts: {temporary: contents},
        );
      });

      for (final payloadKind in const ['empty', 'truncated']) {
        test(
          'keeps a malformed $payloadKind canonical archiving marker and its '
          'active nonterminal run fail-closed',
          () async {
            final fixture = await _prepareMarkerlessNonterminalFixture(
              root: root,
              directoryName: 'archiving_canonical_nonterminal_$payloadKind',
            );
            final canonical = File(
              p.join(
                fixture.workspaceLock.workspaceRoot.path,
                RestoreWorkspaceLock.archivingRunFileName,
              ),
            );
            final contents = _markerPayload(
              payloadKind,
              fixture.prepared.runId,
            );
            await _writeDurableMarkerArtifact(
              file: canonical,
              contents: contents,
              workspaceRoot: fixture.workspaceLock.workspaceRoot,
            );

            await _expectMarkerArtifactsRemainFailClosed(
              root: root,
              fixture: fixture,
              expectedReceiptState: RestoreReceiptState.prepared,
              artifacts: {canonical: contents},
            );
          },
        );
      }
    });

    for (final point in const [
      _LogicalCutoverInterruption.claimed,
      _LogicalCutoverInterruption.previousReady,
      _LogicalCutoverInterruption.oldRenamedPublished,
      _LogicalCutoverInterruption.candidateInstalled,
      _LogicalCutoverInterruption.newInstalledPublished,
      _LogicalCutoverInterruption.liveVerified,
      _LogicalCutoverInterruption.verifiedPublished,
      _LogicalCutoverInterruption.committedPublished,
    ]) {
      test('resumes after logical interruption at ${point.name}', () async {
        SharedPreferences.setMockInitialValues({'theme': 'old'});
        final preferences = await SharedPreferences.getInstance();
        final bundle = await _createBundle(
          root,
          theme: 'new',
          secretsIncluded: true,
          directoryName: 'interrupted_${point.name}',
        );
        final prepared = await RestoreBundlePreparation.prepare(
          appDataDirectory: root,
          extractedDirectory: bundle.directory,
          sourceManifestSha256: bundle.manifestSha256,
          bundleIncludesChats: false,
          bundleIncludesFiles: false,
          restoreChats: false,
          restoreFiles: false,
          createdAtUtc: DateTime.utc(2026, 7, 9, 12),
        );
        final durability = _InterruptingCutoverDurability(
          RestorePlatformDurability(),
          point,
        );

        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
            preferences: preferences,
            durability: durability,
          ),
          throwsA(isA<StateError>()),
        );
        expect(durability.didInterrupt, isTrue);
        if (point == _LogicalCutoverInterruption.committedPublished) {
          expect(await preferences.setString('theme', 'old'), isTrue);
        }

        await _recoverAcrossColdRestart(
          appDataDirectory: root,
          preferences: preferences,
        );
        await preferences.reload();
        final receiptStore = RestoreReceiptStore(
          appDataDirectory: root,
          runId: prepared.runId,
          archived: true,
        );
        expect(preferences.getString('theme'), 'new');
        expect(
          (await receiptStore.readHistory()).map((receipt) => receipt.state),
          [
            RestoreReceiptState.prepared,
            RestoreReceiptState.oldRenamed,
            RestoreReceiptState.newInstalled,
            RestoreReceiptState.verified,
            RestoreReceiptState.committed,
          ],
        );
      });
    }

    test(
      'retries verified rollback when a durable rollingBack temp exists',
      () async {
        SharedPreferences.setMockInitialValues({'theme': 'old'});
        final fixture = await _prepareCompleteRollbackBundle(
          root: root,
          directoryName: 'verified_rolling_back_temp',
        );
        final preferenceStore = _FailVerifiedRetryPreferencesStore({
          'flutter.theme': 'old',
        });
        SharedPreferencesStorePlatform.instance = preferenceStore;
        final preferences = await SharedPreferences.getInstance();
        final verifiedDurability = _InterruptingCutoverDurability(
          RestorePlatformDurability(),
          _LogicalCutoverInterruption.verifiedPublished,
        );

        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
            preferences: preferences,
            durability: verifiedDurability,
          ),
          throwsA(isA<StateError>()),
        );
        expect(verifiedDurability.didInterrupt, isTrue);

        final activeReceiptStore = RestoreReceiptStore(
          appDataDirectory: root,
          runId: fixture.prepared.runId,
        );
        final verifiedHistory = await activeReceiptStore.readHistory();
        expect(verifiedHistory.map((receipt) => receipt.state), [
          RestoreReceiptState.prepared,
          RestoreReceiptState.oldRenamed,
          RestoreReceiptState.newInstalled,
          RestoreReceiptState.verified,
        ]);
        expect(verifiedHistory.map((receipt) => receipt.sequence), [
          1,
          2,
          3,
          4,
        ]);
        final verified = verifiedHistory.last;
        final stagedRollingBack = verified.advance(
          RestoreReceiptState.rollingBack,
        );
        final staleTemporary = File(
          p.join(
            activeReceiptStore.receiptDirectory.path,
            'receipt_0000000000000005.json.123456_789.tmp',
          ),
        );
        final durability = RestorePlatformDurability();
        await staleTemporary.create(exclusive: true);
        await durability.restrictFile(staleTemporary);
        await staleTemporary.writeAsString(
          jsonEncode(stagedRollingBack.toJson()),
          flush: true,
        );
        await durability.syncFile(staleTemporary, fullBarrier: true);

        final stagedReceipt = RestoreReceipt.fromJson(
          jsonDecode(await staleTemporary.readAsString()) as Map,
        );
        expect(stagedReceipt.sequence, 5);
        expect(stagedReceipt.state, RestoreReceiptState.rollingBack);
        expect(stagedReceipt.runId, fixture.prepared.runId);
        expect(stagedReceipt.previousChecksum, verified.checksum);
        expect(stagedReceipt.checksum, stagedRollingBack.checksum);

        preferenceStore.armVerifiedTargetFailure();
        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
            preferences: preferences,
          ),
          throwsA(
            isA<RestoreColdRestartRequired>().having(
              (error) => error.state,
              'state',
              RestoreReceiptState.rolledBack,
            ),
          ),
        );
        expect(preferenceStore.verifiedTargetFailures, 1);

        final activeHistory = await activeReceiptStore.readHistory();
        expect(activeHistory.map((receipt) => receipt.state), [
          RestoreReceiptState.prepared,
          RestoreReceiptState.oldRenamed,
          RestoreReceiptState.newInstalled,
          RestoreReceiptState.verified,
          RestoreReceiptState.rollingBack,
          RestoreReceiptState.rolledBack,
        ]);
        expect(activeHistory.map((receipt) => receipt.sequence), [
          1,
          2,
          3,
          4,
          5,
          6,
        ]);
        expect(activeHistory[4].checksum, stagedReceipt.checksum);
        expect(activeHistory[4].previousChecksum, verified.checksum);
        expect(await staleTemporary.exists(), isTrue);
        expect(
          RestoreReceipt.fromJson(
            jsonDecode(await staleTemporary.readAsString()) as Map,
          ).checksum,
          activeHistory[4].checksum,
        );

        await preferences.reload();
        expect(preferences.getString('theme'), 'old');
        expect(await _rollbackConversationIds(fixture.liveDatabase), ['old']);
        expect(await fixture.liveOldUpload.readAsString(), 'old asset');
        expect(await fixture.liveNewUpload.exists(), isFalse);
        final candidateDirectory = fixture.prepared.candidateDirectory;
        expect(
          await _rollbackConversationIds(
            File(p.join(candidateDirectory.path, 'database', 'kelivo.sqlite')),
          ),
          ['new'],
        );
        expect(
          await File(
            p.join(candidateDirectory.path, 'upload', 'new.txt'),
          ).readAsString(),
          'new asset',
        );
        final previousDirectory = Directory(
          p.join(
            activeReceiptStore.runDirectory.path,
            RestorePreviousStore.previousDirectoryName,
          ),
        );
        expect(
          (await previousDirectory
                .list(followLinks: false)
                .map((entity) => p.basename(entity.path))
                .toList()
            ..sort()),
          [
            RestorePreviousStore.manifestFileName,
            RestorePreviousStore.settingsFileName,
          ],
        );

        final activeAck = await RestoreSettingsColdAckStore(
          runDirectory: activeReceiptStore.runDirectory,
        ).read();
        expect(activeAck, isNotNull);
        expect(activeAck!.expected, RestoreSettingsColdAckExpected.before);
        expect(activeAck.terminalReceiptChecksum, activeHistory.last.checksum);

        await simulateRestoreColdProcessBoundary(root);
        preferenceStore.resetMutationAttempts();
        final result = await RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
        );
        expect(result?.state, RestoreReceiptState.rolledBack);
        expect(preferenceStore.mutationAttempts, 0);
        expect(
          await RestoreStartupGate.inspect(appDataDirectory: root),
          isNull,
        );

        final archivedReceiptStore = RestoreReceiptStore(
          appDataDirectory: root,
          runId: fixture.prepared.runId,
          archived: true,
        );
        final archivedHistory = await archivedReceiptStore.readHistory();
        expect(
          archivedHistory.map((receipt) => receipt.state),
          activeHistory.map((receipt) => receipt.state),
        );
        final archivedTemporary = File(
          p.join(
            archivedReceiptStore.receiptDirectory.path,
            p.basename(staleTemporary.path),
          ),
        );
        expect(await archivedTemporary.exists(), isTrue);
        expect(
          RestoreReceipt.fromJson(
            jsonDecode(await archivedTemporary.readAsString()) as Map,
          ).checksum,
          archivedHistory[4].checksum,
        );
        final archivedAck = await RestoreSettingsColdAckStore(
          runDirectory: archivedReceiptStore.runDirectory,
        ).read();
        expect(archivedAck?.expected, RestoreSettingsColdAckExpected.before);
        expect(
          archivedAck?.terminalReceiptChecksum,
          archivedHistory.last.checksum,
        );
      },
    );

    for (final point in const [
      _LogicalCutoverInterruption.rollingBackPublished,
      _LogicalCutoverInterruption.rollbackVerified,
      _LogicalCutoverInterruption.rolledBackPublished,
    ]) {
      test('resumes rollback interruption at ${point.name}', () async {
        SharedPreferences.setMockInitialValues({'theme': 'old'});
        final bundle = await _createBundle(
          root,
          theme: 'new',
          secretsIncluded: true,
          directoryName: 'rollback_interrupted_${point.name}',
        );
        final prepared = await RestoreBundlePreparation.prepare(
          appDataDirectory: root,
          extractedDirectory: bundle.directory,
          sourceManifestSha256: bundle.manifestSha256,
          bundleIncludesChats: false,
          bundleIncludesFiles: false,
          restoreChats: false,
          restoreFiles: false,
          createdAtUtc: DateTime.utc(2026, 7, 9, 12),
        );
        SharedPreferencesStorePlatform.instance =
            _FailingNthSetPreferencesStore({
              'flutter.theme': 'old',
            }, failOnCall: 2);
        final preferences = await SharedPreferences.getInstance();
        final durability = _InterruptingCutoverDurability(
          RestorePlatformDurability(),
          point,
        );

        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
            preferences: preferences,
            durability: durability,
          ),
          throwsA(isA<RestoreCutoverRollbackException>()),
        );
        expect(durability.didInterrupt, isTrue);
        if (point == _LogicalCutoverInterruption.rolledBackPublished) {
          expect(await preferences.setString('theme', 'new'), isTrue);
        }

        final result = await _recoverAcrossColdRestart(
          appDataDirectory: root,
          preferences: preferences,
        );
        expect(result?.state, RestoreReceiptState.rolledBack);
        await preferences.reload();
        expect(preferences.getString('theme'), 'old');
        expect(
          (await RestoreReceiptStore(
            appDataDirectory: root,
            runId: prepared.runId,
            archived: true,
          ).readHistory()).map((receipt) => receipt.state),
          [
            RestoreReceiptState.prepared,
            RestoreReceiptState.oldRenamed,
            RestoreReceiptState.newInstalled,
            RestoreReceiptState.rollingBack,
            RestoreReceiptState.rolledBack,
          ],
        );
      });
    }

    test('keeps a divergent committed terminal run fail-closed', () async {
      SharedPreferences.setMockInitialValues({'theme': 'old'});
      final preferences = await SharedPreferences.getInstance();
      final bundle = await _createBundle(
        root,
        theme: 'new',
        secretsIncluded: true,
        directoryName: 'divergent_terminal',
      );
      await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: bundle.directory,
        sourceManifestSha256: bundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );
      final durability = _InterruptingCutoverDurability(
        RestorePlatformDurability(),
        _LogicalCutoverInterruption.committedPublished,
      );

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
          durability: durability,
        ),
        throwsA(isA<StateError>()),
      );
      expect(durability.didInterrupt, isTrue);
      expect(await preferences.setString('theme', 'unexpected'), isTrue);

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'restore_settings_projection:theme',
          ),
        ),
      );
      final pending = await RestoreStartupGate.inspect(appDataDirectory: root);
      expect(pending?.receipt.state, RestoreReceiptState.committed);
      expect(
        pending?.markerFileName,
        RestoreWorkspaceLock.publishingRunFileName,
      );
    });

    test('recognizes an interrupted publication phase marker', () async {
      final bundle = await _createBundle(root);
      final prepared = await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: bundle.directory,
        sourceManifestSha256: bundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );
      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await File(
        p.join(workspace.path, RestoreWorkspaceLock.activeRunFileName),
      ).rename(
        p.join(workspace.path, RestoreWorkspaceLock.publishingRunFileName),
      );

      final pending = await RestoreStartupGate.inspect(appDataDirectory: root);

      expect(pending?.runId, prepared.runId);
      expect(
        pending?.markerFileName,
        RestoreWorkspaceLock.publishingRunFileName,
      );
    });

    test('rejects a prepared run whose candidate changed', () async {
      final bundle = await _createBundle(root);
      final prepared = await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: bundle.directory,
        sourceManifestSha256: bundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );
      await File(
        p.join(prepared.candidateDirectory.path, 'settings.json'),
      ).writeAsString('{"theme":"changed"}', flush: true);

      await expectLater(
        RestoreStartupGate.inspect(appDataDirectory: root),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown workspace entries', () async {
      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      await File(p.join(workspace.path, 'unknown')).writeAsString('value');

      await expectLater(
        RestoreStartupGate.inspect(appDataDirectory: root),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects a marker without its matching run directory', () async {
      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      await File(
        p.join(workspace.path, RestoreWorkspaceLock.activeRunFileName),
      ).writeAsString('0123456789abcdef0123456789abcdef', flush: true);

      await expectLater(
        RestoreStartupGate.inspect(appDataDirectory: root),
        throwsA(isA<StateError>()),
      );
    });
  });
}
