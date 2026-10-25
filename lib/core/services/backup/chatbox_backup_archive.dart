import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'streaming_zip_entry.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../utils/sandbox_path_resolver.dart';

class ChatboxImportException implements Exception {
  final String message;
  const ChatboxImportException(this.message);
  @override
  String toString() => message;
}

class ChatboxBackupReadResult {
  final Map<String, dynamic> root;
  final List<File> stagedResourceFiles;
  final String resourceDestDir;

  const ChatboxBackupReadResult({
    required this.root,
    required this.stagedResourceFiles,
    required this.resourceDestDir,
  });
}

/// Chatbox 1.22+ ZIP v2 backup (`format=chatbox-backup`, `formatVersion=2`).
class ChatboxBackupArchive {
  ChatboxBackupArchive._();

  static const String backupFormat = 'chatbox-backup';
  static const int backupFormatVersion = 2;
  static const int maxSessions = 50000;
  static const int maxResources = 50000;
  static const int maxFileEntries = 100004;
  static const int maxJsonEntryBytes = 128 * 1024 * 1024;
  static const int maxResourceEntryBytes = 512 * 1024 * 1024;
  static const int maxTotalUncompressedBytes = 4 * 1024 * 1024 * 1024;
  static const int maxCompressionRatio = 2000;

  static const String _manifestPath = 'manifest.json';
  static const String _settingsPath = 'settings.json';
  static const String _copilotsPath = 'copilots.json';
  static const String _sessionSettingsPath = 'session-settings.json';

  static const Set<String> _exportItems = {
    'setting',
    'key',
    'conversations',
    'copilot',
  };

  static const Set<String> _resourceScopes = {'session', 'shared', 'global'};
  static const Set<String> _resourceEncodings = {'utf8', 'data-url-base64'};
  static const Set<String> _resourceKinds = {
    'image',
    'parsed-attachment',
    'raw-attachment',
    'parsed-link',
    'tool-result',
    'avatar',
    'background',
    'copilot-image',
  };

  static final RegExp _sha256Hex = RegExp(r'^[a-f0-9]{64}$');
  static final RegExp _windowsDrive = RegExp(r'^[a-zA-Z]:');

  static bool looksLikeZip(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4b &&
        ((bytes[2] == 0x03 && bytes[3] == 0x04) ||
            (bytes[2] == 0x05 && bytes[3] == 0x06) ||
            (bytes[2] == 0x07 && bytes[3] == 0x08));
  }

