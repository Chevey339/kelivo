import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'restore_receipt.dart' show restoreWorkspaceRootName;

typedef _StagedRestoreEntry = ({int bytes, String sha256});

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

  static const workspaceRootName = restoreWorkspaceRootName;
  static const _assetRoots = ['upload', 'images', 'avatars', 'fonts'];

  static Future<StagedRestoreBundle> create({
    required Directory appDataDirectory,
    required Directory extractedDirectory,
    required bool includeChats,
    required bool includeFiles,
  }) async {
    final workspaceRoot = Directory(
      p.join(appDataDirectory.path, workspaceRootName),
    );
    final existingRootType = await FileSystemEntity.type(
      workspaceRoot.path,
      followLinks: false,
    );
    if (existingRootType == FileSystemEntityType.link) {
      throw FileSystemException(
        'Restore staging root must not be a link',
        workspaceRoot.path,
      );
    }
    if (existingRootType != FileSystemEntityType.notFound &&
        existingRootType != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Restore staging root is not a directory',
        workspaceRoot.path,
      );
    }
    await workspaceRoot.create(recursive: true);
    if (await FileSystemEntity.type(workspaceRoot.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw FileSystemException(
        'Restore staging root changed type',
        workspaceRoot.path,
      );
    }
    final allocation = await _createRunWorkspace(workspaceRoot);
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
      final decodedManifest = jsonDecode(
        await sourceManifestFile.readAsString(),
      );
      if (decodedManifest is! Map ||
          decodedManifest['includeChats'] != includeChats ||
          decodedManifest['includeFiles'] != includeFiles ||
          decodedManifest['entries'] is! Map) {
        throw const FormatException('restore_staging_manifest');
      }
      final manifest = decodedManifest.cast<String, dynamic>();

      const settingsEntry = 'settings.json';
      stagedEntries[settingsEntry] = await _copyVerified(
        File(p.join(extractedDirectory.path, settingsEntry)),
        File(p.join(payloadDirectory.path, settingsEntry)),
        settingsEntry,
      );

      if (includeChats) {
        const entryName = 'database/kelivo.sqlite';
        stagedEntries[entryName] = await _copyVerified(
          File(p.joinAll([extractedDirectory.path, ...entryName.split('/')])),
          File(p.joinAll([payloadDirectory.path, ...entryName.split('/')])),
          entryName,
        );
      }

      if (includeFiles) {
        for (final rootName in _assetRoots) {
          await _copyAssetRoot(
            source: Directory(p.join(extractedDirectory.path, rootName)),
            target: Directory(p.join(payloadDirectory.path, rootName)),
            rootName: rootName,
            stagedEntries: stagedEntries,
          );
        }
      }

      final declaredEntries = (manifest['entries'] as Map).keys
          .map((key) => key.toString())
          .toSet();
      if (declaredEntries.length != stagedEntries.length ||
          !declaredEntries.containsAll(stagedEntries.keys)) {
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
      await stagedManifestFile.writeAsString(jsonEncode(manifest), flush: true);
      final reopenedManifest = jsonDecode(
        await stagedManifestFile.readAsString(),
      );
      if (reopenedManifest is! Map || reopenedManifest['entries'] is! Map) {
        throw const FormatException('restore_staging_manifest_reopen');
      }
      final candidateManifestSha256 = await _sha256(stagedManifestFile);

      return StagedRestoreBundle(
        runId: runId,
        workspace: workspace,
        payloadDirectory: payloadDirectory,
        candidateManifestSha256: candidateManifestSha256,
      );
    } catch (_) {
      if (await workspace.exists()) await workspace.delete(recursive: true);
      rethrow;
    }
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
    }
    throw StateError('restore_staging_run_id_collision');
  }

  static String _newRunId() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var index = 0; index < 16; index++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static Future<void> _copyAssetRoot({
    required Directory source,
    required Directory target,
    required String rootName,
    required Map<String, _StagedRestoreEntry> stagedEntries,
  }) async {
    await target.create(recursive: true);
    if (!await source.exists()) return;

    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      final relativePath = p.relative(entity.path, from: source.path);
      final targetPath = p.join(target.path, relativePath);
      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
      } else if (entity is File) {
        final entryName = [rootName, ...p.split(relativePath)].join('/');
        stagedEntries[entryName] = await _copyVerified(
          entity,
          File(targetPath),
          entryName,
        );
      } else {
        throw FormatException('restore_staging_link:$rootName');
      }
    }
  }

  static Future<_StagedRestoreEntry> _copyVerified(
    File source,
    File target,
    String entryName,
  ) async {
    if (!await source.exists()) throw FormatException(entryName);
    final sourceBytes = await source.length();
    final sourceSha256 = await _sha256(source);
    await target.parent.create(recursive: true);
    await source.copy(target.path);
    final targetBytes = await target.length();
    final targetSha256 = await _sha256(target);
    if (targetBytes != sourceBytes || targetSha256 != sourceSha256) {
      throw StateError('restore_staging_copy:$entryName');
    }
    return (bytes: targetBytes, sha256: targetSha256);
  }

  static Future<String> _sha256(File file) async {
    return (await sha256.bind(file.openRead()).first).toString();
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
