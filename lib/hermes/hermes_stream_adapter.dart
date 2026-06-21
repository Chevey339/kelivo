import 'dart:async';
import 'hermes_event_bus.dart';
import 'hermes_models.dart';
import '../core/models/token_usage.dart';

/// A streaming chunk from Hermes backend, compatible with ChatStreamChunk.
/// Maps Hermes events → streaming chunks for the existing StreamController.
class HermesStreamChunk {
  /// Accumulated text content.
  final String content;

  /// Reasoning/thinking delta.
  final String? reasoning;

  /// Whether the generation is complete.
  final bool isDone;

  /// Total tokens so far.
  final int totalTokens;

  /// Token usage from completion payload.
  final TokenUsage? usage;

  /// Tool calls started.
  final List<HermesToolCall>? toolCalls;

  /// Tool results received.
  final List<HermesToolResult>? toolResults;

  const HermesStreamChunk({
    this.content = '',
    this.reasoning,
    this.isDone = false,
    this.totalTokens = 0,
    this.usage,
    this.toolCalls,
    this.toolResults,
  });

  HermesStreamChunk copyWith({
    String? content,
    String? reasoning,
    bool? isDone,
    int? totalTokens,
    TokenUsage? usage,
    List<HermesToolCall>? toolCalls,
    List<HermesToolResult>? toolResults,
  }) {
    return HermesStreamChunk(
      content: content ?? this.content,
      reasoning: reasoning ?? this.reasoning,
      isDone: isDone ?? this.isDone,
      totalTokens: totalTokens ?? this.totalTokens,
      usage: usage ?? this.usage,
      toolCalls: toolCalls ?? this.toolCalls,
      toolResults: toolResults ?? this.toolResults,
    );
  }
}

/// Tool call info from Hermes.
class HermesToolCall {
  final String? id;
  final String name;
  final Map<String, dynamic>? args;
  final String? preview;
  final int index;
  final int? durationMs;

  const HermesToolCall({
    this.id,
    required this.name,
    this.args,
    this.preview,
    this.index = 0,
    this.durationMs,
  });

  factory HermesToolCall.fromToolStart(ToolStart event) {
    return HermesToolCall(
      id: event.args?['id']?.toString(),
      name: event.name,
      args: event.args,
      preview: event.preview,
      index: event.index,
    );
  }
}

/// Tool result info from Hermes.
class HermesToolResult {
  final String? id;
  final String name;
  final Map<String, dynamic>? args;
  final String? content;
  final int? durationMs;

  const HermesToolResult({
    this.id,
    required this.name,
    this.args,
    this.content,
    this.durationMs,
  });
}

/// Converts Hermes stream events into HermesStreamChunk objects.
///
/// Usage:
/// ```dart
/// final adapter = HermesStreamAdapter(eventBus: provider.eventBus);
/// adapter.stream(sessionId: sessionId).listen((chunk) { ... });
/// ```
class HermesStreamAdapter {
  HermesStreamAdapter({required this.eventBus});

  final HermesEventBus eventBus;
  StreamSubscription<HermesStreamEvent>? _sub;
  final _controller = StreamController<HermesStreamChunk>.broadcast();

  /// Accumulated state for the current session.
  String _content = '';
  String _reasoning = '';
  bool _isDone = false;
  int _totalTokens = 0;
  TokenUsage? _usage;
  final List<HermesToolCall> _toolCalls = [];
  final List<HermesToolResult> _toolResults = [];
  String? _currentSessionId;

  /// Start streaming events for a session.
  void start(String sessionId) {
    stop();
    _currentSessionId = sessionId;
    _reset();
    _sub = eventBus.allEvents.listen(_onEvent);
  }

  /// Stop streaming and reset state.
  void stop() {
    _sub?.cancel();
    _sub = null;
    _reset();
    _currentSessionId = null;
  }

  void _reset() {
    _content = '';
    _reasoning = '';
    _isDone = false;
    _totalTokens = 0;
    _usage = null;
    _toolCalls.clear();
    _toolResults.clear();
  }

  /// Stream of chunks for the current session.
  Stream<HermesStreamChunk> get stream => _controller.stream;

  void _emit() {
    _controller.add(
      HermesStreamChunk(
        content: _content,
        reasoning: _reasoning.isNotEmpty ? _reasoning : null,
        isDone: _isDone,
        totalTokens: _totalTokens,
        usage: _usage,
        toolCalls: _toolCalls.isNotEmpty ? List.unmodifiable(_toolCalls) : null,
        toolResults: _toolResults.isNotEmpty
            ? List.unmodifiable(_toolResults)
            : null,
      ),
    );
  }

  void _onEvent(HermesStreamEvent event) {
    if (_currentSessionId == null) return;

    bool emit = false;

    if (event is MessageDelta && event.sessionId == _currentSessionId) {
      _content += event.text;
      emit = true;
    }

    if (event is ReasoningDelta && event.sessionId == _currentSessionId) {
      _reasoning += event.text;
      emit = true;
    }

    if (event is ThinkingDelta && event.sessionId == _currentSessionId) {
      _reasoning += event.text;
      emit = true;
    }

    if (event is ToolStart && event.sessionId == _currentSessionId) {
      _toolCalls.add(HermesToolCall.fromToolStart(event));
      emit = true;
    }

    if (event is ToolProgress && event.sessionId == _currentSessionId) {
      // Update the latest matching tool call with progress
      // For now, emit with updated state
      emit = true;
    }

    if (event is ToolComplete && event.sessionId == _currentSessionId) {
      _toolResults.add(
        HermesToolResult(
          id: event.openTool?['id']?.toString(),
          name: event.name,
          args: event.openTool?['args'] as Map<String, dynamic>?,
          content: event.openTool?['content']?.toString(),
          durationMs: (event.duration * 1000).toInt(),
        ),
      );
      emit = true;
    }

    if (event is MessageComplete && event.sessionId == _currentSessionId) {
      _isDone = true;
      // Parse usage from payload
      if (event.payload != null) {
        final usageMap = event.payload!;
        _totalTokens = (usageMap['total_tokens'] as num?)?.toInt() ?? 0;
        _usage = TokenUsage(
          promptTokens: (usageMap['prompt_tokens'] as num?)?.toInt() ?? 0,
          completionTokens:
              (usageMap['completion_tokens'] as num?)?.toInt() ?? 0,
          totalTokens: _totalTokens,
          cachedTokens: (usageMap['cached_tokens'] as num?)?.toInt() ?? 0,
        );
      }
      emit = true;
    }

    if (emit) {
      _emit();
    }
  }

  void dispose() {
    stop();
    _controller.close();
  }
}

/// Token usage parsed from Hermes payload.
class HermesTokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int? cachedTokens;

  const HermesTokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    this.cachedTokens,
  });
}
