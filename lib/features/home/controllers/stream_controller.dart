import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/token_usage.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../chat/widgets/chat_message_widget.dart';
import '../../../utils/markdown_media_sanitizer.dart';
import 'streaming_content_notifier.dart';

export 'streaming_content_notifier.dart';

/// Controller for managing streaming message generation.
///
/// This controller handles:
/// - Stream chunk processing (content, reasoning, tool calls, tool results)
/// - Stream throttling to reduce UI rebuild frequency
/// - Reasoning state management (including segments)
/// - Tool UI state management
/// - Inline image sanitization during streaming
///
/// The controller is designed to work alongside ChatController and be used
/// by the home page to handle streaming generation without cluttering the UI code.
class StreamController {
  StreamController({
    required ChatService chatService,
    required this.onStateChanged,
    required this.getSettingsProvider,
    required this.getCurrentConversationId,
    this.onStreamTick,
  }) : _chatService = chatService;

  final ChatService _chatService;

  /// Callback when state changes (trigger setState in the widget).
  /// NOTE: This should only be used for non-streaming state changes.
  /// For streaming content updates, use streamingContentNotifier instead.
  final VoidCallback onStateChanged;

  /// Optional callback fired during streaming updates (e.g., auto-scroll).
  final VoidCallback? onStreamTick;

  /// Lightweight notifier for streaming content updates.
  /// This avoids triggering full page rebuilds during streaming.
  final StreamingContentNotifier streamingContentNotifier =
      StreamingContentNotifier();

  /// Set of message IDs currently being streamed.
  /// Used to suppress onStateChanged calls during streaming.
  final Set<String> _activeStreamingIds = <String>{};

  /// Check if any message is currently streaming.
  bool get isAnyMessageStreaming => _activeStreamingIds.isNotEmpty;

  /// Mark a message as actively streaming.
  /// Also creates the StreamingContentNotifier for this message so that
  /// MessageListView can detect it and use ValueListenableBuilder.
  void markStreamingStarted(String messageId) {
    _activeStreamingIds.add(messageId);
    // Pre-create notifier so MessageListView can detect streaming state
    streamingContentNotifier.getNotifier(messageId);
  }

  /// Mark a message as no longer streaming.
  void markStreamingEnded(String messageId) {
    _activeStreamingIds.remove(messageId);
  }

  /// Call onStateChanged only if no messages are actively streaming.
  /// During streaming, UI updates are handled by ValueListenableBuilder.
  void _safeNotifyStateChanged() {
    if (_activeStreamingIds.isEmpty) {
      onStateChanged();
    }
  }

  /// Get current settings provider (for auto-collapse setting, etc.).
  final SettingsProvider Function() getSettingsProvider;

  /// Get current conversation ID (for checking if we should update UI).
  final String? Function() getCurrentConversationId;

  // ============================================================================
  // State Maps
  // ============================================================================

  /// Reasoning data per assistant message.
  final Map<String, ReasoningData> _reasoning = <String, ReasoningData>{};
  Map<String, ReasoningData> get reasoning => _reasoning;

  /// Reasoning segments per assistant message (for interleaved tool/thinking).
  final Map<String, List<ReasoningSegmentData>> _reasoningSegments =
      <String, List<ReasoningSegmentData>>{};
  Map<String, List<ReasoningSegmentData>> get reasoningSegments =>
      _reasoningSegments;

  /// Tool UI parts per assistant message.
  final Map<String, List<ToolUIPart>> _toolParts = <String, List<ToolUIPart>>{};
  Map<String, List<ToolUIPart>> get toolParts => _toolParts;

  /// Gemini thought signatures per assistant message.
  final Map<String, String> _geminiThoughtSigs = <String, String>{};
  Map<String, String> get geminiThoughtSigs => _geminiThoughtSigs;

  // ============================================================================
  // Throttle State
  // ============================================================================

  /// Throttle interval for streaming UI updates.
  static const Duration _streamThrottleInterval = Duration(milliseconds: 60);

  /// Throttle timers per message ID.
  final Map<String, Timer?> _streamThrottleTimers = <String, Timer?>{};

  /// Pending content to be applied on next throttle tick.
  final Map<String, String> _pendingStreamContent = <String, String>{};

  /// Delay before sanitizing inline base64 images.
  static const Duration _inlineImageSanitizeDelay = Duration(milliseconds: 120);

  /// Timers for inline image sanitization per message.
  final Map<String, Timer?> _inlineImageSanitizeTimers = <String, Timer?>{};

  /// Set of message IDs currently being sanitized.
  final Set<String> _inlineImageSanitizing = <String>{};

  /// Regex to capture Gemini thought signature comments.
  static final RegExp _geminiThoughtSigRe = RegExp(
    r'<!--\s*gemini_thought_signatures:.*?-->',
    dotAll: true,
  );

