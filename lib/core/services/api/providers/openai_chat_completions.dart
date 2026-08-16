import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../providers/settings_provider.dart';
import '../../../utils/multimodal_input_utils.dart';
import '../chat_api_helpers.dart';
import '../stream/stream_chunk.dart';

import 'openai_common.dart';

Map<String, dynamic> copyChatCompletionMessage(Map<String, dynamic> m) {
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
      out['tool_calls'] = toolCalls.whereType<Map>().map((toolCall) {
        final copy = toolCall.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        copy.remove('metadata');
        return copy;
      }).toList();
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

  // Keep structured media refs across tool-followup rebuilds so later
  // Chat Completions builders can still emit image_url / multimodal parts.
  final mediaPaths = m[multimodalInternalMediaPathsKey];
  if (mediaPaths != null) {
    if (mediaPaths is List) {
      out[multimodalInternalMediaPathsKey] = [
        for (final item in mediaPaths)
          if (item is Map) Map<String, dynamic>.from(item) else item,
      ];
    } else if (mediaPaths is Map) {
      out[multimodalInternalMediaPathsKey] = Map<String, dynamic>.from(
        mediaPaths,
      );
    } else {
      out[multimodalInternalMediaPathsKey] = mediaPaths;
    }
  }
  final revisionId = m[multimodalInternalRevisionIdKey];
  if (revisionId != null) {
    out[multimodalInternalRevisionIdKey] = revisionId;
  }

  return out;
}

List<Map<String, dynamic>> cleanToolsForCompatibility(
  List<Map<String, dynamic>> tools,
) {
  final cleaned = tools.map((tool) {
    final result = Map<String, dynamic>.from(tool);
    final fn = result['function'];
    if (fn is Map) {
      final fnMap = Map<String, dynamic>.from(fn);
      final params = fnMap['parameters'];
      if (params is Map) {
        fnMap['parameters'] = cleanSchemaForGemini(
          Map<String, dynamic>.from(params),
        );
      }
      result['function'] = fnMap;
    }
    return result;
  }).toList();
  // print('[ChatApi/Tools] Cleaned ${cleaned.length} tools: ${jsonEncode(cleaned)}');
  return cleaned;
}

Stream<StreamChunk> sendOpenAIChatCompletionsStream(
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
  ToolCallHandler? onToolCall,
  Map<String, String>? extraHeaders,
  Map<String, dynamic>? extraBody,
  bool stream = true,
}) {
  final cfg = config.copyWith(useResponseApi: false);
  return sendOpenAIStream(
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
  );
}
