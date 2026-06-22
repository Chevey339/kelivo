import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_directories.dart';
import '../models/assistant.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../providers/assistant_provider.dart';
import '../providers/settings_provider.dart';
import 'api/chat_api_service.dart';
import 'chat/chat_service.dart';
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
/// SharedPreferences + [ProactiveCareHeadlessChatStore].
class ProactiveCareMessageFlow {
  const ProactiveCareMessageFlow._();

  // SharedPreferences keys owned by other classes that keep them private.
  // They are stable v1 keys; keep in sync with SettingsProvider.
  static const String _selectedModelPrefsKey = 'selected_model_v1';
  static const String _providerConfigsPrefsKey = 'provider_configs_v1';
  // Keep in sync with UserProvider.
  static const String _userNamePrefsKey = 'user_name';

  /// Loads [assistantId] from the persisted assistant list (background path).
  static Future<Assistant?> loadAssistantFromPrefs(String assistantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AssistantProvider.assistantsPrefsKey);
      if (raw == null || raw.isEmpty) return null;
      for (final a in Assistant.decodeList(raw)) {
        if (a.id == assistantId) return a;
      }
    } catch (e) {
      FlutterLogger.log('Load assistant failed: $e', tag: _logTag);
    }
    return null;
  }

  /// Persists a new next-care time for [assistantId] (background path; the
  /// app process is dead, so there is no concurrent writer).
  static Future<bool> updateAssistantNextCareTimeInPrefs(
    String assistantId,
    DateTime nextCareTime,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AssistantProvider.assistantsPrefsKey);
      if (raw == null || raw.isEmpty) return false;
      final assistants = Assistant.decodeList(raw);
      final idx = assistants.indexWhere((a) => a.id == assistantId);
      if (idx == -1) return false;
      assistants[idx] = assistants[idx].copyWith(
        proactiveCareNextMessageAt: nextCareTime,
      );
      await prefs.setString(
        AssistantProvider.assistantsPrefsKey,
        Assistant.encodeList(assistants),
      );
      return true;
    } catch (e) {
      FlutterLogger.log('Persist next care time failed: $e', tag: _logTag);
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

  /// Assembles the full silent care request:
  /// system prompt (placeholders replaced) + memories + instruction
  /// injections + conversation history + the care prompt with the current
  /// system time as the final user turn + world book injections.
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

    // The care prompt is the final user turn so the model replies to it; it
    // must be present before world book injection so bottom/at-depth
    // positions and keyword scans account for it.
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

    // Memory records. Unlike the normal chat pipeline, no memory tool
    // instructions are included because tools are not available here.
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

  /// Silently asks the assistant model for the next proactive care time
  /// (mirrors HomeViewModel's decision flow, including the assistant persona
  /// and memories as analysis context). Returns null when the model
  /// declines, fails, or returns an invalid/past time.
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

/// Direct Hive access used ONLY by the proactive care background isolate when
/// the app process is dead, so no ChatService instance has the boxes open.
/// Never call this from the main isolate: Hive does not support concurrent
/// multi-isolate writes to the same box files.
class ProactiveCareHeadlessChatStore {
  const ProactiveCareHeadlessChatStore._();

  /// Overridable for tests, where path_provider is unavailable.
  @visibleForTesting
  static Future<String> Function() dataDirPathProvider = () async =>
      (await AppDirectories.getAppDataDirectory()).path;

  static Future<void> _ensureHive() async {
    // ChatService uses Hive.initFlutter(appDataDir.path), which resolves to
    // the same absolute path; Hive.init avoids the path_provider re-lookup.
    // Hive.init only sets the home path, so it is safe to call repeatedly.
    Hive.init(await dataDirPathProvider());
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ConversationAdapter());
    }
  }

  /// Returns the most recently active conversation of [assistantId] and its
  /// messages, or a null conversation when the assistant has none.
  static Future<({Conversation? conversation, List<ChatMessage> messages})>
  loadRecentConversationFor(String assistantId) async {
    await _ensureHive();
    final convBox = await Hive.openBox<Conversation>(
      ChatService.conversationsBoxName,
    );
    final msgBox = await Hive.openBox<ChatMessage>(ChatService.messagesBoxName);

    Conversation? latest;
    for (final c in convBox.values) {
      if (c.assistantId != assistantId) continue;
      if (latest == null || c.updatedAt.isAfter(latest.updatedAt)) {
        latest = c;
      }
    }
    if (latest == null) {
      return (conversation: null, messages: const <ChatMessage>[]);
    }
    final messages = <ChatMessage>[
      for (final id in latest.messageIds)
        if (msgBox.get(id) != null) msgBox.get(id)!,
    ];
    return (conversation: latest, messages: messages);
  }

  /// Appends an assistant reply to [conversation], creating a new
  /// conversation titled [fallbackTitle] when null. Field semantics
  /// intentionally mirror ChatService.addMessage so the main isolate reads
  /// consistent data on next launch.
  static Future<({Conversation conversation, ChatMessage message})>
  appendAssistantReply({
    required String assistantId,
    required Conversation? conversation,
    required String content,
    required String fallbackTitle,
    String? modelId,
    String? providerId,
  }) async {
    await _ensureHive();
    final convBox = await Hive.openBox<Conversation>(
      ChatService.conversationsBoxName,
    );
    final msgBox = await Hive.openBox<ChatMessage>(ChatService.messagesBoxName);

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
    await msgBox.put(message.id, message);
    convo.messageIds.add(message.id);
    convo.updatedAt = DateTime.now();
    await convBox.put(convo.id, convo);
    return (conversation: convo, message: message);
  }

  /// Flushes and closes the boxes so all writes hit disk before the
  /// background isolate is torn down.
  static Future<void> close() async {
    try {
      await Hive.close();
    } catch (e) {
      FlutterLogger.log('Hive close failed: $e', tag: _logTag);
    }
  }
}
