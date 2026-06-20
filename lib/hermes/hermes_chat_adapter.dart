import 'dart:async';
import '../core/models/token_usage.dart';
import '../core/services/api/chat_api_service.dart';
import 'hermes_event_bus.dart';
import 'hermes_models.dart';

/// Adapts [HermesEventBus] stream events into [Stream<ChatStreamChunk>]
/// so that downstream code (StreamController, ChatActions) can consume
/// Hermes events identically to ChatApiService streaming chunks.
///
/// Usage:
/// ```dart
/// final adapter = HermesChatAdapter(
///   eventBus: gatewayProvider.eventBus,
///   sessionId: sessionId,
/// );
/// final stream = adapter.chunkStream; // Stream<ChatStreamChunk>
/// // pipe to StreamController._handleStreamChunk(...)
/// ```
class HermesChatAdapter {
  HermesChatAdapter({
    required HermesEventBus eventBus,
    required String sessionId,
  }) : _eventBus = eventBus,
       _sessionId = sessionId {
    _subscription = _eventBus.allEvents.listen(_onEvent);
  }

  final HermesEventBus _eventBus;
  final String _sessionId;
  StreamSubscription<HermesStreamEvent>? _subscription;

  final _chunkController = StreamController<ChatStreamChunk>.broadcast();

  /// Stream of [ChatStreamChunk] equivalents parsed from Hermes events.
  Stream<ChatStreamChunk> get chunkStream => _chunkController.stream;

  /// Completes when the message generation is done (MessageComplete).
  Future<void> get completionFuture => _completionCompleter.future;
  final _completionCompleter = Completer<void>();

  /// Token usage from the final MessageComplete event.
  TokenUsage? get finalUsage => _finalUsage;
  TokenUsage? _finalUsage;

  /// Accumulated text content.
  final StringBuffer _textBuffer = StringBuffer();

  /// Accumulated reasoning text.
  final StringBuffer _reasoningBuffer = StringBuffer();

  /// Tool calls encountered.
  final List<ToolCallInfo> _toolCalls = [];

  /// Tool results encountered.
  final List<ToolResultInfo> _toolResults = [];

  /// Tool generating state: name → partial content buffer.
  final Map<String, StringBuffer> _toolProgressBuffers = {};

  /// Whether we've seen a done / complete event.
  bool _isDone = false;

  void _onEvent(HermesStreamEvent event) {
    if (_isDone) return;

    // Only process events for our session
    if (!_matchesSession(event)) return;

    if (event is MessageDelta) {
      _textBuffer.write(event.text);
      _emitContent(isDone: false);
    } else if (event is MessageComplete) {
      _isDone = true;
      _finalUsage = _parseUsage(event);
      _emitContent(isDone: true);
      _completionCompleter.complete();
    } else if (event is ReasoningDelta) {
      _reasoningBuffer.write(event.text);
      _emitReasoning();
    } else if (event is ThinkingDelta) {
      // Hermes thinking is treated as reasoning delta
      _reasoningBuffer.write(event.text);
      _emitReasoning();
    } else if (event is ToolStart) {
      _toolCalls.add(
        ToolCallInfo(
          id: event.index.toString(),
          name: event.name,
          arguments: event.args ?? const {},
          metadata: event.preview != null ? {'preview': event.preview} : null,
        ),
      );
      _emitToolCalls();
    } else if (event is ToolProgress) {
      // Accumulate incremental output for this tool
      final buf = _toolProgressBuffers.putIfAbsent(
        event.name,
        StringBuffer.new,
      );
      if (event.content != null) buf.write(event.content);
    } else if (event is ToolGenerating) {
      // Tool is generating / in progress — emit partial content
      final buf = _toolProgressBuffers.putIfAbsent(
        event.name,
        StringBuffer.new,
      );
      _emitToolGenerating(event.name, buf.toString());
    } else if (event is ToolComplete) {
      // Flush any remaining progress buffer into a tool result
      final buf = _toolProgressBuffers.remove(event.name);
      final content = buf?.toString() ?? '';
      _toolResults.add(
        ToolResultInfo(
          id: event.index.toString(),
          name: event.name,
          arguments: const {},
          content: content,
          metadata: event.openTool,
        ),
      );
      _emitToolResults();
    } else if (event is HermesError) {
      _isDone = true;
      _completionCompleter.completeError(Exception(event.message));
    }
    // Other events (GatewayReady, StatusUpdate, ApprovalRequest, etc.)
    // are consumed by the UI layer directly via HermesEventBus — not forwarded here.
  }