  // ============================================================================
  // Public Methods - State Access
  // ============================================================================

  /// Get reasoning data for a message.
  ReasoningData? getReasoningData(String messageId) => _reasoning[messageId];

  /// Set reasoning data for a message.
  void setReasoningData(String messageId, ReasoningData data) {
    _reasoning[messageId] = data;
  }

  /// Remove reasoning data for a message.
  void removeReasoningData(String messageId) {
    _reasoning.remove(messageId);
  }

  /// Get reasoning segments for a message.
  List<ReasoningSegmentData>? getReasoningSegments(String messageId) =>
      _reasoningSegments[messageId];

  /// Set reasoning segments for a message.
  void setReasoningSegments(
    String messageId,
    List<ReasoningSegmentData> segments,
  ) {
    _reasoningSegments[messageId] = segments;
  }

  /// Remove reasoning segments for a message.
  void removeReasoningSegments(String messageId) {
    _reasoningSegments.remove(messageId);
  }

  /// Get tool parts for a message.
  List<ToolUIPart>? getToolParts(String messageId) => _toolParts[messageId];

  /// Set tool parts for a message.
  void setToolParts(String messageId, List<ToolUIPart> parts) {
    _toolParts[messageId] = parts;
  }

  /// Remove tool parts for a message.
  void removeToolParts(String messageId) {
    _toolParts.remove(messageId);
  }

  /// Clear all state for a message (reasoning, segments, tools).
  void clearMessageState(String messageId) {
    _reasoning.remove(messageId);
    _reasoningSegments.remove(messageId);
    _toolParts.remove(messageId);
    _geminiThoughtSigs.remove(messageId);
    _cleanupStreamTimers(messageId);
  }

  /// Clear all state maps (for new conversation).
  void clearAllState() {
    _reasoning.clear();
    _reasoningSegments.clear();
    _toolParts.clear();
    _geminiThoughtSigs.clear();
    _cancelAllTimers();
    streamingContentNotifier.clear();
  }

  // ============================================================================
  // Gemini Thought Signature Handling
  // ============================================================================

  /// Capture and strip Gemini thought signature from content.
  String captureGeminiThoughtSignature(String content, String messageId) {
    if (content.isEmpty) return content;
    final m = _geminiThoughtSigRe.firstMatch(content);
    if (m != null) {
      final sig = m.group(0) ?? '';
      if (sig.isNotEmpty) {
        if (_geminiThoughtSigs[messageId] != sig) {
          _geminiThoughtSigs[messageId] = sig;
          unawaited(_chatService.setGeminiThoughtSignature(messageId, sig));
        }
      }
      content = content.replaceAll(_geminiThoughtSigRe, '').trimRight();
    }
    return content;
  }

  /// Append Gemini thought signature for API calls (when sending history).
  String appendGeminiThoughtSignatureForApi(
    ChatMessage message,
    String content,
  ) {
    String? sig = _geminiThoughtSigs[message.id];
    sig ??= _chatService.getGeminiThoughtSignature(message.id);
    if (sig != null &&
        sig.isNotEmpty &&
        !content.contains('gemini_thought_signatures:')) {
      if (content.isEmpty) return sig;
      return '$content\n$sig';
    }
    return content;
  }

  /// Clear Gemini thought signatures map.
  void clearGeminiThoughtSigs() {
    _geminiThoughtSigs.clear();
  }

  // ============================================================================
  // Reasoning Serialization
  // ============================================================================

  /// Serialize reasoning segments to JSON string.
  String serializeReasoningSegments(List<ReasoningSegmentData> segments) {
    final list = segments
        .map(
          (s) => {
            'text': s.text,
            'startAt': s.startAt?.toIso8601String(),
            'finishedAt': s.finishedAt?.toIso8601String(),
            'expanded': s.expanded,
            'toolStartIndex': s.toolStartIndex,
          },
        )
        .toList();
    return _encodeJson(list);
  }

