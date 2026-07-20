import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../utils/app_directories.dart';
import '../models/assistant.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../providers/settings_provider.dart';
import 'api/chat_api_service.dart';
import 'chat/prompt_transformer.dart';
import 'instruction_injection_store.dart';
import 'logging/flutter_logger.dart';
import 'memory_store.dart';
import 'proactive_care_service.dart';

const String _logTag = 'ProactiveCareFlow';

/// Snapshot of localized strings needed by the proactive care background
/// isolate, which has no BuildContext / AppLocalizations. The main isolate
/// saves it on every app start (see main.dart), so by the time an alarm can
/// fire the snapshot reflects the user's UI language.
class ProactiveCareL10nSnapshot {
  const ProactiveCareL10nSnapshot({
    required this.defaultConversationTitle,
    required this.carePromptDefault,
    required this.decisionPromptDefault,
    required this.failureNotificationBody,
  });

  static const String _prefsKey = 'proactive_care_l10n_v1';

  final String defaultConversationTitle;
  final String carePromptDefault;
  final String decisionPromptDefault;
  final String failureNotificationBody;

  static Future<void> save({
    required String defaultConversationTitle,
    required String carePromptDefault,
    required String decisionPromptDefault,
    required String failureNotificationBody,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(<String, String>{
        'defaultConversationTitle': defaultConversationTitle,
        'carePromptDefault': carePromptDefault,
        'decisionPromptDefault': decisionPromptDefault,
        'failureNotificationBody': failureNotificationBody,
      }),
    );
  }

  static Future<ProactiveCareL10nSnapshot?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return ProactiveCareL10nSnapshot(
        defaultConversationTitle:
            (map['defaultConversationTitle'] as String?) ?? '',
        carePromptDefault: (map['carePromptDefault'] as String?) ?? '',
        decisionPromptDefault: (map['decisionPromptDefault'] as String?) ?? '',
        failureNotificationBody:
            (map['failureNotificationBody'] as String?) ?? '',
      );
    } catch (e) {
      FlutterLogger.log('L10n snapshot load failed: $e', tag: _logTag);
      return null;
    }
  }
}

/// Resolved provider/model for a proactive care request.
class ProactiveCareModelConfig {
  const ProactiveCareModelConfig({
    required this.config,
    required this.providerKey,
    required this.modelId,
  });

  final ProviderConfig config;
  final String providerKey;
  final String modelId;
}

/// Shared logic for the proactive care message ("Ta的来信") sent when the
/// scheduled care time arrives.
///
/// Everything here is headless (no BuildContext): the same code path runs in
/// the main isolate (app alive) and in the alarm background isolate (app
/// killed). Only data loading and persistence differ between the two paths:
/// the main isolate uses providers + ChatService, the background isolate uses
/// SQLite via [ProactiveCareHeadlessChatStore].
class ProactiveCareMessageFlow {
  const ProactiveCareMessageFlow._();

  // SharedPreferences keys owned by other classes that keep them private.
  // They are stable v1 keys; keep in sync with SettingsProvider.
  static const String _selectedModelPrefsKey = 'selected_model_v1';
  static const String _providerConfigsPrefsKey = 'provider_configs_v1';
  // Keep in sync with UserProvider.
  static const String _userNamePrefsKey = 'user_name';

  /// Loads [assistantId] from SQLite (background isolate path).
  static Future<Assistant?> loadAssistantFromDb(String assistantId) async {
    try {
      return await ProactiveCareHeadlessChatStore.loadAssistantFor(assistantId);
    } catch (e) {
      FlutterLogger.log('Load assistant from DB failed: $e', tag: _logTag);
    }
    return null;
  }

  /// Persists a new next-care time for [assistantId] in SQLite (background
  /// isolate path; the app process is dead, so there is no concurrent writer).
  static Future<bool> updateAssistantNextCareTimeInDb(
    String assistantId,
    DateTime nextCareTime,
  ) async {
    try {
      await ProactiveCareHeadlessChatStore.updateNextCareTime(
        assistantId,
        nextCareTime,
      );
      return true;
    } catch (e) {
      FlutterLogger.log(
        'Persist next care time to DB failed: $e',
        tag: _logTag,
      );
      return false;
    }
  }

