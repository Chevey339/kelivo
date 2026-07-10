import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../database/chat_database_repository.dart';
import 'backup_settings_validator.dart';
import 'restore_workspace_lock.dart';

typedef _StagedRestoreEntry = ({int bytes, String sha256});
typedef ValidatedRestoreCandidate = ({
  bool includeChats,
  bool includeFiles,
  String manifestSha256,
});

final class StagedRestoreBundle {
  const StagedRestoreBundle({
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

/// Copies a validated v2 restore payload into the app-data filesystem.
///
/// The current restore flow consumes this candidate immediately. A later
/// cutover slice will keep the workspace with a durable receipt until startup.
final class RestoreBundleStaging {
  RestoreBundleStaging._();

  static const workspaceRootName = RestoreWorkspaceLock.workspaceRootName;
  static const _backupFormat = 'kelivo-backup';
  static const _backupFormatVersion = 2;
  static const _assetRoots = ['upload', 'images', 'avatars', 'fonts'];
  static const _databaseEntry = 'database/kelivo.sqlite';
  static const _maximumManifestBytes = 16 * 1024 * 1024;
  // Settings contain structured preferences, never chat rows or binary assets.
  // Cap JSON before copying/parsing to bound UTF-8 and DOM amplification.
  static const _maximumSettingsBytes = 16 * 1024 * 1024;

  static Future<StagedRestoreBundle> create({
    required Directory appDataDirectory,
    required Directory extractedDirectory,
    required bool includeChats,
    required bool includeFiles,
    required String sourceManifestSha256,
  }) async {
    final workspaceLock = RestoreWorkspaceLock(
      appDataDirectory: appDataDirectory,
    );
    final allocation = await workspaceLock.synchronized(() async {
      await _requireAvailableWorkspace(workspaceLock.workspaceRoot);
      return _createRunWorkspace(workspaceLock.workspaceRoot);
    });
    final runId = allocation.runId;
    final workspace = allocation.workspace;
    final payloadDirectory = Directory(p.join(workspace.path, 'candidate'));
    final stagedEntries = <String, _StagedRestoreEntry>{};

    try {
      await _verifySameFilesystem(appDataDirectory, workspace);
      await payloadDirectory.create(recursive: true);
      final sourceManifestFile = File(
        p.join(extractedDirectory.path, 'manifest.json'),
      );
      final sourceManifestBytes = await _readBoundedBytes(
        sourceManifestFile,
        maximumBytes: _maximumManifestBytes,
        error: 'restore_staging_manifest',
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
      if (decodedManifest['includeChats'] != includeChats ||
          decodedManifest['includeFiles'] != includeFiles ||
          decodedManifest['entries'] is! Map) {
        throw const FormatException('restore_staging_manifest');
      }
      final manifest = decodedManifest;
      final declaredEntries = _parseDeclaredEntries(
        manifest,
        includeChats: includeChats,
        includeFiles: includeFiles,
      );

      const settingsEntry = 'settings.json';
      stagedEntries[settingsEntry] = await _copyVerified(
        File(p.join(extractedDirectory.path, settingsEntry)),
        File(p.join(payloadDirectory.path, settingsEntry)),
        settingsEntry,
        declaredEntries[settingsEntry]!,
      );

      if (includeChats) {
        stagedEntries[_databaseEntry] = await _copyVerified(
          File(
            p.joinAll([extractedDirectory.path, ..._databaseEntry.split('/')]),
          ),
          File(
            p.joinAll([payloadDirectory.path, ..._databaseEntry.split('/')]),
          ),
          _databaseEntry,
          declaredEntries[_databaseEntry]!,
        );
      }

      if (includeFiles) {
        for (final rootName in _assetRoots) {
          await Directory(p.join(payloadDirectory.path, rootName)).create();
        }
        final assetEntries = declaredEntries.keys.where(
          (name) => _assetRoots.any((root) => name.startsWith('$root/')),
        );
        for (final entryName in assetEntries) {
          stagedEntries[entryName] = await _copyVerified(
            File(p.joinAll([extractedDirectory.path, ...entryName.split('/')])),
            File(p.joinAll([payloadDirectory.path, ...entryName.split('/')])),
            entryName,
            declaredEntries[entryName]!,
          );
        }
      }

      if (declaredEntries.length != stagedEntries.length ||
          !declaredEntries.keys.toSet().containsAll(stagedEntries.keys)) {
        throw const FormatException('restore_staging_entries');
      }
      final sortedEntryNames = stagedEntries.keys.toList()..sort();
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
      if (stagedManifestBytes.length > _maximumManifestBytes) {
        throw const FormatException('restore_staging_manifest_size');
      }
      await stagedManifestFile.writeAsBytes(stagedManifestBytes, flush: true);
      final validated = await validateExistingCandidate(
        candidateDirectory: payloadDirectory,
        expectedManifestSha256: sha256.convert(stagedManifestBytes).toString(),
      );
      if (validated.includeChats != includeChats ||
          validated.includeFiles != includeFiles) {
        throw const FormatException('restore_staging_candidate_selection');
      }

      return StagedRestoreBundle(
        runId: runId,
        workspace: workspace,
        payloadDirectory: payloadDirectory,
        candidateManifestSha256: validated.manifestSha256,
      );
    } catch (_) {
      await _discardUnpublishedWorkspace(
        workspaceLock: workspaceLock,
        workspace: workspace,
      );
      rethrow;
    }
  }

  /// Reopens and fully validates a staged candidate without mutating it.
  static Future<ValidatedRestoreCandidate> validateExistingCandidate({
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
      maximumBytes: _maximumManifestBytes,
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
    if (manifest['format'] != _backupFormat ||
        manifest['formatVersion'] != _backupFormatVersion ||
        includeChats is! bool ||
        includeFiles is! bool ||
        payloadKind is! String ||
        manifest['createdAtUtc'] is! String ||
        manifest['appVersion'] is! String ||
        manifest['secretsIncluded'] is! bool) {
      throw const FormatException('restore_staging_manifest_fields');
    }
    final declaredEntries = _parseDeclaredEntries(
      manifest,
      includeChats: includeChats,
      includeFiles: includeFiles,
    );
    final rawDatabase = manifest['database'];
    if (includeChats) {
      if (payloadKind != 'sqlite' || rawDatabase is! Map) {
        throw const FormatException('restore_staging_database');
      }
    } else if (payloadKind != 'settings-only' || rawDatabase != null) {
      throw const FormatException('restore_staging_database');
    }

    await _validateSettings(
      File(p.join(candidateDirectory.path, 'settings.json')),
    );
    if (includeChats) {
      final databaseInfo = await ChatDatabaseRepository.inspectPreparedSnapshot(
        File(
          p.joinAll([candidateDirectory.path, ..._databaseEntry.split('/')]),
        ),
      );
      _validateDatabaseInfo(rawDatabase, databaseInfo);
    }
    await _validateCandidateTopology(
      candidateDirectory,
      expectedFiles: {...declaredEntries.keys, 'manifest.json'},
      includeChats: includeChats,
      includeFiles: includeFiles,
    );
    await _validateCandidateEntries(candidateDirectory, declaredEntries);
    return (
      includeChats: includeChats,
      includeFiles: includeFiles,
      manifestSha256: manifestSha256,
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
        if (await _readActiveRunId(activeRunFile) != runId) {
          throw StateError('restore_staging_active_run');
        }
        await workspace.create();
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
        }
        if (ownsActiveRun &&
            await FileSystemEntity.type(
                  activeRunFile.path,
                  followLinks: false,
                ) ==
                FileSystemEntityType.file) {
          await activeRunFile.delete();
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

  static Future<_StagedRestoreEntry> _copyVerified(
    File source,
    File target,
    String entryName,
    _StagedRestoreEntry expected,
  ) async {
    if (await FileSystemEntity.type(source.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw FormatException('restore_staging_source:$entryName');
    }
    final sourceBytes = await source.length();
    final sourceSha256 = await _sha256(source);
    if (sourceBytes != expected.bytes || sourceSha256 != expected.sha256) {
      throw FormatException('restore_staging_descriptor:$entryName');
    }
    await target.parent.create(recursive: true);
    await source.copy(target.path);
    final targetHandle = await target.open(mode: FileMode.append);
    try {
      await targetHandle.flush();
    } finally {
      await targetHandle.close();
    }
    final targetBytes = await target.length();
    final targetSha256 = await _sha256(target);
    if (targetBytes != sourceBytes || targetSha256 != sourceSha256) {
      throw StateError('restore_staging_copy:$entryName');
    }
    return (bytes: targetBytes, sha256: targetSha256);
  }

  static Map<String, _StagedRestoreEntry> _parseDeclaredEntries(
    Map<String, dynamic> manifest, {
    required bool includeChats,
    required bool includeFiles,
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
          name == 'settings.json' ||
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
    final hasDatabase = entries.containsKey(_databaseEntry);
    final hasAssets = entries.keys.any(
      (name) => _assetRoots.any((root) => name.startsWith('$root/')),
    );
    final settingsBytes = entries['settings.json']?.bytes;
    if (settingsBytes == null ||
        settingsBytes <= 0 ||
        settingsBytes > _maximumSettingsBytes ||
        hasDatabase != includeChats ||
        (!includeFiles && hasAssets)) {
      throw const FormatException('restore_staging_entries');
    }
    return entries;
  }

  static Future<void> _validateSettings(File settingsFile) async {
    final settings = await _readJsonMap(
      settingsFile,
      maximumBytes: _maximumSettingsBytes,
      error: 'restore_staging_settings',
    );
    BackupSettingsValidator.normalizeAndValidate(settings);
  }

  static void _validateDatabaseInfo(
    dynamic rawDatabase,
    ChatDatabaseSnapshotInfo actual,
  ) {
    if (rawDatabase is! Map) {
      throw const FormatException('restore_staging_database');
    }
    final database = rawDatabase.cast<String, dynamic>();
    if (database['entry'] != _databaseEntry ||
        database['schemaVersion'] != actual.schemaVersion ||
        database['conversationCount'] != actual.conversationCount ||
        database['messageCount'] != actual.messageCount) {
      throw const FormatException('restore_staging_database');
    }
  }

  static Future<void> _validateCandidateTopology(
    Directory candidate, {
    required Set<String> expectedFiles,
    required bool includeChats,
    required bool includeFiles,
  }) async {
    final actualFiles = <String>{};
    final actualDirectories = <String>{};
    final expectedDirectories = <String>{};
    for (final file in expectedFiles) {
      final segments = file.split('/');
      for (var index = 1; index < segments.length; index++) {
        expectedDirectories.add(segments.take(index).join('/'));
      }
    }
    if (includeFiles) expectedDirectories.addAll(_assetRoots);
    await for (final entity in candidate.list(
      recursive: true,
      followLinks: false,
    )) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      final relativePath = p
          .relative(entity.path, from: candidate.path)
          .replaceAll('\\', '/');
      if (type == FileSystemEntityType.directory) {
        if (!expectedDirectories.contains(relativePath)) {
          throw const FormatException('restore_staging_candidate_directory');
        }
        actualDirectories.add(relativePath);
        continue;
      }
      if (type != FileSystemEntityType.file) {
        throw const FormatException('restore_staging_candidate_type');
      }
      actualFiles.add(relativePath);
    }
    if (actualFiles.length != expectedFiles.length ||
        !actualFiles.containsAll(expectedFiles)) {
      throw const FormatException('restore_staging_candidate_entries');
    }
    if (actualDirectories.length != expectedDirectories.length ||
        !actualDirectories.containsAll(expectedDirectories) ||
        (includeChats != expectedDirectories.contains('database'))) {
      throw const FormatException('restore_staging_candidate_directories');
    }
  }

  static Future<void> _validateCandidateEntries(
    Directory candidate,
    Map<String, _StagedRestoreEntry> expectedEntries,
  ) async {
    for (final entry in expectedEntries.entries) {
      final file = File(p.joinAll([candidate.path, ...entry.key.split('/')]));
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
              FileSystemEntityType.file ||
          await file.length() != entry.value.bytes ||
          await _sha256(file) != entry.value.sha256) {
        throw FormatException('restore_staging_candidate:${entry.key}');
      }
    }
  }

  static Future<String> _sha256(File file) async {
    return (await sha256.bind(file.openRead()).first).toString();
  }

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

  static Future<Map<String, dynamic>> _readJsonMap(
    File file, {
    required int maximumBytes,
    required String error,
  }) async {
    return _decodeJsonMap(
      await _readBoundedBytes(file, maximumBytes: maximumBytes, error: error),
      error: error,
    );
  }

  static Future<List<int>> _readBoundedBytes(
    File file, {
    required int maximumBytes,
    required String error,
  }) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw FormatException(error);
    }
    final handle = await file.open(mode: FileMode.read);
    final bytes = BytesBuilder(copy: false);
    try {
      while (bytes.length <= maximumBytes) {
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

  static Future<void> _verifySameFilesystem(
    Directory appDataDirectory,
    Directory workspace,
  ) async {
    final probeName = '.restore_probe_${p.basename(workspace.path)}';
    final source = File(p.join(workspace.path, probeName));
    final target = File(p.join(appDataDirectory.path, probeName));
    try {
      if (await FileSystemEntity.type(target.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('restore_staging_probe_collision');
      }
      await source.writeAsString('probe', flush: true);
      await source.rename(target.path);
      await target.rename(source.path);
    } finally {
      if (await source.exists()) await source.delete();
      if (await target.exists()) await target.delete();
    }
  }
}
