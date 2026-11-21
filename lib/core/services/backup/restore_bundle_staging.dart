import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../database/app_database.dart';
import '../../database/backup_content_filter.dart';
import '../../models/backup_scope.dart';
import '../../database/backup_portability.dart';
import '../../database/extension_entity_store.dart';
import '../../database/schema_migrations.dart';
import '../../database/business_repository.dart';
import '../../database/business_restore_service.dart';
import '../../database/chat_database_repository.dart';
import 'backup_cancel_token.dart';
import 'backup_file_digest.dart';
import 'backup_archive_limits.dart';
import 'backup_isolate_runner.dart';
import 'backup_settings_validator.dart';
import 'backup_task_progress.dart';
import 'restore_durability.dart';
import 'restore_diagnostic_exception.dart';
import '../../../utils/app_directories.dart';
import 'restore_workspace_lock.dart';

typedef ValidatedRestoreEntry = ({int bytes, String sha256});
typedef _StagedRestoreEntry = ValidatedRestoreEntry;
typedef _PreparedDatabase = ({
  ChatDatabaseSnapshotInfo info,
  _StagedRestoreEntry entry,
});
typedef _StageFiles = ({
  String source,
  String candidate,
  bool consumeExtractedFiles,
  Set<String> roots,
  Map<String, _StagedRestoreEntry> entries,
});

final class ValidatedRestoreCandidate {
  ValidatedRestoreCandidate({
    required this.includeChats,
    required this.includeFiles,
    required Set<String> assetRoots,
    required this.manifestSha256,
    required Map<String, ValidatedRestoreEntry> entries,
    required this.databaseInfo,
  }) : entries = Map.unmodifiable(entries),
       assetRoots = Set.unmodifiable(assetRoots);

  final bool includeChats;
  final bool includeFiles;
  final Set<String> assetRoots;
  final String manifestSha256;
  final Map<String, ValidatedRestoreEntry> entries;
  final ChatDatabaseSnapshotInfo? databaseInfo;
}

final class StagedRestoreBundle {
  const StagedRestoreBundle._({
    required this.runId,
    required this.workspace,
    required this.payloadDirectory,
    required this.candidateManifestSha256,
  });

  final String runId;
  final Directory workspace;
  final Directory payloadDirectory;
  final String candidateManifestSha256;
}

/// Copies a validated portable restore payload into the app-data filesystem.
///
/// The candidate remains immutable under its run workspace until the startup
/// gate either commits the whole bundle or restores the previous bundle.
final class RestoreBundleStaging {
  RestoreBundleStaging._();

  static const workspaceRootName = RestoreWorkspaceLock.workspaceRootName;
  static const _backupFormat = 'kelivo-backup';
  // Candidates explicitly bind the asset roots selected for cutover.
  static const _backupFormatVersion = 3;

  /// The source archive's declaration key. DataSync depends on this file, so
  /// importing its definition here would introduce a cycle.
  static const _minimumReadableFormatKey = 'minimumReadableFormatVersion';
  static const _assetRoots = [
    'upload',
    'images',
    'avatars',
    'fonts',
    'skills',
    'workspaces',
    'sessions',
  ];
  static const _databaseEntry = 'database/kelivo.db';
  // Settings contain structured preferences, never chat rows or binary assets.
  // Cap JSON before copying/parsing to bound UTF-8 and DOM amplification.

  /// Test-only stall inside the candidate-db isolate (milliseconds).
  @visibleForTesting
  static int debugCandidateDbStallMs = 0;

  /// Test-only hang that ignores cancel (seconds). Native sleep.
  @visibleForTesting
  static int debugCandidateDbHangSeconds = 0;

  /// Test-only stall inside the candidate revalidation isolate (milliseconds).
  @visibleForTesting
  static int debugCandidateValidateStallMs = 0;

  /// Test-only hang that ignores cancel (seconds). Native sleep.
  @visibleForTesting
  static int debugCandidateValidateHangSeconds = 0;

  @visibleForTesting
  static Duration? debugIsolateKillGrace;

  @visibleForTesting
  static Duration? debugIsolateExitDeadline;

  @visibleForTesting
  static Duration? debugIsolateTimeout;

