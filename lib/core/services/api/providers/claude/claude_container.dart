import 'dart:convert';

/// Provider artifact kind under which a turn's code execution container is
/// stored against the assistant message that ran in it.
///
/// Only a request that declares the code execution tool stores or sends one.
/// Dynamic search filtering runs code execution too, but the API provisions
/// that itself and documents no `container` contract for it — so a turn that
/// only searched is treated as having no container, whatever the response
/// carried.
const String claudeContainerArtifactKind = 'claude_container';

/// Internal message key carrying the stored container into the next request.
/// Stripped before anything reaches the wire, like the other `_kelivo_` keys.
const String multimodalInternalClaudeContainerKey = '_kelivo_claude_container';

/// The container a code execution turn ran in, as the API reported it.
///
/// Files and REPL state live in the container, so the next turn sends the id
/// back to pick up where the last one left off. The API expires containers,
/// and says when, so an expired one is never offered.
class ClaudeContainerRef {
  const ClaudeContainerRef({required this.id, this.expiresAt});

  final String id;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && !expiresAt!.isAfter(DateTime.now().toUtc());

  /// Reads the `container` object of a Messages API response.
  static ClaudeContainerRef? fromResponse(Object? container) {
    if (container is! Map) return null;
    final id = (container['id'] ?? '').toString();
    if (id.isEmpty) return null;
    final raw = (container['expires_at'] ?? '').toString();
    return ClaudeContainerRef(
      id: id,
      expiresAt: raw.isEmpty ? null : DateTime.tryParse(raw)?.toUtc(),
    );
  }

  String encode() => jsonEncode({
    'id': id,
    if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
  });

  static ClaudeContainerRef? decode(Object? payload) {
    if (payload is! String || payload.isEmpty) return null;
    try {
      return fromResponse(jsonDecode(payload));
    } catch (_) {
      return null;
    }
  }
}

/// Removes the container key from a message about to be sent by a provider
/// that copies messages whole.
void stripClaudeContainerKey(Map<String, dynamic> message) {
  message.remove(multimodalInternalClaudeContainerKey);
}