  static Future<bool> looksLikeZipFile(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      return looksLikeZip(await raf.read(4));
    } catch (_) {
      return false;
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  static Future<ChatboxBackupReadResult> readZipV2({
    File? file,
    List<int>? bytes,
    required Directory stagingDir,
    required String resourceDestDir,
  }) async {
    if (file == null && bytes == null) {
      throw ArgumentError('Pass file or bytes');
    }
    InputFileStream? input;
    Archive? archive;
    try {
      try {
        if (file != null) {
          input = InputFileStream(file.path);
          archive = ZipDecoder().decodeStream(input, verify: true);
        } else {
          archive = ZipDecoder().decodeBytes(bytes!, verify: true);
        }
      } catch (e) {
        if (e is ChatboxImportException) rethrow;
        throw ChatboxImportException('Unable to read Chatbox backup ZIP: $e');
      }
      return await _interpretArchive(
        archive,
        stagingDir: stagingDir,
        resourceDestDir: resourceDestDir,
      );
    } finally {
      try {
        archive?.clearSync();
      } catch (_) {}
      try {
        input?.closeSync();
      } catch (_) {}
    }
  }

  static Future<ChatboxBackupReadResult> _interpretArchive(
    Archive archive, {
    required Directory stagingDir,
    required String resourceDestDir,
  }) async {
    final entries = <String, ArchiveFile>{};
    var totalUncompressed = 0;
    var fileCount = 0;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      if (entry.isSymbolicLink) {
        throw ChatboxImportException('Unsafe ZIP entry path: ${entry.name}');
      }
      final path = _normalizedArchivePath(entry.name);
      if (entries.containsKey(path)) {
        throw ChatboxImportException('Duplicate ZIP entry: $path');
      }
      fileCount++;
      if (fileCount > maxFileEntries) {
        throw const ChatboxImportException('Backup contains too many entries.');
      }
      _assertEntryBudget(
        path: path,
        uncompressed: entry.size,
        compressed: _compressedLength(entry),
      );
      totalUncompressed += entry.size;
      if (totalUncompressed > maxTotalUncompressedBytes) {
        throw const ChatboxImportException(
          'Backup uncompressed size exceeds the safety limit.',
        );
      }
      entries[path] = entry;
    }

    final manifestEntry = entries[_manifestPath];
    if (manifestEntry == null) {
      throw const ChatboxImportException(
        'Not a Chatbox backup archive (missing manifest.json).',
      );
    }
    final manifest = _parseManifest(
      _extractVerified(
        manifestEntry,
        <String, dynamic>{
          'path': _manifestPath,
          'size': manifestEntry.size,
          'checksum': null,
        },
        collectBytes: true,
        verifyChecksum: false,
      ).bytes!,
    );
    _validateManifestMembership(manifest, entries);

    final keyToUri = <String, String>{};
    final keyToText = <String, String>{};
    final staged = <File>[];
    await stagingDir.create(recursive: true);

    final resources = manifest['resources'] as List;
    for (final raw in resources) {
      final resource = _asStringMap(raw);
      final path = resource['path'] as String;
      final kind = (resource['kind'] ?? '').toString();
      if (kind == 'tool-result') {
        final extracted = _extractVerified(
          entries[path]!,
          resource,
          collectBytes: true,
        );
        final text = utf8.decode(extracted.bytes!);
        for (final key in resource['originalStorageKeys'] as List) {
          keyToText[key.toString()] = text;
        }
        continue;
      }
      final fileName = _resourceFileName(resource);
      final stagedFile = File(p.join(stagingDir.path, fileName));
      _extractVerified(entries[path]!, resource, destFile: stagedFile);
      staged.add(stagedFile);
      final destPath = p.join(resourceDestDir, fileName);
      final uri = SandboxPathResolver.canonicalize(destPath);
      for (final key in resource['originalStorageKeys'] as List) {
        keyToUri[key.toString()] = uri;
      }
    }

    final root = <String, dynamic>{'__exported_at': manifest['exportedAt']};

    final data = _asStringMap(manifest['data']);
    final settingsDesc = data['settings'];
    if (settingsDesc is Map) {
      final settingsMap = _asStringMap(settingsDesc);
      final settingsPath = (settingsMap['path'] ?? _settingsPath).toString();
      root['settings'] = _decodeJsonObject(
        _extractVerified(
          entries[settingsPath]!,
          settingsMap,
          collectBytes: true,
        ).bytes!,
        settingsPath,
      );
    }

    final copilotsDesc = data['copilots'];
    if (copilotsDesc is Map) {
      final copilotsMap = _asStringMap(copilotsDesc);
      final copilotsPath = (copilotsMap['path'] ?? _copilotsPath).toString();
      final copilots = _decodeJsonArray(
        _extractVerified(
          entries[copilotsPath]!,
          copilotsMap,
          collectBytes: true,
        ).bytes!,
        copilotsPath,
      );
      root['myCopilots'] = [
        for (final item in copilots)
          if (item is Map)
            _rewriteCopilot(_asStringMap(item), keyToUri)
          else
            item,
      ];
    }

    final sessionSettingsDesc = data['sessionSettings'];
    if (sessionSettingsDesc is Map) {
      _extractVerified(
        entries[_asStringMap(sessionSettingsDesc)['path'] as String]!,
        _asStringMap(sessionSettingsDesc),
      );
    }

    final sessionList = <Map<String, dynamic>>[];
    final sessions = manifest['sessions'] as List;
    for (final raw in sessions) {
      final descriptor = _asStringMap(raw);
      final sessionPath = descriptor['path'] as String;
      final sessionId = descriptor['id'] as String;
      final parsed = _decodeJsonObject(
        _extractVerified(
          entries[sessionPath]!,
          descriptor,
          collectBytes: true,
        ).bytes!,
        sessionPath,
      );
      if (!_isBackupSession(parsed)) {
        throw ChatboxImportException('Invalid session entry: $sessionPath');
      }
      if ((parsed['id'] ?? '').toString() != sessionId) {
        throw ChatboxImportException(
          'Session id does not match manifest: $sessionPath',
        );
      }
      final rewritten = _rewriteSession(parsed, keyToUri, keyToText);
      root['session:$sessionId'] = rewritten;
      sessionList.add(_sessionMetaForList(descriptor, rewritten, keyToUri));
    }
    root['chat-sessions-list'] = sessionList;
    return ChatboxBackupReadResult(
      root: root,
      stagedResourceFiles: staged,
      resourceDestDir: resourceDestDir,
    );
  }

  static Future<void> publishStagedResources(
    ChatboxBackupReadResult result,
  ) async {
    if (result.stagedResourceFiles.isEmpty) return;
    final destDir = Directory(result.resourceDestDir);
    await destDir.create(recursive: true);
    for (final staged in result.stagedResourceFiles) {
      final dest = File(p.join(destDir.path, p.basename(staged.path)));
      if (!p.isWithin(p.normalize(destDir.path), p.normalize(dest.path))) {
        throw ChatboxImportException(
          'Refusing to write resource outside the destination directory.',
        );
      }
      await _publishStagedFile(staged, dest);
    }
  }

  static Future<void> _publishStagedFile(File staged, File dest) async {
    if (await dest.exists() && await _sameFileContent(dest, staged)) {
      return;
    }
    final tmp = File('${dest.path}.part');
    try {
      if (await tmp.exists()) await tmp.delete();
      await staged.copy(tmp.path);
      if (await dest.exists()) await dest.delete();
      await tmp.rename(dest.path);
    } catch (e) {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      if (e is ChatboxImportException) rethrow;
      throw ChatboxImportException('Unable to publish backup resource: $e');
    }
  }

  static Future<bool> _sameFileContent(File a, File b) async {
    if (await a.length() != await b.length()) return false;
    return await _fileSha256(a) == await _fileSha256(b);
  }

  static Future<Digest> _fileSha256(File file) async {
    final collector = _DigestSink();
    final hasher = sha256.startChunkedConversion(collector);
    await for (final chunk in file.openRead()) {
      hasher.add(chunk);
    }
    hasher.close();
    return collector.digest!;
  }