  /// Resolves the chat model for [assistant] from SharedPreferences:
  /// assistant-specific model first, then the globally selected model
  /// (mirrors the decision flow in HomeViewModel).
  static Future<ProactiveCareModelConfig?> loadModelConfigFromPrefs(
    Assistant assistant,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    String? provKey = assistant.chatModelProvider;
    String? modelId = assistant.chatModelId;
    if (provKey == null || modelId == null) {
      final sel = prefs.getString(_selectedModelPrefsKey);
      if (sel != null && sel.contains('::')) {
        final parts = sel.split('::');
        if (parts.length >= 2) {
          provKey ??= parts[0];
          modelId ??= parts.sublist(1).join('::');
        }
      }
    }
    if (provKey == null || modelId == null) return null;

    ProviderConfig? cfg;
    try {
      final cfgStr = prefs.getString(_providerConfigsPrefsKey);
      if (cfgStr != null && cfgStr.isNotEmpty) {
        final raw = jsonDecode(cfgStr) as Map<String, dynamic>;
        final entry = raw[provKey];
        if (entry is Map) {
          cfg = ProviderConfig.fromJson(entry.cast<String, dynamic>());
        }
      }
    } catch (e) {
      FlutterLogger.log('Provider configs decode failed: $e', tag: _logTag);
    }
    cfg ??= ProviderConfig.defaultsFor(provKey);
    return ProactiveCareModelConfig(
      config: cfg,
      providerKey: provKey,
      modelId: modelId,
    );
  }

  /// Resolves the proactive care decision model from SharedPreferences.
  /// Falls back to the chat model if no dedicated decision model is set.
  static Future<ProactiveCareModelConfig?> loadDecisionModelConfigFromPrefs(
    Assistant assistant,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final sel = prefs.getString('proactive_care_decision_model_v1');
    if (sel != null && sel.contains('::')) {
      final parts = sel.split('::');
      if (parts.length >= 2) {
        final provKey = parts[0];
        final modelId = parts.sublist(1).join('::');
        ProviderConfig? cfg;
        try {
          final cfgStr = prefs.getString(_providerConfigsPrefsKey);
          if (cfgStr != null && cfgStr.isNotEmpty) {
            final raw = jsonDecode(cfgStr) as Map<String, dynamic>;
            final entry = raw[provKey];
            if (entry is Map) {
              cfg = ProviderConfig.fromJson(entry.cast<String, dynamic>());
            }
          }
        } catch (_) {}
        cfg ??= ProviderConfig.defaultsFor(provKey);
        return ProactiveCareModelConfig(
          config: cfg,
          providerKey: provKey,
          modelId: modelId,
        );
      }
    }
    // Fallback to chat model
    return loadModelConfigFromPrefs(assistant);
  }

