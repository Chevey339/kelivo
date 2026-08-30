import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../models/token_usage.dart';
import '../../../../providers/model_provider.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../utils/multimodal_input_utils.dart';
import '../../../../../utils/sandbox_path_resolver.dart';
import '../../builtin_tools.dart';
import '../../chat_api_helpers.dart';
import '../../kimi_formula_search.dart';
import '../../stream/sse_framing.dart';
import '../../stream/stream_chunk.dart';
import '../../stream/stream_chunk_emit.dart';
import '../../stream/stream_chunk_ids.dart';
import 'chat_completions_api.dart';
import 'chat_completions_decoder.dart';
import 'openai_vendor_compat.dart';
import 'responses_api.dart';
import 'responses_decoder.dart';

Uri _openAICompatibleUrl(ProviderConfig config) {
  final rawBase = config.baseUrl.endsWith('/')
      ? config.baseUrl.substring(0, config.baseUrl.length - 1)
      : config.baseUrl;
  final baseUri = Uri.parse(rawBase);
  if (config.useResponseApi == true) {
    final normalizedPath = baseUri.path.replaceAll(RegExp(r'/$'), '');
    if (BuiltInToolsHelper.isDashScopeProvider(config) &&
        normalizedPath != '/api/v2/apps/protocols/compatible-mode/v1') {
      return Uri.parse(
        '${baseUri.scheme}://${baseUri.authority}'
        '/api/v2/apps/protocols/compatible-mode/v1/responses',
      );
    }
    return Uri.parse('$rawBase/responses');
  }
  final path = config.chatPath ?? '/chat/completions';
  return Uri.parse('$rawBase$path');
}

/// Accumulates streamed `reasoning_details` entries.
///
/// OpenRouter streams the array as ordered deltas (each chunk may carry one
/// or more new entries) that must be concatenated and replayed unmodified
/// and in the original order, so chunks are appended by default and identical
/// consecutive deltas are preserved. Some other providers instead resend the
/// full array-so-far with each chunk; for those (when [allowSnapshots] is
/// set) a chunk that positively looks like such a cumulative snapshot (same
/// entries plus new ones appended) switches the accumulator to snapshot
/// mode, and later chunks replace the buffer instead of appending
/// duplicates. For OpenRouter itself [allowSnapshots] is cleared because its
/// documented semantics are always delta-style concatenation.
class _ReasoningDetailsAccumulator {
  _ReasoningDetailsAccumulator({this.allowSnapshots = true});

  /// Whether cumulative-snapshot detection is enabled (false for OpenRouter,
  /// whose documented semantics are delta-style concatenation).
  final bool allowSnapshots;
  List<dynamic> _details = const <dynamic>[];
  bool _snapshotMode = false;

  /// The accumulated entries, or null when nothing was captured.
  List<dynamic>? get detailsOrNull => _details.isEmpty ? null : _details;

  void add(List<dynamic> incoming) {
    if (incoming.isEmpty) return;
    if (_details.isEmpty) {
      _details = List<dynamic>.of(incoming);
      return;
    }
    final prefixMatches = allowSnapshots && _hasCurrentAsPrefix(incoming);
    if (prefixMatches && incoming.length > _details.length) {
      // Positive evidence of a cumulative snapshot: same prefix, but longer.
      _snapshotMode = true;
      _details = List<dynamic>.of(incoming);
      return;
    }
    if (_snapshotMode && prefixMatches) {
      // Snapshot-style resend of the same array; keep the buffer as-is.
      return;
    }
    _details = <dynamic>[..._details, ...incoming];
  }

  bool _hasCurrentAsPrefix(List<dynamic> incoming) {
    if (incoming.length < _details.length) return false;
    for (var i = 0; i < _details.length; i++) {
      if (jsonEncode(_details[i]) != jsonEncode(incoming[i])) return false;
    }
    return true;
  }
}

