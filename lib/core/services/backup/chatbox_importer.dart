import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../models/backup.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../providers/settings_provider.dart';
import '../chat/chat_service.dart';

class ChatboxImportException implements Exception {
  final String message;
  const ChatboxImportException(this.message);
  @override
  String toString() => message;
}

class ChatboxImportResult {
  final int providers;
  final int assistants;
  final int conversations;
  final int messages;
  const ChatboxImportResult({
    required this.providers,
    required this.assistants,
    required this.conversations,
    required this.messages,
  });
}

class ChatboxImporter {
  ChatboxImporter._();

  // Persisted keys used by SettingsProvider/AssistantProvider/TagProvider
  static const String _providersKey = 'provider_configs_v1';
  static const String _providersOrderKey = 'providers_order_v1';
  static const String _assistantsKey = 'assistants_v1';
  static const String _tagsKey = 'assistant_tags_v1';
  static const String _assignKey = 'assistant_tag_map_v1'; // assistantId -> tagId
  static const String _collapsedKey = 'assistant_tag_collapsed_v1'; // tagId -> bool

  static Future<ChatboxImportResult> importFromChatbox({
    required File file,
    required RestoreMode mode,
    required SettingsProvider settings,
    required ChatService chatService,
  }) async {
    final root = await _readChatboxBackupFile(file);

    // Safety: avoid destructive overwrite when the export is incomplete.
    if (mode == RestoreMode.overwrite) {
      final sessionsList = root['chat-sessions-list'];
      if (sessionsList is! List || sessionsList.isEmpty) {
        throw const ChatboxImportException(
          'This Chatbox export does not include chat history. Re-export with "Chat History" enabled, or use merge mode.',
        );
      }
      bool hasAnySessionObject = false;
      for (final meta in sessionsList) {
        if (meta is! Map) continue;
        final id = (meta['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        if (root['session:$id'] is Map) {
          hasAnySessionObject = true;
          break;
        }
      }
      if (!hasAnySessionObject) {
        throw const ChatboxImportException(
          'This Chatbox export is missing session data (no "session:*" entries). Please export again and include chat history.',
        );
      }
    }

    final importedProviders = await _importProviders(root, mode);
    final assistantConvRes = await _importAssistantsAndConversations(root, mode, chatService);
    await _tagImportedAssistants(assistantConvRes.assistantIds, mode);

    return ChatboxImportResult(
      providers: importedProviders,
      assistants: assistantConvRes.assistants,
      conversations: assistantConvRes.conversations,
      messages: assistantConvRes.messages,
    );
  }

  // ---------- parsing ----------

  static Future<Map<String, dynamic>> _readChatboxBackupFile(File file) async {
    if (!await file.exists()) {
      throw const ChatboxImportException('Chatbox backup file not found.');
    }

    late final String text;
    try {
      text = await file.readAsString();
    } catch (e) {
      throw ChatboxImportException('Unable to read Chatbox backup file: $e');
    }

    late final Object decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const ChatboxImportException('Invalid JSON: unable to parse Chatbox backup file.');
    }

    if (decoded is! Map) {
      throw const ChatboxImportException('Unsupported data format: expected a JSON object.');
    }

    final root = decoded.map((k, v) => MapEntry(k.toString(), v));

    // Minimal shape validation: exported data usually has at least one of these.
    final hasSessions = root['chat-sessions-list'] is List;
    final settings = root['settings'];
    final hasProviders = settings is Map && (settings['providers'] is Map);
    if (!hasSessions && !hasProviders) {
      throw const ChatboxImportException(
        'Not a Chatbox export file (missing "chat-sessions-list" and "settings.providers").',
      );
    }

    return root.cast<String, dynamic>();
  }

  // ---------- providers ----------

