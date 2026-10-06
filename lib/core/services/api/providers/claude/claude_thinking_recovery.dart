import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../../utils/multimodal_input_utils.dart';

const claudeThinkingRecoveryArtifactKind = 'claude_thinking_recovery';

/// Records only blocks rejected for a changed conversation prefix. Keeping
/// these fingerprints with subsequent replies prevents a restored session
/// from reintroducing them and invalidating newly generated thinking again.
class ClaudeThinkingRecovery {
  final _removed = <String>{};

  void readArtifact(Object? payload) {
    if (payload is! String) return;
    try {
      final value = jsonDecode(payload);
      if (value is List) _removed.addAll(value.whereType<String>());
    } on FormatException {
      // A damaged artifact must not stop an otherwise usable conversation.
    }
  }

  void readMessages(List<Map<String, dynamic>> messages) {
    for (final message in messages) {
      readArtifact(message[multimodalInternalClaudeThinkingRecoveryKey]);
    }
  }

  String? get artifact =>
      _removed.isEmpty ? null : jsonEncode(_removed.toList());

  /// Only the documented prefix mismatch can be repaired this way. Invalid
  /// signatures without that diagnosis, authentication errors, etc. propagate.
  /// The error's path addresses the actual body, after all custom overrides.
  bool recover(Map<String, dynamic> body, int status, String errorBody) {
    if (status != 400) return false;
    final Object? decoded;
    try {
      decoded = jsonDecode(errorBody);
    } on FormatException {
      return false;
    }
    if (decoded is! Map) return false;
    final error = decoded['error'];
    if (error is! Map || error['type'] != 'invalid_request_error') return false;
    final message = (error['message'] ?? '').toString();
    if (!message.contains('The block is bound to a different conversation.')) {
      return false;
    }
    final path = RegExp(r'messages\.(\d+)\.content\.(\d+)').firstMatch(message);
    if (path == null) return false;
    final messageIndex = int.tryParse(path[1]!);
    final blockIndex = int.tryParse(path[2]!);
    final messages = body['messages'];
    if (messages is! List ||
        messageIndex == null ||
        blockIndex == null ||
        messageIndex >= messages.length) {
      return false;
    }
    final failedMessage = messages[messageIndex];
    if (failedMessage is! Map || failedMessage['role'] != 'assistant') {
      return false;
    }
    final content = failedMessage['content'];
    if (content is! List ||
        blockIndex >= content.length ||
        !_isThinking(content[blockIndex])) {
      return false;
    }

    final before = _removed.length;
    for (var i = messageIndex; i < messages.length; i++) {
      final message = messages[i];
      if (message is! Map || message['role'] != 'assistant') continue;
      final blocks = message['content'];
      if (blocks is! List) continue;
      for (final block in blocks.skip(i == messageIndex ? blockIndex : 0)) {
        if (_isThinking(block)) _removed.add(_fingerprint(block as Map));
      }
    }
    return _removed.length > before;
  }

  /// Does not mutate stored blocks, tool calls/results, or the caller's input.
  /// A thinking-only message disappears if none of its blocks can be replayed.
  void filterRequest(Map<String, dynamic> body) {
    if (_removed.isEmpty) return;
    final messages = body['messages'];
    if (messages is! List) return;
    body['messages'] = [
      for (final message in messages)
        if (message is Map &&
            message['role'] == 'assistant' &&
            message['content'] is List)
          ..._filterMessage(message)
        else
          message,
    ];
  }

  Iterable<Map> _filterMessage(Map message) sync* {
    final original = message['content'] as List;
    final content = [
      for (final block in original)
        if (!_isThinking(block) ||
            !_removed.contains(_fingerprint(block as Map)))
          block,
    ];
    if (content.length == original.length) {
      yield message;
    } else if (content.isNotEmpty) {
      yield {...message, 'content': content};
    }
  }

  static bool _isThinking(Object? block) =>
      block is Map &&
      (block['type'] == 'thinking' || block['type'] == 'redacted_thinking');

  // Signatures and encrypted data identify the original blocks without
  // storing another copy of their potentially large opaque payloads.
  static String _fingerprint(Map block) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            block['type'],
            block['signature'] ?? block['data'] ?? block['thinking'],
          ]),
        ),
      )
      .toString();
}
