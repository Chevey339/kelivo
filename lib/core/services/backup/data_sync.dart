import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import '../../database/business_repository.dart';
import '../../database/business_preferences.dart';
import '../../database/business_restore_service.dart';
import '../../database/business_settings_router.dart';
import '../../database/app_database.dart';
import '../../database/chat_database_repository.dart';
import '../../database/schema_migrations.dart';
import '../../models/backup.dart';
import '../../models/chat_message.dart';
import '../../models/message_part.dart';
import '../../models/conversation.dart';
import '../chat/chat_service.dart';
import '../migration/legacy_message_content_decoder.dart';
import '../migration/legacy_record_sanitizer.dart';
import '../../utils/multimodal_input_utils.dart';
import '../../../utils/app_directories.dart';
import '../../../utils/sandbox_path_resolver.dart';
import 'backup_settings_validator.dart';
import 'restore_bundle_preparation.dart';
import 'temporary_restore_file.dart';
import 'backup_cancel_token.dart';
import 'backup_isolate_runner.dart';
import 'backup_task_progress.dart';

typedef _ParsedChatBackup = ({
  List<Conversation> conversations,
  List<ChatMessage> messages,
  Map<String, List<Map<String, dynamic>>> toolEvents,
  Map<String, String> geminiThoughtSigs,
});

typedef _BackupEntryMetadata = ({int bytes, String sha256});

/// What restoring a backup file would mean for this build, determined from its
/// manifest alone.
///
/// A local file is inspected up front by [DataSync.inspectBackupCompatibility],
/// so the question reaches the user before the restore starts at all. A remote
/// backup only exists on disk after it has been downloaded, so those paths ask
/// through a [ForwardCompatibilityPrompt] instead.
typedef BackupCompatibility = ({
  int schemaVersion,
  BackupSchemaVerdict verdict,
});

/// How a caller answers [ForwardCompatibilityPrompt].
enum ForwardCompatibilityAnswer {
  /// Restore normally.
  proceed,

  /// The backup is newer than this build and made no compatibility promise,
  /// and the user accepted the risk anyway.
  proceedUnverified,

  /// Do not restore. The caller is responsible for telling the user why.
  refuse,
}

/// Asked once a backup is on disk and before anything is read out of it.
///
/// Exists for the WebDAV and S3 restores, which cannot inspect the archive
/// before downloading it. Runs on the caller's isolate, so it may show UI.
typedef ForwardCompatibilityPrompt =
    Future<ForwardCompatibilityAnswer> Function(BackupCompatibility);

typedef _VersionedBackupInfo = ({
  bool includeChats,
  bool includeFiles,
  bool secretsIncluded,
  Map<String, Object?>? businessEntityRowIds,
  String normalizedManifestSha256,
});

/// Recompute [ImagePart]/[FilePart.unavailable] against the live filesystem.
///
/// Remote/data URIs stay available. Local URIs use
/// [SandboxPathResolver.localFileExists] (structured remap only; no generic
/// images/upload basename probe).
/// Intended for post-file-restore refresh of legacy chats.json imports that
/// decoded before assets were copied.

List<MessagePart> _normalizeAttachmentPartUris(List<MessagePart> parts) {
  var changed = false;
  final out = <MessagePart>[];
  for (final part in parts) {
    if (part is ImagePart) {
      final uri = SandboxPathResolver.canonicalize(part.uri);
      if (uri != part.uri) {
        changed = true;
        out.add(
          ImagePart(
            uri: uri,
            mime: part.mime,
            assetId: part.assetId,
            unavailable: part.unavailable,
          ),
        );
      } else {
        out.add(part);
      }
    } else if (part is FilePart) {
      final uri = SandboxPathResolver.canonicalize(part.uri);
      if (uri != part.uri) {
        changed = true;
        out.add(
          FilePart(
            uri: uri,
            name: part.name,
            mime: part.mime,
            assetId: part.assetId,
            unavailable: part.unavailable,
          ),
        );
      } else {
        out.add(part);
      }
    } else {
      out.add(part);
    }
  }
  return changed ? out : parts;
}

List<MessagePart> _remapRestoredAttachmentPartUris(List<MessagePart> parts) {
  var changed = false;
  final out = <MessagePart>[];
  for (final part in parts) {
    if (part is ImagePart) {
      final uri =
          SandboxPathResolver.tryRemapRestoredManagedAbsolute(part.uri) ??
          part.uri;
      if (uri != part.uri) {
        changed = true;
        out.add(
          ImagePart(
            uri: uri,
            mime: part.mime,
            assetId: part.assetId,
            unavailable: part.unavailable,
          ),
        );
      } else {
        out.add(part);
      }
    } else if (part is FilePart) {
      final uri =
          SandboxPathResolver.tryRemapRestoredManagedAbsolute(part.uri) ??
          part.uri;
      if (uri != part.uri) {
        changed = true;
        out.add(
          FilePart(
            uri: uri,
            name: part.name,
            mime: part.mime,
            assetId: part.assetId,
            unavailable: part.unavailable,
          ),
        );
      } else {
        out.add(part);
      }
    } else {
      out.add(part);
    }
  }
  return changed ? out : parts;
}

List<MessagePart> recomputeAttachmentAvailability(
  List<MessagePart> parts, {
  bool Function(String path)? fileExists,
}) {
  final exists = fileExists ?? _attachmentExistsOnDisk;
  final out = <MessagePart>[];
  var changed = false;
  for (final part in parts) {
    if (part is ImagePart) {
      final unavailable = _unavailableForUri(part.uri, exists);
      if (unavailable != part.unavailable) changed = true;
      out.add(
        ImagePart(
          uri: part.uri,
          mime: part.mime,
          assetId: part.assetId,
          unavailable: unavailable,
        ),
      );
    } else if (part is FilePart) {
      final unavailable = _unavailableForUri(part.uri, exists);
      if (unavailable != part.unavailable) changed = true;
      out.add(
        FilePart(
          uri: part.uri,
          name: part.name,
          mime: part.mime,
          assetId: part.assetId,
          unavailable: unavailable,
        ),
      );
    } else {
      out.add(part);
    }
  }
  return changed ? out : parts;
}

bool _unavailableForUri(String uri, bool Function(String path) exists) {
  if (isRemoteOrDataUri(uri)) return false;
  return !exists(uri);
}

bool _attachmentExistsOnDisk(String path) {
  // Do not use fix(): its generic `/images/`·basename probe can mark a
  // missing external path available when a same-named managed file exists.
  return SandboxPathResolver.localFileExists(path);
}

class DataSync {
  static const _backupFormat = 'kelivo-backup';
  static const _backupFormatVersion = 2;

  /// Manifest key naming the oldest archive format that can still read a
  /// backup this build writes.
  static const backupMinimumReadableFormatKey = 'minimumReadableFormatVersion';

  /// The archive-format counterpart of
  /// [SchemaMigrations.minimumReadableSchemaVersion].
  ///
  /// [_backupFormatVersion] governs the archive -- entry names and manifest
  /// fields -- while the database schema governs the SQLite payload; the two
  /// move independently, so a build can add an ignorable directory without
  /// touching the schema, or vice versa.
  ///
  /// Raise this in lockstep with [_backupFormatVersion] whenever an archive
  /// change is NOT purely additive: a renamed or repurposed entry or manifest
  /// field, anything an older build would MISREAD rather than merely fail to
  /// recognise. Leaving it behind on a purely additive change is what lets
  /// tomorrow's backups still restore into today's build.
  static const _minimumReadableFormatVersion = 2;
  static const _manifestEntryName = 'manifest.json';
  static const _databaseEntryName = 'database/kelivo.db';
  // A 16 MiB metadata cap keeps manifest parsing and entry metadata bounded.
  static const _maxManifestBytes = 16 * 1024 * 1024;
  // Settings are parsed as one JSON object, so keep their decoded input bound.
  static const _maxSettingsBytes = 1024 * 1024 * 1024;
  // ZIP64 supports larger entries. Restore keeps explicit, diagnosable bounds.
  static const _maxRestoreEntryBytes = 8 * 1024 * 1024 * 1024;
  static const _maxRestoreTotalBytes = 16 * 1024 * 1024 * 1024;
  static const _maxRestoreEntries = 100000;

  final ChatService chatService;
  final BusinessRepository businessRepository;
  final BusinessPreferences? businessPreferences;
  BackupMergeReport? _lastMergeReport;
  BackupMergeReport? get lastMergeReport => _lastMergeReport;

  DataSync({
    required this.chatService,
    required this.businessRepository,
    this.businessPreferences,
  });

  Future<T> _runLiveBusinessRestore<T>(Future<T> Function() operation) {
    final preferences = businessPreferences;
    return preferences == null
        ? operation()
        : preferences.runWithRestoreWriteFence(operation);
  }

