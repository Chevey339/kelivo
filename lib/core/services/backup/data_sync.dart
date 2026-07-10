import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../../database/chat_database_repository.dart';
import '../../models/backup.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../chat/chat_service.dart';
import '../../../utils/app_directories.dart';

typedef _ParsedChatBackup = ({
  List<Conversation> conversations,
  List<ChatMessage> messages,
  Map<String, List<Map<String, dynamic>>> toolEvents,
  Map<String, String> geminiThoughtSigs,
});

class DataSync {
  final ChatService chatService;
  DataSync({required this.chatService});

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

    File? settingsTmp;
    File? chatsTmp;
    try {
      // --- Step 1: Prepare temp files that need ChatService (main isolate) ---
      // settings.json
      final settingsJson = await _exportSettingsJson();
      settingsTmp = await _writeTempText(
        workDir,
        '_bk_settings.json',
        settingsJson,
      );

      // chats.json — stream to file to avoid huge string in memory
      if (cfg.includeChats) {
        chatsTmp = await _exportChatsToFile(workDir);
      }

      // Resolve directory paths (need AppDirectories on main isolate)
      final uploadDirPath = (await _getUploadDir()).path;
      final avatarsDirPath = (await _getAvatarsDir()).path;
      final imagesDirPath = (await _getImagesDir()).path;
      final fontsDirPath = (await _getFontsDir()).path;
      final settingsPath = settingsTmp.path;
      final chatsPath = chatsTmp?.path;
      final includeFiles = cfg.includeFiles;

      // --- Step 2: Run CPU-heavy ZIP packing in a separate isolate ---
      await Isolate.run(() {
        _packZipSync(
          outPath: outPath,
          settingsPath: settingsPath,
          chatsPath: chatsPath,
          includeFiles: includeFiles,
          uploadDirPath: uploadDirPath,
          avatarsDirPath: avatarsDirPath,
          imagesDirPath: imagesDirPath,
          fontsDirPath: fontsDirPath,
        );
      });

      return outFile;
    } catch (_) {
      await _deleteDirectoryQuietly(workDir);
      rethrow;
    } finally {
      // Cleanup temp intermediate files. The final zip is returned to callers
      // and must be deleted by the upload/export caller after it is consumed.
      await _deleteFileQuietly(settingsTmp);
      await _deleteFileQuietly(chatsTmp);
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
                name == '_bk_chats.json')) {
          await _deleteFileQuietly(ent);
        }
      }
    } catch (_) {}
  }

  /// Synchronous ZIP packing — runs inside an Isolate.
  static void _packZipSync({
    required String outPath,
    required String settingsPath,
    String? chatsPath,
    required bool includeFiles,
    required String uploadDirPath,
    required String avatarsDirPath,
    required String imagesDirPath,
    required String fontsDirPath,
  }) {
    final writer = _StreamingZipWriter(outPath);
    try {
      // settings.json
      _addFileToZip(writer, settingsPath, 'settings.json');

      // chats.json
      if (chatsPath != null) {
        _addFileToZip(writer, chatsPath, 'chats.json');
      }

      // files under upload/, images/, and avatars/
      if (includeFiles) {
        _addDirectoryToZip(writer, uploadDirPath, 'upload');
        _addDirectoryToZip(writer, avatarsDirPath, 'avatars');
        _addDirectoryToZip(writer, imagesDirPath, 'images');
        _addDirectoryToZip(writer, fontsDirPath, 'fonts');
      }

      writer.closeSync();
    } finally {
      writer.closeIfNeededSync();
    }
  }

  static void _addFileToZip(
    _StreamingZipWriter writer,
    String filePath,
    String entryName,
  ) {
    final file = File(filePath);
    if (!file.existsSync()) return;
    writer.addFile(file, _zipEntryName(entryName));
  }

  /// Add all files from [srcDirPath] into the zip under [zipPrefix].
  static void _addDirectoryToZip(
    _StreamingZipWriter writer,
    String srcDirPath,
    String zipPrefix,
  ) {
    final dir = Directory(srcDirPath);
    if (!dir.existsSync()) return;
    final entries = dir.listSync(recursive: true, followLinks: false);
    for (final ent in entries) {
      if (ent is File) {
        final rel = p.relative(ent.path, from: srcDirPath);
        // ZIP entries must use forward slashes regardless of platform
        final relPosix = rel.replaceAll('\\', '/');
        _addFileToZip(writer, ent.path, '$zipPrefix/$relPosix');
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
      final archive = ZipDecoder().decodeStream(inputStream);
      try {
        for (final entry in archive) {
          // Normalize entry name to use forward slashes and remove traversal
          final normalized = entry.name.replaceAll('\\', '/');
          final parts = normalized
              .split('/')
              .where((seg) => seg.isNotEmpty && seg != '.' && seg != '..')
              .toList();
          if (parts.isEmpty) continue;
          final outPath = p.joinAll([extractDirPath, ...parts]);
          if (entry.isFile) {
            File(outPath).parent.createSync(recursive: true);
            final output = OutputFileStream(outPath);
            try {
              entry.writeContent(output);
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
      file = File(p.join(tmpDir.path, item.displayName));
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
    final prefs = await SharedPreferencesAsync.instance;
    final map = await prefs.snapshot();
    return jsonEncode(map);
  }

  /// Stream chat data to a temporary JSON file instead of building a huge
  /// in-memory String.  Uses IOSink for low memory overhead.
  Future<File> _exportChatsToFile(Directory directory) async {
    if (!chatService.initialized) {
      await chatService.init();
    }
    final conversations = chatService.getAllCompleteConversations();
    final file = File(p.join(directory.path, '_bk_chats.json'));
    final sink = file.openWrite();

    try {
      sink.write('{"version":1,');

      // --- conversations ---
      sink.write('"conversations":[');
      for (int i = 0; i < conversations.length; i++) {
        if (i > 0) sink.write(',');
        sink.write(jsonEncode(conversations[i].toJson()));
        // Yield periodically so the main isolate can process UI frames
        if (i % 50 == 0) await Future<void>.delayed(Duration.zero);
      }
      sink.write('],');

      // --- messages, toolEvents, geminiThoughtSigs ---
      sink.write('"messages":[');
      final toolEvents = <String, List<Map<String, dynamic>>>{};
      final geminiThoughtSigs = <String, String>{};
      bool firstMsg = true;
      for (final c in conversations) {
        final msgs = chatService.getMessages(c.id);
        for (final m in msgs) {
          if (!firstMsg) sink.write(',');
          firstMsg = false;
          sink.write(jsonEncode(m.toJson()));
          if (m.role == 'assistant') {
            final ev = chatService.getToolEvents(m.id);
            if (ev.isNotEmpty) toolEvents[m.id] = ev;
            final sig = chatService.getGeminiThoughtSignature(m.id);
            if (sig != null && sig.isNotEmpty) geminiThoughtSigs[m.id] = sig;
          }
        }
        // Yield after each conversation
        await Future<void>.delayed(Duration.zero);
      }
      sink.write('],');

      // --- toolEvents ---
      sink.write('"toolEvents":');
      sink.write(jsonEncode(toolEvents));
      sink.write(',');

      // --- geminiThoughtSigs ---
      sink.write('"geminiThoughtSigs":');
      sink.write(jsonEncode(geminiThoughtSigs));

      sink.write('}');
    } finally {
      await sink.flush();
      await sink.close();
    }

    return file;
  }

  Future<void> _restoreFromBackupFile(
    File file,
    WebDavConfig cfg, {
    RestoreMode mode = RestoreMode.overwrite,
  }) async {
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

      final settingsFile = File(p.join(extractDir.path, 'settings.json'));
      final chatsFile = File(p.join(extractDir.path, 'chats.json'));
      if (!await settingsFile.exists()) {
        throw const FormatException('settings.json');
      }
      final restoreChats = cfg.includeChats && await chatsFile.exists();

      final settings =
          jsonDecode(await settingsFile.readAsString()) as Map<String, dynamic>;
      final prefs = await SharedPreferencesAsync.instance;
      prefs._normalizeLegacyStringLists(settings);
      prefs._validateRestore(settings);

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

      // Restore settings
      if (await settingsFile.exists()) {
        try {
          if (mode == RestoreMode.overwrite) {
            // For overwrite mode, restore all settings
            await prefs.restore(settings);
          } else {
            // For merge mode, intelligently merge settings
            final existing = await prefs.snapshot();
            prefs._normalizeLegacyStringLists(existing);
            final pendingSettings = <String, dynamic>{};

            // Keys that should be merged as JSON arrays/objects
            const mergeableKeys = {
              'assistants_v1', // Assistant configurations
              'assistant_memories_v1', // Assistant memory entries
              'provider_configs_v1', // Provider configurations
              'pinned_models_v1', // Pinned models list
              'providers_order_v1', // Provider order list
              'mcp_servers_v1', // MCP server configurations
              'provider_groups_v1', // provider group list
              'provider_group_map_v1', // providerKey -> groupId
              'provider_group_collapsed_v1', // groupId|__ungrouped__ -> bool
              'search_services_v1', // Search services configuration
              'assistant_tags_v1', // Ordered tag list [{id,name}]
              'assistant_tag_map_v1', // assistantId -> tagId
              'assistant_tag_collapsed_v1', // tagId -> bool
            };

            for (final entry in settings.entries) {
              final key = entry.key;
              final newValue = entry.value;

              if (mergeableKeys.contains(key)) {
                // Special handling for mergeable configurations
                if (key == 'assistants_v1' && existing.containsKey(key)) {
                  // Merge assistants by ID with field-level rules.
                  // Preserve local avatar if already set to avoid clearing/overwriting.
                  final existingAssistants =
                      jsonDecode(existing[key] as String) as List;
                  final newAssistants = jsonDecode(newValue as String) as List;
                  final assistantMap = <String, Map<String, dynamic>>{};

                  // Seed map with existing assistants
                  for (final a in existingAssistants) {
                    if (a is Map && a.containsKey('id')) {
                      // Store as mutable map<String, dynamic>
                      assistantMap[a['id'].toString()] =
                          Map<String, dynamic>.from(a);
                    }
                  }

                  // Merge with imported assistants
                  for (final a in newAssistants) {
                    if (a is Map && a.containsKey('id')) {
                      final id = a['id'].toString();
                      final incoming = Map<String, dynamic>.from(a);

                      if (!assistantMap.containsKey(id)) {
                        // New assistant entirely
                        assistantMap[id] = incoming;
                        continue;
                      }

                      final local = assistantMap[id]!;

                      // Start with default behavior: imported values override
                      final merged = <String, dynamic>{...local, ...incoming};

                      // Special rule: do not override existing non-empty avatar
                      final localAvatar = (local['avatar'] ?? '').toString();
                      final incomingAvatar = (incoming['avatar'] ?? '');
                      if (localAvatar.trim().isNotEmpty) {
                        // Keep local avatar regardless of imported value
                        merged['avatar'] = localAvatar;
                      } else {
                        // Only take imported avatar if present (non-empty)
                        final s = incomingAvatar is String
                            ? incomingAvatar
                            : incomingAvatar?.toString();
                        if (s == null || s.trim().isEmpty) {
                          merged['avatar'] = null;
                        } else {
                          merged['avatar'] = s;
                        }
                      }

                      // Special rule: do not override existing non-empty background
                      final localBg = (local['background'] ?? '').toString();
                      final incomingBg = (incoming['background'] ?? '');
                      if (localBg.trim().isNotEmpty) {
                        // Keep local background regardless of imported value
                        merged['background'] = localBg;
                      } else {
                        // Only take imported background if present (non-empty)
                        final sb = incomingBg is String
                            ? incomingBg
                            : incomingBg?.toString();
                        if (sb == null || sb.trim().isEmpty) {
                          merged['background'] = null;
                        } else {
                          merged['background'] = sb;
                        }
                      }

                      assistantMap[id] = merged;
                    }
                  }

                  final mergedAssistants = assistantMap.values.toList();
                  pendingSettings[key] = jsonEncode(mergedAssistants);
                } else if (key == 'provider_configs_v1' &&
                    existing.containsKey(key)) {
                  // Merge provider configs: combine both maps
                  final existingConfigs =
                      jsonDecode(existing[key] as String)
                          as Map<String, dynamic>;
                  final newConfigs =
                      jsonDecode(newValue as String) as Map<String, dynamic>;

                  // Merge configs, new values override existing for same keys
                  final mergedConfigs = {...existingConfigs, ...newConfigs};
                  pendingSettings[key] = jsonEncode(mergedConfigs);
                } else if (key == 'assistant_memories_v1' &&
                    existing.containsKey(key)) {
                  pendingSettings[key] = _mergeAssistantMemories(
                    existing[key] as String,
                    newValue as String,
                  );
                } else if (key == 'mcp_servers_v1' &&
                    existing.containsKey(key)) {
                  pendingSettings[key] = _mergeJsonListById(
                    existing[key] as String,
                    newValue as String,
                  );
                } else if (key == 'pinned_models_v1' &&
                    existing.containsKey(key)) {
                  // Merge pinned models: combine and deduplicate
                  final existingModels = (existing[key] as List).cast<String>();
                  final newModels = (newValue as List).cast<String>();
                  final modelSet = <String>{};

                  // Add all models to set for deduplication
                  modelSet.addAll(existingModels);
                  modelSet.addAll(newModels);

                  pendingSettings[key] = modelSet.toList();
                } else if (key == 'assistant_tags_v1') {
                  // Merge tag list by id; keep existing order, append new tags at end (incoming order)
                  final existingStr = (existing[key] ?? '') as String?;
                  final newStr = (newValue ?? '') as String?;
                  final existingList =
                      (existingStr == null || existingStr.isEmpty)
                      ? <dynamic>[]
                      : (jsonDecode(existingStr) as List);
                  final newList = (newStr == null || newStr.isEmpty)
                      ? <dynamic>[]
                      : (jsonDecode(newStr) as List);

                  // Map existing by id and maintain order
                  final existingOrder = <String>[];
                  final tagById = <String, Map<String, dynamic>>{};
                  for (final e in existingList) {
                    if (e is Map && e['id'] != null) {
                      final id = e['id'].toString();
                      existingOrder.add(id);
                      tagById[id] = Map<String, dynamic>.from(e);
                    }
                  }
                  // Add new tags that don't exist yet
                  for (final e in newList) {
                    if (e is Map && e['id'] != null) {
                      final id = e['id'].toString();
                      if (!tagById.containsKey(id)) {
                        tagById[id] = Map<String, dynamic>.from(e);
                        existingOrder.add(id);
                      }
                    }
                  }
                  final merged = [
                    for (final id in existingOrder) tagById[id],
                  ].whereType<Map<String, dynamic>>().toList();
                  pendingSettings[key] = jsonEncode(merged);
                } else if (key == 'assistant_tag_map_v1') {
                  // Merge assistant->tag mapping; prefer existing on conflicts
                  final existingStr = (existing[key] ?? '') as String?;
                  final newStr = (newValue ?? '') as String?;
                  final existingMap =
                      (existingStr == null || existingStr.isEmpty)
                      ? <String, dynamic>{}
                      : (jsonDecode(existingStr) as Map<String, dynamic>);
                  final newMap = (newStr == null || newStr.isEmpty)
                      ? <String, dynamic>{}
                      : (jsonDecode(newStr) as Map<String, dynamic>);
                  final merged = <String, dynamic>{...newMap, ...existingMap};
                  pendingSettings[key] = jsonEncode(merged);
                } else if (key == 'assistant_tag_collapsed_v1') {
                  // Merge collapse states; prefer existing on conflicts
                  final existingStr = (existing[key] ?? '') as String?;
                  final newStr = (newValue ?? '') as String?;
                  final existingMap =
                      (existingStr == null || existingStr.isEmpty)
                      ? <String, dynamic>{}
                      : (jsonDecode(existingStr) as Map<String, dynamic>);
                  final newMap = (newStr == null || newStr.isEmpty)
                      ? <String, dynamic>{}
                      : (jsonDecode(newStr) as Map<String, dynamic>);
                  final merged = <String, dynamic>{...newMap, ...existingMap};
                  pendingSettings[key] = jsonEncode(merged);
                } else if (key == 'provider_groups_v1') {
                  // Merge provider groups by id; keep existing order, append new groups at end (incoming order)
                  final existingStr = (existing[key] ?? '') as String?;
                  final newStr = (newValue ?? '') as String?;
                  final existingList =
                      (existingStr == null || existingStr.isEmpty)
                      ? <dynamic>[]
                      : (jsonDecode(existingStr) as List);
                  final newList = (newStr == null || newStr.isEmpty)
                      ? <dynamic>[]
                      : (jsonDecode(newStr) as List);

                  final existingOrder = <String>[];
                  final groupById = <String, Map<String, dynamic>>{};
                  for (final e in existingList) {
                    if (e is Map && e['id'] != null) {
                      final id = e['id'].toString();
                      existingOrder.add(id);
                      groupById[id] = Map<String, dynamic>.from(e);
                    }
                  }
                  for (final e in newList) {
                    if (e is Map && e['id'] != null) {
                      final id = e['id'].toString();
                      if (!groupById.containsKey(id)) {
                        groupById[id] = Map<String, dynamic>.from(e);
                        existingOrder.add(id);
                      }
                    }
                  }
                  final merged = [
                    for (final id in existingOrder) groupById[id],
                  ].whereType<Map<String, dynamic>>().toList();
                  pendingSettings[key] = jsonEncode(merged);
                } else if (key == 'provider_group_map_v1') {
                  // Merge provider->group mapping; prefer existing on conflicts
                  final existingStr = (existing[key] ?? '') as String?;
                  final newStr = (newValue ?? '') as String?;
                  final existingMap =
                      (existingStr == null || existingStr.isEmpty)
                      ? <String, dynamic>{}
                      : (jsonDecode(existingStr) as Map<String, dynamic>);
                  final newMap = (newStr == null || newStr.isEmpty)
                      ? <String, dynamic>{}
                      : (jsonDecode(newStr) as Map<String, dynamic>);
                  final merged = <String, dynamic>{...newMap, ...existingMap};
                  pendingSettings[key] = jsonEncode(merged);
                } else if (key == 'provider_group_collapsed_v1') {
                  // Merge collapse states; prefer existing on conflicts
                  final existingStr = (existing[key] ?? '') as String?;
                  final newStr = (newValue ?? '') as String?;
                  final existingMap =
                      (existingStr == null || existingStr.isEmpty)
                      ? <String, dynamic>{}
                      : (jsonDecode(existingStr) as Map<String, dynamic>);
                  final newMap = (newStr == null || newStr.isEmpty)
                      ? <String, dynamic>{}
                      : (jsonDecode(newStr) as Map<String, dynamic>);
                  final merged = <String, dynamic>{...newMap, ...existingMap};
                  pendingSettings[key] = jsonEncode(merged);
                } else if ((key == 'providers_order_v1' ||
                        key == 'search_services_v1') &&
                    existing.containsKey(key)) {
                  // For these lists, prefer the imported version if different
                  // This ensures new providers/services are properly ordered
                  pendingSettings[key] = newValue;
                } else {
                  // For new keys, add them
                  pendingSettings[key] = newValue;
                }
              } else if (!existing.containsKey(key)) {
                // For non-mergeable keys, only add if not existing
                pendingSettings[key] = newValue;
              }
              // Skip existing non-mergeable keys to preserve user preferences
            }
            prefs._validateRestore(pendingSettings);
            for (final entry in pendingSettings.entries) {
              await prefs.restoreSingle(entry.key, entry.value);
            }
          }
        } catch (_) {
          rethrow;
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
              final messages = chatService.getMessages(conv.id);
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
          final uploadSrc = Directory(p.join(extractDir.path, 'upload'));
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
          final imagesSrc = Directory(p.join(extractDir.path, 'images'));
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
          final avatarsSrc = Directory(p.join(extractDir.path, 'avatars'));
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
          final fontsSrc = Directory(p.join(extractDir.path, 'fonts'));
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
          final uploadSrc = Directory(p.join(extractDir.path, 'upload'));
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
          final imagesSrc = Directory(p.join(extractDir.path, 'images'));
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
          final avatarsSrc = Directory(p.join(extractDir.path, 'avatars'));
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
          final fontsSrc = Directory(p.join(extractDir.path, 'fonts'));
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

  static String _mergeJsonListById(String existingRaw, String incomingRaw) {
    final existingList = jsonDecode(existingRaw) as List;
    final incomingList = jsonDecode(incomingRaw) as List;
    final byId = <String, Map<String, dynamic>>{};
    final order = <String>[];

    void addIfNew(dynamic item) {
      if (item is! Map || item['id'] == null) return;
      final id = item['id'].toString();
      if (id.isEmpty || byId.containsKey(id)) return;
      byId[id] = Map<String, dynamic>.from(item);
      order.add(id);
    }

    for (final item in existingList) {
      addIfNew(item);
    }
    for (final item in incomingList) {
      addIfNew(item);
    }

    return jsonEncode([for (final id in order) byId[id]]);
  }

  static String _mergeAssistantMemories(
    String existingRaw,
    String incomingRaw,
  ) {
    final existingList = jsonDecode(existingRaw) as List;
    final incomingList = jsonDecode(incomingRaw) as List;
    final merged = <Map<String, dynamic>>[];
    final contentKeys = <String>{};
    var maxId = 0;

    void addExisting(dynamic item) {
      if (item is! Map) return;
      final map = Map<String, dynamic>.from(item);
      final id = (map['id'] as num?)?.toInt() ?? 0;
      if (id > maxId) maxId = id;
      final key = _assistantMemoryContentKey(map);
      if (key != null) contentKeys.add(key);
      merged.add(map);
    }

    for (final item in existingList) {
      addExisting(item);
    }

    for (final item in incomingList) {
      if (item is! Map) continue;
      final incoming = Map<String, dynamic>.from(item);
      final key = _assistantMemoryContentKey(incoming);
      if (key != null && contentKeys.contains(key)) continue;

      final id = (incoming['id'] as num?)?.toInt() ?? 0;
      final idTaken = merged.any(
        (e) => ((e['id'] as num?)?.toInt() ?? 0) == id,
      );
      if (id <= 0 || idTaken) {
        maxId += 1;
        incoming['id'] = maxId;
      } else if (id > maxId) {
        maxId = id;
      }

      if (key != null) contentKeys.add(key);
      merged.add(incoming);
    }

    return jsonEncode(merged);
  }

  static String? _assistantMemoryContentKey(Map<String, dynamic> memory) {
    final assistantId = (memory['assistantId'] ?? '').toString().trim();
    final content = (memory['content'] ?? '').toString().trim();
    if (assistantId.isEmpty || content.isEmpty) return null;
    return '$assistantId\n$content';
  }
}

class _StreamingZipWriter {
  _StreamingZipWriter(String outPath) : _output = OutputFileStream(outPath);

  static const int _localFileHeaderSignature = 0x04034b50;
  static const int _centralDirectoryHeaderSignature = 0x02014b50;
  static const int _endOfCentralDirectorySignature = 0x06054b50;
  static const int _dataDescriptorSignature = 0x08074b50;
  static const int _versionNeeded = 20;
  static const int _utf8Flag = 1 << 11;
  static const int _dataDescriptorFlag = 1 << 3;
  static const int _deflateMethod = 8;
  static const int _maxZip32 = 0xffffffff;
  static const int _maxZipEntries = 0xffff;
  static const int _chunkSize = 1024 * 1024;

  final OutputFileStream _output;
  final List<_StreamingZipEntry> _entries = <_StreamingZipEntry>[];
  bool _closed = false;

  void addFile(File file, String entryName) {
    if (_closed) {
      throw StateError('Cannot add files after the ZIP writer is closed.');
    }
    if (entryName.isEmpty) return;

    final stat = file.statSync();
    final uncompressedSize = stat.size;
    _checkZip32(uncompressedSize, 'file size');
    _checkZip32(_output.length, 'local header offset');

    final modified = stat.modified;
    final modTime = _zipTime(modified);
    final modDate = _zipDate(modified);
    final nameBytes = utf8.encode(entryName);
    final localHeaderOffset = _output.length;

    _writeLocalHeader(nameBytes: nameBytes, modTime: modTime, modDate: modDate);

    final written = _writeDeflatedFile(file);
    _checkZip32(written.compressedSize, 'compressed size');
    _checkZip32(written.uncompressedSize, 'uncompressed size');

    _writeDataDescriptor(written);

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
  }

  void closeSync() {
    if (_closed) return;
    _checkEntryCount();

    final centralDirectoryOffset = _output.length;
    _checkZip32(centralDirectoryOffset, 'central directory offset');
    for (final entry in _entries) {
      _writeCentralDirectoryHeader(entry);
    }
    final centralDirectorySize = _output.length - centralDirectoryOffset;
    _checkZip32(centralDirectorySize, 'central directory size');

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
  }) {
    _output.writeUint32(_localFileHeaderSignature);
    _output.writeUint16(_versionNeeded);
    _output.writeUint16(_utf8Flag | _dataDescriptorFlag);
    _output.writeUint16(_deflateMethod);
    _output.writeUint16(modTime);
    _output.writeUint16(modDate);
    _output.writeUint32(0);
    _output.writeUint32(0);
    _output.writeUint32(0);
    _output.writeUint16(nameBytes.length);
    _output.writeUint16(0);
    _output.writeBytes(nameBytes);
  }

  _StreamingZipWrittenFile _writeDeflatedFile(File file) {
    final compressedSink = _CountingOutputSink(_output);
    final inputSink = ZLibCodec(
      level: ZLibOption.defaultLevel,
      raw: true,
    ).encoder.startChunkedConversion(compressedSink);

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
        inputSink.add(chunk);
      }
      inputSink.close();
    } finally {
      raf.closeSync();
    }

    return _StreamingZipWrittenFile(
      crc32: crc32,
      compressedSize: compressedSink.bytesWritten,
      uncompressedSize: uncompressedSize,
    );
  }

  void _writeDataDescriptor(_StreamingZipWrittenFile written) {
    _output.writeUint32(_dataDescriptorSignature);
    _output.writeUint32(written.crc32);
    _output.writeUint32(written.compressedSize);
    _output.writeUint32(written.uncompressedSize);
  }

  void _writeCentralDirectoryHeader(_StreamingZipEntry entry) {
    _output.writeUint32(_centralDirectoryHeaderSignature);
    _output.writeUint16(_versionNeeded);
    _output.writeUint16(_versionNeeded);
    _output.writeUint16(_utf8Flag | _dataDescriptorFlag);
    _output.writeUint16(_deflateMethod);
    _output.writeUint16(entry.modTime);
    _output.writeUint16(entry.modDate);
    _output.writeUint32(entry.crc32);
    _output.writeUint32(entry.compressedSize);
    _output.writeUint32(entry.uncompressedSize);
    _output.writeUint16(entry.nameBytes.length);
    _output.writeUint16(0);
    _output.writeUint16(0);
    _output.writeUint16(0);
    _output.writeUint16(0);
    _output.writeUint32(entry.mode << 16);
    _output.writeUint32(entry.localHeaderOffset);
    _output.writeBytes(entry.nameBytes);
  }

  void _writeEndOfCentralDirectory({
    required int centralDirectoryOffset,
    required int centralDirectorySize,
  }) {
    _output.writeUint32(_endOfCentralDirectorySignature);
    _output.writeUint16(0);
    _output.writeUint16(0);
    _output.writeUint16(_entries.length);
    _output.writeUint16(_entries.length);
    _output.writeUint32(centralDirectorySize);
    _output.writeUint32(centralDirectoryOffset);
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

  static void _checkZip32(int value, String field) {
    if (value > _maxZip32) {
      throw FileSystemException('ZIP entry exceeds ZIP32 limit: $field');
    }
  }

  void _checkEntryCount() {
    if (_entries.length > _maxZipEntries) {
      throw FileSystemException('ZIP entry count exceeds ZIP32 limit');
    }
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
  });

  final int crc32;
  final int compressedSize;
  final int uncompressedSize;
}

// ===== SharedPreferences async snapshot/restore helpers =====
class SharedPreferencesAsync {
  SharedPreferencesAsync._();
  static SharedPreferencesAsync? _inst;
  // Local-only UI state stays on device and is excluded from backups/restores.
  static const _localOnlyKeys = {
    'window_width_v1',
    'window_height_v1',
    'window_pos_x_v1',
    'window_pos_y_v1',
    'window_maximized_v1',
    'display_chat_font_scale_v1',
    'desktop_hotkeys_commands_v1',
    'desktop_hotkeys_enabled_v1',
  };
  static const _jsonListKeys = {
    'assistants_v1',
    'assistant_memories_v1',
    'mcp_servers_v1',
    'provider_groups_v1',
    'search_services_v1',
    'assistant_tags_v1',
  };
  static const _jsonMapKeys = {
    'provider_configs_v1',
    'provider_group_map_v1',
    'provider_group_collapsed_v1',
    'assistant_tag_map_v1',
    'assistant_tag_collapsed_v1',
  };
  static const _jsonMapOfMapKeys = {'provider_configs_v1'};
  static const _jsonMapOfStringKeys = {
    'provider_group_map_v1',
    'assistant_tag_map_v1',
  };
  static const _jsonMapOfBoolKeys = {
    'provider_group_collapsed_v1',
    'assistant_tag_collapsed_v1',
  };
  static const _stringListKeys = {'pinned_models_v1', 'providers_order_v1'};

  static Future<SharedPreferencesAsync> get instance async {
    _inst ??= SharedPreferencesAsync._();
    return _inst!;
  }

  Future<Map<String, dynamic>> snapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final map = <String, dynamic>{};
    for (final k in keys) {
      if (_localOnlyKeys.contains(k)) continue;
      map[k] = prefs.get(k);
    }
    return map;
  }

  Future<void> restore(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in data.entries) {
      final k = entry.key;
      final v = entry.value;
      if (_localOnlyKeys.contains(k)) continue;
      await _restoreValue(prefs, k, v);
    }
  }

  Future<void> restoreSingle(String key, dynamic value) async {
    if (_localOnlyKeys.contains(key)) return;
    final prefs = await SharedPreferences.getInstance();
    await _restoreValue(prefs, key, value);
  }

  void _validateRestore(Map<String, dynamic> data) {
    for (final entry in data.entries) {
      if (_localOnlyKeys.contains(entry.key)) continue;
      _validateRestoreValue(entry.key, entry.value);
    }
  }

  void _validateRestoreValue(String key, dynamic value) {
    final supported =
        value is bool ||
        value is int ||
        value is double ||
        value is String ||
        (value is List && value.every((item) => item is String));
    if (!supported) {
      throw FormatException(key);
    }
    if (_jsonListKeys.contains(key)) {
      _validateJsonShape(key, value, expectList: true);
    } else if (_jsonMapKeys.contains(key)) {
      _validateJsonShape(key, value, expectList: false);
    }
  }

  void _validateJsonShape(
    String key,
    dynamic value, {
    required bool expectList,
  }) {
    if (value is! String) {
      throw FormatException(key);
    }
    try {
      final decoded = jsonDecode(value);
      if (expectList) {
        if (decoded is! List || decoded.any((entry) => entry is! Map)) {
          throw FormatException(key);
        }
      } else if (decoded is! Map) {
        throw FormatException(key);
      } else if (_jsonMapOfMapKeys.contains(key) &&
          decoded.values.any((entry) => entry is! Map)) {
        throw FormatException(key);
      } else if (_jsonMapOfStringKeys.contains(key) &&
          decoded.values.any((entry) => entry is! String)) {
        throw FormatException(key);
      } else if (_jsonMapOfBoolKeys.contains(key) &&
          decoded.values.any((entry) => entry is! bool)) {
        throw FormatException(key);
      }
    } on FormatException {
      throw FormatException(key);
    }
  }

  void _normalizeLegacyStringLists(Map<String, dynamic> data) {
    for (final key in _stringListKeys) {
      final value = data[key];
      if (value is! String) continue;
      try {
        final decoded = jsonDecode(value);
        if (decoded is! List || decoded.any((item) => item is! String)) {
          throw FormatException(key);
        }
        data[key] = decoded.cast<String>();
      } on FormatException {
        throw FormatException(key);
      }
    }
  }

  Future<void> _restoreValue(
    SharedPreferences prefs,
    String key,
    dynamic value,
  ) async {
    _validateRestoreValue(key, value);
    final bool restored;
    if (value is bool) {
      restored = await prefs.setBool(key, value);
    } else if (value is int) {
      restored = await prefs.setInt(key, value);
    } else if (value is double) {
      restored = await prefs.setDouble(key, value);
    } else if (value is String) {
      restored = await prefs.setString(key, value);
    } else if (value is List && value.every((item) => item is String)) {
      restored = await prefs.setStringList(key, value.cast<String>());
    } else {
      throw FormatException(key);
    }
    if (!restored) {
      throw StateError(key);
    }
  }
}