  static Map<String, dynamic> _parseManifest(Uint8List bytes) {
    final decoded = _decodeJsonValue(bytes, _manifestPath);
    if (decoded is! Map) {
      throw const ChatboxImportException(
        'Not a Chatbox backup archive (manifest.json is not an object).',
      );
    }
    final manifest = _asStringMap(decoded);
    final format = (manifest['format'] ?? '').toString();
    if (format != backupFormat) {
      throw const ChatboxImportException(
        'Not a Chatbox backup archive (format is not "chatbox-backup").',
      );
    }
    final version = manifest['formatVersion'];
    if (version != backupFormatVersion) {
      throw ChatboxImportException(
        'Unsupported Chatbox backup formatVersion: $version. '
        'Only formatVersion $backupFormatVersion is supported.',
      );
    }

    final exportedAt = (manifest['exportedAt'] ?? '').toString().trim();
    if (exportedAt.isEmpty) {
      throw const ChatboxImportException(
        'Invalid Chatbox backup manifest (missing exportedAt).',
      );
    }

    final application = manifest['application'];
    if (application is! Map ||
        (application['name'] ?? '').toString() != 'Chatbox' ||
        (application['version'] ?? '').toString().isEmpty ||
        (application['platform'] ?? '').toString().isEmpty) {
      throw const ChatboxImportException(
        'Invalid Chatbox backup manifest (application).',
      );
    }

    final exportItems = manifest['exportItems'];
    if (exportItems is! List) {
      throw const ChatboxImportException(
        'Invalid Chatbox backup manifest (exportItems).',
      );
    }
    for (final item in exportItems) {
      if (!_exportItems.contains(item.toString())) {
        throw ChatboxImportException(
          'Invalid Chatbox backup export item: $item',
        );
      }
    }

    final data = manifest['data'];
    if (data is! Map) {
      throw const ChatboxImportException(
        'Invalid Chatbox backup manifest (data).',
      );
    }
    final dataMap = _asStringMap(data);
    for (final key in const ['settings', 'copilots', 'sessionSettings']) {
      final value = dataMap[key];
      if (value != null) _requireJsonDescriptor(value, 'data.$key');
    }

    final sessions = manifest['sessions'];
    if (sessions is! List) {
      throw const ChatboxImportException(
        'Invalid Chatbox backup manifest (sessions).',
      );
    }
    if (sessions.length > maxSessions) {
      throw const ChatboxImportException('Backup contains too many sessions.');
    }
    for (final session in sessions) {
      _requireSessionDescriptor(session);
    }

    final resources = manifest['resources'];
    if (resources is! List) {
      throw const ChatboxImportException(
        'Invalid Chatbox backup manifest (resources).',
      );
    }
    if (resources.length > maxResources) {
      throw const ChatboxImportException('Backup contains too many resources.');
    }
    for (final resource in resources) {
      _requireResourceDescriptor(resource);
    }

    final warnings = manifest['warnings'];
    if (warnings is! List) {
      throw const ChatboxImportException(
        'Invalid Chatbox backup manifest (warnings).',
      );
    }

    final stats = manifest['stats'];
    if (stats is! Map) {
      throw const ChatboxImportException(
        'Invalid Chatbox backup manifest (stats).',
      );
    }
    final statsMap = _asStringMap(stats);
    if (_asNonNegInt(statsMap['sessionCount']) != sessions.length ||
        _asNonNegInt(statsMap['resourceCount']) != resources.length ||
        _asNonNegInt(statsMap['warningCount']) != warnings.length ||
        _asNonNegInt(statsMap['deduplicatedResourceCount']) == null) {
      throw const ChatboxImportException(
        'Backup manifest statistics do not match its entries.',
      );
    }

    _validateManifestGraph(manifest);
    return manifest;
  }

  static void _validateManifestMembership(
    Map<String, dynamic> manifest,
    Map<String, ArchiveFile> entries,
  ) {
    final expected = <String>{_manifestPath};
    void addDescriptor(Object? raw, {required bool requiredId}) {
      if (raw is! Map) return;
      final descriptor = _asStringMap(raw);
      final path = descriptor['path'] as String;
      if (!expected.add(path)) {
        throw ChatboxImportException(
          'Manifest contains a duplicate path: $path',
        );
      }
      if (!entries.containsKey(path)) {
        throw ChatboxImportException('Backup entry is missing: $path');
      }
      if (requiredId && (descriptor['id'] ?? '').toString().isEmpty) {
        throw ChatboxImportException('Backup entry is missing an id: $path');
      }
    }

    final data = _asStringMap(manifest['data']);
    addDescriptor(data['settings'], requiredId: false);
    addDescriptor(data['copilots'], requiredId: false);
    addDescriptor(data['sessionSettings'], requiredId: false);
    for (final session in manifest['sessions'] as List) {
      addDescriptor(session, requiredId: true);
    }
    for (final resource in manifest['resources'] as List) {
      addDescriptor(resource, requiredId: true);
    }

    for (final path in entries.keys) {
      if (!expected.contains(path)) {
        throw ChatboxImportException(
          'Backup contains an entry not listed in manifest: $path',
        );
      }
    }
    if (expected.length != entries.length) {
      throw const ChatboxImportException(
        'Backup manifest entry list is incomplete.',
      );
    }
  }