  bool _matchesSession(HermesStreamEvent event) {
    if (event is MessageStart) return event.sessionId == _sessionId;
    if (event is MessageDelta) return event.sessionId == _sessionId;
    if (event is MessageComplete) return event.sessionId == _sessionId;
    if (event is ReasoningDelta) return event.sessionId == _sessionId;
    if (event is ReasoningAvailable) return event.sessionId == _sessionId;
    if (event is ThinkingDelta) return event.sessionId == _sessionId;
    if (event is ToolStart) return event.sessionId == _sessionId;
    if (event is ToolProgress) return event.sessionId == _sessionId;
    if (event is ToolGenerating) return event.sessionId == _sessionId;
    if (event is ToolComplete) return event.sessionId == _sessionId;
    if (event is HermesError) return event.sessionId == _sessionId;
    if (event is StatusUpdate) return event.sessionId == _sessionId;
    if (event is ApprovalRequest) return event.sessionId == _sessionId;
    if (event is ClarifyRequest) return event.sessionId == _sessionId;
    if (event is SudoRequest) return event.sessionId == _sessionId;
    if (event is SecretRequest) return event.sessionId == _sessionId;
    if (event is SessionInfo) return event.sessionId == _sessionId;
    if (event is Commentary) return event.sessionId == _sessionId;
    if (event is PreviewRestartProgress) return event.sessionId == _sessionId;
    if (event is PreviewRestartComplete) return event.sessionId == _sessionId;
    // Gateway-level events (no session_id) apply to all
    if (event is GatewayReady) return true;
    if (event is GatewayNotice) return true;
    if (event is SkinChanged) return true;
    return false;
  }

  void _emitContent({required bool isDone}) {
    final text = _textBuffer.toString();
    _chunkController.add(
      ChatStreamChunk(
        content: text,
        reasoning: _reasoningBuffer.isNotEmpty
            ? _reasoningBuffer.toString()
            : null,
        isDone: isDone,
        totalTokens: 0, // Hermes doesn't provide mid-stream token counts
        usage: isDone ? _finalUsage : null,
        toolCalls: _toolCalls.isNotEmpty ? List.of(_toolCalls) : null,
        toolResults: _toolResults.isNotEmpty ? List.of(_toolResults) : null,
      ),
    );
  }

  void _emitReasoning() {
    // Reasoning is emitted as a non-done content chunk with reasoning field set.
    _emitContent(isDone: false);
  }

  void _emitToolCalls() {
    // Re-emit with updated tool calls but no text change
    _emitContent(isDone: false);
  }

  void _emitToolResults() {
    // Re-emit with updated tool results but no text change
    _emitContent(isDone: false);
  }

  void _emitToolGenerating(String toolName, String content) {
    // Emit a content-chunk with empty text but tool results set
    // so the UI can show the tool generating state.
    _chunkController.add(
      ChatStreamChunk(
        content: '',
        isDone: false,
        totalTokens: 0,
        toolResults: _toolResults.isNotEmpty ? List.of(_toolResults) : null,
      ),
    );
  }

  TokenUsage? _parseUsage(MessageComplete event) {
    final payload = event.payload;
    if (payload == null) return null;
    final promptTokens = payload['prompt_tokens'] as int?;
    final completionTokens = payload['completion_tokens'] as int?;
    final totalTokens = payload['total_tokens'] as int?;
    final cachedTokens = payload['cached_tokens'] as int?;
    if (promptTokens == null &&
        completionTokens == null &&
        totalTokens == null) {
      return null;
    }
    return TokenUsage(
      promptTokens: promptTokens ?? 0,
      completionTokens: completionTokens ?? 0,
      totalTokens: totalTokens ?? 0,
      cachedTokens: cachedTokens ?? 0,
    );
  }

  /// Dispose the adapter and cancel the subscription.
  void dispose() {
    _subscription?.cancel();
    _chunkController.close();
  }
}
