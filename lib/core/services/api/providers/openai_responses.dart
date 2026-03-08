part of '../chat_api_service.dart';

List<Map<String, dynamic>> _toResponsesToolsFormat(
  List<Map<String, dynamic>> tools,
) {
  return tools.map((tool) {
    // Keep non-function tools (e.g., web_search) unchanged
    if ((tool['type'] ?? '').toString() != 'function') {
      return Map<String, dynamic>.from(tool);
    }

    // If already flattened (no nested 'function'), return as-is
    if (tool['function'] is! Map) {
      return Map<String, dynamic>.from(tool);
    }

    final fn = Map<String, dynamic>.from(tool['function'] as Map);
    final out = <String, dynamic>{
      'type': 'function',
      if (fn['name'] != null) 'name': fn['name'],
      if (fn['description'] != null) 'description': fn['description'],
    };
    final params = fn['parameters'];
    if (params is Map<String, dynamic>) {
      // Ensure parameters stays as-is (schema)
      out['parameters'] = params;
    }
    // Preserve strict flag if present (either at tool-level or function-level)
    final strict = (tool['strict'] ?? fn['strict']);
    if (strict is bool) {
      out['strict'] = strict;
    }
    return out;
  }).toList();
}

Stream<ChatStreamChunk> _sendOpenAIResponsesStream(
  http.Client client,
  ProviderConfig config,
  String modelId,
  List<Map<String, dynamic>> messages, {
  List<String>? userImagePaths,
  int? thinkingBudget,
  double? temperature,
  double? topP,
  int? maxTokens,
  List<Map<String, dynamic>>? tools,
  Future<String> Function(String, Map<String, dynamic>)? onToolCall,
  Map<String, String>? extraHeaders,
  Map<String, dynamic>? extraBody,
  bool stream = true,
  String? verbosity,
}) {
  final cfg = config.copyWith(useResponseApi: true);
  return _sendOpenAIStream(
    client,
    cfg,
    modelId,
    messages,
    userImagePaths: userImagePaths,
    thinkingBudget: thinkingBudget,
    temperature: temperature,
    topP: topP,
    maxTokens: maxTokens,
    tools: tools,
    onToolCall: onToolCall,
    extraHeaders: extraHeaders,
    extraBody: extraBody,
    stream: stream,
    verbosity: verbosity,
  );
}