  static int _compressedLength(ArchiveFile entry) {
    final raw = entry.rawContent;
    if (raw == null) return 0;
    // ZipFile.length calls getRawContent()/toUint8List() and would load the
    // whole compressed entry. Prefer the central-directory size, then the
    // undecoded stream length (InputFileStream.length is remaining bytes).
    if (raw is ZipFile && raw.compressedSize > 0) {
      return raw.compressedSize;
    }
    if (raw.isCompressed) {
      return raw.getStream(decompress: false).length;
    }
    return entry.size;
  }

  static bool isUnsafeCompressionRatio(int uncompressed, int compressed) {
    return compressed > 0 && uncompressed > compressed * maxCompressionRatio;
  }

  /// Inflates raw DEFLATE bytes, forwarding each decoder chunk immediately.
  /// Used by tests and [_copyEntryToSink]; does not go through archive 4.x
  /// `ZLibDecoder.decodeStream`, which buffers the full output first.
  static int inflateDeflateBounded(
    List<int> compressed, {
    required int maxBytes,
  }) {
    final sink = _BoundedInflateSink(path: 'deflate', maxBytes: maxBytes);
    try {
      inflateZipDeflateStreaming(InputMemoryStream(compressed), sink);
      return sink.finish().size;
    } catch (e) {
      sink.abort();
      rethrow;
    }
  }

  static void _copyEntryToSink(ArchiveFile entry, _BoundedInflateSink sink) {
    final raw = entry.rawContent;
    if (raw != null &&
        (entry.compression == CompressionType.deflate ||
            (raw.isCompressed && entry.compression != CompressionType.bzip2))) {
      inflateZipDeflateStreaming(raw.getStream(decompress: false), sink);
      return;
    }
    if (raw != null) {
      sink.writeStream(raw.getStream(decompress: false));
      return;
    }
    writeZipEntryStreaming(entry, sink);
  }

  static void _assertEntryBudget({
    required String path,
    required int uncompressed,
    required int compressed,
  }) {
    final limit = _isBackupJsonPath(path)
        ? maxJsonEntryBytes
        : maxResourceEntryBytes;
    if (uncompressed > limit) {
      throw ChatboxImportException('Backup entry is too large: $path');
    }
    if (isUnsafeCompressionRatio(uncompressed, compressed)) {
      throw ChatboxImportException(
        'Backup entry compression ratio is too high: $path',
      );
    }
  }

  static _ExtractedEntry _extractVerified(
    ArchiveFile entry,
    Map<String, dynamic> descriptor, {
    File? destFile,
    bool collectBytes = false,
    bool verifyChecksum = true,
  }) {
    final path = (descriptor['path'] ?? entry.name).toString();
    final expectedSize = descriptor['size'];
    if (expectedSize is int && entry.size != expectedSize) {
      throw ChatboxImportException('Backup entry size mismatch: $path');
    }
    final limit = _isBackupJsonPath(path)
        ? maxJsonEntryBytes
        : maxResourceEntryBytes;
    final expected = expectedSize is int ? expectedSize : null;
    final sink = _BoundedInflateSink(
      path: path,
      maxBytes: expected != null && expected < limit ? expected : limit,
      expectedBytes: expected,
      filePath: destFile?.path,
      collectBytes: collectBytes,
    );
    try {
      _copyEntryToSink(entry, sink);
      final extracted = sink.finish();
      if (expected != null && extracted.size != expected) {
        throw ChatboxImportException('Backup entry size mismatch: $path');
      }
      if (verifyChecksum) {
        final checksumRaw = descriptor['checksum'];
        if (checksumRaw is! Map) {
          throw ChatboxImportException('Backup entry checksum mismatch: $path');
        }
        final checksum = _asStringMap(checksumRaw);
        if (extracted.sha256 != checksum['value']) {
          throw ChatboxImportException('Backup entry checksum mismatch: $path');
        }
      }
      return extracted;
    } catch (e) {
      sink.abort();
      if (e is ChatboxImportException) rethrow;
      throw ChatboxImportException('Unable to read backup entry: $path');
    } finally {
      entry.clear();
    }
  }