  /// Loads the user nickname for system prompt placeholders (background
  /// path). 'User' mirrors UserProvider's built-in default.
  static Future<String> loadUserNicknameFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final n = prefs.getString(_userNamePrefsKey);
      if (n != null && n.isNotEmpty) return n;
    } catch (_) {}
    return 'User';
  }

  /// Collapses message versions, keeping the selected (or latest) version per
  /// group. Same semantics as MessageBuilderService.collapseVersions.
  @visibleForTesting
  static List<ChatMessage> collapseMessageVersions(
    List<ChatMessage> items,
    Map<String, int> versionSelections,
  ) {
    final Map<String, List<ChatMessage>> byGroup =
        <String, List<ChatMessage>>{};
    final List<String> order = <String>[];

    for (final m in items) {
      final gid = (m.groupId ?? m.id);
      final list = byGroup.putIfAbsent(gid, () {
        order.add(gid);
        return <ChatMessage>[];
      });
      list.add(m);
    }

    for (final e in byGroup.entries) {
      e.value.sort((a, b) => a.version.compareTo(b.version));
    }

    final out = <ChatMessage>[];
    for (final gid in order) {
      final vers = byGroup[gid]!;
      final sel = versionSelections[gid];
      final idx = (sel != null && sel >= 0 && sel < vers.length)
          ? sel
          : (vers.length - 1);
      out.add(vers[idx]);
    }
    return out;
  }

  /// Builds the plain-text LLM history for [conversation]: collapsed
  /// versions, truncateIndex applied, only completed non-empty user/assistant
  /// turns (mirrors the decision flow in HomeViewModel).
  static List<Map<String, dynamic>> buildHistory({
    required Conversation conversation,
    required List<ChatMessage> messages,
  }) {
    final collapsed = collapseMessageVersions(
      messages,
      conversation.versionSelections,
    );
    final tIndex = conversation.truncateIndex;
    final effective = (tIndex >= 0 && tIndex <= collapsed.length)
        ? collapsed.sublist(tIndex)
        : collapsed;
    return <Map<String, dynamic>>[
      for (final m in effective)
        if ((m.role == 'user' || m.role == 'assistant') &&
            !m.isStreaming &&
            m.content.trim().isNotEmpty)
          {'role': m.role, 'content': m.content},
    ];
  }

  /// System prompt placeholders without a BuildContext: locale comes from
  /// Platform.localeName instead of Localizations (otherwise mirrors
  /// PromptTransformer.buildPlaceholders).
  @visibleForTesting
  static Map<String, String> buildHeadlessPlaceholders({
    required Assistant assistant,
    required String modelId,
    required String userNickname,
    required DateTime now,
  }) {
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final os = Platform.operatingSystem;
    final osv = Platform.operatingSystemVersion;
    return <String, String>{
      '{cur_date}': date,
      '{cur_time}': time,
      '{cur_datetime}': '$date $time',
      '{model_id}': modelId,
      '{model_name}': modelId,
      '{locale}': Platform.localeName,
      '{timezone}': now.timeZoneName,
      '{system_version}': '$os $osv',
      '{device_info}': os,
      '{battery_level}': 'unknown',
      '{nickname}': userNickname,
      '{assistant_name}': assistant.name,
    };
  }

  /// Assembles the full silent care request (Pipeline ②):
  /// system prompt (placeholders replaced) + memories + instruction
  /// injections + conversation history + the care prompt with the current
  /// system time as the final user turn.
  static Future<List<Map<String, dynamic>>> buildCareApiMessages({
    required Assistant assistant,
    required String userNickname,
    required String modelId,
    required List<Map<String, dynamic>> history,
    required String carePrompt,
    required DateTime now,
  }) async {
    final apiMessages = <Map<String, dynamic>>[
      for (final m in history) Map<String, dynamic>.of(m),
    ];

    // The care prompt is the final user turn so the model replies to it.
    apiMessages.add({
      'role': 'user',
      'content': ProactiveCareService.buildCareUserMessage(
        carePrompt: carePrompt,
        now: now,
      ),
    });

    if (assistant.systemPrompt.trim().isNotEmpty) {
      final vars = buildHeadlessPlaceholders(
        assistant: assistant,
        modelId: modelId,
        userNickname: userNickname,
        now: now,
      );
      apiMessages.insert(0, {
        'role': 'system',
        'content': PromptTransformer.replacePlaceholders(
          assistant.systemPrompt,
          vars,
        ),
      });
    }

    // Memory records.
    if (assistant.enableMemory) {
      try {
        final block = ProactiveCareService.buildMemoriesBlock(
          await MemoryStore.getForAssistant(assistant.id),
        );
        if (block.isNotEmpty) {
          _appendToSystemMessage(apiMessages, block);
        }
      } catch (e) {
        FlutterLogger.log('Memory injection failed: $e', tag: _logTag);
      }
    }

    // Instruction injections.
    try {
      final actives = await InstructionInjectionStore.getActives(
        assistantId: assistant.id,
      );
      final prompts = actives
          .map((e) => e.prompt.trim())
          .where((p) => p.isNotEmpty)
          .toList(growable: false);
      if (prompts.isNotEmpty) {
        _appendToSystemMessage(apiMessages, prompts.join('\n\n'));
      }
    } catch (e) {
      FlutterLogger.log('Instruction injection failed: $e', tag: _logTag);
    }

    return apiMessages;
  }

  static void _appendToSystemMessage(
    List<Map<String, dynamic>> apiMessages,
    String content,
  ) {
    if (apiMessages.isNotEmpty && apiMessages.first['role'] == 'system') {
      apiMessages[0]['content'] =
          '${(apiMessages[0]['content'] ?? '') as String}\n\n$content';
    } else {
      apiMessages.insert(0, {'role': 'system', 'content': content});
    }
  }

  /// Sends the silent care request and returns the aggregated reply text.
  static Future<String> requestCareReply({
    required ProviderConfig config,
    required String modelId,
    required Assistant assistant,
    required List<Map<String, dynamic>> apiMessages,
    int? fallbackThinkingBudget,
  }) async {
    final buf = StringBuffer();
    await for (final chunk in ChatApiService.sendMessageStream(
      config: config,
      modelId: modelId,
      messages: apiMessages,
      thinkingBudget: assistant.thinkingBudget ?? fallbackThinkingBudget,
      temperature: assistant.temperature,
      topP: assistant.topP,
      maxTokens: assistant.maxTokens,
      stream: false,
    )) {
      buf.write(chunk.content);
    }
    return buf.toString().trim();
  }

  /// Silently asks the decision model for the next proactive care time
  /// (Pipeline ①). Returns null when the model declines, fails, or returns
  /// an invalid/past time.
  static Future<DateTime?> decideNextCareTime({
    required ProviderConfig config,
    required String modelId,
    required Assistant assistant,
    required String userNickname,
    required List<Map<String, dynamic>> history,
    required String decisionPrompt,
    int? fallbackThinkingBudget,
  }) async {
    if (history.isEmpty) return null;
    final now = DateTime.now();

    String personaPrompt = '';
    if (assistant.systemPrompt.trim().isNotEmpty) {
      final vars = buildHeadlessPlaceholders(
        assistant: assistant,
        modelId: modelId,
        userNickname: userNickname,
        now: now,
      );
      personaPrompt = PromptTransformer.replacePlaceholders(
        assistant.systemPrompt,
        vars,
      );
    }
    String memoriesBlock = '';
    if (assistant.enableMemory) {
      try {
        memoriesBlock = ProactiveCareService.buildMemoriesBlock(
          await MemoryStore.getForAssistant(assistant.id),
        );
      } catch (e) {
        FlutterLogger.log('Decision memories load failed: $e', tag: _logTag);
      }
    }

    final apiMessages = ProactiveCareService.buildDecisionApiMessages(
      decisionPrompt: decisionPrompt,
      currentNextCareTime: assistant.proactiveCareNextMessageAt,
      now: now,
      history: history,
      personaPrompt: personaPrompt,
      memoriesBlock: memoriesBlock,
    );

    try {
      final buf = StringBuffer();
      await for (final chunk in ChatApiService.sendMessageStream(
        config: config,
        modelId: modelId,
        messages: apiMessages,
        thinkingBudget: assistant.thinkingBudget ?? fallbackThinkingBudget,
        temperature: assistant.temperature,
        topP: assistant.topP,
        maxTokens: assistant.maxTokens,
        stream: false,
      )) {
        buf.write(chunk.content);
      }
      return ProactiveCareService.parseDecision(
        buf.toString(),
        now: DateTime.now(),
      );
    } catch (e) {
      FlutterLogger.log('Decision request failed: $e', tag: _logTag);
      return null;
    }
  }
}

