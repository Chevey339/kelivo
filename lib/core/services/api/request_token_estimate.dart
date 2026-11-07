import 'dart:convert';
import '../../providers/settings_provider.dart';
import '../../utils/token_estimator.dart';
import 'request_history_context.dart';

/// Counts the actual wire projection, including tools, but never tokenizes
/// base64 image bytes as text. Call after the existing image planner.
int estimateRequestInput(Map<String, dynamic> body, ProviderKind kind) {
  var images = 0;
  dynamic countable(dynamic value) {
    if (value is List) return value.map(countable).toList();
    if (value is! Map) return value;
    final type = value['type'];
    // Encrypted state is not text tokens. Callers need a provider measurement
    // for a complete native-context count; never tokenize its base64 payload.
    if (type == 'compaction') return '[opaque native context]';
    final inline = value['inline_data'] ?? value['inlineData'];
    if (type == 'image' ||
        type == 'image_url' ||
        type == 'input_image' ||
        (inline is Map &&
            (inline['mime_type'] ?? inline['mimeType'] ?? '')
                .toString()
                .startsWith('image/'))) {
      images++;
      return '[image]';
    }
    return {
      for (final entry in value.entries)
        if (entry.key != historySourceKey)
          entry.key.toString(): countable(entry.value),
    };
  }

  final input = {
    for (final key in [
      'messages',
      'input',
      'contents',
      'system',
      'instructions',
      'systemInstruction',
      'system_instruction',
      'tools',
      'functions',
    ])
      if (body[key] != null) key: countable(body[key]),
  };
  return estimateTokens(jsonEncode(input)) + images * estimateImageTokens(kind);
}

/// Read the provider-normalized output reservation from the actual request.
int normalizedRequestOutputReserve(
  Map<String, dynamic> body,
  int? modelMaximum,
) {
  final generation = body['generationConfig'];
  final raw =
      body['max_completion_tokens'] ??
      body['max_output_tokens'] ??
      body['max_tokens'] ??
      (generation is Map ? generation['maxOutputTokens'] : null);
  final configured = raw is num
      ? raw.toInt()
      : int.tryParse(raw?.toString() ?? '');
  if (configured != null && configured > 0) return configured;
  return modelMaximum == null ? 4096 : modelMaximum.clamp(1, 4096);
}