  static void _validateManifestGraph(Map<String, dynamic> manifest) {
    final sessionIds = <String>{};
    final sessions = manifest['sessions'] as List;
    for (final raw in sessions) {
      final session = _asStringMap(raw);
      final id = session['id'] as String;
      if (!sessionIds.add(id)) {
        throw ChatboxImportException('Duplicate session id in manifest: $id');
      }
      final meta = session['meta'];
      if (meta is Map && (meta['id'] ?? '').toString() != id) {
        throw ChatboxImportException('Session metadata id does not match: $id');
      }
    }

    final resourceIds = <String>{};
    final resourceKeys = <String>{};
    final resources = <String, Map<String, dynamic>>{};
    for (final raw in manifest['resources'] as List) {
      final resource = _asStringMap(raw);
      final id = resource['id'] as String;
      if (!resourceIds.add(id)) {
        throw ChatboxImportException('Duplicate resource id in manifest: $id');
      }
      resources[id] = resource;
      final ownKeys = <String>{};
      for (final key in resource['originalStorageKeys'] as List) {
        final storageKey = key.toString();
        if (!ownKeys.add(storageKey)) {
          throw ChatboxImportException(
            'Resource contains a duplicate storage key: $id',
          );
        }
        if (!resourceKeys.add(storageKey)) {
          throw ChatboxImportException(
            'Duplicate resource storage key in manifest: $storageKey',
          );
        }
      }
      final ownSessionIds = <String>{};
      for (final sessionId in resource['sessionIds'] as List) {
        final sid = sessionId.toString();
        if (!ownSessionIds.add(sid)) {
          throw ChatboxImportException(
            'Resource contains a duplicate session id: $id',
          );
        }
        if (!sessionIds.contains(sid)) {
          throw ChatboxImportException(
            'Resource references an unknown session: $sid',
          );
        }
      }
      final scope = resource['scope'] as String;
      if (scope == 'session' && ownSessionIds.length != 1) {
        throw ChatboxImportException(
          'Session-scoped resource must reference exactly one session: $id',
        );
      }
      if (scope == 'global' && ownSessionIds.isNotEmpty) {
        throw ChatboxImportException(
          'Global resource must not reference a session: $id',
        );
      }
    }

    final sessionsById = <String, Map<String, dynamic>>{
      for (final raw in sessions)
        _asStringMap(raw)['id'] as String: _asStringMap(raw),
    };
    for (final session in sessionsById.values) {
      final id = session['id'] as String;
      final ownResourceIds = <String>{};
      for (final resourceId in session['resourceIds'] as List) {
        final rid = resourceId.toString();
        if (!ownResourceIds.add(rid)) {
          throw ChatboxImportException(
            'Session contains a duplicate resource id: $id',
          );
        }
        final resource = resources[rid];
        if (resource == null) {
          throw ChatboxImportException(
            'Session references an unknown resource: $rid',
          );
        }
        final mapped = (resource['sessionIds'] as List)
            .map((value) => value.toString())
            .contains(id);
        if (!mapped) {
          throw ChatboxImportException(
            'Session/resource mapping is inconsistent: $id/$rid',
          );
        }
      }
    }
    for (final resource in resources.values) {
      final id = resource['id'] as String;
      for (final sessionId in resource['sessionIds'] as List) {
        final sid = sessionId.toString();
        final session = sessionsById[sid];
        final mapped =
            session != null &&
            (session['resourceIds'] as List)
                .map((value) => value.toString())
                .contains(id);
        if (!mapped) {
          throw ChatboxImportException(
            'Resource/session mapping is inconsistent: $id/$sid',
          );
        }
      }
    }
  }

  static void _requireJsonDescriptor(Object raw, String label) {
    if (raw is! Map) {
      throw ChatboxImportException('Invalid Chatbox backup manifest ($label).');
    }
    _requireChecksumPath(raw, label);
  }

  static void _requireSessionDescriptor(Object raw) {
    if (raw is! Map) {
      throw const ChatboxImportException(
        'Invalid Chatbox backup manifest (session).',
      );
    }
    final session = _asStringMap(raw);
    _requireChecksumPath(session, 'session');
    final id = (session['id'] ?? '').toString();
    if (id.isEmpty) {
      throw const ChatboxImportException(
        'Invalid Chatbox backup manifest (session.id).',
      );
    }
    if (session['meta'] is! Map) {
      throw const ChatboxImportException(
        'Invalid Chatbox backup manifest (session.meta).',
      );
    }
    final resourceIds = session['resourceIds'];
    if (resourceIds is! List || resourceIds.length > maxResources) {
      throw const ChatboxImportException(
        'Invalid Chatbox backup manifest (session.resourceIds).',
      );
    }
  }

  static void _requireResourceDescriptor(Object raw) {
    if (raw is! Map) {
      throw const ChatboxImportException(
        'Invalid Chatbox backup manifest (resource).',
      );
    }
    final resource = _asStringMap(raw);
    _requireChecksumPath(resource, 'resource');
    if ((resource['id'] ?? '').toString().isEmpty) {
      throw const ChatboxImportException(
        'Invalid Chatbox backup manifest (resource.id).',
      );
    }
    final keys = resource['originalStorageKeys'];
    if (keys is! List || keys.isEmpty || keys.length > maxResources) {
      throw const ChatboxImportException(
        'Invalid Chatbox backup manifest (resource.originalStorageKeys).',
      );
    }
    final sessionIds = resource['sessionIds'];
    if (sessionIds is! List || sessionIds.length > maxSessions) {
      throw const ChatboxImportException(
        'Invalid Chatbox backup manifest (resource.sessionIds).',
      );
    }
    if (!_resourceScopes.contains((resource['scope'] ?? '').toString()) ||
        !_resourceEncodings.contains((resource['encoding'] ?? '').toString()) ||
        (resource['mimeType'] ?? '').toString().isEmpty ||
        !_resourceKinds.contains((resource['kind'] ?? '').toString())) {
      throw const ChatboxImportException(
        'Invalid Chatbox backup manifest (resource metadata).',
      );
    }
  }

