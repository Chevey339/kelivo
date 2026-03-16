part of '../chat_api_service.dart';

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

void _applyCompatibleBuiltInSearch(
  Map<String, dynamic> body, {
  required ProviderConfig config,
  required String modelId,
  required String upstreamModelId,
}) {
  final builtIns = _builtInTools(config, modelId);
  if (!builtIns.contains(BuiltInToolNames.search)) return;

  if (BuiltInToolsHelper.isGrokModel(upstreamModelId)) {
    body['search_parameters'] = {'mode': 'auto', 'return_citations': true};
    return;
  }

  if (config.useResponseApi == true) return;
  if (!BuiltInToolsHelper.isDashScopeProvider(config)) return;
  if (!BuiltInToolsHelper.isDashScopeChatBuiltInSearchSupportedModel(
    upstreamModelId,
  )) {
    return;
  }

  body['enable_search'] = true;
  final options = BuiltInToolsHelper.dashScopeSearchOptionsFromOverride(
    config.modelOverrides[modelId],
  );
  if (options.isNotEmpty) {
    body['search_options'] = options;
  } else {
    body.remove('search_options');
  }
}

void _applyCompatibleResponsesReasoning(
  Map<String, dynamic> body, {
  required ProviderConfig config,
  required String modelId,
  required String upstreamModelId,
  required bool isReasoning,
  int? thinkingBudget,
}) {
  if (config.useResponseApi != true) return;
  if (!BuiltInToolsHelper.isDashScopeProvider(config)) return;

  body.remove('reasoning');
  if (!isReasoning) {
    body.remove('enable_thinking');
    return;
  }

  final builtInSearchEnabled = _builtInTools(
    config,
    modelId,
  ).contains(BuiltInToolNames.search);
  final forceThinkingForQwen3Max =
      builtInSearchEnabled &&
      upstreamModelId.toLowerCase().startsWith('qwen3-max');
  body['enable_thinking'] = forceThinkingForQwen3Max || !_isOff(thinkingBudget);
}

String _openAIEffortForBudget(int? budget, String upstreamModelId) {
  final baseEffort = _effortForBudget(budget);
  final requestedEffort =
      baseEffort == 'high' && budget != null && budget >= 64000
      ? 'xhigh'
      : baseEffort;
  return openAINormalizeReasoningEffort(requestedEffort, upstreamModelId);
}

String _effectiveOpenAIEffort(
  Map<String, dynamic> body, {
  required String fallbackEffort,
}) {
  // Read the effort from the final payload shape first, then fall back to the
  // budget-derived value. Overrides can set either chat-completions style
  // (`reasoning_effort`) or Responses style (`reasoning.effort`).
  final reasoningEffort = body['reasoning_effort'];
  if (reasoningEffort is String && reasoningEffort.trim().isNotEmpty) {
    return reasoningEffort.trim().toLowerCase();
  }
  final reasoning = body['reasoning'];
  if (reasoning is Map) {
    final effort = reasoning['effort'];
    if (effort is String && effort.trim().isNotEmpty) {
      return effort.trim().toLowerCase();
    }
  }
  return fallbackEffort.toLowerCase();
}

bool _allowsSamplingParamsForOpenAIModel(
  String upstreamModelId, {
  required String effort,
}) {
  // Source: https://developers.openai.com/api/docs/guides/latest-model#gpt-54-parameter-compatibility
  // Only the documented GPT-5.2 / GPT-5.4 base-model compatibility rules are
  // enforced here; other GPT-5 variants keep their request body unchanged.
  return openAIAllowsSamplingParams(upstreamModelId, effort: effort);
}

void _sanitizeOpenAIGpt5SamplingParams(
  Map<String, dynamic> body,
  String upstreamModelId, {
  required String fallbackEffort,
}) {
  // Must run on the final request body (after override merges), otherwise
  // we may keep/drop sampling params based on stale effort assumptions.
  if (!body.containsKey('temperature') &&
      !body.containsKey('top_p') &&
      !body.containsKey('logprobs')) {
    return;
  }
  final effort = _effectiveOpenAIEffort(body, fallbackEffort: fallbackEffort);
  final allowed = _allowsSamplingParamsForOpenAIModel(
    upstreamModelId,
    effort: effort,
  );
  if (!allowed) {
    body.remove('temperature');
    body.remove('top_p');
    body.remove('logprobs');
  }
}

bool _isLongCatHost(String baseUrl) {
  final host =
      Uri.tryParse(baseUrl)?.host.toLowerCase() ?? baseUrl.toLowerCase();
  return host.contains('longcat');
}

bool _shouldUseLongCatOmniPayload(
  ProviderConfig config,
  String upstreamModelId,
) {
  return config.useResponseApi != true && isLongCatOmniModelId(upstreamModelId);
}

bool _shouldIncludeStreamingUsageOptions(
  String host, {
  required String upstreamModelId,
}) {
  if (isLongCatOmniModelId(upstreamModelId) || _isLongCatHost(host)) {
    return false;
  }
  return !host.contains('mistral.ai') && !host.contains('openrouter');
}

void _maybeAddStreamingUsageOptions(
  Map<String, dynamic> body, {
  required bool stream,
  required ProviderConfig config,
  required String host,
  required String upstreamModelId,
}) {
  if (!stream || config.useResponseApi == true) return;
  if (_shouldIncludeStreamingUsageOptions(
    host,
    upstreamModelId: upstreamModelId,
  )) {
    body['stream_options'] = {'include_usage': true};
  }
}

String _stripDataUrlPrefix(String dataUrl) {
  final commaIndex = dataUrl.indexOf(',');
  if (commaIndex >= 0 && commaIndex + 1 < dataUrl.length) {
    return dataUrl.substring(commaIndex + 1);
  }
  return dataUrl;
}

String? _longCatAudioFormatForMimeOrPath(String source, {String? mime}) {
  final normalizedMime = (mime ?? '').toLowerCase();
  final normalizedSource = source.toLowerCase();
  if (normalizedMime.contains('mpeg') || normalizedSource.endsWith('.mp3')) {
    return 'mp3';
  }
  if (normalizedMime.contains('wav') || normalizedSource.endsWith('.wav')) {
    return 'wav';
  }
  if (normalizedMime.endsWith('pcm16') || normalizedSource.endsWith('.pcm16')) {
    return 'pcm16';
  }
  if (normalizedMime.endsWith('/pcm') || normalizedSource.endsWith('.pcm')) {
    return 'pcm';
  }
  return null;
}

String _normalizeOpenAICompatibleSource(String src) {
  if (src.startsWith('http://') ||
      src.startsWith('https://') ||
      src.startsWith('data:')) {
    return src;
  }
  try {
    return SandboxPathResolver.fix(src);
  } catch (_) {
    return src;
  }
}

Future<Map<String, dynamic>?> _buildLongCatOmniAttachmentPart(
  String source,
) async {
  final normalized = source.trim();
  if (normalized.isEmpty) return null;

  final bool isRemoteUrl =
      normalized.startsWith('http://') || normalized.startsWith('https://');
  final bool isDataUrl = normalized.startsWith('data:');
  final String mime = isDataUrl
      ? _mimeFromDataUrl(normalized)
      : _mimeFromPath(normalized);

  if (isAudioMime(mime)) {
    final format = _longCatAudioFormatForMimeOrPath(normalized, mime: mime);
    if (format == null) return null;
    final data = isRemoteUrl
        ? normalized
        : isDataUrl
        ? _stripDataUrlPrefix(normalized)
        : await _encodeBase64File(normalized, withPrefix: false);
    return {
      'type': 'input_audio',
      'input_audio': {
        'type': isRemoteUrl ? 'url' : 'base64',
        'data': data,
        'format': format,
        if (format == 'pcm16') 'sample_rate': 16000,
      },
    };
  }

  if (isVideoMime(mime)) {
    final data = isRemoteUrl
        ? normalized
        : isDataUrl
        ? _stripDataUrlPrefix(normalized)
        : await _encodeBase64File(normalized, withPrefix: false);
    return {
      'type': 'input_video',
      'input_video': {'type': isRemoteUrl ? 'url' : 'base64', 'data': data},
    };
  }

  final imageData = <String>[
    isRemoteUrl
        ? normalized
        : isDataUrl
        ? _stripDataUrlPrefix(normalized)
        : await _encodeBase64File(normalized, withPrefix: false),
  ];
  return {
    'type': 'input_image',
    'input_image': {'type': isRemoteUrl ? 'url' : 'base64', 'data': imageData},
  };
}

Future<List<Map<String, dynamic>>> _buildLongCatOmniMessages(
  List<Map<String, dynamic>> messages, {
  List<String>? userMediaPaths,
}) async {
  int lastUserIndex = -1;
  for (int i = messages.length - 1; i >= 0; i--) {
    if ((messages[i]['role'] ?? '').toString() == 'user') {
      lastUserIndex = i;
      break;
    }
  }

  final out = <Map<String, dynamic>>[];
  for (int i = 0; i < messages.length; i++) {
    final original = messages[i];
    final role = (original['role'] ?? 'user').toString();
    final raw = (original['content'] ?? '').toString();
    final outMsg = Map<String, dynamic>.from(original);
    outMsg.remove(multimodalInternalMediaPathsKey);
    outMsg['role'] = role;
    final internalMediaPaths =
        (original[multimodalInternalMediaPathsKey] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];

    if (role == 'system') {
      outMsg['content'] = <Map<String, dynamic>>[
        {'type': 'text', 'text': raw},
      ];
      out.add(outMsg);
      continue;
    }

    if (role == 'tool' ||
        (role == 'assistant' &&
            outMsg['tool_calls'] is List &&
            (outMsg['tool_calls'] as List).isNotEmpty)) {
      outMsg['content'] = raw;
      out.add(outMsg);
      continue;
    }

    if (role == 'assistant') {
      outMsg['content'] = <Map<String, dynamic>>[
        {'type': 'text', 'text': raw},
      ];
      out.add(outMsg);
      continue;
    }

    final parsed = await _parseTextAndImages(
      raw,
      allowRemoteImages: true,
      allowLocalImages: true,
      keepRemoteMarkdownText: true,
    );
    final parts = <Map<String, dynamic>>[];
    final seenSources = <String>{};

    if (parsed.text.isNotEmpty) {
      parts.add({'type': 'text', 'text': parsed.text});
    }

    for (final ref in parsed.images) {
      final normalized = _normalizeOpenAICompatibleSource(ref.src);
      if (!seenSources.add(normalized)) continue;
      final source = ref.kind == 'path' ? normalized : ref.src;
      final part = await _buildLongCatOmniAttachmentPart(source);
      if (part != null) {
        parts.add(part);
      }
    }

    final supplementalMediaPaths = <String>[
      ...internalMediaPaths,
      if (i == lastUserIndex && userMediaPaths != null) ...userMediaPaths,
    ];
    for (final path in supplementalMediaPaths) {
      final normalized = _normalizeOpenAICompatibleSource(path);
      if (!seenSources.add(normalized)) continue;
      final part = await _buildLongCatOmniAttachmentPart(normalized);
      if (part != null) {
        parts.add(part);
      }
    }

    if (parts.isEmpty) {
      parts.add({'type': 'text', 'text': raw});
    }

    outMsg['content'] = parts;
    out.add(outMsg);
  }
  return out;
}

String _extractOpenAICompatibleDeltaText(Map? delta) {
  if (delta == null) return '';
  final deltaType = (delta['type'] ?? '').toString();
  if (deltaType == 'response.audio.delta') {
    return '';
  }
  final content = delta['content'];
  if (content is String) {
    return content;
  }
  if (content is List) {
    final buffer = StringBuffer();
    for (final item in content) {
      if (item is! Map) continue;
      final text = (item['text'] ?? item['delta'] ?? '').toString();
      final type = (item['type'] ?? '').toString();
      if (text.isEmpty) continue;
      if (type.isEmpty || type == 'text') {
        buffer.write(text);
      }
    }
    return buffer.toString();
  }
  return '';
}