/// Direct SQLite access used ONLY by the proactive care background isolate
/// when the app process is dead, so no ChatService instance has the database
/// open. Never call this from the main isolate: SQLite WAL mode does not
/// support concurrent multi-isolate writes to the same database file.
class ProactiveCareHeadlessChatStore {
  const ProactiveCareHeadlessChatStore._();

  /// Overridable for tests, where path_provider is unavailable.
  @visibleForTesting
  static Future<String> Function() dataDirPathProvider = () async =>
      (await AppDirectories.getAppDataDirectory()).path;

  static sqlite.Database? _db;

  static Future<sqlite.Database> _ensureDb() async {
    if (_db != null) return _db!;
    final dirPath = await dataDirPathProvider();
    final dbPath = '$dirPath/kelivo.sqlite';
    _db = sqlite.sqlite3.open(dbPath);
    _db!.execute('PRAGMA journal_mode = WAL;');
    _db!.execute('PRAGMA foreign_keys = ON;');
    _db!.execute('PRAGMA busy_timeout = 5000;');
    return _db!;
  }

  /// Loads a single assistant by id from the `assistant_rows` table.
  static Future<Assistant?> loadAssistantFor(String assistantId) async {
    final db = await _ensureDb();
    final rows = db.select('SELECT * FROM assistant_rows WHERE id = ?', [
      assistantId,
    ]);
    if (rows.isEmpty) return null;
    return _assistantFromRow(rows.first);
  }