  static void _requireChecksumPath(Map raw, String label) {
    final path = (raw['path'] ?? '').toString();
    if (path.isEmpty || path.length > 4096) {
      throw ChatboxImportException(
        'Invalid Chatbox backup manifest ($label.path).',
      );
    }
    _assertSafeArchivePath(path);
    final size = raw['size'];
    if (size is! int || size < 0) {
      throw ChatboxImportException(
        'Invalid Chatbox backup manifest ($label.size).',
      );
    }
    final checksum = raw['checksum'];
    if (checksum is! Map ||
        (checksum['algorithm'] ?? '').toString() != 'sha256' ||
        !_sha256Hex.hasMatch((checksum['value'] ?? '').toString())) {
      throw ChatboxImportException(
        'Invalid Chatbox backup manifest ($label.checksum).',
      );
    }
  }

  static String _normalizedArchivePath(String raw) {
    if (raw.contains('\u0000')) {
      throw ChatboxImportException('Unsafe ZIP entry path: $raw');
    }
    final path = raw.replaceAll('\\', '/');
    _assertSafeArchivePath(path);
    return path;
  }

  static void _assertSafeArchivePath(String path) {
    if (path.isEmpty) {
      throw const ChatboxImportException('Unsafe ZIP entry path: (empty)');
    }
    if (path.contains('\\') ||
        path.startsWith('/') ||
        _windowsDrive.hasMatch(path)) {
      throw ChatboxImportException('Unsafe ZIP entry path: $path');
    }
    final segments = path.split('/');
    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      throw ChatboxImportException('Unsafe ZIP entry path: $path');
    }
  }

  static bool _isBackupSessionPath(String path) {
    return RegExp(r'^sessions/[^/]+/session\.json$').hasMatch(path);
  }

  static bool _isBackupJsonPath(String path) {
    return path == _manifestPath ||
        path == _settingsPath ||
        path == _copilotsPath ||
        path == _sessionSettingsPath ||
        _isBackupSessionPath(path);
  }

  static bool _isBackupSession(Map<String, dynamic> value) {
    final id = value['id'];
    final name = value['name'];
    return id is String &&
        id.isNotEmpty &&
        name is String &&
        value['messages'] is List;
  }

  static Map<String, dynamic> _rewriteSession(
    Map<String, dynamic> session,
    Map<String, String> keyToUri,
    Map<String, String> keyToText,
  ) {
    _rewriteMessages(session['messages'], keyToUri, keyToText);
    final threads = session['threads'];
    if (threads is List) {
      for (final thread in threads) {
        if (thread is Map) {
          _rewriteMessages(thread['messages'], keyToUri, keyToText);
        }
      }
    }
    final forks = session['messageForksHash'];
    if (forks is Map) {
      for (final fork in forks.values) {
        if (fork is! Map) continue;
        final lists = fork['lists'];
        if (lists is! List) continue;
        for (final list in lists) {
          if (list is Map) {
            _rewriteMessages(list['messages'], keyToUri, keyToText);
          }
        }
      }
    }
    _rewriteStorageKeyedField(session, 'assistantAvatarKey', keyToUri);
    _rewriteImageSourceField(session, 'backgroundImage', keyToUri);
    final avatarKey = (session['assistantAvatarKey'] ?? '').toString();
    if (avatarKey.isNotEmpty && keyToUri.containsKey(avatarKey)) {
      session['picUrl'] = keyToUri[avatarKey];
    }
    return session;
  }

  static Map<String, dynamic> _rewriteCopilot(
    Map<String, dynamic> copilot,
    Map<String, String> keyToUri,
  ) {
    _rewriteImageSourceField(copilot, 'avatar', keyToUri);
    _rewriteImageSourceField(copilot, 'backgroundImage', keyToUri);
    final screenshots = copilot['screenshots'];
    if (screenshots is List) {
      final next = <dynamic>[];
      for (final item in screenshots) {
        if (item is! Map) {
          next.add(item);
          continue;
        }
        final rewritten = _rewrittenImageSource(_asStringMap(item), keyToUri);
        if (rewritten != null) next.add(rewritten);
      }
      copilot['screenshots'] = next;
    }
    final avatar = copilot['avatar'];
    if (avatar is Map && (avatar['type'] ?? '') == 'url') {
      final url = (avatar['url'] ?? '').toString();
      if (url.isNotEmpty) copilot['picUrl'] = url;
    }
    return copilot;
  }

  static void _rewriteMessages(
    Object? raw,
    Map<String, String> keyToUri,
    Map<String, String> keyToText,
  ) {
    if (raw is! List) return;
    for (final item in raw) {
      if (item is! Map) continue;
      final message = item;
      final parts = message['contentParts'];
      if (parts is List) {
        message['contentParts'] = [
          for (final part in parts)
            if (part is Map)
              ..._rewriteContentPart(_asStringMap(part), keyToUri, keyToText)
            else
              part,
        ];
      }
      final files = message['files'];
      if (files is List) {
        for (final file in files) {
          if (file is! Map) continue;
          file.remove('localPath');
          _applyFileStorageKey(file, 'rawStorageKey', keyToUri);
          _applyFileStorageKey(file, 'storageKey', keyToUri);
        }
      }
      final pictures = message['pictures'];
      if (pictures is List) {
        message['pictures'] = [
          for (final picture in pictures)
            if (picture is Map)
              ..._rewritePicture(_asStringMap(picture), keyToUri)
            else
              picture,
        ];
      }
      final links = message['links'];
      if (links is List) {
        for (final link in links) {
          if (link is! Map) continue;
          final key = (link['storageKey'] ?? '').toString();
          if (key.isEmpty) continue;
          if (!keyToUri.containsKey(key)) {
            link.remove('storageKey');
          }
        }
      }
    }
  }

  static List<Map<String, dynamic>> _rewriteContentPart(
    Map<String, dynamic> part,
    Map<String, String> keyToUri,
    Map<String, String> keyToText,
  ) {
    final type = (part['type'] ?? '').toString();
    if (type == 'image') {
      final key = (part['storageKey'] ?? '').toString();
      if (key.isEmpty) {
        return (part['url'] ?? '').toString().trim().isEmpty
            ? const <Map<String, dynamic>>[]
            : [part];
      }
      final uri = keyToUri[key];
      if (uri == null) return const <Map<String, dynamic>>[];
      part['url'] = uri;
      return [part];
    }
    if (type == 'tool-call') {
      final key = (part['resultStorageKey'] ?? '').toString();
      if (key.isEmpty) return [part];
      final text = keyToText[key];
      part.remove('resultStorageKey');
      if (text != null) part['result'] = text;
    }
    return [part];
  }

  static List<Map<String, dynamic>> _rewritePicture(
    Map<String, dynamic> picture,
    Map<String, String> keyToUri,
  ) {
    final key = (picture['storageKey'] ?? '').toString();
    if (key.isEmpty) {
      return (picture['url'] ?? '').toString().trim().isEmpty
          ? const <Map<String, dynamic>>[]
          : [picture];
    }
    final uri = keyToUri[key];
    if (uri == null) {
      picture.remove('storageKey');
      return (picture['url'] ?? '').toString().trim().isEmpty
          ? const <Map<String, dynamic>>[]
          : [picture];
    }
    picture['url'] = uri;
    return [picture];
  }

  static void _applyFileStorageKey(
    Map file,
    String field,
    Map<String, String> keyToUri,
  ) {
    final key = (file[field] ?? '').toString();
    if (key.isEmpty) return;
    final uri = keyToUri[key];
    if (uri == null) {
      file.remove(field);
      return;
    }
    if ((file['url'] ?? '').toString().trim().isEmpty) {
      file['url'] = uri;
    }
  }

  static void _rewriteStorageKeyedField(
    Map<String, dynamic> object,
    String field,
    Map<String, String> keyToUri,
  ) {
    final key = (object[field] ?? '').toString();
    if (key.isEmpty) return;
    if (!keyToUri.containsKey(key)) {
      object.remove(field);
    }
  }

  static void _rewriteImageSourceField(
    Map<String, dynamic> parent,
    String field,
    Map<String, String> keyToUri,
  ) {
    final value = parent[field];
    if (value is! Map) return;
    final rewritten = _rewrittenImageSource(_asStringMap(value), keyToUri);
    if (rewritten == null) {
      parent.remove(field);
    } else {
      parent[field] = rewritten;
    }
  }

  static Map<String, dynamic>? _rewrittenImageSource(
    Map<String, dynamic> source,
    Map<String, String> keyToUri,
  ) {
    if ((source['type'] ?? '').toString() != 'storage-key') return source;
    final key = (source['storageKey'] ?? '').toString();
    final uri = keyToUri[key];
    if (uri == null) return null;
    return <String, dynamic>{'type': 'url', 'url': uri};
  }

  static Map<String, dynamic> _sessionMetaForList(
    Map<String, dynamic> descriptor,
    Map<String, dynamic> session,
    Map<String, String> keyToUri,
  ) {
    final metaRaw = descriptor['meta'];
    final meta = metaRaw is Map
        ? _asStringMap(metaRaw)
        : <String, dynamic>{'id': descriptor['id'], 'name': session['name']};
    final avatarKey = (meta['assistantAvatarKey'] ?? '').toString();
    if (avatarKey.isNotEmpty && keyToUri.containsKey(avatarKey)) {
      meta['picUrl'] = keyToUri[avatarKey];
    } else {
      final sessionPic = (session['picUrl'] ?? '').toString().trim();
      if (sessionPic.isNotEmpty &&
          (meta['picUrl'] ?? '').toString().trim().isEmpty) {
        meta['picUrl'] = sessionPic;
      }
    }
    return meta;
  }

  static String _resourceFileName(Map<String, dynamic> resource) {
    final id = _safeToken(
      (resource['id'] ?? 'resource').toString(),
      'resource',
    );
    final checksumRaw = resource['checksum'];
    final digest = checksumRaw is Map
        ? _safeToken((checksumRaw['value'] ?? '').toString(), id)
        : id;
    final path = (resource['path'] ?? '').toString();
    var ext = p.extension(path);
    if (ext.isEmpty) {
      ext = _extensionForMime((resource['mimeType'] ?? '').toString());
    }
    if (ext.isNotEmpty && !ext.startsWith('.')) ext = '.$ext';
    final filename = (resource['filename'] ?? '').toString();
    final fromName = filename.isEmpty ? '' : p.extension(filename);
    if (ext.isEmpty && fromName.isNotEmpty) ext = fromName;
    return '$id-$digest$ext';
  }

  static String _safeToken(String raw, String fallback) {
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return fallback;
    return cleaned;
  }

  static String _extensionForMime(String mime) {
    switch (mime.toLowerCase()) {
      case 'image/png':
        return '.png';
      case 'image/jpeg':
      case 'image/jpg':
        return '.jpg';
      case 'image/gif':
        return '.gif';
      case 'image/webp':
        return '.webp';
      case 'image/svg+xml':
        return '.svg';
      case 'application/pdf':
        return '.pdf';
      case 'text/plain':
        return '.txt';
      case 'application/json':
        return '.json';
      default:
        return '';
    }
  }

  static Map<String, dynamic> _decodeJsonObject(Uint8List bytes, String path) {
    final decoded = _decodeJsonValue(bytes, path);
    if (decoded is! Map) {
      throw ChatboxImportException('Invalid JSON object entry: $path');
    }
    return _asStringMap(decoded);
  }

  static List<dynamic> _decodeJsonArray(Uint8List bytes, String path) {
    final decoded = _decodeJsonValue(bytes, path);
    if (decoded is! List) {
      throw ChatboxImportException('Invalid JSON array entry: $path');
    }
    return decoded;
  }

  static Object? _decodeJsonValue(Uint8List bytes, String path) {
    if (bytes.length > maxJsonEntryBytes) {
      throw ChatboxImportException('Backup JSON entry is too large: $path');
    }
    try {
      return jsonDecode(utf8.decode(bytes, allowMalformed: false));
    } catch (_) {
      throw ChatboxImportException('Invalid JSON in backup entry: $path');
    }
  }

  static Map<String, dynamic> _asStringMap(Map raw) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  static int? _asNonNegInt(Object? raw) {
    if (raw is int && raw >= 0) return raw;
    return null;
  }
}

