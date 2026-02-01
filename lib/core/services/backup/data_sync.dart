import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../../models/backup.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../chat/chat_service.dart';
import '../../../utils/app_directories.dart';

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

  Future<void> _ensureCollection(WebDavConfig cfg) async {
    final client = http.Client();
    try {
      // Ensure each segment exists
      final url = cfg.url.trim().replaceAll(RegExp(r'/+$'), '');
      final segments = cfg.path.split('/').where((s) => s.trim().isNotEmpty).toList();
      String acc = url;
      for (final seg in segments) {
        acc = acc + '/' + seg;
        // PROPFIND depth 0 on this collection (with trailing slash)
        final u = Uri.parse(acc + '/');
        final req = http.Request('PROPFIND', u);
        req.headers.addAll({
          'Depth': '0',
          'Content-Type': 'application/xml; charset=utf-8',
          ..._authHeaders(cfg),
        });
        req.body = '<?xml version="1.0" encoding="utf-8" ?><d:propfind xmlns:d="DAV:"><d:prop><d:displayname/></d:prop></d:propfind>';
        final res = await client.send(req).then(http.Response.fromStream);
        if (res.statusCode == 404) {
          // create this level
          final mk = await client
              .send(http.Request('MKCOL', u)..headers.addAll(_authHeaders(cfg)))
              .then(http.Response.fromStream);
          if (mk.statusCode != 201 && mk.statusCode != 200 && mk.statusCode != 405) {
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
    req.headers.addAll({'Depth': '1', 'Content-Type': 'application/xml; charset=utf-8', ..._authHeaders(cfg)});
    req.body = '<?xml version="1.0" encoding="utf-8" ?>\n'
        '<d:propfind xmlns:d="DAV:">\n'
        '  <d:prop>\n'
        '    <d:displayname/>\n'
        '  </d:prop>\n'
        '</d:propfind>';
    final res = await http.Client().send(req).then(http.Response.fromStream);
    if (res.statusCode != 207 && (res.statusCode < 200 || res.statusCode >= 300)) {
      throw Exception('WebDAV test failed: ${res.statusCode}');
    }
  }

  Future<File> prepareBackupFile(WebDavConfig cfg) async {
    final tmp = await _ensureTempDir();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final outFile = File(p.join(tmp.path, 'kelivo_backup_$timestamp.zip'));
    if (await outFile.exists()) await outFile.delete();

    // Use Archive instead of ZipFileEncoder for better control
    final archive = Archive();

    // settings.json
    final settingsJson = await _exportSettingsJson();
    final settingsBytes = utf8.encode(settingsJson);
    final settingsArchiveFile = ArchiveFile('settings.json', settingsBytes.length, settingsBytes);
    archive.addFile(settingsArchiveFile);

    // chats
    if (cfg.includeChats) {
      final chatsJson = await _exportChatsJson();
      final chatsBytes = utf8.encode(chatsJson);
      final chatsArchiveFile = ArchiveFile('chats.json', chatsBytes.length, chatsBytes);
      archive.addFile(chatsArchiveFile);
    }

    // files under upload/, images/, and avatars/
    if (cfg.includeFiles) {
      // Export upload directory
      final uploadDir = await _getUploadDir();
      if (await uploadDir.exists()) {
        final entries = uploadDir.listSync(recursive: true, followLinks: false);
        for (final ent in entries) {
          if (ent is File) {
            final rel = p.relative(ent.path, from: uploadDir.path);
            // ZIP entries must use forward slashes regardless of platform
            final relPosix = rel.replaceAll('\\', '/');
            final fileBytes = await ent.readAsBytes();
            final archiveFile = ArchiveFile('upload/$relPosix', fileBytes.length, fileBytes);
            archive.addFile(archiveFile);
          }
        }
      }

      // Export avatars directory
      final avatarsDir = await _getAvatarsDir();
      if (await avatarsDir.exists()) {
        final entries = avatarsDir.listSync(recursive: true, followLinks: false);
        for (final ent in entries) {
          if (ent is File) {
            final rel = p.relative(ent.path, from: avatarsDir.path);
            final relPosix = rel.replaceAll('\\', '/');
            final fileBytes = await ent.readAsBytes();
            final archiveFile = ArchiveFile('avatars/$relPosix', fileBytes.length, fileBytes);
            archive.addFile(archiveFile);
          }
        }
      }

      // Export images directory
      final imagesDir = await _getImagesDir();
      if (await imagesDir.exists()) {
        final entries = imagesDir.listSync(recursive: true, followLinks: false);
        for (final ent in entries) {
          if (ent is File) {
            final rel = p.relative(ent.path, from: imagesDir.path);
            final relPosix = rel.replaceAll('\\', '/');
            final fileBytes = await ent.readAsBytes();
            final archiveFile = ArchiveFile('images/$relPosix', fileBytes.length, fileBytes);
            archive.addFile(archiveFile);
          }
        }
      }
    }

    // Encode archive to ZIP
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive)!;
    await outFile.writeAsBytes(zipBytes);
    
    return outFile;
  }

  Future<void> backupToWebDav(WebDavConfig cfg) async {
    final file = await prepareBackupFile(cfg);
    await _ensureCollection(cfg);
    final target = _fileUri(cfg, p.basename(file.path));
    final bytes = await file.readAsBytes();
    final res = await http.put(target, headers: {
      'content-type': 'application/zip',
      ..._authHeaders(cfg),
    }, body: bytes);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Upload failed: ${res.statusCode}');
    }
  }

  Future<List<BackupFileItem>> listBackupFiles(WebDavConfig cfg) async {
    await _ensureCollection(cfg);
    final uri = _collectionUri(cfg);
    final req = http.Request('PROPFIND', uri);
    req.headers.addAll({'Depth': '1', 'Content-Type': 'application/xml; charset=utf-8', ..._authHeaders(cfg)});
    req.body = '<?xml version="1.0" encoding="utf-8" ?>\n'
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
      final abs = Uri.parse(href).isAbsolute ? Uri.parse(href).toString() : uri.resolve(href).toString();
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
        try { mtime = DateTime.parse(mtimeStr.first); } catch (_) {}
      }
      final name = (disp.isNotEmpty && disp.first.trim().isNotEmpty)
          ? disp.first.trim()
          : Uri.parse(href).pathSegments.last;
      
      // If mtime is null, try to extract from filename (format: kelivo_backup_2025-01-19T12-34-56.123456.zip)
      if (mtime == null) {
        final match = RegExp(r'kelivo_backup_(\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d+)\.zip').firstMatch(name);
        if (match != null) {
          try {
            // Replace hyphens in time part back to colons
            final timestamp = match.group(1)!.replaceAll(RegExp(r'T(\d{2})-(\d{2})-(\d{2})'), 'T\$1:\$2:\$3');
            mtime = DateTime.parse(timestamp);
          } catch (_) {}
        }
      }
      
      // Skip directories
      if (abs.endsWith('/')) continue;
      final fullHref = Uri.parse(abs);
      items.add(BackupFileItem(href: fullHref, displayName: name, size: size, lastModified: mtime));
    }
    items.sort((a, b) => (b.lastModified ?? DateTime(0)).compareTo(a.lastModified ?? DateTime(0)));
    return items;
  }

  Future<void> restoreFromWebDav(WebDavConfig cfg, BackupFileItem item, {RestoreOptions? options, RestoreMode mode = RestoreMode.overwrite}) async {
    // Backward compatibility: if options is null, construct from legacy mode
    final opts = options ?? RestoreOptions.fromMode(mode);

    final res = await http.get(item.href, headers: _authHeaders(cfg));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Download failed: ${res.statusCode}');
    }
    final tmpDir = await _ensureTempDir();
    final file = File(p.join(tmpDir.path, item.displayName));
    await file.writeAsBytes(res.bodyBytes);
    await _restoreFromBackupFile(file, cfg, opts);
    try { await file.delete(); } catch (_) {}
  }

  Future<void> deleteWebDavBackupFile(WebDavConfig cfg, BackupFileItem item) async {
    final req = http.Request('DELETE', item.href);
    req.headers.addAll(_authHeaders(cfg));
    final res = await http.Client().send(req).then(http.Response.fromStream);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Delete failed: ${res.statusCode}');
    }
  }

  Future<File> exportToFile(WebDavConfig cfg) => prepareBackupFile(cfg);

  Future<void> restoreFromLocalFile(File file, WebDavConfig cfg, {RestoreOptions? options, RestoreMode mode = RestoreMode.overwrite}) async {
    if (!await file.exists()) throw Exception('备份文件不存在');
    // Backward compatibility
    final opts = options ?? RestoreOptions.fromMode(mode);
    await _restoreFromBackupFile(file, cfg, opts);
  }

  // ===== Internal helpers =====
  /// Ensures the temporary directory exists (some macOS installs may not create the cache folder until first use).
  Future<Directory> _ensureTempDir() async {
    Directory dir = await getTemporaryDirectory();
    if (!await dir.exists()) {
      try { await dir.create(recursive: true); } catch (_) {}
    }
    if (!await dir.exists()) {
      dir = await Directory.systemTemp.createTemp('kelivo_tmp_');
    }
    return dir;
  }

  Future<File> _writeTempText(String name, String content) async {
    final tmp = await _ensureTempDir();
    final f = File(p.join(tmp.path, name));
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

  Future<String> _exportSettingsJson() async {
    final prefs = await SharedPreferencesAsync.instance;
    final map = await prefs.snapshot();
    return jsonEncode(map);
  }

  Future<String> _exportChatsJson() async {
    if (!chatService.initialized) {
      await chatService.init();
    }
    final conversations = chatService.getAllConversations();
    final allMsgs = <ChatMessage>[];
    final toolEvents = <String, List<Map<String, dynamic>>>{};
    final geminiThoughtSigs = <String, String>{};
    for (final c in conversations) {
      final msgs = chatService.getMessages(c.id);
      allMsgs.addAll(msgs);
      for (final m in msgs) {
        if (m.role == 'assistant') {
          final ev = chatService.getToolEvents(m.id);
          if (ev.isNotEmpty) toolEvents[m.id] = ev;
          final sig = chatService.getGeminiThoughtSignature(m.id);
          if (sig != null && sig.isNotEmpty) geminiThoughtSigs[m.id] = sig;
        }
      }
    }
    final obj = {
      'version': 1,
      'conversations': conversations.map((c) => c.toJson()).toList(),
      'messages': allMsgs.map((m) => m.toJson()).toList(),
      'toolEvents': toolEvents,
      'geminiThoughtSigs': geminiThoughtSigs,
    };
    return jsonEncode(obj);
  }

  Future<void> _restoreFromBackupFile(File file, WebDavConfig cfg, RestoreOptions options) async {
    // If it's a full overwrite (legacy behavior), use the robust legacy method
    if (options.isFullOverwrite) {
      await _legacyRestoreFromBackupFile(file, cfg, mode: RestoreMode.overwrite);
      return;
    }

    // Otherwise, use granular restore logic
    
    // Extract to temp
    final tmp = await _ensureTempDir();
    final extractDir = Directory(p.join(tmp.path, 'restore_${DateTime.now().millisecondsSinceEpoch}'));
    await extractDir.create(recursive: true);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final entry in archive) {
      // Normalize entry name to use forward slashes and remove traversal
      final normalized = entry.name.replaceAll('\\', '/');
      final parts = normalized
          .split('/')
          .where((seg) => seg.isNotEmpty && seg != '.' && seg != '..')
          .toList();
      final outPath = p.joinAll([extractDir.path, ...parts]);
      if (entry.isFile) {
        final outFile = File(outPath)..createSync(recursive: true);
        outFile.writeAsBytesSync(entry.content as List<int>);
      } else {
        Directory(outPath).createSync(recursive: true);
      }
    }

    // 1. Settings & Providers Restoration
    final settingsFile = File(p.join(extractDir.path, 'settings.json'));
    if (await settingsFile.exists()) {
      try {
        final txt = await settingsFile.readAsString();
        final map = jsonDecode(txt) as Map<String, dynamic>;
        final prefs = await SharedPreferencesAsync.instance;
        final existing = await prefs.snapshot();

        // Categorize keys
        const providerKeys = {
          'provider_configs_v1',
          'providers_order_v1',
          'pinned_models_v1',
          'assistants_v1',
          'assistant_tags_v1',
          'assistant_tag_map_v1',
          'assistant_tag_collapsed_v1',
          'search_services_v1',
          'quick_phrases_v1',
        };

        // Determine action for each key and apply
        for (final entry in map.entries) {
          final key = entry.key;
          final newValue = entry.value;

          final isProviderKey = providerKeys.contains(key);
          final action = isProviderKey ? options.providersAction : options.settingsAction;

          if (action == RestoreAction.ignore) {
            continue;
          } else if (action == RestoreAction.overwrite) {
             await prefs.restoreSingle(key, newValue);
          } else if (action == RestoreAction.merge) {
             // Merge logic (reused from legacy)
             // ... [Duplicate merge logic or abstract it] ...
             // For simplicity, we can reuse the specific merge logic for known keys,
             // and fallback to "preserve existing" for others.
             await _mergeSetting(prefs, existing, key, newValue);
          }
        }
      } catch (_) {}
    }

    // 2. Chats Restoration
    if (options.chatsAction != RestoreAction.ignore) {
      final chatsFile = File(p.join(extractDir.path, 'chats.json'));
      if (cfg.includeChats && await chatsFile.exists()) {
        try {
          final obj = jsonDecode(await chatsFile.readAsString()) as Map<String, dynamic>;
          // Parse data
          final convs = (obj['conversations'] as List?)
                  ?.map((e) => Conversation.fromJson((e as Map).cast<String, dynamic>()))
                  .toList() ?? const [];
          final msgs = (obj['messages'] as List?)
                  ?.map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
                  .toList() ?? const [];
          final toolEvents = ((obj['toolEvents'] as Map?) ?? const <String, dynamic>{})
              .map((k, v) => MapEntry(k.toString(), (v as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList()));
          final geminiThoughtSigs = ((obj['geminiThoughtSigs'] as Map?) ?? const <String, dynamic>{})
              .map((k, v) => MapEntry(k.toString(), v.toString()));

          if (options.chatsAction == RestoreAction.overwrite) {
             await chatService.clearAllData();
             await _restoreChats(convs, msgs, toolEvents, geminiThoughtSigs, overwrite: true);
          } else {
             // Merge
             await _restoreChats(convs, msgs, toolEvents, geminiThoughtSigs, overwrite: false);
          }
        } catch (_) {}
      }
    }

    // 3. Files Restoration
    if (options.filesAction != RestoreAction.ignore && cfg.includeFiles) {
      final isOverwrite = options.filesAction == RestoreAction.overwrite;
      
      // Uploads
      await _restoreDirectory(
        Directory(p.join(extractDir.path, 'upload')),
        await _getUploadDir(),
        overwrite: isOverwrite
      );
      
      // Images
      await _restoreDirectory(
        Directory(p.join(extractDir.path, 'images')),
        await _getImagesDir(),
        overwrite: isOverwrite
      );
      
      // Avatars
      await _restoreDirectory(
        Directory(p.join(extractDir.path, 'avatars')),
        await _getAvatarsDir(),
        overwrite: isOverwrite
      );
    }

    try { await extractDir.delete(recursive: true); } catch (_) {}
  }
  
  /// Original logic for full overwrite (renamed)
  Future<void> _legacyRestoreFromBackupFile(File file, WebDavConfig cfg, {RestoreMode mode = RestoreMode.overwrite}) async {
    // Extract to temp
    final tmp = await _ensureTempDir();
    final extractDir = Directory(p.join(tmp.path, 'restore_legacy_${DateTime.now().millisecondsSinceEpoch}'));
    await extractDir.create(recursive: true);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final entry in archive) {
      final normalized = entry.name.replaceAll('\\', '/');
      final parts = normalized.split('/').where((seg) => seg.isNotEmpty && seg != '.' && seg != '..').toList();
      final outPath = p.joinAll([extractDir.path, ...parts]);
      if (entry.isFile) {
        final outFile = File(outPath)..createSync(recursive: true);
        outFile.writeAsBytesSync(entry.content as List<int>);
      } else {
        Directory(outPath).createSync(recursive: true);
      }
    }

    // Restore settings
    final settingsFile = File(p.join(extractDir.path, 'settings.json'));
    if (await settingsFile.exists()) {
      try {
        final txt = await settingsFile.readAsString();
        final map = jsonDecode(txt) as Map<String, dynamic>;
        final prefs = await SharedPreferencesAsync.instance;
        if (mode == RestoreMode.overwrite) {
          await prefs.restore(map);
        } else {
          final existing = await prefs.snapshot();
          for (final entry in map.entries) {
            await _mergeSetting(prefs, existing, entry.key, entry.value);
          }
        }
      } catch (_) {}
    }

    // Restore chats
    final chatsFile = File(p.join(extractDir.path, 'chats.json'));
    if (cfg.includeChats && await chatsFile.exists()) {
      try {
        final obj = jsonDecode(await chatsFile.readAsString()) as Map<String, dynamic>;
        final convs = (obj['conversations'] as List?)?.map((e) => Conversation.fromJson((e as Map).cast<String, dynamic>())).toList() ?? const [];
        final msgs = (obj['messages'] as List?)?.map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>())).toList() ?? const [];
        final toolEvents = ((obj['toolEvents'] as Map?) ?? const <String, dynamic>{}).map((k, v) => MapEntry(k.toString(), (v as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList()));
        final geminiThoughtSigs = ((obj['geminiThoughtSigs'] as Map?) ?? const <String, dynamic>{}).map((k, v) => MapEntry(k.toString(), v.toString()));
        
        await _restoreChats(convs, msgs, toolEvents, geminiThoughtSigs, overwrite: mode == RestoreMode.overwrite);
      } catch (_) {}
    }

    // Restore files
    if (cfg.includeFiles) {
       final isOverwrite = mode == RestoreMode.overwrite;
       await _restoreDirectory(Directory(p.join(extractDir.path, 'upload')), await _getUploadDir(), overwrite: isOverwrite);
       await _restoreDirectory(Directory(p.join(extractDir.path, 'images')), await _getImagesDir(), overwrite: isOverwrite);
       await _restoreDirectory(Directory(p.join(extractDir.path, 'avatars')), await _getAvatarsDir(), overwrite: isOverwrite);
    }

    try { await extractDir.delete(recursive: true); } catch (_) {}
  }

  // Helper to reuse merge logic
  Future<void> _mergeSetting(SharedPreferencesAsync prefs, Map<String, dynamic> existing, String key, dynamic newValue) async {
    // Keys that should be merged as JSON arrays/objects
    const mergeableKeys = {
      'assistants_v1', 'provider_configs_v1', 'pinned_models_v1', 'providers_order_v1',
      'search_services_v1', 'assistant_tags_v1', 'assistant_tag_map_v1', 'assistant_tag_collapsed_v1'
    };

    if (mergeableKeys.contains(key)) {
      if (key == 'assistants_v1' && existing.containsKey(key)) {
        try {
          final existingAssistants = jsonDecode(existing[key] as String) as List;
          final newAssistants = jsonDecode(newValue as String) as List;
          final assistantMap = <String, Map<String, dynamic>>{};
          for (final a in existingAssistants) {
            if (a is Map && a.containsKey('id')) assistantMap[a['id'].toString()] = Map<String, dynamic>.from(a as Map);
          }
          for (final a in newAssistants) {
            if (a is Map && a.containsKey('id')) {
              final id = a['id'].toString();
              final incoming = Map<String, dynamic>.from(a as Map);
              if (!assistantMap.containsKey(id)) {
                assistantMap[id] = incoming;
                continue;
              }
              final local = assistantMap[id]!;
              final merged = <String, dynamic>{...local, ...incoming};
              // Protect avatar and background
              final localAvatar = (local['avatar'] ?? '').toString();
              if (localAvatar.trim().isNotEmpty) merged['avatar'] = localAvatar;
              else merged['avatar'] = incoming['avatar'];
              final localBg = (local['background'] ?? '').toString();
              if (localBg.trim().isNotEmpty) merged['background'] = localBg;
              else merged['background'] = incoming['background'];
              
              assistantMap[id] = merged;
            }
          }
          await prefs.restoreSingle(key, jsonEncode(assistantMap.values.toList()));
        } catch (_) {}
      } else if (key == 'provider_configs_v1' && existing.containsKey(key)) {
        try {
          final existingConfigs = jsonDecode(existing[key] as String) as Map<String, dynamic>;
          final newConfigs = jsonDecode(newValue as String) as Map<String, dynamic>;
          final mergedConfigs = {...existingConfigs, ...newConfigs};
          await prefs.restoreSingle(key, jsonEncode(mergedConfigs));
        } catch (_) {}
      } else if (key == 'pinned_models_v1' && existing.containsKey(key)) {
        try {
          final existingModels = jsonDecode(existing[key] as String) as List;
          final newModels = jsonDecode(newValue as String) as List;
          final modelSet = <String>{};
          for (final m in existingModels) if (m is String) modelSet.add(m);
          for (final m in newModels) if (m is String) modelSet.add(m);
          await prefs.restoreSingle(key, jsonEncode(modelSet.toList()));
        } catch (_) {}
      } else if (key == 'assistant_tags_v1') {
         try {
           final existingList = (existing[key] == null || existing[key] == '') ? [] : jsonDecode(existing[key]);
           final newList = (newValue == null || newValue == '') ? [] : jsonDecode(newValue);
           final tagById = <String, Map>{};
           final order = <String>[];
           for (final e in existingList) { if (e['id']!=null) { tagById[e['id'].toString()] = e; order.add(e['id'].toString()); } }
           for (final e in newList) {
             if (e['id']!=null && !tagById.containsKey(e['id'].toString())) {
               tagById[e['id'].toString()] = e; order.add(e['id'].toString());
             }
           }
           final merged = order.map((id) => tagById[id]).toList();
           await prefs.restoreSingle(key, jsonEncode(merged));
         } catch (_) {}
      } else if (key == 'assistant_tag_map_v1' || key == 'assistant_tag_collapsed_v1') {
         try {
           final existingMap = (existing[key] == null || existing[key] == '') ? {} : jsonDecode(existing[key]);
           final newMap = (newValue == null || newValue == '') ? {} : jsonDecode(newValue);
           final Map<String, dynamic> merged = {...newMap, ...existingMap}; // Prefer existing
           await prefs.restoreSingle(key, jsonEncode(merged));
         } catch (_) {}
      } else if ((key == 'providers_order_v1' || key == 'search_services_v1') && existing.containsKey(key)) {
        // Prefer imported order
        await prefs.restoreSingle(key, newValue);
      } else {
        await prefs.restoreSingle(key, newValue);
      }
    } else if (!existing.containsKey(key)) {
      // Non-mergeable: only add if missing
      await prefs.restoreSingle(key, newValue);
    }
  }

  // Helper for chats restore logic
  Future<void> _restoreChats(
    List<Conversation> convs,
    List<ChatMessage> msgs,
    Map<String, List<Map<String, dynamic>>> toolEvents,
    Map<String, String> geminiThoughtSigs,
    {required bool overwrite}
  ) async {
    if (overwrite) {
       await chatService.clearAllData();
       final byConv = <String, List<ChatMessage>>{};
       for (final m in msgs) { (byConv[m.conversationId] ??= []).add(m); }
       for (final c in convs) { await chatService.restoreConversation(c, byConv[c.id] ?? []); }
       for (final e in toolEvents.entries) { try{await chatService.setToolEvents(e.key, e.value);}catch(_){} }
       for (final e in geminiThoughtSigs.entries) { try{await chatService.setGeminiThoughtSignature(e.key, e.value);}catch(_){} }
    } else {
      final existingConvs = chatService.getAllConversations();
      final existingConvIds = existingConvs.map((c) => c.id).toSet();
      final existingMsgIds = <String>{};
      for(final c in existingConvs) existingMsgIds.addAll(chatService.getMessages(c.id).map((m)=>m.id));
      
      final byConv = <String, List<ChatMessage>>{};
      for (final m in msgs) { if(!existingMsgIds.contains(m.id)) (byConv[m.conversationId] ??= []).add(m); }

      for (final c in convs) {
        if (!existingConvIds.contains(c.id)) {
          await chatService.restoreConversation(c, byConv[c.id] ?? []);
        } else if (byConv.containsKey(c.id)) {
          for (final msg in byConv[c.id]!) await chatService.addMessageDirectly(c.id, msg);
        }
      }
      for (final e in toolEvents.entries) { if(chatService.getToolEvents(e.key).isEmpty) try{await chatService.setToolEvents(e.key, e.value);}catch(_){} }
      for (final e in geminiThoughtSigs.entries) { if(chatService.getGeminiThoughtSignature(e.key)==null) try{await chatService.setGeminiThoughtSignature(e.key, e.value);}catch(_){} }
    }
  }
  
  // Helper for file/directory restore logic
  Future<void> _restoreDirectory(Directory src, Directory dst, {required bool overwrite}) async {
    if (!await src.exists()) return;
    
    if (overwrite) {
      if (await dst.exists()) {
        try { await dst.delete(recursive: true); } catch (_) {}
      }
      await dst.create(recursive: true);
      for (final ent in src.listSync(recursive: true)) {
        if (ent is File) {
          final rel = p.relative(ent.path, from: src.path);
          final target = File(p.join(dst.path, rel));
          await target.parent.create(recursive: true);
          await ent.copy(target.path);
        }
      }
    } else {
      // Merge: only copy if not exists
      if (!await dst.exists()) await dst.create(recursive: true);
      for (final ent in src.listSync(recursive: true)) {
        if (ent is File) {
          final rel = p.relative(ent.path, from: src.path);
          final target = File(p.join(dst.path, rel));
          if (!await target.exists()) {
            await target.parent.create(recursive: true);
            await ent.copy(target.path);
          }
        }
      }
    }
  }
}

// ===== SharedPreferences async snapshot/restore helpers =====
class SharedPreferencesAsync {
  SharedPreferencesAsync._();
  static SharedPreferencesAsync? _inst;
  // Local window state keys stay on device and are excluded from backups
  static const _localOnlyKeys = {
    'window_width_v1',
    'window_height_v1',
    'window_pos_x_v1',
    'window_pos_y_v1',
    'window_maximized_v1',
  };

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
      if (v is bool) await prefs.setBool(k, v);
      else if (v is int) await prefs.setInt(k, v);
      else if (v is double) await prefs.setDouble(k, v);
      else if (v is String) await prefs.setString(k, v);
      else if (v is List) {
        await prefs.setStringList(k, v.whereType<String>().toList());
      }
    }
  }
  
  Future<void> restoreSingle(String key, dynamic value) async {
    if (_localOnlyKeys.contains(key)) return;
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    else if (value is int) await prefs.setInt(key, value);
    else if (value is double) await prefs.setDouble(key, value);
    else if (value is String) await prefs.setString(key, value);
    else if (value is List) {
      await prefs.setStringList(key, value.whereType<String>().toList());
    }
  }
}
