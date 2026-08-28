import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../../core/database/chat_database_repository.dart';
import '../../../core/models/assistant.dart';
import '../../../core/models/chat_input_data.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/message_part.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/instruction_injection.dart';
import '../../../core/models/memory_entry.dart';
import '../../../core/models/world_book.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/chat/document_text_extractor.dart';
import '../../../utils/mcp_structured_image.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../core/services/chat/prompt_transformer.dart';
import '../../../core/services/logging/context_log_models.dart';
import '../../../core/services/logging/context_logger.dart';
import '../../../core/services/memory/memory_block_builder.dart';
import '../../../core/services/memory/memory_prompts.dart';
import '../../../core/services/search/search_tool_service.dart';
import '../../../core/providers/instruction_injection_provider.dart';
import '../../../core/providers/world_book_provider.dart';
import '../../../core/services/api/builtin_tools.dart';
import '../../../core/services/api/providers/claude/claude_container.dart';
import '../../../core/services/api/providers/claude/claude_history.dart';
import '../../../core/models/assistant_regex.dart';
import '../../../core/utils/multimodal_input_utils.dart';
import '../../../utils/assistant_regex.dart';
import '../../../utils/markdown_media_sanitizer.dart';
import 'ocr_service.dart';

/// Result of §7.6 memory-prefix resolution.
typedef MemoryPrefixResolution = ({
  String prefix,
  String? hash,
  String? snapshotKind,
});

/// Memory injection state shared by the messages assembled in one request.
///
/// Persisted conversations could read all of this back from the database, but
/// temporary ones are never written there, so without a pass-scoped record each
/// message would look like the first and re-inject the same snapshot.
class MemoryInjectionPass {
  /// Revision ids that received a memory block during this request.
  final Set<String> snapshotCarriers = <String>{};

  /// The most recent hash injected during this request, if any.
  String? get injectedHash => _injectedHash;
  String? _injectedHash;

  /// Whether [injectedHash] has been set, distinguishing "none yet" from a
  /// legitimately null hash.
  bool get hasInjectedHash => _hasInjectedHash;
  bool _hasInjectedHash = false;

  void recordInjectedHash(String? hash) {
    _injectedHash = hash;
    _hasInjectedHash = true;
  }
}

/// Service for building API messages from conversation state.
///
/// This service handles:
/// - Building API messages list from chat history
/// - Processing user messages (documents, OCR, templates)
/// - Injecting system prompts
/// - Injecting memory and recent chats context
/// - Injecting search prompts
/// - Injecting instruction prompts
/// - Applying context limits
/// - Inlining local images for model context
class MessageBuilderService {
  static const String internalMediaPathsKey = multimodalInternalMediaPathsKey;
  static const String internalRevisionIdKey = multimodalInternalRevisionIdKey;

  MessageBuilderService({
    required this.chatService,
    required this.contextProvider,
    this.chatRepository,
    this.ocrHandler,
    this.ocrPrefetch,
    this.geminiThoughtSignatureHandler,
    this.providerArtifactLookup,
  });

  final ChatService chatService;

  /// Optional override for `promptContent` freeze and §7.6 injection.
  /// When null, falls back to [ChatService.chatRepositoryOrNull].
  final ChatDatabaseRepository? chatRepository;

  ChatDatabaseRepository? get _repo =>
      chatRepository ?? chatService.chatRepositoryOrNull;

  /// Build context (used for accessing providers via context.read)
  final BuildContext contextProvider;

  /// OCR handler for processing images (optional, injected from home_page)
  final Future<String?> Function(
    List<String> imagePaths, {
    String? revisionId,
    OcrPrepareSession? session,
  })?
  ocrHandler;

  /// Optional batch prefetch of persisted OCR before per-message processing.
  final Future<OcrPrepareSession> Function({
    required List<String> revisionIds,
    required List<String> imagePaths,
  })?
  ocrPrefetch;

  /// OCR text wrapper function
  String Function(String ocrText)? ocrTextWrapper;

  /// Handler to append Gemini thought signatures for API calls
  final String Function(ChatMessage message, String content)?
  geminiThoughtSignatureHandler;

  /// Provider state stored against an assistant message (a container id), by
  /// kind. It rides along under an internal key the provider strips.
  final String? Function(ChatMessage message, String kind)?
  providerArtifactLookup;

  /// Cache for document text extraction to avoid re-reading files on every message
  /// Keyed by path, validated with (modified + size) to avoid stale reuse.
  final Map<String, _DocTextCacheEntry> _docTextCache =
      <String, _DocTextCacheEntry>{};

  /// Collapse message versions to show only selected version per group.
  List<ChatMessage> collapseVersions(
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

    // Sort each group by version
    for (final e in byGroup.entries) {
      e.value.sort((a, b) => a.version.compareTo(b.version));
    }

    // Select the appropriate version from each group
    final out = <ChatMessage>[];
    for (final gid in order) {
      final vers = byGroup[gid]!;
      final sel = versionSelections[gid];
      ChatMessage? selected;
      if (sel != null) {
        for (final candidate in vers) {
          if (candidate.version == sel) {
            selected = candidate;
            break;
          }
        }
      }
      out.add(selected ?? vers.last);
    }

    return out;
  }

  /// Build API messages list from current conversation state.
  ///
  /// Applies truncation and version collapsing. Attachments come from parts.
  List<Map<String, dynamic>> buildApiMessages({
    required List<ChatMessage> messages,
    required Map<String, int> versionSelections,
    required Conversation? currentConversation,
    bool includeToolMessages = false,
  }) {
    final tIndex = currentConversation?.truncateIndex ?? -1;
    final List<ChatMessage> sourceAll =
        (tIndex >= 0 && tIndex <= messages.length)
        ? messages.sublist(tIndex)
        : List.of(messages);
    final List<ChatMessage> source = collapseVersions(
      sourceAll,
      versionSelections,
    );

    final out = <Map<String, dynamic>>[];

    for (final m in source) {
      String? assistantReasoningContent;
      dynamic reasoningDetails;
      if (m.role == 'assistant') {
        assistantReasoningContent = _reasoningContentForToolContinuation(m);
        reasoningDetails = _reasoningDetailsForApi(m);
      }
      if (includeToolMessages && m.role == 'assistant') {
        final events = chatService.getToolEvents(m.id);
        if (events.isNotEmpty) {
          // Tool-call history is only valid once every call has a result.
          final hasPendingToolEvent = events.any((e) => e['content'] == null);
          if (!hasPendingToolEvent) {
            final calls = <Map<String, dynamic>>[];
            final toolMessages = <Map<String, dynamic>>[];

            for (int i = 0; i < events.length; i++) {
              final e = events[i];
              final name = (e['name'] ?? '').toString().trim();
              if (name.isEmpty) continue;
              final rawId = (e['id'] ?? '').toString().trim();
              final id = rawId.isNotEmpty
                  ? rawId
                  : 'call_${m.id.substring(0, m.id.length < 8 ? m.id.length : 8)}_$i';

              Map<String, dynamic> args = const <String, dynamic>{};
              final a = e['arguments'];
              if (a is Map) {
                args = a.map((k, v) => MapEntry(k.toString(), v));
              }
              String argumentsJson = '{}';
              try {
                argumentsJson = jsonEncode(args);
              } catch (_) {}

              calls.add({
                'id': id,
                'type': 'function',
                'function': {'name': name, 'arguments': argumentsJson},
                if (e['metadata'] is Map)
                  'metadata': (e['metadata'] as Map).cast<String, dynamic>(),
              });

              final c = e['content'];
              toolMessages.add({
                'role': 'tool',
                'name': name,
                'tool_call_id': id,
                'content': toolResultContentForModel(c?.toString()),
                if (e['metadata'] is Map)
                  'metadata': (e['metadata'] as Map).cast<String, dynamic>(),
              });
            }

            if (calls.isNotEmpty) {
              final assistantToolMessage = <String, dynamic>{
                'role': 'assistant',
                'content': '\n\n',
                'tool_calls': calls,
              };
              final turn = providerArtifactLookup?.call(
                m,
                claudeTurnArtifactKind,
              );
              if (turn != null && turn.isNotEmpty) {
                assistantToolMessage[multimodalInternalClaudeTurnKey] = turn;
              }
              if (assistantReasoningContent?.isNotEmpty == true) {
                assistantToolMessage['reasoning_content'] =
                    assistantReasoningContent;
              }
              // The persisted reasoning_details belong to the final round of
              // this message; attaching them to this synthetic pre-tool
              // assistant message as well would replay the same reasoning
              // twice, which OpenRouter/Anthropic reject. Only the final
              // assistant message below carries them.
              if (ContextLogger.enabled) {
                ContextSegmentTags.replaceWithSingle(
                  assistantToolMessage,
                  source: ContextSource.toolCall,
                  length: (assistantToolMessage['content'] ?? '')
                      .toString()
                      .length,
                );
                for (final toolMessage in toolMessages) {
                  ContextSegmentTags.replaceWithSingle(
                    toolMessage,
                    source: ContextSource.toolResult,
                    length: (toolMessage['content'] ?? '').toString().length,
                  );
                }
              }
              out.add(assistantToolMessage);
              out.addAll(toolMessages);
            }
          }
        }
      }

      var content = m.content;
      if (m.role == 'assistant' && geminiThoughtSignatureHandler != null) {
        content = geminiThoughtSignatureHandler!(m, content);
      }
      final mediaRefs = mediaRefsFromParts(m);
      // Pure-attachment turns have empty text content but still must be sent.
      // Document FileParts are omitted from mediaRefs (they travel via
      // document extraction), so also keep messages that still have a usable
      // ImagePart/FilePart for processUserMessagesForApi to inject text.
      if (content.isEmpty &&
          mediaRefs.isEmpty &&
          !_hasUsableAttachmentPart(m)) {
        continue;
      }
      final role = m.role == 'assistant' ? 'assistant' : 'user';
      final message = <String, dynamic>{'role': role, 'content': content};
      if (role == 'user') {
        message[internalRevisionIdKey] = m.id;
      } else {
        final container = providerArtifactLookup?.call(
          m,
          claudeContainerArtifactKind,
        );
        if (container != null && container.isNotEmpty) {
          message[multimodalInternalClaudeContainerKey] = container;
        }
      }
      if (mediaRefs.isNotEmpty) {
        message[internalMediaPathsKey] = mediaRefs;
      }
      if (assistantReasoningContent?.isNotEmpty == true) {
        message['reasoning_content'] = assistantReasoningContent;
      }
      if (reasoningDetails != null) {
        message['reasoning_details'] = reasoningDetails;
      }
      if (ContextLogger.enabled) {
        ContextSegmentTags.replaceWithSingle(
          message,
          source: ContextSource.chatHistory,
          length: content.length,
        );
      }
      out.add(message);
    }

    return out;
  }