class _ExtractedEntry {
  const _ExtractedEntry({required this.size, required this.sha256, this.bytes});

  final int size;
  final String sha256;
  final Uint8List? bytes;
}

class _DigestSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}

class _BoundedInflateSink extends OutputStream {
  _BoundedInflateSink({
    required this.path,
    required this.maxBytes,
    this.expectedBytes,
    this.filePath,
    this.collectBytes = false,
  }) : _file = filePath == null ? null : OutputFileStream(filePath),
       _builder = collectBytes ? BytesBuilder(copy: false) : null,
       super(byteOrder: ByteOrder.littleEndian);

  final String path;
  final int maxBytes;
  final int? expectedBytes;
  final String? filePath;
  final bool collectBytes;
  final OutputFileStream? _file;
  final BytesBuilder? _builder;
  final _DigestSink _digestSink = _DigestSink();
  late final ByteConversionSink _hasher = sha256.startChunkedConversion(
    _digestSink,
  );
  int _written = 0;
  bool _closed = false;

  @override
  int get length => _written;

  void _accept(List<int> bytes, int length) {
    if (length <= 0) return;
    if (_written + length > maxBytes) {
      throw ChatboxImportException('Backup entry is too large: $path');
    }
    if (expectedBytes != null && _written + length > expectedBytes!) {
      throw ChatboxImportException('Backup entry size mismatch: $path');
    }
    final slice = length == bytes.length ? bytes : bytes.sublist(0, length);
    _written += length;
    _hasher.add(slice);
    _file?.writeBytes(slice);
    _builder?.add(slice);
  }

