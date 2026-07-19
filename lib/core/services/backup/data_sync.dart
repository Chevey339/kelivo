import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import '../../database/business_repository.dart';
import '../../database/business_restore_service.dart';
import '../../database/chat_database_repository.dart';
import '../../models/backup.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../chat/chat_service.dart';
import '../../../utils/app_directories.dart';
import 'backup_settings_validator.dart';
import 'restore_bundle_preparation.dart';
import 'temporary_restore_file.dart';

typedef _ParsedChatBackup = ({
  List<Conversation> conversations,
  List<ChatMessage> messages,
  Map<String, List<Map<String, dynamic>>> toolEvents,
  Map<String, String> geminiThoughtSigs,
});

typedef _BackupEntryMetadata = ({int bytes, String sha256});
typedef _VersionedBackupInfo = ({
  bool includeChats,
  bool includeFiles,
  bool secretsIncluded,
  String normalizedManifestSha256,
});

class DataSync {
  static const _backupFormat = 'kelivo-backup';
  static const _backupFormatVersion = 2;
  static const _manifestEntryName = 'manifest.json';
  static const _databaseEntryName = 'database/kelivo.db';
  // A 16 MiB metadata cap keeps manifest parsing and entry metadata bounded.
  static const _maxManifestBytes = 16 * 1024 * 1024;
  // Settings are parsed as one JSON object, so keep their decoded input bound.
  static const _maxSettingsBytes = 16 * 1024 * 1024;
  // ZIP64 supports larger entries. Restore keeps explicit, diagnosable bounds.
  static const _maxRestoreEntryBytes = 8 * 1024 * 1024 * 1024;
  static const _maxRestoreTotalBytes = 16 * 1024 * 1024 * 1024;
  static const _maxRestoreEntries = 100000;

  final ChatService chatService;
  final BusinessRepository businessRepository;
  BackupMergeReport? _lastMergeReport;
  BackupMergeReport? get lastMergeReport => _lastMergeReport;

  DataSync({required this.chatService, required this.businessRepository});

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

