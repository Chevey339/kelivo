import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/backup.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../providers/settings_provider.dart';
import '../chat/chat_service.dart';
import '../../../utils/app_directories.dart';

class CherryImportResult {
  final int providers;
  final int assistants;
  final int conversations;
  final int messages;
  final int files;
  const CherryImportResult({
    required this.providers,
    required this.assistants,
    required this.conversations,
    required this.messages,
    required this.files,
  });
}

class CherryImporter {
  CherryImporter._();

  // Persisted keys used by SettingsProvider/AssistantProvider
  static const String _providersKey = 'provider_configs_v1';
  static const String _providersOrderKey = 'providers_order_v1';
  static const String _assistantsKey = 'assistants_v1';

  static Future<CherryImportResult> importFromCherryStudio({
    required File file,
    required RestoreMode mode,
    required SettingsProvider settings,
    required ChatService chatService,
    required String defaultConversationTitle,
  }) async {
    // 1) Load JSON from ZIP/BAK (best-effort)
    final Map<String, dynamic> root = await _readCherryBackupFile(file);

    // 2) Basic validation
    final version = (root['version'] as num?)?.toInt() ?? 0;
    if (version < 2) {
      throw Exception('Unsupported Cherry backup version: $version');
    }

    // 3) Parse localStorage persist:cherry-studio (Redux persist)
    final localStorage =
        (root['localStorage'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v),
        ) ??
        const <String, dynamic>{};
    final persistStr = (localStorage['persist:cherry-studio'] ?? '') as String;
    if (persistStr.isEmpty) {
      throw Exception('Missing localStorage["persist:cherry-studio"]');
    }
    late Map<String, dynamic> persistObj;
    try {
      persistObj = jsonDecode(persistStr) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid persist:cherry-studio JSON');
    }

    // slices in persist are also JSON-encoded strings
    Map<String, dynamic> assistantsSlice = const {};
    Map<String, dynamic> llmSlice = const {};
    try {
      final aStr = (persistObj['assistants'] ?? '') as String;
      if (aStr.isNotEmpty) {
        assistantsSlice = jsonDecode(aStr) as Map<String, dynamic>;
      }
    } catch (_) {}
    try {
      final lStr = (persistObj['llm'] ?? '') as String;
      if (lStr.isNotEmpty) {
        llmSlice = jsonDecode(lStr) as Map<String, dynamic>;
      }
    } catch (_) {}

    final List<dynamic> cherryProviders =
        (llmSlice['providers'] as List?) ?? const <dynamic>[];
    final Map<String, dynamic> assistantsRoot = assistantsSlice;
    final List<dynamic> cherryAssistants =
        (assistantsRoot['assistants'] as List?) ?? const <dynamic>[];

    // 4) IndexedDB
    final indexedDB =
        (root['indexedDB'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ??
        const <String, dynamic>{};
    final List<dynamic> cherryFiles =
        (indexedDB['files'] as List?) ?? const <dynamic>[];
    final List<dynamic> cherryTopicsWithMessages =
        (indexedDB['topics'] as List?) ?? const <dynamic>[];
    final List<dynamic> cherryMessageBlocks =
        (indexedDB['message_blocks'] as List?) ?? const <dynamic>[];

    // Build a map of topic metadata from assistants[].topics[]
    final Map<String, Map<String, dynamic>> topicMeta =
        <String, Map<String, dynamic>>{};
    for (final a in cherryAssistants) {
      if (a is! Map) continue;
      final topics = (a['topics'] as List?) ?? const <dynamic>[];
      for (final t in topics) {
        if (t is Map && t['id'] != null) {
          final id = t['id'].toString();
          topicMeta[id] = t.map((k, v) => MapEntry(k.toString(), v));
          // Ensure assistantId is present (avoid null index warning by using local var)
          final tm = topicMeta[id]!;
          final dynamic cand = t['assistantId'] ?? a['id'];
          if (cand != null) tm['assistantId'] = cand.toString();
        }
      }
    }

    // Build a map of topicId -> messages
    // Also keep a best-effort topic meta map from IndexedDB topics (some exports
    // don't include assistants[].topics[] or omit assistantId/name there).
    final Map<String, Map<String, dynamic>> topicMetaFromIndexedDb =
        <String, Map<String, dynamic>>{};
    final Map<String, List<Map<String, dynamic>>> topicMessages =
        <String, List<Map<String, dynamic>>>{};
    for (final e in cherryTopicsWithMessages) {
      if (e is! Map) continue;
      final mm = e.map((k, v) => MapEntry(k.toString(), v));
      final id = (mm['id'] ?? '').toString();
      if (id.isEmpty) continue;
      // Meta fallback (strip messages to avoid large maps)
      final meta = <String, dynamic>{}..addAll(mm);
      meta.remove('messages');
      // Some exports may use 'title' for topic name
      if ((meta['name'] == null || meta['name'].toString().trim().isEmpty) &&
          meta['title'] != null &&
          meta['title'].toString().trim().isNotEmpty) {
        meta['name'] = meta['title'].toString();
      }
      // Normalize assistantId variants
      dynamic candAid = meta['assistantId'] ?? meta['assistant_id'];
      if (candAid is Map) {
        final m = candAid.map((k, v) => MapEntry(k.toString(), v));
        candAid = m['id'] ?? m['assistantId'] ?? m['assistant_id'];
      }
      if (candAid != null && candAid.toString().trim().isNotEmpty) {
        meta['assistantId'] = candAid.toString();
      }
      topicMetaFromIndexedDb[id] = meta.map(
        (k, v) => MapEntry(k.toString(), v),
      );

      final msgs = (mm['messages'] as List?) ?? const <dynamic>[];
      topicMessages[id] = [
        for (final m in msgs)
          if (m is Map) m.map((k, v) => MapEntry(k.toString(), v)),
      ];
    }

    // Build a map of messageId -> reconstructed text from message_blocks (for cases where message.content is empty)
    final Map<String, String> blockTextByMessageId = <String, String>{};
    for (final b in cherryMessageBlocks) {
      if (b is! Map) continue;
      final type = (b['type'] ?? '').toString();
      final messageId = (b['messageId'] ?? '').toString();
      if (messageId.isEmpty) continue;
      // Only include readable blocks
      if (type == 'main_text') {
        final content = (b['content'] ?? '').toString();
        if (content.isNotEmpty) {
          final prev = blockTextByMessageId[messageId];
          blockTextByMessageId[messageId] = prev == null || prev.isEmpty
              ? content
              : '$prev\n$content';
        }
      } else if (type == 'code') {
        final code = (b['content'] ?? '').toString();
        final lang = (b['language'] ?? '').toString();
        if (code.isNotEmpty) {
          final fenced =
              '```' + (lang.isNotEmpty ? lang : '') + "\n" + code + "\n```";
          final prev = blockTextByMessageId[messageId];
          blockTextByMessageId[messageId] = prev == null || prev.isEmpty
              ? fenced
              : '$prev\n$fenced';
        }
      } else if (type == 'error') {
        final err = (b['content'] ?? '').toString();
        if (err.isNotEmpty) {
          final tagged = '> Error\n> ' + err.replaceAll('\n', '\n> ');
          final prev = blockTextByMessageId[messageId];
          blockTextByMessageId[messageId] = prev == null || prev.isEmpty
              ? tagged
              : '$prev\n$tagged';
        }
      } else if (type == 'thinking') {
        // Optional: include as a collapsible-like section in plain text
        final think = (b['content'] ?? '').toString();
        if (think.isNotEmpty) {
          final wrapped = '<think>\n' + think + '\n</think>';
          final prev = blockTextByMessageId[messageId];
          blockTextByMessageId[messageId] = prev == null || prev.isEmpty
              ? wrapped
              : '$prev\n$wrapped';
        }
      }
    }

    // 5) Import providers into Settings (SharedPreferences)
    final importedProviders = await _importProviders(
      cherryProviders,
      settings,
      mode,
    );

    // 6) Import assistants (persist to SharedPreferences, restart recommended)
    final importedAssistants = await _importAssistants(cherryAssistants, mode);

    // Determine a stable fallback assistant id to avoid creating assistantId==null
    // conversations (which would be treated as "global" and shown under any assistant).
    String? fallbackAssistantId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_assistantsKey);
      if (raw != null && raw.isNotEmpty) {
        final obj = jsonDecode(raw);
        if (obj is List) {
          for (final e in obj) {
            if (e is Map && e['id'] != null) {
              final id = e['id'].toString().trim();
              if (id.isNotEmpty) {
                fallbackAssistantId = id;
                break;
              }
            }
          }
        }
      }
    } catch (_) {
      // best-effort
    }
    if ((fallbackAssistantId ?? '').trim().isEmpty) {
      // Fallback to the first assistant id from the backup itself.
      for (final a in cherryAssistants) {
        if (a is! Map) continue;
        final id = (a['id'] ?? '').toString().trim();
        if (id.isNotEmpty) {
          fallbackAssistantId = id;
          break;
        }
      }
    }

    // If overwrite, clear chats/files BEFORE writing any uploads to avoid deletion later
    if (!chatService.initialized) {
      await chatService.init();
    }
    if (mode == RestoreMode.overwrite) {
      await chatService.clearAllData();
    }

    // 7) Prepare files (only if referenced by messages)
    final filesById = <String, Map<String, dynamic>>{
      for (final f in cherryFiles)
        if (f is Map && f['id'] != null)
          f['id'].toString(): f.map((k, v) => MapEntry(k.toString(), v)),
    };

    // Precompute used file ids
    final usedFileIds = <String>{};
    for (final entry in topicMessages.entries) {
      for (final m in entry.value) {
        final files = (m['files'] as List?) ?? const <dynamic>[];
        for (final rf in files) {
          if (rf is Map && rf['id'] != null)
            usedFileIds.add(rf['id'].toString());
        }
      }
    }

    // Also include files referenced by message_blocks when a 'file' object is present
    for (final b in cherryMessageBlocks) {
      if (b is! Map) continue;
      final fileObj = (b['file'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), v),
      );
      final fid = (fileObj?['id'] ?? '').toString();
      if (fid.isNotEmpty) usedFileIds.add(fid);
    }

