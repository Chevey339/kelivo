/// Mistral typed-thinking history replay.
///
/// Mistral's Chat Completions endpoint rejects the vendor reasoning echo fields
/// (`reasoning_content`, `reasoning`, `reasoning_details`) with
/// `422 extra_forbidden`, and it also rejects a top-level `thinking` switch.
/// Assistant history must instead carry the thought as a typed `thinking`
/// content part ahead of the visible body, while the request enables reasoning
/// through `reasoning_effort`.
///
/// The request builder gates this on the resolved model spec
/// (`ReasoningSpec.effortDefaultIsOff` with the effort dialect), so a provider
/// merely named Mistral does not change the replay shape.
library;

import 'chat_completions_decoder.dart';

/// The thought to replay for [message], or null when there is nothing to say.
///
/// Scalar reasoning is the canonical saved form. OpenRouter-style text/summary
/// details are a fallback for imported history, and typed parts cover a
/// response that is replayed before it is persisted. Exactly one source wins,
/// so the same thought is never sent twice.
String? mistralReplayThinkingText(Map<String, dynamic> message) {
  final scalar =
      _nonBlank(message['reasoning_content']) ??
      _nonBlank(message['reasoning']);
  if (scalar != null) return scalar;
  final details = _reasoningDetailsText(message['reasoning_details']);
  if (details != null) return details;
  return _nonBlank(openAIContentParts(message['content']).thinking);
}

/// Prepends [thinking] as a typed thinking part to assistant [content].
///
/// Existing thinking/reasoning parts are dropped: the extracted thought is the
/// single replayable copy, and a non-stream tool continuation can echo the
/// original part with `closed`/`signature` metadata that Mistral does not
/// accept in history. Other parts keep their order.
///
/// A whitespace-only body is a tool-round placeholder rather than visible
/// output, so it is dropped instead of being sent as an empty text part.
dynamic mistralAssistantContentWithThinking(dynamic content, String thinking) {
  final thinkingPart = <String, dynamic>{
    'type': 'thinking',
    'thinking': [
      {'type': 'text', 'text': thinking},
    ],
  };
  if (content is List) {
    return [
      thinkingPart,
      for (final part in content)
        if (!_isThinkingPart(part)) part,
    ];
  }
  final text = switch (content) {
    String value => value,
    null => '',
    _ => content.toString(),
  };
  if (text.trim().isEmpty) return [thinkingPart];
  return [
    thinkingPart,
    {'type': 'text', 'text': text},
  ];
}

/// Drops thinking/reasoning parts from assistant [content] when history replay
/// is disabled. An empty result becomes an empty body instead of an empty
/// content array.
dynamic mistralAssistantContentWithoutThinking(dynamic content) {
  if (content is! List) return content;
  final parts = [
    for (final part in content)
      if (!_isThinkingPart(part)) part,
  ];
  return parts.isEmpty ? '' : parts;
}

bool _isThinkingPart(dynamic part) {
  if (part is! Map) return false;
  final type = (part['type'] ?? '').toString();
  return type == 'thinking' || type == 'reasoning';
}

/// Joins the prose of plain `reasoning.text` / `reasoning.summary` blocks.
/// Opaque blocks (encrypted payloads, signatures) carry no replayable text.
String? _reasoningDetailsText(dynamic raw) {
  if (raw is! List) return null;
  final buffer = StringBuffer();
  for (final item in raw) {
    if (item is! Map) continue;
    final type = (item['type'] ?? 'reasoning.text').toString();
    final String? text;
    if (type == 'reasoning.text') {
      text = _stringOrNull(item['text']);
    } else if (type == 'reasoning.summary') {
      text = _stringOrNull(item['summary']) ?? _stringOrNull(item['text']);
    } else {
      text = null;
    }
    if (text == null || text.isEmpty) continue;
    buffer.write(text);
  }
  return _nonBlank(buffer.toString());
}

String? _stringOrNull(dynamic value) => value is String ? value : null;

String? _nonBlank(dynamic value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value;
}