  /// Deserialize reasoning segments from JSON string.
  List<ReasoningSegmentData> deserializeReasoningSegments(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final list = _decodeJson(json) as List;
      return list.map((item) {
        final s = ReasoningSegmentData();
        s.text = item['text'] ?? '';
        s.startAt = item['startAt'] != null
            ? DateTime.parse(item['startAt'])
            : null;
        s.finishedAt = item['finishedAt'] != null
            ? DateTime.parse(item['finishedAt'])
            : null;
        s.expanded = item['expanded'] ?? false;
        s.toolStartIndex = (item['toolStartIndex'] as int?) ?? 0;
        return s;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // Simple JSON encode/decode to avoid importing dart:convert in this file
  String _encodeJson(dynamic obj) {
    return _jsonEncode(obj);
  }

  dynamic _decodeJson(String json) {
    return _jsonDecode(json);
  }

  // ============================================================================
  // Tool Parts Deduplication
  // ============================================================================

  /// Deduplicate tool UI parts by id or by name+args when id is empty.
  List<ToolUIPart> dedupeToolPartsList(List<ToolUIPart> parts) {
    final seen = <String>{};
    final out = <ToolUIPart>[];
    for (final p in parts) {
      final id = (p.id).trim();
      final key = id.isNotEmpty
          ? 'id:$id'
          : 'name:${p.toolName}|args:${_encodeJson(p.arguments)}';
      if (seen.add(key)) out.add(p);
    }
    return out;
  }

  /// Deduplicate raw persisted tool events.
  List<Map<String, dynamic>> dedupeToolEvents(
    List<Map<String, dynamic>> events,
  ) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final e in events) {
      final id = (e['id']?.toString() ?? '').trim();
      final name = (e['name']?.toString() ?? '');
      final args =
          ((e['arguments'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{});
      final key = id.isNotEmpty
          ? 'id:$id'
          : 'name:$name|args:${_encodeJson(args)}';
      if (seen.add(key)) out.add(e.map((k, v) => MapEntry(k.toString(), v)));
    }
    return out;
  }

  // ============================================================================
  // Stream Throttling
  // ============================================================================

  /// Schedule a throttled UI update for streaming content.
  ///
  /// This method uses StreamingContentNotifier to update only the streaming
  /// message widget, avoiding full page rebuilds that cause lag.
  void scheduleThrottledUpdate(
    String messageId,
    String conversationId,
    String content, {
    required void Function(String messageId, String content, int totalTokens)
    updateMessageInList,
    required int totalTokens,
  }) {
    _pendingStreamContent[messageId] = content;

    // Ensure notifier exists for this message
    streamingContentNotifier.getNotifier(messageId);

    _streamThrottleTimers[messageId] ??= Timer.periodic(
      _streamThrottleInterval,
      (_) {
        final pending = _pendingStreamContent[messageId];
        if (pending != null && getCurrentConversationId() == conversationId) {
          // Use lightweight notifier instead of full page rebuild
          streamingContentNotifier.updateContent(
            messageId,
            pending,
            totalTokens,
          );
          // Also update the message list data (without triggering rebuild)
          updateMessageInList(messageId, pending, totalTokens);
          onStreamTick?.call();
        }
      },
    );
  }

  /// Get pending stream content for a message.
  String? getPendingStreamContent(String messageId) =>
      _pendingStreamContent[messageId];

  /// Set pending stream content (used by inline image sanitizer).
  void setPendingStreamContent(String messageId, String content) {
    _pendingStreamContent[messageId] = content;
  }

  /// Clean up stream throttle timers for a message.
  void _cleanupStreamTimers(String messageId) {
    _streamThrottleTimers[messageId]?.cancel();
    _streamThrottleTimers.remove(messageId);
    _pendingStreamContent.remove(messageId);
    _inlineImageSanitizeTimers[messageId]?.cancel();
    _inlineImageSanitizeTimers.remove(messageId);
    _inlineImageSanitizing.remove(messageId);
  }

  /// Clean up timers for a message (public API).
  void cleanupTimers(String messageId) {
    _cleanupStreamTimers(messageId);
  }

  /// Remove the streaming content notifier for a message.
  ///
  /// This must be called AFTER onMessagesChanged to avoid a race where
  /// the UI rebuilds without the notifier and falls back to stale
  /// message.content (which may still be empty).
  /// Idempotent: safe to call multiple times.
  void removeStreamingNotifier(String messageId) {
    streamingContentNotifier.removeNotifier(messageId);
  }

  /// Cancel all throttle timers.
  void _cancelAllTimers() {
    for (final timer in _streamThrottleTimers.values) {
      timer?.cancel();
    }
    _streamThrottleTimers.clear();
    _pendingStreamContent.clear();
    for (final timer in _inlineImageSanitizeTimers.values) {
      timer?.cancel();
    }
    _inlineImageSanitizeTimers.clear();
    _inlineImageSanitizing.clear();
  }

  // ============================================================================
  // Inline Image Sanitization
  // ============================================================================

  /// Schedule inline base64 image sanitization.
  void scheduleInlineImageSanitize(
    String messageId, {
    String? latestContent,
    bool immediate = false,
    required Future<void> Function(String messageId, String sanitizedContent)
    onSanitized,
  }) {
    // Quick pre-check to avoid needless timers
    final snapshot = latestContent ?? '';
    if (snapshot.isEmpty ||
        !snapshot.contains('data:image') ||
        !snapshot.contains('base64,')) {
      return;
    }

    // Debounce per message
    _inlineImageSanitizeTimers[messageId]?.cancel();
    _inlineImageSanitizeTimers[messageId] = Timer(
      immediate ? Duration.zero : _inlineImageSanitizeDelay,
      () async {
        if (_inlineImageSanitizing.contains(messageId)) return;
        _inlineImageSanitizing.add(messageId);
        try {
          String current = latestContent ?? '';
          if (current.isEmpty ||
              !current.contains('data:image') ||
              !current.contains('base64,')) {
            return;
          }

          final sanitized =
              await MarkdownMediaSanitizer.replaceInlineBase64Images(current);
          if (sanitized == current) return;

          // Keep throttled UI updates in sync
          _pendingStreamContent[messageId] = sanitized;
          await onSanitized(messageId, sanitized);
        } catch (_) {
          // Swallow errors to avoid crashing streaming UI
        } finally {
          _inlineImageSanitizing.remove(messageId);
          _inlineImageSanitizeTimers.remove(messageId);
        }
      },
    );
  }

  // ============================================================================
  // Stream Chunk Processing
  // ============================================================================

  /// Process a reasoning chunk from stream.
  Future<void> handleReasoningChunk(
    ChatStreamChunk chunk,
    StreamingState state, {
    required Future<void> Function(
      String messageId, {
      String? reasoningText,
      DateTime? reasoningStartAt,
      String? reasoningSegmentsJson,
    })
    updateReasoningInDb,
  }) async {
    if ((chunk.reasoning ?? '').isEmpty || !state.ctx.supportsReasoning) return;

    final messageId = state.messageId;
    final conversationId = state.conversationId;

    if (state.ctx.streamOutput) {
      final r = _reasoning[messageId] ?? ReasoningData();
      r.text += chunk.reasoning!;
      r.startAt ??= DateTime.now();
      // NOTE: Do not reset r.expanded here - preserve user's toggle state during streaming
      _reasoning[messageId] = r;

      // Add to reasoning segments for mixed display
      final segments =
          _reasoningSegments[messageId] ?? <ReasoningSegmentData>[];
      if (segments.isEmpty) {
        final newSegment = ReasoningSegmentData();
        newSegment.text = chunk.reasoning!;
        newSegment.startAt = DateTime.now();
        newSegment.expanded = false;
        newSegment.toolStartIndex = (_toolParts[messageId]?.length ?? 0);
        segments.add(newSegment);
      } else {
        final hasToolsAfterLastSegment =
            (_toolParts[messageId]?.isNotEmpty ?? false);
        final lastSegment = segments.last;
        if (hasToolsAfterLastSegment && lastSegment.finishedAt != null) {
          final newSegment = ReasoningSegmentData();
          newSegment.text = chunk.reasoning!;
          newSegment.startAt = DateTime.now();
          newSegment.expanded = false;
          newSegment.toolStartIndex = (_toolParts[messageId]?.length ?? 0);
          segments.add(newSegment);
        } else {
          lastSegment.text += chunk.reasoning!;
          lastSegment.startAt ??= DateTime.now();
        }
      }
      _reasoningSegments[messageId] = segments;

      await updateReasoningInDb(
        messageId,
        reasoningSegmentsJson: serializeReasoningSegments(segments),
      );

      // Update reasoning via StreamingContentNotifier for real-time UI updates
      // without triggering full page rebuild (only when viewing this conversation)
      if (getCurrentConversationId() == conversationId) {
        streamingContentNotifier.updateReasoning(
          messageId,
          reasoningText: r.text,
          reasoningStartAt: r.startAt,
        );
        onStreamTick?.call();
      }

      await updateReasoningInDb(
        messageId,
        reasoningText: r.text,
        reasoningStartAt: r.startAt,
      );
    } else {
      state.reasoningStartAt ??= DateTime.now();
      state.bufferedReasoning += chunk.reasoning!;
      await updateReasoningInDb(
        messageId,
        reasoningText: state.bufferedReasoning,
        reasoningStartAt: state.reasoningStartAt,
      );
    }
  }

  /// Process tool calls chunk from stream.
  Future<void> handleToolCallsChunk(
    ChatStreamChunk chunk,
    StreamingState state, {
    required Future<void> Function(String messageId, String json)
    updateReasoningSegmentsInDb,
    required Future<void> Function(
      String messageId,
      List<Map<String, dynamic>> events,
    )
    setToolEventsInDb,
    required List<Map<String, dynamic>> Function(String messageId)
    getToolEventsFromDb,
  }) async {
    if ((chunk.toolCalls ?? const []).isEmpty) return;

    final messageId = state.messageId;
    final conversationId = state.conversationId;

    // Finish any unfinished reasoning segment when tools start
    final segments = _reasoningSegments[messageId] ?? <ReasoningSegmentData>[];
    if (segments.isNotEmpty && segments.last.finishedAt == null) {
      segments.last.finishedAt = DateTime.now();
      final autoCollapse = getSettingsProvider().autoCollapseThinking;
      if (autoCollapse) {
        segments.last.expanded = false;
        final rd = _reasoning[messageId];
        if (rd != null) rd.expanded = false;
      }
      _reasoningSegments[messageId] = segments;
      await updateReasoningSegmentsInDb(
        messageId,
        serializeReasoningSegments(segments),
      );
    }

    // Add tool call placeholders
    final existing = List<ToolUIPart>.of(_toolParts[messageId] ?? const []);
    for (final c in chunk.toolCalls!) {
      existing.add(
        ToolUIPart(
          id: c.id,
          toolName: c.name,
          arguments: c.arguments,
          loading: true,
        ),
      );
    }
    if (getCurrentConversationId() == conversationId) {
      _toolParts[messageId] = dedupeToolPartsList(existing);
      // Notify via StreamingContentNotifier for real-time UI updates
      streamingContentNotifier.notifyToolPartsUpdated(messageId);
    }

    // Persist tool events
    try {
      final prev = getToolEventsFromDb(messageId);
      final newEvents = <Map<String, dynamic>>[
        ...prev,
        for (final c in chunk.toolCalls!)
          {
            'id': c.id,
            'name': c.name,
            'arguments': c.arguments,
            'content': null,
          },
      ];
      await setToolEventsInDb(messageId, dedupeToolEvents(newEvents));
    } catch (_) {}
  }

  /// Process tool results chunk from stream.
  Future<void> handleToolResultsChunk(
    ChatStreamChunk chunk,
    StreamingState state, {
    required Future<void> Function(
      String messageId, {
      required String id,
      required String name,
      required Map<String, dynamic> arguments,
      String? content,
    })
    upsertToolEventInDb,
  }) async {
    if ((chunk.toolResults ?? const []).isEmpty) return;

    final messageId = state.messageId;
    final conversationId = state.conversationId;

    final parts = List<ToolUIPart>.of(_toolParts[messageId] ?? const []);
    for (final r in chunk.toolResults!) {
      int idx = -1;
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].loading &&
            (parts[i].id == r.id ||
                (parts[i].id.isEmpty && parts[i].toolName == r.name))) {
          idx = i;
          break;
        }
      }
      if (idx >= 0) {
        parts[idx] = ToolUIPart(
          id: parts[idx].id,
          toolName: parts[idx].toolName,
          arguments: (r.arguments is Map && (r.arguments as Map).isNotEmpty)
              ? Map<String, dynamic>.from(r.arguments)
              : parts[idx].arguments,
          content: r.content,
          loading: false,
        );
      } else {
        parts.add(
          ToolUIPart(
            id: r.id,
            toolName: r.name,
            arguments: r.arguments,
            content: r.content,
            loading: false,
          ),
        );
      }
      try {
        final args = (r.arguments is Map)
            ? Map<String, dynamic>.from(r.arguments as Map)
            : <String, dynamic>{};
        await upsertToolEventInDb(
          messageId,
          id: r.id,
          name: r.name,
          arguments: args,
          content: r.content,
        );
      } catch (_) {}
    }
    if (getCurrentConversationId() == conversationId) {
      _toolParts[messageId] = dedupeToolPartsList(parts);
      // Notify via StreamingContentNotifier for real-time UI updates
      streamingContentNotifier.notifyToolPartsUpdated(messageId);
    }
  }