  @override
  void writeByte(int value) {
    _accept(<int>[value], 1);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final writeLength = length ?? bytes.length;
    if (writeLength < 0 || writeLength > bytes.length) {
      throw RangeError.range(writeLength, 0, bytes.length, 'length');
    }
    _accept(bytes, writeLength);
  }

  @override
  void writeStream(InputStream stream) {
    const chunkSize = 64 * 1024;
    while (!stream.isEOS) {
      final remaining = stream.length;
      final readSize = remaining < chunkSize ? remaining : chunkSize;
      if (readSize <= 0) break;
      final bytes = stream.readBytes(readSize).toUint8List();
      if (bytes.isEmpty) break;
      writeBytes(bytes);
    }
  }

  @override
  void flush() {
    _file?.flush();
  }

  @override
  void clear() {
    _builder?.clear();
  }

  @override
  Uint8List subset(int start, [int? end]) {
    final bytes = _builder?.toBytes() ?? Uint8List(0);
    return bytes.sublist(start, end ?? bytes.length);
  }

  _ExtractedEntry finish() {
    _closeIo(propagate: true);
    return _ExtractedEntry(
      size: _written,
      sha256: _digestSink.digest!.toString(),
      bytes: _builder?.takeBytes(),
    );
  }

  void abort() {
    _closeIo(propagate: false);
    final path = filePath;
    if (path == null) return;
    try {
      final leftover = File(path);
      if (leftover.existsSync()) leftover.deleteSync();
    } catch (_) {}
  }

  void _closeIo({required bool propagate}) {
    if (_closed) return;
    _closed = true;
    Object? error;
    StackTrace? stack;
    void capture(Object e, StackTrace st) {
      error ??= e;
      stack ??= st;
    }

    try {
      _file?.flush();
    } catch (e, st) {
      capture(e, st);
    }
    try {
      _hasher.close();
    } catch (e, st) {
      capture(e, st);
    }
    try {
      _file?.closeSync();
    } catch (e, st) {
      capture(e, st);
    }
    final thrown = error;
    final thrownStack = stack;
    if (propagate && thrown != null) {
      Error.throwWithStackTrace(thrown, thrownStack!);
    }
  }
}