  /// [consumeExtractedFiles] transfers ownership of a disposable user-import
  /// tree. Its sealed candidate is fully verified at startup before live data
  /// moves. Reusable sources stay intact and get a full staged readback.
  static Future<StagedRestoreBundle> create({
    required Directory appDataDirectory,
    required Directory extractedDirectory,
    bool consumeExtractedFiles = false,
    required bool includeChats,
    required bool includeFiles,
    BackupScope scope = const BackupScope(),
    bool useExistingLocalAttachments = false,
    Directory? filesDirectory,
    bool? sourceIncludesChats,
    bool? sourceIncludesFiles,
    required String sourceManifestSha256,
    RestoreDurability? durability,
    Map<String, dynamic>? validatedSettings,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    final declaredIncludeChats = sourceIncludesChats ?? includeChats;
    final declaredIncludeFiles = sourceIncludesFiles ?? includeFiles;
    final selectedAssetRoots = includeFiles ? scope.assetRoots : <String>{};
    if (!includeChats ||
        !declaredIncludeChats ||
        (includeFiles && !declaredIncludeFiles)) {
      throw const FormatException('restore_staging_selection');
    }
    final resolvedDurability = durability ?? RestorePlatformDurability();
    final workspaceLock = RestoreWorkspaceLock(
      appDataDirectory: appDataDirectory,
      durability: resolvedDurability,
    );
    final allocation = await workspaceLock.synchronized(() async {
      await _requireAvailableWorkspace(workspaceLock.workspaceRoot);
      return _createRunWorkspace(
        workspaceLock.workspaceRoot,
        resolvedDurability,
      );
    });
    final runId = allocation.runId;
    final workspace = allocation.workspace;
    final payloadDirectory = Directory(p.join(workspace.path, 'candidate'));

    try {
      _throwIfCancelled(cancelToken);
      onProgress?.call(
        const BackupProgress(
          phase: BackupPhase.stagingCandidate,
          processed: 0,
          cancellable: true,
        ),
      );
      await _ensureDurableDirectory(
        directory: payloadDirectory,
        boundary: workspace,
        durability: resolvedDurability,
      );
      final sourceManifestFile = File(
        p.join(extractedDirectory.path, 'manifest.json'),
      );
      final sourceManifestBytes = await _readBoundedBytes(
        sourceManifestFile,
        maximumBytes: BackupArchiveLimits.manifestBytes,
        error: 'restore_staging_manifest',
        cancelToken: cancelToken,
      );
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sourceManifestSha256) ||
          sha256.convert(sourceManifestBytes).toString() !=
              sourceManifestSha256) {
        throw const FormatException('restore_staging_manifest_hash');
      }
      final decodedManifest = _decodeJsonMap(
        sourceManifestBytes,
        error: 'restore_staging_manifest',
      );
      if (decodedManifest['includeChats'] != declaredIncludeChats ||
          decodedManifest['includeFiles'] != declaredIncludeFiles ||
          decodedManifest['entries'] is! Map) {
        throw const FormatException('restore_staging_manifest');
      }
      if (decodedManifest['payloadKind'] != 'sqlite' ||
          decodedManifest['secretsIncluded'] != true) {
        throw const FormatException('restore_staging_manifest_fields');
      }
      final manifest = decodedManifest;
      final rawBusinessEntityRowIds = _parseBusinessEntityRowIds(manifest);
      final businessEntityRowIds = rawBusinessEntityRowIds == null
          ? null
          : BackupContentFilter.select(rawBusinessEntityRowIds, scope);
      final declaredEntries = _parseDeclaredEntries(
        manifest,
        includeChats: declaredIncludeChats,
        includeFiles: declaredIncludeFiles,
      );
      final declaredDatabaseInfo = _parseDatabaseInfo(
        manifest['database'],
        includeChats: true,
        payloadKind: 'sqlite',
      )!;

      const settingsEntry = 'settings.json';
      final sourceSettingsFile = File(
        p.join(extractedDirectory.path, settingsEntry),
      );
      final stagedEntries = {
        for (final entry in declaredEntries.entries)
          if (entry.key == _databaseEntry ||
              selectedAssetRoots.contains(entry.key.split('/').first))
            entry.key: entry.value,
      };
      final files = (
        source: extractedDirectory.path,
        consumeExtractedFiles: consumeExtractedFiles,
        candidate: payloadDirectory.path,
        roots: selectedAssetRoots,
        entries: {
          settingsEntry: declaredEntries[settingsEntry]!,
          ...stagedEntries,
        },
      );
      // Platform durability owns native handles, so construct it on the worker.
      // An explicitly injected durability object belongs to its caller.
      if (durability == null || durability is RestorePlatformDurability) {
        await runBackupIsolate<void, _StageFiles>(
          body: _stageFilesInIsolate,
          payload: files,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
      } else {
        await _stageFiles(
          files,
          durability,
          onProgress,
          () => _throwIfCancelled(cancelToken),
        );
      }
      _throwIfCancelled(cancelToken);
      final Map<String, dynamic> settings;
      if (validatedSettings != null) {
        settings = Map<String, dynamic>.from(validatedSettings);
        BackupSettingsValidator.normalizeAndValidate(settings);
      } else {
        settings = await runBackupIsolate<Map<String, dynamic>, String>(
          body: _validateSettingsInIsolate,
          payload: sourceSettingsFile.path,
          cancelToken: cancelToken,
          onProgress: onProgress,
        );
      }

      final stagedDatabaseFile = File(
        p.joinAll([payloadDirectory.path, ..._databaseEntry.split('/')]),
      );
      final prepared = await _replaceCandidateBusinessSettings(
        databaseFile: stagedDatabaseFile,
        // Startup recovery must not open the missing or damaged live database.
        deviceDatabasePath: useExistingLocalAttachments
            ? null
            : p.join(appDataDirectory.path, AppDatabase.databaseFileName),
        settings: settings,
        scope: scope,
        entityRowIds: businessEntityRowIds,
        preserveExplicitEmptyInstructionList: businessEntityRowIds == null,
        expectedDatabaseInfo: declaredDatabaseInfo,
        expectedEntry: stagedEntries[_databaseEntry]!,
        durability: resolvedDurability,
        recomputeAttachmentsUnavailable:
            !includeFiles || !scope.includes(BackupCategory.files),
        localSnapshotAppDataPath: useExistingLocalAttachments
            ? (filesDirectory ??
                      await AppDirectories.contentDirectoryFor(
                        appDataDirectory,
                      ))
                  .path
            : null,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      final databaseInfo = prepared.info;
      stagedEntries[_databaseEntry] = prepared.entry;
      final sortedEntryNames = stagedEntries.keys.toList()..sort();
      manifest['formatVersion'] = _backupFormatVersion;
      manifest.remove('scope');
      manifest['payloadKind'] = 'sqlite';
      manifest['includeChats'] = true;
      manifest['includeFiles'] = includeFiles;
      manifest['assetRoots'] = selectedAssetRoots.toList()..sort();
      manifest.remove('secretsIncluded');
      manifest.remove('businessEntityRowIds');
      // Omitted source paths are export diagnostics, not candidate payload.
      manifest.remove('skippedEntries');
      // A forward-compatibility declaration describes the SOURCE archive. The
      // candidate is only ever read back by this same build, so it carries no
      // declaration -- matching how the database block below is rebuilt rather
      // than copied.
      manifest.remove(_minimumReadableFormatKey);
      manifest['database'] = {
        'entry': _databaseEntry,
        'schemaVersion': databaseInfo.schemaVersion,
        'conversationCount': databaseInfo.conversationCount,
        'messageCount': databaseInfo.messageCount,
      };
      manifest['entries'] = {
        for (final entryName in sortedEntryNames)
          entryName: {
            'bytes': stagedEntries[entryName]!.bytes,
            'sha256': stagedEntries[entryName]!.sha256,
          },
      };
      final stagedManifestFile = File(
        p.join(payloadDirectory.path, 'manifest.json'),
      );
      final stagedManifestBytes = utf8.encode(jsonEncode(manifest));
      if (stagedManifestBytes.length > BackupArchiveLimits.manifestBytes) {
        throw const FormatException('restore_staging_manifest_size');
      }
      _throwIfCancelled(cancelToken);
      await stagedManifestFile.writeAsBytes(stagedManifestBytes, flush: true);
      await resolvedDurability.restrictFile(stagedManifestFile);
      await resolvedDurability.syncFile(stagedManifestFile, fullBarrier: true);
      await resolvedDurability.syncDirectory(
        payloadDirectory,
        fullBarrier: true,
      );
      _throwIfCancelled(cancelToken);
      final validated = await _checkCandidate(
        // User imports just checked their content while extracting it. Check
        // the staged inventory now; startup reopens every byte before cutover.
        verifyContents: !consumeExtractedFiles,
        candidateDirectory: payloadDirectory,
        expectedManifestSha256: sha256.convert(stagedManifestBytes).toString(),
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
      if (!validated.includeChats || validated.includeFiles != includeFiles) {
        throw const FormatException('restore_staging_candidate_selection');
      }

      return StagedRestoreBundle._(
        runId: runId,
        workspace: workspace,
        payloadDirectory: payloadDirectory,
        candidateManifestSha256: validated.manifestSha256,
      );
    } catch (error) {
      if (backupIsolateStillAlive(error)) {
        final isolateExit = backupIsolateExitFuture(error);
        if (isolateExit != null) {
          unawaited(
            isolateExit.then((_) {
              return _discardUnpublishedWorkspace(
                workspaceLock: workspaceLock,
                workspace: workspace,
              );
            }),
          );
        }
      } else {
        await _discardUnpublishedWorkspace(
          workspaceLock: workspaceLock,
          workspace: workspace,
        );
      }
      rethrow;
    }
  }

  /// Reopens and fully validates a staged candidate without mutating it.
  static Future<ValidatedRestoreCandidate> validateExistingCandidate({
    required Directory candidateDirectory,
    required String expectedManifestSha256,
    BackupCancelToken? cancelToken,
    BackupProgressSink? onProgress,
  }) => _checkCandidate(
    candidateDirectory: candidateDirectory,
    expectedManifestSha256: expectedManifestSha256,
    verifyContents: true,
    cancelToken: cancelToken,
    onProgress: onProgress,
  );

  static Future<ValidatedRestoreCandidate> _checkCandidate({
    required Directory candidateDirectory,
    required String expectedManifestSha256,
    required bool verifyContents,
    BackupCancelToken? cancelToken,
    BackupProgressSink? onProgress,
  }) {
    return runBackupIsolate<ValidatedRestoreCandidate, _ValidateCandidateArgs>(
      body: _validateExistingCandidateInIsolate,
      payload: _ValidateCandidateArgs(
        candidatePath: candidateDirectory.path,
        verifyContents: verifyContents,
        expectedManifestSha256: expectedManifestSha256,
        stallMs: debugCandidateValidateStallMs,
        hangSeconds: debugCandidateValidateHangSeconds,
      ),
      cancelToken: cancelToken,
      onProgress: onProgress,
      timeout: debugIsolateTimeout,
      killGrace: debugIsolateKillGrace ?? const Duration(seconds: 3),
      isolateExitDeadline:
          debugIsolateExitDeadline ?? const Duration(seconds: 2),
    );
  }

  /// Reads the immutable candidate control model without requiring selected
  /// payload files to remain in candidate after cutover has started.
  static Future<ValidatedRestoreCandidate> readCandidateManifest({
    required Directory candidateDirectory,
    required String expectedManifestSha256,
  }) async {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedManifestSha256) ||
        await FileSystemEntity.type(
              candidateDirectory.path,
              followLinks: false,
            ) !=
            FileSystemEntityType.directory) {
      throw const FormatException('restore_staging_candidate');
    }
    final manifestFile = File(p.join(candidateDirectory.path, 'manifest.json'));
    final manifestBytes = await _readBoundedBytes(
      manifestFile,
      maximumBytes: BackupArchiveLimits.manifestBytes,
      error: 'restore_staging_manifest_reopen',
    );
    final manifestSha256 = sha256.convert(manifestBytes).toString();
    if (manifestSha256 != expectedManifestSha256) {
      throw const FormatException('restore_staging_manifest_reopen');
    }
    final manifest = _decodeJsonMap(
      manifestBytes,
      error: 'restore_staging_manifest_reopen',
    );
    final includeChats = manifest['includeChats'];
    final includeFiles = manifest['includeFiles'];
    final payloadKind = manifest['payloadKind'];
    final formatVersion = manifest['formatVersion'];
    if (manifest['format'] != _backupFormat ||
        formatVersion is! int ||
        (formatVersion != 2 && formatVersion != _backupFormatVersion) ||
        includeChats != true ||
        includeFiles is! bool ||
        payloadKind != 'sqlite' ||
        manifest['createdAtUtc'] is! String ||
        manifest['appVersion'] is! String) {
      throw const FormatException('restore_staging_manifest_fields');
    }
    final expectedFields = <String>{
      'format',
      'formatVersion',
      'payloadKind',
      'createdAtUtc',
      'appVersion',
      'includeChats',
      'includeFiles',
      if (formatVersion == _backupFormatVersion) 'assetRoots',
      'database',
      'entries',
    };
    if (manifest.length != expectedFields.length ||
        !manifest.keys.toSet().containsAll(expectedFields)) {
      throw const FormatException('restore_staging_manifest_fields');
    }
    final declaredEntries = _parseCandidateEntries(
      manifest,
      includeFiles: includeFiles,
    );
    // v1.3.0 staged all asset roots together. Interpret that exact schema in
    // memory without rewriting the manifest bound by the existing receipts.
    final rawAssetRoots = formatVersion == 2
        ? (includeFiles ? _assetRoots : const <String>[])
        : manifest['assetRoots'];
    if (rawAssetRoots is! List ||
        rawAssetRoots.any(
          (root) => root is! String || !_assetRoots.contains(root),
        ) ||
        rawAssetRoots.toSet().length != rawAssetRoots.length ||
        includeFiles != rawAssetRoots.isNotEmpty) {
      throw const FormatException('restore_staging_asset_roots');
    }
    final assetRoots = rawAssetRoots.cast<String>().toSet();
    if (declaredEntries.keys.any(
      (name) =>
          name != _databaseEntry &&
          !assetRoots.any((root) => name.startsWith('$root/')),
    )) {
      throw const FormatException('restore_staging_asset_roots');
    }
    final databaseInfo = _parseDatabaseInfo(
      manifest['database'],
      includeChats: true,
      payloadKind: 'sqlite',
      requireCurrentSchema: true,
    );

    return ValidatedRestoreCandidate(
      includeChats: true,
      includeFiles: includeFiles,
      assetRoots: assetRoots,
      manifestSha256: manifestSha256,
      entries: declaredEntries,
      databaseInfo: databaseInfo,
    );
  }