  /// Finish reasoning segment when content starts arriving.
  Future<void> finishReasoningOnContent(
    StreamingState state, {
    required Future<void> Function(
      String messageId, {
      String? reasoningText,
      DateTime? reasoningFinishedAt,
      String? reasoningSegmentsJson,
    })
    updateReasoningInDb,
  }) async {
    final messageId = state.messageId;

    final r = _reasoning[messageId];
    if (r != null && r.startAt != null && r.finishedAt == null) {
      r.finishedAt = DateTime.now();
      final autoCollapse = getSettingsProvider().autoCollapseThinking;
      if (autoCollapse) {
        r.expanded = false;
      }
      _reasoning[messageId] = r;
      await updateReasoningInDb(
        messageId,
        reasoningText: r.text,
        reasoningFinishedAt: r.finishedAt,
      );
      _safeNotifyStateChanged();
    }

    final segments = _reasoningSegments[messageId];
    if (segments != null &&
        segments.isNotEmpty &&
        segments.last.finishedAt == null) {
      segments.last.finishedAt = DateTime.now();
      final autoCollapse = getSettingsProvider().autoCollapseThinking;
      if (autoCollapse) {
        segments.last.expanded = false;
      }
      _reasoningSegments[messageId] = segments;
      _safeNotifyStateChanged();
      await updateReasoningInDb(
        messageId,
        reasoningSegmentsJson: serializeReasoningSegments(segments),
      );
    }
  }