  /// Updates the proactive care next-message time for [assistantId].
  static Future<void> updateNextCareTime(
    String assistantId,
    DateTime nextCareTime,
  ) async {
    final db = await _ensureDb();
    db.execute(
      'UPDATE assistant_rows SET proactive_care_next_message_at = ? WHERE id = ?',
      [nextCareTime.toIso8601String(), assistantId],
    );
  }

  /// Maps a raw sqlite3 row to an [Assistant] via its JSON constructor,
  /// mirroring `ChatDatabaseRepository._assistantFromRow`.
  static Assistant _assistantFromRow(sqlite.Row row) {
    return Assistant.fromJson({
      'id': row['id'] as String,
      'name': row['name'] as String,
      'avatar': row['avatar'] as String?,
      'useAssistantAvatar': (row['use_assistant_avatar'] as int) != 0,
      'useAssistantName': (row['use_assistant_name'] as int) != 0,
      'background': row['background'] as String?,
      'chatModelProvider': row['chat_model_provider'] as String?,
      'chatModelId': row['chat_model_id'] as String?,
      'temperature': row['temperature'] as double?,
      'topP': row['top_p'] as double?,
      'contextMessageSize': row['context_message_size'] as int,
      'limitContextMessages': (row['limit_context_messages'] as int) != 0,
      'streamOutput': (row['stream_output'] as int) != 0,
      'thinkingBudget': row['thinking_budget'] as int?,
      'maxTokens': row['max_tokens'] as int?,
      'systemPrompt': row['system_prompt'] as String,
      'messageTemplate': row['message_template'] as String,
      'searchEnabled': (row['search_enabled'] as int) != 0,
      'mcpServerIds': (jsonDecode(row['mcp_server_ids_json'] as String) as List)
          .cast<String>(),
      'localToolIds': (jsonDecode(row['local_tool_ids_json'] as String) as List)
          .cast<String>(),
      'customHeaders': jsonDecode(row['custom_headers_json'] as String),
      'customBody': jsonDecode(row['custom_body_json'] as String),
      'enableMemory': (row['enable_memory'] as int) != 0,
      'memoryMode': row['memory_mode'] as String,
      'enableRecentChatsReference':
          (row['enable_recent_chats_reference'] as int) != 0,
      'recentChatsSummaryMessageCount':
          row['recent_chats_summary_message_count'] as int,
      'memoryRecordPrompt': row['memory_record_prompt'] as String,
      'docxMode': row['docx_mode'] as String,
      'pdfMode': row['pdf_mode'] as String,
      'otherOfficeMode': row['other_office_mode'] as String,
      'presetMessages': jsonDecode(row['preset_messages_json'] as String),
      'regexRules': jsonDecode(row['regex_rules_json'] as String),
      'enableProactiveCare': (row['enable_proactive_care'] as int) != 0,
      'proactiveCareNextMessageAt':
          row['proactive_care_next_message_at'] as String?,
      'proactiveCarePrompt': row['proactive_care_prompt'] as String,
      'proactiveCareDecisionPrompt':
          row['proactive_care_decision_prompt'] as String,
      'createdAt': row['created_at'] as String,
      'updatedAt': row['updated_at'] as String,
    });
  }

