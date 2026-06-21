import '../../hermes/hermes_rpc.dart';
import '../../hermes/hermes_stream_adapter.dart';
import 'hermes_gateway_provider.dart';

export '../../hermes/hermes_stream_adapter.dart'
    show HermesStreamChunk, HermesToolCall, HermesToolResult;

/// Chat-specific extensions for [HermesGatewayProvider].
///
/// Manages Hermes session lifecycle, streaming, and interactive requests
/// (approval, clarify, sudo, secret) for the chat UI.
extension HermesChatProviderX on HermesGatewayProvider {
  // ── Hermes Chat Stream ─────────────────────────────────────────────────

  /// Subscribe to Hermes events and get a stream of chat chunks.
  HermesStreamAdapter subscribeToStream(String sessionId) {
    final adapter = HermesStreamAdapter(eventBus: eventBus);
    adapter.start(sessionId);
    streamAdapter = adapter;
    return adapter;
  }

  /// Stop the current stream subscription.
  void unsubscribeFromStream() {
    streamAdapter = null;
  }

  // ── Hermes Interactive Responses ────────────────────────────────────────

  /// Respond to an approval request.
  Future<void> respondApproval(
    String sessionId,
    bool approved, {
    String? reason,
  }) async {
    await gateway.approvalRespond(sessionId, approved, reason: reason);
    takePendingRequest(sessionId); // Remove from pending list
  }

  /// Respond to a clarify request.
  Future<void> respondClarify(
    String sessionId,
    Map<String, dynamic> response,
  ) async {
    await gateway.clarifyRespond(sessionId, response);
  }

  /// Respond to a sudo request.
  Future<void> respondSudo(
    String sessionId,
    bool approved, {
    String? reason,
  }) async {
    await gateway.sudoRespond(sessionId, approved, reason: reason);
  }

  /// Provide a secret (API key, token, etc.).
  Future<void> respondSecret(String sessionId, String secret) async {
    await gateway.secretRespond(sessionId, secret);
  }

  // ── Hermes Session History ───────────────────────────────────────────────

  /// Load message history from Hermes backend for a session.
  Future<List<HermesChatMessage>> loadSessionHistory(
    String sessionId, {
    int? limit,
    int? before,
  }) async {
    final raw = await gateway.sessionHistory(
      sessionId,
      limit: limit,
      before: before,
    );
    return raw.map((m) => HermesChatMessage.fromHermes(m)).toList();
  }

  /// Get session usage stats.
  Future<HermesSessionUsage?> getSessionUsage(String sessionId) async {
    final raw = await gateway.sessionUsage(sessionId);
    if (raw.isEmpty) return null;
    return HermesSessionUsage.fromJson(raw);
  }

  // ── File Attachments ────────────────────────────────────────────────────

  /// Attach a file to the current session.
  Future<String> attachFile(String path) async {
    final sessionId = activeSessionId;
    if (sessionId == null) throw StateError('No active session');
    return gateway.fileAttach(sessionId, path);
  }

  /// Attach an image URL to the current session.
  Future<String> attachImage(String url, {String? mimeType}) async {
    final sessionId = activeSessionId;
    if (sessionId == null) throw StateError('No active session');
    return gateway.imageAttach(sessionId, url, mimeType: mimeType);
  }

  /// Attach an image from base64 bytes.
  Future<String> attachImageBytes(
    String base64Bytes, {
    String? mimeType,
  }) async {
    final sessionId = activeSessionId;
    if (sessionId == null) throw StateError('No active session');
    return gateway.imageAttachBytes(sessionId, base64Bytes, mimeType: mimeType);
  }

  /// Paste clipboard content.
  Future<void> pasteClipboard(String content) async {
    final sessionId = activeSessionId;
    if (sessionId == null) return;
    await gateway.clipboardPaste(sessionId, content);
  }

  /// Report dropped files.
  Future<void> reportDroppedFiles(List<String> paths) async {
    final sessionId = activeSessionId;
    if (sessionId == null) return;
    await gateway.inputDetectDrop(sessionId, paths);
  }
}

// ── Hermes Session Data Models ──────────────────────────────────────────────

/// A chat message loaded from Hermes backend.
class HermesChatMessage {
  final String id;
  final String role; // 'user' | 'assistant' | 'system'
  final String? content;
  final String? reasoning;
  final DateTime? createdAt;
  final List<HermesToolEvent>? toolEvents;

  const HermesChatMessage({
    required this.id,
    required this.role,
    this.content,
    this.reasoning,
    this.createdAt,
    this.toolEvents,
  });

  factory HermesChatMessage.fromHermes(Map<String, dynamic> json) {
    return HermesChatMessage(
      id: json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      content: json['content']?.toString(),
      reasoning: json['reasoning']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      toolEvents: (json['tool_events'] as List<dynamic>?)
          ?.map((e) => HermesToolEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A tool event in Hermes message history.
class HermesToolEvent {
  final String? id;
  final String name;
  final Map<String, dynamic>? arguments;
  final String? content;
  final bool isComplete;

  const HermesToolEvent({
    this.id,
    required this.name,
    this.arguments,
    this.content,
    this.isComplete = false,
  });

  factory HermesToolEvent.fromJson(Map<String, dynamic> json) {
    return HermesToolEvent(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      arguments: (json['arguments'] as Map?)?.cast<String, dynamic>(),
      content: json['content']?.toString(),
      isComplete: json['content'] != null,
    );
  }
}

/// Session usage data from Hermes.
class HermesSessionUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int? cachedTokens;
  final String? modelId;

  const HermesSessionUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    this.cachedTokens,
    this.modelId,
  });

  factory HermesSessionUsage.fromJson(Map<String, dynamic> json) {
    return HermesSessionUsage(
      promptTokens: (json['prompt_tokens'] as num?)?.toInt() ?? 0,
      completionTokens: (json['completion_tokens'] as num?)?.toInt() ?? 0,
      totalTokens: (json['total_tokens'] as num?)?.toInt() ?? 0,
      cachedTokens: (json['cached_tokens'] as num?)?.toInt(),
      modelId: json['model']?.toString(),
    );
  }
}