  static Future<void> discardUnpublished({
    required Directory appDataDirectory,
    required String runId,
  }) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(runId)) {
      throw ArgumentError.value(runId, 'runId');
    }
    final workspaceLock = RestoreWorkspaceLock(
      appDataDirectory: appDataDirectory,
    );
    await _discardUnpublishedWorkspace(
      workspaceLock: workspaceLock,
      workspace: Directory(
        p.join(workspaceLock.workspaceRoot.path, 'run_$runId'),
      ),
    );
  }

  static Future<void> _requireAvailableWorkspace(
    Directory workspaceRoot,
  ) async {
    await for (final entity in workspaceRoot.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (name == RestoreWorkspaceLock.lockFileName &&
          type == FileSystemEntityType.file) {
        continue;
      }
      if (name == RestoreWorkspaceLock.completedRunsDirectoryName &&
          type == FileSystemEntityType.directory) {
        await RestoreWorkspaceLock.validateCompletedRunsDirectory(
          Directory(entity.path),
        );
        continue;
      }
      throw StateError('restore_staging_workspace_not_empty');
    }
  }

  static Future<void> _discardUnpublishedWorkspace({
    required RestoreWorkspaceLock workspaceLock,
    required Directory workspace,
  }) async {
    final workspaceName = p.basename(workspace.path);
    if (!RegExp(r'^run_[a-f0-9]{32}$').hasMatch(workspaceName)) {
      throw StateError('restore_staging_discard_workspace');
    }
    final runId = workspaceName.substring('run_'.length);
    await workspaceLock.withDiscardingRun(
      runId: runId,
      action: () async {
        var foundWorkspace = false;
        var foundDiscardingRun = false;
        await for (final entity in workspaceLock.workspaceRoot.list(
          followLinks: false,
        )) {
          final name = p.basename(entity.path);
          final type = await FileSystemEntity.type(
            entity.path,
            followLinks: false,
          );
          if (name == RestoreWorkspaceLock.lockFileName &&
              type == FileSystemEntityType.file) {
            continue;
          }
          if (name == RestoreWorkspaceLock.completedRunsDirectoryName &&
              type == FileSystemEntityType.directory) {
            await RestoreWorkspaceLock.validateCompletedRunsDirectory(
              Directory(entity.path),
            );
            continue;
          }
          if (name == RestoreWorkspaceLock.discardingRunFileName &&
              type == FileSystemEntityType.file &&
              await _readActiveRunId(File(entity.path)) == runId &&
              !foundDiscardingRun) {
            foundDiscardingRun = true;
            continue;
          }
          if (p.equals(entity.path, workspace.path) &&
              type == FileSystemEntityType.directory &&
              !foundWorkspace) {
            foundWorkspace = true;
            continue;
          }
          throw StateError('restore_staging_discard_workspace');
        }
        if (!foundWorkspace) {
          throw StateError('restore_staging_discard_workspace');
        }
        if (!foundDiscardingRun) {
          throw StateError('restore_staging_discard_active_run');
        }

        await for (final entity in workspace.list(followLinks: false)) {
          final name = p.basename(entity.path);
          final type = await FileSystemEntity.type(
            entity.path,
            followLinks: false,
          );
          if (name != 'candidate' || type != FileSystemEntityType.directory) {
            throw StateError('restore_staging_discard_run');
          }
        }
        await workspace.delete(recursive: true);
      },
    );
  }

  static Future<({String runId, Directory workspace})> _createRunWorkspace(
    Directory workspaceRoot,
    RestoreDurability durability,
  ) async {
    for (var attempt = 0; attempt < 16; attempt++) {
      final runId = _newRunId();
      final workspace = Directory(p.join(workspaceRoot.path, 'run_$runId'));
      if (await FileSystemEntity.type(workspace.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        continue;
      }
      final activeRunFile = File(
        p.join(workspaceRoot.path, RestoreWorkspaceLock.activeRunFileName),
      );
      var ownsActiveRun = false;
      try {
        await activeRunFile.create(exclusive: true);
        ownsActiveRun = true;
        await activeRunFile.writeAsString(runId, flush: true);
        await durability.restrictFile(activeRunFile);
        await durability.syncFile(activeRunFile, fullBarrier: true);
        await durability.syncDirectory(workspaceRoot, fullBarrier: true);
        if (await _readActiveRunId(activeRunFile) != runId) {
          throw StateError('restore_staging_active_run');
        }
        await workspace.create();
        await durability.restrictDirectory(workspace);
        await durability.syncDirectory(workspaceRoot, fullBarrier: true);
        if (await FileSystemEntity.type(workspace.path, followLinks: false) !=
            FileSystemEntityType.directory) {
          throw FileSystemException(
            'Restore run workspace changed type',
            workspace.path,
          );
        }
        if (!await workspace.list(followLinks: false).isEmpty) {
          throw FileSystemException(
            'Restore run workspace is not empty',
            workspace.path,
          );
        }
        return (runId: runId, workspace: workspace);
      } catch (_) {
        if (await FileSystemEntity.type(workspace.path, followLinks: false) ==
            FileSystemEntityType.directory) {
          await workspace.delete(recursive: true);
          await durability.syncDirectory(workspaceRoot, fullBarrier: true);
        }
        if (ownsActiveRun &&
            await FileSystemEntity.type(
                  activeRunFile.path,
                  followLinks: false,
                ) ==
                FileSystemEntityType.file) {
          await activeRunFile.delete();
          await durability.syncDirectory(workspaceRoot, fullBarrier: true);
        }
        rethrow;
      }
    }
    throw StateError('restore_staging_run_id_collision');
  }

  static Future<String> _readActiveRunId(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await file.length() != 32) {
      throw StateError('restore_staging_active_run');
    }
    final runId = await file.readAsString();
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(runId)) {
      throw StateError('restore_staging_active_run');
    }
    return runId;
  }

  static String _newRunId() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var index = 0; index < 16; index++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static void _throwIfCancelled(BackupCancelToken? cancelToken) {
    if (cancelToken?.isCancelled == true) {
      throw const BackupCancelledException();
    }
  }

  static Future<void> _stageFilesInIsolate(
    BackupIsolateContext ctx,
    _StageFiles files,
  ) => _stageFiles(
    files,
    RestorePlatformDurability(),
    ctx.reportProgress,
    ctx.throwIfCancelled,
  );

  static Future<void> _stageFiles(
    _StageFiles files,
    RestoreDurability durability,
    BackupProgressSink? onProgress,
    void Function() checkCancelled,
  ) async {
    var canMove = files.consumeExtractedFiles;
    var stagedFiles = 0;
    void reportFileCount() => onProgress?.call(
      BackupProgress(
        phase: BackupPhase.stagingCandidate,
        processed: stagedFiles,
        total: files.entries.length,
        unit: BackupProgressUnit.items,
      ),
    );
    final meter = BackupByteProgress(
      phase: BackupPhase.stagingCandidate,
      total: files.entries.values.fold<int>(0, (sum, e) => sum + e.bytes),
      onProgress: (progress) {
        if (!canMove) onProgress?.call(progress);
      },
      checkCancelled: checkCancelled,
    )..report();
    if (canMove) reportFileCount();
    final candidate = Directory(files.candidate);
    final directories = <String>{};
    Future<void> ensureDirectory(Directory dir) async {
      checkCancelled();
      if (directories.add(dir.path)) {
        await _ensureDurableDirectory(
          directory: dir,
          boundary: candidate,
          durability: durability,
        );
      }
    }

    for (final root in files.roots) {
      await ensureDirectory(Directory(p.join(files.candidate, root)));
    }
    final buffer = Uint8List(1024 * 1024);
    for (final entry in files.entries.entries) {
      checkCancelled();
      final parts = entry.key.split('/');
      final source = File(p.joinAll([files.source, ...parts]));
      if (FileSystemEntity.typeSync(source.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw FormatException('restore_staging_source:${entry.key}');
      }
      if (source.lengthSync() != entry.value.bytes) {
        throw FormatException('restore_staging_descriptor:${entry.key}');
      }
      // Business settings live in the candidate database, not in a second JSON file.
      final target = entry.key == 'settings.json'
          ? null
          : File(p.joinAll([files.candidate, ...parts]));
      if (target != null) {
        await ensureDirectory(target.parent);
        if (FileSystemEntity.typeSync(target.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          throw StateError('restore_staging_target:${entry.key}');
        }
      }
      // Only the importer's disposable extraction tree may be consumed. A
      // same-volume rename keeps the exact file; the candidate is independently
      // verified before publication. A reusable source is always copied.
      var moved = false;
      if (canMove && target != null) {
        try {
          source.renameSync(target.path);
          moved = true;
        } on FileSystemException catch (error) {
          if (error.osError?.errorCode != (Platform.isWindows ? 17 : 18)) {
            rethrow;
          }
          canMove = false;
          meter.report();
        }
      }
      if (moved) {
        meter.add(entry.value.bytes, detail: entry.key);
      } else {
        final actual = digestBackupFile(
          source,
          copyTo: target,
          buffer: buffer,
          checkCancelled: checkCancelled,
          onBytes: (n) => meter.add(n, detail: entry.key),
        );
        if (actual != entry.value) {
          throw FormatException('restore_staging_descriptor:${entry.key}');
        }
      }
      if (target != null) {
        await durability.restrictFile(target);
        await durability.syncFile(target);
      }
      if (canMove) {
        stagedFiles++;
        reportFileCount();
      }
    }
    // The unpublished workspace can be discarded after a crash. Flush each
    // populated directory once before any candidate can be published.
    for (final path in directories) {
      checkCancelled();
      await durability.syncDirectory(Directory(path));
    }
  }

  static Future<void> _ensureDurableDirectory({
    required Directory directory,
    required Directory boundary,
    required RestoreDurability durability,
  }) async {
    final boundaryPath = p.normalize(boundary.absolute.path);
    final directoryPath = p.normalize(directory.absolute.path);
    if (!p.equals(boundaryPath, directoryPath) &&
        !p.isWithin(boundaryPath, directoryPath)) {
      throw StateError('restore_staging_directory_boundary');
    }
    final relative = p.relative(directoryPath, from: boundaryPath);
    var current = boundary;
    if (p.equals(boundaryPath, directoryPath)) {
      if (await FileSystemEntity.type(current.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw StateError('restore_staging_directory');
      }
      await durability.restrictDirectory(current);
      return;
    }
    for (final segment in p.split(relative)) {
      final parent = current;
      current = Directory(p.join(current.path, segment));
      final type = await FileSystemEntity.type(
        current.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.notFound) {
        await current.create();
        await durability.restrictDirectory(current);
        await durability.syncDirectory(parent);
      } else if (type == FileSystemEntityType.directory) {
        await durability.restrictDirectory(current);
      } else {
        throw StateError('restore_staging_directory');
      }
    }
  }

  static Map<String, _StagedRestoreEntry> _parseDeclaredEntries(
    Map<String, dynamic> manifest, {
    required bool includeChats,
    required bool includeFiles,
  }) {
    final entries = _parseEntryDescriptors(manifest, allowSettings: true);
    final hasDatabase = entries.containsKey(_databaseEntry);
    final hasAssets = entries.keys.any(
      (name) => _assetRoots.any((root) => name.startsWith('$root/')),
    );
    final settingsBytes = entries['settings.json']?.bytes;
    if (settingsBytes == null ||
        settingsBytes <= 0 ||
        settingsBytes > BackupArchiveLimits.settingsBytes ||
        hasDatabase != includeChats ||
        (!includeFiles && hasAssets)) {
      throw const FormatException('restore_staging_entries');
    }
    return entries;
  }

  static Map<String, _StagedRestoreEntry> _parseCandidateEntries(
    Map<String, dynamic> manifest, {
    required bool includeFiles,
  }) {
    final entries = _parseEntryDescriptors(manifest, allowSettings: false);
    final hasDatabase = entries.containsKey(_databaseEntry);
    final hasAssets = entries.keys.any(
      (name) => _assetRoots.any((root) => name.startsWith('$root/')),
    );
    if (!hasDatabase || (!includeFiles && hasAssets)) {
      throw const FormatException('restore_staging_entries');
    }
    return entries;
  }

  static Map<String, _StagedRestoreEntry> _parseEntryDescriptors(
    Map<String, dynamic> manifest, {
    required bool allowSettings,
  }) {
    final rawEntries = manifest['entries'];
    if (rawEntries is! Map) {
      throw const FormatException('restore_staging_entries');
    }
    final entries = <String, _StagedRestoreEntry>{};
    final caseFoldedNames = <String>{};
    for (final rawEntry in rawEntries.entries) {
      if (rawEntry.key is! String || rawEntry.value is! Map) {
        throw const FormatException('restore_staging_entry');
      }
      final name = rawEntry.key as String;
      final rawMetadata = rawEntry.value as Map;
      if (rawMetadata.keys.any((key) => key is! String)) {
        throw FormatException('restore_staging_entry:$name');
      }
      final metadata = rawMetadata.cast<String, dynamic>();
      final bytes = metadata['bytes'];
      final digest = metadata['sha256'];
      final knownName =
          (allowSettings && name == 'settings.json') ||
          name == _databaseEntry ||
          _assetRoots.any((root) => name.startsWith('$root/'));
      if (!_isCanonicalEntryName(name) ||
          !caseFoldedNames.add(name.toLowerCase()) ||
          !knownName ||
          metadata.length != 2 ||
          !metadata.containsKey('bytes') ||
          !metadata.containsKey('sha256') ||
          bytes is! int ||
          bytes < 0 ||
          digest is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
        throw FormatException('restore_staging_entry:$name');
      }
      entries[name] = (bytes: bytes, sha256: digest);
    }
    return entries;
  }

  static Map<String, dynamic> _validateSettingsInIsolate(
    BackupIsolateContext ctx,
    String path,
  ) {
    ctx.throwIfCancelled();
    ctx.reportProgress(
      const BackupProgress(
        phase: BackupPhase.readingSettings,
        processed: 0,
        cancellable: true,
      ),
    );
    final file = File(path);
    if (!file.existsSync()) {
      throw const FormatException('restore_staging_settings');
    }
    final length = file.lengthSync();
    if (length <= 0 || length > BackupArchiveLimits.settingsBytes) {
      throw const FormatException('restore_staging_settings');
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map || decoded.keys.any((key) => key is! String)) {
      throw const FormatException('restore_staging_settings');
    }
    final settings = decoded.cast<String, dynamic>();
    BackupSettingsValidator.normalizeAndValidate(settings);
    ctx.throwIfCancelled();
    return settings;
  }

  static Future<_PreparedDatabase> _replaceCandidateBusinessSettings({
    required File databaseFile,
    required String? deviceDatabasePath,
    required Map<String, dynamic> settings,
    required BackupScope scope,
    required Map<String, Object?>? entityRowIds,
    required bool preserveExplicitEmptyInstructionList,
    required ChatDatabaseSnapshotInfo expectedDatabaseInfo,
    required _StagedRestoreEntry expectedEntry,
    required RestoreDurability durability,
    required bool recomputeAttachmentsUnavailable,
    String? localSnapshotAppDataPath,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    final databaseInfo =
        await runBackupIsolate<_PreparedDatabase, _CandidateDbIsolateArgs>(
          body: _prepareCandidateDatabaseInIsolate,
          payload: _CandidateDbIsolateArgs(
            databasePath: databaseFile.path,
            deviceDatabasePath: deviceDatabasePath,
            settings: settings,
            scope: scope,
            entityRowIds: entityRowIds,
            preserveExplicitEmptyInstructionList:
                preserveExplicitEmptyInstructionList,
            expectedDatabaseInfo: expectedDatabaseInfo,
            expectedEntry: expectedEntry,
            recomputeAttachmentsUnavailable: recomputeAttachmentsUnavailable,
            localSnapshotAppDataPath: localSnapshotAppDataPath,
            stallMs: debugCandidateDbStallMs,
            hangSeconds: debugCandidateDbHangSeconds,
          ),
          cancelToken: cancelToken,
          onProgress: onProgress,
          timeout: debugIsolateTimeout,
          killGrace: debugIsolateKillGrace ?? const Duration(seconds: 3),
          isolateExitDeadline:
              debugIsolateExitDeadline ?? const Duration(seconds: 2),
        );
    await durability.restrictFile(databaseFile);
    await durability.syncFile(databaseFile, fullBarrier: true);
    await durability.syncDirectory(databaseFile.parent, fullBarrier: true);
    return databaseInfo;
  }

  static Future<ValidatedRestoreCandidate> _validateExistingCandidateInIsolate(
    BackupIsolateContext ctx,
    _ValidateCandidateArgs args,
  ) async {
    ctx.reportProgress(
      BackupProgress(
        phase: args.verifyContents
            ? BackupPhase.checkingDatabase
            : BackupPhase.validating,
        processed: 0,
        cancellable: true,
        detail: 'candidate-revalidate',
      ),
    );
    ctx.throwIfCancelled();
    if (args.hangSeconds > 0) {
      debugNativeSleepIgnoringKill(args.hangSeconds);
    }
    if (args.stallMs > 0) {
      final until = DateTime.now().add(Duration(milliseconds: args.stallMs));
      while (DateTime.now().isBefore(until)) {
        ctx.throwIfCancelled();
      }
    }
    final candidateDirectory = Directory(args.candidatePath);
    final candidate = await readCandidateManifest(
      candidateDirectory: candidateDirectory,
      expectedManifestSha256: args.expectedManifestSha256,
    );
    ctx.throwIfCancelled();
    if (args.verifyContents && candidate.includeChats) {
      final actual = await ChatDatabaseRepository.inspectPreparedSnapshot(
        File(
          p.joinAll([candidateDirectory.path, ..._databaseEntry.split('/')]),
        ),
      );
      if (actual != candidate.databaseInfo) {
        throw const FormatException('restore_staging_database');
      }
    }
    ctx.throwIfCancelled();
    await _validateCandidateTopology(
      ctx,
      candidateDirectory,
      expectedFiles: {...candidate.entries.keys, 'manifest.json'},
      checkSizes: args.verifyContents ? null : candidate.entries,
      includeChats: candidate.includeChats,
      assetRoots: candidate.assetRoots,
    );
    ctx.throwIfCancelled();
    if (args.verifyContents) {
      _validateCandidateEntries(ctx, candidateDirectory, candidate.entries);
    }
    ctx.throwIfCancelled();
    return candidate;
  }

  static Future<_PreparedDatabase> _prepareCandidateDatabaseInIsolate(
    BackupIsolateContext ctx,
    _CandidateDbIsolateArgs args,
  ) async {
    ctx.reportProgress(
      const BackupProgress(
        phase: BackupPhase.checkingDatabase,
        processed: 0,
        cancellable: true,
        detail: 'candidate-db',
      ),
    );
    ctx.throwIfCancelled();
    if (args.hangSeconds > 0) {
      debugNativeSleepIgnoringKill(args.hangSeconds);
    }
    if (args.stallMs > 0) {
      final until = DateTime.now().add(Duration(milliseconds: args.stallMs));
      while (DateTime.now().isBefore(until)) {
        ctx.throwIfCancelled();
      }
    }
    final databaseFile = File(args.databasePath);
    if (_databaseDigest(ctx, databaseFile) != args.expectedEntry) {
      throw StateError('restore_staging_copy:$_databaseEntry');
    }
    ctx.reportProgress(
      const BackupProgress(
        phase: BackupPhase.checkingDatabase,
        processed: 0,
        detail: 'candidate-db',
      ),
    );

    // A backup authored by an older build carries an older schema. Bring the
    // staged copy forward first: everything below — the snapshot validators,
    // the business overwrite, the candidate manifest — only ever describes the
    // current schema. The staged copy is disposable and the source archive is
    // itself the backup, so no extra copy is taken.
    final stagedSchemaVersion = SchemaMigrations.readSchemaVersion(
      databaseFile,
    );
    if (SchemaMigrations.needsUpgrade(stagedSchemaVersion)) {
      await SchemaMigrations.upgradeFileInPlace(databaseFile);
      await ChatDatabaseRepository.normalizeSnapshotJournal(databaseFile);
    }
    final sourceDatabaseInfo =
        await ChatDatabaseRepository.inspectPreparedSnapshot(databaseFile);
    // The declared info records the schema the backup was AUTHORED at, which
    // legitimately differs from the migrated one. Row counts are the invariant:
    // a migration must never add or drop rows.
    if (sourceDatabaseInfo.conversationCount !=
            args.expectedDatabaseInfo.conversationCount ||
        sourceDatabaseInfo.messageCount !=
            args.expectedDatabaseInfo.messageCount) {
      throw const FormatException('restore_staging_database');
    }
    final database = AppDatabase.open(file: databaseFile);
    try {
      await BackupPortability.sanitizeDatabase(database);
      await BusinessRestoreService(BusinessRepository(database)).overwrite(
        BackupContentFilter.select(args.settings, args.scope),
        entityRowIds: args.entityRowIds,
        preserveExplicitEmptyInstructionList:
            args.preserveExplicitEmptyInstructionList,
      );
      final devicePath = args.deviceDatabasePath;
      if (devicePath != null && await File(devicePath).exists()) {
        final localDatabase = AppDatabase.open(file: File(devicePath));
        try {
          final local = await BusinessRepository(localDatabase).readSnapshot();
          await BusinessRepository(database).transformSnapshot(
            (incoming) => BackupPortability.preserveDeviceState(
              BackupContentFilter.preserveUnselected(
                incoming,
                local,
                args.scope,
              ),
              local,
            ),
            writeReceipt: true,
          );
          final mounts = await ExtensionEntityStore(
            localDatabase,
          ).listByKind('externalMounts');
          final targetStore = ExtensionEntityStore(database);
          for (final mount in mounts) {
            await targetStore.upsert(
              mount.kind,
              mount.id,
              mount.payload,
              sortOrder: mount.sortOrder,
              ownerId: mount.ownerId,
            );
          }
        } finally {
          await localDatabase.close();
        }
      }
    } finally {
      await database.close();
    }
    final databaseInfo = await ChatDatabaseRepository.prepareSnapshotForRestore(
      databaseFile,
    );
    if (databaseInfo != sourceDatabaseInfo) {
      throw const FormatException('restore_staging_database');
    }
    if (args.recomputeAttachmentsUnavailable) {
      await ChatDatabaseRepository.recomputeAttachmentAvailabilityOnDatabaseFile(
        databaseFile: databaseFile,
        filesRestored: false,
        localSnapshotAppDataDirectory: args.localSnapshotAppDataPath == null
            ? null
            : Directory(args.localSnapshotAppDataPath!),
      );
    }
    ctx.throwIfCancelled();
    return (info: databaseInfo, entry: _databaseDigest(ctx, databaseFile));
  }

  static Map<String, Object?>? _parseBusinessEntityRowIds(
    Map<String, dynamic> manifest,
  ) {
    if (!manifest.containsKey('businessEntityRowIds')) return null;
    final raw = manifest['businessEntityRowIds'];
    if (raw is! Map || raw.keys.any((key) => key is! String)) {
      throw const FormatException('restore_staging_business_entity_row_ids');
    }
    final result = <String, Object?>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! List || value.any((item) => item is! String)) {
        throw const FormatException('restore_staging_business_entity_row_ids');
      }
      result[entry.key as String] = List<String>.unmodifiable(
        value.cast<String>(),
      );
    }
    return Map<String, Object?>.unmodifiable(result);
  }

  /// Parses a manifest's `database` block.
  ///
  /// [requireCurrentSchema] separates the two manifests this handles: a source
  /// manifest records the schema the backup was AUTHORED at, which may be any
  /// published version, while a staged candidate's manifest is written after
  /// the snapshot was migrated and must record the current schema exactly.
  static ChatDatabaseSnapshotInfo? _parseDatabaseInfo(
    dynamic rawDatabase, {
    required bool includeChats,
    required String payloadKind,
    bool requireCurrentSchema = false,
  }) {
    if (!includeChats) {
      if (payloadKind != 'settings-only' || rawDatabase != null) {
        throw const FormatException('restore_staging_database');
      }
      return null;
    }
    if (payloadKind != 'sqlite' ||
        rawDatabase is! Map ||
        rawDatabase.keys.any((key) => key is! String)) {
      throw const FormatException('restore_staging_database');
    }
    final database = rawDatabase.cast<String, dynamic>();
    const expectedKeys = {
      'entry',
      'schemaVersion',
      'conversationCount',
      'messageCount',
    };
    final schemaVersion = database['schemaVersion'];
    final conversationCount = database['conversationCount'];
    final messageCount = database['messageCount'];
    // A source manifest may also carry the forward-compatibility declaration;
    // the staged candidate never needs it, because it is only ever read back
    // by this same build.
    const optionalKeys = {SchemaMigrations.minimumReadableManifestKey};
    final presentKeys = database.keys.toSet();
    if (!presentKeys.containsAll(expectedKeys) ||
        !presentKeys.difference(expectedKeys).every(optionalKeys.contains) ||
        database['entry'] != _databaseEntry ||
        schemaVersion is! int ||
        // A source manifest can legitimately name a schema this build has
        // never heard of; only the staged candidate must be current.
        (requireCurrentSchema
            ? schemaVersion != AppDatabase.currentSchemaVersion
            : schemaVersion < 1) ||
        conversationCount is! int ||
        conversationCount < 0 ||
        messageCount is! int ||
        messageCount < 0) {
      throw const FormatException('restore_staging_database');
    }
    return (
      schemaVersion: schemaVersion,
      conversationCount: conversationCount,
      messageCount: messageCount,
    );
  }

  static Future<void> _validateCandidateTopology(
    BackupIsolateContext ctx,
    Directory candidate, {
    required Set<String> expectedFiles,
    required Map<String, _StagedRestoreEntry>? checkSizes,
    required bool includeChats,
    required Set<String> assetRoots,
  }) async {
    void report(int count) => ctx.reportProgress(
      BackupProgress(
        phase: checkSizes == null
            ? BackupPhase.scanning
            : BackupPhase.validating,
        processed: count,
        total: expectedFiles.length,
        unit: BackupProgressUnit.items,
      ),
    );
    report(0);
    final actualFiles = <String>{};
    final actualDirectories = <String>{};
    final expectedDirectories = <String>{};
    for (final file in expectedFiles) {
      final segments = file.split('/');
      for (var index = 1; index < segments.length; index++) {
        expectedDirectories.add(segments.take(index).join('/'));
      }
    }
    expectedDirectories.addAll(assetRoots);
    await for (final entity in candidate.list(
      recursive: true,
      followLinks: false,
    )) {
      ctx.throwIfCancelled();
      final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
      final relativePath = p
          .relative(entity.path, from: candidate.path)
          .replaceAll('\\', '/');
      if (type == FileSystemEntityType.directory) {
        if (!expectedDirectories.contains(relativePath)) {
          throw RestoreFormatException('restore_staging_candidate_directory', {
            'candidate directory': candidate.path,
            'unexpected directory': relativePath,
            'entry path': entity.path,
          });
        }
        actualDirectories.add(relativePath);
        continue;
      }
      if (type != FileSystemEntityType.file) {
        throw RestoreFormatException('restore_staging_candidate_type', {
          'candidate directory': candidate.path,
          'relative path': relativePath,
          'entry path': entity.path,
          'entry type': '$type',
        });
      }
      final descriptor = checkSizes?[relativePath];
      if (descriptor != null &&
          File(entity.path).lengthSync() != descriptor.bytes) {
        throw FormatException('restore_staging_candidate:$relativePath');
      }
      actualFiles.add(relativePath);
      report(actualFiles.length);
    }
    if (actualFiles.length != expectedFiles.length ||
        !actualFiles.containsAll(expectedFiles)) {
      throw RestoreFormatException('restore_staging_candidate_entries', {
        'candidate directory': candidate.path,
        ..._topologyDifferenceDetails('files', actualFiles, expectedFiles),
      });
    }
    if (actualDirectories.length != expectedDirectories.length ||
        !actualDirectories.containsAll(expectedDirectories) ||
        (includeChats != expectedDirectories.contains('database'))) {
      throw RestoreFormatException('restore_staging_candidate_directories', {
        'candidate directory': candidate.path,
        'include chats': '$includeChats',
        ..._topologyDifferenceDetails(
          'directories',
          actualDirectories,
          expectedDirectories,
        ),
      });
    }
  }

  static Map<String, String> _topologyDifferenceDetails(
    String kind,
    Set<String> actual,
    Set<String> expected,
  ) {
    final missing = expected.difference(actual);
    final unexpected = actual.difference(expected);
    return {
      'expected $kind': '${expected.length}',
      'actual $kind': '${actual.length}',
      'missing $kind count': '${missing.length}',
      'unexpected $kind count': '${unexpected.length}',
      // Limit listed paths even when the whole payload is missing or unexpected.
      'missing $kind (first 10)': jsonEncode(missing.take(10).toList()),
      'unexpected $kind (first 10)': jsonEncode(unexpected.take(10).toList()),
    };
  }

  static _StagedRestoreEntry _databaseDigest(
    BackupIsolateContext ctx,
    File file,
  ) {
    final meter = BackupByteProgress(
      phase: BackupPhase.validating,
      total: file.lengthSync(),
      onProgress: ctx.reportProgress,
      checkCancelled: ctx.throwIfCancelled,
    )..report();
    return digestBackupFile(
      file,
      checkCancelled: ctx.throwIfCancelled,
      onBytes: (n) => meter.add(n, detail: _databaseEntry),
    );
  }

  static void _validateCandidateEntries(
    BackupIsolateContext ctx,
    Directory candidate,
    Map<String, _StagedRestoreEntry> expectedEntries,
  ) {
    final meter = BackupByteProgress(
      phase: BackupPhase.validating,
      total: expectedEntries.values.fold<int>(0, (sum, e) => sum + e.bytes),
      onProgress: ctx.reportProgress,
      checkCancelled: ctx.throwIfCancelled,
    )..report();
    final buffer = Uint8List(1024 * 1024);
    for (final entry in expectedEntries.entries) {
      ctx.throwIfCancelled();
      final file = File(p.joinAll([candidate.path, ...entry.key.split('/')]));
      if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
              FileSystemEntityType.file ||
          file.lengthSync() != entry.value.bytes ||
          digestBackupFile(
                file,
                buffer: buffer,
                checkCancelled: ctx.throwIfCancelled,
                onBytes: (n) => meter.add(n, detail: entry.key),
              ) !=
              entry.value) {
        throw FormatException('restore_staging_candidate:${entry.key}');
      }
    }
  }

  @visibleForTesting
  static Future<String> debugSha256(
    File file, {
    BackupCancelToken? cancelToken,
  }) async => digestBackupFile(
    file,
    checkCancelled: cancelToken?.throwIfCancelled,
  ).sha256;

  static bool _isCanonicalEntryName(String name) {
    if (name.isEmpty ||
        name.contains('\\') ||
        name.startsWith('/') ||
        name.endsWith('/')) {
      return false;
    }
    final segments = name.split('/');
    return !segments.any(
          (segment) => segment.isEmpty || segment == '.' || segment == '..',
        ) &&
        p.posix.normalize(name) == name;
  }

  static Future<List<int>> _readBoundedBytes(
    File file, {
    required int maximumBytes,
    required String error,
    BackupCancelToken? cancelToken,
  }) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw FormatException(error);
    }
    final handle = await file.open(mode: FileMode.read);
    final bytes = BytesBuilder(copy: false);
    try {
      while (bytes.length <= maximumBytes) {
        _throwIfCancelled(cancelToken);
        final chunk = await handle.read(
          min(1024 * 1024, maximumBytes + 1 - bytes.length),
        );
        if (chunk.isEmpty) break;
        bytes.add(chunk);
      }
    } finally {
      await handle.close();
    }
    if (bytes.length == 0 || bytes.length > maximumBytes) {
      throw FormatException(error);
    }
    return bytes.takeBytes();
  }

  static Map<String, dynamic> _decodeJsonMap(
    List<int> bytes, {
    required String error,
  }) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map || decoded.keys.any((key) => key is! String)) {
      throw FormatException(error);
    }
    return decoded.cast<String, dynamic>();
  }
}