  static Future<int> _importProviders(
    Map<String, dynamic> root,
    RestoreMode mode,
  ) async {
    final rawSettings = root['settings'];
    if (rawSettings is! Map) return 0;
    final providers = rawSettings['providers'];
    if (providers is! Map) return 0;

    final imported = <String, Map<String, dynamic>>{};
    for (final entry in providers.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty) continue;
      if (key == 'chatbox-ai') continue; // not supported in this app
      final cfg = entry.value;
      if (cfg is! Map) continue;

      final apiKey = (cfg['apiKey'] ?? '').toString();
      final apiHost = (cfg['apiHost'] ?? '').toString();
      final apiPath = (cfg['apiPath'] ?? '').toString();
      final endpoint = (cfg['endpoint'] ?? '').toString();

      final kind = ProviderConfig.classify(key);
      final normalized = _normalizeHostAndPath(
        providerKey: key,
        kind: kind,
        apiHost: apiHost,
        apiPath: apiPath,
        endpoint: endpoint,
      );
      final models = <String>[];
      final rawModels = cfg['models'];
      if (rawModels is List) {
        for (final m in rawModels) {
          if (m is! Map) continue;
          final mid = (m['modelId'] ?? '').toString().trim();
          if (mid.isNotEmpty) models.add(mid);
        }
      }

      imported[key] = <String, dynamic>{
        'id': key,
        'enabled': apiKey.trim().isNotEmpty,
        'name': key,
        'apiKey': apiKey,
        'baseUrl': normalized.apiHost.isNotEmpty
            ? normalized.apiHost
            : ProviderConfig.defaultsFor(key, displayName: key).baseUrl,
        'providerType': kind.name,
        'chatPath': kind == ProviderKind.openai ? normalized.apiPath : null,
        'useResponseApi': kind == ProviderKind.openai ? false : null,
        'vertexAI': kind == ProviderKind.google ? false : null,
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
    }

    final prefs = await SharedPreferences.getInstance();

    if (mode == RestoreMode.overwrite) {
      // If the export does not include provider configs, don't wipe existing local providers.
      if (imported.isEmpty) return 0;
      await prefs.setString(_providersKey, jsonEncode(imported));
      await prefs.setStringList(_providersOrderKey, imported.keys.toList());
      return imported.length;
    }

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
        // Update non-empty fields (keep user's local name/avatar/proxy etc if present)
        final cur = (merged[entry.key] as Map).map((k, v) => MapEntry(k.toString(), v));
        final inc = entry.value;
        final next = Map<String, dynamic>.from(cur);
        void putIfNotEmpty(String k) {
          final v = inc[k];
          if (v == null) return;
          if (v is String && v.trim().isEmpty) return;
          next[k] = v;
        }
        for (final k in inc.keys) {
          // avoid overwriting non-empty local display name
          if (k == 'name') continue;
          putIfNotEmpty(k);
        }
        merged[entry.key] = next;
      }
    }
    await prefs.setString(_providersKey, jsonEncode(merged));

    final existedOrder = prefs.getStringList(_providersOrderKey) ?? const <String>[];
    final order = existedOrder.toList();
    for (final id in imported.keys) {
      if (!order.contains(id)) order.add(id);
    }
    await prefs.setStringList(_providersOrderKey, order);

    return imported.length;
  }

  // ---------- assistants + conversations ----------

  static Future<_AssistantsConversationsResult> _importAssistantsAndConversations(
    Map<String, dynamic> root,
    RestoreMode mode,
    ChatService chatService,
  ) async {
    final sessionsListRaw = root['chat-sessions-list'];
    final sessionsList = sessionsListRaw is List ? sessionsListRaw : const <dynamic>[];

    // Collect all session ids first so we can tag them later.
    final importedAssistants = <Map<String, dynamic>>[];
    final importedAssistantIds = <String>[];

    // For merge mode, we need to know what already exists.
    final prefs = await SharedPreferences.getInstance();
    final existingAssistantsById = <String, Map<String, dynamic>>{};
    if (mode == RestoreMode.merge) {
      try {
        final raw = prefs.getString(_assistantsKey);
        if (raw != null && raw.isNotEmpty) {
          final arr = jsonDecode(raw) as List<dynamic>;
          for (final e in arr) {
            if (e is Map && e['id'] != null) {
              existingAssistantsById[e['id'].toString()] =
                  e.map((k, v) => MapEntry(k.toString(), v));
            }
          }
        }
      } catch (_) {}
    }

    // Prepare chat service for conversation restore.
    if (!chatService.initialized) await chatService.init();
    if (mode == RestoreMode.overwrite) {
      await chatService.clearAllData();
    }

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

    // `__exported_at` is a good fallback timestamp base when message timestamps are missing.
    final exportedAt = _parseIsoDateTime((root['__exported_at'] ?? '').toString()) ?? DateTime.now();

    for (final meta in sessionsList) {
      if (meta is! Map) continue;
      final id = (meta['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      final name = (meta['name'] ?? id).toString();
      final avatar = (meta['picUrl'] ?? '').toString().trim();
      final starred = meta['starred'] as bool? ?? false;

      final sessionRaw = root['session:$id'];
      final session = sessionRaw is Map ? sessionRaw.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};
      final sessionSettingsRaw = session['settings'];
      final sessionSettings = sessionSettingsRaw is Map ? sessionSettingsRaw.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};

      // Derive assistant config fields.
      final provider = (sessionSettings['provider'] ?? '').toString().trim();
      final modelId = (sessionSettings['modelId'] ?? '').toString().trim();
      final temperature = (sessionSettings['temperature'] as num?)?.toDouble();
      final topP = (sessionSettings['topP'] as num?)?.toDouble();
      final maxTokens = (sessionSettings['maxTokens'] as num?)?.toInt();
      final stream = sessionSettings['stream'] as bool?;
      final contextCount = (sessionSettings['maxContextMessageCount'] as num?)?.toInt();

      final thinkingBudget = _extractThinkingBudget(sessionSettings);

      // Use first system message as assistant system prompt.
      final sysPrompt = _extractSystemPromptFromSession(session, fallback: _extractDefaultPrompt(root));

      final assistantJson = <String, dynamic>{
        'id': id,
        'name': name,
        'avatar': avatar.isNotEmpty ? avatar : null,
        'useAssistantAvatar': false,
        'chatModelProvider': (provider.isEmpty || provider == 'chatbox-ai') ? null : provider,
        'chatModelId': (provider.isEmpty || provider == 'chatbox-ai' || modelId.isEmpty) ? null : modelId,
        'temperature': temperature,
        'topP': topP,
        'contextMessageSize': contextCount ?? 64,
        'limitContextMessages': true,
        'streamOutput': stream ?? true,
        'thinkingBudget': thinkingBudget,
        'maxTokens': maxTokens,
        'systemPrompt': sysPrompt,
        'messageTemplate': '{{ message }}',
        'mcpServerIds': const <String>[],
        'background': null,
        'deletable': true,
        'customHeaders': const <Map<String, String>>[],
        'customBody': const <Map<String, String>>[],
        'enableMemory': false,
        'enableRecentChatsReference': false,
        'presetMessages': const <dynamic>[],
        'regexRules': const <dynamic>[],
      };

      final exists = existingAssistantsById.containsKey(id);
      if (mode == RestoreMode.overwrite || !exists) {
        importedAssistants.add(assistantJson);
        importedAssistantIds.add(id);
      } else {
        // Merge: keep local assistant unless incoming contains non-empty system prompt / model fields.
        final local = existingAssistantsById[id]!;
        final incPrompt = (assistantJson['systemPrompt'] as String?)?.trim() ?? '';
        if (incPrompt.isNotEmpty) local['systemPrompt'] = incPrompt;
        if (assistantJson['chatModelProvider'] != null) local['chatModelProvider'] = assistantJson['chatModelProvider'];
        if (assistantJson['chatModelId'] != null) local['chatModelId'] = assistantJson['chatModelId'];
        if (assistantJson['temperature'] != null) local['temperature'] = assistantJson['temperature'];
        if (assistantJson['topP'] != null) local['topP'] = assistantJson['topP'];
        if (assistantJson['maxTokens'] != null) local['maxTokens'] = assistantJson['maxTokens'];
        if (assistantJson['thinkingBudget'] != null) local['thinkingBudget'] = assistantJson['thinkingBudget'];
        // Do not overwrite local avatar/background in merge mode.
        existingAssistantsById[id] = local;
        importedAssistantIds.add(id); // still tag it as chatbox source
      }

      // Conversations (topics)
      final threadsRaw = session['threads'];
      final threads = threadsRaw is List ? threadsRaw : const <dynamic>[];
      final sessionMessages = (session['messages'] is List) ? session['messages'] as List : const <dynamic>[];
      List<String> collectIds(dynamic raw) {
        if (raw is! List) return const <String>[];
        final out = <String>[];
        for (final e in raw) {
          if (e is! Map) continue;
          final mid = (e['id'] ?? '').toString().trim();
          if (mid.isNotEmpty) out.add(mid);
        }
        return out;
      }

      final parsedThreads = <Map<String, dynamic>>[
        for (final t in threads)
          if (t is Map) t.map((k, v) => MapEntry(k.toString(), v)).cast<String, dynamic>(),
      ];

      final effectiveThreads = <Map<String, dynamic>>[];
      if (parsedThreads.isEmpty) {
        effectiveThreads.add(<String, dynamic>{
          'id': 'chatbox_default_$id',
          'name': name,
          'createdAt': null,
          'messages': sessionMessages,
        });
      } else {
        effectiveThreads.addAll(parsedThreads);

        // Chatbox stores current topic messages in `session.messages`, and previous topics in `session.threads`.
        // Import both, but avoid duplicating if the current topic is already present in threads.
        final currentIds = collectIds(sessionMessages);
        if (currentIds.isNotEmpty) {
          final currentSet = currentIds.toSet();
          bool duplicated = false;
          for (final t in parsedThreads) {
            final ids = collectIds(t['messages']);
            if (ids.length != currentIds.length) continue;
            final s = ids.toSet();
            if (s.length == currentSet.length && s.containsAll(currentSet)) {
              duplicated = true;
              break;
            }
          }
          if (!duplicated) {
            final threadName = (session['threadName'] ?? '').toString().trim();
            String systemMessageId(List<dynamic> raw) {
              for (final e in raw) {
                if (e is! Map) continue;
                if ((e['role'] ?? '').toString() != 'system') continue;
                final mid = (e['id'] ?? '').toString().trim();
                if (mid.isNotEmpty) return mid;
              }
              return '';
            }
            final baseId = systemMessageId(sessionMessages);
            final derivedId = baseId.isNotEmpty
                ? 'chatbox_thread_$baseId'
                : 'chatbox_current_$id';
            effectiveThreads.add(<String, dynamic>{
              'id': derivedId,
              'name': threadName.isNotEmpty ? threadName : name,
              'createdAt': null,
              'messages': sessionMessages,
            });
          }
        }
      }

      for (final t in effectiveThreads) {
        final tid = (t['id'] ?? '').toString().trim();
        if (tid.isEmpty) continue;
        final title = ((t['name'] ?? '').toString().trim().isNotEmpty) ? (t['name'] ?? '').toString() : name;
        final threadMessagesRaw = (t['messages'] is List) ? (t['messages'] as List) : const <dynamic>[];

        // Convert messages
        final messages = <ChatMessage>[];
        bool consumedSystem = false;
        int fallbackIndex = 0;
        for (final rawMsg in threadMessagesRaw) {
          if (rawMsg is! Map) continue;
          final msg = rawMsg.map((k, v) => MapEntry(k.toString(), v));
          final msgId = (msg['id'] ?? '').toString();
          if (msgId.isEmpty) continue;
          if (mode == RestoreMode.merge && existingMsgIds.contains(msgId)) continue;

          final roleRaw = (msg['role'] ?? '').toString();
          final content = _extractMessageContent(
            msg,
            roleHint: roleRaw,
          );

          // System message: first one becomes assistant prompt, others become assistant-visible note.
          if (roleRaw == 'system') {
            if (!consumedSystem && content.trim().isNotEmpty) {
              consumedSystem = true;
              continue;
            }
          }

          final role = switch (roleRaw) {
            'user' => 'user',
            'tool' => 'tool',
            _ => 'assistant',
          };

          final ts = _parseMessageTimestamp(msg['timestamp']) ??
              exportedAt.add(Duration(milliseconds: fallbackIndex++));

          if (role == 'tool') {
            messages.add(ChatMessage(
              id: msgId,
              role: 'tool',
              content: _buildToolMessagePayload(msg, fallbackText: content),
              timestamp: ts,
              modelId: null,
              providerId: null,
              totalTokens: null,
              conversationId: tid,
            ));
          } else {
            final inferredModel = _inferModelIdFromChatboxMessage(msg);
            final providerId = (msg['aiProvider'] ?? '').toString().trim();
            final totalTokens = (msg['tokenCount'] as num?)?.toInt() ?? (msg['tokensUsed'] as num?)?.toInt();
            messages.add(ChatMessage(
              id: msgId,
              role: roleRaw == 'system' ? 'assistant' : role,
              content: roleRaw == 'system' ? '[System]\n$content' : content,
              timestamp: ts,
              modelId: inferredModel.isNotEmpty ? inferredModel : null,
              providerId: providerId.isNotEmpty ? providerId : null,
              totalTokens: totalTokens,
              conversationId: tid,
            ));
          }
        }

        // Determine timestamps
        DateTime createdAt = exportedAt;
        DateTime updatedAt = exportedAt;
        if (messages.isNotEmpty) {
          final times = messages.map((m) => m.timestamp).toList()..sort();
          createdAt = times.first;
          updatedAt = times.last;
        } else {
          // Thread createdAt can be a number (ms)
          final createdRaw = t['createdAt'];
          final created = _parseEpochMillis(createdRaw);
          if (created != null) {
            createdAt = created;
            updatedAt = created;
          }
        }

        final conv = Conversation(
          id: tid,
          title: title,
          createdAt: createdAt,
          updatedAt: updatedAt,
          isPinned: starred,
          assistantId: id,
        );

        if (mode == RestoreMode.merge && existingConvIds.contains(tid)) {
          for (final m in messages) {
            await chatService.addMessageDirectly(tid, m);
            msgCount += 1;
          }
        } else {
          await chatService.restoreConversation(conv, messages);
          convCount += 1;
          msgCount += messages.length;
        }
      }
    }

    if (mode == RestoreMode.overwrite) {
      await prefs.setString(_assistantsKey, jsonEncode(importedAssistants));
    } else {
      // merge: preserve existing and add/update imported ones
      final mergedById = <String, Map<String, dynamic>>{}..addAll(existingAssistantsById);
      for (final a in importedAssistants) {
        final id = (a['id'] ?? '').toString();
        if (id.isEmpty) continue;
        mergedById[id] = a;
      }
      await prefs.setString(_assistantsKey, jsonEncode(mergedById.values.toList()));
    }

    return _AssistantsConversationsResult(
      assistants: importedAssistantIds.toSet().length,
      conversations: convCount,
      messages: msgCount,
      assistantIds: importedAssistantIds,
    );
  }

  // ---------- tags ----------

  static Future<void> _tagImportedAssistants(List<String> assistantIds, RestoreMode mode) async {
    if (assistantIds.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();

    List<dynamic> tags = const <dynamic>[];
    Map<String, dynamic> assignment = const <String, dynamic>{};
    Map<String, dynamic> collapsed = const <String, dynamic>{};

    if (mode == RestoreMode.merge) {
      try {
        final rawTags = prefs.getString(_tagsKey);
        if (rawTags != null && rawTags.isNotEmpty) {
          tags = jsonDecode(rawTags) as List<dynamic>;
        }
      } catch (_) {}
      try {
        final rawAssign = prefs.getString(_assignKey);
        if (rawAssign != null && rawAssign.isNotEmpty) {
          assignment = jsonDecode(rawAssign) as Map<String, dynamic>;
        }
      } catch (_) {}
      try {
        final rawCol = prefs.getString(_collapsedKey);
        if (rawCol != null && rawCol.isNotEmpty) {
          collapsed = jsonDecode(rawCol) as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    final normalizedTags = <Map<String, dynamic>>[
      for (final t in tags)
        if (t is Map) t.map((k, v) => MapEntry(k.toString(), v)),
    ];

    String? chatboxTagId;
    for (final t in normalizedTags) {
      final name = (t['name'] ?? '').toString().trim().toLowerCase();
      if (name == 'chatbox') {
        final id = (t['id'] ?? '').toString().trim();
        if (id.isNotEmpty) {
          chatboxTagId = id;
          break;
        }
      }
    }

    final tagId = chatboxTagId ?? const Uuid().v4();
    if (!normalizedTags.any((t) => (t['id'] ?? '').toString() == tagId)) {
      normalizedTags.add(<String, dynamic>{'id': tagId, 'name': 'Chatbox'});
    }

    final nextAssign = <String, String>{
      for (final e in assignment.entries) e.key: e.value.toString(),
    };
    for (final id in assistantIds) {
      final aid = id.trim();
      if (aid.isEmpty) continue;
      if (mode == RestoreMode.overwrite) {
        nextAssign[aid] = tagId;
      } else {
        nextAssign.putIfAbsent(aid, () => tagId);
      }
    }

    final nextCollapsed = <String, bool>{
      for (final e in collapsed.entries)
        e.key: (e.value is bool) ? (e.value as bool) : (e.value.toString() == 'true'),
    };
    nextCollapsed.putIfAbsent(tagId, () => false);

    await prefs.setString(_tagsKey, jsonEncode(normalizedTags));
    await prefs.setString(_assignKey, jsonEncode(nextAssign));
    await prefs.setString(_collapsedKey, jsonEncode(nextCollapsed));
  }

  // ---------- content helpers ----------

  static String _extractDefaultPrompt(Map<String, dynamic> root) {
    final settings = root['settings'];
    if (settings is Map) {
      final p = (settings['defaultPrompt'] ?? '').toString();
      if (p.trim().isNotEmpty) return p;
    }
    return '';
  }

  static String _extractSystemPromptFromSession(Map<String, dynamic> session, {required String fallback}) {
    final msgs = session['messages'];
    if (msgs is List) {
      for (final raw in msgs) {
        if (raw is! Map) continue;
        final m = raw.map((k, v) => MapEntry(k.toString(), v));
        if ((m['role'] ?? '').toString() != 'system') continue;
        final content = _extractMessageContent(m, roleHint: 'system');
        if (content.trim().isNotEmpty) return content;
      }
    }
    return fallback;
  }

  static int? _extractThinkingBudget(Map<String, dynamic> sessionSettings) {
    final opts = sessionSettings['providerOptions'];
    if (opts is Map) {
      final claude = opts['claude'];
      if (claude is Map) {
        final thinking = claude['thinking'];
        if (thinking is Map) {
          final type = (thinking['type'] ?? '').toString();
          if (type == 'disabled') return 0;
          final budget = (thinking['budgetTokens'] as num?)?.toInt();
          if (budget != null) return budget;
        }
      }
      final google = opts['google'];
      if (google is Map) {
        final thinkingConfig = google['thinkingConfig'];
        if (thinkingConfig is Map) {
          final budget = (thinkingConfig['thinkingBudget'] as num?)?.toInt();
          if (budget != null) return budget;
        }
      }
    }
    return null;
  }

  static DateTime? _parseIsoDateTime(String raw) {
    try {
      if (raw.trim().isEmpty) return null;
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseEpochMillis(dynamic raw) {
    if (raw is num) {
      final ms = raw.toInt();
      if (ms <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    if (raw is String) {
      final n = int.tryParse(raw);
      if (n == null || n <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(n);
    }
    return null;
  }

  static DateTime? _parseMessageTimestamp(dynamic raw) {
    return _parseEpochMillis(raw);
  }

  static String _extractMessageContent(Map<String, dynamic> msg, {required String roleHint}) {
    final role = roleHint;
    final partsRaw = msg['contentParts'];
    final out = <String>[];

    void addText(String s) {
      final t = s.replaceAll('\r\n', '\n');
      if (t.trim().isNotEmpty) out.add(t);
    }

    if (partsRaw is List) {
      for (final p in partsRaw) {
        if (p is! Map) continue;
        final part = p.map((k, v) => MapEntry(k.toString(), v));
        final type = (part['type'] ?? '').toString();
        switch (type) {
          case 'text':
            addText((part['text'] ?? '').toString());
            break;
          case 'image':
            final url = (part['url'] ?? '').toString().trim();
            final storageKey = (part['storageKey'] ?? '').toString().trim();
            final ref = url.isNotEmpty ? url : storageKey;
            if (ref.isEmpty) break;
            if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('data:image')) {
              if (role == 'user') {
                out.add('[image:$url]');
              } else {
                out.add('![]($url)');
              }
            } else {
              out.add('[Chatbox image: $ref]');
            }
            break;
          case 'info':
            addText((part['text'] ?? '').toString());
            break;
          case 'reasoning':
            final t = (part['text'] ?? '').toString();
            if (t.trim().isNotEmpty) {
              out.add('<think>\n$t\n</think>');
            }
            break;
          case 'tool-call':
            final state = (part['state'] ?? '').toString();
            final toolName = (part['toolName'] ?? '').toString();
            final args = part['args'];
            if (state.isNotEmpty) {
              out.add('[tool:$state] ${toolName.isNotEmpty ? toolName : 'tool'} ${args == null ? '' : jsonEncode(args)}'.trim());
            }
            break;
          default:
            break;
        }
      }
    }

    // Fallback to legacy `content`
    if (out.isEmpty) {
      final legacy = (msg['content'] ?? '').toString();
      if (legacy.trim().isNotEmpty) addText(legacy);
    }

    // Links
    final links = msg['links'];
    if (links is List) {
      for (final l in links) {
        if (l is! Map) continue;
        final url = (l['url'] ?? '').toString().trim();
        if (url.isEmpty) continue;
        final title = (l['title'] ?? '').toString().trim();
        if (title.isNotEmpty) {
          out.add('[$title]($url)');
        } else {
          out.add(url);
        }
      }
    }

    // Files
    final files = msg['files'];
    if (files is List) {
      for (final f in files) {
        if (f is! Map) continue;
        final url = (f['url'] ?? '').toString().trim();
        if (url.isEmpty) continue;
        final name = (f['name'] ?? 'file').toString();
        final type = (f['fileType'] ?? '').toString();
        if (role == 'user') {
          out.add('[file:$url|$name|${type.isEmpty ? 'application/octet-stream' : type}]');
        } else {
          out.add('[$name]($url)');
        }
      }
    }

    // Pictures (legacy image list)
    final pics = msg['pictures'];
    if (pics is List) {
      for (final p in pics) {
        if (p is! Map) continue;
        final url = (p['url'] ?? '').toString().trim();
        if (url.isEmpty) continue;
        if (role == 'user') {
          out.add('[image:$url]');
        } else {
          out.add('![]($url)');
        }
      }
    }

    // Error info
    final err = (msg['error'] ?? '').toString();
    if (err.trim().isNotEmpty) {
      out.add('[Error] $err');
    }

    return out.join('\n').trim();
  }

  static String _inferModelIdFromChatboxMessage(Map<String, dynamic> msg) {
    final raw = (msg['model'] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    final m = RegExp(r'\\(([^)]+)\\)\\s*$').firstMatch(raw);
    if (m != null) return (m.group(1) ?? '').trim();
    return raw;
  }

  static String _buildToolMessagePayload(Map<String, dynamic> msg, {required String fallbackText}) {
    String toolName = (msg['name'] ?? '').toString().trim();
    Map<String, dynamic> args = const <String, dynamic>{};
    String result = fallbackText;

    final parts = msg['contentParts'];
    if (parts is List) {
      for (final p in parts) {
        if (p is! Map) continue;
        final part = p.map((k, v) => MapEntry(k.toString(), v));
        if ((part['type'] ?? '').toString() != 'tool-call') continue;
        toolName = toolName.isNotEmpty ? toolName : (part['toolName'] ?? '').toString();
        final a = part['args'];
        if (a is Map) args = a.cast<String, dynamic>();
        final state = (part['state'] ?? '').toString();
        if (state == 'result' && part.containsKey('result')) {
          result = (part['result'] ?? '').toString();
        }
        break;
      }
    }

    final payload = <String, dynamic>{
      'tool': toolName.isNotEmpty ? toolName : 'tool',
      'arguments': args,
      'result': result,
    };
    return jsonEncode(payload);
  }

  static _NormalizedHostAndPath _normalizeHostAndPath({
    required String providerKey,
    required ProviderKind kind,
    required String apiHost,
    required String apiPath,
    required String endpoint,
  }) {
    String host = apiHost.trim();
    String path = apiPath.trim();

    // Azure settings: prefer endpoint if present.
    if (host.isEmpty && endpoint.trim().isNotEmpty) {
      host = endpoint.trim();
    }

    if (host.isNotEmpty && host.endsWith('/')) {
      host = host.substring(0, host.length - 1);
    }

    // Ensure scheme for host if user stored bare domain
    if (host.isNotEmpty && !(host.startsWith('http://') || host.startsWith('https://'))) {
      host = 'https://$host';
    }

    if (kind == ProviderKind.openai) {
      if (path.isNotEmpty && !path.startsWith('/')) path = '/$path';
      // If host already includes the full path, split it out.
      if (host.toLowerCase().endsWith('/chat/completions')) {
        host = host.substring(0, host.length - '/chat/completions'.length);
        path = '/chat/completions';
      }
      // Avoid appending '/v1' when host already contains a known version segment.
      final lower = host.toLowerCase();
      final hasKnownVersionSuffix = lower.endsWith('/v1') ||
          lower.endsWith('/v1beta') ||
          RegExp(r'/api/v\\d+$').hasMatch(lower) ||
          lower.endsWith('/api/paas/v4') ||
          lower.endsWith('/compatible-mode/v1');
      if (path.isEmpty) {
        path = '/chat/completions';
      }
      if (host.isNotEmpty && !hasKnownVersionSuffix && !path.contains('/v1')) {
        host = '$host/v1';
      }
      // Special-case OpenAI and OpenRouter canonicalization (best-effort)
      if (lower.endsWith('://api.openai.com') || lower.endsWith('://api.openai.com/v1')) {
        host = 'https://api.openai.com/v1';
        path = '/chat/completions';
      }
      if (lower.endsWith('://openrouter.ai') || lower.endsWith('://openrouter.ai/api')) {
        host = 'https://openrouter.ai/api/v1';
        path = '/chat/completions';
      }
      return _NormalizedHostAndPath(apiHost: host, apiPath: path);
    }

    if (kind == ProviderKind.claude) {
      // Align with Anthropic: base should end with /v1
      final lower = host.toLowerCase();
      if (host.isNotEmpty && lower == 'https://api.anthropic.com') {
        host = '$host/v1';
      } else if (host.isNotEmpty && !lower.endsWith('/v1') && !RegExp(r'/v\\d+$').hasMatch(lower)) {
        host = '$host/v1';
      }
      return _NormalizedHostAndPath(apiHost: host, apiPath: '');
    }

    if (kind == ProviderKind.google) {
      // Chatbox uses /v1beta; keep if already present.
      final lower = host.toLowerCase();
      if (host.isNotEmpty && !lower.endsWith('/v1beta')) {
        host = '$host/v1beta';
      }
      return _NormalizedHostAndPath(apiHost: host, apiPath: '');
    }

    return _NormalizedHostAndPath(apiHost: host, apiPath: path);
  }
}

class _NormalizedHostAndPath {
  final String apiHost;
  final String apiPath;
  const _NormalizedHostAndPath({required this.apiHost, required this.apiPath});
}

class _AssistantsConversationsResult {
  final int assistants;
  final int conversations;
  final int messages;
  final List<String> assistantIds;
  const _AssistantsConversationsResult({
    required this.assistants,
    required this.conversations,
    required this.messages,
    required this.assistantIds,
  });
}