Stream<StreamChunk> sendOpenAIStream(
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
}) async* {
  final upstreamModelId = apiModelId(config, modelId);
  // Utility calls (title / summary generation) only want search injected.
  final Iterable<String>? configuredBuiltInTools = builtInSearchOnly
      ? builtInTools(
          config,
          modelId,
        ).where((name) => name == BuiltInToolNames.search)
      : null;
  final url = _openAICompatibleUrl(config);
  // Claude models served through OpenAI-compatible proxies require signed
  // thinking blocks; unsigned reasoning echoes are stripped before sending.
  final isClaudeUpstream = upstreamModelId.toLowerCase().contains('claude');

  final effectiveInfo = effectiveModelInfo(config, modelId);
  final isReasoning = effectiveInfo.abilities.contains(ModelAbility.reasoning);
  final wantsImageOutput = effectiveInfo.output.contains(Modality.image);
  final bool canImageInput = effectiveInfo.input.contains(Modality.image);
  final bool allowRemoteImages =
      canImageInput && !isKimiK3Model(upstreamModelId);

  final effort = openAIEffortForBudget(thinkingBudget, upstreamModelId);
  final info = OpenAIProviderInfo(
    host: Uri.tryParse(config.baseUrl)?.host.toLowerCase() ?? '',
    providerId: config.id.toLowerCase(),
    upstreamModelId: upstreamModelId,
  );
  // OpenRouter documents delta-style `reasoning_details` chunks that must be
  // concatenated in order, so cumulative-snapshot detection is disabled for
  // it; other providers may resend the full array-so-far with each chunk.
  final reasoningDetailsAllowSnapshots =
      !BuiltInToolsHelper.isOpenRouterProvider(config);
  final bool needsReasoningEcho =
      info.needsReasoningEcho &&
      (isReasoning || (info.isDeepSeek && tools?.isNotEmpty == true));
  void setMaxTokens(Map<String, dynamic> map) {
    if (maxTokens != null) map[info.completionTokensKey] = maxTokens;
  }

  // Kimi K3 Formula web-search: fetch tool decls, then fiber-execute calls.
  // Only names actually inserted after duplicate resolution are dispatched.
  final formulaToolNames = <String>{};
  List<Map<String, dynamic>> kimiFormulaTools = const <Map<String, dynamic>>[];
  final builtInSearchEnabled = builtInTools(
    config,
    modelId,
  ).contains(BuiltInToolNames.search);
  if (config.useResponseApi != true &&
      BuiltInToolsHelper.isMoonshotProvider(config) &&
      BuiltInToolsHelper.isKimiK3Model(upstreamModelId) &&
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
  if (config.useResponseApi == true) {
    final input = <Map<String, dynamic>>[];
    // Extract system messages into `instructions` (Responses API best practice)
    String instructions = '';
    // Prepare tools list for Responses path (may be augmented with built-in web search)
    final List<Map<String, dynamic>> toolList = [];
    if (tools != null && tools.isNotEmpty) {
      for (final t in tools) {
        toolList.add(Map<String, dynamic>.from(t));
      }
    }

    void addResponsesBuiltInTool(Map<String, dynamic> entry) {
      final type = (entry['type'] ?? '').toString();
      if (type.isEmpty) return;
      final exists = toolList.any((e) => (e['type'] ?? '').toString() == type);
      if (!exists) toolList.add(entry);
    }

    final builtInPayload = BuiltInToolsHelper.buildResponsesTools(
      cfg: config,
      modelId: modelId,
      upstreamModelId: upstreamModelId,
      configuredTools: configuredBuiltInTools,
    );
    for (final tool in builtInPayload.tools) {
      addResponsesBuiltInTool(tool);
    }
    // Collect assistant images to attach to the last user message.
    // Use last *user* index so tool follow-ups still receive stashed media.
    final List<String> lastAssistantImageUrls = <String>[];
    int lastResponsesUserIndex = -1;
    for (int i = messages.length - 1; i >= 0; i--) {
      if ((messages[i]['role'] ?? '').toString() == 'user') {
        lastResponsesUserIndex = i;
        break;
      }
    }
    for (int i = 0; i < messages.length; i++) {
      final m = messages[i];
      final originalContent = m['content'];
      final raw = originalContent is List
          ? textFromContentParts(originalContent)
          : (originalContent ?? '').toString();
      final roleRaw = (m['role'] ?? 'user').toString();

      // Responses API supports a top-level `instructions` field that has higher priority
      if (roleRaw == 'system') {
        if (raw.isNotEmpty) {
          instructions = instructions.isEmpty ? raw : ('$instructions\n\n$raw');
        }
        continue;
      }

      // Handle tool result messages (role: 'tool') - convert to function_call_output format
      if (roleRaw == 'tool') {
        final toolCallId = (m['tool_call_id'] ?? '').toString();
        final content = (m['content'] ?? '').toString();
        if (toolCallId.isNotEmpty) {
          input.add({
            'type': 'function_call_output',
            'call_id': toolCallId,
            'output': content,
          });
        }
        continue;
      }

      final isAssistant = roleRaw == 'assistant';

      // Handle assistant messages with tool_calls - convert to function_call format
      if (isAssistant && m['tool_calls'] is List) {
        final toolCalls = m['tool_calls'] as List;
        for (final tc in toolCalls) {
          if (tc is! Map) continue;
          final callId = (tc['id'] ?? '').toString();
          final fn = tc['function'];
          if (fn is! Map) continue;
          final name = (fn['name'] ?? '').toString();
          final arguments = (fn['arguments'] ?? '{}').toString();
          if (callId.isNotEmpty && name.isNotEmpty) {
            input.add({
              'type': 'function_call',
              'call_id': callId,
              'name': name,
              'arguments': arguments,
            });
          }
        }
        // Skip adding the assistant message content if it only contains tool calls
        if (raw.trim().isEmpty || raw.trim() == '\n\n') continue;
      }

      // Only parse images if there are images to process.
      // Semantic media detection only - custom attachment markers are not
      // recognized. Attachments arrive via structured media-path keys /
      // userImagePaths, plus Markdown ![](...).
      final hasMarkdownImages = shouldParseMarkdownImages(
        raw,
        skipImageParsing: skipImageParsing,
      );
      final internalMediaRefs = parseInternalMediaRefs(
        m[multimodalInternalMediaPathsKey],
      );
      // Consume injected media refs for user and assistant history turns.
      final hasInternalMedia = canImageInput && internalMediaRefs.isNotEmpty;
      final hasAttachedImages =
          canImageInput &&
          (m['role'] == 'user') &&
          i == lastResponsesUserIndex &&
          (userImagePaths?.isNotEmpty == true);
      // For the last user message, also attach the last assistant image if available
      final shouldAttachAssistantImage =
          canImageInput &&
          (m['role'] == 'user') &&
          i == lastResponsesUserIndex &&
          lastAssistantImageUrls.isNotEmpty;

      if (hasMarkdownImages ||
          hasAttachedImages ||
          hasInternalMedia ||
          shouldAttachAssistantImage) {
        final parsed = await parseTextAndImages(
          raw,
          allowRemoteImages: allowRemoteImages,
          allowLocalImages: canImageInput,
          allowDataImages: canImageInput,
          keepRemoteMarkdownText: true,
          keepDisallowedImageText: canImageInput,
          skipImageParsing: skipImageParsing,
        );
        if (!canImageInput) {
          if (isAssistant) {
            input.add({
              'type': 'message',
              'role': 'assistant',
              'status': 'completed',
              'content': [
                {'type': 'output_text', 'text': parsed.text},
              ],
            });
          } else {
            input.add({'role': roleRaw, 'content': parsed.text});
          }
          continue;
        }

        final parts = <Map<String, dynamic>>[];
        final seenImageSources = <String>{};
        final seenImageUrls = <String>{};
        String normalizeSrc(String src) {
          if (src.startsWith('http') || src.startsWith('data:')) return src;
          try {
            return SandboxPathResolver.fix(src);
          } catch (_) {
            return src;
          }
        }

        void addImage(String url) {
          if (url.isEmpty) return;
          if (!allowRemoteImages && isRemoteHttpUrl(url)) return;
          if (seenImageUrls.add(url)) {
            parts.add({'type': 'input_image', 'image_url': url});
          }
        }

        if (parsed.text.isNotEmpty) {
          // Use output_text for assistant, input_text for user
          parts.add({
            'type': isAssistant ? 'output_text' : 'input_text',
            'text': parsed.text,
          });
        }
        // Images extracted from this message's text
        for (final ref in parsed.images) {
          final normalized = normalizeSrc(ref.src);
          if (!seenImageSources.add(normalized)) continue;
          final String? url;
          if (ref.kind == 'data') {
            url = ref.src;
          } else if (ref.kind == 'path') {
            url = await tryEncodeBase64DataUrl(ref.src);
            if (url == null) continue;
          } else {
            url = ref.src; // http(s)
          }
          // For assistant messages, collect images; for user messages, add directly
          if (isAssistant) {
            if (!lastAssistantImageUrls.contains(url)) {
              lastAssistantImageUrls.add(url);
            }
          } else {
            addImage(url);
          }
        }
        // Structured / attached media refs (user + assistant history turns)
        final supplementalRefs = supplementalMediaRefs(
          internalRaw: m[multimodalInternalMediaPathsKey],
          userPaths: userImagePaths,
          includeUserPaths: hasAttachedImages,
        );
        for (final mediaRef in supplementalRefs) {
          final p = mediaRef.uri;
          final String mime = mimeForInternalMediaRef(mediaRef);
          final bool isAv = isAudioMime(mime) || isVideoMime(mime);
          if (isAv) {
            // Responses path has no first-class A/V input parts here; never
            // encode video/audio as input_image. Keep a text reference for both
            // remote and local paths so pure A/V attachments do not become
            // content: [] (API reject / silent drop).
            final normalized = normalizeSrc(p);
            if (seenImageSources.add(normalized)) {
              parts.add({
                'type': isAssistant ? 'output_text' : 'input_text',
                'text': p,
              });
            }
            continue;
          }
          if (!allowRemoteImages && isRemoteHttpUrl(p)) {
            // Keep the remote reference visible as text when image embed is off.
            final normalized = normalizeSrc(p);
            if (!seenImageSources.add(normalized)) continue;
            parts.add({
              'type': isAssistant ? 'output_text' : 'input_text',
              'text': p,
            });
            continue;
          }
          final normalized = normalizeSrc(p);
          if (!seenImageSources.add(normalized)) continue;
          final dataUrl = (isRemoteHttpUrl(p) || p.startsWith('data:'))
              ? p
              : await tryEncodeBase64DataUrl(p, explicitMime: mediaRef.mime);
          if (dataUrl == null) continue;
          // Assistant Responses messages may only contain output_text/refusal.
          // Mirror the markdown path: stash for the following user turn.
          if (isAssistant) {
            if (!lastAssistantImageUrls.contains(dataUrl)) {
              lastAssistantImageUrls.add(dataUrl);
            }
          } else {
            addImage(dataUrl);
          }
        }
        // Attach all stashed assistant images to the last user message
        if (shouldAttachAssistantImage) {
          for (final url in lastAssistantImageUrls) {
            addImage(url);
          }
        }
        // Use proper message object format for assistant messages
        if (isAssistant) {
          // Never emit input_image inside assistant completed output.
          final assistantContent = <Map<String, dynamic>>[
            for (final part in parts)
              if (part['type'] == 'output_text' || part['type'] == 'refusal')
                part,
          ];
          if (assistantContent.isEmpty) {
            assistantContent.add({'type': 'output_text', 'text': parsed.text});
          }
          input.add({
            'type': 'message',
            'role': 'assistant',
            'status': 'completed',
            'content': assistantContent,
          });
        } else {
          input.add({'role': roleRaw, 'content': parts});
        }
      } else {
        // No images
        if (isAssistant) {
          // Use proper message object format for assistant messages
          input.add({
            'type': 'message',
            'role': 'assistant',
            'status': 'completed',
            'content': [
              {'type': 'output_text', 'text': raw},
            ],
          });
        } else {
          input.add({'role': roleRaw, 'content': raw});
        }
      }
    }
    body = {
      'model': upstreamModelId,
      'input': input,
      'stream': stream,
      if (instructions.isNotEmpty) 'instructions': instructions,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (maxTokens != null) 'max_output_tokens': maxTokens,
      if (toolList.isNotEmpty) 'tools': toResponsesToolsFormat(toolList),
      if (toolList.isNotEmpty) 'tool_choice': 'auto',
      if (isReasoning && effort != 'off')
        'reasoning': {
          'summary': 'auto',
          if (effort != 'auto') 'effort': effort,
        },
    };
    applyCompatibleResponsesReasoning(
      body,
      config: config,
      modelId: modelId,
      upstreamModelId: upstreamModelId,
      isReasoning: isReasoning,
      thinkingBudget: thinkingBudget,
    );
    // OpenAI-compatible native search can optionally expose source details.
    // OpenRouter rejects the `include` parameter, so skip it there.
    if (!BuiltInToolsHelper.isDashScopeProvider(config) &&
        !BuiltInToolsHelper.isOpenRouterProvider(config)) {
      try {
        final ov = config.modelOverrides[modelId];
        final ws = (ov is Map ? ov['webSearch'] : null);
        if (ws is Map && ws['include_sources'] == true) {
          body['include'] = ['web_search_call.action.sources'];
        }
      } catch (_) {}
    }
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
      canImageInput: canImageInput,
      allowRemoteImages: allowRemoteImages,
      reasoningContentReplayPolicy: info.reasoningContentReplayPolicy,
      supportsGoogleOpenAIThoughtSignatures:
          info.supportsGoogleOpenAIThoughtSignatures,
      stripReasoningContent: isClaudeUpstream,
      normalizeReasoningDetails: isClaudeUpstream,
      skipImageParsing: skipImageParsing,
    );
    body = {
      'model': upstreamModelId,
      'messages': mm,
      'stream': stream,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (isReasoning && effort != 'off' && effort != 'auto')
        'reasoning_effort': effort,
      if (tools != null && tools.isNotEmpty)
        'tools': cleanToolsForCompatibility(tools),
      if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
    };
    setMaxTokens(body);
  }

  // Vendor-specific reasoning knobs for chat-completions compatible hosts
  if (config.useResponseApi != true) {
    applyVendorReasoningKnobs(
      body,
      info: info,
      isReasoning: isReasoning,
      thinkingBudget: thinkingBudget,
    );
    if (info.isKimiThinkingModel) {
      normalizeMoonshotKimiChatBody(
        body,
        upstreamModelId: upstreamModelId,
        isReasoning: isReasoning,
        thinkingBudget: thinkingBudget,
      );
    }
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
  maybeAddStreamingUsageOptions(
    body,
    stream: stream,
    config: config,
    host: info.host,
  );
  if (config.useResponseApi != true) {
    formulaToolNames.addAll(
      KimiFormulaSearch.mergeTools(body, kimiFormulaTools),
    );
  }
  applyOpenRouterClaudePromptCaching(
    body,
    config: config,
    upstreamModelId: upstreamModelId,
  );

  // Merge custom body keys (override takes precedence)
  final extraBodyCfg = customBody(config, modelId, assistantBody: extraBody);
  if (extraBodyCfg.isNotEmpty) {
    body.addAll(extraBodyCfg);
  }
  // Built-in tools run after the custom body and merge by type so custom
  // function tools and provider server tools coexist.
  if (config.useResponseApi != true) {
    applyChatCompletionsBuiltInTools(
      body,
      config: config,
      modelId: modelId,
      upstreamModelId: upstreamModelId,
      configuredTools: configuredBuiltInTools,
    );
  }
  sanitizeOpenAIGpt5SamplingParams(
    body,
    upstreamModelId,
    fallbackEffort: effort,
    isOpenRouter: info.isOpenRouter,
  );
  normalizeMoonshotKimiChatBody(
    body,
    upstreamModelId: upstreamModelId,
    isReasoning: isReasoning,
    thinkingBudget: thinkingBudget,
  );
  request.body = jsonEncode(body);

  final response = await client.send(request);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    final errorBody = await response.stream.bytesToString();
    throw HttpException('HTTP ${response.statusCode}: $errorBody');
  }

  // Non-streaming path: parse one-shot JSON and optionally follow tool calls.
  if (!stream) {
    final txt = await decodeUtf8Stream(response.stream);
    try {
      final obj = jsonDecode(txt);
      // Responses API non-stream
      if (config.useResponseApi == true) {
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
        yield* emitDone(
          ids: ids,
          content: outText,
          reasoning: reasoningText.isEmpty ? null : reasoningText,
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
          info: info,
          messages: messages,
          requestBody: body,
          firstObj: lastObj,
          initialCalls: firstCalls,
          onToolCall: effectiveOnToolCall,
          userImagePaths: userImagePaths,
          canImageInput: canImageInput,
          allowRemoteImages: allowRemoteImages,
          skipImageParsing: skipImageParsing,
          isClaudeUpstream: isClaudeUpstream,
          needsReasoningEcho: needsReasoningEcho,
          extraHeaders: extraHeaders,
          initialUsage: firstUsage,
        );
        return;
      }
      final visible = openaiVisibleOutputFromMessage(
        (firstChoice['message'] as Map?)?.cast<String, dynamic>(),
      );
      final firstMessage = openaiFirstChoiceMessage(lastObj);
      final ids = StreamChunkIds('finish');
      yield* emitImages(visible.images, ids: ids);
      yield* emitDone(
        ids: ids,
        content: visible.content,
        reasoning: openaiReasoningText(firstMessage),
        reasoningDetails: firstMessage?['reasoning_details'],
        usage: firstUsage,
        totalTokens: firstUsage?.totalTokens ?? 0,
        finishReason: (firstChoice['finish_reason'] ?? '').toString().isEmpty
            ? null
            : firstChoice['finish_reason'].toString(),
      );
      return;
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
  final reasoningDetailsBuffer = _ReasoningDetailsAccumulator(
    allowSnapshots: reasoningDetailsAllowSnapshots,
  );
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
  String? finishReason;
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
            client: client,
            config: config,
            modelId: modelId,
            upstreamModelId: upstreamModelId,
            url: url,
            info: info,
            initialInput: responsesInitialInput,
            firstOutputItems: lastResponseOutputItems,
            initialCalls: callInfos,
            responsesToolsSpec: responsesToolsSpec,
            responsesInstructions: responsesInstructions,
            responsesIncludeParam: responsesIncludeParam,
            onToolCall: effectiveOnToolCall,
            extraHeaders: extraHeaders,
            extraBody: extraBody,
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens,
            isReasoning: isReasoning,
            effort: effort,
            thinkingBudget: thinkingBudget,
            initialUsage: usage,
            streamRound: streamRound,
            approxPromptTokens: approxPromptTokens,
            approxCompletionChars: approxCompletionChars,
          );
          return;
        }

        final approxTotal =
            approxPromptTokens + approxTokensFromChars(approxCompletionChars);
        yield* emitDone(
          ids: StreamChunkIds('finish'),
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
        finishReason = decoder.finishReason;
        usage = decoder.usage ?? usage;
        if (usage != null) totalTokens = usage.totalTokens;
        approxCompletionChars = decoder.approxCompletionChars;
        reasoningBuffer = decoder.reasoningEcho;
        assistantContentBuffer = decoder.assistantContent;
        if (data == '[DONE]') {
          for (final chunk in decoder.onClosed()) {
            yield chunk;
          }
          if (effectiveOnToolCall != null && toolAcc.isNotEmpty) {
            yield* runOpenAIChatCompletionsToolFollowUps(
              client: client,
              config: config,
              modelId: modelId,
              upstreamModelId: upstreamModelId,
              url: url,
              info: info,
              messages: messages,
              firstToolAcc: toolAcc,
              firstAssistantContent: assistantContentBuffer,
              firstReasoning: reasoningBuffer,
              firstReasoningDetails:
                  decoder.reasoningDetails ??
                  reasoningDetailsBuffer.detailsOrNull,
              onToolCall: effectiveOnToolCall,
              userImagePaths: userImagePaths,
              canImageInput: canImageInput,
              allowRemoteImages: allowRemoteImages,
              skipImageParsing: skipImageParsing,
              isClaudeUpstream: isClaudeUpstream,
              isReasoning: isReasoning,
              effort: effort,
              thinkingBudget: thinkingBudget,
              temperature: temperature,
              topP: topP,
              tools: tools,
              extraBodyCfg: extraBodyCfg,
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
            );
            return;
          }
          final approxTotal =
              approxPromptTokens + approxTokensFromChars(approxCompletionChars);
          yield* emitDone(
            ids: StreamChunkIds('finish'),
            reasoningDetails:
                decoder.reasoningDetails ??
                reasoningDetailsBuffer.detailsOrNull,
            usage: usage,
            totalTokens: usage?.totalTokens ?? approxTotal,
          );
          return;
        }
      }

      // Some providers (e.g., OpenRouter) may omit the [DONE] sentinel
      // and only send finish_reason on the last delta. If we see a
      // definitive finish that's not tool_calls, end the stream now so
      // the UI can persist the message.
      // XinLiu compatibility: Execute tools immediately if we have finish_reason='tool_calls' and accumulated calls
      if (config.useResponseApi != true &&
          finishReason == 'tool_calls' &&
          toolAcc.isNotEmpty &&
          effectiveOnToolCall != null) {
        for (final chunk in chatDecoder.onClosed()) {
          yield chunk;
        }
        yield* runOpenAIChatCompletionsToolFollowUps(
          client: client,
          config: config,
          modelId: modelId,
          upstreamModelId: upstreamModelId,
          url: url,
          info: info,
          messages: messages,
          firstToolAcc: toolAcc,
          firstAssistantContent: assistantContentBuffer,
          firstReasoning: reasoningBuffer,
          firstReasoningDetails:
              chatDecoder.reasoningDetails ??
              reasoningDetailsBuffer.detailsOrNull,
          onToolCall: effectiveOnToolCall,
          userImagePaths: userImagePaths,
          canImageInput: canImageInput,
          allowRemoteImages: allowRemoteImages,
          skipImageParsing: skipImageParsing,
          isClaudeUpstream: isClaudeUpstream,
          isReasoning: isReasoning,
          effort: effort,
          thinkingBudget: thinkingBudget,
          temperature: temperature,
          topP: topP,
          tools: tools,
          extraBodyCfg: extraBodyCfg,
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
        );
        return;
      }
      // XinLiu compatibility: Don't end early if we have accumulated tool calls
      if (config.useResponseApi != true &&
          finishReason != null &&
          finishReason != 'tool_calls') {
        final bool hasPendingToolCalls =
            toolAcc.isNotEmpty || toolAccResp.isNotEmpty;
        final pendingHandler = effectiveOnToolCall;
        if (hasPendingToolCalls && pendingHandler != null) {
          // Some providers (like XinLiu/iflow.cn) may return tool_calls with finish_reason='stop'
          // and may not send a [DONE] marker. Execute tools immediately in this case.
          for (final chunk in chatDecoder.onClosed()) {
            yield chunk;
          }
          yield* runOpenAIChatCompletionsToolFollowUps(
            client: client,
            config: config,
            modelId: modelId,
            upstreamModelId: upstreamModelId,
            url: url,
            info: info,
            messages: messages,
            firstToolAcc: toolAcc,
            firstAssistantContent: assistantContentBuffer,
            firstReasoning: reasoningBuffer,
            firstReasoningDetails:
                chatDecoder.reasoningDetails ??
                reasoningDetailsBuffer.detailsOrNull,
            onToolCall: pendingHandler,
            userImagePaths: userImagePaths,
            canImageInput: canImageInput,
            allowRemoteImages: allowRemoteImages,
            skipImageParsing: skipImageParsing,
            isClaudeUpstream: isClaudeUpstream,
            isReasoning: isReasoning,
            effort: effort,
            thinkingBudget: thinkingBudget,
            temperature: temperature,
            topP: topP,
            tools: tools,
            extraBodyCfg: extraBodyCfg,
            extraHeaders: extraHeaders,
            wantsImageOutput: wantsImageOutput,
            needsReasoningEcho: needsReasoningEcho,
            reasoningDetailsAllowSnapshots: reasoningDetailsAllowSnapshots,
            applyMaxTokens: setMaxTokens,
            initialUsage: usage,
            streamRound: streamRound,
            approxPromptTokens: approxPromptTokens,
            approxCompletionChars: approxCompletionChars,
            includeReasoningDetailsOnDone: false,
          );
          return;
        }
      }
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

  // Fallback: provider closed SSE without sending [DONE]
  for (final chunk in chatDecoder?.onClosed() ?? const <StreamChunk>[]) {
    yield chunk;
  }
  for (final chunk in responsesDecoder?.onClosed() ?? const <StreamChunk>[]) {
    yield chunk;
  }
  final approxTotal =
      usage?.totalTokens ??
      (approxPromptTokens + approxTokensFromChars(approxCompletionChars));
  yield* emitDone(
    ids: StreamChunkIds('finish'),
    reasoningDetails:
        chatDecoder?.reasoningDetails ?? reasoningDetailsBuffer.detailsOrNull,
    usage: usage,
    totalTokens: approxTotal,
  );
}
