import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../database/business_data.dart';
import '../../database/business_repository.dart';
import '../../database/business_settings_router.dart';
import '../../database/chat_database_repository.dart'
    show ParsedChatImportBatch;
import '../../models/backup.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../models/message_part.dart';
import '../../utils/multimodal_input_utils.dart';
import '../../../utils/app_directories.dart';
import '../../../utils/kelivo_file_uri.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../providers/settings_provider.dart'
    show ProviderConfig, ProviderKind;
import '../chat/chat_service.dart';
import 'backup_cancel_token.dart';
import 'backup_isolate_runner.dart';
import 'backup_task_progress.dart';
import 'chatbox_backup_archive.dart';
import 'data_sync.dart';

export 'chatbox_backup_archive.dart' show ChatboxImportException;

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

  // Published backup keys used by the business settings router.
  static const String _providersKey = 'provider_configs_v1';
  static const String _providersOrderKey = 'providers_order_v1';
  static const String _assistantsKey = 'assistants_v1';
  static const String _tagsKey = 'assistant_tags_v1';
  static const String _assignKey =
      'assistant_tag_map_v1'; // assistantId -> tagId
  static const String _collapsedKey =
      'assistant_tag_collapsed_v1'; // tagId -> bool

  static Future<ChatboxImportResult> importFromChatbox({
    required File file,
    required RestoreMode mode,
    required BusinessRepository businessRepository,
    required ChatService chatService,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    Directory? staging;
    ChatboxBackupReadResult? archive;
    Object? importError;
    try {
      if (!await file.exists()) {
        throw const ChatboxImportException('Chatbox backup file not found.');
      }
      if (!chatService.initialized) await chatService.init();

      final treatAsZip =
          p.extension(file.path).toLowerCase() == '.zip' ||
          await ChatboxBackupArchive.looksLikeZipFile(file);
      String? resourceDestDir;
      if (treatAsZip) {
        staging = await Directory.systemTemp.createTemp('kelivo_chatbox_res_');
        DataSync.registerLiveTempPath(staging.path);
        final upload = await AppDirectories.getUploadDirectory();
        resourceDestDir = p.join(upload.path, 'chatbox');
      }

      final existingConvs = chatService.getAllCompleteConversations();
      final existingConvIds = existingConvs.map((c) => c.id).toList();
      final existingMsgIds = <String>[];
      if (mode == RestoreMode.merge) {
        for (final c in existingConvs) {
          existingMsgIds.addAll(await chatService.getMessageIds(c.id));
        }
      }

      final prepared =
          await runBackupIsolate<
            _ChatboxPreparedImport,
            _ChatboxImportIsolateArgs
          >(
            body: _prepareChatboxImportInIsolate,
            payload: _ChatboxImportIsolateArgs(
              path: file.path,
              isZip: treatAsZip,
              stagingPath: staging?.path,
              resourceDestDir: resourceDestDir,
              overwrite: mode == RestoreMode.overwrite,
              merge: mode == RestoreMode.merge,
              existingConvIds: existingConvIds,
              existingMsgIds: existingMsgIds,
            ),
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
      archive = prepared.archive;
      final assistantConvRes = prepared.plan;
      final importedProviders = assistantConvRes.providers;
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
      await chatService.commitParsedImport(
        businessRepository: businessRepository,
        overwrite: mode == RestoreMode.overwrite,
        conversationBatches: assistantConvRes.conversationBatches,
        messagesToAppend: assistantConvRes.messagesToAppend,
        transformBusiness: (current) => _transformBusinessData(
          current: current,
          mode: mode,
          providers: importedProviders,
          assistants: assistantConvRes.assistantPayloads,
          assistantIds: assistantConvRes.assistantIds,
        ),
      );
      if (archive != null) {
        // Only publish after the DB commit succeeds. Overwrite also wipes
        // Documents/upload during commit, so this is the sole dest write.
        await ChatboxBackupArchive.publishStagedResources(archive);
      }

      return ChatboxImportResult(
        providers: importedProviders.length,
        assistants: assistantConvRes.assistants,
        conversations: assistantConvRes.conversations,
        messages: assistantConvRes.messages,
      );
    } catch (error) {
      importError = error;
      rethrow;
    } finally {
      if (staging != null) {
        await DataSync.deleteTempDirectoryWhenIsolateSafe(
          staging,
          error: importError,
        );
      }
    }
  }

  // ---------- parsing ----------

  static Future<_ChatboxPreparedImport> _prepareChatboxImportInIsolate(
    BackupIsolateContext ctx,
    _ChatboxImportIsolateArgs args,
  ) async {
    ctx.throwIfCancelled();
    late final Map<String, dynamic> root;
    ChatboxBackupReadResult? archive;
    try {
      if (args.isZip) {
        ctx.reportProgress(
          const BackupProgress(
            phase: BackupPhase.extracting,
            processed: 0,
            cancellable: true,
          ),
        );
        final read = await ChatboxBackupArchive.readZipV2(
          file: File(args.path),
          stagingDir: Directory(args.stagingPath!),
          resourceDestDir: args.resourceDestDir!,
        );
        root = _validateLegacyRootShape(read.root);
        archive = ChatboxBackupReadResult(
          root: const <String, dynamic>{},
          stagedResourceFiles: read.stagedResourceFiles,
          resourceDestDir: read.resourceDestDir,
        );
      } else {
        ctx.reportProgress(
          const BackupProgress(
            phase: BackupPhase.preparing,
            processed: 0,
            cancellable: true,
          ),
        );
        final decoded = jsonDecode(File(args.path).readAsStringSync());
        if (decoded is! Map) {
          throw const ChatboxImportException(
            'Unsupported data format: expected a JSON object.',
          );
        }
        root = _validateLegacyRootShape(
          decoded.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    } catch (e) {
      if (e is ChatboxImportException) rethrow;
      if (e is BackupCancelledException) rethrow;
      if (args.isZip) {
        throw ChatboxImportException('Unable to read Chatbox backup ZIP: $e');
      }
      throw const ChatboxImportException(
        'Invalid JSON: unable to parse Chatbox backup file.',
      );
    }

    if (args.overwrite) {
      final sessionsList = root['chat-sessions-list'];
      if (sessionsList is! List || sessionsList.isEmpty) {
        throw const ChatboxImportException(
          'This Chatbox export does not include chat history. Re-export with "Chat History" enabled, or use merge mode.',
        );
      }
      var hasAnySessionObject = false;
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

    final plan = _parseChatboxPlanInIsolate(
      ctx,
      _ChatboxParseArgs(
        root: root,
        merge: args.merge,
        existingConvIds: args.existingConvIds,
        existingMsgIds: args.existingMsgIds,
      ),
    );
    return _ChatboxPreparedImport(plan: plan, archive: archive);
  }

  static Map<String, dynamic> _validateLegacyRootShape(
    Map<String, dynamic> root,
  ) {
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

  static Map<String, Map<String, dynamic>> _parseProviders(
    Map<String, dynamic> root,
  ) {
    final rawSettings = root['settings'];
    if (rawSettings is! Map) return const {};
    final providers = rawSettings['providers'];
    if (providers is! Map) return const {};

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

    return imported;
  }

  static _AssistantsConversationsResult _parseChatboxPlanInIsolate(
    BackupIsolateContext ctx,
    _ChatboxParseArgs args,
  ) {
    final root = args.root;
    final sessionsListRaw = root['chat-sessions-list'];
    final sessionsList = sessionsListRaw is List
        ? sessionsListRaw
        : const <dynamic>[];
    final existingConvIds = args.existingConvIds.toSet();
    final existingMsgIds = args.existingMsgIds.toSet();

    final importedAssistants = <Map<String, dynamic>>[];
    final importedAssistantIds = <String>[];
    final conversationBatches = <ParsedChatImportBatch>[];
    final messagesToAppend = <String, List<ChatMessage>>{};
    int convCount = 0;
    int msgCount = 0;

    // `__exported_at` is a good fallback timestamp base when message timestamps are missing.
    final exportedAt =
        _parseIsoDateTime((root['__exported_at'] ?? '').toString()) ??
        DateTime.now();

    var sessionIndex = 0;
    final pendingThreads = <_ChatboxPendingThread>[];
    for (final meta in sessionsList) {
      ctx.throwIfCancelled();
      sessionIndex++;
      ctx.reportProgress(
        BackupProgress(
          phase: BackupPhase.importingSessions,
          processed: sessionIndex,
          total: sessionsList.length,
          unit: BackupProgressUnit.items,
          cancellable: true,
        ),
      );
      if (meta is! Map) continue;
      final id = (meta['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      final name = (meta['name'] ?? id).toString();
      final avatar = (meta['picUrl'] ?? '').toString().trim();
      final starred = meta['starred'] as bool? ?? false;

      final sessionRaw = root['session:$id'];
      final session = sessionRaw is Map
          ? sessionRaw.map((k, v) => MapEntry(k.toString(), v))
          : const <String, dynamic>{};
      final sessionSettingsRaw = session['settings'];
      final sessionSettings = sessionSettingsRaw is Map
          ? sessionSettingsRaw.map((k, v) => MapEntry(k.toString(), v))
          : const <String, dynamic>{};

      // Derive assistant config fields.
      final provider = (sessionSettings['provider'] ?? '').toString().trim();
      final modelId = (sessionSettings['modelId'] ?? '').toString().trim();
      final temperature = (sessionSettings['temperature'] as num?)?.toDouble();
      final topP = (sessionSettings['topP'] as num?)?.toDouble();
      final maxTokens = (sessionSettings['maxTokens'] as num?)?.toInt();
      final stream = sessionSettings['stream'] as bool?;
      final contextCount = (sessionSettings['maxContextMessageCount'] as num?)
          ?.toInt();

      final thinkingBudget = _extractThinkingBudget(sessionSettings);

      // Use first system message as assistant system prompt.
      final sysPrompt = _extractSystemPromptFromSession(
        session,
        fallback: _extractDefaultPrompt(root),
      );

      final assistantJson = <String, dynamic>{
        'id': id,
        'name': name,
        'avatar': avatar.isNotEmpty ? avatar : null,
        'useAssistantAvatar': false,
        'useAssistantName': false,
        'chatModelProvider': (provider.isEmpty || provider == 'chatbox-ai')
            ? null
            : provider,
        'chatModelId':
            (provider.isEmpty || provider == 'chatbox-ai' || modelId.isEmpty)
            ? null
            : modelId,
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
        'customHeaders': const <Map<String, String>>[],
        'customBody': const <Map<String, String>>[],
        'enableMemory': false,
        'allowPastConversationRecall': false,
        'presetMessages': const <dynamic>[],
        'regexRules': const <dynamic>[],
      };

      importedAssistants.add(assistantJson);
      importedAssistantIds.add(id);

      // Conversations (topics)
      final threadsRaw = session['threads'];
      final threads = threadsRaw is List ? threadsRaw : const <dynamic>[];
      final sessionMessages = (session['messages'] is List)
          ? session['messages'] as List
          : const <dynamic>[];
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
          if (t is Map)
            t.map((k, v) => MapEntry(k.toString(), v)).cast<String, dynamic>(),
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
        pendingThreads.add(
          _ChatboxPendingThread(
            assistantId: id,
            assistantName: name,
            starred: starred,
            thread: t,
          ),
        );
      }
    }

    var totalMessages = 0;
    for (final pending in pendingThreads) {
      final raw = pending.thread['messages'];
      if (raw is List) totalMessages += raw.length;
    }

    var messageIndex = 0;
    for (final pending in pendingThreads) {
      final t = pending.thread;
      final id = pending.assistantId;
      final name = pending.assistantName;
      final starred = pending.starred;
      final tid = (t['id'] ?? '').toString().trim();
      if (tid.isEmpty) continue;
      final title = ((t['name'] ?? '').toString().trim().isNotEmpty)
          ? (t['name'] ?? '').toString()
          : name;
      final threadMessagesRaw = (t['messages'] is List)
          ? (t['messages'] as List)
          : const <dynamic>[];

      // Convert messages
      final messages = <ChatMessage>[];
      bool consumedSystem = false;
      int fallbackIndex = 0;
      for (final rawMsg in threadMessagesRaw) {
        ctx.throwIfCancelled();
        messageIndex++;
        ctx.reportProgress(
          BackupProgress(
            phase: BackupPhase.importingMessages,
            processed: messageIndex,
            total: totalMessages,
            unit: BackupProgressUnit.items,
            cancellable: true,
          ),
        );
        if (rawMsg is! Map) continue;
        final msg = rawMsg.map((k, v) => MapEntry(k.toString(), v));
        final msgId = (msg['id'] ?? '').toString();
        if (msgId.isEmpty) continue;
        if (args.merge && existingMsgIds.contains(msgId)) {
          continue;
        }

        final roleRaw = (msg['role'] ?? '').toString();
        final parts = _extractMessageParts(msg, roleHint: roleRaw);
        final content = _textFromParts(parts);

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

        final ts =
            _parseMessageTimestamp(msg['timestamp']) ??
            exportedAt.add(Duration(milliseconds: fallbackIndex++));

        if (role == 'tool') {
          // Keep tool-result JSON in a TextPart for tool semantics, but do not
          // drop ImagePart/FilePart attachments extracted from contentParts.
          final toolPayload = _buildToolMessagePayload(
            msg,
            fallbackText: content,
          );
          final attachmentParts = parts
              .where((part) => part is ImagePart || part is FilePart)
              .toList(growable: false);
          messages.add(
            ChatMessage(
              id: msgId,
              role: 'tool',
              parts: <MessagePart>[TextPart(toolPayload), ...attachmentParts],
              timestamp: ts,
              modelId: null,
              providerId: null,
              totalTokens: null,
              conversationId: tid,
            ),
          );
        } else {
          final inferredModel = _inferModelIdFromChatboxMessage(msg);
          final providerId = (msg['aiProvider'] ?? '').toString().trim();
          final totalTokens =
              (msg['tokenCount'] as num?)?.toInt() ??
              (msg['tokensUsed'] as num?)?.toInt();
          final messageParts = roleRaw == 'system'
              ? <MessagePart>[
                  TextPart(content.isEmpty ? '[System]' : '[System]\n$content'),
                  ...parts.where((part) => part is! TextPart),
                ]
              : parts;
          final reasoningTexts = messageParts
              .whereType<ReasoningPart>()
              .map((part) => part.text)
              .where((text) => text.trim().isNotEmpty)
              .toList(growable: false);
          final reasoningText = reasoningTexts.isEmpty
              ? null
              : reasoningTexts.join('\n');
          messages.add(
            ChatMessage(
              id: msgId,
              role: roleRaw == 'system' ? 'assistant' : role,
              parts: messageParts.isEmpty
                  ? const <MessagePart>[TextPart('')]
                  : messageParts,
              timestamp: ts,
              modelId: inferredModel.isNotEmpty ? inferredModel : null,
              providerId: providerId.isNotEmpty ? providerId : null,
              totalTokens: totalTokens,
              conversationId: tid,
              reasoningText: reasoningText,
            ),
          );
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

      if (args.merge && existingConvIds.contains(tid)) {
        messagesToAppend.putIfAbsent(tid, () => []).addAll(messages);
        msgCount += messages.length;
      } else {
        conversationBatches.add((conversation: conv, messages: messages));
        convCount += 1;
        msgCount += messages.length;
      }
    }

    _addCopilotAssistants(
      root,
      importedAssistants: importedAssistants,
      importedAssistantIds: importedAssistantIds,
    );

    return _AssistantsConversationsResult(
      providers: _parseProviders(root),
      assistants: importedAssistantIds.toSet().length,
      conversations: convCount,
      messages: msgCount,
      assistantIds: importedAssistantIds,
      assistantPayloads: importedAssistants,
      conversationBatches: conversationBatches,
      messagesToAppend: messagesToAppend,
    );
  }

  static void _addCopilotAssistants(
    Map<String, dynamic> root, {
    required List<Map<String, dynamic>> importedAssistants,
    required List<String> importedAssistantIds,
  }) {
    final copilots = root['myCopilots'];
    if (copilots is! List) return;
    final seen = importedAssistantIds.toSet();
    for (final raw in copilots) {
      if (raw is! Map) continue;
      final copilot = raw.map((k, v) => MapEntry(k.toString(), v));
      final id = (copilot['id'] ?? '').toString().trim();
      if (id.isEmpty || seen.contains(id)) continue;
      final name = (copilot['name'] ?? id).toString();
      var avatar = (copilot['picUrl'] ?? '').toString().trim();
      final avatarSource = copilot['avatar'];
      if (avatar.isEmpty && avatarSource is Map) {
        if ((avatarSource['type'] ?? '').toString() == 'url') {
          avatar = (avatarSource['url'] ?? '').toString().trim();
        }
      }
      importedAssistants.add(<String, dynamic>{
        'id': id,
        'name': name,
        'avatar': avatar.isNotEmpty ? avatar : null,
        'useAssistantAvatar': false,
        'useAssistantName': false,
        'chatModelProvider': null,
        'chatModelId': null,
        'temperature': null,
        'topP': null,
        'contextMessageSize': 64,
        'limitContextMessages': true,
        'streamOutput': true,
        'thinkingBudget': null,
        'maxTokens': null,
        'systemPrompt': (copilot['prompt'] ?? '').toString(),
        'messageTemplate': '{{ message }}',
        'mcpServerIds': const <String>[],
        'background': null,
        'customHeaders': const <Map<String, String>>[],
        'customBody': const <Map<String, String>>[],
        'enableMemory': false,
        'allowPastConversationRecall': false,
        'presetMessages': const <dynamic>[],
        'regexRules': const <dynamic>[],
      });
      importedAssistantIds.add(id);
      seen.add(id);
    }
  }

  // ---------- atomic business patch ----------

  static BusinessSnapshot _transformBusinessData({
    required BusinessSnapshot current,
    required RestoreMode mode,
    required Map<String, Map<String, dynamic>> providers,
    required List<Map<String, dynamic>> assistants,
    required List<String> assistantIds,
  }) {
    final settings = BusinessSettingsRouter.exportSnapshot(current);
    final overwrite = mode == RestoreMode.overwrite;

    if (overwrite) {
      // Chatbox exports without providers historically left local providers
      // intact, so preserve that importer-specific behavior.
      if (providers.isNotEmpty) {
        settings[_providersKey] = jsonEncode(providers);
        settings[_providersOrderKey] = providers.keys.toList();
      }
      settings[_assistantsKey] = jsonEncode(assistants);
    } else {
      final currentProviders = _jsonObjectMap(
        settings[_providersKey],
        _providersKey,
      );
      for (final entry in providers.entries) {
        final local = currentProviders[entry.key];
        if (local is! Map) {
          currentProviders[entry.key] = entry.value;
          continue;
        }
        final next = local.map((key, value) => MapEntry(key.toString(), value));
        for (final importedField in entry.value.entries) {
          if (importedField.key == 'name') continue;
          final value = importedField.value;
          if (value == null || (value is String && value.trim().isEmpty)) {
            continue;
          }
          next[importedField.key] = value;
        }
        currentProviders[entry.key] = next;
      }
      settings[_providersKey] = jsonEncode(currentProviders);

      final order = List<String>.from(
        (settings[_providersOrderKey] as List).cast<String>(),
      );
      for (final providerId in providers.keys) {
        if (!order.contains(providerId)) order.add(providerId);
      }
      settings[_providersOrderKey] = order;

      final currentAssistants = _jsonObjectList(
        settings[_assistantsKey],
        _assistantsKey,
      );
      final assistantsById = <String, Map<String, dynamic>>{
        for (final assistant in currentAssistants)
          if (assistant['id'] != null) assistant['id'].toString(): assistant,
      };
      for (final assistant in assistants) {
        final id = (assistant['id'] ?? '').toString();
        if (id.isEmpty) continue;
        final local = assistantsById[id];
        if (local == null) {
          assistantsById[id] = assistant;
          continue;
        }
        final prompt = (assistant['systemPrompt'] as String?)?.trim() ?? '';
        if (prompt.isNotEmpty) local['systemPrompt'] = prompt;
        for (final key in const [
          'chatModelProvider',
          'chatModelId',
          'temperature',
          'topP',
          'maxTokens',
          'thinkingBudget',
        ]) {
          final value = assistant[key];
          if (value != null) local[key] = value;
        }
      }
      settings[_assistantsKey] = jsonEncode(assistantsById.values.toList());
    }

    if (assistantIds.isNotEmpty) {
      final tags = overwrite
          ? <Map<String, dynamic>>[]
          : _jsonObjectList(settings[_tagsKey], _tagsKey);
      final assignment = overwrite
          ? <String, dynamic>{}
          : _jsonMap(settings[_assignKey], _assignKey);
      final collapsed = overwrite
          ? <String, dynamic>{}
          : _jsonMap(settings[_collapsedKey], _collapsedKey);

      String? chatboxTagId;
      for (final tag in tags) {
        if ((tag['name'] ?? '').toString().trim().toLowerCase() != 'chatbox') {
          continue;
        }
        final id = (tag['id'] ?? '').toString().trim();
        if (id.isNotEmpty) {
          chatboxTagId = id;
          break;
        }
      }
      final tagId = chatboxTagId ?? const Uuid().v4();
      if (!tags.any((tag) => (tag['id'] ?? '').toString() == tagId)) {
        tags.add(<String, dynamic>{'id': tagId, 'name': 'Chatbox'});
      }

      final nextAssignment = <String, String>{
        for (final entry in assignment.entries)
          entry.key: entry.value.toString(),
      };
      for (final assistantId in assistantIds) {
        final id = assistantId.trim();
        if (id.isEmpty) continue;
        if (overwrite) {
          nextAssignment[id] = tagId;
        } else {
          nextAssignment.putIfAbsent(id, () => tagId);
        }
      }
      final nextCollapsed = <String, bool>{
        for (final entry in collapsed.entries)
          entry.key: entry.value is bool
              ? entry.value as bool
              : entry.value.toString() == 'true',
      };
      nextCollapsed.putIfAbsent(tagId, () => false);

      settings[_tagsKey] = jsonEncode(tags);
      settings[_assignKey] = jsonEncode(nextAssignment);
      settings[_collapsedKey] = jsonEncode(nextCollapsed);
    }

    return BusinessSettingsRouter.normalizeAndRoute(settings);
  }

  static Map<String, dynamic> _jsonObjectMap(Object? raw, String key) {
    final decoded = _jsonMap(raw, key);
    if (decoded.values.any((value) => value is! Map)) {
      throw FormatException(key);
    }
    return decoded;
  }

  static List<Map<String, dynamic>> _jsonObjectList(Object? raw, String key) {
    if (raw is! String) throw FormatException(key);
    final decoded = jsonDecode(raw);
    if (decoded is! List || decoded.any((value) => value is! Map)) {
      throw FormatException(key);
    }
    return decoded
        .cast<Map>()
        .map(
          (value) => value.map(
            (field, fieldValue) => MapEntry(field.toString(), fieldValue),
          ),
        )
        .toList();
  }

  static Map<String, dynamic> _jsonMap(Object? raw, String key) {
    if (raw == null || raw == '') return <String, dynamic>{};
    if (raw is! String) throw FormatException(key);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw FormatException(key);
    return decoded.map((field, value) => MapEntry(field.toString(), value));
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

  static String _extractSystemPromptFromSession(
    Map<String, dynamic> session, {
    required String fallback,
  }) {
    final msgs = session['messages'];
    if (msgs is List) {
      for (final raw in msgs) {
        if (raw is! Map) continue;
        final m = raw.map((k, v) => MapEntry(k.toString(), v));
        if ((m['role'] ?? '').toString() != 'system') continue;
        final content = _textFromParts(
          _extractMessageParts(m, roleHint: 'system'),
        );
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

  static bool _isAvailableChatboxMediaUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('data:image') ||
        lower.startsWith('file:') ||
        KelivoFileUri.isKelivoFileUri(url)) {
      return true;
    }
    if (url.startsWith('/')) return true;
    return RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(url);
  }

  static String _textFromParts(List<MessagePart> parts) {
    return parts
        .whereType<TextPart>()
        .map((part) => part.text)
        .join('\n')
        .trim();
  }

  static List<MessagePart> _extractMessageParts(
    Map<String, dynamic> msg, {
    required String roleHint,
  }) {
    // roleHint retained for call-site clarity; attachment encoding is role-agnostic.
    final _ = roleHint;
    final partsRaw = msg['contentParts'];
    final out = <MessagePart>[];
    final textChunks = <String>[];
    // When an attachment splits text runs, keep one newline so joining TextPart
    // payloads (no separator) yields `before\nafter` rather than `beforeafter`.
    var pendingContentNewline = false;

    void flushText() {
      if (textChunks.isEmpty) return;
      out.add(TextPart(textChunks.join('\n')));
      textChunks.clear();
    }

    void flushTextForAttachment() {
      flushText();
      pendingContentNewline = out.any((part) => part is TextPart);
    }

    void addText(String s) {
      final t = s.replaceAll('\r\n', '\n');
      if (t.trim().isEmpty) return;
      if (pendingContentNewline && textChunks.isEmpty) {
        textChunks.add('');
      }
      pendingContentNewline = false;
      textChunks.add(t);
    }

    String? mimeFor(String uri, {String? explicit, String? fileName}) {
      final e = explicit?.trim();
      if (e != null && e.isNotEmpty) return e;
      final source = (fileName != null && fileName.isNotEmpty) ? fileName : uri;
      final inferred = inferMediaMimeFromSource(source);
      return inferred.isNotEmpty ? inferred : null;
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
            final available = _isAvailableChatboxMediaUrl(url);
            if (available || storageKey.isNotEmpty) {
              flushTextForAttachment();
              out.add(
                ImagePart(
                  uri: SandboxPathResolver.canonicalize(ref),
                  mime: mimeFor(ref),
                  unavailable: !available,
                ),
              );
            } else {
              addText('[Chatbox image: $ref]');
            }
            break;
          case 'info':
            addText((part['text'] ?? '').toString());
            break;
          case 'reasoning':
            final t = (part['text'] ?? '').toString();
            if (t.trim().isNotEmpty) {
              flushText();
              out.add(ReasoningPart(t));
              // Same bridging newline as attachments so before/reasoning/after
              // yields derived content `before\nafter`.
              pendingContentNewline = out.any((p) => p is TextPart);
            }
            break;
          case 'tool-call':
            final state = (part['state'] ?? '').toString();
            final toolName = (part['toolName'] ?? '').toString();
            final args = part['args'];
            if (state.isNotEmpty) {
              addText(
                '[tool:$state] ${toolName.isNotEmpty ? toolName : 'tool'} ${args == null ? '' : jsonEncode(args)}'
                    .trim(),
              );
            }
            final result = (part['result'] ?? '').toString();
            if (result.trim().isNotEmpty) addText(result);
            break;
          default:
            break;
        }
      }
    }

    // Fallback to legacy `content`
    if (out.isEmpty && textChunks.isEmpty) {
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
          addText('[$title]($url)');
        } else {
          addText(url);
        }
      }
    }

    // Files — known attachment objects become FilePart directly
    final files = msg['files'];
    if (files is List) {
      for (final f in files) {
        if (f is! Map) continue;
        final url = (f['url'] ?? '').toString().trim();
        if (url.isEmpty) continue;
        final name = (f['name'] ?? 'file').toString();
        final type = (f['fileType'] ?? '').toString();
        flushTextForAttachment();
        out.add(
          FilePart(
            uri: SandboxPathResolver.canonicalize(url),
            name: name.isNotEmpty ? name : 'file',
            mime:
                mimeFor(url, explicit: type, fileName: name) ??
                'application/octet-stream',
          ),
        );
      }
    }

    // Pictures (legacy image list)
    final pics = msg['pictures'];
    if (pics is List) {
      for (final p in pics) {
        if (p is! Map) continue;
        final url = (p['url'] ?? '').toString().trim();
        if (url.isEmpty) continue;
        flushTextForAttachment();
        out.add(
          ImagePart(
            uri: SandboxPathResolver.canonicalize(url),
            mime: mimeFor(url),
          ),
        );
      }
    }

    // Error info
    final err = (msg['error'] ?? '').toString();
    if (err.trim().isNotEmpty) {
      addText('[Error] $err');
    }

    flushText();
    return out;
  }

  static String _inferModelIdFromChatboxMessage(Map<String, dynamic> msg) {
    final raw = (msg['model'] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    final m = RegExp(r'\\(([^)]+)\\)\\s*$').firstMatch(raw);
    if (m != null) return (m.group(1) ?? '').trim();
    return raw;
  }

  static String _buildToolMessagePayload(
    Map<String, dynamic> msg, {
    required String fallbackText,
  }) {
    String toolName = (msg['name'] ?? '').toString().trim();
    Map<String, dynamic> args = const <String, dynamic>{};
    String result = fallbackText;

    final parts = msg['contentParts'];
    if (parts is List) {
      for (final p in parts) {
        if (p is! Map) continue;
        final part = p.map((k, v) => MapEntry(k.toString(), v));
        if ((part['type'] ?? '').toString() != 'tool-call') continue;
        toolName = toolName.isNotEmpty
            ? toolName
            : (part['toolName'] ?? '').toString();
        final a = part['args'];
        if (a is Map) args = a.cast<String, dynamic>();
        if (part.containsKey('result')) {
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
    if (host.isNotEmpty &&
        !(host.startsWith('http://') || host.startsWith('https://'))) {
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
      final hasKnownVersionSuffix =
          lower.endsWith('/v1') ||
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
      if (lower.endsWith('://api.openai.com') ||
          lower.endsWith('://api.openai.com/v1')) {
        host = 'https://api.openai.com/v1';
        path = '/chat/completions';
      }
      if (lower.endsWith('://openrouter.ai') ||
          lower.endsWith('://openrouter.ai/api')) {
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
      } else if (host.isNotEmpty &&
          !lower.endsWith('/v1') &&
          !RegExp(r'/v\\d+$').hasMatch(lower)) {
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

class _ChatboxPendingThread {
  const _ChatboxPendingThread({
    required this.assistantId,
    required this.assistantName,
    required this.starred,
    required this.thread,
  });

  final String assistantId;
  final String assistantName;
  final bool starred;
  final Map<String, dynamic> thread;
}

class _ChatboxParseArgs {
  const _ChatboxParseArgs({
    required this.root,
    required this.merge,
    required this.existingConvIds,
    required this.existingMsgIds,
  });

  final Map<String, dynamic> root;
  final bool merge;
  final List<String> existingConvIds;
  final List<String> existingMsgIds;
}

class _ChatboxImportIsolateArgs {
  const _ChatboxImportIsolateArgs({
    required this.path,
    required this.isZip,
    required this.overwrite,
    required this.merge,
    required this.existingConvIds,
    required this.existingMsgIds,
    this.stagingPath,
    this.resourceDestDir,
  });

  final String path;
  final bool isZip;
  final String? stagingPath;
  final String? resourceDestDir;
  final bool overwrite;
  final bool merge;
  final List<String> existingConvIds;
  final List<String> existingMsgIds;
}

class _ChatboxPreparedImport {
  const _ChatboxPreparedImport({required this.plan, this.archive});

  final _AssistantsConversationsResult plan;
  final ChatboxBackupReadResult? archive;
}

class _NormalizedHostAndPath {
  final String apiHost;
  final String apiPath;
  const _NormalizedHostAndPath({required this.apiHost, required this.apiPath});
}

class _AssistantsConversationsResult {
  final Map<String, Map<String, dynamic>> providers;
  final int assistants;
  final int conversations;
  final int messages;
  final List<String> assistantIds;
  final List<Map<String, dynamic>> assistantPayloads;
  final List<ParsedChatImportBatch> conversationBatches;
  final Map<String, List<ChatMessage>> messagesToAppend;
  const _AssistantsConversationsResult({
    required this.providers,
    required this.assistants,
    required this.conversations,
    required this.messages,
    required this.assistantIds,
    required this.assistantPayloads,
    required this.conversationBatches,
    required this.messagesToAppend,
  });
}