Stream<ChatStreamChunk> _sendOpenAIStream(
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
}) async* {
  final upstreamModelId = _apiModelId(config, modelId);
  final url = _openAICompatibleUrl(config);

  final effectiveInfo = _effectiveModelInfo(config, modelId);
  final isReasoning = effectiveInfo.abilities.contains(ModelAbility.reasoning);
  final wantsImageOutput = effectiveInfo.output.contains(Modality.image);
  final bool canImageInput = effectiveInfo.input.contains(Modality.image);

  final effort = _openAIEffortForBudget(thinkingBudget, upstreamModelId);
  final host = Uri.tryParse(config.baseUrl)?.host.toLowerCase() ?? '';
  final modelLower = upstreamModelId.toLowerCase();
  final bool isAzureOpenAI = host.contains('openai.azure.com');
  final bool isMimoHost = host.contains('xiaomimimo');
  final bool isMimoModel =
      modelLower.startsWith('mimo-') || modelLower.contains('/mimo-');
  final bool isMimo = isMimoHost || isMimoModel;
  final bool useLongCatOmniPayload = _shouldUseLongCatOmniPayload(
    config,
    upstreamModelId,
  );
  final bool needsReasoningEcho =
      (host.contains('deepseek') ||
          modelLower.contains('deepseek') ||
          isMimo ||
          modelLower.contains('kimi-k2.5')) &&
      isReasoning;
  // OpenRouter reasoning models require preserving `reasoning_details` across tool-calling turns.
  final bool preserveReasoningDetails =
      host.contains('openrouter.ai') && isReasoning;
  final String completionTokensKey = (isAzureOpenAI || isMimo)
      ? 'max_completion_tokens'
      : 'max_tokens';
  void setMaxTokens(Map<String, dynamic> map) {
    if (maxTokens != null) map[completionTokensKey] = maxTokens;
  }

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

    final builtIns = _builtInTools(config, modelId);
    void addResponsesBuiltInTool(Map<String, dynamic> entry) {
      final type = (entry['type'] ?? '').toString();
      if (type.isEmpty) return;
      final exists = toolList.any((e) => (e['type'] ?? '').toString() == type);
      if (!exists) toolList.add(entry);
    }

    // OpenAI built-in tools (Responses API)
    if (builtIns.contains(BuiltInToolNames.codeInterpreter)) {
      addResponsesBuiltInTool({
        'type': 'code_interpreter',
        'container': {'type': 'auto', 'memory_limit': '4g'},
      });
    }
    if (builtIns.contains(BuiltInToolNames.imageGeneration)) {
      addResponsesBuiltInTool({'type': 'image_generation'});
    }

    // Built-in web search for Responses API when enabled on supported models
    bool isResponsesWebSearchSupported(String id) {
      if (BuiltInToolsHelper.isOpenAIResponsesBuiltInSearchSupportedModel(id)) {
        return true;
      }
      if (BuiltInToolsHelper.isDashScopeProvider(config)) {
        return BuiltInToolsHelper.isDashScopeResponsesBuiltInSearchSupportedModel(
          id,
        );
      }
      return false;
    }

    if (isResponsesWebSearchSupported(upstreamModelId)) {
      if (builtIns.contains(BuiltInToolNames.search)) {
        if (BuiltInToolsHelper.isDashScopeProvider(config)) {
          addResponsesBuiltInTool({'type': 'web_search'});
        } else {
          // Optional per-model configuration under modelOverrides[modelId]['webSearch']
          Map<String, dynamic> ws = const <String, dynamic>{};
          try {
            final ov = config.modelOverrides[modelId];
            if (ov is Map && ov['webSearch'] is Map) {
              ws = (ov['webSearch'] as Map).cast<String, dynamic>();
            }
          } catch (_) {}
          final usePreview =
              (ws['preview'] == true) ||
              ((ws['tool'] ?? '').toString() == 'preview');
          final entry = <String, dynamic>{
            'type': usePreview ? 'web_search_preview' : 'web_search',
          };
          // Domain filters
          if (ws['allowed_domains'] is List &&
              (ws['allowed_domains'] as List).isNotEmpty) {
            entry['filters'] = {
              'allowed_domains': List<String>.from(
                (ws['allowed_domains'] as List).map((e) => e.toString()),
              ),
            };
          }
          // User location
          if (ws['user_location'] is Map) {
            entry['user_location'] = (ws['user_location'] as Map)
                .cast<String, dynamic>();
          }
          // Search context size (preview tool only)
          if (usePreview && ws['search_context_size'] is String) {
            entry['search_context_size'] = ws['search_context_size'];
          }
          addResponsesBuiltInTool(entry);
          // Optionally request sources in output
          if (ws['include_sources'] == true) {
            // Merge/append include array
            // We'll add this after input loop when building body
          }
        }
      }
    }
    // Collect the last assistant image to attach to the new user message
    String? lastAssistantImageUrl;
    for (int i = 0; i < messages.length; i++) {
      final m = messages[i];
      final isLast = i == messages.length - 1;
      final raw = (m['content'] ?? '').toString();
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

      // Only parse images if there are images to process
      final hasMarkdownImages = raw.contains('![') && raw.contains('](');
      final hasCustomImages = raw.contains('[image:');
      final hasAttachedImages =
          isLast &&
          (userImagePaths?.isNotEmpty == true) &&
          (m['role'] == 'user');
      // For the last user message, also attach the last assistant image if available
      final shouldAttachAssistantImage =
          isLast && (m['role'] == 'user') && lastAssistantImageUrl != null;

      if (hasMarkdownImages ||
          hasCustomImages ||
          hasAttachedImages ||
          shouldAttachAssistantImage) {
        final parsed = await _parseTextAndImages(
          raw,
          allowRemoteImages: canImageInput,
          allowLocalImages: true,
          keepRemoteMarkdownText: true,
        );
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
          String url;
          if (ref.kind == 'data') {
            url = ref.src;
          } else if (ref.kind == 'path') {
            url = await _encodeBase64File(ref.src, withPrefix: true);
          } else {
            url = ref.src; // http(s)
          }
          // For assistant messages, collect the last image; for user messages, add directly
          if (isAssistant) {
            lastAssistantImageUrl = url;
          } else {
            addImage(url);
          }
        }
        // Additional images explicitly attached to the last user message
        if (hasAttachedImages) {
          for (final p in userImagePaths!) {
            final normalized = normalizeSrc(p);
            if (!seenImageSources.add(normalized)) continue;
            final dataUrl = (p.startsWith('http') || p.startsWith('data:'))
                ? p
                : await _encodeBase64File(p, withPrefix: true);
            addImage(dataUrl);
          }
        }
        // Attach last assistant image to the last user message
        if (shouldAttachAssistantImage && lastAssistantImageUrl != null) {
          addImage(lastAssistantImageUrl);
        }
        // Use proper message object format for assistant messages
        if (isAssistant) {
          input.add({
            'type': 'message',
            'role': 'assistant',
            'status': 'completed',
            'content': parts,
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
      if (toolList.isNotEmpty) 'tools': _toResponsesToolsFormat(toolList),
      if (toolList.isNotEmpty) 'tool_choice': 'auto',
      if (isReasoning && effort != 'off')
        'reasoning': {
          'summary': 'auto',
          if (effort != 'auto') 'effort': effort,
        },
    };
    _applyCompatibleResponsesReasoning(
      body,
      config: config,
      modelId: modelId,
      upstreamModelId: upstreamModelId,
      isReasoning: isReasoning,
      thinkingBudget: thinkingBudget,
    );
    // Append include parameter if we opted into sources via overrides
    if (!BuiltInToolsHelper.isDashScopeProvider(config)) {
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
    if (useLongCatOmniPayload) {
      body = {
        'model': upstreamModelId,
        'messages': await _buildLongCatOmniMessages(
          messages,
          userMediaPaths: userImagePaths,
        ),
        'stream': stream,
        'output_modalities': const ['text'],
        if (temperature != null) 'temperature': temperature,
        if (topP != null) 'top_p': topP,
        if (isReasoning && effort != 'off' && effort != 'auto')
          'reasoning_effort': effort,
        if (tools != null && tools.isNotEmpty)
          'tools': _cleanToolsForCompatibility(tools),
        if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
      };
    } else {
      final mm = <Map<String, dynamic>>[];
      for (int i = 0; i < messages.length; i++) {
        final m = messages[i];
        final isLast = i == messages.length - 1;
        final raw = (m['content'] ?? '').toString();
        final role = (m['role'] ?? 'user').toString();
        final outMsg = Map<String, dynamic>.from(m);
        outMsg.remove(multimodalInternalMediaPathsKey);
        outMsg['role'] = role;

        // System 消息保持为纯文本，不解析为图片
        if (role == 'system') {
          outMsg['content'] = raw;
          mm.add(outMsg);
          continue;
        }

        // Tool / tool_calls messages must preserve tool-specific fields (tool_call_id / tool_calls / name).
        // Also do not convert tool output to multimodal parts, as many OpenAI-compatible backends require tool content to be a string.
        if (role == 'tool' ||
            (role == 'assistant' &&
                outMsg['tool_calls'] is List &&
                (outMsg['tool_calls'] as List).isNotEmpty)) {
          outMsg['content'] = raw;
          mm.add(outMsg);
          continue;
        }

        // Only parse images if there are images to process
        final hasMarkdownImages = raw.contains('![') && raw.contains('](');
        final hasCustomImages = raw.contains('[image:');
        final hasAttachedImages =
            isLast && (userImagePaths?.isNotEmpty == true) && (role == 'user');

        if (hasMarkdownImages || hasCustomImages || hasAttachedImages) {
          final parsed = await _parseTextAndImages(
            raw,
            allowRemoteImages: canImageInput,
            allowLocalImages: true,
            keepRemoteMarkdownText: true,
          );
          final parts = <Map<String, dynamic>>[];
          final seenSources = <String>{};
          final seenImageUrls = <String>{};
          final seenVideoUrls = <String>{};
          String normalizeSrc(String src) {
            if (src.startsWith('http') || src.startsWith('data:')) return src;
            try {
              return SandboxPathResolver.fix(src);
            } catch (_) {
              return src;
            }
          }

          void addImageUrl(String url) {
            if (url.isEmpty) return;
            if (seenImageUrls.add(url)) {
              parts.add({
                'type': 'image_url',
                'image_url': {'url': url},
              });
            }
          }

          void addVideoUrl(String url) {
            if (url.isEmpty) return;
            if (seenVideoUrls.add(url)) {
              parts.add({
                'type': 'video_url',
                'video_url': {'url': url},
              });
            }
          }

          if (parsed.text.isNotEmpty) {
            parts.add({'type': 'text', 'text': parsed.text});
          }
          for (final ref in parsed.images) {
            final normalized = normalizeSrc(ref.src);
            if (!seenSources.add(normalized)) continue;
            String url;
            if (ref.kind == 'data') {
              url = ref.src;
            } else if (ref.kind == 'path') {
              url = await _encodeBase64File(ref.src, withPrefix: true);
            } else {
              url = ref.src;
            }
            addImageUrl(url);
          }
          if (hasAttachedImages) {
            for (final p in userImagePaths!) {
              final normalized = normalizeSrc(p);
              if (!seenSources.add(normalized)) continue;
              final bool isInlineUrl =
                  p.startsWith('http') || p.startsWith('data:');
              final String mime = isInlineUrl
                  ? _mimeFromDataUrl(p)
                  : _mimeFromPath(p);
              if (isAudioMime(mime)) continue;
              final bool isVideo = isVideoMime(mime);
              final String dataUrl = isInlineUrl
                  ? p
                  : await _encodeBase64File(p, withPrefix: true);
              if (isVideo) {
                addVideoUrl(dataUrl);
              } else {
                addImageUrl(dataUrl);
              }
            }
          }
          outMsg['content'] = parts;
          mm.add(outMsg);
        } else {
          // No images, use simple string content
          outMsg['content'] = raw;
          mm.add(outMsg);
        }
      }
      body = {
        'model': upstreamModelId,
        'messages': mm,
        'stream': stream,
        if (temperature != null) 'temperature': temperature,
        if (topP != null) 'top_p': topP,
        if (isReasoning && effort != 'off' && effort != 'auto')
          'reasoning_effort': effort,
        if (tools != null && tools.isNotEmpty)
          'tools': _cleanToolsForCompatibility(tools),
        if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
      };
    }
    setMaxTokens(body);
  }

  // Vendor-specific reasoning knobs for chat-completions compatible hosts
  if (config.useResponseApi != true) {
    final off = _isOff(thinkingBudget);
    if (host.contains('openrouter.ai')) {
      if (isReasoning) {
        // OpenRouter uses `reasoning.enabled/max_tokens`
        if (off) {
          body['reasoning'] = {'enabled': false};
        } else {
          final obj = <String, dynamic>{'enabled': true};
          if (thinkingBudget != null && thinkingBudget > 0) {
            obj['max_tokens'] = thinkingBudget;
          }
          body['reasoning'] = obj;
        }
        body.remove('reasoning_effort');
      } else {
        body.remove('reasoning');
        body.remove('reasoning_effort');
      }
    } else if (host.contains('dashscope') || host.contains('aliyun')) {
      // Aliyun DashScope: enable_thinking + thinking_budget
      if (isReasoning) {
        body['enable_thinking'] = !off;
        if (!off && thinkingBudget != null && thinkingBudget > 0) {
          body['thinking_budget'] = thinkingBudget;
        } else {
          body.remove('thinking_budget');
        }
      } else {
        body.remove('enable_thinking');
        body.remove('thinking_budget');
      }
      body.remove('reasoning_effort');
    } else if (host.contains('open.bigmodel.cn') ||
        host.contains('bigmodel') ||
        isMimo) {
      // Zhipu (BigModel) / Xiaomi MiMo: thinking.type enabled/disabled
      if (isReasoning) {
        body['thinking'] = {'type': off ? 'disabled' : 'enabled'};
      } else {
        body.remove('thinking');
      }
      body.remove('reasoning_effort');
    } else if (host.contains('ark.cn-beijing.volces.com') ||
        host.contains('volc') ||
        host.contains('ark')) {
      // Volc Ark: thinking: { type: enabled|disabled }
      if (isReasoning) {
        body['thinking'] = {'type': off ? 'disabled' : 'enabled'};
      } else {
        body.remove('thinking');
      }
      body.remove('reasoning_effort');
    } else if (host.contains('intern-ai') ||
        host.contains('intern') ||
        host.contains('chat.intern-ai.org.cn')) {
      // InternLM (InternAI): thinking_mode boolean switch
      if (isReasoning) {
        body['thinking_mode'] = !off;
      } else {
        body.remove('thinking_mode');
      }
      body.remove('reasoning_effort');
    } else if (host.contains('siliconflow')) {
      // SiliconFlow: OFF -> enable_thinking: false; otherwise omit
      if (isReasoning) {
        if (off) {
          body['enable_thinking'] = false;
        } else {
          body.remove('enable_thinking');
        }
      } else {
        body.remove('enable_thinking');
      }
      body.remove('reasoning_effort');
    } else if (host.contains('deepseek') ||
        upstreamModelId.toLowerCase().contains('deepseek')) {
      if (isReasoning) {
        if (off) {
          body['reasoning_content'] = false;
          body.remove('reasoning_budget');
        } else {
          body['reasoning_content'] = true;
          if (thinkingBudget != null && thinkingBudget > 0) {
            body['reasoning_budget'] = thinkingBudget;
          } else {
            body.remove('reasoning_budget');
          }
        }
      } else {
        body.remove('reasoning_content');
        body.remove('reasoning_budget');
      }
    }
  }

  final request = http.Request('POST', url);
  final headers = <String, String>{
    'Authorization': 'Bearer ${_apiKeyForRequest(config, modelId)}',
    'Content-Type': 'application/json',
    'Accept': stream ? 'text/event-stream' : 'application/json',
  };
  // Merge custom headers (override takes precedence)
  headers.addAll(_customHeaders(config, modelId));
  if (extraHeaders != null && extraHeaders.isNotEmpty) {
    headers.addAll(extraHeaders);
  }
  request.headers.addAll(headers);
  _maybeAddStreamingUsageOptions(
    body,
    stream: stream,
    config: config,
    host: host,
    upstreamModelId: upstreamModelId,
  );
  _applyCompatibleBuiltInSearch(
    body,
    config: config,
    modelId: modelId,
    upstreamModelId: upstreamModelId,
  );

  // Merge custom body keys (override takes precedence)
  final extraBodyCfg = _customBody(config, modelId);
  if (extraBodyCfg.isNotEmpty) {
    body.addAll(extraBodyCfg);
  }
  if (extraBody != null && extraBody.isNotEmpty) {
    extraBody.forEach((k, v) {
      body[k] = (v is String) ? _parseOverrideValue(v) : v;
    });
  }
  _sanitizeOpenAIGpt5SamplingParams(
    body,
    upstreamModelId,
    fallbackEffort: effort,
  );
  request.body = jsonEncode(body);

  final response = await client.send(request);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    final errorBody = await response.stream.bytesToString();
    throw HttpException('HTTP ${response.statusCode}: $errorBody');
  }

  // Non-streaming path: parse one-shot JSON and optionally follow tool calls.
  if (!stream) {
    final txt = await response.stream.bytesToString();
    try {
      final obj = jsonDecode(txt);
      // Responses API non-stream
      if (config.useResponseApi == true) {
        String outText = '';
        try {
          outText = (obj['output_text'] ?? '').toString();
        } catch (_) {}
        if (outText.isEmpty) {
          try {
            outText = (obj['response']?['output_text'] ?? '').toString();
          } catch (_) {}
        }
        if (outText.isEmpty) {
          try {
            final out = obj['output'] as List?;
            if (out != null) {
              final buf = StringBuffer();
              for (final it in out) {
                if (it is Map && it['type'] == 'output_text') {
                  final c = (it['content'] ?? '').toString();
                  if (c.isNotEmpty) buf.write(c);
                } else if (it is Map && it['type'] == 'message') {
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
        }
        TokenUsage? usage;
        try {
          final u = (obj['usage'] ?? obj['response']?['usage']) as Map?;
          if (u != null) {
            final prompt =
                (u['prompt_tokens'] ?? u['input_tokens'] ?? 0) as int? ?? 0;
            final completion =
                (u['completion_tokens'] ?? u['output_tokens'] ?? 0) as int? ??
                0;
            final cached =
                (u['prompt_tokens_details']?['cached_tokens'] ?? 0) as int? ??
                0;
            usage = TokenUsage(
              promptTokens: prompt,
              completionTokens: completion,
              cachedTokens: cached,
              totalTokens: prompt + completion,
            );
          }
        } catch (_) {}
        yield ChatStreamChunk(
          content: outText,
          isDone: true,
          totalTokens: usage?.totalTokens ?? 0,
          usage: usage,
        );
        return;
      }

      // Chat Completions non-stream with tool-calls follow-ups
      TokenUsage? aggUsage;
      Map<String, dynamic> lastObj = obj is Map
          ? Map<String, dynamic>.from(obj)
          : <String, dynamic>{};
      while (true) {
        Map<String, dynamic>? c0;
        try {
          final choices = lastObj['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            c0 = (choices.first as Map).cast<String, dynamic>();
          }
        } catch (_) {}
        if (c0 == null) {
          final s = (lastObj['output_text'] ?? '').toString();
          yield ChatStreamChunk(
            content: s,
            isDone: true,
            totalTokens: aggUsage?.totalTokens ?? 0,
            usage: aggUsage,
          );
          return;
        }
        // usage
        try {
          final u = lastObj['usage'];
          if (u is Map) {
            final prompt = (u['prompt_tokens'] ?? 0) as int? ?? 0;
            final completion = (u['completion_tokens'] ?? 0) as int? ?? 0;
            final cached =
                (u['prompt_tokens_details']?['cached_tokens'] ?? 0) as int? ??
                0;
            final round = TokenUsage(
              promptTokens: prompt,
              completionTokens: completion,
              cachedTokens: cached,
              totalTokens: prompt + completion,
            );
            aggUsage = (aggUsage ?? const TokenUsage()).merge(round);
          }
        } catch (_) {}

        final msg =
            (c0['message'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final reasoningForTools =
            (msg['reasoning_content'] ?? msg['reasoning'])?.toString() ?? '';
        final reasoningDetailsForTools = msg['reasoning_details'];
        final tcs = (msg['tool_calls'] as List?) ?? const <dynamic>[];
        if (tcs.isNotEmpty && onToolCall != null) {
          final calls = <Map<String, dynamic>>[];
          final callInfos = <ToolCallInfo>[];
          for (int i = 0; i < tcs.length; i++) {
            final t = (tcs[i] as Map).cast<String, dynamic>();
            final id = (t['id'] ?? 'call_$i').toString();
            final f =
                (t['function'] as Map?)?.cast<String, dynamic>() ??
                const <String, dynamic>{};
            final name = (f['name'] ?? '').toString();
            Map<String, dynamic> args;
            try {
              args = (jsonDecode((f['arguments'] ?? '{}').toString()) as Map)
                  .cast<String, dynamic>();
            } catch (_) {
              args = <String, dynamic>{};
            }
            callInfos.add(ToolCallInfo(id: id, name: name, arguments: args));
            calls.add({
              'id': id,
              'type': 'function',
              'function': {'name': name, 'arguments': jsonEncode(args)},
            });
          }
          if (callInfos.isNotEmpty) {
            yield ChatStreamChunk(
              content: '',
              isDone: false,
              totalTokens: aggUsage?.totalTokens ?? 0,
              usage: aggUsage,
              toolCalls: callInfos,
            );
          }
          final results = <Map<String, dynamic>>[];
          final resultsInfo = <ToolResultInfo>[];
          for (final c in callInfos) {
            final res = await onToolCall(c.name, c.arguments);
            results.add({'tool_call_id': c.id, 'content': res});
            resultsInfo.add(
              ToolResultInfo(
                id: c.id,
                name: c.name,
                arguments: c.arguments,
                content: res,
              ),
            );
          }
          if (resultsInfo.isNotEmpty) {
            yield ChatStreamChunk(
              content: '',
              isDone: false,
              totalTokens: aggUsage?.totalTokens ?? 0,
              usage: aggUsage,
              toolResults: resultsInfo,
            );
          }
          // Follow-up request
          final req = http.Request('POST', url);
          final headers2 = <String, String>{
            'Authorization': 'Bearer ${_apiKeyForRequest(config, modelId)}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          };
          headers2.addAll(_customHeaders(config, modelId));
          if (extraHeaders != null && extraHeaders.isNotEmpty) {
            headers2.addAll(extraHeaders);
          }
          req.headers.addAll(headers2);
          final next = <Map<String, dynamic>>[];
          for (final m in messages) {
            next.add(_copyChatCompletionMessage(m));
          }
          final assistantToolCallMsg = <String, dynamic>{
            'role': 'assistant',
            'content': '\n\n',
            'tool_calls': calls,
          };
          if (needsReasoningEcho) {
            assistantToolCallMsg['reasoning_content'] = reasoningForTools;
          }
          if (preserveReasoningDetails &&
              reasoningDetailsForTools is List &&
              reasoningDetailsForTools.isNotEmpty) {
            assistantToolCallMsg['reasoning_details'] =
                reasoningDetailsForTools;
          }
          next.add(assistantToolCallMsg);
          for (final r in results) {
            final id = r['tool_call_id'];
            final name = calls.firstWhere(
              (c) => c['id'] == id,
              orElse: () => const {
                'function': {'name': ''},
              },
            )['function']['name'];
            next.add({
              'role': 'tool',
              'tool_call_id': id,
              'name': name,
              'content': r['content'],
            });
          }
          final reqBody = Map<String, dynamic>.from(body);
          reqBody['messages'] = useLongCatOmniPayload
              ? await _buildLongCatOmniMessages(
                  next,
                  userMediaPaths: userImagePaths,
                )
              : next;
          reqBody.remove('stream');
          req.body = jsonEncode(reqBody);
          final resp2 = await client.send(req);
          if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
            final errorBody = await resp2.stream.bytesToString();
            throw HttpException('HTTP ${resp2.statusCode}: $errorBody');
          }
          final txt2 = await resp2.stream.bytesToString();
          lastObj = jsonDecode(txt2) as Map<String, dynamic>;
          messages = next; // update transcript for next round
          continue;
        }

        // No tool calls -> final content
        String content = '';
        final cmsg = (c0['message'] as Map?)?.cast<String, dynamic>();
        if (cmsg != null) {
          final cc = cmsg['content'];
          if (cc is String) {
            content = cc;
          } else if (cc is List) {
            final buf = StringBuffer();
            for (final it in cc) {
              if (it is Map && (it['type'] == 'text')) {
                final t = (it['text'] ?? '').toString();
                if (t.isNotEmpty) buf.write(t);
              } else if (it is Map &&
                  (it['type'] == 'image_url' || it['type'] == 'image')) {
                dynamic iu = it['image_url'];
                String? url;
                if (iu is String) {
                  url = iu;
                } else if (iu is Map) {
                  final u2 = iu['url'];
                  if (u2 is String) url = u2;
                }
                if (url != null && url.isNotEmpty) {
                  buf.write('\n\n![image]($url)');
                }
              }
            }
            content = buf.toString();
          }
        }
        yield ChatStreamChunk(
          content: content,
          isDone: true,
          totalTokens: aggUsage?.totalTokens ?? 0,
          usage: aggUsage,
        );
        return;
      }
    } catch (e) {
      throw HttpException('Invalid JSON: $e');
    }
  }

  // Streaming path
  final sse = response.stream.transform(utf8.decoder);
  String buffer = '';
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
  dynamic reasoningDetailsBuffer;

  // Track potential tool calls (OpenAI Chat Completions)
  final Map<int, Map<String, String>> toolAcc =
      <int, Map<String, String>>{}; // index -> {id,name,args}
  // Track potential tool calls (OpenAI Responses API)
  final Map<String, Map<String, String>> toolAccResp =
      <String, Map<String, String>>{}; // id/name -> {name,args}
  // Responses API: track by output_index to capture call_id reliably
  final Map<int, Map<String, String>> respToolCallsByIndex =
      <int, Map<String, String>>{}; // index -> {call_id,name,args}
  List<Map<String, dynamic>> lastResponseOutputItems =
      const <Map<String, dynamic>>[];
  String? finishReason;

  await for (final chunk in sse) {
    buffer += chunk;
    final lines = buffer.split('\n');
    buffer = lines.last;

    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || !line.startsWith('data:')) continue;

      final data = line.substring(5).trimLeft();
      if (data == '[DONE]') {
        // If model streamed tool_calls but didn't include finish_reason on prior chunks,
        // execute tool flow now and start follow-up request.
        if (onToolCall != null && toolAcc.isNotEmpty) {
          final calls = <Map<String, dynamic>>[];
          final callInfos = <ToolCallInfo>[];
          final toolMsgs = <Map<String, dynamic>>[];
          toolAcc.forEach((idx, m) {
            final id = (m['id'] ?? 'call_$idx');
            final name = (m['name'] ?? '');
            Map<String, dynamic> args;
            try {
              args = (jsonDecode(m['args'] ?? '{}') as Map)
                  .cast<String, dynamic>();
            } catch (_) {
              args = <String, dynamic>{};
            }
            callInfos.add(ToolCallInfo(id: id, name: name, arguments: args));
            calls.add({
              'id': id,
              'type': 'function',
              'function': {'name': name, 'arguments': jsonEncode(args)},
            });
            toolMsgs.add({'__name': name, '__id': id, '__args': args});
          });

          if (callInfos.isNotEmpty) {
            final approxTotal =
                approxPromptTokens +
                approxTokensFromChars(approxCompletionChars);
            yield ChatStreamChunk(
              content: '',
              isDone: false,
              totalTokens: usage?.totalTokens ?? approxTotal,
              usage: usage,
              toolCalls: callInfos,
            );
          }

          // Execute tools and emit results
          final results = <Map<String, dynamic>>[];
          final resultsInfo = <ToolResultInfo>[];
          for (final m in toolMsgs) {
            final name = m['__name'] as String;
            final id = m['__id'] as String;
            final args = (m['__args'] as Map<String, dynamic>);
            final res = await onToolCall(name, args);
            results.add({'tool_call_id': id, 'content': res});
            resultsInfo.add(
              ToolResultInfo(id: id, name: name, arguments: args, content: res),
            );
          }
          if (resultsInfo.isNotEmpty) {
            yield ChatStreamChunk(
              content: '',
              isDone: false,
              totalTokens: usage?.totalTokens ?? 0,
              usage: usage,
              toolResults: resultsInfo,
            );
          }

          // Build follow-up messages
          final mm2 = <Map<String, dynamic>>[];
          for (final m in messages) {
            mm2.add(_copyChatCompletionMessage(m));
          }
          final assistantToolCallMsg = <String, dynamic>{
            'role': 'assistant',
            'content': '\n\n',
            'tool_calls': calls,
          };
          if (needsReasoningEcho) {
            assistantToolCallMsg['reasoning_content'] = reasoningBuffer;
          }
          if (preserveReasoningDetails &&
              reasoningDetailsBuffer is List &&
              reasoningDetailsBuffer.isNotEmpty) {
            assistantToolCallMsg['reasoning_details'] = reasoningDetailsBuffer;
          }
          mm2.add(assistantToolCallMsg);
          for (final r in results) {
            final id = r['tool_call_id'];
            final name = calls.firstWhere(
              (c) => c['id'] == id,
              orElse: () => const {
                'function': {'name': ''},
              },
            )['function']['name'];
            mm2.add({
              'role': 'tool',
              'tool_call_id': id,
              'name': name,
              'content': r['content'],
            });
          }

          // Follow-up request(s) with multi-round tool calls
          var currentMessages = mm2;
          while (true) {
            final Map<String, dynamic> body2 = useLongCatOmniPayload
                ? {
                    'model': upstreamModelId,
                    'messages': await _buildLongCatOmniMessages(
                      currentMessages,
                      userMediaPaths: userImagePaths,
                    ),
                    'stream': true,
                    'output_modalities': const ['text'],
                    if (temperature != null) 'temperature': temperature,
                    if (topP != null) 'top_p': topP,
                    if (isReasoning && effort != 'off' && effort != 'auto')
                      'reasoning_effort': effort,
                    if (tools != null && tools.isNotEmpty)
                      'tools': _cleanToolsForCompatibility(tools),
                    if (tools != null && tools.isNotEmpty)
                      'tool_choice': 'auto',
                  }
                : {
                    'model': upstreamModelId,
                    'messages': currentMessages,
                    'stream': true,
                    if (temperature != null) 'temperature': temperature,
                    if (topP != null) 'top_p': topP,
                    if (isReasoning && effort != 'off' && effort != 'auto')
                      'reasoning_effort': effort,
                    if (tools != null && tools.isNotEmpty)
                      'tools': _cleanToolsForCompatibility(tools),
                    if (tools != null && tools.isNotEmpty)
                      'tool_choice': 'auto',
                  };
            setMaxTokens(body2);

            // Apply the same vendor-specific reasoning settings as the original request
            final off = _isOff(thinkingBudget);
            if (host.contains('openrouter.ai')) {
              if (isReasoning) {
                if (off) {
                  body2['reasoning'] = {'enabled': false};
                } else {
                  final obj = <String, dynamic>{'enabled': true};
                  if (thinkingBudget != null && thinkingBudget > 0) {
                    obj['max_tokens'] = thinkingBudget;
                  }
                  body2['reasoning'] = obj;
                }
                body2.remove('reasoning_effort');
              } else {
                body2.remove('reasoning');
                body2.remove('reasoning_effort');
              }
            } else if (host.contains('dashscope') || host.contains('aliyun')) {
              if (isReasoning) {
                body2['enable_thinking'] = !off;
                if (!off && thinkingBudget != null && thinkingBudget > 0) {
                  body2['thinking_budget'] = thinkingBudget;
                } else {
                  body2.remove('thinking_budget');
                }
              } else {
                body2.remove('enable_thinking');
                body2.remove('thinking_budget');
              }
              body2.remove('reasoning_effort');
            } else if (host.contains('open.bigmodel.cn') ||
                host.contains('bigmodel') ||
                isMimo) {
              if (isReasoning) {
                body2['thinking'] = {'type': off ? 'disabled' : 'enabled'};
              } else {
                body2.remove('thinking');
              }
              body2.remove('reasoning_effort');
            } else if (host.contains('ark.cn-beijing.volces.com') ||
                host.contains('volc') ||
                host.contains('ark')) {
              if (isReasoning) {
                body2['thinking'] = {'type': off ? 'disabled' : 'enabled'};
              } else {
                body2.remove('thinking');
              }
              body2.remove('reasoning_effort');
            } else if (host.contains('intern-ai') ||
                host.contains('intern') ||
                host.contains('chat.intern-ai.org.cn')) {
              if (isReasoning) {
                body2['thinking_mode'] = !off;
              } else {
                body2.remove('thinking_mode');
              }
              body2.remove('reasoning_effort');
            } else if (host.contains('siliconflow')) {
              if (isReasoning) {
                if (off) {
                  body2['enable_thinking'] = false;
                } else {
                  body2.remove('enable_thinking');
                }
              } else {
                body2.remove('enable_thinking');
              }
              body2.remove('reasoning_effort');
            } else if (host.contains('deepseek') ||
                upstreamModelId.toLowerCase().contains('deepseek')) {
              if (isReasoning) {
                if (off) {
                  body2['reasoning_content'] = false;
                  body2.remove('reasoning_budget');
                } else {
                  body2['reasoning_content'] = true;
                  if (thinkingBudget != null && thinkingBudget > 0) {
                    body2['reasoning_budget'] = thinkingBudget;
                  } else {
                    body2.remove('reasoning_budget');
                  }
                }
              } else {
                body2.remove('reasoning_content');
                body2.remove('reasoning_budget');
              }
            }

            // Ask for usage in streaming (when supported)
            _applyCompatibleBuiltInSearch(
              body2,
              config: config,
              modelId: modelId,
              upstreamModelId: upstreamModelId,
            );
            _maybeAddStreamingUsageOptions(
              body2,
              stream: true,
              config: config,
              host: host,
              upstreamModelId: upstreamModelId,
            );

            // Apply custom body overrides
            if (extraBodyCfg.isNotEmpty) {
              body2.addAll(extraBodyCfg);
            }
            if (extraBody != null && extraBody.isNotEmpty) {
              extraBody.forEach((k, v) {
                body2[k] = (v is String) ? _parseOverrideValue(v) : v;
              });
            }

            _sanitizeOpenAIGpt5SamplingParams(
              body2,
              upstreamModelId,
              fallbackEffort: effort,
            );

            final req2 = http.Request('POST', url);
            final headers2 = <String, String>{
              'Authorization': 'Bearer ${_apiKeyForRequest(config, modelId)}',
              'Content-Type': 'application/json',
              'Accept': 'text/event-stream',
            };
            // Apply custom headers
            headers2.addAll(_customHeaders(config, modelId));
            if (extraHeaders != null && extraHeaders.isNotEmpty) {
              headers2.addAll(extraHeaders);
            }
            req2.headers.addAll(headers2);
            req2.body = jsonEncode(body2);
            final resp2 = await client.send(req2);
            if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
              final errorBody = await resp2.stream.bytesToString();
              throw HttpException('HTTP ${resp2.statusCode}: $errorBody');
            }
            final s2 = resp2.stream.transform(utf8.decoder);
            String buf2 = '';
            // Track potential subsequent tool calls
            final Map<int, Map<String, String>> toolAcc2 =
                <int, Map<String, String>>{};
            String? finishReason2;
            String contentAccum = ''; // Accumulate content for this round
            String reasoningAccum = '';
            dynamic reasoningDetailsAccum;
            await for (final ch in s2) {
              buf2 += ch;
              final lines2 = buf2.split('\n');
              buf2 = lines2.last;
              for (int j = 0; j < lines2.length - 1; j++) {
                final l = lines2[j].trim();
                if (l.isEmpty || !l.startsWith('data:')) continue;
                final d = l.substring(5).trimLeft();
                if (d == '[DONE]') {
                  // This round finished; handle below
                  continue;
                }
                try {
                  final o = jsonDecode(d);
                  if (o is Map &&
                      o['choices'] is List &&
                      (o['choices'] as List).isNotEmpty) {
                    final c0 = (o['choices'] as List).first;
                    finishReason2 = c0['finish_reason'] as String?;
                    final delta = c0['delta'] as Map?;
                    final message = c0['message'] as Map?;
                    final txt = _extractOpenAICompatibleDeltaText(delta);
                    final rc =
                        delta?['reasoning_content'] ?? delta?['reasoning'];
                    final u = o['usage'];
                    if (u != null) {
                      final prompt = (u['prompt_tokens'] ?? 0) as int;
                      final completion = (u['completion_tokens'] ?? 0) as int;
                      final cached =
                          (u['prompt_tokens_details']?['cached_tokens'] ?? 0)
                              as int? ??
                          0;
                      usage = (usage ?? const TokenUsage()).merge(
                        TokenUsage(
                          promptTokens: prompt,
                          completionTokens: completion,
                          cachedTokens: cached,
                        ),
                      );
                      totalTokens = usage.totalTokens;
                    }
                    // Capture Grok citations
                    final gCitations = o['citations'];
                    if (gCitations is List && gCitations.isNotEmpty) {
                      final items = <Map<String, dynamic>>[];
                      for (int k = 0; k < gCitations.length; k++) {
                        final u = gCitations[k].toString();
                        items.add({'index': k + 1, 'url': u, 'title': u});
                      }
                      if (items.isNotEmpty) {
                        final payload = jsonEncode({'items': items});
                        yield ChatStreamChunk(
                          content: '',
                          isDone: false,
                          totalTokens: usage?.totalTokens ?? 0,
                          usage: usage,
                          toolResults: [
                            ToolResultInfo(
                              id: 'builtin_search',
                              name: 'search_web',
                              arguments: const <String, dynamic>{},
                              content: payload,
                            ),
                          ],
                        );
                      }
                    }
                    if (rc is String && rc.isNotEmpty) {
                      if (needsReasoningEcho) reasoningAccum += rc;
                      yield ChatStreamChunk(
                        content: '',
                        reasoning: rc,
                        isDone: false,
                        totalTokens: 0,
                        usage: usage,
                      );
                    }
                    if (txt.isNotEmpty) {
                      contentAccum += txt; // Accumulate content
                      yield ChatStreamChunk(
                        content: txt,
                        isDone: false,
                        totalTokens: 0,
                        usage: usage,
                      );
                    }
                    // Fallback/merge: message.content in same chunk (if any)
                    if (message != null && message['content'] != null) {
                      final mc = message['content'];
                      if (mc is String && mc.isNotEmpty) {
                        contentAccum += mc;
                        yield ChatStreamChunk(
                          content: mc,
                          isDone: false,
                          totalTokens: 0,
                          usage: usage,
                        );
                      }
                    }
                    if (message != null) {
                      final rcMsg =
                          message['reasoning_content'] ?? message['reasoning'];
                      if (rcMsg is String &&
                          rcMsg.isNotEmpty &&
                          needsReasoningEcho) {
                        reasoningAccum += rcMsg;
                      }
                    }
                    if (preserveReasoningDetails) {
                      final rd = delta?['reasoning_details'];
                      if (rd is List && rd.isNotEmpty) {
                        reasoningDetailsAccum = rd;
                      }
                      final rdMsg = message?['reasoning_details'];
                      if (rdMsg is List && rdMsg.isNotEmpty) {
                        reasoningDetailsAccum = rdMsg;
                      }
                    }
                    // Handle image outputs from OpenRouter-style deltas
                    // Possible shapes:
                    // - delta['images']: [ { type: 'image_url', image_url: { url: 'data:...' }, index: 0 }, ... ]
                    // - delta['content']: [ { type: 'image_url', image_url: { url: '...' } }, { type: 'text', text: '...' } ]
                    // - delta['image_url'] directly (less common)
                    if (wantsImageOutput) {
                      final List<dynamic> imageItems = <dynamic>[];
                      final imgs = delta?['images'];
                      if (imgs is List) imageItems.addAll(imgs);
                      final contentArr = delta?['content'] as List?;
                      if (contentArr is List) {
                        for (final it in contentArr) {
                          if (it is Map &&
                              (it['type'] == 'image_url' ||
                                  it['type'] == 'image')) {
                            imageItems.add(it);
                          }
                        }
                      }
                      final singleImage = delta?['image_url'];
                      if (singleImage is Map || singleImage is String) {
                        imageItems.add({
                          'type': 'image_url',
                          'image_url': singleImage,
                        });
                      }
                      if (imageItems.isNotEmpty) {
                        final buf = StringBuffer();
                        for (final it in imageItems) {
                          if (it is! Map) continue;
                          dynamic iu = it['image_url'];
                          String? url;
                          if (iu is String) {
                            url = iu;
                          } else if (iu is Map) {
                            final u2 = iu['url'];
                            if (u2 is String) url = u2;
                          }
                          if (url != null && url.isNotEmpty) {
                            final md = '\n\n![image]($url)';
                            buf.write(md);
                            contentAccum += md;
                          }
                        }
                        final out = buf.toString();
                        if (out.isNotEmpty) {
                          yield ChatStreamChunk(
                            content: out,
                            isDone: false,
                            totalTokens: 0,
                            usage: usage,
                          );
                        }
                      }
                    }
                    final tcs = delta?['tool_calls'] as List?;
                    if (tcs != null) {
                      for (final t in tcs) {
                        final idx = (t['index'] as int?) ?? 0;
                        final id = t['id'] as String?;
                        final func = t['function'] as Map<String, dynamic>?;
                        final name = func?['name'] as String?;
                        final argsDelta = func?['arguments'] as String?;
                        final entry = toolAcc2.putIfAbsent(
                          idx,
                          () => {'id': '', 'name': '', 'args': ''},
                        );
                        if (id != null) entry['id'] = id;
                        if (name != null && name.isNotEmpty) {
                          entry['name'] = name;
                        }
                        if (argsDelta != null && argsDelta.isNotEmpty) {
                          entry['args'] = (entry['args'] ?? '') + argsDelta;
                        }
                      }
                    }
                  }
                } catch (_) {}
              }
            }

            // After this follow-up round finishes: if tool calls again, execute and loop
            if (finishReason2 == 'tool_calls' || toolAcc2.isNotEmpty) {
              final calls2 = <Map<String, dynamic>>[];
              final callInfos2 = <ToolCallInfo>[];
              final toolMsgs2 = <Map<String, dynamic>>[];
              toolAcc2.forEach((idx, m) {
                final id = (m['id'] ?? 'call_$idx');
                final name = (m['name'] ?? '');
                Map<String, dynamic> args;
                try {
                  args = (jsonDecode(m['args'] ?? '{}') as Map)
                      .cast<String, dynamic>();
                } catch (_) {
                  args = <String, dynamic>{};
                }
                callInfos2.add(
                  ToolCallInfo(id: id, name: name, arguments: args),
                );
                calls2.add({
                  'id': id,
                  'type': 'function',
                  'function': {'name': name, 'arguments': jsonEncode(args)},
                });
                toolMsgs2.add({'__name': name, '__id': id, '__args': args});
              });
              if (callInfos2.isNotEmpty) {
                yield ChatStreamChunk(
                  content: '',
                  isDone: false,
                  totalTokens: usage?.totalTokens ?? 0,
                  usage: usage,
                  toolCalls: callInfos2,
                );
              }
              final results2 = <Map<String, dynamic>>[];
              final resultsInfo2 = <ToolResultInfo>[];
              for (final m in toolMsgs2) {
                final name = m['__name'] as String;
                final id = m['__id'] as String;
                final args = (m['__args'] as Map<String, dynamic>);
                final res = await onToolCall(name, args);
                results2.add({'tool_call_id': id, 'content': res});
                resultsInfo2.add(
                  ToolResultInfo(
                    id: id,
                    name: name,
                    arguments: args,
                    content: res,
                  ),
                );
              }
              if (resultsInfo2.isNotEmpty) {
                yield ChatStreamChunk(
                  content: '',
                  isDone: false,
                  totalTokens: usage?.totalTokens ?? 0,
                  usage: usage,
                  toolResults: resultsInfo2,
                );
              }
              // Append for next loop - including any content accumulated in this round
              final nextAssistantToolCall = <String, dynamic>{
                'role': 'assistant',
                'content': '\n\n',
                'tool_calls': calls2,
              };
              if (needsReasoningEcho) {
                nextAssistantToolCall['reasoning_content'] = reasoningAccum;
              }
              if (preserveReasoningDetails &&
                  reasoningDetailsAccum is List &&
                  reasoningDetailsAccum.isNotEmpty) {
                nextAssistantToolCall['reasoning_details'] =
                    reasoningDetailsAccum;
              }
              currentMessages = [
                ...currentMessages,
                if (contentAccum.isNotEmpty)
                  {'role': 'assistant', 'content': contentAccum},
                nextAssistantToolCall,
                for (final r in results2)
                  {
                    'role': 'tool',
                    'tool_call_id': r['tool_call_id'],
                    'name': calls2.firstWhere(
                      (c) => c['id'] == r['tool_call_id'],
                      orElse: () => const {
                        'function': {'name': ''},
                      },
                    )['function']['name'],
                    'content': r['content'],
                  },
              ];
              // Continue loop
              continue;
            } else {
              // No further tool calls; finish
              final approxTotal =
                  approxPromptTokens +
                  approxTokensFromChars(approxCompletionChars);
              yield ChatStreamChunk(
                content: '',
                isDone: true,
                totalTokens: usage?.totalTokens ?? approxTotal,
                usage: usage,
              );
              return;
            }
          }
        }

        final approxTotal =
            approxPromptTokens + approxTokensFromChars(approxCompletionChars);
        yield ChatStreamChunk(
          content: '',
          isDone: true,
          totalTokens: usage?.totalTokens ?? approxTotal,
          usage: usage,
        );
        return;
      }

      try {
        final json = jsonDecode(data);
        String content = '';
        String? reasoning;

        if (config.useResponseApi == true) {
          // OpenAI /responses SSE types
          final type = json['type'];
          if (type == 'response.output_text.delta') {
            final delta = json['delta'];
            if (delta is String) {
              content = delta;
              approxCompletionChars += content.length;
            }
          } else if (type == 'response.reasoning_summary_text.delta') {
            final delta = json['delta'];
            if (delta is String) reasoning = delta;
          } else if (type == 'response.output_item.added') {
            try {
              final item = json['item'];
              final idx = (json['output_index'] ?? 0) as int;
              if (item is Map && (item['type'] ?? '') == 'function_call') {
                final name = (item['name'] ?? '').toString();
                final callId = (item['call_id'] ?? '').toString();
                respToolCallsByIndex[idx] = {
                  'call_id': callId,
                  'name': name,
                  'args': '',
                };
              }
            } catch (_) {}
          } else if (type == 'response.function_call_arguments.delta') {
            try {
              final idx = (json['output_index'] ?? 0) as int;
              final delta = (json['delta'] ?? '').toString();
              final entry = respToolCallsByIndex.putIfAbsent(
                idx,
                () => {'call_id': '', 'name': '', 'args': ''},
              );
              if (delta.isNotEmpty) {
                entry['args'] = (entry['args'] ?? '') + delta;
              }
            } catch (_) {}
          } else if (type == 'response.output_item.done') {
            try {
              final item = json['item'];
              final idx = (json['output_index'] ?? 0) as int;
              if (item is Map && (item['type'] ?? '') == 'function_call') {
                final args = (item['arguments'] ?? '').toString();
                final entry = respToolCallsByIndex.putIfAbsent(
                  idx,
                  () => {
                    'call_id': (item['call_id'] ?? '').toString(),
                    'name': (item['name'] ?? '').toString(),
                    'args': '',
                  },
                );
                if (args.isNotEmpty) entry['args'] = args;
              }
            } catch (_) {}
          } else if (type is String && type.contains('function_call')) {
            // Accumulate function call args for Responses API
            final id = (json['id'] ?? json['call_id'] ?? '').toString();
            final name = (json['name'] ?? json['function']?['name'] ?? '')
                .toString();
            final argsDelta =
                (json['arguments'] ??
                        json['arguments_delta'] ??
                        json['delta'] ??
                        '')
                    .toString();
            if (id.isNotEmpty || name.isNotEmpty) {
              final key = id.isNotEmpty ? id : name;
              final entry = toolAccResp.putIfAbsent(
                key,
                () => {'name': name, 'args': ''},
              );
              if (name.isNotEmpty) entry['name'] = name;
              if (argsDelta.isNotEmpty) {
                entry['args'] = (entry['args'] ?? '') + argsDelta;
              }
            }
          } else if (type == 'response.completed') {
            final u = json['response']?['usage'];
            if (u != null) {
              final inTok = (u['input_tokens'] ?? 0) as int;
              final outTok = (u['output_tokens'] ?? 0) as int;
              usage = (usage ?? const TokenUsage()).merge(
                TokenUsage(promptTokens: inTok, completionTokens: outTok),
              );
              totalTokens = usage.totalTokens;
            }
            // Extract web search citations from final output (Responses API)
            try {
              final output = json['response']?['output'];
              final items = <Map<String, dynamic>>[];
              // Save output items for potential follow-up call input
              lastResponseOutputItems = const <Map<String, dynamic>>[];
              if (output is List) {
                lastResponseOutputItems = [
                  for (final it in output)
                    if (it is Map) (it.cast<String, dynamic>()),
                ];
              }
              if (output is List) {
                int idx = 1;
                final seen = <String>{};
                for (final it in output) {
                  if (it is! Map) continue;
                  if (it['type'] == 'message') {
                    final content = it['content'] as List? ?? const <dynamic>[];
                    for (final block in content) {
                      if (block is! Map) continue;
                      final anns =
                          block['annotations'] as List? ?? const <dynamic>[];
                      for (final an in anns) {
                        if (an is! Map) continue;
                        if ((an['type'] ?? '') == 'url_citation') {
                          final url = (an['url'] ?? '').toString();
                          if (url.isEmpty || seen.contains(url)) continue;
                          final title = (an['title'] ?? '').toString();
                          items.add({
                            'index': idx,
                            'url': url,
                            if (title.isNotEmpty) 'title': title,
                          });
                          seen.add(url);
                          idx += 1;
                        }
                      }
                    }
                  } else if (it['type'] == 'image_generation_call') {
                    // Handle image generation output from OpenAI Responses API
                    // it['result'] is directly the base64 image data
                    final b64 = (it['result'] ?? '').toString();
                    if (b64.isNotEmpty) {
                      final savedPath = await AppDirectories.saveBase64Image(
                        'image/png',
                        b64,
                      );
                      if (savedPath != null && savedPath.isNotEmpty) {
                        final mdImg = '\n![Generated Image]($savedPath)\n';
                        yield ChatStreamChunk(
                          content: mdImg,
                          isDone: false,
                          totalTokens: totalTokens,
                          usage: usage,
                        );
                      }
                    }
                  }
                }
              }
              if (items.isNotEmpty) {
                final payload = jsonEncode({'items': items});
                yield ChatStreamChunk(
                  content: '',
                  isDone: false,
                  totalTokens: totalTokens,
                  usage: usage,
                  toolResults: [
                    ToolResultInfo(
                      id: 'builtin_search',
                      name: 'search_web',
                      arguments: const <String, dynamic>{},
                      content: payload,
                    ),
                  ],
                );
              }
            } catch (_) {}
            // Responses tool calling follow-up handling
            final bool hasRespCalls =
                respToolCallsByIndex.isNotEmpty || toolAccResp.isNotEmpty;
            if (onToolCall != null && hasRespCalls) {
              // Prefer the indexed calls (with call_id); fallback to toolAccResp
              final callInfos = <ToolCallInfo>[];
              final msgs = <Map<String, dynamic>>[]; // for executing tools
              if (respToolCallsByIndex.isNotEmpty) {
                final sorted = respToolCallsByIndex.keys.toList()..sort();
                for (final idx in sorted) {
                  final m = respToolCallsByIndex[idx]!;
                  final callId = (m['call_id'] ?? '').toString();
                  final name = (m['name'] ?? '').toString();
                  Map<String, dynamic> args;
                  try {
                    args = (jsonDecode(m['args'] ?? '{}') as Map)
                        .cast<String, dynamic>();
                  } catch (_) {
                    args = <String, dynamic>{};
                  }
                  callInfos.add(
                    ToolCallInfo(
                      id: callId.isNotEmpty ? callId : 'call_$idx',
                      name: name,
                      arguments: args,
                    ),
                  );
                  msgs.add({
                    '__id': callId.isNotEmpty ? callId : 'call_$idx',
                    '__name': name,
                    '__args': args,
                  });
                }
              } else {
                int idx = 0;
                toolAccResp.forEach((key, m) {
                  Map<String, dynamic> args;
                  try {
                    args = (jsonDecode(m['args'] ?? '{}') as Map)
                        .cast<String, dynamic>();
                  } catch (_) {
                    args = <String, dynamic>{};
                  }
                  final id2 = key.isNotEmpty ? key : 'call_$idx';
                  callInfos.add(
                    ToolCallInfo(
                      id: id2,
                      name: (m['name'] ?? ''),
                      arguments: args,
                    ),
                  );
                  msgs.add({
                    '__id': id2,
                    '__name': (m['name'] ?? ''),
                    '__args': args,
                  });
                  idx += 1;
                });
              }
              if (callInfos.isNotEmpty) {
                final approxTotal =
                    approxPromptTokens +
                    approxTokensFromChars(approxCompletionChars);
                yield ChatStreamChunk(
                  content: '',
                  isDone: false,
                  totalTokens: usage?.totalTokens ?? approxTotal,
                  usage: usage,
                  toolCalls: callInfos,
                );
              }
              final resultsInfo = <ToolResultInfo>[];
              final followUpOutputs = <Map<String, dynamic>>[];
              for (final m in msgs) {
                final nm = m['__name'] as String;
                final id2 = m['__id'] as String;
                final args = (m['__args'] as Map<String, dynamic>);
                final res = await onToolCall(nm, args);
                resultsInfo.add(
                  ToolResultInfo(
                    id: id2,
                    name: nm,
                    arguments: args,
                    content: res,
                  ),
                );
                followUpOutputs.add({
                  'type': 'function_call_output',
                  'call_id': id2,
                  'output': res,
                });
              }
              if (resultsInfo.isNotEmpty) {
                yield ChatStreamChunk(
                  content: '',
                  isDone: false,
                  totalTokens: usage?.totalTokens ?? 0,
                  usage: usage,
                  toolResults: resultsInfo,
                );
              }

              // Build follow-up Responses request input
              List<Map<String, dynamic>> currentInput = <Map<String, dynamic>>[
                ...responsesInitialInput,
              ];
              if (lastResponseOutputItems.isNotEmpty) {
                currentInput.addAll(lastResponseOutputItems);
              }
              currentInput.addAll(followUpOutputs);

              // Iteratively request until no more tool calls
              for (int round = 0; round < 3; round++) {
                final body2 = <String, dynamic>{
                  'model': upstreamModelId,
                  'input': currentInput,
                  'stream': true,
                  if (responsesToolsSpec.isNotEmpty)
                    'tools': responsesToolsSpec,
                  if (responsesToolsSpec.isNotEmpty) 'tool_choice': 'auto',
                  if (responsesInstructions.isNotEmpty)
                    'instructions': responsesInstructions,
                  if (temperature != null) 'temperature': temperature,
                  if (topP != null) 'top_p': topP,
                  if (maxTokens != null) 'max_output_tokens': maxTokens,
                  if (isReasoning && effort != 'off')
                    'reasoning': {
                      'summary': 'auto',
                      if (effort != 'auto') 'effort': effort,
                    },
                  if (responsesIncludeParam != null)
                    'include': responsesIncludeParam,
                };
                _applyCompatibleResponsesReasoning(
                  body2,
                  config: config,
                  modelId: modelId,
                  upstreamModelId: upstreamModelId,
                  isReasoning: isReasoning,
                  thinkingBudget: thinkingBudget,
                );

                // Apply overrides
                final extraCfg = _customBody(config, modelId);
                if (extraCfg.isNotEmpty) body2.addAll(extraCfg);
                if (extraBody != null && extraBody.isNotEmpty) {
                  extraBody.forEach((k, v) {
                    body2[k] = (v is String) ? _parseOverrideValue(v) : v;
                  });
                }
                // Ensure tools are flattened
                try {
                  if (body2['tools'] is List) {
                    final raw = (body2['tools'] as List).cast<dynamic>();
                    body2['tools'] = _toResponsesToolsFormat(
                      raw
                          .map((e) => (e as Map).cast<String, dynamic>())
                          .toList(),
                    );
                  }
                } catch (_) {}

                _sanitizeOpenAIGpt5SamplingParams(
                  body2,
                  upstreamModelId,
                  fallbackEffort: effort,
                );

                final req2 = http.Request('POST', url);
                final headers2 = <String, String>{
                  'Authorization':
                      'Bearer ${_apiKeyForRequest(config, modelId)}',
                  'Content-Type': 'application/json',
                  'Accept': 'text/event-stream',
                };
                headers2.addAll(_customHeaders(config, modelId));
                if (extraHeaders != null && extraHeaders.isNotEmpty) {
                  headers2.addAll(extraHeaders);
                }
                req2.headers.addAll(headers2);
                req2.body = jsonEncode(body2);
                final resp2 = await client.send(req2);
                if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
                  final errorBody = await resp2.stream.bytesToString();
                  throw HttpException('HTTP ${resp2.statusCode}: $errorBody');
                }
                final s2 = resp2.stream.transform(utf8.decoder);
                String buf2 = '';
                final Map<int, Map<String, String>> respCalls2 =
                    <int, Map<String, String>>{};
                List<Map<String, dynamic>> outItems2 =
                    const <Map<String, dynamic>>[];
                await for (final ch in s2) {
                  buf2 += ch;
                  final lines2 = buf2.split('\n');
                  buf2 = lines2.last;
                  for (int j = 0; j < lines2.length - 1; j++) {
                    final l = lines2[j].trim();
                    if (l.isEmpty || !l.startsWith('data:')) continue;
                    final d = l.substring(5).trimLeft();
                    if (d == '[DONE]') continue;
                    try {
                      final o = jsonDecode(d);
                      if (o is Map &&
                          (o['type'] ?? '') == 'response.output_text.delta') {
                        final delta = (o['delta'] ?? '').toString();
                        if (delta.isNotEmpty) {
                          approxCompletionChars += delta.length;
                          yield ChatStreamChunk(
                            content: delta,
                            isDone: false,
                            totalTokens: 0,
                            usage: usage,
                          );
                        }
                      } else if (o is Map &&
                          (o['type'] ?? '') == 'response.output_item.added') {
                        final item = o['item'];
                        final idx2 = (o['output_index'] ?? 0) as int;
                        if (item is Map &&
                            (item['type'] ?? '') == 'function_call') {
                          respCalls2[idx2] = {
                            'call_id': (item['call_id'] ?? '').toString(),
                            'name': (item['name'] ?? '').toString(),
                            'args': '',
                          };
                        }
                      } else if (o is Map &&
                          (o['type'] ?? '') ==
                              'response.function_call_arguments.delta') {
                        final idx2 = (o['output_index'] ?? 0) as int;
                        final delta = (o['delta'] ?? '').toString();
                        final entry = respCalls2.putIfAbsent(
                          idx2,
                          () => {'call_id': '', 'name': '', 'args': ''},
                        );
                        if (delta.isNotEmpty) {
                          entry['args'] = (entry['args'] ?? '') + delta;
                        }
                      } else if (o is Map &&
                          (o['type'] ?? '') == 'response.output_item.done') {
                        final item = o['item'];
                        final idx2 = (o['output_index'] ?? 0) as int;
                        if (item is Map &&
                            (item['type'] ?? '') == 'function_call') {
                          final args = (item['arguments'] ?? '').toString();
                          final entry = respCalls2.putIfAbsent(
                            idx2,
                            () => {
                              'call_id': (item['call_id'] ?? '').toString(),
                              'name': (item['name'] ?? '').toString(),
                              'args': '',
                            },
                          );
                          if (args.isNotEmpty) entry['args'] = args;
                        }
                      } else if (o is Map &&
                          (o['type'] ?? '') == 'response.completed') {
                        // usage
                        final u2 = o['response']?['usage'];
                        if (u2 != null) {
                          final inTok = (u2['input_tokens'] ?? 0) as int;
                          final outTok = (u2['output_tokens'] ?? 0) as int;
                          usage = (usage ?? const TokenUsage()).merge(
                            TokenUsage(
                              promptTokens: inTok,
                              completionTokens: outTok,
                            ),
                          );
                          totalTokens = usage.totalTokens;
                        }
                        // capture output items
                        final out2 = o['response']?['output'];
                        if (out2 is List) {
                          outItems2 = [
                            for (final it in out2)
                              if (it is Map) (it.cast<String, dynamic>()),
                          ];
                        }
                      }
                    } catch (_) {}
                  }
                }

                if (respCalls2.isEmpty) {
                  // No further tool calls; finalize
                  final approxTotal2 =
                      approxPromptTokens +
                      approxTokensFromChars(approxCompletionChars);
                  yield ChatStreamChunk(
                    content: '',
                    reasoning: null,
                    isDone: true,
                    totalTokens: usage?.totalTokens ?? approxTotal2,
                    usage: usage,
                  );
                  return;
                }

                // Execute next round of tool calls
                final callInfos2 = <ToolCallInfo>[];
                final msgs2 = <Map<String, dynamic>>[];
                final sorted2 = respCalls2.keys.toList()..sort();
                for (final idx2 in sorted2) {
                  final m2 = respCalls2[idx2]!;
                  final callId2 = (m2['call_id'] ?? '').toString();
                  final name2 = (m2['name'] ?? '').toString();
                  Map<String, dynamic> args2;
                  try {
                    args2 = (jsonDecode(m2['args'] ?? '{}') as Map)
                        .cast<String, dynamic>();
                  } catch (_) {
                    args2 = <String, dynamic>{};
                  }
                  callInfos2.add(
                    ToolCallInfo(
                      id: callId2.isNotEmpty ? callId2 : 'call_$idx2',
                      name: name2,
                      arguments: args2,
                    ),
                  );
                  msgs2.add({
                    '__id': callId2.isNotEmpty ? callId2 : 'call_$idx2',
                    '__name': name2,
                    '__args': args2,
                  });
                }
                if (callInfos2.isNotEmpty) {
                  final approxTotal =
                      approxPromptTokens +
                      approxTokensFromChars(approxCompletionChars);
                  yield ChatStreamChunk(
                    content: '',
                    isDone: false,
                    totalTokens: usage?.totalTokens ?? approxTotal,
                    usage: usage,
                    toolCalls: callInfos2,
                  );
                }
                final resultsInfo2 = <ToolResultInfo>[];
                final followUpOutputs2 = <Map<String, dynamic>>[];
                for (final m in msgs2) {
                  final nm = m['__name'] as String;
                  final id2 = m['__id'] as String;
                  final args2 = (m['__args'] as Map<String, dynamic>);
                  final res2 = await onToolCall(nm, args2);
                  resultsInfo2.add(
                    ToolResultInfo(
                      id: id2,
                      name: nm,
                      arguments: args2,
                      content: res2,
                    ),
                  );
                  followUpOutputs2.add({
                    'type': 'function_call_output',
                    'call_id': id2,
                    'output': res2,
                  });
                }
                if (resultsInfo2.isNotEmpty) {
                  yield ChatStreamChunk(
                    content: '',
                    isDone: false,
                    totalTokens: usage?.totalTokens ?? 0,
                    usage: usage,
                    toolResults: resultsInfo2,
                  );
                }
                // Extend current input with this round's model output and our outputs
                if (outItems2.isNotEmpty) currentInput.addAll(outItems2);
                currentInput.addAll(followUpOutputs2);
              }

              // Safety
              final approxTotal =
                  approxPromptTokens +
                  approxTokensFromChars(approxCompletionChars);
              yield ChatStreamChunk(
                content: '',
                reasoning: null,
                isDone: true,
                totalTokens: usage?.totalTokens ?? approxTotal,
                usage: usage,
              );
              return;
            }

            final approxTotal =
                approxPromptTokens +
                approxTokensFromChars(approxCompletionChars);
            yield ChatStreamChunk(
              content: '',
              reasoning: null,
              isDone: true,
              totalTokens: usage?.totalTokens ?? approxTotal,
              usage: usage,
            );
            return;
          } else {
            // Fallback for providers that inline output
            final output = json['output'];
            if (output != null) {
              content = (output['content'] ?? '').toString();
              approxCompletionChars += content.length;
              final u = json['usage'];
              if (u != null) {
                final inTok = (u['input_tokens'] ?? 0) as int;
                final outTok = (u['output_tokens'] ?? 0) as int;
                usage = (usage ?? const TokenUsage()).merge(
                  TokenUsage(promptTokens: inTok, completionTokens: outTok),
                );
                totalTokens = usage.totalTokens;
              }
            }
          }
        } else {
          // Handle standard OpenAI Chat Completions format
          final choices = json['choices'];
          if (choices != null && choices.isNotEmpty) {
            final c0 = choices[0];
            finishReason = c0['finish_reason'] as String?;
            // if (finishReason != null) {
            //   print('[ChatApi] Received finishReason from choices: $finishReason');
            // }

            // Some providers may include both delta and message.content in SSE chunks.
            // Prioritize delta, then fallback to message.content; merge if both present.
            final message = c0['message'];
            final delta = c0['delta'];

            // 1) Parse delta first
            if (delta != null) {
              // Streaming format: choices[0].delta.content
              final dc = delta['content'];
              final deltaContent = _extractOpenAICompatibleDeltaText(delta);
              if (deltaContent.isNotEmpty) {
                content += deltaContent;
                approxCompletionChars += deltaContent.length;
              }

              // reasoning_content handling (unchanged)
              final rc =
                  (delta['reasoning_content'] ?? delta['reasoning']) as String?;
              if (rc != null && rc.isNotEmpty) {
                reasoning = rc;
                if (needsReasoningEcho) reasoningBuffer += rc;
              }
              if (preserveReasoningDetails) {
                final rd = delta['reasoning_details'];
                if (rd is List && rd.isNotEmpty) reasoningDetailsBuffer = rd;
              }

              // images handling from delta (unchanged)
              if (wantsImageOutput) {
                final List<dynamic> imageItems = <dynamic>[];
                final imgs = delta['images'];
                if (imgs is List) imageItems.addAll(imgs);
                if (dc is List) {
                  for (final it in dc) {
                    if (it is Map &&
                        (it['type'] == 'image_url' || it['type'] == 'image')) {
                      imageItems.add(it);
                    }
                  }
                }
                final singleImage = delta['image_url'];
                if (singleImage is Map || singleImage is String) {
                  imageItems.add({
                    'type': 'image_url',
                    'image_url': singleImage,
                  });
                }
                if (imageItems.isNotEmpty) {
                  final buf = StringBuffer();
                  for (final it in imageItems) {
                    if (it is! Map) continue;
                    dynamic iu = it['image_url'];
                    String? url;
                    if (iu is String) {
                      url = iu;
                    } else if (iu is Map) {
                      final u2 = iu['url'];
                      if (u2 is String) url = u2;
                    }
                    if (url != null && url.isNotEmpty) {
                      buf.write('\n\n![image]($url)');
                    }
                  }
                  if (buf.isNotEmpty) content = content + buf.toString();
                }
              }

              // tool_calls handling from delta (unchanged)
              final tcs = delta['tool_calls'] as List?;
              if (tcs != null) {
                for (final t in tcs) {
                  final idx = (t['index'] as int?) ?? 0;
                  final id = t['id'] as String?;
                  final func = t['function'] as Map<String, dynamic>?;
                  final name = func?['name'] as String?;
                  final argsDelta = func?['arguments'] as String?;
                  final entry = toolAcc.putIfAbsent(
                    idx,
                    () => {'id': '', 'name': '', 'args': ''},
                  );
                  if (id != null) entry['id'] = id;
                  if (name != null && name.isNotEmpty) entry['name'] = name;
                  if (argsDelta != null && argsDelta.isNotEmpty) {
                    entry['args'] = (entry['args'] ?? '') + argsDelta;
                  }
                }
              }
            }

            if (preserveReasoningDetails && message != null) {
              final rdMsg = message['reasoning_details'];
              if (rdMsg is List && rdMsg.isNotEmpty) {
                reasoningDetailsBuffer = rdMsg;
              }
            }

            // 2) Fallback and merge: parse choices[0].message.content
            if (message != null && message['content'] != null) {
              final mc = message['content'];
              String messageContent = '';
              if (mc is String) {
                messageContent = mc;
              } else if (mc is List) {
                final sb = StringBuffer();
                for (final it in mc) {
                  if (it is Map) {
                    final t = (it['text'] ?? '') as String? ?? '';
                    if (t.isNotEmpty &&
                        (it['type'] == null || it['type'] == 'text')) {
                      sb.write(t);
                    }
                  }
                }
                messageContent = sb.toString();
              } else {
                messageContent = (mc ?? '').toString();
              }
              if (messageContent.isNotEmpty) {
                content += messageContent;
                approxCompletionChars += messageContent.length;
              }

              // Capture reasoning_content if only present on the message object
              if (message != null) {
                final rcMsg =
                    message['reasoning_content'] ?? message['reasoning'];
                if (rcMsg is String && rcMsg.isNotEmpty) {
                  if (needsReasoningEcho) reasoningBuffer += rcMsg;
                  reasoning ??= rcMsg;
                }
              }

              // images handling from message content (unchanged)
              if (wantsImageOutput && mc is List) {
                final List<dynamic> imageItems = <dynamic>[];
                for (final it in mc) {
                  if (it is Map &&
                      (it['type'] == 'image_url' || it['type'] == 'image')) {
                    imageItems.add(it);
                  }
                }
                if (imageItems.isNotEmpty) {
                  final buf = StringBuffer();
                  for (final it in imageItems) {
                    if (it is! Map) continue;
                    dynamic iu = it['image_url'];
                    String? url;
                    if (iu is String) {
                      url = iu;
                    } else if (iu is Map) {
                      final u2 = iu['url'];
                      if (u2 is String) url = u2;
                    }
                    if (url != null && url.isNotEmpty) {
                      buf.write('\n\n![image]($url)');
                    }
                  }
                  if (buf.isNotEmpty) content = content + buf.toString();
                }
              }
            }
          }
          // XinLiu (iflow.cn) compatibility: tool_calls at root level instead of delta
          final rootToolCalls = json['tool_calls'] as List?;
          if (rootToolCalls != null) {
            // print('[ChatApi/XinLiu] Detected root-level tool_calls, count: ${rootToolCalls.length}, original finishReason: $finishReason');
            // print('[ChatApi/XinLiu] Full JSON keys: ${json.keys.toList()}');
            // print('[ChatApi/XinLiu] Full JSON: ${jsonEncode(json)}');
            for (final t in rootToolCalls) {
              if (t is! Map) continue;
              final id = (t['id'] ?? '').toString();
              final type = (t['type'] ?? 'function').toString();
              if (type != 'function') continue;
              final func = t['function'] as Map<String, dynamic>?;
              if (func == null) continue;
              final name = (func['name'] ?? '').toString();
              final argsStr = (func['arguments'] ?? '').toString();
              if (name.isEmpty) continue;
              // print('[ChatApi/XinLiu] Tool call: id=$id, name=$name, args=${argsStr.length} chars');
              final idx = toolAcc.length;
              final entry = toolAcc.putIfAbsent(
                idx,
                () => {
                  'id': id.isEmpty ? 'call_$idx' : id,
                  'name': name,
                  'args': argsStr,
                },
              );
              if (id.isNotEmpty) entry['id'] = id;
              entry['name'] = name;
              entry['args'] = argsStr;
            }
            // When root-level tool_calls are present, always treat as tool_calls finish reason
            // (override any other finish_reason from provider)
            if (rootToolCalls.isNotEmpty) {
              // print('[ChatApi/XinLiu] Overriding finishReason from "$finishReason" to "tool_calls"');
              finishReason = 'tool_calls';
            }
          }
          final u = json['usage'];
          if (u != null) {
            final prompt = (u['prompt_tokens'] ?? 0) as int;
            final completion = (u['completion_tokens'] ?? 0) as int;
            final cached =
                (u['prompt_tokens_details']?['cached_tokens'] ?? 0) as int? ??
                0;
            usage = (usage ?? const TokenUsage()).merge(
              TokenUsage(
                promptTokens: prompt,
                completionTokens: completion,
                cachedTokens: cached,
              ),
            );
            totalTokens = usage.totalTokens;
          }
        }

        if (content.isNotEmpty || (reasoning?.isNotEmpty ?? false)) {
          final approxTotal =
              approxPromptTokens + approxTokensFromChars(approxCompletionChars);
          yield ChatStreamChunk(
            content: content,
            reasoning: reasoning,
            isDone: false,
            totalTokens: totalTokens > 0 ? totalTokens : approxTotal,
            usage: usage,
          );
        }

        // Some providers (e.g., OpenRouter) may omit the [DONE] sentinel
        // and only send finish_reason on the last delta. If we see a
        // definitive finish that's not tool_calls, end the stream now so
        // the UI can persist the message.
        // XinLiu compatibility: Execute tools immediately if we have finish_reason='tool_calls' and accumulated calls
        if (config.useResponseApi != true &&
            finishReason == 'tool_calls' &&
            toolAcc.isNotEmpty &&
            onToolCall != null) {
          // print('[ChatApi/XinLiu] Executing tools immediately (finishReason=tool_calls, toolAcc.size=${toolAcc.length})');
          // Some providers (like XinLiu) return tool_calls with finish_reason='tool_calls' but no [DONE]
          // Execute tools immediately in this case
          final calls = <Map<String, dynamic>>[];
          final callInfos = <ToolCallInfo>[];
          final toolMsgs = <Map<String, dynamic>>[];
          toolAcc.forEach((idx, m) {
            final id = (m['id'] ?? 'call_$idx');
            final name = (m['name'] ?? '');
            Map<String, dynamic> args;
            try {
              args = (jsonDecode(m['args'] ?? '{}') as Map)
                  .cast<String, dynamic>();
            } catch (_) {
              args = <String, dynamic>{};
            }
            callInfos.add(ToolCallInfo(id: id, name: name, arguments: args));
            calls.add({
              'id': id,
              'type': 'function',
              'function': {'name': name, 'arguments': jsonEncode(args)},
            });
            toolMsgs.add({'__name': name, '__id': id, '__args': args});
          });
          if (callInfos.isNotEmpty) {
            final approxTotal =
                approxPromptTokens +
                approxTokensFromChars(approxCompletionChars);
            yield ChatStreamChunk(
              content: '',
              isDone: false,
              totalTokens: usage?.totalTokens ?? approxTotal,
              usage: usage,
              toolCalls: callInfos,
            );
          }
          // Execute tools and emit results
          final results = <Map<String, dynamic>>[];
          final resultsInfo = <ToolResultInfo>[];
          for (final m in toolMsgs) {
            final name = m['__name'] as String;
            final id = m['__id'] as String;
            final args = (m['__args'] as Map<String, dynamic>);
            final res = await onToolCall(name, args);
            results.add({'tool_call_id': id, 'content': res});
            resultsInfo.add(
              ToolResultInfo(id: id, name: name, arguments: args, content: res),
            );
          }
          if (resultsInfo.isNotEmpty) {
            yield ChatStreamChunk(
              content: '',
              isDone: false,
              totalTokens: usage?.totalTokens ?? 0,
              usage: usage,
              toolResults: resultsInfo,
            );
          }
          // Build follow-up messages
          final mm2 = <Map<String, dynamic>>[];
          for (final m in messages) {
            mm2.add(_copyChatCompletionMessage(m));
          }
          final assistantToolCallMsg = <String, dynamic>{
            'role': 'assistant',
            'content': '\n\n',
            'tool_calls': calls,
          };
          if (needsReasoningEcho) {
            assistantToolCallMsg['reasoning_content'] = reasoningBuffer;
          }
          if (preserveReasoningDetails &&
              reasoningDetailsBuffer is List &&
              reasoningDetailsBuffer.isNotEmpty) {
            assistantToolCallMsg['reasoning_details'] = reasoningDetailsBuffer;
          }
          mm2.add(assistantToolCallMsg);
          for (final r in results) {
            final id = r['tool_call_id'];
            final name = calls.firstWhere(
              (c) => c['id'] == id,
              orElse: () => const {
                'function': {'name': ''},
              },
            )['function']['name'];
            mm2.add({
              'role': 'tool',
              'tool_call_id': id,
              'name': name,
              'content': r['content'],
            });
          }
          // Continue streaming with follow-up request
          var currentMessages = mm2;
          while (true) {
            final Map<String, dynamic> body2 = useLongCatOmniPayload
                ? {
                    'model': upstreamModelId,
                    'messages': await _buildLongCatOmniMessages(
                      currentMessages,
                      userMediaPaths: userImagePaths,
                    ),
                    'stream': true,
                    'output_modalities': const ['text'],
                    if (temperature != null) 'temperature': temperature,
                    if (topP != null) 'top_p': topP,
                    if (isReasoning && effort != 'off' && effort != 'auto')
                      'reasoning_effort': effort,
                    if (tools != null && tools.isNotEmpty)
                      'tools': _cleanToolsForCompatibility(tools),
                    if (tools != null && tools.isNotEmpty)
                      'tool_choice': 'auto',
                  }
                : {
                    'model': upstreamModelId,
                    'messages': currentMessages,
                    'stream': true,
                    if (temperature != null) 'temperature': temperature,
                    if (topP != null) 'top_p': topP,
                    if (isReasoning && effort != 'off' && effort != 'auto')
                      'reasoning_effort': effort,
                    if (tools != null && tools.isNotEmpty)
                      'tools': _cleanToolsForCompatibility(tools),
                    if (tools != null && tools.isNotEmpty)
                      'tool_choice': 'auto',
                  };
            setMaxTokens(body2);
            final off = _isOff(thinkingBudget);
            if (host.contains('openrouter.ai')) {
              if (isReasoning) {
                if (off) {
                  body2['reasoning'] = {'enabled': false};
                } else {
                  final obj = <String, dynamic>{'enabled': true};
                  if (thinkingBudget != null && thinkingBudget > 0) {
                    obj['max_tokens'] = thinkingBudget;
                  }
                  body2['reasoning'] = obj;
                }
                body2.remove('reasoning_effort');
              } else {
                body2.remove('reasoning');
                body2.remove('reasoning_effort');
              }
            } else if (host.contains('dashscope') || host.contains('aliyun')) {
              if (isReasoning) {
                body2['enable_thinking'] = !off;
                if (!off && thinkingBudget != null && thinkingBudget > 0) {
                  body2['thinking_budget'] = thinkingBudget;
                } else {
                  body2.remove('thinking_budget');
                }
              } else {
                body2.remove('enable_thinking');
                body2.remove('thinking_budget');
              }
              body2.remove('reasoning_effort');
            } else if (host.contains('open.bigmodel.cn') ||
                host.contains('bigmodel') ||
                isMimo) {
              if (isReasoning) {
                body2['thinking'] = {'type': off ? 'disabled' : 'enabled'};
              } else {
                body2.remove('thinking');
              }
              body2.remove('reasoning_effort');
            } else if (host.contains('ark.cn-beijing.volces.com') ||
                host.contains('volc') ||
                host.contains('ark')) {
              if (isReasoning) {
                body2['thinking'] = {'type': off ? 'disabled' : 'enabled'};
              } else {
                body2.remove('thinking');
              }
              body2.remove('reasoning_effort');
            } else if (host.contains('intern-ai') ||
                host.contains('intern') ||
                host.contains('chat.intern-ai.org.cn')) {
              if (isReasoning) {
                body2['thinking_mode'] = !off;
              } else {
                body2.remove('thinking_mode');
              }
              body2.remove('reasoning_effort');
            } else if (host.contains('siliconflow')) {
              if (isReasoning) {
                if (off) {
                  body2['enable_thinking'] = false;
                } else {
                  body2.remove('enable_thinking');
                }
              } else {
                body2.remove('enable_thinking');
              }
              body2.remove('reasoning_effort');
            } else if (host.contains('deepseek') ||
                upstreamModelId.toLowerCase().contains('deepseek')) {
              if (isReasoning) {
                if (off) {
                  body2['reasoning_content'] = false;
                  body2.remove('reasoning_budget');
                } else {
                  body2['reasoning_content'] = true;
                  if (thinkingBudget != null && thinkingBudget > 0) {
                    body2['reasoning_budget'] = thinkingBudget;
                  } else {
                    body2.remove('reasoning_budget');
                  }
                }
              } else {
                body2.remove('reasoning_content');
                body2.remove('reasoning_budget');
              }
            }
            _applyCompatibleBuiltInSearch(
              body2,
              config: config,
              modelId: modelId,
              upstreamModelId: upstreamModelId,
            );
            _maybeAddStreamingUsageOptions(
              body2,
              stream: true,
              config: config,
              host: host,
              upstreamModelId: upstreamModelId,
            );
            if (extraBodyCfg.isNotEmpty) {
              body2.addAll(extraBodyCfg);
            }
            if (extraBody != null && extraBody.isNotEmpty) {
              extraBody.forEach((k, v) {
                body2[k] = (v is String) ? _parseOverrideValue(v) : v;
              });
            }
            _sanitizeOpenAIGpt5SamplingParams(
              body2,
              upstreamModelId,
              fallbackEffort: effort,
            );
            final req2 = http.Request('POST', url);
            final headers2 = <String, String>{
              'Authorization': 'Bearer ${_effectiveApiKey(config)}',
              'Content-Type': 'application/json',
              'Accept': 'text/event-stream',
            };
            headers2.addAll(_customHeaders(config, modelId));
            if (extraHeaders != null && extraHeaders.isNotEmpty) {
              headers2.addAll(extraHeaders);
            }
            req2.headers.addAll(headers2);
            req2.body = jsonEncode(body2);
            final resp2 = await client.send(req2);
            if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
              final errorBody = await resp2.stream.bytesToString();
              throw HttpException('HTTP ${resp2.statusCode}: $errorBody');
            }
            final s2 = resp2.stream.transform(utf8.decoder);
            String buf2 = '';
            final Map<int, Map<String, String>> toolAcc2 =
                <int, Map<String, String>>{};
            String? finishReason2;
            String contentAccum = '';
            String reasoningAccum = '';
            dynamic reasoningDetailsAccum;
            await for (final ch in s2) {
              buf2 += ch;
              final lines2 = buf2.split('\n');
              buf2 = lines2.last;
              for (int j = 0; j < lines2.length - 1; j++) {
                final l = lines2[j].trim();
                if (l.isEmpty || !l.startsWith('data:')) continue;
                final d = l.substring(5).trimLeft();
                if (d == '[DONE]') {
                  continue;
                }
                try {
                  final o = jsonDecode(d);
                  if (o is Map &&
                      o['choices'] is List &&
                      (o['choices'] as List).isNotEmpty) {
                    final c0 = (o['choices'] as List).first;
                    finishReason2 = c0['finish_reason'] as String?;
                    final delta = c0['delta'] as Map?;
                    final txt = _extractOpenAICompatibleDeltaText(delta);
                    final rc =
                        delta?['reasoning_content'] ?? delta?['reasoning'];
                    final u = o['usage'];
                    if (u != null) {
                      final prompt = (u['prompt_tokens'] ?? 0) as int;
                      final completion = (u['completion_tokens'] ?? 0) as int;
                      final cached =
                          (u['prompt_tokens_details']?['cached_tokens'] ?? 0)
                              as int? ??
                          0;
                      usage = (usage ?? const TokenUsage()).merge(
                        TokenUsage(
                          promptTokens: prompt,
                          completionTokens: completion,
                          cachedTokens: cached,
                        ),
                      );
                      totalTokens = usage.totalTokens;
                    }
                    // Capture Grok citations
                    final gCitations = o['citations'];
                    if (gCitations is List && gCitations.isNotEmpty) {
                      final items = <Map<String, dynamic>>[];
                      for (int k = 0; k < gCitations.length; k++) {
                        final u = gCitations[k].toString();
                        items.add({'index': k + 1, 'url': u, 'title': u});
                      }
                      if (items.isNotEmpty) {
                        final payload = jsonEncode({'items': items});
                        yield ChatStreamChunk(
                          content: '',
                          isDone: false,
                          totalTokens: usage?.totalTokens ?? 0,
                          usage: usage,
                          toolResults: [
                            ToolResultInfo(
                              id: 'builtin_search',
                              name: 'search_web',
                              arguments: const <String, dynamic>{},
                              content: payload,
                            ),
                          ],
                        );
                      }
                    }
                    if (rc is String && rc.isNotEmpty) {
                      if (needsReasoningEcho) reasoningAccum += rc;
                      yield ChatStreamChunk(
                        content: '',
                        reasoning: rc,
                        isDone: false,
                        totalTokens: 0,
                        usage: usage,
                      );
                    }
                    if (txt.isNotEmpty) {
                      contentAccum += txt;
                      yield ChatStreamChunk(
                        content: txt,
                        isDone: false,
                        totalTokens: 0,
                        usage: usage,
                      );
                    }
                    if (wantsImageOutput) {
                      final List<dynamic> imageItems = <dynamic>[];
                      final imgs = delta?['images'];
                      if (imgs is List) imageItems.addAll(imgs);
                      final contentArr = delta?['content'] as List?;
                      if (contentArr is List) {
                        for (final it in contentArr) {
                          if (it is Map &&
                              (it['type'] == 'image_url' ||
                                  it['type'] == 'image')) {
                            imageItems.add(it);
                          }
                        }
                      }
                      final singleImage = delta?['image_url'];
                      if (singleImage is Map || singleImage is String) {
                        imageItems.add({
                          'type': 'image_url',
                          'image_url': singleImage,
                        });
                      }
                      if (imageItems.isNotEmpty) {
                        final buf = StringBuffer();
                        for (final it in imageItems) {
                          if (it is! Map) continue;
                          dynamic iu = it['image_url'];
                          String? url;
                          if (iu is String) {
                            url = iu;
                          } else if (iu is Map) {
                            final u2 = iu['url'];
                            if (u2 is String) url = u2;
                          }
                          if (url != null && url.isNotEmpty) {
                            final md = '\n\n![image]($url)';
                            buf.write(md);
                            contentAccum += md;
                          }
                        }
                        final out = buf.toString();
                        if (out.isNotEmpty) {
                          yield ChatStreamChunk(
                            content: out,
                            isDone: false,
                            totalTokens: 0,
                            usage: usage,
                          );
                        }
                      }
                    }
                    final tcs = delta?['tool_calls'] as List?;
                    if (tcs != null) {
                      for (final t in tcs) {
                        final idx = (t['index'] as int?) ?? 0;
                        final id = t['id'] as String?;
                        final func = t['function'] as Map<String, dynamic>?;
                        final name = func?['name'] as String?;
                        final argsDelta = func?['arguments'] as String?;
                        final entry = toolAcc2.putIfAbsent(
                          idx,
                          () => {'id': '', 'name': '', 'args': ''},
                        );
                        if (id != null) entry['id'] = id;
                        if (name != null && name.isNotEmpty) {
                          entry['name'] = name;
                        }
                        if (argsDelta != null && argsDelta.isNotEmpty) {
                          entry['args'] = (entry['args'] ?? '') + argsDelta;
                        }
                      }
                    }

                    // Fallback/merge: message.content in same chunk (if any)
                    final message = c0['message'] as Map?;
                    if (message != null && message['content'] != null) {
                      final mc = message['content'];
                      if (mc is String && mc.isNotEmpty) {
                        contentAccum += mc;
                        yield ChatStreamChunk(
                          content: mc,
                          isDone: false,
                          totalTokens: 0,
                          usage: usage,
                        );
                      }
                    }
                    if (message != null) {
                      final rcMsg =
                          message['reasoning_content'] ?? message['reasoning'];
                      if (rcMsg is String &&
                          rcMsg.isNotEmpty &&
                          needsReasoningEcho) {
                        reasoningAccum += rcMsg;
                      }
                    }
                    if (preserveReasoningDetails) {
                      final rd = delta?['reasoning_details'];
                      if (rd is List && rd.isNotEmpty) {
                        reasoningDetailsAccum = rd;
                      }
                      final rdMsg = message?['reasoning_details'];
                      if (rdMsg is List && rdMsg.isNotEmpty) {
                        reasoningDetailsAccum = rdMsg;
                      }
                    }
                  }
                  // XinLiu compatibility for follow-up requests too
                  final rootToolCalls2 = o['tool_calls'] as List?;
                  if (rootToolCalls2 != null) {
                    for (final t in rootToolCalls2) {
                      if (t is! Map) continue;
                      final id = (t['id'] ?? '').toString();
                      final type = (t['type'] ?? 'function').toString();
                      if (type != 'function') continue;
                      final func = t['function'] as Map<String, dynamic>?;
                      if (func == null) continue;
                      final name = (func['name'] ?? '').toString();
                      final argsStr = (func['arguments'] ?? '').toString();
                      if (name.isEmpty) continue;
                      final idx = toolAcc2.length;
                      final entry = toolAcc2.putIfAbsent(
                        idx,
                        () => {
                          'id': id.isEmpty ? 'call_$idx' : id,
                          'name': name,
                          'args': argsStr,
                        },
                      );
                      if (id.isNotEmpty) entry['id'] = id;
                      entry['name'] = name;
                      entry['args'] = argsStr;
                    }
                    if (rootToolCalls2.isNotEmpty) {
                      finishReason2 = 'tool_calls';
                    }
                  }
                } catch (_) {}
              }
            }
            if (finishReason2 == 'tool_calls' || toolAcc2.isNotEmpty) {
              final calls2 = <Map<String, dynamic>>[];
              final callInfos2 = <ToolCallInfo>[];
              final toolMsgs2 = <Map<String, dynamic>>[];
              toolAcc2.forEach((idx, m) {
                final id = (m['id'] ?? 'call_$idx');
                final name = (m['name'] ?? '');
                Map<String, dynamic> args;
                try {
                  args = (jsonDecode(m['args'] ?? '{}') as Map)
                      .cast<String, dynamic>();
                } catch (_) {
                  args = <String, dynamic>{};
                }
                callInfos2.add(
                  ToolCallInfo(id: id, name: name, arguments: args),
                );
                calls2.add({
                  'id': id,
                  'type': 'function',
                  'function': {'name': name, 'arguments': jsonEncode(args)},
                });
                toolMsgs2.add({'__name': name, '__id': id, '__args': args});
              });
              if (callInfos2.isNotEmpty) {
                yield ChatStreamChunk(
                  content: '',
                  isDone: false,
                  totalTokens: usage?.totalTokens ?? 0,
                  usage: usage,
                  toolCalls: callInfos2,
                );
              }
              final results2 = <Map<String, dynamic>>[];
              final resultsInfo2 = <ToolResultInfo>[];
              for (final m in toolMsgs2) {
                final name = m['__name'] as String;
                final id = m['__id'] as String;
                final args = (m['__args'] as Map<String, dynamic>);
                final res = await onToolCall(name, args);
                results2.add({'tool_call_id': id, 'content': res});
                resultsInfo2.add(
                  ToolResultInfo(
                    id: id,
                    name: name,
                    arguments: args,
                    content: res,
                  ),
                );
              }
              if (resultsInfo2.isNotEmpty) {
                yield ChatStreamChunk(
                  content: '',
                  isDone: false,
                  totalTokens: usage?.totalTokens ?? 0,
                  usage: usage,
                  toolResults: resultsInfo2,
                );
              }
              final nextAssistantToolCall = <String, dynamic>{
                'role': 'assistant',
                'content': '\n\n',
                'tool_calls': calls2,
              };
              if (needsReasoningEcho) {
                nextAssistantToolCall['reasoning_content'] = reasoningAccum;
              }
              if (preserveReasoningDetails &&
                  reasoningDetailsAccum is List &&
                  reasoningDetailsAccum.isNotEmpty) {
                nextAssistantToolCall['reasoning_details'] =
                    reasoningDetailsAccum;
              }
              currentMessages = [
                ...currentMessages,
                if (contentAccum.isNotEmpty)
                  {'role': 'assistant', 'content': contentAccum},
                nextAssistantToolCall,
                for (final r in results2)
                  {
                    'role': 'tool',
                    'tool_call_id': r['tool_call_id'],
                    'name': calls2.firstWhere(
                      (c) => c['id'] == r['tool_call_id'],
                      orElse: () => const {
                        'function': {'name': ''},
                      },
                    )['function']['name'],
                    'content': r['content'],
                  },
              ];
              continue;
            } else {
              final approxTotal =
                  approxPromptTokens +
                  approxTokensFromChars(approxCompletionChars);
              yield ChatStreamChunk(
                content: '',
                isDone: true,
                totalTokens: usage?.totalTokens ?? approxTotal,
                usage: usage,
              );
              return;
            }
          }
        }
        // XinLiu compatibility: Don't end early if we have accumulated tool calls
        if (config.useResponseApi != true &&
            finishReason != null &&
            finishReason != 'tool_calls') {
          final bool hasPendingToolCalls =
              toolAcc.isNotEmpty || toolAccResp.isNotEmpty;
          if (hasPendingToolCalls) {
            // Some providers (like XinLiu/iflow.cn) may return tool_calls with finish_reason='stop'
            // and may not send a [DONE] marker. Execute tools immediately in this case.
            if (onToolCall != null && toolAcc.isNotEmpty) {
              final calls = <Map<String, dynamic>>[];
              final callInfos = <ToolCallInfo>[];
              final toolMsgs = <Map<String, dynamic>>[];
              toolAcc.forEach((idx, m) {
                final id = (m['id'] ?? 'call_$idx');
                final name = (m['name'] ?? '');
                Map<String, dynamic> args;
                try {
                  args = (jsonDecode(m['args'] ?? '{}') as Map)
                      .cast<String, dynamic>();
                } catch (_) {
                  args = <String, dynamic>{};
                }
                callInfos.add(
                  ToolCallInfo(id: id, name: name, arguments: args),
                );
                calls.add({
                  'id': id,
                  'type': 'function',
                  'function': {'name': name, 'arguments': jsonEncode(args)},
                });
                toolMsgs.add({'__name': name, '__id': id, '__args': args});
              });
              if (callInfos.isNotEmpty) {
                final approxTotal =
                    approxPromptTokens +
                    approxTokensFromChars(approxCompletionChars);
                yield ChatStreamChunk(
                  content: '',
                  isDone: false,
                  totalTokens: usage?.totalTokens ?? approxTotal,
                  usage: usage,
                  toolCalls: callInfos,
                );
              }
              // Execute tools and emit results
              final results = <Map<String, dynamic>>[];
              final resultsInfo = <ToolResultInfo>[];
              for (final m in toolMsgs) {
                final name = m['__name'] as String;
                final id = m['__id'] as String;
                final args = (m['__args'] as Map<String, dynamic>);
                final res = await onToolCall(name, args);
                results.add({'tool_call_id': id, 'content': res});
                resultsInfo.add(
                  ToolResultInfo(
                    id: id,
                    name: name,
                    arguments: args,
                    content: res,
                  ),
                );
              }
              if (resultsInfo.isNotEmpty) {
                yield ChatStreamChunk(
                  content: '',
                  isDone: false,
                  totalTokens: usage?.totalTokens ?? 0,
                  usage: usage,
                  toolResults: resultsInfo,
                );
              }
              // Build follow-up messages
              final mm2 = <Map<String, dynamic>>[];
              for (final m in messages) {
                mm2.add(_copyChatCompletionMessage(m));
              }
              final assistantToolCallMsg = <String, dynamic>{
                'role': 'assistant',
                'content': '\n\n',
                'tool_calls': calls,
              };
              if (needsReasoningEcho) {
                assistantToolCallMsg['reasoning_content'] = reasoningBuffer;
              }
              if (preserveReasoningDetails &&
                  reasoningDetailsBuffer is List &&
                  reasoningDetailsBuffer.isNotEmpty) {
                assistantToolCallMsg['reasoning_details'] =
                    reasoningDetailsBuffer;
              }
              mm2.add(assistantToolCallMsg);
              for (final r in results) {
                final id = r['tool_call_id'];
                final name = calls.firstWhere(
                  (c) => c['id'] == id,
                  orElse: () => const {
                    'function': {'name': ''},
                  },
                )['function']['name'];
                mm2.add({
                  'role': 'tool',
                  'tool_call_id': id,
                  'name': name,
                  'content': r['content'],
                });
              }
              // Continue streaming with follow-up request - reuse existing multi-round logic from [DONE] handler
              var currentMessages = mm2;
              while (true) {
                final Map<String, dynamic> body2 = useLongCatOmniPayload
                    ? {
                        'model': upstreamModelId,
                        'messages': await _buildLongCatOmniMessages(
                          currentMessages,
                          userMediaPaths: userImagePaths,
                        ),
                        'stream': true,
                        'output_modalities': const ['text'],
                        if (temperature != null) 'temperature': temperature,
                        if (topP != null) 'top_p': topP,
                        if (isReasoning && effort != 'off' && effort != 'auto')
                          'reasoning_effort': effort,
                        if (tools != null && tools.isNotEmpty)
                          'tools': _cleanToolsForCompatibility(tools),
                        if (tools != null && tools.isNotEmpty)
                          'tool_choice': 'auto',
                      }
                    : {
                        'model': upstreamModelId,
                        'messages': currentMessages,
                        'stream': true,
                        if (temperature != null) 'temperature': temperature,
                        if (topP != null) 'top_p': topP,
                        if (isReasoning && effort != 'off' && effort != 'auto')
                          'reasoning_effort': effort,
                        if (tools != null && tools.isNotEmpty)
                          'tools': _cleanToolsForCompatibility(tools),
                        if (tools != null && tools.isNotEmpty)
                          'tool_choice': 'auto',
                      };
                setMaxTokens(body2);
                final off = _isOff(thinkingBudget);
                if (host.contains('openrouter.ai')) {
                  if (isReasoning) {
                    if (off) {
                      body2['reasoning'] = {'enabled': false};
                    } else {
                      final obj = <String, dynamic>{'enabled': true};
                      if (thinkingBudget != null && thinkingBudget > 0) {
                        obj['max_tokens'] = thinkingBudget;
                      }
                      body2['reasoning'] = obj;
                    }
                    body2.remove('reasoning_effort');
                  } else {
                    body2.remove('reasoning');
                    body2.remove('reasoning_effort');
                  }
                } else if (host.contains('dashscope') ||
                    host.contains('aliyun')) {
                  if (isReasoning) {
                    body2['enable_thinking'] = !off;
                    if (!off && thinkingBudget != null && thinkingBudget > 0) {
                      body2['thinking_budget'] = thinkingBudget;
                    } else {
                      body2.remove('thinking_budget');
                    }
                  } else {
                    body2.remove('enable_thinking');
                    body2.remove('thinking_budget');
                  }
                  body2.remove('reasoning_effort');
                } else if (host.contains('ark.cn-beijing.volces.com') ||
                    host.contains('volc') ||
                    host.contains('ark') ||
                    isMimo) {
                  if (isReasoning) {
                    body2['thinking'] = {'type': off ? 'disabled' : 'enabled'};
                  } else {
                    body2.remove('thinking');
                  }
                  body2.remove('reasoning_effort');
                } else if (host.contains('intern-ai') ||
                    host.contains('intern') ||
                    host.contains('chat.intern-ai.org.cn')) {
                  if (isReasoning) {
                    body2['thinking_mode'] = !off;
                  } else {
                    body2.remove('thinking_mode');
                  }
                  body2.remove('reasoning_effort');
                } else if (host.contains('siliconflow')) {
                  if (isReasoning) {
                    if (off) {
                      body2['enable_thinking'] = false;
                    } else {
                      body2.remove('enable_thinking');
                    }
                  } else {
                    body2.remove('enable_thinking');
                  }
                  body2.remove('reasoning_effort');
                } else if (host.contains('deepseek') ||
                    upstreamModelId.toLowerCase().contains('deepseek')) {
                  if (isReasoning) {
                    if (off) {
                      body2['reasoning_content'] = false;
                      body2.remove('reasoning_budget');
                    } else {
                      body2['reasoning_content'] = true;
                      if (thinkingBudget != null && thinkingBudget > 0) {
                        body2['reasoning_budget'] = thinkingBudget;
                      } else {
                        body2.remove('reasoning_budget');
                      }
                    }
                  } else {
                    body2.remove('reasoning_content');
                    body2.remove('reasoning_budget');
                  }
                }
                _applyCompatibleBuiltInSearch(
                  body2,
                  config: config,
                  modelId: modelId,
                  upstreamModelId: upstreamModelId,
                );
                _maybeAddStreamingUsageOptions(
                  body2,
                  stream: true,
                  config: config,
                  host: host,
                  upstreamModelId: upstreamModelId,
                );
                if (extraBodyCfg.isNotEmpty) {
                  body2.addAll(extraBodyCfg);
                }
                if (extraBody != null && extraBody.isNotEmpty) {
                  extraBody.forEach((k, v) {
                    body2[k] = (v is String) ? _parseOverrideValue(v) : v;
                  });
                }
                _sanitizeOpenAIGpt5SamplingParams(
                  body2,
                  upstreamModelId,
                  fallbackEffort: effort,
                );
                final req2 = http.Request('POST', url);
                final headers2 = <String, String>{
                  'Authorization': 'Bearer ${_effectiveApiKey(config)}',
                  'Content-Type': 'application/json',
                  'Accept': 'text/event-stream',
                };
                headers2.addAll(_customHeaders(config, modelId));
                if (extraHeaders != null && extraHeaders.isNotEmpty) {
                  headers2.addAll(extraHeaders);
                }
                req2.headers.addAll(headers2);
                req2.body = jsonEncode(body2);
                final resp2 = await client.send(req2);
                if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
                  final errorBody = await resp2.stream.bytesToString();
                  throw HttpException('HTTP ${resp2.statusCode}: $errorBody');
                }
                final s2 = resp2.stream.transform(utf8.decoder);
                String buf2 = '';
                final Map<int, Map<String, String>> toolAcc2 =
                    <int, Map<String, String>>{};
                String? finishReason2;
                String contentAccum = '';
                String reasoningAccum = '';
                dynamic reasoningDetailsAccum;
                await for (final ch in s2) {
                  buf2 += ch;
                  final lines2 = buf2.split('\n');
                  buf2 = lines2.last;
                  for (int j = 0; j < lines2.length - 1; j++) {
                    final l = lines2[j].trim();
                    if (l.isEmpty || !l.startsWith('data:')) continue;
                    final d = l.substring(5).trimLeft();
                    if (d == '[DONE]') {
                      continue;
                    }
                    try {
                      final o = jsonDecode(d);
                      if (o is Map &&
                          o['choices'] is List &&
                          (o['choices'] as List).isNotEmpty) {
                        final c0 = (o['choices'] as List).first;
                        finishReason2 = c0['finish_reason'] as String?;
                        final delta = c0['delta'] as Map?;
                        final txt = _extractOpenAICompatibleDeltaText(delta);
                        final rc =
                            delta?['reasoning_content'] ?? delta?['reasoning'];
                        final u = o['usage'];
                        if (u != null) {
                          final prompt = (u['prompt_tokens'] ?? 0) as int;
                          final completion =
                              (u['completion_tokens'] ?? 0) as int;
                          final cached =
                              (u['prompt_tokens_details']?['cached_tokens'] ??
                                      0)
                                  as int? ??
                              0;
                          usage = (usage ?? const TokenUsage()).merge(
                            TokenUsage(
                              promptTokens: prompt,
                              completionTokens: completion,
                              cachedTokens: cached,
                            ),
                          );
                          totalTokens = usage.totalTokens;
                        }
                        if (rc is String && rc.isNotEmpty) {
                          if (needsReasoningEcho) reasoningAccum += rc;
                          yield ChatStreamChunk(
                            content: '',
                            reasoning: rc,
                            isDone: false,
                            totalTokens: 0,
                            usage: usage,
                          );
                        }
                        if (txt.isNotEmpty) {
                          contentAccum += txt;
                          yield ChatStreamChunk(
                            content: txt,
                            isDone: false,
                            totalTokens: 0,
                            usage: usage,
                          );
                        }
                        if (wantsImageOutput) {
                          final List<dynamic> imageItems = <dynamic>[];
                          final imgs = delta?['images'];
                          if (imgs is List) imageItems.addAll(imgs);
                          final contentArr = delta?['content'] as List?;
                          if (contentArr is List) {
                            for (final it in contentArr) {
                              if (it is Map &&
                                  (it['type'] == 'image_url' ||
                                      it['type'] == 'image')) {
                                imageItems.add(it);
                              }
                            }
                          }
                          final singleImage = delta?['image_url'];
                          if (singleImage is Map || singleImage is String) {
                            imageItems.add({
                              'type': 'image_url',
                              'image_url': singleImage,
                            });
                          }
                          if (imageItems.isNotEmpty) {
                            final buf = StringBuffer();
                            for (final it in imageItems) {
                              if (it is! Map) continue;
                              dynamic iu = it['image_url'];
                              String? url;
                              if (iu is String) {
                                url = iu;
                              } else if (iu is Map) {
                                final u2 = iu['url'];
                                if (u2 is String) url = u2;
                              }
                              if (url != null && url.isNotEmpty) {
                                final md = '\n\n![image]($url)';
                                buf.write(md);
                                contentAccum += md;
                              }
                            }
                            final out = buf.toString();
                            if (out.isNotEmpty) {
                              yield ChatStreamChunk(
                                content: out,
                                isDone: false,
                                totalTokens: 0,
                                usage: usage,
                              );
                            }
                          }
                        }
                        final tcs = delta?['tool_calls'] as List?;
                        if (tcs != null) {
                          for (final t in tcs) {
                            final idx = (t['index'] as int?) ?? 0;
                            final id = t['id'] as String?;
                            final func = t['function'] as Map<String, dynamic>?;
                            final name = func?['name'] as String?;
                            final argsDelta = func?['arguments'] as String?;
                            final entry = toolAcc2.putIfAbsent(
                              idx,
                              () => {'id': '', 'name': '', 'args': ''},
                            );
                            if (id != null) entry['id'] = id;
                            if (name != null && name.isNotEmpty) {
                              entry['name'] = name;
                            }
                            if (argsDelta != null && argsDelta.isNotEmpty) {
                              entry['args'] = (entry['args'] ?? '') + argsDelta;
                            }
                          }
                        }

                        // Fallback/merge: message.content in same chunk (if any)
                        final message = c0['message'] as Map?;
                        if (message != null && message['content'] != null) {
                          final mc = message['content'];
                          if (mc is String && mc.isNotEmpty) {
                            contentAccum += mc;
                            yield ChatStreamChunk(
                              content: mc,
                              isDone: false,
                              totalTokens: 0,
                              usage: usage,
                            );
                          }
                        }
                        if (message != null) {
                          final rcMsg =
                              message['reasoning_content'] ??
                              message['reasoning'];
                          if (rcMsg is String &&
                              rcMsg.isNotEmpty &&
                              needsReasoningEcho) {
                            reasoningAccum += rcMsg;
                          }
                        }
                        if (preserveReasoningDetails) {
                          final rd = delta?['reasoning_details'];
                          if (rd is List && rd.isNotEmpty) {
                            reasoningDetailsAccum = rd;
                          }
                          final rdMsg = message?['reasoning_details'];
                          if (rdMsg is List && rdMsg.isNotEmpty) {
                            reasoningDetailsAccum = rdMsg;
                          }
                        }
                      }
                      // XinLiu compatibility for follow-up requests too
                      final rootToolCalls2 = o['tool_calls'] as List?;
                      if (rootToolCalls2 != null) {
                        for (final t in rootToolCalls2) {
                          if (t is! Map) continue;
                          final id = (t['id'] ?? '').toString();
                          final type = (t['type'] ?? 'function').toString();
                          if (type != 'function') continue;
                          final func = t['function'] as Map<String, dynamic>?;
                          if (func == null) continue;
                          final name = (func['name'] ?? '').toString();
                          final argsStr = (func['arguments'] ?? '').toString();
                          if (name.isEmpty) continue;
                          final idx = toolAcc2.length;
                          final entry = toolAcc2.putIfAbsent(
                            idx,
                            () => {
                              'id': id.isEmpty ? 'call_$idx' : id,
                              'name': name,
                              'args': argsStr,
                            },
                          );
                          if (id.isNotEmpty) entry['id'] = id;
                          entry['name'] = name;
                          entry['args'] = argsStr;
                        }
                        if (rootToolCalls2.isNotEmpty &&
                            finishReason2 == null) {
                          finishReason2 = 'tool_calls';
                        }
                      }
                    } catch (_) {}
                  }
                }
                if (finishReason2 == 'tool_calls' || toolAcc2.isNotEmpty) {
                  final calls2 = <Map<String, dynamic>>[];
                  final callInfos2 = <ToolCallInfo>[];
                  final toolMsgs2 = <Map<String, dynamic>>[];
                  toolAcc2.forEach((idx, m) {
                    final id = (m['id'] ?? 'call_$idx');
                    final name = (m['name'] ?? '');
                    Map<String, dynamic> args;
                    try {
                      args = (jsonDecode(m['args'] ?? '{}') as Map)
                          .cast<String, dynamic>();
                    } catch (_) {
                      args = <String, dynamic>{};
                    }
                    callInfos2.add(
                      ToolCallInfo(id: id, name: name, arguments: args),
                    );
                    calls2.add({
                      'id': id,
                      'type': 'function',
                      'function': {'name': name, 'arguments': jsonEncode(args)},
                    });
                    toolMsgs2.add({'__name': name, '__id': id, '__args': args});
                  });
                  if (callInfos2.isNotEmpty) {
                    yield ChatStreamChunk(
                      content: '',
                      isDone: false,
                      totalTokens: usage?.totalTokens ?? 0,
                      usage: usage,
                      toolCalls: callInfos2,
                    );
                  }
                  final results2 = <Map<String, dynamic>>[];
                  final resultsInfo2 = <ToolResultInfo>[];
                  for (final m in toolMsgs2) {
                    final name = m['__name'] as String;
                    final id = m['__id'] as String;
                    final args = (m['__args'] as Map<String, dynamic>);
                    final res = await onToolCall(name, args);
                    results2.add({'tool_call_id': id, 'content': res});
                    resultsInfo2.add(
                      ToolResultInfo(
                        id: id,
                        name: name,
                        arguments: args,
                        content: res,
                      ),
                    );
                  }
                  if (resultsInfo2.isNotEmpty) {
                    yield ChatStreamChunk(
                      content: '',
                      isDone: false,
                      totalTokens: usage?.totalTokens ?? 0,
                      usage: usage,
                      toolResults: resultsInfo2,
                    );
                  }
                  final nextAssistantToolCall = <String, dynamic>{
                    'role': 'assistant',
                    'content': '\n\n',
                    'tool_calls': calls2,
                  };
                  if (needsReasoningEcho) {
                    nextAssistantToolCall['reasoning_content'] = reasoningAccum;
                  }
                  if (preserveReasoningDetails &&
                      reasoningDetailsAccum is List &&
                      reasoningDetailsAccum.isNotEmpty) {
                    nextAssistantToolCall['reasoning_details'] =
                        reasoningDetailsAccum;
                  }
                  currentMessages = [
                    ...currentMessages,
                    if (contentAccum.isNotEmpty)
                      {'role': 'assistant', 'content': contentAccum},
                    nextAssistantToolCall,
                    for (final r in results2)
                      {
                        'role': 'tool',
                        'tool_call_id': r['tool_call_id'],
                        'name': calls2.firstWhere(
                          (c) => c['id'] == r['tool_call_id'],
                          orElse: () => const {
                            'function': {'name': ''},
                          },
                        )['function']['name'],
                        'content': r['content'],
                      },
                  ];
                  continue;
                } else {
                  final approxTotal =
                      approxPromptTokens +
                      approxTokensFromChars(approxCompletionChars);
                  yield ChatStreamChunk(
                    content: '',
                    isDone: true,
                    totalTokens: usage?.totalTokens ?? approxTotal,
                    usage: usage,
                  );
                  return;
                }
              }
            }
          } else if (host.contains('openrouter.ai')) {
          } else {
            // final approxTotal = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
            // yield ChatStreamChunk(
            //   content: '',
            //   isDone: false,
            //   totalTokens: usage?.totalTokens ?? approxTotal,
            //   usage: usage,
            // );
            // return;
          }
        }
      } catch (e) {
        // Skip malformed JSON
      }
    }
  }

  // Fallback: provider closed SSE without sending [DONE]
  final approxTotal =
      usage?.totalTokens ??
      (approxPromptTokens + approxTokensFromChars(approxCompletionChars));
  yield ChatStreamChunk(
    content: '',
    isDone: true,
    totalTokens: approxTotal,
    usage: usage,
  );
}
