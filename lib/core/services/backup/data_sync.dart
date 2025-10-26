import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

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
    final tmp = await getTemporaryDirectory();
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
            final fileBytes = await ent.readAsBytes();
            final archiveFile = ArchiveFile(p.join('upload', rel), fileBytes.length, fileBytes);
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
            final fileBytes = await ent.readAsBytes();
            final archiveFile = ArchiveFile(p.join('avatars', rel), fileBytes.length, fileBytes);
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
            final fileBytes = await ent.readAsBytes();
            final archiveFile = ArchiveFile(p.join('images', rel), fileBytes.length, fileBytes);
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

  Future<void> restoreFromWebDav(WebDavConfig cfg, BackupFileItem item, {RestoreMode mode = RestoreMode.overwrite}) async {
    final res = await http.get(item.href, headers: _authHeaders(cfg));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Download failed: ${res.statusCode}');
    }
    if (kIsWeb) {
      await _restoreFromZipBytes(res.bodyBytes, cfg, mode: mode);
      return;
    }
    final tmpDir = await getTemporaryDirectory();
    final file = File(p.join(tmpDir.path, item.displayName));
    await file.writeAsBytes(res.bodyBytes);
    await _restoreFromBackupFile(file, cfg, mode: mode);
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

  Future<void> restoreFromLocalFile(File file, WebDavConfig cfg, {RestoreMode mode = RestoreMode.overwrite}) async {
    if (!await file.exists()) throw Exception('备份文件不存在');
    await _restoreFromBackupFile(file, cfg, mode: mode);
  }

  // For web: restore directly from bytes (selected via FilePicker for web)
  Future<void> restoreFromLocalBytes(Uint8List bytes, WebDavConfig cfg, {RestoreMode mode = RestoreMode.overwrite}) async {
    await _restoreFromZipBytes(bytes, cfg, mode: mode);
  }

  // ===== Internal helpers =====
  Future<File> _writeTempText(String name, String content) async {
    final tmp = await getTemporaryDirectory();
    final f = File(p.join(tmp.path, name));
    await f.writeAsString(content);
    return f;
  }

  Future<Directory> _getUploadDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'upload'));
  }

  Future<Directory> _getImagesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'images'));
  }

  Future<Directory> _getAvatarsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'avatars'));
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
    for (final c in conversations) {
      final msgs = chatService.getMessages(c.id);
      allMsgs.addAll(msgs);
      for (final m in msgs) {
        if (m.role == 'assistant') {
          final ev = chatService.getToolEvents(m.id);
          if (ev.isNotEmpty) toolEvents[m.id] = ev;
        }
      }
    }
    final obj = {
      'version': 1,
      'conversations': conversations.map((c) => c.toJson()).toList(),
      'messages': allMsgs.map((m) => m.toJson()).toList(),
      'toolEvents': toolEvents,
    };
    return jsonEncode(obj);
  }

  Future<void> _restoreFromBackupFile(File file, WebDavConfig cfg, {RestoreMode mode = RestoreMode.overwrite}) async {
    // Extract to temp
    final tmp = await getTemporaryDirectory();
    final extractDir = Directory(p.join(tmp.path, 'restore_${DateTime.now().millisecondsSinceEpoch}'));
    await extractDir.create(recursive: true);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final entry in archive) {
      final outPath = p.join(extractDir.path, entry.name);
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
          // For overwrite mode, restore all settings
          await prefs.restore(map);
        } else {
          // For merge mode, intelligently merge settings
          final existing = await prefs.snapshot();
          
          // Keys that should be merged as JSON arrays/objects
          const mergeableKeys = {
            'assistants_v1',       // Assistant configurations
            'provider_configs_v1', // Provider configurations
            'pinned_models_v1',    // Pinned models list
            'providers_order_v1',  // Provider order list
            'search_services_v1',  // Search services configuration
          };
          
          for (final entry in map.entries) {
            final key = entry.key;
            final newValue = entry.value;
            
            if (mergeableKeys.contains(key)) {
              // Special handling for mergeable configurations
              if (key == 'assistants_v1' && existing.containsKey(key)) {
                // Merge assistants by ID with field-level rules.
                // Preserve local avatar if already set to avoid clearing/overwriting.
                try {
                  final existingAssistants = jsonDecode(existing[key] as String) as List;
                  final newAssistants = jsonDecode(newValue as String) as List;
                  final assistantMap = <String, Map<String, dynamic>>{};

                  // Seed map with existing assistants
                  for (final a in existingAssistants) {
                    if (a is Map && a.containsKey('id')) {
                      // Store as mutable map<String, dynamic>
                      assistantMap[a['id'].toString()] = Map<String, dynamic>.from(a as Map);
                    }
                  }

                  // Merge with imported assistants
                  for (final a in newAssistants) {
                    if (a is Map && a.containsKey('id')) {
                      final id = a['id'].toString();
                      final incoming = Map<String, dynamic>.from(a as Map);

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
                        final s = incomingAvatar is String ? incomingAvatar : incomingAvatar?.toString();
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
                        final sb = incomingBg is String ? incomingBg : incomingBg?.toString();
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
                  await prefs.restoreSingle(key, jsonEncode(mergedAssistants));
                } catch (e) {
                  // If merge fails, keep existing
                }
              } else if (key == 'provider_configs_v1' && existing.containsKey(key)) {
                // Merge provider configs: combine both maps
                try {
                  final existingConfigs = jsonDecode(existing[key] as String) as Map<String, dynamic>;
                  final newConfigs = jsonDecode(newValue as String) as Map<String, dynamic>;
                  
                  // Merge configs, new values override existing for same keys
                  final mergedConfigs = {...existingConfigs, ...newConfigs};
                  await prefs.restoreSingle(key, jsonEncode(mergedConfigs));
                } catch (e) {
                  // If merge fails, keep existing
                }
              } else if (key == 'pinned_models_v1' && existing.containsKey(key)) {
                // Merge pinned models: combine and deduplicate
                try {
                  final existingModels = jsonDecode(existing[key] as String) as List;
                  final newModels = jsonDecode(newValue as String) as List;
                  final modelSet = <String>{};
                  
                  // Add all models to set for deduplication
                  for (final model in existingModels) {
                    if (model is String) modelSet.add(model);
                  }
                  for (final model in newModels) {
                    if (model is String) modelSet.add(model);
                  }
                  
                  await prefs.restoreSingle(key, jsonEncode(modelSet.toList()));
                } catch (e) {
                  // If merge fails, keep existing
                }
              } else if ((key == 'providers_order_v1' || key == 'search_services_v1') && existing.containsKey(key)) {
                // For these lists, prefer the imported version if different
                // This ensures new providers/services are properly ordered
                await prefs.restoreSingle(key, newValue);
              } else {
                // For new keys, add them
                await prefs.restoreSingle(key, newValue);
              }
            } else if (!existing.containsKey(key)) {
              // For non-mergeable keys, only add if not existing
              await prefs.restoreSingle(key, newValue);
            }
            // Skip existing non-mergeable keys to preserve user preferences
          }
        }
      } catch (_) {}
    }

    // Restore chats
    final chatsFile = File(p.join(extractDir.path, 'chats.json'));
    if (cfg.includeChats && await chatsFile.exists()) {
      try {
        final obj = jsonDecode(await chatsFile.readAsString()) as Map<String, dynamic>;
        final convs = (obj['conversations'] as List?)
                ?.map((e) => Conversation.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            const <Conversation>[];
        final msgs = (obj['messages'] as List?)
                ?.map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            const <ChatMessage>[];
        final toolEvents = ((obj['toolEvents'] as Map?) ?? const <String, dynamic>{})
            .map((k, v) => MapEntry(k.toString(), (v as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList()));
        
        if (mode == RestoreMode.overwrite) {
          // Clear and restore via ChatService
          await chatService.clearAllData();
          final byConv = <String, List<ChatMessage>>{};
          for (final m in msgs) {
            (byConv[m.conversationId] ??= <ChatMessage>[]).add(m);
          }
          for (final c in convs) {
            final list = byConv[c.id] ?? const <ChatMessage>[];
            await chatService.restoreConversation(c, list);
          }
          // Tool events
          for (final entry in toolEvents.entries) {
            try { await chatService.setToolEvents(entry.key, entry.value); } catch (_) {}
          }
        } else {
          // Merge mode: Add only non-existing conversations and messages
          final existingConvs = chatService.getAllConversations();
          final existingConvIds = existingConvs.map((c) => c.id).toSet();
          
          // Create a map of message IDs to avoid duplicates
          final existingMsgIds = <String>{};
          for (final conv in existingConvs) {
            final messages = chatService.getMessages(conv.id);
            existingMsgIds.addAll(messages.map((m) => m.id));
          }
          
          // Group messages by conversation
          final byConv = <String, List<ChatMessage>>{};
          for (final m in msgs) {
            if (!existingMsgIds.contains(m.id)) {
              (byConv[m.conversationId] ??= <ChatMessage>[]).add(m);
            }
          }
          
          // Restore non-existing conversations and their messages
          for (final c in convs) {
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
              try { await chatService.setToolEvents(entry.key, entry.value); } catch (_) {}
            }
          }
        }
      } catch (_) {}
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
            try { await dst.delete(recursive: true); } catch (_) {}
          }
          await dst.create(recursive: true);
          for (final ent in uploadSrc.listSync(recursive: true)) {
            if (ent is File) {
              final rel = p.relative(ent.path, from: uploadSrc.path);
              final target = File(p.join(dst.path, rel));
              await target.parent.create(recursive: true);
              await ent.copy(target.path);
            }
          }
        }

        // Restore images directory
        final imagesSrc = Directory(p.join(extractDir.path, 'images'));
        if (await imagesSrc.exists()) {
          final dst = await _getImagesDir();
          if (await dst.exists()) {
            try { await dst.delete(recursive: true); } catch (_) {}
          }
          await dst.create(recursive: true);
          for (final ent in imagesSrc.listSync(recursive: true)) {
            if (ent is File) {
              final rel = p.relative(ent.path, from: imagesSrc.path);
              final target = File(p.join(dst.path, rel));
              await target.parent.create(recursive: true);
              await ent.copy(target.path);
            }
          }
        }

        // Restore avatars directory
        final avatarsSrc = Directory(p.join(extractDir.path, 'avatars'));
        if (await avatarsSrc.exists()) {
          final dst = await _getAvatarsDir();
          if (await dst.exists()) {
            try { await dst.delete(recursive: true); } catch (_) {}
          }
          await dst.create(recursive: true);
          for (final ent in avatarsSrc.listSync(recursive: true)) {
            if (ent is File) {
              final rel = p.relative(ent.path, from: avatarsSrc.path);
              final target = File(p.join(dst.path, rel));
              await target.parent.create(recursive: true);
              await ent.copy(target.path);
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
                await target.parent.create(recursive: true);
                await ent.copy(target.path);
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
                await target.parent.create(recursive: true);
                await ent.copy(target.path);
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
                await target.parent.create(recursive: true);
                await ent.copy(target.path);
              }
            }
          }
        }
      }
    }

    try { await extractDir.delete(recursive: true); } catch (_) {}
  }

  Future<void> _restoreFromZipBytes(Uint8List bytes, WebDavConfig cfg, {RestoreMode mode = RestoreMode.overwrite}) async {
    // Decode archive and process JSON parts directly; skip file copies on web
    final archive = ZipDecoder().decodeBytes(bytes);

    String? readText(String name) {
      try {
        final f = archive.findFile(name);
        if (f == null) return null;
        return utf8.decode(f.content as List<int>);
      } catch (_) {
        return null;
      }
    }

    // Settings
    final settingsTxt = readText('settings.json');
    if (settingsTxt != null) {
      try {
        final map = jsonDecode(settingsTxt) as Map<String, dynamic>;
        final prefs = await SharedPreferencesAsync.instance;
        if (mode == RestoreMode.overwrite) {
          await prefs.restore(map);
        } else {
          final existing = await prefs.snapshot();
          for (final entry in map.entries) {
            if (!existing.containsKey(entry.key)) {
              await prefs.restoreSingle(entry.key, entry.value);
            }
          }
        }
      } catch (_) {}
    }

    // Chats
    final chatsTxt = readText('chats.json');
    if (cfg.includeChats && chatsTxt != null) {
      try {
        final obj = jsonDecode(chatsTxt) as Map<String, dynamic>;
        final convs = (obj['conversations'] as List?)?.map((e) => Conversation.fromJson((e as Map).cast<String, dynamic>())).toList() ?? const <Conversation>[];
        final msgs = (obj['messages'] as List?)?.map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>())).toList() ?? const <ChatMessage>[];
        final toolEvents = ((obj['toolEvents'] as Map?) ?? const <String, dynamic>{}).map((k, v) => MapEntry(k.toString(), (v as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList()));

        if (mode == RestoreMode.overwrite) {
          await chatService.clearAllData();
          final byConv = <String, List<ChatMessage>>{};
          for (final m in msgs) { (byConv[m.conversationId] ??= <ChatMessage>[]).add(m); }
          for (final c in convs) { await chatService.restoreConversation(c, byConv[c.id] ?? const <ChatMessage>[]); }
          for (final entry in toolEvents.entries) { try { await chatService.setToolEvents(entry.key, entry.value); } catch (_) {} }
        } else {
          final existingConvs = chatService.getAllConversations();
          final existingConvIds = existingConvs.map((c) => c.id).toSet();
          final existingMsgIds = <String>{};
          for (final conv in existingConvs) { existingMsgIds.addAll(chatService.getMessages(conv.id).map((m) => m.id)); }
          final byConv = <String, List<ChatMessage>>{};
          for (final m in msgs) { if (!existingMsgIds.contains(m.id)) { (byConv[m.conversationId] ??= <ChatMessage>[]).add(m); } }
          for (final c in convs) {
            if (!existingConvIds.contains(c.id)) {
              await chatService.restoreConversation(c, byConv[c.id] ?? const <ChatMessage>[]);
            } else if (byConv.containsKey(c.id)) {
              for (final msg in byConv[c.id]!) { await chatService.addMessageDirectly(c.id, msg); }
            }
          }
          for (final entry in toolEvents.entries) { final e = chatService.getToolEvents(entry.key); if (e.isEmpty) { try { await chatService.setToolEvents(entry.key, entry.value); } catch (_) {} } }
        }
      } catch (_) {}
    }
  }
}

// ===== SharedPreferences async snapshot/restore helpers =====
class SharedPreferencesAsync {
  SharedPreferencesAsync._();
  static SharedPreferencesAsync? _inst;
  static Future<SharedPreferencesAsync> get instance async {
    _inst ??= SharedPreferencesAsync._();
    return _inst!;
  }

  Future<Map<String, dynamic>> snapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final map = <String, dynamic>{};
    for (final k in keys) {
      map[k] = prefs.get(k);
    }
    return map;
  }

  Future<void> restore(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in data.entries) {
      final k = entry.key;
      final v = entry.value;
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
