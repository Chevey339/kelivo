import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../providers/settings_provider.dart';
import '../chat_api_helpers.dart';
import '../generation/tool_loop_runner.dart';
import '../stream/stream_chunk.dart';

import 'openai/openai_provider.dart';

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
  bool builtInSearchOnly = false,
  bool skipImageParsing = false,
  StreamRoundRunner? retryRound,
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
    builtInSearchOnly: builtInSearchOnly,
    skipImageParsing: skipImageParsing,
    retryRound: retryRound,
  );
}
