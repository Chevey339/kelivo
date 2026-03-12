part of '../chat_api_service.dart';

Map<String, dynamic> _copyChatCompletionMessage(Map<String, dynamic> m) {
  final role = (m['role'] ?? 'user').toString();
  final out = <String, dynamic>{
    'role': role,
    'content': m.containsKey('content') ? (m['content'] ?? '') : '',
  };

  // Preserve optional name (some providers support it on non-tool roles).
  final name = m['name'];
  if (role != 'tool' && name != null && name.toString().isNotEmpty) {
    out['name'] = name;
  }

  // Preserve assistant tool_calls + vendor reasoning echoes (when present).
  if (role == 'assistant') {
    final toolCalls = m['tool_calls'];
    if (toolCalls is List && toolCalls.isNotEmpty) {
      out['tool_calls'] = toolCalls;
    }
    final functionCall = m['function_call'];
    if (functionCall != null) {
      out['function_call'] = functionCall;
    }
    if (m['reasoning_content'] != null) {
      out['reasoning_content'] = m['reasoning_content'];
    }
    if (m['reasoning_details'] != null) {
      out['reasoning_details'] = m['reasoning_details'];
    }
  }

  // Preserve tool linkage fields.
  if (role == 'tool') {
    final toolCallId = m['tool_call_id'];
    if (toolCallId != null && toolCallId.toString().isNotEmpty) {
      out['tool_call_id'] = toolCallId;
    }
    if (name != null && name.toString().isNotEmpty) {
      out['name'] = name;
    }
  }

  return out;
}

List<Map<String, dynamic>> _cleanToolsForCompatibility(
  List<Map<String, dynamic>> tools,
) {
  final cleaned = tools.map((tool) {
    final result = Map<String, dynamic>.from(tool);
    final fn = result['function'];
    if (fn is Map) {
      final fnMap = Map<String, dynamic>.from(fn as Map);
      final params = fnMap['parameters'];
      if (params is Map) {
        fnMap['parameters'] = _cleanSchemaForGemini(
          params as Map<String, dynamic>,
        );
      }
      result['function'] = fnMap;
    }
    return result;
  }).toList();
  // print('[ChatApi/Tools] Cleaned ${cleaned.length} tools: ${jsonEncode(cleaned)}');
  return cleaned;
}

Stream<ChatStreamChunk> _sendOpenAIChatCompletionsStream(
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
  final cfg = config.copyWith(useResponseApi: false);
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
