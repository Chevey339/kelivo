import '../../../network/provider_http_exception.dart';
import '../../../../models/image_context.dart';
import 'responses_request.dart';
import '../../native_compaction_context.dart';
import '../../request_history_context.dart';
import '../../request_image_context.dart';
import '../../../custom_request_merger.dart';
import '../../../../models/provider_oauth.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../models/model_spec.dart';
import '../../../../models/token_usage.dart';
import '../../../../providers/model_provider.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../utils/provider_url.dart';
import '../../../model_spec/model_spec_resolver.dart';
import '../../../model_spec/vendor_defaults.dart';
import '../../builtin_tools.dart';
import '../../chat_api_helpers.dart';
import '../../response_speed.dart';
import '../../native_input_attachments.dart';
import '../../generation/tool_loop_runner.dart';
import '../../kimi_formula_search.dart';
import '../../reasoning/reasoning_dialects.dart';
import '../../stream/sse_framing.dart';
import '../../stream/stream_chunk.dart';
import '../../stream/stream_chunk_emit.dart';
import '../../stream/stream_chunk_ids.dart';
import 'chat_completions_api.dart';
import 'chat_completions_decoder.dart';
import 'openai_request_shaping.dart';
import 'reasoning_details_replay.dart';
import 'responses_api.dart';
import 'responses_decoder.dart';
import 'responses_history.dart';

Uri _openAICompatibleUrl(ProviderConfig config) =>
    Uri.parse(resolveRequestUrl(config));