  // NOTE: transformAssistantContent is kept in home_page.dart because it uses AssistantRegexScope

  /// Finalize streaming and finish reasoning state.
  Future<void> finalizeReasoningState(
    String messageId, {
    required Future<void> Function(
      String messageId, {
      String? reasoningText,
      DateTime? reasoningFinishedAt,
      String? reasoningSegmentsJson,
    })
    updateReasoningInDb,
  }) async {
    // Finish reasoning data
    final r = _reasoning[messageId];
    if (r != null) {
      if (r.finishedAt == null) {
        r.finishedAt = DateTime.now();
      }
      final autoCollapse = getSettingsProvider().autoCollapseThinking;
      if (autoCollapse) {
        r.expanded = false;
      }
      _reasoning[messageId] = r;
      _safeNotifyStateChanged();
    }

    // Also finish any unfinished reasoning segments
    final segments = _reasoningSegments[messageId];
    if (segments != null &&
        segments.isNotEmpty &&
        segments.last.finishedAt == null) {
      segments.last.finishedAt = DateTime.now();
      final autoCollapse = getSettingsProvider().autoCollapseThinking;
      if (autoCollapse) {
        segments.last.expanded = false;
      }
      _reasoningSegments[messageId] = segments;
      _safeNotifyStateChanged();
    }

    // Save reasoning segments to database
    if (segments != null && segments.isNotEmpty) {
      await updateReasoningInDb(
        messageId,
        reasoningSegmentsJson: serializeReasoningSegments(segments),
      );
    }
  }