  /// Collect structured `_kelivo_media_paths` entries from image/file parts.
  ///
  /// Skips unavailable parts. Document (non-media) FileParts are omitted — they
  /// travel through document extraction, not media-path attachments.
  static List<Map<String, dynamic>> mediaRefsFromParts(ChatMessage message) {
    final refs = <Map<String, dynamic>>[];
    for (final part in message.parts) {
      if (part is ImagePart) {
        if (part.unavailable) continue;
        final uri = part.uri.trim();
        if (uri.isEmpty) continue;
        refs.add(encodeInternalMediaRef(uri: uri, mime: part.mime));
      } else if (part is FilePart) {
        if (part.unavailable) continue;
        final uri = part.uri.trim();
        if (uri.isEmpty) continue;
        final effectiveMime = resolveMediaAttachmentMime(
          explicitMime: part.mime ?? '',
          fileName: part.name,
          path: uri,
        );
        if (!(isImageMime(effectiveMime) ||
            isAudioMime(effectiveMime) ||
            isVideoMime(effectiveMime))) {
          continue;
        }
        // Prefer resolved media mime over stale generics like
        // application/octet-stream stored on the part.
        refs.add(
          encodeInternalMediaRef(
            uri: uri,
            mime: effectiveMime.isEmpty ? null : effectiveMime,
          ),
        );
      }
    }
    return refs;
  }

  /// True when the message still has a non-unavailable image/file attachment
  /// that should survive into API preparation even without media refs.
  static bool _hasUsableAttachmentPart(ChatMessage message) {
    for (final part in message.parts) {
      if (part is ImagePart && !part.unavailable) {
        if (part.uri.trim().isNotEmpty) return true;
      } else if (part is FilePart && !part.unavailable) {
        if (part.uri.trim().isNotEmpty) return true;
      }
    }
    return false;
  }

  /// Remove internal keys before provider requests.
  void stripInternalRevisionIds(List<Map<String, dynamic>> apiMessages) {
    for (final message in apiMessages) {
      message.remove(internalRevisionIdKey);
      message.remove(kelivoContextSegmentsKey);
    }
  }

  void _tagFrozenUserPrompt(
    Map<String, dynamic> message, {
    required String payload,
    required bool carriesMemorySnapshot,
  }) {
    if (!carriesMemorySnapshot) {
      ContextSegmentTags.replaceWithSingle(
        message,
        source: ContextSource.chatHistory,
        length: payload.length,
      );
      return;
    }
    final split = MemoryBlockBuilder.splitInjectedPrefix(payload);
    if (split != null && split.rest.isNotEmpty) {
      ContextSegmentTags.write(message, [
        ContextSegmentTags.item(
          source: ContextSource.memorySnapshot,
          length: split.prefix.length,
          meta: {'kind': split.kind},
        ),
        ContextSegmentTags.item(
          source: ContextSource.chatHistory,
          length: split.rest.length,
        ),
      ]);
      return;
    }
    ContextSegmentTags.replaceWithSingle(
      message,
      source: ContextSource.memorySnapshot,
      length: payload.length,
    );
  }

  ChatMessage? _latestPersistedMessage(ChatMessage message) {
    final persisted = chatService.getMessages(message.conversationId);
    for (final candidate in persisted) {
      if (candidate.id == message.id) return candidate;
    }
    return null;
  }

  String _reasoningContentForToolContinuation(ChatMessage message) {
    String pick(ChatMessage candidate) {
      final direct = (candidate.reasoningText ?? '').trim();
      if (direct.isNotEmpty) return direct;

      final raw = (candidate.reasoningSegmentsJson ?? '').trim();
      if (raw.isEmpty) return '';
      try {
        final decoded = jsonDecode(raw);
        final segmentsRaw = switch (decoded) {
          Map<String, dynamic> map => map['segments'],
          List<dynamic> list => list,
          _ => null,
        };
        if (segmentsRaw is! List) return '';
        final parts = <String>[];
        for (final item in segmentsRaw) {
          if (item is! Map) continue;
          final text = (item['text'] ?? '').toString().trim();
          if (text.isNotEmpty) parts.add(text);
        }
        return parts.join('\n').trim();
      } catch (_) {
        return '';
      }
    }

    final fromMessage = pick(message);
    if (fromMessage.isNotEmpty) return fromMessage;

    final persisted = _latestPersistedMessage(message);
    if (persisted == null) return '';
    return pick(persisted);
  }