    // Write referenced files into Documents/upload and build path map
    final pathsByFileId = await _materializeFiles(
      filesById,
      usedFileIds,
      backupArchive: file,
    );

    // Build mapping of extra attachments (images/files) in message_blocks (not represented in message.files)
    final Map<String, List<_PendingAttachmentRef>> pendingAttachmentsByMessage =
        <String, List<_PendingAttachmentRef>>{};
    for (final b in cherryMessageBlocks) {
      if (b is! Map) continue;
      final type = (b['type'] ?? '').toString();
      final messageId = (b['messageId'] ?? '').toString();
      if (messageId.isEmpty) continue;
      final fileObj = (b['file'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), v),
      );
      final url = (b['url'] ?? '').toString();
      final isImageType =
          type.toLowerCase().contains('image') ||
          (fileObj?['type']?.toString().toLowerCase().startsWith('image') ??
              false);
      if (fileObj != null && (fileObj['id'] ?? '').toString().isNotEmpty) {
        (pendingAttachmentsByMessage[messageId] ??= <_PendingAttachmentRef>[])
            .add(
              _PendingAttachmentRef(
                fileId: (fileObj['id'] ?? '').toString(),
                name: (fileObj['origin_name'] ?? fileObj['name'] ?? '')
                    .toString(),
                mime: (fileObj['type'] ?? '').toString(),
                isImage: isImageType,
              ),
            );
      } else if (url.isNotEmpty) {
        if (url.startsWith('data:image')) {
          (pendingAttachmentsByMessage[messageId] ??= <_PendingAttachmentRef>[])
              .add(_PendingAttachmentRef(dataUrl: url, isImage: true));
        } else {
          (pendingAttachmentsByMessage[messageId] ??= <_PendingAttachmentRef>[])
              .add(_PendingAttachmentRef(url: url, isImage: isImageType));
        }
      }
    }

    // 8) Import topics & messages into ChatService
    final convCountAndMsgCount = await _importConversations(
      topicMeta: topicMeta,
      topicMetaFromIndexedDb: topicMetaFromIndexedDb,
      topicMessages: topicMessages,
      filePaths: pathsByFileId,
      chatService: chatService,
      mode: mode,
      blockTexts: blockTextByMessageId,
      pendingAttachmentsByMessage: pendingAttachmentsByMessage,
      fallbackAssistantId: fallbackAssistantId,
      defaultConversationTitle: defaultConversationTitle,
    );

    return CherryImportResult(
      providers: importedProviders,
      assistants: importedAssistants,
      conversations: convCountAndMsgCount.$1,
      messages: convCountAndMsgCount.$2,
      files: pathsByFileId.length + convCountAndMsgCount.$3,
    );
  }

  // ---------- helpers ----------

  static Future<Map<String, dynamic>> _readCherryBackupFile(File file) async {
    final bytes = await file.readAsBytes();

    // Helper to verify structure looks like Cherry backup
    Map<String, dynamic>? _tryParseBackupJson(String text) {
      try {
        final obj = jsonDecode(text) as Map<String, dynamic>;
        if (obj.containsKey('localStorage') && obj.containsKey('indexedDB')) {
          return obj;
        }
      } catch (_) {}
      return null;
    }

    // 1) Try as plain JSON text
    try {
      final content = await file.readAsString();
      final obj = _tryParseBackupJson(content);
      if (obj != null) return obj;
    } catch (_) {}

    // 2) Try ZIP: scan all file entries and pick the one that parses to expected JSON
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final entry in archive) {
        if (!entry.isFile) continue;
        try {
          final content = utf8.decode(
            entry.content as List<int>,
            allowMalformed: true,
          );
          final obj = _tryParseBackupJson(content);
          if (obj != null) return obj;
        } catch (_) {
          // skip non-text entries
        }
      }
    } catch (_) {}

    // 3) Try GZIP (some .bak may be gzip-compressed JSON)
    try {
      final gunzipped = GZipDecoder().decodeBytes(bytes, verify: false);
      final content = utf8.decode(gunzipped, allowMalformed: true);
      final obj = _tryParseBackupJson(content);
      if (obj != null) return obj;
    } catch (_) {}

    throw Exception('Unable to read Cherry backup file');
  }

  static Future<int> _importProviders(
    List<dynamic> cherryProviders,
    SettingsProvider settings,
    RestoreMode mode,
  ) async {
    // Build imported map id -> ProviderConfig JSON-like
    final imported = <String, Map<String, dynamic>>{};

    for (final p in cherryProviders) {
      if (p is! Map) continue;
      final id = (p['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final type = (p['type'] ?? '').toString().toLowerCase();
      final name = (p['name'] ?? id).toString();
      final apiKey = (p['apiKey'] ?? '').toString();
      final apiHostRaw = (p['apiHost'] ?? '').toString().trim();

      // Determine provider kind mapping
      String? kind;
      switch (type) {
        case 'openai':
          kind = 'openai';
          break;
        case 'anthropic':
          kind = 'claude';
          break;
        case 'gemini':
          kind = 'google';
          break;
        default:
          // default to OpenAI-compatible
          kind = 'openai';
      }

      // models list (ids only)
      final models = <String>[];
      final mlist = (p['models'] as List?) ?? const <dynamic>[];
      for (final m in mlist) {
        if (m is Map && m['id'] != null) models.add(m['id'].toString());
      }

      // Normalize baseUrl following Cherry Studio semantics:
      // - In Cherry, for OpenAI/Anthropic providers, if base_url DOES NOT end with '/', they default to appending '/v1'.
      // - Our importer previously kept the base as-is, which could miss '/v1' and break requests.
      // - Here we mirror Cherry's behavior on import for 'openai' and 'claude'.
      String base = apiHostRaw;
      if (base.isNotEmpty) {
        if (base.endsWith('/')) {
          // Trim trailing slash for consistency; user is responsible for including version if needed.
          base = base.substring(0, base.length - 1);
        } else {
          // If it's OpenAI/Claude/Google and no trailing slash, append default version unless a suffix already exists.
          final lower = base.toLowerCase();
          final hasVersionSuffix = RegExp(
            r'/v\d([a-z0-9._-]+)?$',
          ).hasMatch(lower);
          if (!hasVersionSuffix) {
            if (kind == 'google') {
              base = '$base/v1beta';
            } else if (kind == 'openai' || kind == 'claude') {
              base = '$base/v1';
            }
          }
        }
      }

      // Compose ProviderConfig json
      final map = <String, dynamic>{
        'id': id,
        'enabled': (p['enabled'] as bool?) ?? apiKey.isNotEmpty,
        'name': name,
        'apiKey': apiKey,
        'baseUrl': base.isNotEmpty
            ? base
            : (kind == 'google'
                  ? 'https://generativelanguage.googleapis.com/v1beta'
                  : (kind == 'claude'
                        ? 'https://api.anthropic.com/v1'
                        : 'https://api.openai.com/v1')),
        'providerType': kind == 'openai'
            ? 'openai'
            : kind == 'google'
            ? 'google'
            : 'claude',
        'chatPath': kind == 'openai' ? '/chat/completions' : null,
        'useResponseApi': kind == 'openai' ? false : null,
        'vertexAI': kind == 'google' ? false : null,
        'location': null,
        'projectId': null,
        'serviceAccountJson': null,
        'models': models,
        'modelOverrides': const <String, dynamic>{},
        'proxyEnabled': false,
        'proxyHost': '',
        'proxyPort': '8080',
        'proxyUsername': '',
        'proxyPassword': '',
        'multiKeyEnabled': false,
        'apiKeys': const <dynamic>[],
        'keyManagement': const <String, dynamic>{},
      };
      imported[id] = map;
    }

    final prefs = await SharedPreferences.getInstance();

    if (mode == RestoreMode.overwrite) {
      await prefs.setString(_providersKey, jsonEncode(imported));
      await prefs.setStringList(_providersOrderKey, imported.keys.toList());
      return imported.length;
    }

    // merge mode: merge into existing providers without removing any
    Map<String, dynamic> current = const <String, dynamic>{};
    try {
      final raw = prefs.getString(_providersKey);
      if (raw != null && raw.isNotEmpty) {
        current = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}

    final merged = <String, dynamic>{}..addAll(current);
    for (final entry in imported.entries) {
      if (!merged.containsKey(entry.key)) {
        merged[entry.key] = entry.value;
      } else {
        // Update with non-empty fields from imported
        final cur = (merged[entry.key] as Map).map(
          (k, v) => MapEntry(k.toString(), v),
        );
        final inc = entry.value;
        final next = Map<String, dynamic>.from(cur);
        void putIfNotEmpty(String k) {
          final v = inc[k];
          if (v == null) return;
          if (v is String && v.trim().isEmpty) return;
          next[k] = v;
        }

        for (final k in inc.keys) {
          putIfNotEmpty(k);
        }
        merged[entry.key] = next;
      }
    }

    await prefs.setString(_providersKey, jsonEncode(merged));

    // Merge providers order: append new ids at end, keep existing order
    final existedOrder =
        prefs.getStringList(_providersOrderKey) ?? const <String>[];
    final orderSet = existedOrder.toList();
    for (final id in imported.keys) {
      if (!orderSet.contains(id)) orderSet.add(id);
    }
    await prefs.setStringList(_providersOrderKey, orderSet);

    return imported.length;
  }

  static Future<int> _importAssistants(
    List<dynamic> cherryAssistants,
    RestoreMode mode,
  ) async {
    // Map to our Assistant JSON list (as stored by Assistant.encodeList)
    final out = <Map<String, dynamic>>[];
    for (final a in cherryAssistants) {
      if (a is! Map) continue;
      final id = (a['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final name = (a['name'] ?? id).toString();
      final prompt = (a['prompt'] ?? '').toString();
      final settings = (a['settings'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), v),
      );
      final model = (a['model'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), v),
      );

      final temperature = (settings?['temperature'] as num?)?.toDouble();
      final topP = (settings?['topP'] as num?)?.toDouble();
      final ctxCount = (settings?['contextCount'] as num?)?.toInt();
      final streamOutput = settings?['streamOutput'] as bool?;
      final enableMaxTokens = settings?['enableMaxTokens'] as bool? ?? false;
      final maxTokens = enableMaxTokens
          ? (settings?['maxTokens'] as num?)?.toInt()
          : null;

      final json = <String, dynamic>{
        'id': id,
        'name': name,
        'avatar': null,
        'useAssistantAvatar': false,
        'chatModelProvider': model?['provider']?.toString(),
        'chatModelId': model?['id']?.toString(),
        'temperature': temperature,
        'topP': topP,
        'contextMessageSize': ctxCount ?? 64,
        'limitContextMessages': true,
        'streamOutput': streamOutput ?? true,
        'thinkingBudget': null,
        'maxTokens': maxTokens,
        'systemPrompt': prompt,
        'messageTemplate': '{{ message }}',
        'mcpServerIds': const <String>[],
        'background': null,
        'deletable': true,
        'customHeaders': const <Map<String, String>>[],
        'customBody': const <Map<String, String>>[],
        'enableMemory': false,
        'enableRecentChatsReference': false,
      };
      out.add(json);
    }

    final prefs = await SharedPreferences.getInstance();
    if (mode == RestoreMode.overwrite) {
      await prefs.setString(_assistantsKey, jsonEncode(out));
      return out.length;
    }

    // merge: merge by id; update systemPrompt if provided, keep other local values
    List<dynamic> existing = const <dynamic>[];
    try {
      final raw = prefs.getString(_assistantsKey);
      if (raw != null && raw.isNotEmpty)
        existing = jsonDecode(raw) as List<dynamic>;
    } catch (_) {}
    final byId = <String, Map<String, dynamic>>{
      for (final e in existing)
        if (e is Map && e['id'] != null)
          e['id'].toString(): e.map((k, v) => MapEntry(k.toString(), v)),
    };
    for (final a in out) {
      final id = a['id'] as String;
      if (!byId.containsKey(id)) {
        byId[id] = a;
      } else {
        final local = byId[id]!;
        // Update prompt if incoming has non-empty
        final incPrompt = (a['systemPrompt'] as String?)?.trim() ?? '';
        if (incPrompt.isNotEmpty) local['systemPrompt'] = incPrompt;
        // Update model fields if provided
        if (a['chatModelProvider'] != null)
          local['chatModelProvider'] = a['chatModelProvider'];
        if (a['chatModelId'] != null) local['chatModelId'] = a['chatModelId'];
      }
    }
    final merged = byId.values.toList();
    await prefs.setString(_assistantsKey, jsonEncode(merged));
    return out.length;
  }

  static Future<Map<String, String>> _materializeFiles(
    Map<String, Map<String, dynamic>> filesById,
    Set<String> usedIds, {
    File? backupArchive,
  }) async {
    final uploadDir = await AppDirectories.getUploadDirectory();
    if (!await uploadDir.exists()) await uploadDir.create(recursive: true);

    // If a ZIP is provided, index entries under common folders for quick lookup
    Map<String, ArchiveFile>? filesIndexByBase;
    Map<String, ArchiveFile>?
    filesIndexByRel; // normalized rel path like files/x.pdf or data/files/uuid.png
    Map<String, ArchiveFile>? filesIndexById; // id (without ext) -> entry
    Map<String, String>?
    diskFilesIndexByBase; // basename -> absolute path (if importing from extracted folder)
    Map<String, String>?
    diskFilesIndexByRel; // normalized rel path -> absolute path
    Map<String, String>?
    diskFilesIndexById; // id (without ext) -> absolute path
    if (backupArchive != null) {
      try {
        final bytes = await backupArchive.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes, verify: false);
        final byBase = <String, ArchiveFile>{};
        final byRel = <String, ArchiveFile>{};
        final byId = <String, ArchiveFile>{};
        final uuidLike = RegExp(r'^[0-9a-fA-F-]{10,}$');
        for (final e in archive) {
          if (!e.isFile) continue;
          final norm = e.name.replaceAll('\\\\', '/');
          final base = p.basename(norm);
          // by basename
          byBase[base] = e;
          // by normalized rel under common roots
          final l = norm.toLowerCase();
          int idx = l.indexOf('/data/files/');
          if (idx != -1) {
            final rel = l.substring(idx + 1);
            byRel[rel] = e;
          }
          idx = l.indexOf('/files/');
          if (idx != -1) {
            final rel = l.substring(idx + 1);
            byRel[rel] = e;
          }
          // by id without ext
          final noExt = base.contains('.')
              ? base.substring(0, base.lastIndexOf('.'))
              : base;
          if (uuidLike.hasMatch(noExt)) {
            byId[noExt] = e;
          }
        }
        if (byBase.isNotEmpty) filesIndexByBase = byBase;
        if (byRel.isNotEmpty) filesIndexByRel = byRel;
        if (byId.isNotEmpty) filesIndexById = byId;
      } catch (_) {
        // not a zip, ignore
      }
      // Also try sibling directories when importing from an extracted folder
      try {
        final parent = Directory(p.dirname(backupArchive.path));
        final candidates = <Directory>[
          Directory(p.join(parent.path, 'Data', 'Files')),
          Directory(p.join(parent.path, 'Files')),
          Directory(p.join(parent.path, 'files')),
        ];
        final byBase = <String, String>{};
        final byRel = <String, String>{};
        final byId = <String, String>{};
        final uuidLike = RegExp(r'^[0-9a-fA-F-]{10,}$');
        for (final dir in candidates) {
          if (!await dir.exists()) continue;
          for (final ent in dir.listSync(recursive: true, followLinks: false)) {
            if (ent is! File) continue;
            final abs = ent.path;
            final base = p.basename(abs);
            byBase[base] = abs;
            final l = abs.replaceAll('\\\\', '/').toLowerCase();
            int idx = l.indexOf('/data/files/');
            if (idx != -1) {
              final rel = l.substring(idx + 1);
              byRel[rel] = abs;
            }
            idx = l.indexOf('/files/');
            if (idx != -1) {
              final rel = l.substring(idx + 1);
              byRel[rel] = abs;
            }
            final noExt = base.contains('.')
                ? base.substring(0, base.lastIndexOf('.'))
                : base;
            if (uuidLike.hasMatch(noExt)) {
              byId[noExt] = abs;
            }
          }
        }
        if (byBase.isNotEmpty) diskFilesIndexByBase = byBase;
        if (byRel.isNotEmpty) diskFilesIndexByRel = byRel;
        if (byId.isNotEmpty) diskFilesIndexById = byId;
      } catch (_) {}
    }

    final result = <String, String>{};
    for (final id in usedIds) {
      final meta = filesById[id];
      if (meta == null) continue;
      final name = (meta['origin_name'] ?? meta['name'] ?? 'file').toString();
      final ext = (meta['ext'] ?? '').toString();
      final safeName = name.replaceAll(RegExp(r'[/\\\0]'), '_');
      final fn = safeName.isNotEmpty
          ? safeName
          : (ext.isNotEmpty ? 'file.$ext' : 'file');
      final fileName = 'cherry_${id}_$fn';
      final outPath = p.join(uploadDir.path, fileName);

      // If already written, reuse path
      if (await File(outPath).exists()) {
        result[id] = outPath;
        continue;
      }

      // Prefer base64 -> content -> archive(Data/Files) -> url (url not downloaded)
      final base64Str = (meta['base64'] ?? '') as String;
      final contentStr = (meta['content'] ?? '') as String;
      try {
        if (base64Str.isNotEmpty) {
          // Strip data URL prefix if present
          String b64 = base64Str;
          final idx = b64.indexOf('base64,');
          if (idx != -1) b64 = b64.substring(idx + 7);
          final bytes = base64.decode(b64);
          await File(outPath).writeAsBytes(bytes);
          result[id] = outPath;
          continue;
        }
      } catch (_) {}

      try {
        if (contentStr.isNotEmpty) {
          await File(outPath).writeAsString(contentStr);
          result[id] = outPath;
          continue;
        }
      } catch (_) {}

      // Try from archive/disk using multiple strategies
      // 1) by normalized rel path from meta.path
      try {
        final mp = (meta['path'] ?? '').toString();
        if (mp.isNotEmpty) {
          String rel = mp.replaceAll('\\\\', '/').trim();
          if (rel.startsWith('file://')) rel = rel.substring('file://'.length);
          if (rel.startsWith('/')) rel = rel.substring(1);
          final lowerRel = rel.toLowerCase();
          final relKeys = <String>{
            lowerRel,
            lowerRel.startsWith('files/') ? lowerRel : 'files/$lowerRel',
            lowerRel.startsWith('data/files/')
                ? lowerRel
                : 'data/files/$lowerRel',
          };
          bool done = false;
          for (final key in relKeys) {
            if (!done &&
                filesIndexByRel != null &&
                filesIndexByRel.containsKey(key)) {
              final entry = filesIndexByRel[key]!;
              final bytes = entry.content as List<int>;
              await File(outPath).writeAsBytes(bytes);
              result[id] = outPath;
              done = true;
            }
            if (!done &&
                diskFilesIndexByRel != null &&
                diskFilesIndexByRel.containsKey(key)) {
              final src = diskFilesIndexByRel[key]!;
              final bytes = await File(src).readAsBytes();
              await File(outPath).writeAsBytes(bytes);
              result[id] = outPath;
              done = true;
            }
            if (done) break;
          }
          if (done) continue;
        }
      } catch (_) {}

      // 2) by filename candidates: name, origin_name, basename(path)
      try {
        final candidates = <String>{};
        void add(String? s) {
          if (s != null && s.trim().isNotEmpty) candidates.add(p.basename(s));
        }

        add(meta['name']?.toString());
        add(meta['origin_name']?.toString());
        add(meta['path']?.toString());
        bool done = false;
        for (final base in candidates) {
          if (!done &&
              filesIndexByBase != null &&
              filesIndexByBase.containsKey(base)) {
            final entry = filesIndexByBase[base]!;
            final bytes = entry.content as List<int>;
            await File(outPath).writeAsBytes(bytes);
            result[id] = outPath;
            done = true;
          }
          if (!done &&
              diskFilesIndexByBase != null &&
              diskFilesIndexByBase.containsKey(base)) {
            final src = diskFilesIndexByBase[base]!;
            final bytes = await File(src).readAsBytes();
            await File(outPath).writeAsBytes(bytes);
            result[id] = outPath;
            done = true;
          }
          if (done) break;
        }
        if (done) continue;
      } catch (_) {}

      // 3) by id + ext
      try {
        String ext = (meta['ext'] ?? '').toString().trim();
        if (ext.isEmpty) {
          final n = (meta['name'] ?? '').toString();
          final b = p.basename(n);
          if (b.contains('.')) ext = b.substring(b.lastIndexOf('.') + 1);
        }
        final extNoDot = ext.startsWith('.') ? ext.substring(1) : ext;
        final idPlus = extNoDot.isNotEmpty ? '${id}.$extNoDot' : id;
        if (filesIndexById != null && filesIndexById.containsKey(id)) {
          final entry = filesIndexById[id]!;
          final bytes = entry.content as List<int>;
          await File(outPath).writeAsBytes(bytes);
          result[id] = outPath;
          continue;
        }
        if (filesIndexByBase != null && filesIndexByBase.containsKey(idPlus)) {
          final entry = filesIndexByBase[idPlus]!;
          final bytes = entry.content as List<int>;
          await File(outPath).writeAsBytes(bytes);
          result[id] = outPath;
          continue;
        }
        if (diskFilesIndexById != null && diskFilesIndexById.containsKey(id)) {
          final src = diskFilesIndexById[id]!;
          final bytes = await File(src).readAsBytes();
          await File(outPath).writeAsBytes(bytes);
          result[id] = outPath;
          continue;
        }
        if (diskFilesIndexByBase != null &&
            diskFilesIndexByBase.containsKey(idPlus)) {
          final src = diskFilesIndexByBase[idPlus]!;
          final bytes = await File(src).readAsBytes();
          await File(outPath).writeAsBytes(bytes);
          result[id] = outPath;
          continue;
        }
      } catch (_) {}

      // If neither available, we cannot materialize this file; skip (message will fall back to URL/none)
    }
    return result;
  }

  // Returns (conversations, messages, extraFilesSaved)
  static Future<(int, int, int)> _importConversations({
    required Map<String, Map<String, dynamic>> topicMeta,
    required Map<String, Map<String, dynamic>> topicMetaFromIndexedDb,
    required Map<String, List<Map<String, dynamic>>> topicMessages,
    required Map<String, String> filePaths,
    required ChatService chatService,
    required RestoreMode mode,
    required Map<String, String> blockTexts,
    required Map<String, List<_PendingAttachmentRef>>
    pendingAttachmentsByMessage,
    required String? fallbackAssistantId,
    required String defaultConversationTitle,
  }) async {
    if (!chatService.initialized) await chatService.init();

    // Build map of existing conv ids for merge
    final existingConvs = chatService.getAllConversations();
    final existingConvIds = existingConvs.map((c) => c.id).toSet();
    final existingMsgIds = <String>{};
    if (mode == RestoreMode.merge) {
      for (final c in existingConvs) {
        final msgs = chatService.getMessages(c.id);
        for (final m in msgs) existingMsgIds.add(m.id);
      }
    }

    int convCount = 0;
    int msgCount = 0;
    int extraSaved = 0; // number of files saved from base64/data urls

    bool _parseBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final t = v.trim().toLowerCase();
        if (t == 'true' || t == '1' || t == 'yes' || t == 'y') return true;
        if (t == 'false' || t == '0' || t == 'no' || t == 'n') return false;
      }
      return false;
    }

    String _resolveAssistantId(Map<String, dynamic> meta) {
      dynamic cand = meta['assistantId'] ?? meta['assistant_id'];
      if (cand is Map) {
        final m = cand.map((k, v) => MapEntry(k.toString(), v));
        cand = m['id'] ?? m['assistantId'] ?? m['assistant_id'];
      }
      final s = (cand ?? '').toString().trim();
      if (s.isNotEmpty) return s;
      final fb = (fallbackAssistantId ?? '').trim();
      if (fb.isNotEmpty) return fb;
      // Last resort: avoid null (null would be treated as global and shown everywhere).
      return 'orphan-imported';
    }

    for (final entry in topicMessages.entries) {
      final topicId = entry.key;
      final msgsRaw = entry.value;
      final meta =
          topicMeta[topicId] ??
          topicMetaFromIndexedDb[topicId] ??
          const <String, dynamic>{};
      final rawTitle = (meta['name'] ?? meta['title'] ?? '').toString().trim();
      final title = rawTitle.isNotEmpty ? rawTitle : defaultConversationTitle;
      final pinned = _parseBool(meta['pinned'] ?? meta['isPinned']);
      final assistantId = _resolveAssistantId(meta);
      // created/updated fallback from messages
      DateTime createdAt;
      DateTime updatedAt;
      try {
        createdAt = DateTime.parse((meta['createdAt'] ?? '').toString());
      } catch (_) {
        createdAt = DateTime.now();
      }
      try {
        updatedAt = DateTime.parse((meta['updatedAt'] ?? '').toString());
      } catch (_) {
        updatedAt = createdAt;
      }

      // Convert messages
      final messages = <ChatMessage>[];
      for (final m in msgsRaw) {
        final msgId = (m['id'] ?? '').toString();
        if (msgId.isEmpty) continue;
        if (mode == RestoreMode.merge && existingMsgIds.contains(msgId))
          continue;
        final roleRaw = (m['role'] ?? 'user').toString();
        final role = (roleRaw == 'system')
            ? 'assistant'
            : roleRaw; // our schema only supports 'user'|'assistant'
        // Prefer message.content; if empty, fallback to reconstructed blocks
        String content = '';
        final rawContent = m['content'];
        if (rawContent is String) {
          content = rawContent;
        } else if (rawContent != null) {
          content = rawContent.toString();
        }
        if (content.trim().isEmpty) {
          content = (blockTexts[msgId] ?? '').toString();
        }
        DateTime ts;
        try {
          ts = DateTime.parse((m['createdAt'] ?? '').toString());
        } catch (_) {
          ts = DateTime.now();
        }

        final modelId =
            (m['modelId'] ??
                    (m['model'] is Map
                        ? (m['model']['id'] ?? '').toString()
                        : null))
                as String?;
        final providerId = (m['model'] is Map
            ? (m['model']['provider'] ?? '').toString()
            : null);
        final usage = (m['usage'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v),
        );
        final totalTokens = (usage?['total_tokens'] as num?)?.toInt();

        // Attachments -> appended as user-style markers or assistant markdown
        final files = (m['files'] as List?) ?? const <dynamic>[];
        final attachmentLines = <String>[];
        for (final f in files) {
          if (f is! Map) continue;
          final fid = (f['id'] ?? '').toString();
          if (fid.isEmpty) continue;
          final name = (f['origin_name'] ?? f['name'] ?? 'file').toString();
          final mime = (f['type'] ?? '').toString();
          final savedPath = filePaths[fid];
          if (savedPath != null && savedPath.isNotEmpty) {
            final isImage =
                mime.toLowerCase().startsWith('image') ||
                (name.toLowerCase().contains('.') &&
                    RegExp(
                      r"\.(png|jpg|jpeg|gif|webp)",
                    ).hasMatch(name.toLowerCase()));
            attachmentLines.add(
              _formatAttachmentLine(role, isImage, savedPath, name, mime),
            );
          } else {
            // Fallback to URL if present (no download)
            final url = (f['url'] ?? '').toString();
            if (url.isNotEmpty) {
              final isImage = url.toLowerCase().contains(
                RegExp(r"\.(png|jpg|jpeg|gif|webp)$"),
              );
              attachmentLines.add(
                _formatAttachmentLine(role, isImage, url, name, mime),
              );
            }
          }
        }

        // Add images referenced by message blocks (image) and message.metadata.generateImageResponse
        final extraAtt =
            pendingAttachmentsByMessage[msgId] ??
            const <_PendingAttachmentRef>[];
        for (final ref in extraAtt) {
          if (ref.fileId != null) {
            final savedPath = filePaths[ref.fileId!];
            if (savedPath != null) {
              attachmentLines.add(
                _formatAttachmentLine(
                  role,
                  ref.isImage,
                  savedPath,
                  ref.name ?? (ref.isImage ? 'image' : 'file'),
                  ref.mime ??
                      (ref.isImage ? 'image/png' : 'application/octet-stream'),
                ),
              );
            }
          } else if (ref.dataUrl != null) {
            final savedPath = await _saveDataUrlToUpload(ref.dataUrl!);
            if (savedPath != null) {
              extraSaved += 1;
              attachmentLines.add(
                _formatAttachmentLine(
                  role,
                  ref.isImage,
                  savedPath,
                  ref.name ?? (ref.isImage ? 'image' : 'file'),
                  ref.mime ??
                      (ref.isImage ? 'image/png' : 'application/octet-stream'),
                ),
              );
            }
          } else if (ref.url != null && ref.url!.isNotEmpty) {
            attachmentLines.add(
              _formatAttachmentLine(
                role,
                ref.isImage,
                ref.url!,
                ref.name ?? (ref.isImage ? 'image' : 'file'),
                ref.mime ??
                    (ref.isImage ? 'image/png' : 'application/octet-stream'),
              ),
            );
          }
        }

        // generateImageResponse in metadata
        final metadata = (m['metadata'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v),
        );
        final gen = (metadata?['generateImageResponse'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v),
        );
        if (gen != null) {
          final imgs = (gen['images'] as List?) ?? const <dynamic>[];
          for (final item in imgs) {
            final s = (item ?? '').toString();
            if (s.isEmpty) continue;
            if (s.startsWith('data:image')) {
              final saved = await _saveDataUrlToUpload(s);
              if (saved != null) {
                extraSaved += 1;
                attachmentLines.add(
                  _formatAttachmentLine(
                    role,
                    true,
                    saved,
                    'image',
                    'image/png',
                  ),
                );
              }
            } else if (s.startsWith('http://') || s.startsWith('https://')) {
              attachmentLines.add(
                _formatAttachmentLine(role, true, s, 'image', 'image/png'),
              );
            } else {
              // raw base64 without prefix
              final saved = await _saveDataUrlToUpload(
                'data:image/png;base64,$s',
              );
              if (saved != null) {
                extraSaved += 1;
                attachmentLines.add(
                  _formatAttachmentLine(
                    role,
                    true,
                    saved,
                    'image',
                    'image/png',
                  ),
                );
              }
            }
          }
        }

        // Extract any inline data:image base64 URLs inside assistant content and convert to files
        if (role == 'assistant' && content.contains('data:image')) {
          final dataUrls = _extractDataImageUrls(content);
          if (dataUrls.isNotEmpty) {
            for (final du in dataUrls) {
              final saved = await _saveDataUrlToUpload(du);
              if (saved != null) {
                extraSaved += 1;
                attachmentLines.add(
                  _formatAttachmentLine(
                    role,
                    true,
                    saved,
                    'image',
                    'image/png',
                  ),
                );
              }
            }
            // Optionally strip the base64 blobs from content to avoid giant text blobs
            content = _stripDataImageUrls(content);
          }
        }
        final mergedContent = attachmentLines.isEmpty
            ? content
            : (content.isEmpty
                  ? attachmentLines.join('\n')
                  : '$content\n${attachmentLines.join('\n')}');

        messages.add(
          ChatMessage(
            id: msgId,
            role: role,
            content: mergedContent,
            timestamp: ts,
            modelId: modelId,
            providerId: providerId,
            totalTokens: totalTokens,
            conversationId: topicId,
          ),
        );
      }

      // Derive timestamps if missing
      if (messages.isNotEmpty) {
        final times = messages.map((m) => m.timestamp).toList()..sort();
        createdAt = times.first;
        updatedAt = times.last;
      }

      // Skip importing empty conversations to match Chatbox import behavior.
      // Still bind an existing unowned conversation (assistantId == null/empty) in merge mode
      // to avoid it being treated as a "global" chat shown under any assistant.
      if (mode == RestoreMode.merge && existingConvIds.contains(topicId)) {
        final existed = chatService.getConversation(topicId);
        if (existed != null) {
          final rawAid = (existed.assistantId ?? '').trim();
          if (rawAid.isEmpty) {
            existed.assistantId = assistantId;
            await existed.save();
          }
        }
      }
      if (messages.isEmpty) {
        continue;
      }

      // Persist
      if (mode == RestoreMode.merge && existingConvIds.contains(topicId)) {
        // Only add new messages
        for (final m in messages) {
          await chatService.addMessageDirectly(topicId, m);
          msgCount += 1;
        }
        // Keep conversation recency in sync with imported messages.
        final existed = chatService.getConversation(topicId);
        if (existed != null && updatedAt.isAfter(existed.updatedAt)) {
          existed.updatedAt = updatedAt;
          await existed.save();
        }
      } else {
        final conv = Conversation(
          id: topicId,
          title: title,
          createdAt: createdAt,
          updatedAt: updatedAt,
          isPinned: pinned,
          assistantId: assistantId,
        );
        await chatService.restoreConversation(conv, messages);
        convCount += 1;
        msgCount += messages.length;
      }
    }

    return (convCount, msgCount, extraSaved);
  }

  static String _formatAttachmentLine(
    String role,
    bool isImage,
    String target,
    String name,
    String mime,
  ) {
    if (role == 'assistant') {
      if (isImage) {
        return '![]($target)';
      } else {
        final label = (name.isNotEmpty ? name : 'file');
        return '[$label]($target)';
      }
    } else {
      if (isImage) {
        return '[image:$target]';
      } else {
        final m = (mime.isEmpty ? 'application/octet-stream' : mime);
        final label = (name.isNotEmpty ? name : 'file');
        return '[file:$target|$label|$m]';
      }
    }
  }

  static List<String> _extractDataImageUrls(String text) {
    final re = RegExp(
      r'data:image\/[a-zA-Z0-9.+-]+;base64,[a-zA-Z0-9+\/\=\r\n]+',
    );
    return re.allMatches(text).map((m) => m.group(0)!).toList();
  }

  static String _stripDataImageUrls(String text) {
    final re = RegExp(
      r'data:image\/[a-zA-Z0-9.+-]+;base64,[a-zA-Z0-9+\/\=\r\n]+',
    );
    return text.replaceAll(re, '');
  }

  static Future<String?> _saveDataUrlToUpload(String dataUrl) async {
    try {
      final upload = await AppDirectories.getUploadDirectory();
      if (!await upload.exists()) await upload.create(recursive: true);
      // Extract mime and data
      String mime = 'image/png';
      String payload = dataUrl;
      final colon = dataUrl.indexOf(':');
      final semi = dataUrl.indexOf(';');
      final base = dataUrl.indexOf('base64,');
      if (colon >= 0 && semi > colon) {
        mime = dataUrl.substring(colon + 1, semi);
      }
      if (base >= 0) {
        payload = dataUrl.substring(base + 7);
      }
      final bytes = base64.decode(payload.replaceAll('\n', ''));
      String ext = 'png';
      switch (mime.toLowerCase()) {
        case 'image/jpeg':
        case 'image/jpg':
          ext = 'jpg';
          break;
        case 'image/webp':
          ext = 'webp';
          break;
        case 'image/gif':
          ext = 'gif';
          break;
        default:
          ext = 'png';
      }
      final fname =
          'cherry_img_${DateTime.now().millisecondsSinceEpoch}_${bytes.length}.$ext';
      final out = File(p.join(upload.path, fname));
      await out.writeAsBytes(bytes);
      return out.path;
    } catch (_) {
      return null;
    }
  }
}

class _PendingAttachmentRef {
  final String? fileId; // if present, resolve via filePaths
  final String? dataUrl; // if present, save as file
  final String? url; // remote url
  final String? name;
  final String? mime;
  final bool isImage;
  const _PendingAttachmentRef({
    this.fileId,
    this.dataUrl,
    this.url,
    this.name,
    this.mime,
    this.isImage = true,
  });
}