final class _ValidateCandidateArgs {
  const _ValidateCandidateArgs({
    required this.candidatePath,
    required this.verifyContents,
    required this.expectedManifestSha256,
    required this.stallMs,
    required this.hangSeconds,
  });

  final String candidatePath;
  final bool verifyContents;
  final String expectedManifestSha256;
  final int stallMs;
  final int hangSeconds;
}

final class _CandidateDbIsolateArgs {
  const _CandidateDbIsolateArgs({
    required this.databasePath,
    required this.deviceDatabasePath,
    required this.settings,
    required this.scope,
    required this.entityRowIds,
    required this.preserveExplicitEmptyInstructionList,
    required this.expectedDatabaseInfo,
    required this.expectedEntry,
    required this.recomputeAttachmentsUnavailable,
    required this.localSnapshotAppDataPath,
    required this.stallMs,
    required this.hangSeconds,
  });

  final String databasePath;
  final String? deviceDatabasePath;
  final Map<String, dynamic> settings;
  final BackupScope scope;
  final Map<String, Object?>? entityRowIds;
  final bool preserveExplicitEmptyInstructionList;
  final ChatDatabaseSnapshotInfo expectedDatabaseInfo;
  final _StagedRestoreEntry expectedEntry;
  final bool recomputeAttachmentsUnavailable;
  final String? localSnapshotAppDataPath;
  final int stallMs;
  final int hangSeconds;
}