  static Future<void> _prepareRestoreBundle({
    required String appDataPath,
    required String extractedPath,
    required String sourceManifestSha256,
    required bool includeChats,
    required bool includeFiles,
    required bool restoreChats,
    required bool restoreFiles,
    Map<String, dynamic>? validatedSettings,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) => RestoreBundlePreparation.prepare(
    appDataDirectory: Directory(appDataPath),
    extractedDirectory: Directory(extractedPath),
    sourceManifestSha256: sourceManifestSha256,
    bundleIncludesChats: includeChats,
    bundleIncludesFiles: includeFiles,
    restoreChats: restoreChats,
    restoreFiles: restoreFiles,
    validatedSettings: validatedSettings,
    onProgress: onProgress,
    cancelToken: cancelToken,
  );

  // ===== WebDAV helpers =====
  Uri _collectionUri(WebDavConfig cfg) {
    String base = cfg.url.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    String pathPart = cfg.path.trim();
    if (pathPart.isNotEmpty) {
      pathPart = '/${pathPart.replaceAll(RegExp(r'^/+'), '')}';
    }
    // Ensure trailing slash for collection
    final full = '$base$pathPart/';
    return Uri.parse(full);
  }

  Uri _fileUri(WebDavConfig cfg, String childName) {
    final base = _collectionUri(cfg).toString();
    final child = childName.replaceAll(RegExp(r'^/+'), '');
    return Uri.parse('$base$child');
  }

  Map<String, String> _authHeaders(WebDavConfig cfg) {
    if (cfg.username.trim().isEmpty) return {};
    final token = base64Encode(utf8.encode('${cfg.username}:${cfg.password}'));
    return {'Authorization': 'Basic $token'};
  }

  Map<String, String> _extraHeaders(WebDavConfig cfg) {
    final h = <String, String>{};
    final ua = cfg.userAgent.trim();
    if (ua.isNotEmpty) h['User-Agent'] = ua;
    return h;
  }

  Future<void> _ensureCollection(
    WebDavConfig cfg, {
    BackupCancelToken? cancelToken,
  }) async {
    final client = http.Client();
    StreamSubscription<void>? cancelSub;
    try {
      cancelSub = cancelToken?.whenCancelled.asStream().listen((_) {
        client.close();
      });
      if (cancelToken?.isCancelled == true) {
        throw const BackupCancelledException();
      }
      // Ensure each segment exists
      final url = cfg.url.trim().replaceAll(RegExp(r'/+$'), '');
      final segments = cfg.path
          .split('/')
          .where((s) => s.trim().isNotEmpty)
          .toList();
      String acc = url;
      for (final seg in segments) {
        acc = '$acc/$seg';
        // PROPFIND depth 0 on this collection (with trailing slash)
        final u = Uri.parse('$acc/');
        final req = http.Request('PROPFIND', u);
        req.headers.addAll({
          'Depth': '0',
          'Content-Type': 'application/xml; charset=utf-8',
          ..._authHeaders(cfg),
          ..._extraHeaders(cfg),
        });
        req.body =
            '<?xml version="1.0" encoding="utf-8" ?><d:propfind xmlns:d="DAV:"><d:prop><d:displayname/></d:prop></d:propfind>';
        final res = await client.send(req).then(http.Response.fromStream);
        if (res.statusCode == 404) {
          // create this level
          final mk = await client
              .send(
                http.Request('MKCOL', u)
                  ..headers.addAll({
                    ..._authHeaders(cfg),
                    ..._extraHeaders(cfg),
                  }),
              )
              .then(http.Response.fromStream);
          if (mk.statusCode != 201 &&
              mk.statusCode != 200 &&
              mk.statusCode != 405) {
            throw Exception('MKCOL failed at $u: ${mk.statusCode}');
          }
        } else if (res.statusCode == 401) {
          throw Exception('Unauthorized');
        } else if (!(res.statusCode >= 200 && res.statusCode < 400)) {
          // Some servers return 207 Multi-Status; accept 2xx/3xx/207
          if (res.statusCode != 207) {
            throw Exception('PROPFIND error at $u: ${res.statusCode}');
          }
        }
        if (cancelToken?.isCancelled == true) {
          throw const BackupCancelledException();
        }
      }
    } catch (error) {
      if (error is BackupCancelledException ||
          cancelToken?.isCancelled == true) {
        throw const BackupCancelledException();
      }
      rethrow;
    } finally {
      await cancelSub?.cancel();
      client.close();
    }
  }

  // ===== Public APIs =====
  Future<void> testWebdav(WebDavConfig cfg) async {
    final uri = _collectionUri(cfg);
    final req = http.Request('PROPFIND', uri);
    req.headers.addAll({
      'Depth': '1',
      'Content-Type': 'application/xml; charset=utf-8',
      ..._authHeaders(cfg),
      ..._extraHeaders(cfg),
    });
    req.body =
        '<?xml version="1.0" encoding="utf-8" ?>\n'
        '<d:propfind xmlns:d="DAV:">\n'
        '  <d:prop>\n'
        '    <d:displayname/>\n'
        '  </d:prop>\n'
        '</d:propfind>';
    final res = await http.Client().send(req).then(http.Response.fromStream);
    if (res.statusCode != 207 &&
        (res.statusCode < 200 || res.statusCode >= 300)) {
      throw Exception('WebDAV test failed: ${res.statusCode}');
    }
  }

  Future<File> prepareBackupFile(
    WebDavConfig cfg, {
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    final tmp = await _ensureTempDir();
    await _cleanupPreviousBackupTempFiles(tmp);
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final workDir = Directory(p.join(tmp.path, 'kelivo_backup_$timestamp'));
    await workDir.create(recursive: true);
    registerLiveTempPath(workDir.path);

    final outPath = p.join(workDir.path, 'kelivo_backup_$timestamp.zip');
    final outFile = File(outPath);
    if (await outFile.exists()) await outFile.delete();

    File? manifestTmp;
    File? settingsTmp;
    File? databaseTmp;
    var abandonWorkDir = false;
    try {
      onProgress?.call(
        const BackupProgress(
          phase: BackupPhase.preparing,
          processed: 0,
          cancellable: true,
        ),
      );
      if (cancelToken?.isCancelled == true) {
        throw const BackupCancelledException();
      }
      // --- Step 1: Prepare temp files that need ChatService (main isolate) ---
      // settings.json
      final businessExport = await _exportBusinessSettings();
      final settingsFile = await _writeTempText(
        workDir,
        '_bk_settings.json',
        businessExport.settingsJson,
      );
      settingsTmp = settingsFile;

      ChatDatabaseSnapshotInfo? snapshotInfo;
      if (cfg.includeChats) {
        final databaseFile = File(p.join(workDir.path, '_bk_kelivo.db'));
        databaseTmp = databaseFile;
        onProgress?.call(
          const BackupProgress(
            phase: BackupPhase.snapshottingDatabase,
            processed: 0,
            cancellable: true,
          ),
        );
        snapshotInfo = await chatService.createBackupDatabaseSnapshot(
          databaseFile,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.buildNumber.trim().isEmpty
          ? packageInfo.version
          : '${packageInfo.version}+${packageInfo.buildNumber}';
      final manifestFile = File(p.join(workDir.path, '_bk_manifest.json'));
      manifestTmp = manifestFile;

      // Resolve directory paths (need AppDirectories on main isolate)
      final uploadDirPath = (await _getUploadDir()).path;
      final avatarsDirPath = (await _getAvatarsDir()).path;
      final imagesDirPath = (await _getImagesDir()).path;
      final fontsDirPath = (await _getFontsDir()).path;
      final manifestPath = manifestFile.path;
      final settingsPath = settingsFile.path;
      final databasePath = databaseTmp?.path;
      final includeFiles = cfg.includeFiles;

      // --- Step 2: Run CPU-heavy ZIP packing in a separate isolate ---
      await runBackupIsolate<void, _BackupPackArgs>(
        body: _packAndVerifyInIsolate,
        payload: _BackupPackArgs(
          outPath: outPath,
          manifestPath: manifestPath,
          settingsPath: settingsPath,
          databasePath: databasePath,
          snapshotInfo: snapshotInfo,
          includeChats: cfg.includeChats,
          includeFiles: includeFiles,
          appVersion: appVersion,
          businessEntityRowIds: businessExport.entityRowIds,
          uploadDirPath: uploadDirPath,
          avatarsDirPath: avatarsDirPath,
          imagesDirPath: imagesDirPath,
          fontsDirPath: fontsDirPath,
        ),
        cancelToken: cancelToken,
        onProgress: onProgress,
      );

      return takePreparedBackupFile(outFile, cancelToken);
    } catch (error) {
      if (shouldDeleteTempPathsAfterIsolateError(error)) {
        unregisterLiveTempPath(workDir.path);
        await _deleteDirectoryQuietly(workDir);
      } else {
        abandonWorkDir = true;
        await deleteTempDirectoryWhenIsolateSafe(workDir, error: error);
      }
      rethrow;
    } finally {
      // Cleanup temp intermediate files. The final zip is returned to callers
      // and must be deleted by the upload/export caller after it is consumed.
      // If a snapshot/pack isolate is still alive, leave the directory alone.
      if (!abandonWorkDir) {
        await _deleteFileQuietly(settingsTmp);
        await _deleteFileQuietly(databaseTmp);
        await _deleteFileQuietly(manifestTmp);
      }
    }
  }

  static Future<void> cleanupTemporaryBackupFile(File? file) async {
    if (file == null) return;
    final parent = file.parent;
    unregisterLiveTempPath(file.path);
    unregisterLiveTempPath(parent.path);
    await _deleteFileQuietly(file);
    try {
      if (await parent.exists() && await parent.list().isEmpty) {
        await parent.delete();
      }
    } catch (_) {}
  }

  @visibleForTesting
  static Future<void> completeLocalFileExport({
    required File exported,
    required Future<void> Function(File exported) persist,
  }) async {
    try {
      await persist(exported);
    } finally {
      await cleanupTemporaryBackupFile(exported);
    }
  }

  @visibleForTesting
  static File takePreparedBackupFile(
    File outFile,
    BackupCancelToken? cancelToken,
  ) {
    if (cancelToken?.isCancelled == true) {
      throw const BackupCancelledException();
    }
    return outFile;
  }

  static Future<void> _deleteFileQuietly(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static Future<void> _deleteDirectoryQuietly(Directory? directory) async {
    if (directory == null) return;
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (_) {}
  }

  @visibleForTesting
  static bool shouldDeleteTempPathsAfterIsolateError(Object? error) {
    if (error is BackupIsolateTimeoutException) return error.isolateExited;
    if (error is BackupCancelledException) return error.isolateExited;
    return true;
  }

  static Future<void> deleteTempDirectoryWhenIsolateSafe(
    Directory directory, {
    Object? error,
  }) async {
    if (shouldDeleteTempPathsAfterIsolateError(error)) {
      unregisterLiveTempPath(directory.path);
      await _deleteDirectoryQuietly(directory);
      return;
    }
    final isolateExit = error == null ? null : backupIsolateExitFuture(error);
    if (isolateExit == null) return;
    unawaited(
      isolateExit.then((_) {
        unregisterLiveTempPath(directory.path);
        return _deleteDirectoryQuietly(directory);
      }),
    );
  }

  static final Set<String> _liveTempPaths = {};

  static void registerLiveTempPath(String path) {
    _liveTempPaths.add(p.normalize(p.absolute(path)));
  }

  static void unregisterLiveTempPath(String path) {
    _liveTempPaths.remove(p.normalize(p.absolute(path)));
  }

  static bool _isLiveTempPath(String path) {
    final normalized = p.normalize(p.absolute(path));
    for (final live in _liveTempPaths) {
      if (normalized == live ||
          p.isWithin(live, normalized) ||
          p.isWithin(normalized, live)) {
        return true;
      }
    }
    return false;
  }

  @visibleForTesting
  static Future<void> debugCleanupPreviousBackupTempFiles(Directory tmp) {
    return _cleanupPreviousBackupTempFiles(tmp);
  }

  /// Parses the creation time out of a `kelivo_backup_<iso-with-dashes>` name
  /// (see [prepareBackupFile], which replaces ':' with '-'). Returns null for
  /// names that do not carry a timestamp.
  static DateTime? _backupTempTimestampFromName(String name) {
    const prefix = 'kelivo_backup_';
    if (!name.startsWith(prefix)) return null;
    var core = name.substring(prefix.length);
    if (core.endsWith('.zip')) {
      core = core.substring(0, core.length - 4);
    }
    final match = RegExp(
      r'^(\d{4}-\d{2}-\d{2})T(\d{2})-(\d{2})-(\d{2})(.*)$',
    ).firstMatch(core);
    if (match == null) return null;
    return DateTime.tryParse(
      '${match[1]}T${match[2]}:${match[3]}:${match[4]}${match[5]}',
    );
  }

  static Future<void> _cleanupPreviousBackupTempFiles(Directory tmp) async {
    try {
      if (!await tmp.exists()) return;
      // Only reclaim entries that are clearly abandoned. WebDAV, S3 and local
      // export are independent providers with no shared busy flag, so an
      // age-blind sweep here would delete the working directory of a backup
      // that another provider is still packing or uploading.
      final cutoff = DateTime.now().subtract(const Duration(hours: 6));
      Future<bool> isStale(FileSystemEntity entity, String name) async {
        final fromName = _backupTempTimestampFromName(name);
        if (fromName != null) return fromName.isBefore(cutoff);
        try {
          return (await entity.stat()).modified.isBefore(cutoff);
        } catch (_) {
          // Unknown age: keep it rather than risk racing a live backup.
          return false;
        }
      }

      await for (final ent in tmp.list(followLinks: false)) {
        if (_isLiveTempPath(ent.path)) continue;
        final name = p.basename(ent.path);
        if (ent is Directory && name.startsWith('kelivo_backup_')) {
          if (await isStale(ent, name)) await _deleteDirectoryQuietly(ent);
        } else if (ent is File &&
            ((name.startsWith('kelivo_backup_') && name.endsWith('.zip')) ||
                name == '_bk_settings.json' ||
                name == '_bk_chats.json' ||
                name == '_bk_manifest.json' ||
                name == '_bk_kelivo.db')) {
          if (await isStale(ent, name)) await _deleteFileQuietly(ent);
        }
      }
    } catch (_) {}
  }

  /// Synchronous ZIP packing — runs inside an Isolate.
  static void _packAndVerifyInIsolate(
    BackupIsolateContext ctx,
    _BackupPackArgs args,
  ) {
    final expectedEntries = _packZipSync(
      outPath: args.outPath,
      manifestPath: args.manifestPath,
      settingsPath: args.settingsPath,
      databasePath: args.databasePath,
      snapshotInfo: args.snapshotInfo,
      includeChats: args.includeChats,
      includeFiles: args.includeFiles,
      appVersion: args.appVersion,
      businessEntityRowIds: args.businessEntityRowIds,
      uploadDirPath: args.uploadDirPath,
      avatarsDirPath: args.avatarsDirPath,
      imagesDirPath: args.imagesDirPath,
      fontsDirPath: args.fontsDirPath,
      ctx: ctx,
    );
    _verifyPackedBackupSync(
      zipPath: args.outPath,
      expectedEntries: expectedEntries,
      ctx: ctx,
    );
  }

  static int _fileSizeSync(String? path) {
    if (path == null) return 0;
    final file = File(path);
    return file.existsSync() ? file.lengthSync() : 0;
  }

  static List<File> _listFilesSync(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return const [];
    return [
      for (final entity in dir.listSync(recursive: true, followLinks: false))
        if (entity is File) entity,
    ];
  }

  static Map<String, _BackupEntryMetadata> _packZipSync({
    required String outPath,
    required String manifestPath,
    required String settingsPath,
    String? databasePath,
    required ChatDatabaseSnapshotInfo? snapshotInfo,
    required bool includeChats,
    required bool includeFiles,
    required String appVersion,
    required Map<String, List<String>> businessEntityRowIds,
    required String uploadDirPath,
    required String avatarsDirPath,
    required String imagesDirPath,
    required String fontsDirPath,
    BackupIsolateContext? ctx,
  }) {
    if (includeChats != (databasePath != null && snapshotInfo != null)) {
      throw StateError('backup_database_component');
    }
    final uploadFiles = includeFiles
        ? _listFilesSync(uploadDirPath)
        : const <File>[];
    final avatarFiles = includeFiles
        ? _listFilesSync(avatarsDirPath)
        : const <File>[];
    final imageFiles = includeFiles
        ? _listFilesSync(imagesDirPath)
        : const <File>[];
    final fontFiles = includeFiles
        ? _listFilesSync(fontsDirPath)
        : const <File>[];
    var totalBytes = _fileSizeSync(settingsPath) + _fileSizeSync(databasePath);
    for (final file in [
      ...uploadFiles,
      ...avatarFiles,
      ...imageFiles,
      ...fontFiles,
    ]) {
      totalBytes += file.lengthSync();
    }
    final meter = _BackupByteMeter(
      ctx: ctx,
      phase: BackupPhase.packing,
      total: totalBytes,
    );
    meter.report();
    final writer = _StreamingZipWriter(outPath, meter: meter);
    try {
      final entries = <String, _BackupEntryMetadata>{};
      final collisionKeys = <String>{};
      _addFileToZip(
        writer,
        settingsPath,
        'settings.json',
        entries,
        collisionKeys,
      );

      if (databasePath != null) {
        _addFileToZip(
          writer,
          databasePath,
          _databaseEntryName,
          entries,
          collisionKeys,
        );
      }

      if (includeFiles) {
        _addDirectoryToZip(
          writer,
          uploadDirPath,
          'upload',
          entries,
          collisionKeys,
          files: uploadFiles,
        );
        _addDirectoryToZip(
          writer,
          avatarsDirPath,
          'avatars',
          entries,
          collisionKeys,
          files: avatarFiles,
        );
        _addDirectoryToZip(
          writer,
          imagesDirPath,
          'images',
          entries,
          collisionKeys,
          files: imageFiles,
        );
        _addDirectoryToZip(
          writer,
          fontsDirPath,
          'fonts',
          entries,
          collisionKeys,
          files: fontFiles,
        );
      }

      final manifestJson = _buildBackupManifestJson(
        entries: entries,
        snapshotInfo: snapshotInfo,
        includeChats: includeChats,
        includeFiles: includeFiles,
        appVersion: appVersion,
        businessEntityRowIds: businessEntityRowIds,
      );
      final manifestFile = File(manifestPath)
        ..writeAsStringSync(manifestJson, flush: true);
      entries[_manifestEntryName] = writer.addFile(
        manifestFile,
        _manifestEntryName,
      );
      writer.closeSync();
      return entries;
    } finally {
      writer.closeIfNeededSync();
    }
  }

  static void _verifyPackedBackupSync({
    required String zipPath,
    required Map<String, _BackupEntryMetadata> expectedEntries,
    BackupIsolateContext? ctx,
  }) {
    final expectedNames = {...expectedEntries.keys, _manifestEntryName};
    final inputStream = InputFileStream(zipPath);
    try {
      final rawEntryNames = <String>[];
      final archive = ZipDecoder().decodeStream(
        inputStream,
        callback: (entry) => rawEntryNames.add(entry.name),
      );
      try {
        final actualNames = <String>{};
        for (final rawName in rawEntryNames) {
          final canonical = _zipEntryName(rawName);
          if (!actualNames.add(canonical)) {
            throw FormatException('duplicate_zip_entry:$canonical');
          }
        }
        if (actualNames.length != expectedNames.length ||
            !actualNames.containsAll(expectedNames)) {
          throw const FormatException('backup_entries');
        }

        final verifyTotal = expectedEntries.values.fold<int>(
          0,
          (sum, metadata) => sum + metadata.bytes,
        );
        final meter = _BackupByteMeter(
          ctx: ctx,
          phase: BackupPhase.verifying,
          total: verifyTotal,
        );
        meter.report();
        for (final entry in archive) {
          if (!entry.isFile) continue;
          final canonical = _zipEntryName(entry.name);
          ctx?.throwIfCancelled();
          final digest = _NullDigestOutputStream(
            onBytes: (bytes) => meter.add(bytes, detail: canonical),
          );
          try {
            entry.writeContent(digest);
            final actualSha256 = digest.closeAndDigest();
            final expected = expectedEntries[canonical];
            if (expected == null) {
              throw FormatException('backup_entry_unexpected:$canonical');
            }
            if (digest.bytesWritten != expected.bytes) {
              throw FormatException('manifest_entry_size:$canonical');
            }
            if (actualSha256 != expected.sha256) {
              throw FormatException('manifest_entry_hash:$canonical');
            }
          } finally {
            digest.closeSync();
          }
        }
      } finally {
        archive.clearSync();
      }
    } finally {
      inputStream.closeSync();
    }
  }

  static void _addFileToZip(
    _StreamingZipWriter writer,
    String filePath,
    String entryName,
    Map<String, _BackupEntryMetadata> entries,
    Set<String> collisionKeys,
  ) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('Backup entry does not exist', filePath);
    }
    final canonicalName = _zipEntryName(entryName);
    final collisionKey = canonicalName.toLowerCase();
    if (!collisionKeys.add(collisionKey)) {
      throw StateError('backup_entry_collision:$canonicalName');
    }
    entries[canonicalName] = writer.addFile(file, canonicalName);
  }

  /// Add all files from [srcDirPath] into the zip under [zipPrefix].
  static void _addDirectoryToZip(
    _StreamingZipWriter writer,
    String srcDirPath,
    String zipPrefix,
    Map<String, _BackupEntryMetadata> entries,
    Set<String> collisionKeys, {
    List<File>? files,
  }) {
    final fileSystemEntries =
        files ??
        [
          for (final entity
              in Directory(srcDirPath).existsSync()
                  ? Directory(
                      srcDirPath,
                    ).listSync(recursive: true, followLinks: false)
                  : const <FileSystemEntity>[])
            if (entity is File) entity,
        ];
    for (final ent in fileSystemEntries) {
      final rel = p.relative(ent.path, from: srcDirPath);
      // ZIP entries must use forward slashes regardless of platform
      final relPosix = rel.replaceAll('\\', '/');
      _addFileToZip(
        writer,
        ent.path,
        '$zipPrefix/$relPosix',
        entries,
        collisionKeys,
      );
    }
  }

  static String _zipEntryName(String name) {
    return name.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');
  }

  /// Decode a DOS date/time packed value (from ZIP entry's lastModTime) into
  /// a [DateTime]. Returns null when the date portion is zero (unset).
  static DateTime? _decodeDosDateTime(int packed) {
    final dosDate = packed >> 16;
    final dosTime = packed & 0xFFFF;
    if (dosDate == 0) return null;
    final year = ((dosDate >> 9) & 0x7f) + 1980;
    final month = (dosDate >> 5) & 0x0f;
    final day = dosDate & 0x1f;
    final hour = (dosTime >> 11) & 0x1f;
    final minute = (dosTime >> 5) & 0x3f;
    final second = (dosTime & 0x1f) * 2;
    try {
      return DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      return null;
    }
  }

  /// Synchronous ZIP extraction — runs inside an Isolate.
  /// Uses InputFileStream so the ZIP bytes are read from disk on demand rather
  /// than loading the entire archive into a single byte array.
  static void _extractZipInIsolate(
    BackupIsolateContext ctx,
    _BackupExtractArgs args,
  ) {
    _extractZipSync(args.zipPath, args.extractDirPath, ctx: ctx);
  }

  static void _extractZipSync(
    String zipPath,
    String extractDirPath, {
    BackupIsolateContext? ctx,
  }) {
    final inputStream = InputFileStream(zipPath);
    try {
      final rawEntryNames = <String>[];
      final archive = ZipDecoder().decodeStream(
        inputStream,
        callback: (entry) => rawEntryNames.add(entry.name),
      );
      try {
        if (rawEntryNames.length > _maxRestoreEntries) {
          throw const FormatException('zip_entry_count');
        }
        final seenNames = <String>{};
        for (final rawName in rawEntryNames) {
          final canonical = _validatedZipEntryName(rawName);
          if (!seenNames.add(canonical.toLowerCase())) {
            throw FormatException('duplicate_zip_entry:$canonical');
          }
        }

        final archiveFiles = <String, ArchiveFile>{};
        final allEntryNames = <String>[];
        for (final entry in archive) {
          if (entry.isSymbolicLink) {
            throw FormatException('symbolic_link:${entry.name}');
          }
          final canonical = _validatedZipEntryName(entry.name);
          allEntryNames.add(canonical);
          if (entry.isFile) {
            archiveFiles[canonical] = entry;
          }
        }
        _validateZipPathPrefixes(allEntryNames, archiveFiles.keys);

        final settingsEntry = archiveFiles['settings.json'];
        if (settingsEntry != null &&
            (settingsEntry.size <= 0 ||
                settingsEntry.size > _maxSettingsBytes)) {
          throw const FormatException('settings_size');
        }

        final manifestEntry = archiveFiles[_manifestEntryName];
        Map<String, int>? declaredEntrySizes;
        if (manifestEntry != null) {
          if (manifestEntry.size < 0 ||
              manifestEntry.size > _maxManifestBytes) {
            throw const FormatException('manifest_size');
          }
          final manifestPath = p.join(extractDirPath, _manifestEntryName);
          final manifestOutput = _BoundedOutputFileStream(
            manifestPath,
            expectedBytes: manifestEntry.size,
            maxEntryBytes: _maxManifestBytes,
            budget: _ExtractionBudget(maxTotalBytes: _maxManifestBytes),
          );
          try {
            manifestEntry.writeContent(manifestOutput);
            manifestOutput.verifyComplete();
          } finally {
            manifestOutput.closeSync();
          }
          final manifestBytes = File(manifestPath).readAsBytesSync();
          declaredEntrySizes = _declaredManifestEntrySizes(manifestBytes);
          final actualEntries = archiveFiles.keys.toSet()
            ..remove(_manifestEntryName);
          if (actualEntries.length != declaredEntrySizes.length ||
              !actualEntries.containsAll(declaredEntrySizes.keys)) {
            throw const FormatException('manifest_entries');
          }
          for (final declaredEntry in declaredEntrySizes.entries) {
            if (archiveFiles[declaredEntry.key]!.size != declaredEntry.value) {
              throw FormatException('manifest_entry_size:${declaredEntry.key}');
            }
          }
        } else if (archiveFiles.containsKey(_databaseEntryName)) {
          throw const FormatException('database_manifest');
        }

        var declaredTotalBytes = 0;
        for (final entry in archiveFiles.values) {
          if (entry.size < 0 || entry.size > _maxRestoreEntryBytes) {
            throw FormatException('zip_entry_size:${entry.name}');
          }
          declaredTotalBytes += entry.size;
          if (declaredTotalBytes > _maxRestoreTotalBytes) {
            throw const FormatException('zip_total_size');
          }
        }
        final extractionBudget = _ExtractionBudget(
          maxTotalBytes: _maxRestoreTotalBytes,
        );
        if (manifestEntry != null) {
          extractionBudget.reserve(manifestEntry.size);
        }
        final extractTotal = archiveFiles.entries
            .where((entry) => entry.key != _manifestEntryName)
            .fold<int>(0, (sum, entry) => sum + entry.value.size);
        final meter = _BackupByteMeter(
          ctx: ctx,
          phase: BackupPhase.extracting,
          total: extractTotal,
        );
        meter.report();
        for (final entry in archive) {
          final canonical = _validatedZipEntryName(entry.name);
          if (canonical == _manifestEntryName) continue;
          final parts = canonical.split('/');
          final outPath = p.joinAll([extractDirPath, ...parts]);
          if (entry.isFile) {
            File(outPath).parent.createSync(recursive: true);
            final output = _BoundedOutputFileStream(
              outPath,
              expectedBytes: declaredEntrySizes?[canonical] ?? entry.size,
              maxEntryBytes: _maxRestoreEntryBytes,
              budget: extractionBudget,
              meter: meter,
            );
            try {
              entry.writeContent(output);
              output.verifyComplete();
            } finally {
              output.closeSync();
            }
            final dt = _decodeDosDateTime(entry.lastModTime);
            if (dt != null) {
              try {
                File(outPath).setLastModifiedSync(dt);
              } catch (_) {}
            }
          } else {
            Directory(outPath).createSync(recursive: true);
          }
        }
        if (extractTotal > 0 && meter.processed != extractTotal) {
          meter.processed = extractTotal;
        }
        if (extractTotal > 0) {
          meter.report();
        }
      } finally {
        archive.clearSync();
      }
    } finally {
      inputStream.closeSync();
    }
  }

  static String _validatedZipEntryName(String rawName) {
    if (rawName.isEmpty || rawName.contains('\u0000')) {
      throw const FormatException('zip_entry_name');
    }
    final normalized = rawName.replaceAll('\\', '/');
    if (normalized.startsWith('/') ||
        normalized.startsWith('//') ||
        RegExp(r'^[A-Za-z]:($|/)').hasMatch(normalized)) {
      throw FormatException('absolute_zip_entry:$rawName');
    }
    final parts = normalized.split('/');
    if (parts.isNotEmpty && parts.last.isEmpty) {
      parts.removeLast();
    }
    if (parts.isEmpty ||
        parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw FormatException('invalid_zip_entry:$rawName');
    }
    return parts.join('/');
  }

  static void _validateZipPathPrefixes(
    Iterable<String> allEntries,
    Iterable<String> fileEntries,
  ) {
    final files = fileEntries.map((name) => name.toLowerCase()).toSet();
    for (final entry in allEntries) {
      final parts = entry.toLowerCase().split('/');
      for (var i = 1; i < parts.length; i++) {
        if (files.contains(parts.take(i).join('/'))) {
          throw FormatException('zip_path_prefix:$entry');
        }
      }
    }
  }

  static Map<String, int> _declaredManifestEntrySizes(List<int> manifestBytes) {
    final decoded = jsonDecode(utf8.decode(manifestBytes));
    if (decoded is! Map) {
      throw const FormatException('manifest.json');
    }
    final manifest = decoded.cast<String, dynamic>();
    if (manifest['format'] != _backupFormat ||
        !_acceptsArchiveFormat(manifest)) {
      throw const FormatException('manifest_version');
    }
    final rawEntries = manifest['entries'];
    if (rawEntries is! Map) {
      throw const FormatException('manifest_entries');
    }
    final entries = <String, int>{};
    final caseFolded = <String>{};
    for (final rawEntry in rawEntries.entries) {
      final rawName = rawEntry.key;
      if (rawName is! String || rawEntry.value is! Map) {
        throw const FormatException('manifest_entry_name');
      }
      final canonical = _validatedZipEntryName(rawName);
      if (canonical != rawName || canonical == _manifestEntryName) {
        throw FormatException('manifest_entry_name:$rawName');
      }
      if (!caseFolded.add(canonical.toLowerCase())) {
        throw FormatException('manifest_entry_collision:$canonical');
      }
      final metadata = (rawEntry.value as Map).cast<String, dynamic>();
      final bytes = metadata['bytes'];
      if (bytes is! int || bytes < 0) {
        throw FormatException('manifest_entry_size:$canonical');
      }
      entries[canonical] = bytes;
    }
    return entries;
  }

  Future<void> backupToWebDav(
    WebDavConfig cfg, {
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    final file = await prepareBackupFile(
      cfg,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    try {
      await _ensureCollection(cfg, cancelToken: cancelToken);
      if (cancelToken?.isCancelled == true) {
        throw const BackupCancelledException();
      }
      final target = _fileUri(cfg, p.basename(file.path));
      final fileLen = await file.length();
      // Use a streamed request so we don't load the entire file into RAM.
      final req = http.StreamedRequest('PUT', target);
      req.headers.addAll({
        'content-type': 'application/zip',
        'content-length': fileLen.toString(),
        ..._authHeaders(cfg),
        ..._extraHeaders(cfg),
      });
      // Pipe the file stream into the request body. addStream honors the
      // sink's pause signal, so a slow network throttles disk reads instead of
      // buffering the whole zip in RAM (which OOM-killed large mobile uploads).
      unawaited(
        req.sink
            .addStream(
              _watchedByteStream(
                file.openRead(),
                phase: BackupPhase.uploading,
                total: fileLen,
                onProgress: onProgress,
                cancelToken: cancelToken,
              ),
            )
            .then(
              (_) => req.sink.close(),
              onError: (Object error) {
                req.sink.addError(error);
                req.sink.close();
              },
            ),
      );
      final client = http.Client();
      StreamSubscription<void>? cancelSub;
      try {
        cancelSub = cancelToken?.whenCancelled.asStream().listen((_) {
          client.close();
        });
        final res = await client.send(req).then(http.Response.fromStream);
        if (cancelToken?.isCancelled == true) {
          throw const BackupCancelledException();
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw Exception('Upload failed: ${res.statusCode}');
        }
      } catch (error) {
        if (error is BackupCancelledException ||
            cancelToken?.isCancelled == true) {
          await _deleteRemoteQuietly(cfg, target);
          throw const BackupCancelledException();
        }
        rethrow;
      } finally {
        await cancelSub?.cancel();
        client.close();
      }
    } finally {
      await cleanupTemporaryBackupFile(file);
    }
  }

  Future<List<BackupFileItem>> listBackupFiles(
    WebDavConfig cfg, {
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    onProgress?.call(
      const BackupProgress(
        phase: BackupPhase.listingRemote,
        processed: 0,
        cancellable: true,
      ),
    );
    await _ensureCollection(cfg, cancelToken: cancelToken);
    if (cancelToken?.isCancelled == true) {
      throw const BackupCancelledException();
    }
    final uri = _collectionUri(cfg);
    final req = http.Request('PROPFIND', uri);
    req.headers.addAll({
      'Depth': '1',
      'Content-Type': 'application/xml; charset=utf-8',
      ..._authHeaders(cfg),
      ..._extraHeaders(cfg),
    });
    req.body =
        '<?xml version="1.0" encoding="utf-8" ?>\n'
        '<d:propfind xmlns:d="DAV:">\n'
        '  <d:prop>\n'
        '    <d:displayname/>\n'
        '    <d:getcontentlength/>\n'
        '    <d:getlastmodified/>\n'
        '  </d:prop>\n'
        '</d:propfind>';
    final client = http.Client();
    StreamSubscription<void>? cancelSub;
    final http.Response res;
    try {
      cancelSub = cancelToken?.whenCancelled.asStream().listen((_) {
        client.close();
      });
      if (cancelToken?.isCancelled == true) {
        throw const BackupCancelledException();
      }
      res = await client.send(req).then(http.Response.fromStream);
    } catch (error) {
      if (error is BackupCancelledException ||
          cancelToken?.isCancelled == true) {
        throw const BackupCancelledException();
      }
      rethrow;
    } finally {
      await cancelSub?.cancel();
      client.close();
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('PROPFIND failed: ${res.statusCode}');
    }
    final doc = XmlDocument.parse(res.body);
    final items = <BackupFileItem>[];
    final baseStr = uri.toString();
    for (final resp in doc.findAllElements('response', namespace: '*')) {
      final href = resp.getElement('href', namespace: '*')?.innerText ?? '';
      if (href.isEmpty) continue;
      // Skip the collection itself
      final abs = Uri.parse(href).isAbsolute
          ? Uri.parse(href).toString()
          : uri.resolve(href).toString();
      if (abs == baseStr) continue;
      final disp = resp
          .findAllElements('displayname', namespace: '*')
          .map((e) => e.innerText)
          .toList();
      final sizeStr = resp
          .findAllElements('getcontentlength', namespace: '*')
          .map((e) => e.innerText)
          .cast<String>()
          .toList();
      final mtimeStr = resp
          .findAllElements('getlastmodified', namespace: '*')
          .map((e) => e.innerText)
          .cast<String>()
          .toList();
      final size = (sizeStr.isNotEmpty) ? int.tryParse(sizeStr.first) ?? 0 : 0;
      DateTime? mtime;
      if (mtimeStr.isNotEmpty) {
        try {
          mtime = DateTime.parse(mtimeStr.first);
        } catch (_) {}
      }
      final name = (disp.isNotEmpty && disp.first.trim().isNotEmpty)
          ? disp.first.trim()
          : Uri.parse(href).pathSegments.last;

      // If mtime is null, try to extract from filename (format: kelivo_backup_2025-01-19T12-34-56.123456.zip)
      if (mtime == null) {
        final match = RegExp(
          r'kelivo_backup_(\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d+)\.zip',
        ).firstMatch(name);
        if (match != null) {
          try {
            // Replace hyphens in time part back to colons
            final timestamp = match
                .group(1)!
                .replaceAll(
                  RegExp(r'T(\d{2})-(\d{2})-(\d{2})'),
                  'T\$1:\$2:\$3',
                );
            mtime = DateTime.parse(timestamp);
          } catch (_) {}
        }
      }

      // Skip directories
      if (abs.endsWith('/')) continue;
      final fullHref = Uri.parse(abs);
      items.add(
        BackupFileItem(
          href: fullHref,
          displayName: name,
          size: size,
          lastModified: mtime,
        ),
      );
    }
    items.sort(
      (a, b) => (b.lastModified ?? DateTime(0)).compareTo(
        a.lastModified ?? DateTime(0),
      ),
    );
    return items;
  }

  /// Whether this build may read an archive of the manifest's format version.
  ///
  /// An exact match, plus one relaxation: a NEWER archive that vouches for us
  /// through [backupMinimumReadableFormatKey]. An undeclared newer archive is
  /// refused -- unlike the database axis there are no undeclared newer
  /// archives in the wild to serve, since every build that can write a newer
  /// format also writes the declaration, so refusing costs nothing and keeps
  /// the strict default.
  static bool _acceptsArchiveFormat(Map<String, dynamic> manifest) {
    final formatVersion = manifest['formatVersion'];
    if (formatVersion is! int) return false;
    if (formatVersion == _backupFormatVersion) return true;
    // Older archive formats were never supported and still are not.
    if (formatVersion < _backupFormatVersion) return false;
    final declared = manifest[backupMinimumReadableFormatKey];
    return declared is int && declared >= 1 && declared <= _backupFormatVersion;
  }

  /// Whether the manifest was written by a build newer than this one, on
  /// either axis: a newer archive format, or a newer database schema.
  ///
  /// Gates what unrecognised content is tolerated. Both axes matter and they
  /// move independently -- a newer build can add an ignorable directory
  /// without touching the schema, and a settings-only backup has no schema at
  /// all -- so keying tolerance to the database alone would reject official
  /// backups this build could otherwise read.
  ///
  /// A newer format version reaching here has already passed
  /// [_acceptsArchiveFormat], so it is one that vouched for us.
  static bool _declaresNewerBuild(Map<String, dynamic> manifest) {
    final formatVersion = manifest['formatVersion'];
    if (formatVersion is int && formatVersion > _backupFormatVersion) {
      return true;
    }
    final database = manifest['database'];
    if (database is! Map) return false;
    final schemaVersion = database['schemaVersion'];
    return schemaVersion is int &&
        schemaVersion > AppDatabase.currentSchemaVersion;
  }

  /// Manifest keys this build understands. Anything else is dropped from a
  /// backup that declares a newer schema, and rejected in any other backup.
  static const _knownManifestKeys = <String>{
    'format',
    'formatVersion',
    'payloadKind',
    'createdAtUtc',
    'appVersion',
    'includeChats',
    'includeFiles',
    'secretsIncluded',
    'businessEntityRowIds',
    'database',
    'entries',
  };

  static const _knownManifestDatabaseKeys = <String>{
    'entry',
    'schemaVersion',
    SchemaMigrations.minimumReadableManifestKey,
    'conversationCount',
    'messageCount',
  };

  /// Reduces a newer build's manifest to the fields this one knows.
  ///
  /// Every validator downstream is single-version by design, and
  /// RestoreBundleStaging checks the root key set exactly, so an unrecognised
  /// field would fail the restore long after the user consented to it.
  /// Trimming here keeps that strictness intact instead of loosening it in
  /// each validator. A same-or-older backup is left alone, so an unexpected
  /// field there still fails.
  static void _stripUnknownManifestKeys(Map<String, dynamic> manifest) {
    if (!_declaresNewerBuild(manifest)) return;
    manifest.removeWhere((key, _) => !_knownManifestKeys.contains(key));
    final database = manifest['database'];
    if (database is Map) {
      database.removeWhere(
        (key, _) => !_knownManifestDatabaseKeys.contains(key),
      );
    }
    // Everything the newer format added has now been removed, so what is left
    // really is an archive in this build's format. Saying otherwise would
    // strand the staged candidate at RestoreBundleStaging's exact-match check.
    manifest['formatVersion'] = _backupFormatVersion;
  }

  /// Resolves [prompt] against [file] and returns the effective value for
  /// `allowUnverifiedForwardCompatible`.
  ///
  /// A refusal is reported as a cancellation: the prompt owns the explanation,
  /// so there is nothing left for the restore to say.
  static Future<bool> _askForwardCompatibility(
    File file, {
    required ForwardCompatibilityPrompt? prompt,
    required bool allowUnverifiedForwardCompatible,
  }) async {
    if (prompt == null) return allowUnverifiedForwardCompatible;
    final compatibility = await inspectBackupCompatibility(file);
    // No manifest or no SQLite payload: nothing to ask about, and the restore
    // itself will report any real problem.
    if (compatibility == null) return allowUnverifiedForwardCompatible;
    switch (await prompt(compatibility)) {
      case ForwardCompatibilityAnswer.refuse:
        throw const BackupCancelledException();
      case ForwardCompatibilityAnswer.proceedUnverified:
        return true;
      case ForwardCompatibilityAnswer.proceed:
        return allowUnverifiedForwardCompatible;
    }
  }

  Future<void> restoreFromWebDav(
    WebDavConfig cfg,
    BackupFileItem item, {
    RestoreMode mode = RestoreMode.overwrite,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
    bool allowUnverifiedForwardCompatible = false,
    ForwardCompatibilityPrompt? onForwardCompatibility,
  }) async {
    // Stream the download to a file instead of buffering in memory.
    final client = http.Client();
    File? file;
    StreamSubscription<void>? cancelSub;
    try {
      cancelSub = cancelToken?.whenCancelled.asStream().listen((_) {
        client.close();
      });
      if (cancelToken?.isCancelled == true) {
        throw const BackupCancelledException();
      }
      final req = http.Request('GET', item.href);
      req.headers.addAll({..._authHeaders(cfg), ..._extraHeaders(cfg)});
      final streamed = await client.send(req);
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        // Drain the response body to allow the client to close cleanly.
        await streamed.stream.drain<void>();
        throw Exception('Download failed: ${streamed.statusCode}');
      }
      final tmpDir = await _ensureTempDir();
      file = await createTemporaryRestoreFile(tmpDir);
      final knownLength = item.size > 0 ? item.size : streamed.contentLength;
      final sink = file.openWrite();
      try {
        await _watchedByteStream(
          streamed.stream,
          phase: BackupPhase.downloading,
          total: (knownLength != null && knownLength > 0) ? knownLength : null,
          onProgress: onProgress,
          cancelToken: cancelToken,
        ).pipe(sink);
      } catch (error) {
        await _deleteFileQuietly(file);
        file = null;
        if (error is BackupCancelledException ||
            cancelToken?.isCancelled == true) {
          throw const BackupCancelledException();
        }
        rethrow;
      }
      // Only now does the archive exist locally, so this is the earliest the
      // question can be put to the user.
      final allowUnverified = await _askForwardCompatibility(
        file,
        prompt: onForwardCompatibility,
        allowUnverifiedForwardCompatible: allowUnverifiedForwardCompatible,
      );
      await _restoreFromBackupFile(
        file,
        cfg,
        mode: mode,
        onProgress: onProgress,
        cancelToken: cancelToken,
        allowUnverifiedForwardCompatible: allowUnverified,
      );
    } catch (error) {
      if (error is BackupCancelledException ||
          cancelToken?.isCancelled == true) {
        throw const BackupCancelledException();
      }
      rethrow;
    } finally {
      await cancelSub?.cancel();
      client.close();
      await _deleteFileQuietly(file);
    }
  }

  Future<void> deleteWebDavBackupFile(
    WebDavConfig cfg,
    BackupFileItem item,
  ) async {
    final req = http.Request('DELETE', item.href);
    req.headers.addAll({..._authHeaders(cfg), ..._extraHeaders(cfg)});
    final res = await http.Client().send(req).then(http.Response.fromStream);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Delete failed: ${res.statusCode}');
    }
  }

  Future<File> exportToFile(
    WebDavConfig cfg, {
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) =>
      prepareBackupFile(cfg, onProgress: onProgress, cancelToken: cancelToken);

  @visibleForTesting
  static void verifyPackedBackupSync({
    required String zipPath,
    required Map<String, ({int bytes, String sha256})> expectedEntries,
  }) {
    _verifyPackedBackupSync(zipPath: zipPath, expectedEntries: expectedEntries);
  }

  @visibleForTesting
  static ({String digest, List<int> sliceSizes}) debugHashBackReference({
    required List<int> prefix,
    required int distance,
    required int count,
  }) {
    final sliceSizes = <int>[];
    final stream = _NullDigestOutputStream(onBytes: sliceSizes.add);
    stream.writeBytes(prefix);
    sliceSizes.clear();
    stream.writeBackReference(distance, count);
    return (digest: stream.closeAndDigest(), sliceSizes: sliceSizes);
  }

  Future<void> restoreFromLocalFile(
    File file,
    WebDavConfig cfg, {
    RestoreMode mode = RestoreMode.overwrite,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
    bool allowUnverifiedForwardCompatible = false,
    ForwardCompatibilityPrompt? onForwardCompatibility,
  }) async {
    if (!await file.exists()) throw Exception('备份文件不存在');
    // Usually already answered by the caller, which had the file all along;
    // the prompt is here for S3, which downloads through this entry point.
    final allowUnverified = await _askForwardCompatibility(
      file,
      prompt: onForwardCompatibility,
      allowUnverifiedForwardCompatible: allowUnverifiedForwardCompatible,
    );
    await _restoreFromBackupFile(
      file,
      cfg,
      mode: mode,
      onProgress: onProgress,
      cancelToken: cancelToken,
      allowUnverifiedForwardCompatible: allowUnverified,
    );
  }

  // ===== Internal helpers =====
  static Stream<List<int>> _watchedByteStream(
    Stream<List<int>> source, {
    required BackupPhase phase,
    required int? total,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async* {
    var processed = 0;
    onProgress?.call(
      BackupProgress(
        phase: phase,
        processed: 0,
        total: total,
        unit: total == null
            ? BackupProgressUnit.none
            : BackupProgressUnit.bytes,
        cancellable: true,
      ),
    );
    await for (final chunk in source) {
      if (cancelToken?.isCancelled == true) {
        throw const BackupCancelledException();
      }
      processed += chunk.length;
      onProgress?.call(
        BackupProgress(
          phase: phase,
          processed: processed,
          total: total,
          unit: BackupProgressUnit.bytes,
          cancellable: true,
        ),
      );
      yield chunk;
    }
  }

  Future<void> _deleteRemoteQuietly(WebDavConfig cfg, Uri target) async {
    final client = http.Client();
    try {
      final req = http.Request('DELETE', target);
      req.headers.addAll({..._authHeaders(cfg), ..._extraHeaders(cfg)});
      await client.send(req).then(http.Response.fromStream);
    } catch (_) {
    } finally {
      client.close();
    }
  }

  /// Ensures the temporary directory exists (some macOS installs may not create the cache folder until first use).
  Future<Directory> _ensureTempDir() async {
    Directory dir = await getTemporaryDirectory();
    if (!await dir.exists()) {
      try {
        await dir.create(recursive: true);
      } catch (_) {}
    }
    if (!await dir.exists()) {
      dir = await Directory.systemTemp.createTemp('kelivo_tmp_');
    }
    return dir;
  }

  Future<File> _writeTempText(
    Directory directory,
    String name,
    String content,
  ) async {
    final f = File(p.join(directory.path, name));
    await f.writeAsString(content);
    return f;
  }

  static String _buildBackupManifestJson({
    required Map<String, _BackupEntryMetadata> entries,
    required ChatDatabaseSnapshotInfo? snapshotInfo,
    required bool includeChats,
    required bool includeFiles,
    required String appVersion,
    required Map<String, List<String>> businessEntityRowIds,
  }) {
    return jsonEncode({
      'format': _backupFormat,
      'formatVersion': _backupFormatVersion,
      backupMinimumReadableFormatKey: _minimumReadableFormatVersion,
      'payloadKind': includeChats ? 'sqlite' : 'settings-only',
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      'appVersion': appVersion,
      'includeChats': includeChats,
      'includeFiles': includeFiles,
      'secretsIncluded': true,
      'businessEntityRowIds': businessEntityRowIds,
      if (snapshotInfo != null)
        'database': {
          'entry': _databaseEntryName,
          'schemaVersion': snapshotInfo.schemaVersion,
          // Lets an older build decide whether it may restore this backup by
          // dropping what it does not know, instead of refusing outright.
          SchemaMigrations.minimumReadableManifestKey:
              SchemaMigrations.minimumReadableSchemaVersion,
          'conversationCount': snapshotInfo.conversationCount,
          'messageCount': snapshotInfo.messageCount,
        },
      'entries': entries.map(
        (name, metadata) => MapEntry(name, {
          'bytes': metadata.bytes,
          'sha256': metadata.sha256,
        }),
      ),
    });
  }

  static Future<_VersionedBackupInfo> _preflightVersionedBackupInIsolate(
    BackupIsolateContext ctx,
    _BackupPreflightArgs args,
  ) => _preflightVersionedBackup(
    manifestPath: args.manifestPath,
    extractDirPath: args.extractDirPath,
    allowUnverifiedForwardCompatible: args.allowUnverifiedForwardCompatible,
    ctx: ctx,
  );

  static Future<_VersionedBackupInfo> _preflightVersionedBackup({
    required String manifestPath,
    required String extractDirPath,
    bool allowUnverifiedForwardCompatible = false,
    BackupIsolateContext? ctx,
  }) async {
    final manifestFile = File(manifestPath);
    if (!manifestFile.existsSync() ||
        manifestFile.lengthSync() > _maxManifestBytes) {
      throw const FormatException('manifest.json');
    }
    final decoded = jsonDecode(manifestFile.readAsStringSync());
    if (decoded is! Map) {
      throw const FormatException('manifest.json');
    }
    final manifest = decoded.cast<String, dynamic>();
    if (manifest['format'] != _backupFormat ||
        !_acceptsArchiveFormat(manifest)) {
      throw const FormatException('manifest_version');
    }
    final payloadKind = manifest['payloadKind'];
    final includeChats = manifest['includeChats'];
    final includeFiles = manifest['includeFiles'];
    if (payloadKind is! String ||
        includeChats is! bool ||
        includeFiles is! bool ||
        manifest['appVersion'] is! String ||
        manifest['createdAtUtc'] is! String ||
        manifest['secretsIncluded'] != true) {
      throw const FormatException('manifest_fields');
    }
    final businessEntityRowIds = _parseBusinessEntityRowIds(manifest);

    final rawEntries = manifest['entries'];
    if (rawEntries is! Map) {
      throw const FormatException('manifest_entries');
    }
    final entries = <String, _BackupEntryMetadata>{};
    for (final rawEntry in rawEntries.entries) {
      if (rawEntry.key is! String || rawEntry.value is! Map) {
        throw const FormatException('manifest_entry');
      }
      final name = rawEntry.key as String;
      final canonical = _validatedZipEntryName(name);
      if (canonical != name || canonical == _manifestEntryName) {
        throw FormatException('manifest_entry_name:$name');
      }
      final metadata = (rawEntry.value as Map).cast<String, dynamic>();
      final bytes = metadata['bytes'];
      final digest = metadata['sha256'];
      if (bytes is! int ||
          bytes < 0 ||
          digest is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
        throw FormatException('manifest_entry_metadata:$name');
      }
      entries[name] = (bytes: bytes, sha256: digest);
    }
    if (!entries.containsKey('settings.json')) {
      throw const FormatException('settings.json');
    }
    // Entries this build has no use for. Tolerated only when the backup comes
    // from a NEWER build, where they are the archive-level counterpart of the
    // unknown tables and columns the database normalizer drops; from a same-or
    // older build they mean the archive is malformed. The verdict below still
    // decides whether the backup may be restored at all -- this only decides
    // whether an unrecognised entry is fatal on its own.
    final unknownEntryNames = <String>[];
    for (final name in entries.keys) {
      final isFileEntry =
          name.startsWith('upload/') ||
          name.startsWith('avatars/') ||
          name.startsWith('images/') ||
          name.startsWith('fonts/');
      final knownEntry =
          name == 'settings.json' || name == _databaseEntryName || isFileEntry;
      if (!knownEntry) {
        unknownEntryNames.add(name);
        continue;
      }
      if (!includeFiles && isFileEntry) {
        throw FormatException('manifest_files:$name');
      }
    }
    if (unknownEntryNames.isNotEmpty) {
      if (!_declaresNewerBuild(manifest)) {
        throw FormatException(
          'manifest_entry_scope:${unknownEntryNames.first}',
        );
      }
      for (final name in unknownEntryNames) {
        entries.remove(name);
        // Removed from disk too, so nothing downstream can pick them up: the
        // rewritten manifest below no longer mentions them, and a staged
        // candidate must contain only what its manifest declares.
        final file = File(p.joinAll([extractDirPath, ...name.split('/')]));
        if (file.existsSync()) file.deleteSync();
      }
    }
    // Same idea one level up: a newer build may describe itself with manifest
    // fields this one has never heard of.
    _stripUnknownManifestKeys(manifest);

    final validateTotal = entries.values.fold<int>(
      0,
      (sum, metadata) => sum + metadata.bytes,
    );
    final meter = _BackupByteMeter(
      ctx: ctx,
      phase: BackupPhase.validating,
      total: validateTotal,
    );
    meter.report();
    for (final entry in entries.entries) {
      ctx?.throwIfCancelled();
      final file = File(p.joinAll([extractDirPath, ...entry.key.split('/')]));
      if (!file.existsSync() || file.lengthSync() != entry.value.bytes) {
        throw FormatException('manifest_entry_size:${entry.key}');
      }
      if (_sha256FileSync(file, ctx: ctx) != entry.value.sha256) {
        throw FormatException('manifest_entry_hash:${entry.key}');
      }
      meter.add(entry.value.bytes, detail: entry.key);
    }

    ctx?.reportProgress(
      const BackupProgress(
        phase: BackupPhase.validating,
        processed: 0,
        cancellable: true,
      ),
    );

    final rawDatabase = manifest['database'];
    if (payloadKind == 'sqlite') {
      if (!includeChats ||
          !entries.containsKey(_databaseEntryName) ||
          rawDatabase is! Map) {
        throw const FormatException('manifest_database');
      }
      final database = rawDatabase.cast<String, dynamic>();
      final schemaVersion = database['schemaVersion'];
      final declaredMinimumReadable =
          database[SchemaMigrations.minimumReadableManifestKey];
      final conversationCount = database['conversationCount'];
      final messageCount = database['messageCount'];
      if (database['entry'] != _databaseEntryName ||
          schemaVersion is! int ||
          schemaVersion < 1 ||
          (declaredMinimumReadable != null &&
              (declaredMinimumReadable is! int ||
                  declaredMinimumReadable < 1 ||
                  declaredMinimumReadable > schemaVersion)) ||
          conversationCount is! int ||
          conversationCount < 0 ||
          messageCount is! int ||
          messageCount < 0) {
        throw const FormatException('manifest_database');
      }
      final verdict = SchemaMigrations.classifyBackup(
        schemaVersion: schemaVersion,
        declaredMinimumReadable: declaredMinimumReadable as int?,
      );
      switch (verdict) {
        case BackupSchemaVerdict.unreadable:
          throw const FormatException('manifest_database_schema_too_new');
        case BackupSchemaVerdict.forwardUndeclared:
          // The caller must have obtained the user's informed consent; without
          // it there is no way to know this backup is safe to read.
          if (!allowUnverifiedForwardCompatible) {
            throw const FormatException('manifest_database_schema_too_new');
          }
        case BackupSchemaVerdict.current:
        case BackupSchemaVerdict.needsUpgrade:
        case BackupSchemaVerdict.forwardCompatible:
          break;
      }
      final databaseFile = File(
        p.joinAll([extractDirPath, ..._databaseEntryName.split('/')]),
      );
      final databaseInfo =
          await ChatDatabaseRepository.prepareSnapshotForRestore(
            databaseFile,
            allowForwardCompatible:
                verdict == BackupSchemaVerdict.forwardCompatible ||
                verdict == BackupSchemaVerdict.forwardUndeclared,
          );
      // The manifest records the schema the backup was AUTHORED at; the info
      // records the schema after prepareSnapshotForRestore migrated it, so the
      // two legitimately differ for an older backup. Row counts are the
      // invariant instead: a migration must never add or drop rows.
      if (databaseInfo.conversationCount != conversationCount ||
          databaseInfo.messageCount != messageCount) {
        throw const FormatException('manifest_database_metadata');
      }
      entries[_databaseEntryName] = (
        bytes: databaseFile.lengthSync(),
        sha256: _sha256FileSync(databaseFile, ctx: ctx),
      );
    } else if (payloadKind == 'settings-only') {
      if (includeChats ||
          entries.containsKey(_databaseEntryName) ||
          rawDatabase != null) {
        throw const FormatException('manifest_database');
      }
    } else {
      throw const FormatException('manifest_payload_kind');
    }

    final sortedEntryNames = entries.keys.toList()..sort();
    manifest['entries'] = {
      for (final name in sortedEntryNames)
        name: {'bytes': entries[name]!.bytes, 'sha256': entries[name]!.sha256},
    };
    final normalizedManifestBytes = utf8.encode(jsonEncode(manifest));
    if (normalizedManifestBytes.length > _maxManifestBytes) {
      throw const FormatException('manifest_size');
    }
    final normalizedManifestSha256 = sha256
        .convert(normalizedManifestBytes)
        .toString();
    manifestFile.writeAsBytesSync(normalizedManifestBytes, flush: true);

    ctx?.reportProgress(
      const BackupProgress(
        phase: BackupPhase.finalizing,
        processed: 0,
        cancellable: true,
      ),
    );

    return (
      includeChats: includeChats,
      includeFiles: includeFiles,
      secretsIncluded: true,
      businessEntityRowIds: businessEntityRowIds,
      normalizedManifestSha256: normalizedManifestSha256,
    );
  }

  static Map<String, Object?>? _parseBusinessEntityRowIds(
    Map<String, dynamic> manifest,
  ) {
    if (!manifest.containsKey('businessEntityRowIds')) return null;
    final raw = manifest['businessEntityRowIds'];
    if (raw is! Map || raw.keys.any((key) => key is! String)) {
      throw const FormatException('manifest_business_entity_row_ids');
    }
    final result = <String, Object?>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! List || value.any((item) => item is! String)) {
        throw const FormatException('manifest_business_entity_row_ids');
      }
      result[entry.key as String] = List<String>.unmodifiable(
        value.cast<String>(),
      );
    }
    return Map<String, Object?>.unmodifiable(result);
  }

  static Map<String, dynamic> _readSettingsJsonInIsolate(
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
    final settings = _readSettingsJsonSync(path);
    ctx.throwIfCancelled();
    return settings;
  }

  static Map<String, dynamic> _readSettingsJsonSync(String path) {
    final file = File(path);
    if (!file.existsSync()) throw const FormatException('settings.json');
    final length = file.lengthSync();
    if (length <= 0 || length > _maxSettingsBytes) {
      throw const FormatException('settings_size');
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map || decoded.keys.any((key) => key is! String)) {
      throw const FormatException('settings.json');
    }
    return decoded.cast<String, dynamic>();
  }

  static String _sha256FileSync(File file, {BackupIsolateContext? ctx}) {
    final digestSink = _DigestOutputSink();
    final hashSink = sha256.startChunkedConversion(digestSink);
    final input = file.openSync();
    final buffer = Uint8List(1024 * 1024);
    try {
      while (true) {
        ctx?.throwIfCancelled();
        final read = input.readIntoSync(buffer);
        if (read == 0) break;
        hashSink.add(Uint8List.sublistView(buffer, 0, read));
      }
      hashSink.close();
    } finally {
      input.closeSync();
    }
    final digest = digestSink.digest;
    if (digest == null) {
      throw StateError('sha256');
    }
    return digest.toString();
  }

  Future<Directory> _getUploadDir() async {
    return await AppDirectories.getUploadDirectory();
  }

  Future<Directory> _getImagesDir() async {
    return await AppDirectories.getImagesDirectory();
  }

  Future<Directory> _getAvatarsDir() async {
    return await AppDirectories.getAvatarsDirectory();
  }

  Future<Directory> _getFontsDir() async {
    return await AppDirectories.getFontsDirectory();
  }

  Future<void> _copyRestoredFile(File source, File target) async {
    await target.parent.create(recursive: true);
    await source.copy(target.path);
    try {
      await target.setLastModified(await source.lastModified());
    } on FileSystemException {
      // Payload copy is authoritative; timestamps are optional metadata on
      // filesystems that do not support setting them.
    }
  }

  /// Copies the backup's asset payload directories (upload/images/avatars/
  /// fonts) into the live directories without deleting anything already
  /// present, so files referenced by an untouched chat database survive.
  Future<void> _restoreAssetDirectoriesAdditive(
    Directory payloadDirectory,
  ) async {
    final targets =
        <({String entryName, Future<Directory> Function() resolveTarget})>[
          (entryName: 'upload', resolveTarget: _getUploadDir),
          (entryName: 'images', resolveTarget: _getImagesDir),
          (entryName: 'avatars', resolveTarget: _getAvatarsDir),
          (entryName: 'fonts', resolveTarget: _getFontsDir),
        ];
    for (final target in targets) {
      final src = Directory(p.join(payloadDirectory.path, target.entryName));
      if (!await src.exists()) continue;
      final dst = await target.resolveTarget();
      if (!await dst.exists()) {
        await dst.create(recursive: true);
      }
      for (final ent in src.listSync(recursive: true)) {
        if (ent is File) {
          final rel = p.relative(ent.path, from: src.path);
          final targetFile = File(p.join(dst.path, rel));
          if (!await targetFile.exists()) {
            await _copyRestoredFile(ent, targetFile);
          }
        }
      }
    }
  }

  static Future<_ParsedChatBackup> _parseLegacyChatsInIsolate(
    BackupIsolateContext ctx,
    _LegacyChatParseArgs args,
  ) async {
    ctx.throwIfCancelled();
    ctx.reportProgress(
      const BackupProgress(
        phase: BackupPhase.importingMessages,
        processed: 0,
        cancellable: true,
      ),
    );
    final parsed = _sanitizeLegacyChatBackup(
      await _parseChatBackup(File(args.chatsPath), ctx: ctx),
    );
    _validateBackupReferences(
      conversations: parsed.conversations,
      messages: parsed.messages,
      toolEvents: parsed.toolEvents,
      geminiThoughtSigs: parsed.geminiThoughtSigs,
    );
    if (args.buildOverwriteCandidate) {
      final candidatePath = p.join(args.stagingPath, 'candidate.sqlite');
      for (final suffix in const ['', '-wal', '-shm', '-journal']) {
        final file = File('$candidatePath$suffix');
        if (file.existsSync()) file.deleteSync();
      }
      try {
        await _buildAndValidateOverwriteChatCandidate(
          candidatePath: candidatePath,
          conversations: parsed.conversations,
          messages: parsed.messages,
          toolEvents: parsed.toolEvents,
          geminiThoughtSigs: parsed.geminiThoughtSigs,
        );
      } finally {
        for (final suffix in const ['', '-wal', '-shm', '-journal']) {
          final file = File('$candidatePath$suffix');
          if (file.existsSync()) file.deleteSync();
        }
      }
    }
    ctx.throwIfCancelled();
    return parsed;
  }

  static Future<_ParsedChatBackup> _parseChatBackup(
    File chatsFile, {
    BackupIsolateContext? ctx,
  }) async {
    ctx?.throwIfCancelled();
    final chats =
        jsonDecode(await chatsFile.readAsString()) as Map<String, dynamic>;
    final version = chats['version'];
    if (version != null && version != 1) {
      throw const FormatException('version');
    }
    if (chats['conversations'] is! List) {
      throw const FormatException('conversations');
    }
    if (chats['messages'] is! List) {
      throw const FormatException('messages');
    }
    final geminiThoughtSigs = <String, String>{};
    final rawGeminiThoughtSigs =
        (chats['geminiThoughtSigs'] as Map?) ?? const <String, dynamic>{};
    for (final entry in rawGeminiThoughtSigs.entries) {
      if (entry.value is! String) {
        throw const FormatException('geminiThoughtSigs');
      }
      geminiThoughtSigs[entry.key.toString()] = entry.value as String;
    }
    final conversations = (chats['conversations'] as List)
        .map(
          (entry) =>
              Conversation.fromJson((entry as Map).cast<String, dynamic>()),
        )
        .toList();

    // Import boundary for legacy chats.json: promote marker-bearing content
    // into structured parts only when the raw JSON lacks a `parts` list.
    // New exports already carry `parts` (including literal marker-shaped text)
    // and must round-trip without re-promotion.
    var converted = 0;
    var malformed = 0;
    var missingFiles = 0;
    final messages = <ChatMessage>[];
    for (final entry in chats['messages'] as List) {
      ctx?.throwIfCancelled();
      final raw = (entry as Map).cast<String, dynamic>();
      final hasPartsList = raw['parts'] is List;
      var message = ChatMessage.fromJson(raw);
      if (message.isStreaming) {
        message = message.copyWith(isStreaming: false);
      }
      if (!hasPartsList) {
        final decoded = await decodeLegacyContent(
          message.content,
          existingParts: message.parts,
        );
        converted += decoded.converted;
        malformed += decoded.malformed;
        missingFiles += decoded.missingFiles;
        if (decoded.converted > 0) {
          message = message.copyWith(parts: decoded.parts);
        }
      }
      // Import boundary: persist managed local attachments as kelivo-file URIs.
      final normalized = _normalizeAttachmentPartUris(message.parts);
      if (!identical(normalized, message.parts)) {
        message = message.copyWith(parts: normalized);
      }
      messages.add(message);
    }
    if (converted > 0 || malformed > 0 || missingFiles > 0) {
      debugPrint(
        'legacy chats.json decode: converted=$converted '
        'malformed=$malformed missingFiles=$missingFiles',
      );
    }

    return (
      conversations: conversations,
      messages: messages,
      toolEvents: ((chats['toolEvents'] as Map?) ?? const <String, dynamic>{})
          .map(
            (key, value) => MapEntry(
              key.toString(),
              (value as List)
                  .cast<Map>()
                  .map((entry) => entry.cast<String, dynamic>())
                  .toList(),
            ),
          ),
      geminiThoughtSigs: geminiThoughtSigs,
    );
  }

  /// Legacy (1.1.17) backups can carry shapes the old runtime silently
  /// tolerated: dangling or duplicate messageIds references, messages no
  /// conversation references, and messages whose conversationId disagrees
  /// with the conversation referencing them. Restore what 1.1.17 actually
  /// displayed instead of rejecting the archive: each conversation's
  /// messageIds order is authoritative, dangling references are pruned
  /// (SQLite derives order from message_order, so pruning matches the old
  /// runtime), duplicate references keep their first occurrence, and
  /// unreferenced messages were never visible so they are skipped. It also
  /// converts the raw message index and version ordinal used by 1.1.17 into
  /// the logical slot index and concrete message version used by SQLite.
  static _ParsedChatBackup _sanitizeLegacyChatBackup(_ParsedChatBackup parsed) {
    final conversations = <Conversation>[];
    final conversationIds = <String>{};
    var duplicateConversations = 0;
    for (final conversation in parsed.conversations) {
      if (conversationIds.add(conversation.id)) {
        conversations.add(conversation);
      } else {
        duplicateConversations++;
      }
    }

    final messagesById = <String, ChatMessage>{};
    var duplicateMessages = 0;
    for (final message in parsed.messages) {
      if (messagesById.containsKey(message.id)) {
        duplicateMessages++;
      } else {
        messagesById[message.id] = message;
      }
    }

    final sanitizedConversations = <Conversation>[];
    final sanitizedMessages = <ChatMessage>[];
    final referencedMessageIds = <String>{};
    var danglingReferences = 0;
    var duplicateReferences = 0;
    var rehomedMessages = 0;
    var duplicateMcpServerIds = 0;
    var versionConflicts = 0;
    var dirtyFieldRepairs = 0;
    for (final conversation in conversations) {
      final mcpServerIds = <String>[];
      final seenMcpServerIds = <String>{};
      for (final serverId in conversation.mcpServerIds) {
        if (seenMcpServerIds.add(serverId)) {
          mcpServerIds.add(serverId);
        } else {
          duplicateMcpServerIds++;
        }
      }
      final keptMessageIds = <String>[];
      // SQLite enforces unique(conversationId, groupId, version) while the
      // 1.1.17 runtime tolerated duplicate (groupId, version) pairs (and
      // rehoming above can create new ones); reassign versions the same way
      // the Hive migration does so INSERT OR REPLACE cannot swallow rows.
      final seenGroupVersions = <String>{};
      final maxGroupVersions = <String, int>{};
      final legacyGroupIds = <String?>[];
      final versionsBySelectedGroup = <String, List<ChatMessage>>{
        for (final groupId in conversation.versionSelections.keys)
          groupId: <ChatMessage>[],
      };
      final repairedVersionsByMessageId = <String, int>{};
      for (final messageId in conversation.messageIds) {
        var message = messagesById[messageId];
        if (message == null) {
          danglingReferences++;
          continue;
        }
        final groupId = message.groupId ?? message.id;
        versionsBySelectedGroup[groupId]?.add(message);
        final referenceKept = referencedMessageIds.add(messageId);
        legacyGroupIds.add(referenceKept ? groupId : null);
        if (!referenceKept) {
          duplicateReferences++;
          continue;
        }
        keptMessageIds.add(messageId);
        if (message.conversationId != conversation.id) {
          rehomedMessages++;
          message = message.copyWith(conversationId: conversation.id);
        }
        // Field-level repair (empty role, negative tokens/duration,
        // out-of-range version, inverted reasoning timestamps) shares logic
        // with the Hive migration; it must run before the version-conflict
        // repair below because clamping version can introduce collisions
        // that repair resolves.
        final fieldSanitized = sanitizeLegacyMessageFields(message);
        if (!identical(fieldSanitized, message)) {
          dirtyFieldRepairs++;
          message = fieldSanitized;
        }
        final explicitGroupId = message.groupId;
        if (explicitGroupId != null) {
          var version = message.version;
          if (!seenGroupVersions.add('$explicitGroupId $version')) {
            version = (maxGroupVersions[explicitGroupId] ?? version) + 1;
            versionConflicts++;
            message = message.copyWith(version: version);
            repairedVersionsByMessageId[message.id] = version;
            seenGroupVersions.add('$explicitGroupId $version');
          }
          final knownMax = maxGroupVersions[explicitGroupId];
          if (knownMax == null || version > knownMax) {
            maxGroupVersions[explicitGroupId] = version;
          }
        }
        sanitizedMessages.add(message);
      }

      var truncateIndex = conversation.truncateIndex;
      if (truncateIndex >= 0 && truncateIndex <= legacyGroupIds.length) {
        truncateIndex = legacyGroupIds
            .take(truncateIndex)
            .whereType<String>()
            .toSet()
            .length;
      }
      final versionSelections = Map<String, int>.from(
        conversation.versionSelections,
      );
      for (final entry in conversation.versionSelections.entries) {
        final versions = versionsBySelectedGroup[entry.key]!
          ..sort((left, right) => left.version.compareTo(right.version));
        if (versions.isEmpty) continue;
        final ordinal = entry.value;
        final selected = ordinal >= 0 && ordinal < versions.length
            ? versions[ordinal]
            : versions.last;
        versionSelections[entry.key] =
            repairedVersionsByMessageId[selected.id] ?? selected.version;
      }
      // Counter clamping shares logic with the Hive migration so a legacy
      // backup carrying out-of-range values (e.g. negative truncateIndex)
      // cannot trip the conversation_rows CHECK constraints on restore.
      final rebuilt = conversation.copyWith(
        messageIds: keptMessageIds,
        mcpServerIds: mcpServerIds,
        truncateIndex: truncateIndex,
        versionSelections: versionSelections,
      );
      final sanitizedConversation = sanitizeLegacyConversationFields(rebuilt);
      if (!identical(sanitizedConversation, rebuilt)) {
        dirtyFieldRepairs++;
      }
      sanitizedConversations.add(sanitizedConversation);
    }
    final unreferencedMessages =
        messagesById.length - referencedMessageIds.length;

    final toolEvents = <String, List<Map<String, dynamic>>>{};
    var danglingArtifacts = 0;
    for (final entry in parsed.toolEvents.entries) {
      if (referencedMessageIds.contains(entry.key)) {
        toolEvents[entry.key] = entry.value;
      } else {
        danglingArtifacts++;
      }
    }
    final geminiThoughtSigs = <String, String>{};
    for (final entry in parsed.geminiThoughtSigs.entries) {
      if (referencedMessageIds.contains(entry.key)) {
        geminiThoughtSigs[entry.key] = entry.value;
      } else {
        danglingArtifacts++;
      }
    }
    final pruned =
        duplicateConversations +
        duplicateMessages +
        danglingReferences +
        duplicateReferences +
        rehomedMessages +
        duplicateMcpServerIds +
        versionConflicts +
        dirtyFieldRepairs +
        unreferencedMessages +
        danglingArtifacts;
    if (pruned > 0) {
      debugPrint(
        'Legacy backup sanitized: '
        'duplicateConversations=$duplicateConversations '
        'duplicateMessages=$duplicateMessages '
        'danglingReferences=$danglingReferences '
        'duplicateReferences=$duplicateReferences '
        'rehomedMessages=$rehomedMessages '
        'duplicateMcpServerIds=$duplicateMcpServerIds '
        'versionConflicts=$versionConflicts '
        'dirtyFieldRepairs=$dirtyFieldRepairs '
        'unreferencedMessages=$unreferencedMessages '
        'danglingArtifacts=$danglingArtifacts',
      );
    }
    return (
      conversations: sanitizedConversations,
      messages: sanitizedMessages,
      toolEvents: toolEvents,
      geminiThoughtSigs: geminiThoughtSigs,
    );
  }

  static void _validateBackupReferences({
    required List<Conversation> conversations,
    required List<ChatMessage> messages,
    required Map<String, List<Map<String, dynamic>>> toolEvents,
    required Map<String, String> geminiThoughtSigs,
  }) {
    final conversationIds = conversations
        .map((conversation) => conversation.id)
        .toSet();
    if (conversationIds.length != conversations.length) {
      throw StateError('conversation_ids');
    }

    final messagesByConversation = <String, List<String>>{};
    final messageIds = <String>{};
    for (final message in messages) {
      if (!conversationIds.contains(message.conversationId)) {
        throw StateError('message_conversation');
      }
      if (!messageIds.add(message.id)) {
        throw StateError('message_ids');
      }
      (messagesByConversation[message.conversationId] ??= <String>[]).add(
        message.id,
      );
    }
    for (final conversation in conversations) {
      if (conversation.mcpServerIds.toSet().length !=
          conversation.mcpServerIds.length) {
        throw StateError('conversation_mcp_server_ids');
      }
      final actualIds =
          messagesByConversation[conversation.id] ?? const <String>[];
      if (actualIds.length != conversation.messageIds.length) {
        throw StateError('conversation_message_ids');
      }
      for (var i = 0; i < actualIds.length; i++) {
        if (actualIds[i] != conversation.messageIds[i]) {
          throw StateError('conversation_message_order');
        }
      }
    }
    for (final messageId in {...toolEvents.keys, ...geminiThoughtSigs.keys}) {
      if (!messageIds.contains(messageId)) {
        throw StateError('artifact_message');
      }
    }
  }

  static Future<void> _buildAndValidateOverwriteChatCandidate({
    required String candidatePath,
    required List<Conversation> conversations,
    required List<ChatMessage> messages,
    required Map<String, List<Map<String, dynamic>>> toolEvents,
    required Map<String, String> geminiThoughtSigs,
  }) async {
    final nextOrderByConversation = <String, int>{};
    final orderedMessages = <({ChatMessage message, int messageOrder})>[];
    for (final message in messages) {
      final messageOrder = nextOrderByConversation.update(
        message.conversationId,
        (value) => value + 1,
        ifAbsent: () => 0,
      );
      orderedMessages.add((message: message, messageOrder: messageOrder));
    }

    final candidateFile = File(candidatePath);
    final repository = ChatDatabaseRepository.open(file: candidateFile);
    try {
      await repository.ensureReady();
      await repository.putMigrationBatch(
        conversations: conversations,
        messages: orderedMessages,
        toolEventsByMessageId: toolEvents,
        geminiSignaturesByMessageId: geminiThoughtSigs,
      );
      await repository.markMigrationComplete();
      await repository.validateIntegrity();
      await repository.checkpoint();
    } finally {
      await repository.close();
    }

    final reopenedRepository = ChatDatabaseRepository.open(file: candidateFile);
    try {
      await reopenedRepository.ensureReady();
      await reopenedRepository.validateIntegrity();
      final storedConversations = await reopenedRepository
          .getAllConversations();
      if (storedConversations.length != conversations.length) {
        throw StateError('conversation_count');
      }
      final storedConversationsById = {
        for (final conversation in storedConversations)
          conversation.id: conversation,
      };
      var storedMessageCount = 0;
      for (final sourceConversation in conversations) {
        final storedConversation =
            storedConversationsById[sourceConversation.id];
        if (storedConversation == null) {
          throw StateError('conversation_ids');
        }
        if (jsonEncode(storedConversation.mcpServerIds) !=
            jsonEncode(sourceConversation.mcpServerIds)) {
          throw StateError('conversation_mcp_server_ids');
        }
        final storedMessages = await reopenedRepository.getMessagesRange(
          sourceConversation.id,
          start: 0,
          limit: sourceConversation.messageIds.length,
        );
        storedMessageCount += storedMessages.length;
        if (jsonEncode(storedMessages.map((message) => message.id).toList()) !=
            jsonEncode(sourceConversation.messageIds)) {
          throw StateError('conversation_message_order');
        }
      }
      if (storedMessageCount != messages.length) {
        throw StateError('message_count');
      }
      for (final entry in toolEvents.entries) {
        final stored = await reopenedRepository.getToolEvents(entry.key);
        if (jsonEncode(stored) != jsonEncode(entry.value)) {
          throw StateError('tool_events');
        }
      }
      for (final entry in geminiThoughtSigs.entries) {
        final stored = await reopenedRepository.getGeminiThoughtSignature(
          entry.key,
        );
        if (stored != entry.value) {
          throw StateError('gemini_thought_signature');
        }
      }
      if (!await reopenedRepository.isMigrationComplete()) {
        throw StateError('migration_receipt');
      }
    } finally {
      await reopenedRepository.close();
    }
  }

  Future<({String settingsJson, Map<String, List<String>> entityRowIds})>
  _exportBusinessSettings() async {
    final exported = BusinessSettingsRouter.exportSnapshotWithRowIds(
      await businessRepository.readSnapshot(),
    );
    final settings = Map<String, Object>.from(exported.settings);
    settings.removeWhere((key, _) => BackupSettingsValidator.shouldIgnore(key));
    BackupSettingsValidator.retainCloudAsrForExport(settings);
    return (
      settingsJson: jsonEncode(settings),
      entityRowIds: exported.entityRowIds,
    );
  }

  /// Reads a backup file's manifest and reports what restoring it would mean.
  ///
  /// Only the manifest entry is decoded, so this stays cheap enough to run
  /// before the restore begins. Returns null when the file carries no SQLite
  /// payload or its manifest cannot be read — the restore itself reports those
  /// properly.
  static Future<BackupCompatibility?> inspectBackupCompatibility(
    File file,
  ) async {
    try {
      if (!await file.exists()) return null;
      final inputStream = InputFileStream(file.path);
      Map<String, dynamic>? manifest;
      try {
        final archive = ZipDecoder().decodeStream(inputStream);
        for (final entry in archive.files) {
          if (_zipEntryName(entry.name) != _manifestEntryName) continue;
          if (!entry.isFile || entry.size > _maxManifestBytes) return null;
          final decoded = jsonDecode(utf8.decode(entry.readBytes()!));
          if (decoded is Map<String, dynamic>) manifest = decoded;
          break;
        }
      } finally {
        await inputStream.close();
      }
      if (manifest == null) return null;
      final database = manifest['database'];
      if (database is! Map) return null;
      final schemaVersion = database['schemaVersion'];
      if (schemaVersion is! int) return null;
      final declared = database[SchemaMigrations.minimumReadableManifestKey];
      return (
        schemaVersion: schemaVersion,
        verdict: SchemaMigrations.classifyBackup(
          schemaVersion: schemaVersion,
          declaredMinimumReadable: declared is int ? declared : null,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _restoreFromBackupFile(
    File file,
    WebDavConfig cfg, {
    RestoreMode mode = RestoreMode.overwrite,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
    bool allowUnverifiedForwardCompatible = false,
  }) async {
    _lastMergeReport = null;
    // Extract to temp using file-stream decoding to avoid loading the full ZIP
    // into RAM (the old approach called file.readAsBytes() which for a 600-800 MB
    // file would allocate a contiguous byte array of the same size).
    final tmp = await _ensureTempDir();
    final extractDir = Directory(
      p.join(tmp.path, 'restore_${DateTime.now().millisecondsSinceEpoch}'),
    );
    await extractDir.create(recursive: true);
    registerLiveTempPath(extractDir.path);

    Object? restoreError;
    try {
      if (cancelToken?.isCancelled == true) {
        throw const BackupCancelledException();
      }
      await runBackupIsolate<void, _BackupExtractArgs>(
        body: _extractZipInIsolate,
        payload: _BackupExtractArgs(
          zipPath: file.path,
          extractDirPath: extractDir.path,
        ),
        cancelToken: cancelToken,
        onProgress: onProgress,
      );

      final manifestFile = File(p.join(extractDir.path, _manifestEntryName));
      final restorePayloadDirectory = extractDir;
      final settingsFile = File(p.join(extractDir.path, 'settings.json'));
      final chatsFile = File(p.join(extractDir.path, 'chats.json'));
      if (!await settingsFile.exists()) {
        throw const FormatException('settings.json');
      }
      final _VersionedBackupInfo? versionedBackup;
      if (await manifestFile.exists()) {
        if (cancelToken?.isCancelled == true) {
          throw const BackupCancelledException();
        }
        versionedBackup =
            await runBackupIsolate<_VersionedBackupInfo, _BackupPreflightArgs>(
              body: _preflightVersionedBackupInIsolate,
              payload: _BackupPreflightArgs(
                manifestPath: manifestFile.path,
                extractDirPath: extractDir.path,
                allowUnverifiedForwardCompatible:
                    allowUnverifiedForwardCompatible,
              ),
              cancelToken: cancelToken,
              onProgress: onProgress,
            );
      } else {
        versionedBackup = null;
      }
      if (cancelToken?.isCancelled == true) {
        throw const BackupCancelledException();
      }
      final settings = await runBackupIsolate<Map<String, dynamic>, String>(
        body: _readSettingsJsonInIsolate,
        payload: settingsFile.path,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
      BackupSettingsValidator.normalizeAndValidate(settings);
      void beginNonCancellableCommit() {
        if (cancelToken?.isCancelled == true) {
          throw const BackupCancelledException();
        }
        cancelToken?.setCancellable(false);
        onProgress?.call(
          const BackupProgress(
            phase: BackupPhase.committing,
            processed: 0,
            cancellable: false,
          ),
        );
      }

      final businessRestore = BusinessRestoreService(businessRepository);
      Future<void> Function()? pendingBusinessRestore;
      if (versionedBackup != null) {
        final entityRowIds = versionedBackup.businessEntityRowIds;
        final preserveExplicitEmptyInstructionList = entityRowIds == null;
        final includeChats = versionedBackup.includeChats;
        final includeFiles = versionedBackup.includeFiles;
        final restoreChats = cfg.includeChats && includeChats;
        final restoreFiles = cfg.includeFiles && includeFiles;
        if (mode == RestoreMode.merge && restoreChats) {
          // Chat merge commits independently, so reject a mismatched business
          // payload before either live domain is changed.
          BusinessSettingsRouter.normalizeAndRoute(
            settings,
            preserveExplicitEmptyInstructionList:
                preserveExplicitEmptyInstructionList,
            entityRowIds: entityRowIds,
          );
        }
        if (mode == RestoreMode.overwrite) {
          if (!restoreChats) {
            beginNonCancellableCommit();
            if (restoreFiles) {
              // File restore is independent from chat restore. The live
              // database stays untouched here, so copy the payload
              // additively (never deleting existing files it references)
              // and persist business data last, matching the legacy path.
              await _restoreAssetDirectoriesAdditive(extractDir);
            }
            await _runLiveBusinessRestore(
              () => businessRestore.overwrite(
                settings,
                preserveExplicitEmptyInstructionList:
                    preserveExplicitEmptyInstructionList,
                entityRowIds: entityRowIds,
              ),
            );
            return;
          }
          final appDataPath = (await AppDirectories.getAppDataDirectory()).path;
          final extractedPath = extractDir.path;
          final sourceManifestSha256 = versionedBackup.normalizedManifestSha256;
          if (cancelToken?.isCancelled == true) {
            throw const BackupCancelledException();
          }
          await _prepareRestoreBundle(
            appDataPath: appDataPath,
            extractedPath: extractedPath,
            sourceManifestSha256: sourceManifestSha256,
            includeChats: includeChats,
            includeFiles: includeFiles,
            restoreChats: restoreChats,
            restoreFiles: restoreFiles,
            validatedSettings: settings,
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
          return;
        }
        if (restoreChats) {
          beginNonCancellableCommit();
          _lastMergeReport = await chatService.mergeDatabaseSnapshot(
            File(p.join(extractDir.path, _databaseEntryName)),
          );
          // Chats-only: never leave local attachments marked available when
          // files were not restored (path collision on target is insufficient).
          if (!restoreFiles && _lastMergeReport != null) {
            await chatService.recomputeImportedAttachmentAvailability(
              conversationIds: _lastMergeReport!.importedConversationIds,
              filesRestored: false,
            );
          }
        }
        pendingBusinessRestore = () => businessRestore.merge(
          settings,
          preserveExplicitEmptyInstructionList:
              preserveExplicitEmptyInstructionList,
          entityRowIds: entityRowIds,
        );
        if (!restoreChats) {
          beginNonCancellableCommit();
          if (restoreFiles) {
            await _restoreAssetDirectoriesAdditive(extractDir);
          }
          await _runLiveBusinessRestore(pendingBusinessRestore);
          return;
        }
      }
      final restoreChats =
          versionedBackup == null &&
          cfg.includeChats &&
          await chatsFile.exists();

      var conversations = const <Conversation>[];
      var messages = const <ChatMessage>[];
      var toolEvents = const <String, List<Map<String, dynamic>>>{};
      var geminiThoughtSigs = const <String, String>{};
      if (restoreChats) {
        final parsed =
            await runBackupIsolate<_ParsedChatBackup, _LegacyChatParseArgs>(
              body: _parseLegacyChatsInIsolate,
              payload: _LegacyChatParseArgs(
                chatsPath: chatsFile.path,
                stagingPath: extractDir.path,
                buildOverwriteCandidate: mode == RestoreMode.overwrite,
              ),
              cancelToken: cancelToken,
              onProgress: onProgress,
            );
        conversations = parsed.conversations;
        // Worker isolate has no SandboxPathResolver docsDir. Encode managed
        // attachments against the live root here (URI rewrite only, not a
        // second chats.json parse).
        messages = parsed.messages.map((message) {
          final normalized = _normalizeAttachmentPartUris(message.parts);
          return identical(normalized, message.parts)
              ? message
              : message.copyWith(parts: normalized);
        }).toList();
        toolEvents = parsed.toolEvents;
        geminiThoughtSigs = parsed.geminiThoughtSigs;
      }

      if (versionedBackup == null) {
        // Chat and file restoration can commit independently. Reject the
        // complete legacy business payload before changing either domain,
        // then persist business data last so a later failure cannot strand
        // the post-restore write fence without a restart prompt.
        BusinessSettingsRouter.normalizeAndRoute(
          settings,
          preserveExplicitEmptyInstructionList: true,
          assumePreV3EmbeddingMigrationWhenVersionMissing: true,
        );
        pendingBusinessRestore = mode == RestoreMode.overwrite
            ? () => businessRestore.overwrite(
                settings,
                preserveExplicitEmptyInstructionList: true,
                assumePreV3EmbeddingMigrationWhenVersionMissing: true,
              )
            : () => businessRestore.merge(
                settings,
                preserveExplicitEmptyInstructionList: true,
                assumePreV3EmbeddingMigrationWhenVersionMissing: true,
              );
      }

      // Restore files
      if (cfg.includeFiles) {
        beginNonCancellableCommit();
        if (mode == RestoreMode.overwrite) {
          // Overwrite mode: Delete existing directories and copy all
          // Restore upload directory
          final uploadSrc = Directory(
            p.join(restorePayloadDirectory.path, 'upload'),
          );
          if (await uploadSrc.exists()) {
            final dst = await _getUploadDir();
            if (await dst.exists()) {
              await dst.delete(recursive: true);
            }
            await dst.create(recursive: true);
            for (final ent in uploadSrc.listSync(recursive: true)) {
              if (ent is File) {
                final rel = p.relative(ent.path, from: uploadSrc.path);
                final target = File(p.join(dst.path, rel));
                await _copyRestoredFile(ent, target);
              }
            }
          }

          // Restore images directory
          final imagesSrc = Directory(
            p.join(restorePayloadDirectory.path, 'images'),
          );
          if (await imagesSrc.exists()) {
            final dst = await _getImagesDir();
            if (await dst.exists()) {
              await dst.delete(recursive: true);
            }
            await dst.create(recursive: true);
            for (final ent in imagesSrc.listSync(recursive: true)) {
              if (ent is File) {
                final rel = p.relative(ent.path, from: imagesSrc.path);
                final target = File(p.join(dst.path, rel));
                await _copyRestoredFile(ent, target);
              }
            }
          }

          // Restore avatars directory
          final avatarsSrc = Directory(
            p.join(restorePayloadDirectory.path, 'avatars'),
          );
          if (await avatarsSrc.exists()) {
            final dst = await _getAvatarsDir();
            if (await dst.exists()) {
              await dst.delete(recursive: true);
            }
            await dst.create(recursive: true);
            for (final ent in avatarsSrc.listSync(recursive: true)) {
              if (ent is File) {
                final rel = p.relative(ent.path, from: avatarsSrc.path);
                final target = File(p.join(dst.path, rel));
                await _copyRestoredFile(ent, target);
              }
            }
          }

          // Restore managed local fonts directory
          final fontsSrc = Directory(
            p.join(restorePayloadDirectory.path, 'fonts'),
          );
          if (await fontsSrc.exists()) {
            final dst = await _getFontsDir();
            if (await dst.exists()) {
              await dst.delete(recursive: true);
            }
            await dst.create(recursive: true);
            for (final ent in fontsSrc.listSync(recursive: true)) {
              if (ent is File) {
                final rel = p.relative(ent.path, from: fontsSrc.path);
                final target = File(p.join(dst.path, rel));
                await _copyRestoredFile(ent, target);
              }
            }
          }
        } else {
          // Merge mode: Only copy non-existing files
          await _restoreAssetDirectoriesAdditive(restorePayloadDirectory);
        }
      }
      // Legacy chats.json decodes before assets exist. After files land,
      // directed-remap old absolute roots onto restored managed relatives,
      // then refresh availability (no global generic canonicalize fallback).
      if (restoreChats && cfg.includeFiles) {
        if (SandboxPathResolver.docsDir == null) {
          await SandboxPathResolver.init();
        }
        final refreshed = <ChatMessage>[];
        for (final message in messages) {
          final remapped = _remapRestoredAttachmentPartUris(message.parts);
          final nextParts = recomputeAttachmentAvailability(remapped);
          refreshed.add(
            identical(nextParts, message.parts)
                ? message
                : message.copyWith(parts: nextParts),
          );
        }
        messages = refreshed;
      } else if (restoreChats && !cfg.includeFiles) {
        // Chats-only legacy import: local attachments unavailable by default.
        final refreshed = <ChatMessage>[];
        for (final message in messages) {
          final nextParts = recomputeAttachmentAvailability(
            message.parts,
            fileExists: (_) => false,
          );
          refreshed.add(
            identical(nextParts, message.parts)
                ? message
                : message.copyWith(parts: nextParts),
          );
        }
        messages = refreshed;
      }

      // Restore chats
      if (restoreChats) {
        beginNonCancellableCommit();
        try {
          if (mode == RestoreMode.overwrite) {
            await chatService.replaceAllDataFromBackup(
              conversations: conversations,
              messages: messages,
              toolEventsByMessageId: toolEvents,
              geminiSignaturesByMessageId: geminiThoughtSigs,
            );
          } else {
            // Merge mode: Add only non-existing conversations and messages
            final existingConvs = chatService.getAllCompleteConversations();
            final existingConvIds = existingConvs.map((c) => c.id).toSet();

            // Create a map of message IDs to avoid duplicates (ids only:
            // full message loads would flush the LRU cache for no gain)
            final existingMsgIds = <String>{};
            for (final conv in existingConvs) {
              existingMsgIds.addAll(await chatService.getMessageIds(conv.id));
            }

            // Group messages by conversation
            final byConv = <String, List<ChatMessage>>{};
            for (final m in messages) {
              if (!existingMsgIds.contains(m.id)) {
                (byConv[m.conversationId] ??= <ChatMessage>[]).add(m);
              }
            }

            // Restore non-existing conversations and their messages
            final mergedConvIds = <String>[];
            for (final c in conversations) {
              if (!existingConvIds.contains(c.id)) {
                final list = byConv[c.id] ?? const <ChatMessage>[];
                await chatService.restoreConversation(c, list);
                mergedConvIds.add(c.id);
              } else if (byConv.containsKey(c.id)) {
                // Conversation exists but has new messages
                final newMessages = byConv[c.id]!;
                for (final msg in newMessages) {
                  await chatService.addMessageDirectly(c.id, msg);
                }
                mergedConvIds.add(c.id);
              }
            }

            // Merge tool events
            for (final entry in toolEvents.entries) {
              final existing = chatService.getToolEvents(entry.key);
              if (existing.isEmpty) {
                await chatService.setToolEvents(entry.key, entry.value);
              }
            }
            for (final entry in geminiThoughtSigs.entries) {
              final existingSig = chatService.getGeminiThoughtSignature(
                entry.key,
              );
              if (existingSig == null || existingSig.isEmpty) {
                await chatService.setGeminiThoughtSignature(
                  entry.key,
                  entry.value,
                );
              }
            }
            // §6.7: restored history must not re-trigger background extraction,
            // and injection hashes must clear so the next request self-heals.
            await businessRepository.applyPostMergeMemoryConversationState(
              mergedConvIds,
            );
          }
        } catch (_) {
          rethrow;
        }
      }

      final restoreBusiness = pendingBusinessRestore;
      if (restoreBusiness != null) {
        beginNonCancellableCommit();
        await _runLiveBusinessRestore(restoreBusiness);
      }
    } catch (error) {
      restoreError = error;
      rethrow;
    } finally {
      await deleteTempDirectoryWhenIsolateSafe(extractDir, error: restoreError);
    }
  }
}

class _ExtractionBudget {
  _ExtractionBudget({required this.maxTotalBytes});

  final int maxTotalBytes;
  int _writtenBytes = 0;

  void reserve(int bytes) {
    if (bytes < 0 || _writtenBytes + bytes > maxTotalBytes) {
      throw const FormatException('zip_total_size');
    }
    _writtenBytes += bytes;
  }
}

class _BoundedOutputFileStream extends OutputFileStream {
  _BoundedOutputFileStream(
    String path, {
    required this.expectedBytes,
    required this.maxEntryBytes,
    required this.budget,
    this.meter,
  }) : super.withFileHandle(FileHandle(path, mode: FileAccess.write));

  final int expectedBytes;
  final int maxEntryBytes;
  final _ExtractionBudget budget;
  final _BackupByteMeter? meter;
  int _entryBytes = 0;

  void _reserve(int bytes) {
    if (bytes < 0 ||
        _entryBytes + bytes > expectedBytes ||
        _entryBytes + bytes > maxEntryBytes) {
      throw const FormatException('zip_entry_size');
    }
    budget.reserve(bytes);
    _entryBytes += bytes;
    meter?.add(bytes);
  }

  @override
  void writeByte(int value) {
    _reserve(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final writeLength = length ?? bytes.length;
    if (writeLength < 0 || writeLength > bytes.length) {
      throw RangeError.range(writeLength, 0, bytes.length, 'length');
    }
    _reserve(writeLength);
    super.writeBytes(bytes, length: writeLength);
  }

  @override
  void writeStream(InputStream stream) {
    const chunkSize = 1024 * 1024;
    while (!stream.isEOS) {
      meter?.ctx?.throwIfCancelled();
      final readSize = stream.length < chunkSize ? stream.length : chunkSize;
      final bytes = stream.readBytes(readSize).toUint8List();
      if (bytes.isEmpty) break;
      writeBytes(bytes);
    }
  }

  void verifyComplete() {
    if (_entryBytes != expectedBytes) {
      throw const FormatException('zip_entry_size');
    }
  }
}

class _BackupExtractArgs {
  const _BackupExtractArgs({
    required this.zipPath,
    required this.extractDirPath,
  });

  final String zipPath;
  final String extractDirPath;
}

class _LegacyChatParseArgs {
  const _LegacyChatParseArgs({
    required this.chatsPath,
    required this.stagingPath,
    required this.buildOverwriteCandidate,
  });

  final String chatsPath;
  final String stagingPath;
  final bool buildOverwriteCandidate;
}

class _BackupPreflightArgs {
  const _BackupPreflightArgs({
    required this.manifestPath,
    required this.extractDirPath,
    this.allowUnverifiedForwardCompatible = false,
  });

  final String manifestPath;
  final String extractDirPath;

  /// Set only after the user has been told the backup comes from a newer
  /// version that made no compatibility promise, and chose to continue.
  final bool allowUnverifiedForwardCompatible;
}

class _BackupPackArgs {
  const _BackupPackArgs({
    required this.outPath,
    required this.manifestPath,
    required this.settingsPath,
    required this.databasePath,
    required this.snapshotInfo,
    required this.includeChats,
    required this.includeFiles,
    required this.appVersion,
    required this.businessEntityRowIds,
    required this.uploadDirPath,
    required this.avatarsDirPath,
    required this.imagesDirPath,
    required this.fontsDirPath,
  });

  final String outPath;
  final String manifestPath;
  final String settingsPath;
  final String? databasePath;
  final ChatDatabaseSnapshotInfo? snapshotInfo;
  final bool includeChats;
  final bool includeFiles;
  final String appVersion;
  final Map<String, List<String>> businessEntityRowIds;
  final String uploadDirPath;
  final String avatarsDirPath;
  final String imagesDirPath;
  final String fontsDirPath;
}

class _BackupByteMeter {
  _BackupByteMeter({
    required this.ctx,
    required this.phase,
    required this.total,
  });

  final BackupIsolateContext? ctx;
  final BackupPhase phase;
  final int total;
  var processed = 0;

  void add(int bytes, {String? detail}) {
    processed += bytes;
    report(detail: detail);
  }

  void report({String? detail}) {
    ctx?.throwIfCancelled();
    ctx?.reportProgress(
      BackupProgress(
        phase: phase,
        processed: processed,
        total: total,
        unit: BackupProgressUnit.bytes,
        detail: detail,
        cancellable: true,
      ),
    );
  }
}

class _StreamingZipWriter {
  _StreamingZipWriter(String outPath, {this.meter})
    : _output = OutputFileStream(outPath);

  final _BackupByteMeter? meter;

  static const int _localFileHeaderSignature = 0x04034b50;
  static const int _centralDirectoryHeaderSignature = 0x02014b50;
  static const int _endOfCentralDirectorySignature = 0x06054b50;
  static const int _zip64EndOfCentralDirectorySignature = 0x06064b50;
  static const int _zip64EndOfCentralDirectoryLocatorSignature = 0x07064b50;
  static const int _dataDescriptorSignature = 0x08074b50;
  static const int _versionNeeded = 45;
  static const int _utf8Flag = 1 << 11;
  static const int _dataDescriptorFlag = 1 << 3;
  static const int _deflateMethod = 8;
  static const int _maxZip32 = 0xffffffff;
  static const int _chunkSize = 1024 * 1024;

  final OutputFileStream _output;
  final List<_StreamingZipEntry> _entries = <_StreamingZipEntry>[];
  bool _closed = false;

  _BackupEntryMetadata addFile(File file, String entryName) {
    if (_closed) {
      throw StateError('Cannot add files after the ZIP writer is closed.');
    }
    if (entryName.isEmpty) {
      throw ArgumentError.value(entryName, 'entryName', 'must not be empty');
    }

    final stat = file.statSync();
    final uncompressedSize = stat.size;
    // Deflate may grow incompressible input slightly, so reserve ZIP64 before
    // the 32-bit boundary instead of discovering overflow after streaming.
    final usesZip64Entry = uncompressedSize > _maxZip32 - (16 * 1024 * 1024);

    final modified = stat.modified;
    final modTime = _zipTime(modified);
    final modDate = _zipDate(modified);
    final nameBytes = utf8.encode(entryName);
    if (nameBytes.length > 0xffff) {
      throw FileSystemException('ZIP entry name exceeds ZIP32 limit');
    }
    final localHeaderOffset = _output.length;

    _writeLocalHeader(
      nameBytes: nameBytes,
      modTime: modTime,
      modDate: modDate,
      usesZip64: usesZip64Entry,
    );

    final written = _writeDeflatedFile(file, entryName);
    _writeDataDescriptor(written, usesZip64: usesZip64Entry);

    _entries.add(
      _StreamingZipEntry(
        nameBytes: nameBytes,
        modTime: modTime,
        modDate: modDate,
        crc32: written.crc32,
        compressedSize: written.compressedSize,
        uncompressedSize: written.uncompressedSize,
        localHeaderOffset: localHeaderOffset,
        mode: stat.mode,
      ),
    );
    return (bytes: written.uncompressedSize, sha256: written.sha256);
  }

  void closeSync() {
    if (_closed) return;
    final centralDirectoryOffset = _output.length;
    for (final entry in _entries) {
      _writeCentralDirectoryHeader(entry);
    }
    final centralDirectorySize = _output.length - centralDirectoryOffset;
    _writeEndOfCentralDirectory(
      centralDirectoryOffset: centralDirectoryOffset,
      centralDirectorySize: centralDirectorySize,
    );
    _output.closeSync();
    _closed = true;
  }

  void closeIfNeededSync() {
    if (!_closed) {
      _output.closeSync();
      _closed = true;
    }
  }

  void _writeLocalHeader({
    required List<int> nameBytes,
    required int modTime,
    required int modDate,
    required bool usesZip64,
  }) {
    _output.writeUint32(_localFileHeaderSignature);
    _output.writeUint16(_versionNeeded);
    _output.writeUint16(_utf8Flag | _dataDescriptorFlag);
    _output.writeUint16(_deflateMethod);
    _output.writeUint16(modTime);
    _output.writeUint16(modDate);
    _output.writeUint32(0);
    _output.writeUint32(usesZip64 ? _maxZip32 : 0);
    _output.writeUint32(usesZip64 ? _maxZip32 : 0);
    _output.writeUint16(nameBytes.length);
    _output.writeUint16(usesZip64 ? 20 : 0);
    _output.writeBytes(nameBytes);
    if (usesZip64) {
      _output.writeUint16(0x0001);
      _output.writeUint16(16);
      // Sizes are finalized by the ZIP64 data descriptor and central directory.
      _output.writeUint64(0);
      _output.writeUint64(0);
    }
  }

  _StreamingZipWrittenFile _writeDeflatedFile(File file, String entryName) {
    final compressedSink = _CountingOutputSink(_output);
    final inputSink = ZLibCodec(
      level: ZLibOption.defaultLevel,
      raw: true,
    ).encoder.startChunkedConversion(compressedSink);
    final digestSink = _DigestOutputSink();
    final hashSink = sha256.startChunkedConversion(digestSink);

    final raf = file.openSync();
    final buffer = Uint8List(_chunkSize);
    var crc32 = 0;
    var uncompressedSize = 0;
    try {
      while (true) {
        final read = raf.readIntoSync(buffer);
        if (read == 0) break;
        final chunk = Uint8List.sublistView(buffer, 0, read);
        crc32 = getCrc32(chunk, crc32);
        uncompressedSize += read;
        hashSink.add(chunk);
        inputSink.add(chunk);
        meter?.add(read, detail: entryName);
      }
      hashSink.close();
      inputSink.close();
    } finally {
      raf.closeSync();
    }

    return _StreamingZipWrittenFile(
      crc32: crc32,
      compressedSize: compressedSink.bytesWritten,
      uncompressedSize: uncompressedSize,
      sha256: digestSink.digest?.toString() ?? (throw StateError('sha256')),
    );
  }

  void _writeDataDescriptor(
    _StreamingZipWrittenFile written, {
    required bool usesZip64,
  }) {
    _output.writeUint32(_dataDescriptorSignature);
    _output.writeUint32(written.crc32);
    if (usesZip64) {
      _output.writeUint64(written.compressedSize);
      _output.writeUint64(written.uncompressedSize);
    } else {
      _output.writeUint32(written.compressedSize);
      _output.writeUint32(written.uncompressedSize);
    }
  }

  void _writeCentralDirectoryHeader(_StreamingZipEntry entry) {
    final usesZip64 =
        entry.compressedSize > _maxZip32 ||
        entry.uncompressedSize > _maxZip32 ||
        entry.localHeaderOffset > _maxZip32;
    _output.writeUint32(_centralDirectoryHeaderSignature);
    _output.writeUint16(_versionNeeded);
    _output.writeUint16(_versionNeeded);
    _output.writeUint16(_utf8Flag | _dataDescriptorFlag);
    _output.writeUint16(_deflateMethod);
    _output.writeUint16(entry.modTime);
    _output.writeUint16(entry.modDate);
    _output.writeUint32(entry.crc32);
    _output.writeUint32(usesZip64 ? _maxZip32 : entry.compressedSize);
    _output.writeUint32(usesZip64 ? _maxZip32 : entry.uncompressedSize);
    _output.writeUint16(entry.nameBytes.length);
    _output.writeUint16(usesZip64 ? 28 : 0);
    _output.writeUint16(0);
    _output.writeUint16(0);
    _output.writeUint16(0);
    _output.writeUint32(entry.mode << 16);
    _output.writeUint32(usesZip64 ? _maxZip32 : entry.localHeaderOffset);
    _output.writeBytes(entry.nameBytes);
    if (usesZip64) {
      _output.writeUint16(0x0001);
      _output.writeUint16(24);
      _output.writeUint64(entry.uncompressedSize);
      _output.writeUint64(entry.compressedSize);
      _output.writeUint64(entry.localHeaderOffset);
    }
  }

  void _writeEndOfCentralDirectory({
    required int centralDirectoryOffset,
    required int centralDirectorySize,
  }) {
    final zip64EocdOffset = _output.length;
    _output.writeUint32(_zip64EndOfCentralDirectorySignature);
    _output.writeUint64(44);
    _output.writeUint16(_versionNeeded);
    _output.writeUint16(_versionNeeded);
    _output.writeUint32(0);
    _output.writeUint32(0);
    _output.writeUint64(_entries.length);
    _output.writeUint64(_entries.length);
    _output.writeUint64(centralDirectorySize);
    _output.writeUint64(centralDirectoryOffset);

    _output.writeUint32(_zip64EndOfCentralDirectoryLocatorSignature);
    _output.writeUint32(0);
    _output.writeUint64(zip64EocdOffset);
    _output.writeUint32(1);

    _output.writeUint32(_endOfCentralDirectorySignature);
    _output.writeUint16(0);
    _output.writeUint16(0xffff);
    _output.writeUint16(0xffff);
    _output.writeUint16(0xffff);
    _output.writeUint32(_maxZip32);
    _output.writeUint32(_maxZip32);
    _output.writeUint16(0);
  }

  static int _zipTime(DateTime value) {
    return ((value.hour & 0x1f) << 11) |
        ((value.minute & 0x3f) << 5) |
        ((value.second ~/ 2) & 0x1f);
  }

  static int _zipDate(DateTime value) {
    final year = value.year < 1980 ? 1980 : value.year;
    return (((year - 1980) & 0x7f) << 9) |
        ((value.month & 0x0f) << 5) |
        (value.day & 0x1f);
  }
}

class _NullDigestOutputStream extends OutputStream {
  _NullDigestOutputStream({this.onBytes})
    : super(byteOrder: ByteOrder.littleEndian);

  final void Function(int bytes)? onBytes;

  static const _windowSize = 32768;
  static const _backRefFlushSize = 64 * 1024;
  final Uint8List _window = Uint8List(_windowSize);
  final Uint8List _one = Uint8List(1);
  final Uint8List _backRefBuf = Uint8List(_backRefFlushSize);
  final _digestSink = _DigestOutputSink();
  late final ByteConversionSink _hash = sha256.startChunkedConversion(
    _digestSink,
  );
  var _length = 0;
  var _closed = false;

  @override
  int get length => _length;

  int get bytesWritten => _length;

  String closeAndDigest() {
    if (!_closed) {
      _hash.close();
      _closed = true;
    }
    final digest = _digestSink.digest;
    if (digest == null) {
      throw StateError('sha256');
    }
    return digest.toString();
  }

  void _absorb(List<int> bytes, int start, int end) {
    if (start >= end) return;
    final view = bytes is Uint8List
        ? Uint8List.sublistView(bytes, start, end)
        : Uint8List.fromList(bytes.sublist(start, end));
    _hash.add(view);
    onBytes?.call(end - start);
    var offset = start;
    var remaining = end - start;
    while (remaining > 0) {
      final windowIndex = _length % _windowSize;
      final room = _windowSize - windowIndex;
      final n = remaining < room ? remaining : room;
      if (bytes is Uint8List) {
        _window.setRange(windowIndex, windowIndex + n, bytes, offset);
      } else {
        for (var i = 0; i < n; i++) {
          _window[windowIndex + i] = bytes[offset + i];
        }
      }
      _length += n;
      offset += n;
      remaining -= n;
    }
  }

  int _byteAtDistance(int distance) {
    if (distance <= 0 || distance > _length || distance > _windowSize) {
      throw StateError('lz77_window');
    }
    return _window[(_length - distance) % _windowSize];
  }

  @override
  void writeByte(int value) {
    _one[0] = value;
    _hash.add(_one);
    onBytes?.call(1);
    _window[_length % _windowSize] = value;
    _length++;
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final n = length ?? bytes.length;
    if (n < 0 || n > bytes.length) {
      throw RangeError.range(n, 0, bytes.length, 'length');
    }
    _absorb(bytes, 0, n);
  }

  @override
  void writeStream(InputStream stream) {
    const chunkSize = 1024 * 1024;
    while (!stream.isEOS) {
      final readSize = stream.length < chunkSize ? stream.length : chunkSize;
      final bytes = stream.readBytes(readSize).toUint8List();
      if (bytes.isEmpty) break;
      writeBytes(bytes);
    }
  }

  @override
  void writeBackReference(int distance, int count) {
    var remaining = count;
    while (remaining > 0) {
      final n = remaining < _backRefFlushSize ? remaining : _backRefFlushSize;
      for (var i = 0; i < n; i++) {
        final value = _byteAtDistance(distance);
        _backRefBuf[i] = value;
        _window[_length % _windowSize] = value;
        _length++;
      }
      _hash.add(Uint8List.sublistView(_backRefBuf, 0, n));
      onBytes?.call(n);
      remaining -= n;
    }
  }

  @override
  void clear() {}

  @override
  void flush() {}

  @override
  void closeSync() {
    if (!_closed) {
      _hash.close();
      _closed = true;
    }
  }

  @override
  Uint8List subset(int start, [int? end]) {
    if (start < 0) start = _length + start;
    final resolvedEnd = end == null ? _length : (end < 0 ? _length + end : end);
    final n = resolvedEnd - start;
    if (n < 0 || start < 0 || resolvedEnd > _length) {
      throw RangeError('subset');
    }
    if (n > _windowSize || _length - start > _windowSize) {
      throw StateError('subset_window');
    }
    final out = Uint8List(n);
    for (var i = 0; i < n; i++) {
      out[i] = _window[(start + i) % _windowSize];
    }
    return out;
  }
}

class _CountingOutputSink implements Sink<List<int>> {
  _CountingOutputSink(this._output);

  final OutputFileStream _output;
  int bytesWritten = 0;

  @override
  void add(List<int> data) {
    if (data.isEmpty) return;
    _output.writeBytes(data);
    bytesWritten += data.length;
  }

  @override
  void close() {}
}

class _DigestOutputSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest data) {
    if (digest != null) {
      throw StateError('Digest sink received more than one value');
    }
    digest = data;
  }

  @override
  void close() {}
}

class _StreamingZipEntry {
  const _StreamingZipEntry({
    required this.nameBytes,
    required this.modTime,
    required this.modDate,
    required this.crc32,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localHeaderOffset,
    required this.mode,
  });

  final List<int> nameBytes;
  final int modTime;
  final int modDate;
  final int crc32;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;
  final int mode;
}

class _StreamingZipWrittenFile {
  const _StreamingZipWrittenFile({
    required this.crc32,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.sha256,
  });

  final int crc32;
  final int compressedSize;
  final int uncompressedSize;
  final String sha256;
}