  /// Returns the most recently active conversation of [assistantId] and its
  /// messages, or a null conversation when the assistant has none.
  static Future<({Conversation? conversation, List<ChatMessage> messages})>
  loadRecentConversationFor(String assistantId) async {
    final db = await _ensureDb();

    // Find the most recent conversation for this assistant
    final convRows = db.select(
      'SELECT * FROM conversation_rows WHERE assistant_id = ? ORDER BY updated_at DESC LIMIT 1',
      [assistantId],
    );
    if (convRows.isEmpty) {
      return (conversation: null, messages: const <ChatMessage>[]);
    }

    final row = convRows.first;
    final conversation = Conversation(
      id: row['id'] as String,
      title: row['title'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      isPinned: (row['is_pinned'] as int) != 0,
      assistantId: row['assistant_id'] as String?,
      truncateIndex: row['truncate_index'] as int? ?? -1,
      versionSelections: _parseVersionSelections(
        row['version_selections_json'] as String?,
      ),
    );

    // Load messages for this conversation
    final msgRows = db.select(
      'SELECT * FROM message_rows WHERE conversation_id = ? ORDER BY message_order ASC',
      [conversation.id],
    );
    final messages = <ChatMessage>[];
    for (final mRow in msgRows) {
      messages.add(
        ChatMessage(
          id: mRow['id'] as String,
          role: mRow['role'] as String,
          content: mRow['content'] as String,
          timestamp: DateTime.parse(mRow['timestamp'] as String),
          modelId: mRow['model_id'] as String?,
          providerId: mRow['provider_id'] as String?,
          totalTokens: mRow['total_tokens'] as int?,
          conversationId: mRow['conversation_id'] as String,
          isStreaming: (mRow['is_streaming'] as int? ?? 0) != 0,
          groupId: mRow['group_id'] as String?,
          subgroupId: mRow['subgroup_id'] as String?,
          version: mRow['version'] as int? ?? 0,
        ),
      );
    }

    return (conversation: conversation, messages: messages);
  }

  /// Appends an assistant reply to [conversation], creating a new
  /// conversation titled [fallbackTitle] when null.
  static Future<({Conversation conversation, ChatMessage message})>
  appendAssistantReply({
    required String assistantId,
    required Conversation? conversation,
    required String content,
    required String fallbackTitle,
    String? modelId,
    String? providerId,
  }) async {
    final db = await _ensureDb();

    final convo =
        conversation ??
        Conversation(title: fallbackTitle, assistantId: assistantId);

    final message = ChatMessage(
      role: 'assistant',
      content: content,
      conversationId: convo.id,
      modelId: modelId,
      providerId: providerId,
    );

    // Insert message
    final msgCount =
        (db.select(
              'SELECT COUNT(*) as cnt FROM message_rows WHERE conversation_id = ?',
              [convo.id],
            ).first['cnt']
            as int);

    db.execute(
      '''INSERT OR REPLACE INTO message_rows
         (id, conversation_id, role, content, timestamp, model_id, provider_id,
          total_tokens, is_streaming, group_id, subgroup_id, version, message_order)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        message.id,
        convo.id,
        message.role,
        message.content,
        message.timestamp.toIso8601String(),
        message.modelId,
        message.providerId,
        message.totalTokens,
        0,
        message.groupId,
        message.subgroupId,
        message.version,
        msgCount,
      ],
    );

    // Update conversation
    convo.updatedAt = DateTime.now();
    db.execute(
      '''INSERT OR REPLACE INTO conversation_rows
         (id, title, created_at, updated_at, is_pinned, assistant_id,
          truncate_index, version_selections_json)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        convo.id,
        convo.title,
        convo.createdAt.toIso8601String(),
        convo.updatedAt.toIso8601String(),
        convo.isPinned ? 1 : 0,
        convo.assistantId,
        convo.truncateIndex,
        jsonEncode(convo.versionSelections),
      ],
    );

    return (conversation: convo, message: message);
  }

  /// Flushes and closes the database so all writes hit disk before the
  /// background isolate is torn down.
  static Future<void> close() async {
    try {
      _db?.close();
      _db = null;
    } catch (e) {
      FlutterLogger.log('DB close failed: $e', tag: _logTag);
    }
  }

  static Map<String, int> _parseVersionSelections(String? json) {
    if (json == null || json.isEmpty) return <String, int>{};
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return <String, int>{};
    }
  }
}