  /// Extract persisted vendor reasoning details (OpenRouter-style
  /// `reasoning_details`, may carry thinking signatures) so they can be
  /// echoed back to the provider on later turns.
  dynamic _reasoningDetailsForApi(ChatMessage message) {
    dynamic pick(ChatMessage candidate) {
      final raw = (candidate.reasoningSegmentsJson ?? '').trim();
      if (raw.isEmpty) return null;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) return null;
        final details = decoded['reasoningDetails'];
        if (details is List && details.isNotEmpty) return details;
      } catch (_) {}
      return null;
    }

    final fromMessage = pick(message);
    if (fromMessage != null) return fromMessage;

    final persisted = _latestPersistedMessage(message);
    if (persisted == null) return null;
    return pick(persisted);
  }

  /// Parse attachments from structured [ChatMessage.parts].
  ///
  /// Parts-only contract for API request building. Content-marker decode is
  /// not performed here — migration owns that via the legacy decoder.
  ChatInputData parseInputFromMessage(
    ChatMessage message, {
    bool includeMediaFilePathsAsImages = true,
  }) {
    final images = <String>[];
    final docs = <DocumentAttachment>[];
    final textParts = <String>[];
    for (final part in message.parts) {
      if (part is TextPart) {
        textParts.add(part.text);
      } else if (part is ImagePart) {
        // Unavailable parts stay in persisted history for UI placeholders but
        // must not enter API media paths.
        if (part.unavailable) continue;
        final uri = part.uri.trim();
        if (uri.isNotEmpty) images.add(uri);
      } else if (part is FilePart) {
        if (part.unavailable) continue;
        final doc = DocumentAttachment(
          path: part.uri,
          fileName: part.name,
          mime: part.mime ?? '',
        );
        docs.add(doc);
        final effectiveMime = _effectiveAttachmentMime(doc);
        if (includeMediaFilePathsAsImages &&
            (isImageMime(effectiveMime) ||
                isVideoMime(effectiveMime) ||
                isAudioMime(effectiveMime)) &&
            part.uri.trim().isNotEmpty) {
          images.add(part.uri.trim());
        }
      }
    }
    return ChatInputData(
      text: textParts.join().trim(),
      imagePaths: images,
      documents: docs,
    );
  }

  /// Build [ChatInputData] from an API map when no [ChatMessage] is available.
  ///
  /// Uses content text plus [internalMediaPathsKey] only — no marker decode.
  ChatInputData parseInputFromApiMap(
    Map<String, dynamic> message, {
    bool includeMediaFilePathsAsImages = true,
  }) {
    final text = (message['content'] ?? '').toString();
    final mediaRefs = parseInternalMediaRefs(message[internalMediaPathsKey]);
    final mediaPaths = [for (final ref in mediaRefs) ref.uri];
    if (!includeMediaFilePathsAsImages) {
      return ChatInputData(text: text.trim(), imagePaths: mediaPaths);
    }
    final images = <String>[];
    final docs = <DocumentAttachment>[];
    for (final ref in mediaRefs) {
      final path = ref.uri;
      final mime = (ref.mime != null && ref.mime!.trim().isNotEmpty)
          ? ref.mime!.trim()
          : inferMediaMimeFromSource(path);
      if (isAudioMime(mime) || isVideoMime(mime)) {
        final name = path.split(RegExp(r'[\\/]')).last;
        docs.add(
          DocumentAttachment(
            path: path,
            fileName: name.isEmpty ? 'file' : name,
            mime: mime,
          ),
        );
        images.add(path);
      } else {
        images.add(path);
      }
    }
    return ChatInputData(
      text: text.trim(),
      imagePaths: images,
      documents: docs,
    );
  }

  String _effectiveAttachmentMime(DocumentAttachment attachment) {
    return resolveDocumentAttachmentMime(attachment);
  }

  /// True when [apiMessages] still carries attachments that
  /// [processUserMessagesForApi] may have to extract or OCR.
  ///
  /// Deliberately a superset: a frozen prompt can still turn the work into a
  /// no-op. A false result, however, guarantees there is no file work at all —
  /// the remaining cost (frozen prompt reads, memory injection, templating) is
  /// not file parsing and must never raise the parsing indicator.
  bool hasPendingAttachmentWork(
    List<Map<String, dynamic>> apiMessages,
    SettingsProvider settings, {
    Conversation? conversation,
    List<ChatMessage>? sourceMessages,
  }) {
    final bool ocrActive =
        settings.ocrEnabled &&
        settings.ocrModelProvider != null &&
        settings.ocrModelId != null &&
        ocrHandler != null;

    for (final message in apiMessages) {
      if (message['role'] != 'user') continue;
      // WorldBook lore also uses role=user; only persisted input carries a
      // revision id and can hold attachments.
      final revisionId = (message[internalRevisionIdKey] ?? '')
          .toString()
          .trim();
      if (revisionId.isEmpty) continue;
      final chatMessage = _resolveChatMessage(
        revisionId: revisionId,
        conversation: conversation,
        sourceMessages: sourceMessages,
      );
      final parsed = chatMessage != null
          ? parseInputFromMessage(chatMessage)
          : parseInputFromApiMap(message);

      final mediaPaths = <String>{};
      for (final document in parsed.documents) {
        final mime = _effectiveAttachmentMime(document);
        if (isVideoMime(mime) || isAudioMime(mime)) {
          final path = document.path.trim();
          if (path.isNotEmpty) mediaPaths.add(path);
          continue;
        }
        // A document that still needs text extraction.
        return true;
      }
      if (!ocrActive) continue;
      for (final rawPath in parsed.imagePaths) {
        final path = rawPath.trim();
        if (path.isEmpty || mediaPaths.contains(path)) continue;
        // An image OCR still has to read.
        return true;
      }
    }
    return false;
  }

  /// Process user messages in apiMessages: prefer frozen `promptContent`, else
  /// assemble (docs/OCR → memory prefix → template → time) and freeze (§8).
  ///
  /// Returns the image paths from the last user message (for API call).
  Future<List<String>> processUserMessagesForApi(
    List<Map<String, dynamic>> apiMessages,
    SettingsProvider settings,
    Assistant? assistant, {
    Conversation? conversation,
    List<ChatMessage>? sourceMessages,
  }) async {
    final bool ocrActive =
        settings.ocrEnabled &&
        settings.ocrModelProvider != null &&
        settings.ocrModelId != null;

    List<String>? lastUserImagePaths;

    // Only real persisted user messages carry an internal revision ID.
    // WorldBook lore may also use role=user and must not be treated as chat input.
    bool isPersistedUserMessage(Map<String, dynamic> message) {
      if (message['role'] != 'user') return false;
      return (message[internalRevisionIdKey] ?? '')
          .toString()
          .trim()
          .isNotEmpty;
    }

    // Find last real user message index (skip injected lore).
    int lastUserIdx = -1;
    for (int i = apiMessages.length - 1; i >= 0; i--) {
      if (isPersistedUserMessage(apiMessages[i])) {
        lastUserIdx = i;
        break;
      }
    }

    final persistedRevisionIds = <String>[
      for (final message in apiMessages)
        if (isPersistedUserMessage(message))
          (message[internalRevisionIdKey] ?? '').toString().trim(),
    ];
    final frozenPrompts = _repo == null
        ? null
        : await _repo!.getMessagePrompts(persistedRevisionIds);

    // Prefetch OCR only for messages that still need generation (no freeze yet).
    OcrPrepareSession? ocrSession;
    if (ocrActive && ocrPrefetch != null) {
      final revisionIds = <String>[];
      final allImagePaths = <String>{};
      for (final message in apiMessages) {
        if (!isPersistedUserMessage(message)) continue;
        final revisionId = (message[internalRevisionIdKey] ?? '')
            .toString()
            .trim();
        if (frozenPrompts?.containsKey(revisionId) ?? false) continue;
        final revisionForParse = revisionId;
        final chatForParse = _resolveChatMessage(
          revisionId: revisionForParse,
          conversation: conversation,
          sourceMessages: sourceMessages,
        );
        final parsedUser = chatForParse != null
            ? parseInputFromMessage(chatForParse)
            : parseInputFromApiMap(message);
        final videoPaths = <String>{
          for (final d in parsedUser.documents)
            if (isVideoMime(_effectiveAttachmentMime(d))) d.path.trim(),
        }..removeWhere((p) => p.isEmpty);
        final audioPaths = <String>{
          for (final d in parsedUser.documents)
            if (isAudioMime(_effectiveAttachmentMime(d))) d.path.trim(),
        }..removeWhere((p) => p.isEmpty);
        final ocrTargets = parsedUser.imagePaths
            .map((p) => p.trim())
            .where(
              (p) =>
                  p.isNotEmpty &&
                  !videoPaths.contains(p) &&
                  !audioPaths.contains(p),
            )
            .toSet();
        if (ocrTargets.isEmpty) continue;
        if (revisionId.isNotEmpty) revisionIds.add(revisionId);
        allImagePaths.addAll(ocrTargets);
      }
      if (allImagePaths.isNotEmpty) {
        try {
          ocrSession = await ocrPrefetch!(
            revisionIds: revisionIds,
            imagePaths: allImagePaths.toList(growable: false),
          );
        } catch (_) {
          ocrSession = null;
        }
      }
    }

    Future<String?> readDocument(DocumentAttachment d) async {
      // Resolve once so cache key and extractor share the same absolute path.
      // null means rejected (UNC/SMB) — never fall back to the raw path.
      final resolvedPath = SandboxPathResolver.resolveForIo(d.path);
      if (resolvedPath == null) return null;
      // Use file stat to detect content changes without hashing.
      FileStat? stat;
      try {
        stat = await File(resolvedPath).stat();
      } catch (_) {
        stat = null;
      }
      if (stat != null) {
        final cached = _docTextCache[resolvedPath];
        if (cached != null &&
            cached.modifiedMs == stat.modified.millisecondsSinceEpoch &&
            cached.size == stat.size) {
          return cached.text;
        }
      }
      try {
        final text = await DocumentTextExtractor.extractResolved(
          path: resolvedPath,
          mime: d.mime,
        );
        // Cache only when stat is available; otherwise avoid staleness.
        if (stat != null) {
          _docTextCache[resolvedPath] = _DocTextCacheEntry(
            text: text,
            modifiedMs: stat.modified.millisecondsSinceEpoch,
            size: stat.size,
          );
        }
        return text;
      } catch (_) {
        if (stat != null) {
          _docTextCache[resolvedPath] = _DocTextCacheEntry(
            text: null,
            modifiedMs: stat.modified.millisecondsSinceEpoch,
            size: stat.size,
          );
        }
        return null;
      }
    }

    final injectionPass = MemoryInjectionPass();

    for (int i = 0; i < apiMessages.length; i++) {
      if (!isPersistedUserMessage(apiMessages[i])) continue;
      final revisionId = (apiMessages[i][internalRevisionIdKey] ?? '')
          .toString()
          .trim();
      final chatMessageForParts = _resolveChatMessage(
        revisionId: revisionId,
        conversation: conversation,
        sourceMessages: sourceMessages,
      );
      final parsedUser = chatMessageForParts != null
          ? parseInputFromMessage(chatMessageForParts)
          : parseInputFromApiMap(apiMessages[i]);
      final videoPaths = <String>{
        for (final d in parsedUser.documents)
          if (isVideoMime(_effectiveAttachmentMime(d))) d.path.trim(),
      }..removeWhere((p) => p.isEmpty);
      final audioPaths = <String>{
        for (final d in parsedUser.documents)
          if (isAudioMime(_effectiveAttachmentMime(d))) d.path.trim(),
      }..removeWhere((p) => p.isEmpty);

      final mimeByPath = <String, String>{};
      if (chatMessageForParts != null) {
        for (final part in chatMessageForParts.parts) {
          if (part is ImagePart) {
            if (part.unavailable) continue;
            final uri = part.uri.trim();
            if (uri.isEmpty) continue;
            // Prefer resolved media mime over stale generics like
            // application/octet-stream stored on the part.
            final fileName = uri.split(RegExp(r'[\\/]')).last;
            final effectiveMime = resolveMediaAttachmentMime(
              explicitMime: part.mime ?? '',
              fileName: fileName.isEmpty ? uri : fileName,
              path: uri,
            );
            if (effectiveMime.isNotEmpty) mimeByPath[uri] = effectiveMime;
          } else if (part is FilePart) {
            if (part.unavailable) continue;
            final uri = part.uri.trim();
            if (uri.isEmpty) continue;
            final effectiveMime = _effectiveAttachmentMime(
              DocumentAttachment(
                path: uri,
                fileName: part.name,
                mime: part.mime ?? '',
              ),
            );
            if (effectiveMime.isNotEmpty) mimeByPath[uri] = effectiveMime;
          }
        }
      } else {
        for (final ref in parseInternalMediaRefs(
          apiMessages[i][internalMediaPathsKey],
        )) {
          final uri = ref.uri.trim();
          if (uri.isEmpty) continue;
          final fileName = uri.split(RegExp(r'[\\/]')).last;
          final effectiveMime = resolveMediaAttachmentMime(
            explicitMime: ref.mime ?? '',
            fileName: fileName.isEmpty ? uri : fileName,
            path: uri,
          );
          if (effectiveMime.isNotEmpty) mimeByPath[uri] = effectiveMime;
        }
        for (final d in parsedUser.documents) {
          final path = d.path.trim();
          final mime = _effectiveAttachmentMime(d);
          if (path.isNotEmpty && mime.isNotEmpty) {
            mimeByPath.putIfAbsent(path, () => mime);
          }
        }
      }

      final messageMediaPaths = <Map<String, dynamic>>[];
      final seenPaths = <String>{};
      for (final rawPath in parsedUser.imagePaths) {
        final path = rawPath.trim();
        if (path.isEmpty || !seenPaths.add(path)) continue;
        if (ocrActive &&
            !videoPaths.contains(path) &&
            !audioPaths.contains(path)) {
          continue;
        }
        final mime = mimeByPath[path];
        messageMediaPaths.add(encodeInternalMediaRef(uri: path, mime: mime));
      }
      if (messageMediaPaths.isEmpty) {
        apiMessages[i].remove(internalMediaPathsKey);
      } else {
        apiMessages[i][internalMediaPathsKey] = messageMediaPaths;
      }

      // Capture image paths from last user message (from parts).
      if (i == lastUserIdx &&
          lastUserImagePaths == null &&
          parsedUser.imagePaths.isNotEmpty) {
        lastUserImagePaths = List<String>.of(parsedUser.imagePaths);
      }

      // Prefer frozen promptContent — never recompute (§8.3).
      final existing = frozenPrompts?[revisionId];
      if (existing != null) {
        final sendPayload = _legacyAwareFrozenPayload(
          payload: existing.payload,
          carriesMemorySnapshot: existing.carriesMemorySnapshot,
          settings: settings,
        );
        apiMessages[i]['content'] = sendPayload;
        if (ContextLogger.enabled) {
          _tagFrozenUserPrompt(
            apiMessages[i],
            payload: sendPayload,
            carriesMemorySnapshot:
                existing.carriesMemorySnapshot &&
                sendPayload == existing.payload,
          );
        }
        continue;
      }

      // Apply replace-only regexes at send-time on user text.
      final replacedUserText = applyAssistantRegexes(
        parsedUser.text,
        assistant: assistant,
        scope: AssistantRegexScope.user,
        target: AssistantRegexTransformTarget.send,
      );

      // Attachments travel via internalMediaPathsKey / lastUserImagePaths —
      // never re-embed legacy attachment markers into content.
      final cleanedUser = replacedUserText.trim();

      final filePrompts = StringBuffer();
      for (final d in parsedUser.documents) {
        final effectiveMime = _effectiveAttachmentMime(d);
        if (isVideoMime(effectiveMime) || isAudioMime(effectiveMime)) {
          continue;
        }
        final text = await readDocument(d);
        if (text == null || text.trim().isEmpty) continue;
        filePrompts.writeln('## user sent a file: ${d.fileName}');
        filePrompts.writeln('<content>');
        filePrompts.writeln('```');
        filePrompts.writeln(text);
        filePrompts.writeln('```');
        filePrompts.writeln('</content>');
        filePrompts.writeln();
      }

      String merged = (filePrompts.toString() + cleanedUser).trim();
      var canFreezePrompt = true;

      if (ocrActive && ocrHandler != null) {
        final ocrTargets = parsedUser.imagePaths
            .map((p) => p.trim())
            .where(
              (p) =>
                  p.isNotEmpty &&
                  !videoPaths.contains(p) &&
                  !audioPaths.contains(p),
            )
            .toSet()
            .toList();
        if (ocrTargets.isNotEmpty) {
          final ocrText = await ocrHandler!(
            ocrTargets,
            revisionId: revisionId.isEmpty ? null : revisionId,
            session: ocrSession,
          );
          if (ocrText == null) {
            canFreezePrompt = false;
          } else if (ocrText.trim().isNotEmpty) {
            final wrapped = ocrTextWrapper != null
                ? ocrTextWrapper!(ocrText)
                : _defaultWrapOcrBlock(ocrText);
            merged = (wrapped + merged).trim();
          }
        }
      }

      final processedBody = merged.isEmpty ? cleanedUser : merged;
      final chatMessage = _resolveChatMessage(
        revisionId: revisionId,
        conversation: conversation,
        sourceMessages: sourceMessages,
      );

      if (conversation != null && chatMessage != null) {
        apiMessages[i]['content'] = await resolvePromptContent(
          message: chatMessage,
          processedUserBody: processedBody,
          assistant: assistant,
          conversation: conversation,
          settings: settings,
          apiMessages: apiMessages,
          pass: injectionPass,
          readFrozenPrompt: false,
          freezePrompt: canFreezePrompt,
        );
      } else {
        // No conversation or no matching stored message: nothing to freeze
        // against, so render the template without a memory prefix.
        final templ =
            (assistant?.messageTemplate ?? '{{ message }}').trim().isEmpty
            ? '{{ message }}'
            : (assistant?.messageTemplate ?? '{{ message }}');
        final now = chatMessage?.timestamp ?? DateTime.now();
        var content = PromptTransformer.applyMessageTemplate(
          templ,
          role: 'user',
          message: processedBody,
          now: now,
        );
        if (assistant?.appendCurrentTimeToUserMessage == true) {
          content = '$content\n\n${MemoryPrompts.formatCurrentTimeTag(now)}';
        }
        apiMessages[i]['content'] = content;
      }
    }

    return lastUserImagePaths ?? <String>[];
  }

  /// The stored message behind an api payload, or null when it cannot be
  /// found.
  ///
  /// [sourceMessages] is the list this request's api payloads were built from
  /// and is checked first. `ChatService.getMessages` only serves conversations
  /// already in its cache, so on a freshly created conversation it returns
  /// nothing and the new message would silently skip memory injection and
  /// freezing — then pick both up a turn later, rewriting history and losing
  /// the prompt cache.
  ///
  /// A synthesized stand-in would have to invent a timestamp, and freezing that
  /// would bake the wrong `{{ time }}` into the prompt forever, so a genuine
  /// miss returns null and stays on the unfrozen render path.
  ChatMessage? _resolveChatMessage({
    required String revisionId,
    required Conversation? conversation,
    required List<ChatMessage>? sourceMessages,
  }) {
    if (revisionId.isEmpty) return null;
    // Prefer the request's source messages even when Conversation is absent —
    // otherwise structured ImagePart/FilePart attachments are dropped and the
    // caller silently falls back to content-only parsing.
    if (sourceMessages != null) {
      for (final candidate in sourceMessages) {
        if (candidate.id == revisionId) return candidate;
      }
    }
    if (conversation == null) return null;
    for (final candidate in chatService.getMessages(conversation.id)) {
      if (candidate.id == revisionId) return candidate;
    }
    return null;
  }

  /// §8.3 immutability contract: return frozen payload or assemble + freeze.
  Future<String> resolvePromptContent({
    required ChatMessage message,
    required String processedUserBody,
    required Assistant? assistant,
    required Conversation conversation,
    required SettingsProvider settings,
    required List<Map<String, dynamic>> apiMessages,
    MemoryInjectionPass? pass,
    bool readFrozenPrompt = true,
    bool freezePrompt = true,
  }) async {
    final repo = _repo;
    final persist =
        repo != null &&
        !chatService.isTemporaryConversation(message.conversationId);
    if (persist && readFrozenPrompt) {
      final existing = await repo.getMessagePrompt(message.id);
      if (existing != null) {
        return _legacyAwareFrozenPayload(
          payload: existing.payload,
          carriesMemorySnapshot: existing.carriesMemorySnapshot,
          settings: settings,
        );
      }
    }

    final memory = assistant == null
        ? (prefix: '', hash: null, snapshotKind: null)
        : await resolveMemoryPrefix(
            conversation: conversation,
            assistant: assistant,
            apiMessages: apiMessages,
            currentMessageId: message.id,
            lang: settings.resolvedMemoryPromptLang,
            pass: pass,
            settings: settings,
          );
    if (memory.prefix.isNotEmpty) {
      pass?.snapshotCarriers.add(message.id);
    }

    final templ = (assistant?.messageTemplate ?? '{{ message }}').trim().isEmpty
        ? '{{ message }}'
        : (assistant!.messageTemplate);
    final templated = PromptTransformer.applyMessageTemplate(
      templ,
      role: 'user',
      message: processedUserBody,
      now: message.timestamp,
    );
    final timeSuffix = (assistant?.appendCurrentTimeToUserMessage ?? false)
        ? '\n\n${MemoryPrompts.formatCurrentTimeTag(message.timestamp)}'
        : '';
    final finalContent = '${memory.prefix}$templated$timeSuffix';

    if (ContextLogger.enabled) {
      for (final apiMessage in apiMessages) {
        if ((apiMessage[internalRevisionIdKey] ?? '').toString() !=
            message.id) {
          continue;
        }
        if (memory.prefix.isNotEmpty) {
          final kind = memory.snapshotKind;
          ContextSegmentTags.write(apiMessage, [
            ContextSegmentTags.item(
              source: ContextSource.memorySnapshot,
              length: memory.prefix.length,
              meta: kind == null ? null : {'kind': kind},
            ),
            ContextSegmentTags.item(
              source: ContextSource.chatHistory,
              length: finalContent.length - memory.prefix.length,
            ),
          ]);
        } else {
          ContextSegmentTags.replaceWithSingle(
            apiMessage,
            source: ContextSource.chatHistory,
            length: finalContent.length,
          );
        }
        break;
      }
    }

    // Temporary drafts never land in message_rows; freezing would violate the
    // message_prompt_rows FK. Assemble in-memory only for those.
    if (persist && freezePrompt) {
      await repo.freezeMessagePrompt(
        revisionId: message.id,
        conversationId: message.conversationId,
        payload: finalContent,
        carriesMemorySnapshot: memory.prefix.isNotEmpty,
        injectedMemoryHash: memory.hash,
      );
    }

    return finalContent;
  }

  bool _legacyMemoryMode(SettingsProvider? settings) {
    try {
      final resolved = settings ?? contextProvider.read<SettingsProvider>();
      return resolved.legacyMemoryMode;
    } catch (_) {
      return false;
    }
  }

  /// Drop a v2 snapshot that was frozen into history while the new memory
  /// system was on. The stored freeze row is left intact so switching back
  /// still hits prompt cache / hash gating.
  String _legacyAwareFrozenPayload({
    required String payload,
    required bool carriesMemorySnapshot,
    required SettingsProvider settings,
  }) {
    if (!settings.legacyMemoryMode || !carriesMemorySnapshot) return payload;
    return MemoryBlockBuilder.splitInjectedPrefix(payload)?.rest ?? payload;
  }

  /// §7.6 hash gating + self-healing. Compare hash **before** writing it.
  Future<MemoryPrefixResolution> resolveMemoryPrefix({
    required Conversation conversation,
    required Assistant assistant,
    required List<Map<String, dynamic>> apiMessages,
    required String currentMessageId,
    required MemoryPromptLang lang,
    MemoryInjectionPass? pass,
    SettingsProvider? settings,
  }) async {
    if (_legacyMemoryMode(settings) || !assistant.enableMemory) {
      return (prefix: '', hash: null, snapshotKind: null);
    }

    final repo = _repo;
    if (repo == null) {
      return (prefix: '', hash: null, snapshotKind: null);
    }

    SettingsProvider? resolvedSettings = settings;
    if (resolvedSettings == null) {
      try {
        resolvedSettings = contextProvider.read<SettingsProvider>();
      } catch (_) {}
    }
    final maxItems =
        resolvedSettings?.memoryInjectionMaxItems ??
        SettingsProvider.defaultMemoryInjectionMaxItems;

    final fields = await repo.readProfileFields();
    final totalByType = await repo.countVisibleMemoriesByType(
      assistantId: assistant.id,
    );
    final hasAnyMemory = totalByType.values.any((count) => count > 0);
    final hasProfile = fields.any((f) => f.value.trim().isNotEmpty);

    final visible = hasAnyMemory
        ? await repo.queryVisibleMemories(assistantId: assistant.id)
        : const <MemoryEntry>[];
    final profileBlock = MemoryBlockBuilder.buildProfileBlock(
      fields: fields,
      lang: lang,
    );
    final memoryBlock = MemoryBlockBuilder.buildMemoryBlock(
      visible: visible,
      totalByType: totalByType,
      lang: lang,
      maxItems: maxItems,
    );

    final currentHash = MemoryBlockBuilder.hashBlocks(
      profileBlock,
      memoryBlock,
    );

    // Self-healing: any history user message in *this* request carrying a
    // snapshot? Read revision ids before stripInternalRevisionIds; exclude
    // the message being assembled now.
    final historyUserIds = <String>[];
    for (final message in apiMessages) {
      if ((message['role'] ?? '').toString() != 'user') continue;
      final revisionId = (message[internalRevisionIdKey] ?? '')
          .toString()
          .trim();
      if (revisionId.isEmpty || revisionId == currentMessageId) continue;
      historyUserIds.add(revisionId);
    }
    final hasSnapshot =
        historyUserIds.any(
          (id) => pass?.snapshotCarriers.contains(id) ?? false,
        ) ||
        await repo.anyPromptCarriesMemorySnapshot(historyUserIds);

    // With no prior snapshot there is nothing to clear. Once a snapshot has
    // been sent, however, the all-empty state is itself the latest snapshot.
    if (!hasProfile && !hasAnyMemory && !hasSnapshot) {
      return (prefix: '', hash: null, snapshotKind: null);
    }

    // CRITICAL: compare against the prior hash BEFORE any write (appendix §6).
    // Writing first makes currentHash == injectedMemoryHash and the update
    // branch is permanently unreachable.
    //
    // Read from the database, not from [conversation]: callers hand us
    // `conversation.copyWith(...)` and nothing ever loads this column back into
    // the model, so the cached value is stale forever and every turn would look
    // like a change.
    //
    // A hash already injected earlier in this same request wins, because
    // temporary conversations are never persisted and would otherwise read
    // null for every message and repeat an identical update block on each one.
    final previousHash = pass != null && pass.hasInjectedHash
        ? pass.injectedHash
        : await repo.getConversationInjectedMemoryHash(conversation.id);

    final String prefix;
    final String snapshotKind;
    if (!hasSnapshot) {
      prefix = MemoryBlockBuilder.buildFullSnapshotPrefix(
        profileBlock,
        memoryBlock,
        lang,
      );
      snapshotKind = 'full';
    } else if (currentHash != previousHash) {
      prefix = MemoryBlockBuilder.buildUpdatePrefix(
        profileBlock,
        memoryBlock,
        lang,
      );
      snapshotKind = 'update';
    } else {
      return (prefix: '', hash: null, snapshotKind: null);
    }

    // The hash lands in the database through freezeMessagePrompt, in the same
    // transaction as the prompt row.
    pass?.recordInjectedHash(currentHash);
    return (prefix: prefix, hash: currentHash, snapshotKind: snapshotKind);
  }

  /// Default OCR text wrapper
  String _defaultWrapOcrBlock(String ocrText) {
    final buf = StringBuffer();
    buf.writeln(
      "The image_file_ocr tag contains a description of an image that the user uploaded to you, not the user's prompt.",
    );
    buf.writeln('<image_file_ocr>');
    buf.writeln(ocrText.trim());
    buf.writeln('</image_file_ocr>');
    buf.writeln();
    return buf.toString();
  }

  /// Inject system prompt into apiMessages.
  void injectSystemPrompt(
    List<Map<String, dynamic>> apiMessages,
    Assistant? assistant,
    String modelId,
  ) {
    if ((assistant?.systemPrompt.trim().isNotEmpty ?? false)) {
      final vars = PromptTransformer.buildPlaceholders(
        context: contextProvider,
        assistant: assistant!,
        modelId: modelId,
        modelName: modelId,
        userNickname: contextProvider.read<UserProvider>().name,
      );
      final sys = PromptTransformer.replacePlaceholders(
        assistant.systemPrompt,
        vars,
      );
      final sysMessage = <String, dynamic>{'role': 'system', 'content': sys};
      if (ContextLogger.enabled) {
        ContextSegmentTags.replaceWithSingle(
          sysMessage,
          source: ContextSource.systemPrompt,
          length: sys.length,
        );
      }
      apiMessages.insert(0, sysMessage);
    }
  }

  /// Inject §11 memory rules into the system message.
  ///
  /// Pure function of `(enableMemory, allowPastConversationRecall, lang,
  /// user template)` — must not vary with memory content or the clock (§11.1).
  /// Relative order among remaining system injections is preserved by the
  /// caller (`injectSystemPrompt` → this → `injectSearchPrompt` →
  /// `injectInstructionPrompts` → `injectWorldBookPrompts`).
  Future<void> injectMemoryAndRecentChats(
    List<Map<String, dynamic>> apiMessages,
    Assistant? assistant, {
    SettingsProvider? settings,
    String? currentConversationId,
  }) async {
    try {
      if (assistant == null) return;
      if (_legacyMemoryMode(settings)) {
        await _injectLegacyMemoryAndRecentChats(
          apiMessages,
          assistant,
          settings: settings,
          currentConversationId: currentConversationId,
        );
        return;
      }
      // The two gates are independent: chat_search is registered on
      // allowPastConversationRecall alone, so its rules cannot ride along with
      // the long-term memory rules or the tool ships without instructions.
      final wantsMemoryRules = assistant.enableMemory;
      final wantsRecallRules = assistant.allowPastConversationRecall;
      if (!wantsMemoryRules && !wantsRecallRules) return;

      final resolved = settings ?? contextProvider.read<SettingsProvider>();
      final lang = resolved.resolvedMemoryPromptLang;
      final buf = StringBuffer();
      if (wantsMemoryRules) {
        final rules = lang == MemoryPromptLang.zh
            ? resolved.memoryRulesPromptZh
            : resolved.memoryRulesPromptEn;
        buf.write(rules.trim());
      }
      if (wantsRecallRules) {
        if (buf.isNotEmpty) buf.write('\n\n');
        buf.write(MemoryPrompts.rulesPastConversationRecallFor(lang));
      }
      _appendToSystemMessage(
        apiMessages,
        buf.toString(),
        source: ContextSource.memoryRules,
      );
    } catch (_) {}
  }

  Future<void> _injectLegacyMemoryAndRecentChats(
    List<Map<String, dynamic>> apiMessages,
    Assistant assistant, {
    SettingsProvider? settings,
    String? currentConversationId,
  }) async {
    if (assistant.enableMemory) {
      final resolved = settings ?? contextProvider.read<SettingsProvider>();
      final mp = contextProvider.read<MemoryProvider>();
      await mp.initialize();
      final mems = mp.getForAssistant(assistant.id);
      final currentHour = _formatCurrentHour(DateTime.now());
      final buf = StringBuffer();
      buf.writeln('## Memories');
      buf.writeln(
        'These are memories that you can reference in the future conversations.',
      );
      buf.writeln('<memories>');
      for (final m in mems) {
        buf.writeln('<record>');
        buf.writeln('<id>${m.id}</id>');
        buf.writeln('<content>${m.content}</content>');
        buf.writeln('</record>');
      }
      buf.writeln('</memories>');
      final template = resolved.resolvedMemoryPromptLang == MemoryPromptLang.zh
          ? resolved.legacyMemoryPromptZh
          : resolved.legacyMemoryPromptEn;
      buf.writeln(
        template.replaceAll(
          MemoryPrompts.legacyCurrentTimePlaceholder,
          currentHour,
        ),
      );
      _appendToSystemMessage(
        apiMessages,
        buf.toString(),
        source: ContextSource.memoryRules,
      );
    }
    if (assistant.allowPastConversationRecall) {
      final chats = chatService.getAllConversations();
      final excludeId =
          currentConversationId ?? chatService.currentConversationId;
      final relevantChats = chats
          .where((c) => c.assistantId == assistant.id && c.id != excludeId)
          .where((c) => c.title.trim().isNotEmpty)
          .take(10)
          .toList();
      if (relevantChats.isNotEmpty) {
        final sb = StringBuffer();
        sb.writeln('<recent_chats>');
        sb.writeln('这是用户最近的一些对话标题和摘要，你可以参考这些内容了解用户偏好和关注点');
        for (final c in relevantChats) {
          sb.writeln('<conversation>');
          // Format: timestamp: title || summary
          final timestamp = c.updatedAt.toIso8601String().substring(0, 10);
          final title = c.title.trim();
          final summary = (c.summary ?? '').trim();
          if (summary.isNotEmpty) {
            sb.writeln('  $timestamp: $title || $summary');
          } else {
            sb.writeln('  $timestamp: $title');
          }
          sb.writeln('</conversation>');
        }
        sb.writeln('</recent_chats>');
        _appendToSystemMessage(
          apiMessages,
          sb.toString(),
          source: ContextSource.memoryRules,
        );
      }
    }
  }

  String _formatCurrentHour(DateTime now) {
    return '${now.year}年${now.month}月${now.day}日的${now.hour}点';
  }

  /// Inject search tool usage prompt into apiMessages.
  void injectSearchPrompt(
    List<Map<String, dynamic>> apiMessages,
    SettingsProvider settings,
    Assistant? assistant,
    bool hasBuiltInSearch,
  ) {
    if (assistant?.searchEnabled == true && !hasBuiltInSearch) {
      final prompt = SearchToolService.getSystemPrompt();
      _appendToSystemMessage(
        apiMessages,
        prompt,
        source: ContextSource.searchPrompt,
      );
    }
  }

  /// Inject instruction injection prompts into apiMessages.
  Future<void> injectInstructionPrompts(
    List<Map<String, dynamic>> apiMessages,
    String? assistantId,
  ) async {
    try {
      List<InstructionInjection> actives = const <InstructionInjection>[];
      try {
        final ip = contextProvider.read<InstructionInjectionProvider>();
        await ip.initialize();
        actives = ip.activesFor(assistantId);
      } catch (_) {}
      final prompts = actives
          .map((e) => e.prompt.trim())
          .where((p) => p.isNotEmpty)
          .toList(growable: false);
      if (prompts.isNotEmpty) {
        final lp = prompts.join('\n\n');
        _appendToSystemMessage(
          apiMessages,
          lp,
          source: ContextSource.instructionInjection,
        );
      }
    } catch (_) {}
  }

  /// Inject world book (lorebook) entries into apiMessages.
  Future<void> injectWorldBookPrompts(
    List<Map<String, dynamic>> apiMessages,
    String? assistantId,
  ) async {
    try {
      List<WorldBook> all = const <WorldBook>[];
      List<String> activeBookIds = const <String>[];

      try {
        final wb = contextProvider.read<WorldBookProvider>();
        await wb.initialize();
        all = wb.books;
        activeBookIds = wb.activeBookIdsFor(assistantId);
      } catch (_) {}

      if (all.isEmpty || activeBookIds.isEmpty) return;

      final activeSet = activeBookIds.toSet();
      final books = all
          .where((b) => b.enabled && activeSet.contains(b.id))
          .toList(growable: false);
      if (books.isEmpty) return;

      String extractContextForDepth(int scanDepth) {
        final depth = scanDepth <= 0 ? 1 : scanDepth;
        final parts = <String>[];
        for (
          int i = apiMessages.length - 1;
          i >= 0 && parts.length < depth;
          i--
        ) {
          final role = (apiMessages[i]['role'] ?? '').toString();
          if (role != 'user' && role != 'assistant') continue;
          final content = (apiMessages[i]['content'] ?? '').toString().trim();
          if (content.isEmpty) continue;
          parts.add(content);
        }
        return parts.reversed.join('\n');
      }

      bool isTriggered(WorldBookEntry entry, String context) {
        if (!entry.enabled) return false;
        if (entry.constantActive) return true;
        if (entry.keywords.isEmpty) return false;

        for (final raw in entry.keywords) {
          final keyword = raw.trim();
          if (keyword.isEmpty) continue;

          if (entry.useRegex) {
            try {
              final re = RegExp(keyword, caseSensitive: entry.caseSensitive);
              if (re.hasMatch(context)) return true;
            } catch (_) {}
          } else {
            if (entry.caseSensitive) {
              if (context.contains(keyword)) return true;
            } else {
              if (context.toLowerCase().contains(keyword.toLowerCase())) {
                return true;
              }
            }
          }
        }
        return false;
      }

      final contextCache = <int, String>{};
      final triggered = <({WorldBookEntry entry, int seq})>[];
      int seq = 0;

      for (final book in books) {
        for (final entry in book.entries) {
          final depth = (entry.scanDepth <= 0 ? 1 : entry.scanDepth)
              .clamp(1, 200)
              .toInt();
          final ctx = contextCache.putIfAbsent(
            depth,
            () => extractContextForDepth(depth),
          );
          if (isTriggered(entry, ctx)) {
            triggered.add((entry: entry, seq: seq));
          }
          seq++;
        }
      }

      if (triggered.isEmpty) return;

      triggered.sort((a, b) {
        final pa = a.entry.priority;
        final pb = b.entry.priority;
        if (pb != pa) return pb.compareTo(pa);
        return a.seq.compareTo(b.seq);
      });

      String wrapSystemTag(String content) => '<system>\n$content\n</system>';

      String joinContents(Iterable<WorldBookEntry> items) {
        return items
            .map((e) => e.content.trim())
            .where((c) => c.isNotEmpty)
            .join('\n');
      }

      List<Map<String, dynamic>> createMergedInjectionMessages(
        List<WorldBookEntry> injections, {
        required WorldBookInjectionPosition position,
      }) {
        final byRole = <WorldBookInjectionRole, List<WorldBookEntry>>{};
        for (final e in injections) {
          if (e.content.trim().isEmpty) continue;
          byRole.putIfAbsent(e.role, () => <WorldBookEntry>[]).add(e);
        }

        final result = <Map<String, dynamic>>[];
        for (final role in byRole.keys) {
          final group = byRole[role]!;
          final merged = joinContents(group);
          if (merged.isEmpty) continue;
          final message = role == WorldBookInjectionRole.assistant
              ? <String, dynamic>{'role': 'assistant', 'content': merged}
              : <String, dynamic>{
                  'role': 'user',
                  'content': wrapSystemTag(merged),
                };
          if (ContextLogger.enabled) {
            ContextSegmentTags.replaceWithSingle(
              message,
              source: ContextSource.worldBook,
              length: (message['content'] ?? '').toString().length,
              meta: {'position': position.toJson()},
            );
          }
          result.add(message);
        }
        return result;
      }

      int findSafeInsertIndex(List<Map<String, dynamic>> messages, int target) {
        var index = target.clamp(0, messages.length);
        while (index > 0 && index < messages.length) {
          final role = (messages[index]['role'] ?? '').toString();
          if (role != 'tool') break;
          index--;
        }
        return index;
      }

      final byPosition = <WorldBookInjectionPosition, List<WorldBookEntry>>{};
      for (final t in triggered) {
        byPosition
            .putIfAbsent(t.entry.position, () => <WorldBookEntry>[])
            .add(t.entry);
      }

      // BEFORE/AFTER_SYSTEM_PROMPT: merge into system message.
      final beforeContent = joinContents(
        byPosition[WorldBookInjectionPosition.beforeSystemPrompt] ??
            const <WorldBookEntry>[],
      );
      final afterContent = joinContents(
        byPosition[WorldBookInjectionPosition.afterSystemPrompt] ??
            const <WorldBookEntry>[],
      );

      if (beforeContent.isNotEmpty || afterContent.isNotEmpty) {
        final systemIndex = apiMessages.indexWhere(
          (m) => (m['role'] ?? '').toString() == 'system',
        );
        if (systemIndex >= 0) {
          final original = (apiMessages[systemIndex]['content'] ?? '')
              .toString();
          final sb = StringBuffer();
          if (beforeContent.isNotEmpty) {
            sb.write(beforeContent);
            sb.write('\n');
          }
          sb.write(original);
          if (afterContent.isNotEmpty) {
            sb.write('\n');
            sb.write(afterContent);
          }
          apiMessages[systemIndex]['content'] = sb.toString();
          if (ContextLogger.enabled) {
            final sysMsg = apiMessages[systemIndex];
            if (beforeContent.isNotEmpty) {
              ContextSegmentTags.prepend(
                sysMsg,
                source: ContextSource.worldBook,
                length: beforeContent.length + 1,
                meta: {
                  'position': WorldBookInjectionPosition.beforeSystemPrompt
                      .toJson(),
                },
              );
            }
            if (afterContent.isNotEmpty) {
              ContextSegmentTags.append(
                sysMsg,
                source: ContextSource.worldBook,
                length: 1 + afterContent.length,
                meta: {
                  'position': WorldBookInjectionPosition.afterSystemPrompt
                      .toJson(),
                },
              );
            }
          }
        } else {
          final sb = StringBuffer();
          if (beforeContent.isNotEmpty) sb.write(beforeContent);
          if (afterContent.isNotEmpty) {
            if (sb.isNotEmpty) sb.write('\n');
            sb.write(afterContent);
          }
          if (sb.isNotEmpty) {
            final created = <String, dynamic>{
              'role': 'system',
              'content': sb.toString(),
            };
            if (ContextLogger.enabled) {
              if (beforeContent.isNotEmpty && afterContent.isNotEmpty) {
                ContextSegmentTags.write(created, [
                  ContextSegmentTags.item(
                    source: ContextSource.worldBook,
                    length: beforeContent.length + 1,
                    meta: {
                      'position': WorldBookInjectionPosition.beforeSystemPrompt
                          .toJson(),
                    },
                  ),
                  ContextSegmentTags.item(
                    source: ContextSource.worldBook,
                    length: afterContent.length,
                    meta: {
                      'position': WorldBookInjectionPosition.afterSystemPrompt
                          .toJson(),
                    },
                  ),
                ]);
              } else if (beforeContent.isNotEmpty) {
                ContextSegmentTags.replaceWithSingle(
                  created,
                  source: ContextSource.worldBook,
                  length: beforeContent.length,
                  meta: {
                    'position': WorldBookInjectionPosition.beforeSystemPrompt
                        .toJson(),
                  },
                );
              } else {
                ContextSegmentTags.replaceWithSingle(
                  created,
                  source: ContextSource.worldBook,
                  length: afterContent.length,
                  meta: {
                    'position': WorldBookInjectionPosition.afterSystemPrompt
                        .toJson(),
                  },
                );
              }
            }
            apiMessages.insert(0, created);
          }
        }
      }

      // TOP_OF_CHAT: insert before first user message.
      final topInjections = byPosition[WorldBookInjectionPosition.topOfChat];
      if (topInjections != null && topInjections.isNotEmpty) {
        var insertIndex = apiMessages.indexWhere(
          (m) => (m['role'] ?? '').toString() == 'user',
        );
        if (insertIndex < 0) insertIndex = apiMessages.length;
        insertIndex = findSafeInsertIndex(apiMessages, insertIndex);
        apiMessages.insertAll(
          insertIndex,
          createMergedInjectionMessages(
            topInjections,
            position: WorldBookInjectionPosition.topOfChat,
          ),
        );
      }

      // BOTTOM_OF_CHAT: insert before last message.
      final bottomInjections =
          byPosition[WorldBookInjectionPosition.bottomOfChat];
      if (bottomInjections != null && bottomInjections.isNotEmpty) {
        var insertIndex = apiMessages.isEmpty ? 0 : (apiMessages.length - 1);
        insertIndex = findSafeInsertIndex(apiMessages, insertIndex);
        apiMessages.insertAll(
          insertIndex,
          createMergedInjectionMessages(
            bottomInjections,
            position: WorldBookInjectionPosition.bottomOfChat,
          ),
        );
      }

      // AT_DEPTH: insert at depth from end (depth=1 means before last message).
      final atDepthInjections = byPosition[WorldBookInjectionPosition.atDepth];
      if (atDepthInjections != null && atDepthInjections.isNotEmpty) {
        final byDepth = <int, List<WorldBookEntry>>{};
        for (final e in atDepthInjections) {
          final depth = (e.injectDepth <= 0 ? 1 : e.injectDepth)
              .clamp(1, 200)
              .toInt();
          byDepth.putIfAbsent(depth, () => <WorldBookEntry>[]).add(e);
        }

        final depths = byDepth.keys.toList(growable: false)
          ..sort((a, b) => b.compareTo(a));

        for (final depth in depths) {
          final injections = byDepth[depth] ?? const <WorldBookEntry>[];
          var insertIndex = (apiMessages.length - depth).clamp(
            0,
            apiMessages.length,
          );
          insertIndex = findSafeInsertIndex(apiMessages, insertIndex);
          apiMessages.insertAll(
            insertIndex,
            createMergedInjectionMessages(
              injections,
              position: WorldBookInjectionPosition.atDepth,
            ),
          );
        }
      }
    } catch (_) {}
  }

  /// Helper to append content to the system message (or create one if missing).
  void _appendToSystemMessage(
    List<Map<String, dynamic>> apiMessages,
    String content, {
    ContextSource? source,
  }) {
    if (apiMessages.isNotEmpty && apiMessages.first['role'] == 'system') {
      apiMessages[0]['content'] =
          '${(apiMessages[0]['content'] ?? '') as String}\n\n$content';
      if (ContextLogger.enabled && source != null) {
        ContextSegmentTags.append(
          apiMessages[0],
          source: source,
          length: 2 + content.length,
        );
      }
    } else {
      final message = <String, dynamic>{'role': 'system', 'content': content};
      if (ContextLogger.enabled && source != null) {
        ContextSegmentTags.append(
          message,
          source: source,
          length: content.length,
        );
      }
      apiMessages.insert(0, message);
    }
  }

  /// Apply context message limit based on assistant settings.
  void applyContextLimit(
    List<Map<String, dynamic>> apiMessages,
    Assistant? assistant,
  ) {
    if ((assistant?.limitContextMessages ?? false) &&
        (assistant?.contextMessageSize ?? 0) > 0) {
      final int keep = (assistant!.contextMessageSize).clamp(
        Assistant.minContextMessageSize,
        Assistant.maxContextMessageSize,
      );
      int startIdx = 0;
      if (apiMessages.isNotEmpty && apiMessages.first['role'] == 'system') {
        startIdx = 1;
      }
      final tail = apiMessages.sublist(startIdx);
      if (tail.length > keep) {
        final trimmed = tail.sublist(tail.length - keep);
        apiMessages
          ..removeRange(startIdx, apiMessages.length)
          ..addAll(trimmed);
      }
      // Context trimming can cut in the middle of a tool-call triplet; avoid sending dangling tool messages.
      while (apiMessages.length > startIdx &&
          (apiMessages[startIdx]['role'] ?? '').toString() == 'tool') {
        apiMessages.removeAt(startIdx);
      }
    }
  }

  /// Convert local Markdown image links to inline base64 for model context.
  Future<void> inlineLocalImages(List<Map<String, dynamic>> apiMessages) async {
    for (int i = 0; i < apiMessages.length; i++) {
      final s = (apiMessages[i]['content'] ?? '').toString();
      if (s.isNotEmpty) {
        apiMessages[i]['content'] =
            await MarkdownMediaSanitizer.inlineLocalImagesToBase64(s);
      }
    }
  }

  /// Check if built-in search is enabled for the given provider/model.
  bool hasBuiltInSearch(
    SettingsProvider settings,
    String providerKey,
    String modelId,
  ) {
    try {
      final cfg = settings.getProviderConfig(providerKey);
      return BuiltInToolsHelper.isBuiltInSearchEnabled(
        cfg: cfg,
        modelId: modelId,
      );
    } catch (_) {
      return false;
    }
  }
}

class _DocTextCacheEntry {
  const _DocTextCacheEntry({
    required this.text,
    required this.modifiedMs,
    required this.size,
  });

  final String? text;
  final int modifiedMs;
  final int size;
}
