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
/// back to pick up where the last one left off. A container lives 30 days from
/// creation and is checkpointed after a few minutes idle; the `expires_at` the
/// API returns is only that short rolling window, not the lifetime, so it is
/// not read — a container is offered until the API refuses it.
class ClaudeContainerRef {
  const ClaudeContainerRef({required this.id});

  final String id;

  /// Reads the `container` object of a Messages API response.
  static ClaudeContainerRef? fromResponse(Object? container) {
    if (container is! Map) return null;
    final id = (container['id'] ?? '').toString();
    if (id.isEmpty) return null;
    return ClaudeContainerRef(id: id);
  }

  String encode() => jsonEncode({'id': id});

  static ClaudeContainerRef? decode(Object? payload) {
    if (payload is! String || payload.isEmpty) return null;
    try {
      return fromResponse(jsonDecode(payload));
    } catch (_) {
      return null;
    }
  }
}

/// Whether a failed request that named a container failed because of it.
///
/// The API has no dedicated error code for an expired or unknown container,
/// so this reads the message. The caller only asks when the request carried
/// a `container`, which makes an error that mentions one about that one.
bool isClaudeStaleContainerError(int statusCode, String errorBody) =>
    statusCode >= 400 &&
    statusCode < 500 &&
    errorBody.toLowerCase().contains('container');

/// Removes the container key from a message about to be sent by a provider
/// that copies messages whole.
void stripClaudeContainerKey(Map<String, dynamic> message) {
  message.remove(multimodalInternalClaudeContainerKey);
}