  /// Check if there are any loading tool parts for a message.
  bool hasLoadingTools(String messageId) {
    return _toolParts[messageId]?.any((p) => p.loading) ?? false;
  }

  // ============================================================================
  // Unified Reasoning Completion
  // ============================================================================

  /// Finishes reasoning for a message if not already finished.
  ///
  /// This is the unified method to handle reasoning completion logic that was
  /// previously duplicated across multiple places in home_page.dart:
  /// - _cancelStreaming (line 597-617)
  /// - _finishReasoningOnContent (line 3738-3770)
  /// - _finishStreaming (line 3886-3917)
  /// - _handleStreamError (line 3954-3970)
  ///
  /// Returns true if any state was actually changed.
  bool finishReasoningIfNeeded(String messageId, {bool forceCollapse = false}) {
    bool changed = false;
    final autoCollapse =
        forceCollapse || getSettingsProvider().autoCollapseThinking;

    // Finish main reasoning data (only when it first finishes, not on subsequent calls)
    final r = _reasoning[messageId];
    if (r != null && r.finishedAt == null) {
      r.finishedAt = DateTime.now();
      if (autoCollapse) {
        r.expanded = false;
      }
      _reasoning[messageId] = r;
      changed = true;
    }
    // NOTE: Removed the "else if" branch that would force collapse on every call.
    // This allows users to expand reasoning during content streaming without it
    // being immediately collapsed again.

    // Finish last reasoning segment (only when it first finishes)
    final segments = _reasoningSegments[messageId];
    if (segments != null && segments.isNotEmpty) {
      final lastSegment = segments.last;
      if (lastSegment.finishedAt == null) {
        lastSegment.finishedAt = DateTime.now();
        if (autoCollapse) {
          lastSegment.expanded = false;
        }
        _reasoningSegments[messageId] = segments;
        changed = true;
      }
      // NOTE: Removed the "else if" branch that would force collapse on every call.
    }

    if (changed) {
      _safeNotifyStateChanged();
    }
    return changed;
  }

  /// Finishes reasoning and persists to database.
  ///
  /// This is a convenience method that combines finishing reasoning state
  /// and persisting it to the database in one call.
  Future<void> finishReasoningAndPersist(
    String messageId, {
    bool forceCollapse = false,
    required Future<void> Function(
      String messageId, {
      String? reasoningText,
      DateTime? reasoningFinishedAt,
      String? reasoningSegmentsJson,
    })
    updateReasoningInDb,
  }) async {
    final changed = finishReasoningIfNeeded(
      messageId,
      forceCollapse: forceCollapse,
    );
    if (!changed) return;

    // Persist reasoning data
    final r = _reasoning[messageId];
    if (r != null) {
      await updateReasoningInDb(
        messageId,
        reasoningText: r.text,
        reasoningFinishedAt: r.finishedAt,
      );
    }

    // Persist reasoning segments
    final segments = _reasoningSegments[messageId];
    if (segments != null && segments.isNotEmpty) {
      await updateReasoningInDb(
        messageId,
        reasoningSegmentsJson: serializeReasoningSegments(segments),
      );
    }
  }

  // ============================================================================
  // Restoration from Database
  // ============================================================================