  Future<void> _ensureCollection(WebDavConfig cfg) async {
    final client = http.Client();
    try {
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
      }
    } finally {
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

  Future<File> prepareBackupFile(WebDavConfig cfg) async {
    final tmp = await _ensureTempDir();
    await _cleanupPreviousBackupTempFiles(tmp);
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final workDir = Directory(p.join(tmp.path, 'kelivo_backup_$timestamp'));
    await workDir.create(recursive: true);

    final outPath = p.join(workDir.path, 'kelivo_backup_$timestamp.zip');
    final outFile = File(outPath);
    if (await outFile.exists()) await outFile.delete();

    File? manifestTmp;
    File? settingsTmp;
    File? databaseTmp;
    try {
      // --- Step 1: Prepare temp files that need ChatService (main isolate) ---
      // settings.json
      final settingsJson = await _exportSettingsJson();
      final settingsFile = await _writeTempText(
        workDir,
        '_bk_settings.json',
        settingsJson,
      );
      settingsTmp = settingsFile;

      ChatDatabaseSnapshotInfo? snapshotInfo;
      if (cfg.includeChats) {
        final databaseFile = File(p.join(workDir.path, '_bk_kelivo.db'));
        databaseTmp = databaseFile;
        snapshotInfo = await chatService.createBackupDatabaseSnapshot(
          databaseFile,
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
      final verifyDirPath = p.join(workDir.path, '_verify');

      // --- Step 2: Run CPU-heavy ZIP packing in a separate isolate ---
      await Isolate.run(() async {
        _packZipSync(
          outPath: outPath,
          manifestPath: manifestPath,
          settingsPath: settingsPath,
          databasePath: databasePath,
          snapshotInfo: snapshotInfo,
          includeChats: cfg.includeChats,
          includeFiles: includeFiles,
          appVersion: appVersion,
          uploadDirPath: uploadDirPath,
          avatarsDirPath: avatarsDirPath,
          imagesDirPath: imagesDirPath,
          fontsDirPath: fontsDirPath,
        );
        final verifyDir = Directory(verifyDirPath);
        try {
          verifyDir.createSync(recursive: true);
          _extractZipSync(outPath, verifyDirPath);
          await _preflightVersionedBackup(
            manifestPath: p.join(verifyDirPath, _manifestEntryName),
            extractDirPath: verifyDirPath,
          );
        } finally {
          if (verifyDir.existsSync()) {
            verifyDir.deleteSync(recursive: true);
          }
        }
      });

      return outFile;
    } catch (_) {
      await _deleteDirectoryQuietly(workDir);
      rethrow;
    } finally {
      // Cleanup temp intermediate files. The final zip is returned to callers
      // and must be deleted by the upload/export caller after it is consumed.
      await _deleteFileQuietly(settingsTmp);
      await _deleteFileQuietly(databaseTmp);
      await _deleteFileQuietly(manifestTmp);
    }
  }

  static Future<void> cleanupTemporaryBackupFile(File? file) async {
    if (file == null) return;
    final parent = file.parent;
    await _deleteFileQuietly(file);
    try {
      if (await parent.exists() && await parent.list().isEmpty) {
        await parent.delete();
      }
    } catch (_) {}
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

  static Future<void> _cleanupPreviousBackupTempFiles(Directory tmp) async {
    try {
      if (!await tmp.exists()) return;
      await for (final ent in tmp.list(followLinks: false)) {
        final name = p.basename(ent.path);
        if (ent is Directory && name.startsWith('kelivo_backup_')) {
          await _deleteDirectoryQuietly(ent);
        } else if (ent is File &&
            ((name.startsWith('kelivo_backup_') && name.endsWith('.zip')) ||
                name == '_bk_settings.json' ||
                name == '_bk_chats.json' ||
                name == '_bk_manifest.json' ||
                name == '_bk_kelivo.db')) {
          await _deleteFileQuietly(ent);
        }
      }
    } catch (_) {}
  }

  /// Synchronous ZIP packing — runs inside an Isolate.
  static void _packZipSync({
    required String outPath,
    required String manifestPath,
    required String settingsPath,
    String? databasePath,
    required ChatDatabaseSnapshotInfo? snapshotInfo,
    required bool includeChats,
    required bool includeFiles,
    required String appVersion,
    required String uploadDirPath,
    required String avatarsDirPath,
    required String imagesDirPath,
    required String fontsDirPath,
  }) {
    if (includeChats != (databasePath != null && snapshotInfo != null)) {
      throw StateError('backup_database_component');
    }
    final writer = _StreamingZipWriter(outPath);
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
        );
        _addDirectoryToZip(
          writer,
          avatarsDirPath,
          'avatars',
          entries,
          collisionKeys,
        );
        _addDirectoryToZip(
          writer,
          imagesDirPath,
          'images',
          entries,
          collisionKeys,
        );
        _addDirectoryToZip(
          writer,
          fontsDirPath,
          'fonts',
          entries,
          collisionKeys,
        );
      }

      final manifestJson = _buildBackupManifestJson(
        entries: entries,
        snapshotInfo: snapshotInfo,
        includeChats: includeChats,
        includeFiles: includeFiles,
        appVersion: appVersion,
      );
      final manifestFile = File(manifestPath)
        ..writeAsStringSync(manifestJson, flush: true);
      writer.addFile(manifestFile, _manifestEntryName);
      writer.closeSync();
    } finally {
      writer.closeIfNeededSync();
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
    Set<String> collisionKeys,
  ) {
    final dir = Directory(srcDirPath);
    if (!dir.existsSync()) return;
    final fileSystemEntries = dir.listSync(recursive: true, followLinks: false);
    for (final ent in fileSystemEntries) {
      if (ent is File) {
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
  static void _extractZipSync(String zipPath, String extractDirPath) {
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
        manifest['formatVersion'] != _backupFormatVersion) {
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

  Future<void> backupToWebDav(WebDavConfig cfg) async {
    final file = await prepareBackupFile(cfg);
    try {
      await _ensureCollection(cfg);
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
      // Pipe the file stream into the request body.
      file.openRead().listen(
        req.sink.add,
        onDone: req.sink.close,
        onError: req.sink.addError,
      );
      final client = http.Client();
      try {
        final res = await client.send(req).then(http.Response.fromStream);
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw Exception('Upload failed: ${res.statusCode}');
        }
      } finally {
        client.close();
      }
    } finally {
      await cleanupTemporaryBackupFile(file);
    }
  }

  Future<List<BackupFileItem>> listBackupFiles(WebDavConfig cfg) async {
    await _ensureCollection(cfg);
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
    final res = await http.Client().send(req).then(http.Response.fromStream);
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

  Future<void> restoreFromWebDav(
    WebDavConfig cfg,
    BackupFileItem item, {
    RestoreMode mode = RestoreMode.overwrite,
  }) async {
    // Stream the download to a file instead of buffering in memory.
    final client = http.Client();
    File? file;
    try {
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
      final sink = file.openWrite();
      await streamed.stream.pipe(sink);
      await _restoreFromBackupFile(file, cfg, mode: mode);
    } finally {
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

  Future<File> exportToFile(WebDavConfig cfg) => prepareBackupFile(cfg);

  Future<void> restoreFromLocalFile(
    File file,
    WebDavConfig cfg, {
    RestoreMode mode = RestoreMode.overwrite,
  }) async {
    if (!await file.exists()) throw Exception('备份文件不存在');
    await _restoreFromBackupFile(file, cfg, mode: mode);
  }

  // ===== Internal helpers =====
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
  }) {
    return jsonEncode({
      'format': _backupFormat,
      'formatVersion': _backupFormatVersion,
      'payloadKind': includeChats ? 'sqlite' : 'settings-only',
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      'appVersion': appVersion,
      'includeChats': includeChats,
      'includeFiles': includeFiles,
      'secretsIncluded': true,
      if (snapshotInfo != null)
        'database': {
          'entry': _databaseEntryName,
          'schemaVersion': snapshotInfo.schemaVersion,
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

  static Future<_VersionedBackupInfo> _preflightVersionedBackup({
    required String manifestPath,
    required String extractDirPath,
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
        manifest['formatVersion'] != _backupFormatVersion) {
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
    for (final name in entries.keys) {
      final knownEntry =
          name == 'settings.json' ||
          name == _databaseEntryName ||
          name.startsWith('upload/') ||
          name.startsWith('avatars/') ||
          name.startsWith('images/') ||
          name.startsWith('fonts/');
      if (!knownEntry) {
        throw FormatException('manifest_entry_scope:$name');
      }
      if (!includeFiles &&
          (name.startsWith('upload/') ||
              name.startsWith('avatars/') ||
              name.startsWith('images/') ||
              name.startsWith('fonts/'))) {
        throw FormatException('manifest_files:$name');
      }
    }

    for (final entry in entries.entries) {
      final file = File(p.joinAll([extractDirPath, ...entry.key.split('/')]));
      if (!file.existsSync() || file.lengthSync() != entry.value.bytes) {
        throw FormatException('manifest_entry_size:${entry.key}');
      }
      if (_sha256FileSync(file) != entry.value.sha256) {
        throw FormatException('manifest_entry_hash:${entry.key}');
      }
    }

    final rawDatabase = manifest['database'];
    if (payloadKind == 'sqlite') {
      if (!includeChats ||
          !entries.containsKey(_databaseEntryName) ||
          rawDatabase is! Map) {
        throw const FormatException('manifest_database');
      }
      final database = rawDatabase.cast<String, dynamic>();
      final schemaVersion = database['schemaVersion'];
      final conversationCount = database['conversationCount'];
      final messageCount = database['messageCount'];
      if (database['entry'] != _databaseEntryName ||
          schemaVersion is! int ||
          conversationCount is! int ||
          conversationCount < 0 ||
          messageCount is! int ||
          messageCount < 0) {
        throw const FormatException('manifest_database');
      }
      final databaseFile = File(
        p.joinAll([extractDirPath, ..._databaseEntryName.split('/')]),
      );
      final databaseInfo =
          await ChatDatabaseRepository.prepareSnapshotForRestore(databaseFile);
      if (databaseInfo.schemaVersion != schemaVersion ||
          databaseInfo.conversationCount != conversationCount ||
          databaseInfo.messageCount != messageCount) {
        throw const FormatException('manifest_database_metadata');
      }
      entries[_databaseEntryName] = (
        bytes: databaseFile.lengthSync(),
        sha256: _sha256FileSync(databaseFile),
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

    return (
      includeChats: includeChats,
      includeFiles: includeFiles,
      secretsIncluded: true,
      normalizedManifestSha256: normalizedManifestSha256,
    );
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

  static String _sha256FileSync(File file) {
    final digestSink = _DigestOutputSink();
    final hashSink = sha256.startChunkedConversion(digestSink);
    final input = file.openSync();
    final buffer = Uint8List(1024 * 1024);
    try {
      while (true) {
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

  Future<void> _validateOverwriteChatCandidate({
    required Directory stagingDirectory,
    required File chatsFile,
  }) async {
    final candidatePath = p.join(stagingDirectory.path, 'candidate.sqlite');
    final chatsPath = chatsFile.path;
    await _deleteDatabaseFamily(candidatePath);
    try {
      await Isolate.run(() async {
        final parsed = await _parseChatBackup(File(chatsPath));
        _validateBackupReferences(
          conversations: parsed.conversations,
          messages: parsed.messages,
          toolEvents: parsed.toolEvents,
          geminiThoughtSigs: parsed.geminiThoughtSigs,
        );
        await _buildAndValidateOverwriteChatCandidate(
          candidatePath: candidatePath,
          conversations: parsed.conversations,
          messages: parsed.messages,
          toolEvents: parsed.toolEvents,
          geminiThoughtSigs: parsed.geminiThoughtSigs,
        );
      });
    } finally {
      await _deleteDatabaseFamily(candidatePath);
    }
  }

  Future<void> _deleteDatabaseFamily(String databasePath) async {
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final file = File('$databasePath$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static Future<_ParsedChatBackup> _parseChatBackup(File chatsFile) async {
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
    return (
      conversations: (chats['conversations'] as List)
          .map(
            (entry) =>
                Conversation.fromJson((entry as Map).cast<String, dynamic>()),
          )
          .toList(),
      messages: (chats['messages'] as List)
          .map(
            (entry) =>
                ChatMessage.fromJson((entry as Map).cast<String, dynamic>()),
          )
          .map(
            (message) => message.isStreaming
                ? message.copyWith(isStreaming: false)
                : message,
          )
          .toList(),
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

  Future<String> _exportSettingsJson() async {
    final settings = await BusinessRestoreService(
      businessRepository,
    ).exportSettings();
    settings.removeWhere((key, _) => BackupSettingsValidator.shouldIgnore(key));
    return jsonEncode(settings);
  }

  Future<void> _restoreFromBackupFile(
    File file,
    WebDavConfig cfg, {
    RestoreMode mode = RestoreMode.overwrite,
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

    try {
      // Run ZIP extraction in an isolate to keep the UI responsive.
      await Isolate.run(() {
        _extractZipSync(file.path, extractDir.path);
      });

      final manifestFile = File(p.join(extractDir.path, _manifestEntryName));
      final restorePayloadDirectory = extractDir;
      final settingsFile = File(p.join(extractDir.path, 'settings.json'));
      final chatsFile = File(p.join(extractDir.path, 'chats.json'));
      if (!await settingsFile.exists()) {
        throw const FormatException('settings.json');
      }
      final _VersionedBackupInfo? versionedBackup;
      if (await manifestFile.exists()) {
        final manifestPath = manifestFile.path;
        final extractDirPath = extractDir.path;
        versionedBackup = await Isolate.run(
          () => _preflightVersionedBackup(
            manifestPath: manifestPath,
            extractDirPath: extractDirPath,
          ),
        );
      } else {
        versionedBackup = null;
      }
      final settingsPath = settingsFile.path;
      final settings = await Isolate.run(
        () => _readSettingsJsonSync(settingsPath),
      );
      BackupSettingsValidator.normalizeAndValidate(settings);
      final businessRestore = BusinessRestoreService(businessRepository);
      if (versionedBackup != null) {
        final includeChats = versionedBackup.includeChats;
        final includeFiles = versionedBackup.includeFiles;
        final restoreChats = cfg.includeChats && includeChats;
        final restoreFiles = cfg.includeFiles && includeFiles;
        if (mode == RestoreMode.overwrite) {
          if (!restoreChats) {
            await businessRestore.overwrite(settings);
            return;
          }
          final appDataPath = (await AppDirectories.getAppDataDirectory()).path;
          final extractedPath = extractDir.path;
          final sourceManifestSha256 = versionedBackup.normalizedManifestSha256;
          await Isolate.run(() async {
            await RestoreBundlePreparation.prepare(
              appDataDirectory: Directory(appDataPath),
              extractedDirectory: Directory(extractedPath),
              sourceManifestSha256: sourceManifestSha256,
              bundleIncludesChats: includeChats,
              bundleIncludesFiles: includeFiles,
              restoreChats: restoreChats,
              restoreFiles: restoreFiles,
            );
          });
          return;
        }
        if (restoreChats) {
          _lastMergeReport = await chatService.mergeDatabaseSnapshot(
            File(p.join(extractDir.path, _databaseEntryName)),
          );
        }
        await businessRestore.merge(settings);
        if (!restoreChats) {
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
      if (mode == RestoreMode.overwrite && restoreChats) {
        await _validateOverwriteChatCandidate(
          stagingDirectory: extractDir,
          chatsFile: chatsFile,
        );
      }
      if (restoreChats) {
        final parsed = await _parseChatBackup(chatsFile);
        conversations = parsed.conversations;
        messages = parsed.messages;
        toolEvents = parsed.toolEvents;
        geminiThoughtSigs = parsed.geminiThoughtSigs;
      }

      if (versionedBackup == null) {
        if (mode == RestoreMode.overwrite) {
          await businessRestore.overwrite(settings);
        } else {
          await businessRestore.merge(settings);
        }
        if (!restoreChats) {
          return;
        }
      }

      // Restore chats
      if (restoreChats) {
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

            // Create a map of message IDs to avoid duplicates
            final existingMsgIds = <String>{};
            for (final conv in existingConvs) {
              final messages = await chatService.loadMessages(conv.id);
              existingMsgIds.addAll(messages.map((m) => m.id));
            }

            // Group messages by conversation
            final byConv = <String, List<ChatMessage>>{};
            for (final m in messages) {
              if (!existingMsgIds.contains(m.id)) {
                (byConv[m.conversationId] ??= <ChatMessage>[]).add(m);
              }
            }

            // Restore non-existing conversations and their messages
            for (final c in conversations) {
              if (!existingConvIds.contains(c.id)) {
                final list = byConv[c.id] ?? const <ChatMessage>[];
                await chatService.restoreConversation(c, list);
              } else if (byConv.containsKey(c.id)) {
                // Conversation exists but has new messages
                final newMessages = byConv[c.id]!;
                for (final msg in newMessages) {
                  await chatService.addMessageDirectly(c.id, msg);
                }
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
          }
        } catch (_) {
          rethrow;
        }
      }

      // Restore files
      if (cfg.includeFiles) {
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
          // Merge upload directory
          final uploadSrc = Directory(
            p.join(restorePayloadDirectory.path, 'upload'),
          );
          if (await uploadSrc.exists()) {
            final dst = await _getUploadDir();
            if (!await dst.exists()) {
              await dst.create(recursive: true);
            }
            for (final ent in uploadSrc.listSync(recursive: true)) {
              if (ent is File) {
                final rel = p.relative(ent.path, from: uploadSrc.path);
                final target = File(p.join(dst.path, rel));
                if (!await target.exists()) {
                  await _copyRestoredFile(ent, target);
                }
              }
            }
          }

          // Merge images directory
          final imagesSrc = Directory(
            p.join(restorePayloadDirectory.path, 'images'),
          );
          if (await imagesSrc.exists()) {
            final dst = await _getImagesDir();
            if (!await dst.exists()) {
              await dst.create(recursive: true);
            }
            for (final ent in imagesSrc.listSync(recursive: true)) {
              if (ent is File) {
                final rel = p.relative(ent.path, from: imagesSrc.path);
                final target = File(p.join(dst.path, rel));
                if (!await target.exists()) {
                  await _copyRestoredFile(ent, target);
                }
              }
            }
          }

          // Merge avatars directory
          final avatarsSrc = Directory(
            p.join(restorePayloadDirectory.path, 'avatars'),
          );
          if (await avatarsSrc.exists()) {
            final dst = await _getAvatarsDir();
            if (!await dst.exists()) {
              await dst.create(recursive: true);
            }
            for (final ent in avatarsSrc.listSync(recursive: true)) {
              if (ent is File) {
                final rel = p.relative(ent.path, from: avatarsSrc.path);
                final target = File(p.join(dst.path, rel));
                if (!await target.exists()) {
                  await _copyRestoredFile(ent, target);
                }
              }
            }
          }

          // Merge managed local fonts directory
          final fontsSrc = Directory(
            p.join(restorePayloadDirectory.path, 'fonts'),
          );
          if (await fontsSrc.exists()) {
            final dst = await _getFontsDir();
            if (!await dst.exists()) {
              await dst.create(recursive: true);
            }
            for (final ent in fontsSrc.listSync(recursive: true)) {
              if (ent is File) {
                final rel = p.relative(ent.path, from: fontsSrc.path);
                final target = File(p.join(dst.path, rel));
                if (!await target.exists()) {
                  await _copyRestoredFile(ent, target);
                }
              }
            }
          }
        }
      }
    } finally {
      await _deleteDirectoryQuietly(extractDir);
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
  }) : super.withFileHandle(FileHandle(path, mode: FileAccess.write));

  final int expectedBytes;
  final int maxEntryBytes;
  final _ExtractionBudget budget;
  int _entryBytes = 0;

  void _reserve(int bytes) {
    if (bytes < 0 ||
        _entryBytes + bytes > expectedBytes ||
        _entryBytes + bytes > maxEntryBytes) {
      throw const FormatException('zip_entry_size');
    }
    budget.reserve(bytes);
    _entryBytes += bytes;
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

class _StreamingZipWriter {
  _StreamingZipWriter(String outPath) : _output = OutputFileStream(outPath);

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

    final written = _writeDeflatedFile(file);
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

  _StreamingZipWrittenFile _writeDeflatedFile(File file) {
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
