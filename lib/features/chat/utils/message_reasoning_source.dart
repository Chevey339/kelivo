import 'dart:convert';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';

final _reasoningSources = Expando<({List<MessagePart> parts, bool provider})>();

/// Source evidence is independent of whether reasoning cards are visible or
/// contain displayable text. Malformed metadata cannot promote inline content.
bool messageHasProviderReasoning(ChatMessage message) {
  final cached = _reasoningSources[message];
  final parts = message.parts;
  if (cached != null && identical(cached.parts, parts)) return cached.provider;
  final provider = _readProviderReasoning(message);
  // Reasoning metadata fields are final; only storage-published parts can change.
  _reasoningSources[message] = (parts: parts, provider: provider);
  return provider;
}

bool _readProviderReasoning(ChatMessage message) {
  var providerReasoning =
      (message.reasoningText?.isNotEmpty ?? false) ||
      message.parts.any((part) => part is ReasoningPart);
  if (!providerReasoning && message.reasoningSegmentsJson != null) {
    try {
      final payload = jsonDecode(message.reasoningSegmentsJson!);
      final segments = payload is Map ? payload['segments'] : payload;
      // Match both persisted formats and the renderer's all-or-nothing decode.
      // A malformed segment must not turn inline thinking into main content.
      providerReasoning =
          segments is List &&
          segments.isNotEmpty &&
          segments.every(_validReasoningSegment);
    } on FormatException {
      // Malformed metadata cannot grant additional rendering authority.
    }
  }
  return providerReasoning;
}

bool _validReasoningSegment(Object? value) {
  if (value is! Map) return false;
  if (value['text'] != null && value['text'] is! String) return false;
  if (value['expanded'] != null && value['expanded'] is! bool) return false;
  if (value['toolStartIndex'] != null && value['toolStartIndex'] is! int) {
    return false;
  }
  for (final key in const ['startAt', 'finishedAt']) {
    final raw = value[key];
    if (raw != null && (raw is! String || DateTime.tryParse(raw) == null)) {
      return false;
    }
  }
  return true;
}