  /// Restore UI state for a message from its persisted data.
  void restoreMessageUiState(
    ChatMessage message, {
    required List<Map<String, dynamic>> Function(String messageId)
    getToolEventsFromDb,
    required String? Function(String messageId) getGeminiThoughtSigFromDb,
  }) {
    if (message.role != 'assistant') return;

    final messageId = message.id;

    // Restore Gemini thought signature
    final storedSig = getGeminiThoughtSigFromDb(messageId);
    if (storedSig != null && storedSig.isNotEmpty) {
      _geminiThoughtSigs[messageId] = storedSig;
    }

    // Restore reasoning state
    final txt = message.reasoningText ?? '';
    if (txt.isNotEmpty ||
        message.reasoningStartAt != null ||
        message.reasoningFinishedAt != null) {
      final rd = ReasoningData();
      rd.text = txt;
      rd.startAt = message.reasoningStartAt;
      rd.finishedAt = message.reasoningFinishedAt;
      rd.expanded = false;
      _reasoning[messageId] = rd;
    }

    // Restore tool events
    try {
      final events = dedupeToolEvents(getToolEventsFromDb(messageId));
      if (events.isNotEmpty) {
        _toolParts[messageId] = events
            .map(
              (e) => ToolUIPart(
                id: (e['id'] ?? '').toString(),
                toolName: (e['name'] ?? '').toString(),
                arguments:
                    (e['arguments'] as Map?)?.cast<String, dynamic>() ??
                    const <String, dynamic>{},
                content: (e['content']?.toString().isNotEmpty == true)
                    ? e['content'].toString()
                    : null,
                loading: !(e['content']?.toString().isNotEmpty == true),
              ),
            )
            .toList();
      }
    } catch (_) {}

    // Restore reasoning segments
    final segments = deserializeReasoningSegments(
      message.reasoningSegmentsJson,
    );
    if (segments.isNotEmpty) {
      _reasoningSegments[messageId] = segments;
    }
  }

  // ============================================================================
  // Disposal
  // ============================================================================

  /// Dispose of all resources.
  void dispose() {
    _cancelAllTimers();
    streamingContentNotifier.dispose();
  }
}

// ============================================================================
// Data Classes
// ============================================================================

/// Context object for message generation.
class GenerationContext {
  GenerationContext({
    required this.assistantMessage,
    required this.apiMessages,
    required this.userImagePaths,
    required this.providerKey,
    required this.modelId,
    required this.assistant,
    required this.settings,
    required this.config,
    required this.toolDefs,
    this.onToolCall,
    this.extraHeaders,
    this.extraBody,
    required this.supportsReasoning,
    required this.enableReasoning,
    required this.streamOutput,
    this.generateTitleOnFinish = true,
  });

  final ChatMessage assistantMessage;
  final List<Map<String, dynamic>> apiMessages;
  final List<String> userImagePaths;
  final String providerKey;
  final String modelId;
  final dynamic assistant;
  final SettingsProvider settings;
  final ProviderConfig config;
  final List<Map<String, dynamic>> toolDefs;
  final Future<String> Function(String, Map<String, dynamic>)? onToolCall;
  final Map<String, String>? extraHeaders;
  final Map<String, dynamic>? extraBody;
  final bool supportsReasoning;
  final bool enableReasoning;
  final bool streamOutput;
  final bool generateTitleOnFinish;
}

/// State object for streaming message generation.
class StreamingState {
  StreamingState(this.ctx);

  final GenerationContext ctx;
  String fullContentRaw = '';
  int totalTokens = 0;
  TokenUsage? usage;
  String bufferedReasoning = '';
  DateTime? reasoningStartAt;
  bool finishHandled = false;
  bool titleQueued = false;

  String get messageId => ctx.assistantMessage.id;
  String get conversationId => ctx.assistantMessage.conversationId;
}

/// Reasoning data for an assistant message.
class ReasoningData {
  String text = '';
  DateTime? startAt;
  DateTime? finishedAt;
  bool expanded = false;
}

/// Reasoning segment data (for interleaved thinking/tool display).
class ReasoningSegmentData {
  String text = '';
  DateTime? startAt;
  DateTime? finishedAt;
  bool expanded = true;
  int toolStartIndex = 0;
}

// ============================================================================
// JSON Helpers (to avoid circular imports)
// ============================================================================

String _jsonEncode(dynamic obj) {
  // Simple implementation without importing dart:convert here
  // The actual import is at the top level
  return _JsonEncoder.encode(obj);
}

dynamic _jsonDecode(String json) {
  return _JsonDecoder.decode(json);
}

