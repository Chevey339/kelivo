import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../models/reasoning_request.dart';
import '../../../providers/settings_provider.dart';
import '../chat_api_helpers.dart';
import '../generation/tool_loop_runner.dart';
import '../stream/stream_chunk.dart';

import 'openai/openai_provider.dart';

Stream<StreamChunk> sendOpenAIResponsesStream(
  http.Client client,
  ProviderConfig config,
  String modelId,
  List<Map<String, dynamic>> messages, {
  String? conversationId,
  List<String>? userImagePaths,
  ReasoningRequest reasoning = ReasoningRequest.auto,
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
  final cfg = config.copyWith(useResponseApi: true);
  return sendOpenAIStream(
    client,
    cfg,
    modelId,
    messages,
    conversationId: conversationId,
    userImagePaths: userImagePaths,
    reasoning: reasoning,
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