Stream<StreamChunk> sendOpenAIStream(
  http.Client client,
  ProviderConfig config,
  String modelId,
  List<Map<String, dynamic>> messages, {
  String? conversationId,
  String? serviceTier,
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
}) async* {
  final upstreamModelId = apiModelId(config, modelId);
  final cacheKey = conversationId?.trim() ?? '';
  final promptCacheKey =
      config.promptCacheKeyEnabled && !config.isOAuth && cacheKey.isNotEmpty
      ? cacheKey
      : null;
  // Utility calls (title / summary generation) only want search injected.
  final Iterable<String>? configuredBuiltInTools = builtInSearchOnly
      ? builtInTools(
          config,
          modelId,
        ).where((name) => name == BuiltInToolNames.search)
      : null;
  final url =
      hasNativeCompaction(messages) ||
          RequestHistoryContext.current?.nativeCompression == true
      ? nativeResponsesEndpoint(config)
      : _openAICompatibleUrl(config);

  final spec = ModelSpecResolver.instance.spec(config, modelId);
  final wantsImageOutput = spec.output.contains(Modality.image);
  final bool canImageInput = spec.input.contains(Modality.image);
  final maxTokensKey = VendorDefaults.forProvider(
    config,
    modelId: upstreamModelId,
  ).maxTokensKey;
  final extraBodyCfg = customBody(config, modelId, assistantBody: extraBody);
  final bool allowRemoteImages = canImageInput && spec.remoteImageUrls;
  // OpenRouter sends deltas, not cumulative snapshots. The decoder joins
  // fragments into complete blocks after collecting the response.
  final reasoningDetailsAllowSnapshots =
      !BuiltInToolsHelper.isOpenRouterProvider(config);
  final bool needsReasoningEcho =
      spec.reasoning.replay != ReasoningReplayPolicy.none;
  void setMaxTokens(Map<String, dynamic> map) {
    if (maxTokens != null &&
        !extraBodyCfg.containsKey('max_tokens') &&
        !extraBodyCfg.containsKey('max_completion_tokens')) {
      map[maxTokensKey] = maxTokens;
    }
  }

  // Kimi K3 Formula web-search: fetch tool decls, then fiber-execute calls.
  // Only names actually inserted after duplicate resolution are dispatched.
  final formulaToolNames = <String>{};
  List<Map<String, dynamic>> kimiFormulaTools = const <Map<String, dynamic>>[];
  final builtInSearchEnabled = builtInTools(
    config,
    modelId,
  ).contains(BuiltInToolNames.search);
  if (BuiltInToolsHelper.isVercelProvider(config) &&
      config.useResponseApi == true &&
      builtInSearchEnabled &&
      !BuiltInToolsHelper.supportsBuiltInSearchForModel(
        cfg: config,
        modelId: modelId,
      )) {
    throw UnsupportedError(
      'Kelivo supports Vercel Responses native web search with OpenAI models. '
      'Use Chat Completions for Vercel Gateway search with other models.',
    );
  }
  if (config.useResponseApi != true &&
      BuiltInToolsHelper.isMoonshotProvider(config) &&
      builtInSearchEnabled) {
    try {
      kimiFormulaTools = await KimiFormulaSearch.fetchTools(
        client: client,
        config: config,
      );
    } catch (_) {
      kimiFormulaTools = const <Map<String, dynamic>>[];
    }
  }
  Future<Object?> resolveToolCall(
    String name,
    Map<String, dynamic> args, {
    String? toolCallId,
  }) async {
    if (formulaToolNames.contains(name)) {
      return KimiFormulaSearch.executeFiber(
        client: client,
        config: config,
        name: name,
        arguments: jsonEncode(args),
      );
    }
    if (onToolCall != null) {
      return onToolCall(name, args, toolCallId: toolCallId);
    }
    throw Exception('No tool handler for $name');
  }

  final ToolCallHandler? effectiveOnToolCall =
      (onToolCall != null || kimiFormulaTools.isNotEmpty)
      ? resolveToolCall
      : null;

  Map<String, dynamic> body;
  // Keep initial Responses request context so we can perform follow-up requests when tools are called
  List<Map<String, dynamic>> responsesInitialInput =
      const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> responsesToolsSpec =
      const <Map<String, dynamic>>[];
  String responsesInstructions = '';
  List<dynamic>? responsesIncludeParam;
  final responsesRecorder = ResponsesTurnRecorder(
    responsesReplayScope(config, modelId),
  );
  RequestHistoryContext.current?.format = config.useResponseApi == true
      ? HistoryWireFormat.responses
      : HistoryWireFormat.chatCompletions;
  if (config.useResponseApi == true) {
    body = await buildOpenAIResponsesBody(
      config,
      modelId,
      messages,
      tools: tools,
      userImagePaths: userImagePaths,
      configuredBuiltInTools: configuredBuiltInTools,
      stream: stream,
      skipImageParsing: skipImageParsing,
      temperature: temperature,
      topP: topP,
      maxTokens: maxTokens,
    );
    // Save initial Responses context
    try {
      responsesInitialInput = List<Map<String, dynamic>>.from(
        (body['input'] as List).map((e) => (e as Map).cast<String, dynamic>()),
      );
    } catch (_) {
      responsesInitialInput = const <Map<String, dynamic>>[];
    }
    try {
      if (body['tools'] is List) {
        responsesToolsSpec = List<Map<String, dynamic>>.from(
          (body['tools'] as List).map(
            (e) => (e as Map).cast<String, dynamic>(),
          ),
        );
      }
    } catch (_) {
      responsesToolsSpec = const <Map<String, dynamic>>[];
    }
    try {
      responsesInstructions = (body['instructions'] ?? '').toString();
    } catch (_) {
      responsesInstructions = '';
    }
    try {
      responsesIncludeParam = body['include'] as List?;
    } catch (_) {
      responsesIncludeParam = null;
    }
  } else {
    final mm = await buildOpenAIChatCompletionMessages(
      messages,
      userMediaPaths: userImagePaths,
      nativeInputs: NativeInputAttachments(
        config: config,
        spec: spec,
        protocol: NativeInputProtocol.chatCompletions,
      ),
      canImageInput: canImageInput,
      allowRemoteImages: allowRemoteImages,
      reasoningReplay: spec.reasoning.replay,
      replayField: spec.reasoning.replayField,
      skipImageParsing: skipImageParsing,
    );
    body = {
      'model': upstreamModelId,
      'messages': mm,
      'stream': stream,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (tools != null && tools.isNotEmpty)
        'tools': copyChatCompletionTools(tools),
      if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
    };
    setMaxTokens(body);
  }

  final request = http.Request('POST', url);
  final headers = customHeaders(
    config,
    modelId,
    baseHeaders: <String, String>{
      'Authorization': 'Bearer ${apiKeyForRequest(config, modelId)}',
      'Content-Type': 'application/json',
      'Accept': stream ? 'text/event-stream' : 'application/json',
    },
    assistantHeaders: extraHeaders,
  );
  request.headers.addAll(headers);
  maybeAddStreamingUsageOptions(body, stream: stream, config: config);
  if (config.useResponseApi != true) {
    formulaToolNames.addAll(
      KimiFormulaSearch.mergeTools(body, kimiFormulaTools),
    );
  }
  applyOpenAIResolvedRequest(
    body,
    config: config,
    spec: spec,
    reasoning: reasoning,
    transport: config.useResponseApi == true
        ? ReasoningTransport.responses
        : ReasoningTransport.chatCompletions,
  );
  // Custom body keys go last so they win over the reasoning dialect.
  validateNativeCompactionOverrides(body, extraBodyCfg);
  CustomRequestMerger.applyBody(body, extraBodyCfg);
  applyServiceTier(body, config, serviceTier);
  if (promptCacheKey != null) {
    body.putIfAbsent('prompt_cache_key', () => promptCacheKey);
  }
  // Built-in tools run after the custom body and merge by type so custom
  // function tools and provider server tools coexist.
  Object? builtInSearchQuery;
  if (config.useResponseApi != true) {
    builtInSearchQuery = applyChatCompletionsBuiltInTools(
      body,
      config: config,
      modelId: modelId,
      upstreamModelId: upstreamModelId,
      configuredTools: configuredBuiltInTools,
    );
  }
  request.body = await RequestImageContext.encodeBody(body);

  final response = await client.send(request);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    final errorBody = await response.stream.bytesToString();
    throw ProviderHttpException(response, errorBody);
  }

  // Non-streaming path: parse one-shot JSON and optionally follow tool calls.
  if (!stream) {
    final txt = await decodeUtf8Stream(response.stream);
    try {
      final obj = jsonDecode(txt);
      // Responses API non-stream
      if (config.useResponseApi == true) {
        for (final chunk
            in ResponsesStreamDecoder(sourceId: 'finish').decodeSearchResults(
              obj['response'] is Map ? obj['response'] as Map : obj as Map,
            )) {
          yield chunk;
        }
        String outText = '';
        final rawOutput = obj['output'] ?? obj['response']?['output'];
        final reasoningText = responsesReasoningText(rawOutput);
        try {
          outText = (obj['output_text'] ?? '').toString();
        } catch (_) {}
        if (outText.isEmpty) {
          try {
            outText = (obj['response']?['output_text'] ?? '').toString();
          } catch (_) {}
        }
        final shouldReadOutputText = outText.isEmpty;
        final images = <({String uri, String mimeType})>[];
        try {
          final out = rawOutput as List?;
          if (out != null) {
            final buf = StringBuffer(outText);
            for (final it in out) {
              if (it is! Map) continue;
              if (isResponsesImageGenerationType(it['type'])) {
                final source = responsesImageGenerationSource(it);
                if (source.isNotEmpty) {
                  if (isRemoteHttpUrl(source)) {
                    // Already renderable; keep the remote URL as-is.
                    images.add((
                      uri: source,
                      mimeType: mimeTypeFromImageUri(source) ?? 'image/png',
                    ));
                  } else {
                    final saved = await saveResponsesImageGeneration(
                      source,
                      outputFormat:
                          (it['output_format'] ?? it['outputFormat'] ?? '')
                              .toString(),
                    );
                    if (saved != null) images.add(saved);
                  }
                }
                continue;
              }
              if (!shouldReadOutputText) continue;
              if (it['type'] == 'output_text') {
                final c = (it['content'] ?? '').toString();
                if (c.isNotEmpty) buf.write(c);
              } else if (it['type'] == 'message') {
                final content = it['content'] as List?;
                if (content != null) {
                  for (final part in content) {
                    if (part is Map &&
                        (part['type'] == 'output_text' ||
                            part['type'] == 'text')) {
                      final t = (part['text'] ?? part['content'] ?? '')
                          .toString();
                      if (t.isNotEmpty) buf.write(t);
                    }
                  }
                }
              }
            }
            outText = buf.toString();
          }
        } catch (_) {}
        final usage = mergeOpenAICompatibleUsage(
          null,
          obj['usage'] ?? obj['response']?['usage'],
        );
        final ids = StreamChunkIds('finish');
        yield* emitImages(images, ids: ids);
        final outputItems = <Map<String, dynamic>>[
          if (rawOutput is List)
            for (final item in rawOutput.whereType<Map>())
              item.cast<String, dynamic>(),
        ];
        final calls = responsesCallsFromOutput(outputItems);
        yield responsesRecorder.record(outputItems, calls);
        if (calls.isNotEmpty && effectiveOnToolCall != null) {
          yield* emitDelta(
            ids: ids,
            content: outText,
            reasoning: reasoningText,
            usage: usage,
          );
          yield* runOpenAIResponsesToolFollowUps(
            recorder: responsesRecorder,
            client: client,
            config: config,
            modelId: modelId,
            upstreamModelId: upstreamModelId,
            url: url,
            spec: spec,
            initialInput: responsesInitialInput,
            firstOutputItems: outputItems,
            initialCalls: calls,
            responsesToolsSpec: responsesToolsSpec,
            responsesInstructions: responsesInstructions,
            responsesIncludeParam: responsesIncludeParam,
            onToolCall: effectiveOnToolCall,
            extraHeaders: extraHeaders,
            extraBody: extraBody,
            serviceTier: serviceTier,
            promptCacheKey: promptCacheKey,
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens,
            reasoning: reasoning,
            initialUsage: usage,
            streamRound: 1,
            approxPromptTokens: (jsonEncode(messages).length / 4).round(),
            approxCompletionChars: outText.length,
            stream: false,
            retryRound: retryRound,
          );
          return;
        }
        yield* emitDone(
          ids: ids,
          content: outText,
          reasoning: reasoningText.isEmpty ? null : reasoningText,
          finishReason: responsesFinishReason(obj as Map),
          usage: usage,
          totalTokens: usage?.totalTokens ?? 0,
        );
        return;
      }

      // Chat Completions non-stream with tool-calls follow-ups
      final lastObj = obj is Map
          ? Map<String, dynamic>.from(obj)
          : <String, dynamic>{};
      final firstUsage = openaiUsageFromObj(lastObj);
      final firstChoice = openaiFirstChoice(lastObj);
      if (firstChoice == null) {
        yield* emitDone(
          ids: StreamChunkIds('finish'),
          content: (lastObj['output_text'] ?? '').toString(),
          usage: firstUsage,
          totalTokens: firstUsage?.totalTokens ?? 0,
          finishReason: (lastObj['finish_reason'] ?? '').toString().isEmpty
              ? null
              : lastObj['finish_reason'].toString(),
        );
        return;
      }
      final firstCalls = openaiCallsFromCompletionMessage(
        (firstChoice['message'] as Map?)?.cast<String, dynamic>(),
      );
      if (firstCalls.isNotEmpty && effectiveOnToolCall != null) {
        yield* runOpenAIChatCompletionsNonStreamToolFollowUps(
          client: client,
          config: config,
          modelId: modelId,
          upstreamModelId: upstreamModelId,
          url: url,
          spec: spec,
          messages: messages,
          requestBody: body,
          firstObj: lastObj,
          initialCalls: firstCalls,
          onToolCall: effectiveOnToolCall,
          userImagePaths: userImagePaths,
          canImageInput: canImageInput,
          allowRemoteImages: allowRemoteImages,
          skipImageParsing: skipImageParsing,
          needsReasoningEcho: needsReasoningEcho,
          extraHeaders: extraHeaders,
          initialUsage: firstUsage,
          retryRound: retryRound,
        );
        return;
      }
      final visible = openaiVisibleOutputFromMessage(
        (firstChoice['message'] as Map?)?.cast<String, dynamic>(),
      );
      final firstMessage = openaiFirstChoiceMessage(lastObj);
      final ids = StreamChunkIds('finish');
      for (final chunk in ChatCompletionsStreamDecoder(
        sourceId: 'finish',
      ).decodeCitations(lastObj)) {
        yield chunk;
      }
      yield* emitImages(visible.images, ids: ids);
      yield* emitDone(
        ids: ids,
        content: visible.content,
        reasoning: openaiReasoningText(firstMessage),
        reasoningDetails: mergeReasoningDetails(
          firstMessage?['reasoning_details'],
        ),
        usage: firstUsage,
        totalTokens: firstUsage?.totalTokens ?? 0,
        finishReason: (firstChoice['finish_reason'] ?? '').toString().isEmpty
            ? null
            : firstChoice['finish_reason'].toString(),
      );
      return;
    } on ImageContextBudgetException {
      rethrow;
    } catch (e) {
      throw HttpException('Invalid JSON: $e');
    }
  }

  // Streaming path
  final sse = response.stream.transform(utf8.decoder);
  int totalTokens = 0;
  TokenUsage? usage;
  // Fallback approx token calculation when provider doesn't include usage
  int approxTokensFromChars(int chars) => (chars / 4).round();
  final int approxPromptChars = messages.fold<int>(
    0,
    (acc, m) => acc + ((m['content'] ?? '').toString().length),
  );
  final int approxPromptTokens = approxTokensFromChars(approxPromptChars);
  int approxCompletionChars = 0;
  String reasoningBuffer = '';
  String assistantContentBuffer = '';

  // Track potential tool calls (OpenAI Chat Completions)
  final Map<int, Map<String, dynamic>> toolAcc =
      <int, Map<String, dynamic>>{}; // index -> {id,name,args,extra_content?}
  // Track potential tool calls (OpenAI Responses API)
  final Map<String, Map<String, String>> toolAccResp =
      <String, Map<String, String>>{}; // id/name -> {name,args}
  // Responses API: track by output_index to capture call_id reliably
  final Map<int, Map<String, String>> respToolCallsByIndex =
      <int, Map<String, String>>{}; // index -> {call_id,name,args,series_id}
  List<Map<String, dynamic>> lastResponseOutputItems =
      const <Map<String, dynamic>>[];
  var streamRound = 0;
  final responsesDecoder = config.useResponseApi == true
      ? ResponsesStreamDecoder(
          initialUsage: usage,
          sourceId: 'round-${streamRound++}',
        )
      : null;
  final chatDecoder = config.useResponseApi == true
      ? null
      : ChatCompletionsStreamDecoder(
          wantsImageOutput: wantsImageOutput,
          needsReasoningEcho: needsReasoningEcho,
          allowReasoningSnapshots: reasoningDetailsAllowSnapshots,
          initialUsage: usage,
          sourceId: 'round-${streamRound++}',
        );

  await for (final event in parseSseEventStrings(
    sse,
    recoverAdjacentJsonDataRecords: config.useResponseApi != true,
  )) {
    final data = event.data;
    if (data.isNotEmpty && data != '[DONE]') {
      throwIfInBandStreamError(data);
    }
    try {
      if (config.useResponseApi == true) {
        final decoder = responsesDecoder!;
        final decoded = decoder.accept(event);
        for (final chunk in decoded.chunks) {
          yield chunk;
        }
        if (!decoded.completed) continue;
        for (final chunk in decoder.onClosed()) {
          yield chunk;
        }

        usage = decoder.usage ?? usage;
        totalTokens = usage?.totalTokens ?? totalTokens;
        approxCompletionChars = decoder.approxCompletionChars;
        lastResponseOutputItems = decoder.outputItems;
        respToolCallsByIndex
          ..clear()
          ..addAll({
            for (final call in decoder.takeFunctionCalls())
              call.index: call.toIndexFields(),
          });
        final recordedCalls = responsesCallsFromIndexMap(respToolCallsByIndex);
        yield responsesRecorder.record(
          withResponsesFunctionCallItems(
            lastResponseOutputItems,
            recordedCalls,
          ),
          recordedCalls,
        );
        if (!decoder.emittedImageEvents) {
          var fallbackCount = 0;
          for (final image in decoder.takeImages()) {
            if (image.base64.isEmpty) continue;
            final mdImg = await saveResponsesImageGenerationMarkdown(
              image.base64,
              outputFormat: image.outputFormat,
            );
            if (mdImg.isEmpty) continue;
            fallbackCount++;
            yield* emitDelta(
              ids: StreamChunkIds('round-0'),
              content: mdImg,
              usage: usage,
              totalTokens: totalTokens,
            );
          }
          if (fallbackCount > 0) {
            logImageFallback(
              provider: config.id,
              model: modelId,
              reason: 'responses_decoder_missed_image count=$fallbackCount',
            );
          }
        }
        if (!decoder.emittedCitationEvents && decoder.citations.isNotEmpty) {
          yield ServerToolStart(id: 'builtin_search', toolName: 'search_web');
          yield ServerToolEnd(
            id: 'builtin_search',
            output: <String, dynamic>{'items': decoder.citations},
          );
        }
        // Responses tool calling follow-up handling
        final bool hasRespCalls =
            respToolCallsByIndex.isNotEmpty || toolAccResp.isNotEmpty;
        if (effectiveOnToolCall != null && hasRespCalls) {
          final callInfos = respToolCallsByIndex.isNotEmpty
              ? responsesCallsFromIndexMap(respToolCallsByIndex)
              : [
                  for (final entry
                      in toolAccResp.entries.toList().asMap().entries)
                    emitToolCall(
                      id: effectiveToolCallId(
                        entry.value.key,
                        'call',
                        entry.key,
                      ),
                      name: (entry.value.value['name'] ?? '').toString(),
                      arguments: () {
                        try {
                          return (jsonDecode(entry.value.value['args'] ?? '{}')
                                  as Map)
                              .cast<String, dynamic>();
                        } catch (_) {
                          return <String, dynamic>{};
                        }
                      }(),
                    ),
                ];
          yield* runOpenAIResponsesToolFollowUps(
            recorder: responsesRecorder,
            client: client,
            config: config,
            modelId: modelId,
            upstreamModelId: upstreamModelId,
            url: url,
            spec: spec,
            initialInput: responsesInitialInput,
            firstOutputItems: lastResponseOutputItems,
            initialCalls: callInfos,
            responsesToolsSpec: responsesToolsSpec,
            responsesInstructions: responsesInstructions,
            responsesIncludeParam: responsesIncludeParam,
            onToolCall: effectiveOnToolCall,
            extraHeaders: extraHeaders,
            extraBody: extraBody,
            serviceTier: serviceTier,
            promptCacheKey: promptCacheKey,
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens,
            reasoning: reasoning,
            initialUsage: usage,
            streamRound: streamRound,
            approxPromptTokens: approxPromptTokens,
            approxCompletionChars: approxCompletionChars,
            retryRound: retryRound,
          );
          return;
        }

        final approxTotal =
            approxPromptTokens + approxTokensFromChars(approxCompletionChars);
        yield* emitDone(
          ids: StreamChunkIds('finish'),
          finishReason: decoder.finishReason,
          usage: usage,
          totalTokens: usage?.totalTokens ?? approxTotal,
        );
        return;
      } else {
        final decoder = chatDecoder!;
        final decoded = decoder.accept(event);
        for (final chunk in decoded.chunks) {
          yield chunk;
        }
        toolAcc
          ..clear()
          ..addAll(decoder.toolCalls);
        usage = decoder.usage ?? usage;
        if (usage != null) totalTokens = usage.totalTokens;
        approxCompletionChars = decoder.approxCompletionChars;
        reasoningBuffer = decoder.reasoningEcho;
        assistantContentBuffer = decoder.assistantContent;
        // Usage can arrive after finish_reason, including tool_calls. Drain
        // through [DONE] or EOF before starting the next API request.
        if (data == '[DONE]') break;
      }
    } on ImageContextBudgetException {
      rethrow;
    } on ProviderOAuthException {
      rethrow;
    } on HttpException {
      // In-band error frames raised inside this block (follow-up tool-call
      // streams call throwIfInBandStreamError in here) and failed follow-up
      // requests must surface as stream errors; swallowing them would let
      // the no-[DONE] fallback below persist truncated output as a normal
      // completion.
      rethrow;
    } catch (e) {
      // Skip malformed JSON
    }
  }

  // Close the first request after [DONE] or EOF, then continue client tools.
  for (final chunk in chatDecoder?.onClosed() ?? const <StreamChunk>[]) {
    yield chunk;
  }
  for (final chunk in responsesDecoder?.onClosed() ?? const <StreamChunk>[]) {
    yield chunk;
  }
  if (responsesDecoder != null) {
    usage = responsesDecoder.usage ?? usage;
    approxCompletionChars = responsesDecoder.approxCompletionChars;
    final output = responsesDecoder.outputItems;
    if (output.isNotEmpty) {
      // EOF can follow complete output_item.done events without a terminal
      // response event. Retain those native items, but do not synthesize or
      // execute function calls whose response never completed.
      yield responsesRecorder.record(
        output,
        responsesCallsFromIndexMap({
          for (final call in responsesDecoder.takeFunctionCalls())
            call.index: call.toIndexFields(),
        }),
      );
    }
  }
  if (chatDecoder != null &&
      effectiveOnToolCall != null &&
      toolAcc.isNotEmpty) {
    yield* runOpenAIChatCompletionsToolFollowUps(
      client: client,
      config: config,
      modelId: modelId,
      upstreamModelId: upstreamModelId,
      url: url,
      spec: spec,
      messages: messages,
      firstToolAcc: toolAcc,
      firstAssistantContent: assistantContentBuffer,
      firstReasoning: reasoningBuffer,
      firstReasoningDetails: chatDecoder.reasoningDetails,
      onToolCall: effectiveOnToolCall,
      userImagePaths: userImagePaths,
      canImageInput: canImageInput,
      allowRemoteImages: allowRemoteImages,
      skipImageParsing: skipImageParsing,
      reasoning: reasoning,
      temperature: temperature,
      topP: topP,
      tools: tools,
      builtInSearchQuery: builtInSearchQuery,
      extraBodyCfg: extraBodyCfg,
      serviceTier: serviceTier,
      promptCacheKey: promptCacheKey,
      extraHeaders: extraHeaders,
      wantsImageOutput: wantsImageOutput,
      needsReasoningEcho: needsReasoningEcho,
      reasoningDetailsAllowSnapshots: reasoningDetailsAllowSnapshots,
      applyMaxTokens: setMaxTokens,
      initialUsage: usage,
      streamRound: streamRound,
      approxPromptTokens: approxPromptTokens,
      approxCompletionChars: approxCompletionChars,
      includeReasoningDetailsOnDone: true,
      retryRound: retryRound,
    );
    return;
  }
  final approxTotal =
      usage?.totalTokens ??
      (approxPromptTokens + approxTokensFromChars(approxCompletionChars));
  yield* emitDone(
    ids: StreamChunkIds('finish'),
    reasoningDetails: chatDecoder?.reasoningDetails,
    finishReason: responsesDecoder?.finishReason ?? chatDecoder?.finishReason,
    usage: usage,
    totalTokens: approxTotal,
  );
}