class _JsonEncoder {
  static String encode(dynamic obj) {
    if (obj == null) return 'null';
    if (obj is bool) return obj.toString();
    if (obj is num) return obj.toString();
    if (obj is String) return '"${_escapeString(obj)}"';
    if (obj is List) {
      final items = obj.map((e) => encode(e)).join(',');
      return '[$items]';
    }
    if (obj is Map) {
      final entries = obj.entries
          .map((e) => '"${_escapeString(e.key.toString())}":${encode(e.value)}')
          .join(',');
      return '{$entries}';
    }
    return '"${_escapeString(obj.toString())}"';
  }

  static String _escapeString(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }
}

class _JsonDecoder {
  static dynamic decode(String json) {
    final trimmed = json.trim();
    if (trimmed.isEmpty) return null;
    return _parseValue(trimmed, _Position(0)).value;
  }

  static _ParseResult _parseValue(String json, _Position pos) {
    _skipWhitespace(json, pos);
    if (pos.index >= json.length) return _ParseResult(null, pos.index);

    final c = json[pos.index];
    if (c == '{') return _parseObject(json, pos);
    if (c == '[') return _parseArray(json, pos);
    if (c == '"') return _parseString(json, pos);
    if (c == 't' || c == 'f') return _parseBool(json, pos);
    if (c == 'n') return _parseNull(json, pos);
    return _parseNumber(json, pos);
  }

  static _ParseResult _parseObject(String json, _Position pos) {
    pos.index++; // skip {
    final map = <String, dynamic>{};
    _skipWhitespace(json, pos);
    while (pos.index < json.length && json[pos.index] != '}') {
      _skipWhitespace(json, pos);
      final keyResult = _parseString(json, pos);
      final key = keyResult.value as String;
      _skipWhitespace(json, pos);
      if (json[pos.index] == ':') pos.index++;
      _skipWhitespace(json, pos);
      final valueResult = _parseValue(json, pos);
      map[key] = valueResult.value;
      _skipWhitespace(json, pos);
      if (json[pos.index] == ',') pos.index++;
    }
    if (pos.index < json.length) pos.index++; // skip }
    return _ParseResult(map, pos.index);
  }

  static _ParseResult _parseArray(String json, _Position pos) {
    pos.index++; // skip [
    final list = <dynamic>[];
    _skipWhitespace(json, pos);
    while (pos.index < json.length && json[pos.index] != ']') {
      final result = _parseValue(json, pos);
      list.add(result.value);
      _skipWhitespace(json, pos);
      if (json[pos.index] == ',') pos.index++;
    }
    if (pos.index < json.length) pos.index++; // skip ]
    return _ParseResult(list, pos.index);
  }

  static _ParseResult _parseString(String json, _Position pos) {
    pos.index++; // skip opening "
    final buffer = StringBuffer();
    while (pos.index < json.length) {
      final c = json[pos.index];
      if (c == '"') {
        pos.index++;
        break;
      }
      if (c == '\\' && pos.index + 1 < json.length) {
        pos.index++;
        final escaped = json[pos.index];
        switch (escaped) {
          case 'n':
            buffer.write('\n');
            break;
          case 'r':
            buffer.write('\r');
            break;
          case 't':
            buffer.write('\t');
            break;
          case '\\':
            buffer.write('\\');
            break;
          case '"':
            buffer.write('"');
            break;
          default:
            buffer.write(escaped);
        }
      } else {
        buffer.write(c);
      }
      pos.index++;
    }
    return _ParseResult(buffer.toString(), pos.index);
  }

  static _ParseResult _parseNumber(String json, _Position pos) {
    final start = pos.index;
    while (pos.index < json.length &&
        (json[pos.index].contains(RegExp(r'[\d.eE+-]')))) {
      pos.index++;
    }
    final numStr = json.substring(start, pos.index);
    if (numStr.contains('.') || numStr.contains('e') || numStr.contains('E')) {
      return _ParseResult(double.parse(numStr), pos.index);
    }
    return _ParseResult(int.parse(numStr), pos.index);
  }

  static _ParseResult _parseBool(String json, _Position pos) {
    if (json.substring(pos.index).startsWith('true')) {
      pos.index += 4;
      return _ParseResult(true, pos.index);
    }
    pos.index += 5;
    return _ParseResult(false, pos.index);
  }

  static _ParseResult _parseNull(String json, _Position pos) {
    pos.index += 4;
    return _ParseResult(null, pos.index);
  }

  static void _skipWhitespace(String json, _Position pos) {
    while (pos.index < json.length &&
        (json[pos.index] == ' ' ||
            json[pos.index] == '\n' ||
            json[pos.index] == '\r' ||
            json[pos.index] == '\t')) {
      pos.index++;
    }
  }
}

class _Position {
  _Position(this.index);
  int index;
}

class _ParseResult {
  _ParseResult(this.value, this.endIndex);
  final dynamic value;
  final int endIndex;
}
