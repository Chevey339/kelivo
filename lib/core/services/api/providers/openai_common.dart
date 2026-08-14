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

Future<String> _saveResponsesImageGenerationMarkdown(
  String imageData, {
  String? outputFormat,
}) async {
  final normalizedFormat = (outputFormat ?? '').trim().toLowerCase();
  var mime = switch (normalizedFormat) {
    'jpeg' || 'jpg' => 'image/jpeg',
    'webp' => 'image/webp',
    _ => 'image/png',
  };
  var imageBase64 = imageData.trim();
  if (imageBase64.startsWith('data:')) {
    final commaIndex = imageBase64.indexOf(',');
    if (commaIndex < 0) return '';
    mime = _mimeFromDataUrl(imageBase64);
    imageBase64 = imageBase64.substring(commaIndex + 1);
  }
  final savedPath = await AppDirectories.saveBase64Image(mime, imageBase64);
  if (savedPath == null || savedPath.isEmpty) return '';
  final uri = SandboxPathResolver.canonicalize(savedPath);
  return '\n![image]($uri)\n';
}

String _responsesImageGenerationSource(Map<dynamic, dynamic> item) {
  for (final key in const <String>[
    'imageUrl',
    'image_url',
    'imageB64',
    'image_b64',
    'result',
  ]) {
    final raw = item[key];
    final value = raw is Map ? raw['url'] : raw;
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

Future<String> _responsesImageGenerationMarkdown(
  Map<dynamic, dynamic> item,
) async {
  final source = _responsesImageGenerationSource(item);
  if (source.isEmpty) return '';
  if (_isRemoteHttpUrl(source)) return '\n![image]($source)\n';
  return _saveResponsesImageGenerationMarkdown(
    source,
    outputFormat: (item['output_format'] ?? item['outputFormat'] ?? '')
        .toString(),
  );
}

bool _isResponsesImageGenerationType(dynamic type) {
  return type == 'image_generation_call' ||
      type == 'openrouter:image_generation';
}

void _applyChatCompletionsBuiltInTools(
  Map<String, dynamic> body, {
  required ProviderConfig config,
  required String modelId,
  required String upstreamModelId,
  Iterable<String>? configuredTools,
}) {
  final payload = BuiltInToolsHelper.buildChatCompletionsTools(
    cfg: config,
    modelId: modelId,
    upstreamModelId: upstreamModelId,
    configuredTools: configuredTools,
  );
  for (final entry in payload.body.entries) {
    body.putIfAbsent(entry.key, () => entry.value);
  }
  for (final tool in payload.tools) {
    _appendChatTool(body, tool);
  }
  final migratesWebPlugin =
      BuiltInToolsHelper.isOpenRouterProvider(config) &&
      payload.tools.any((tool) => tool['type'] == 'openrouter:web_search');
  if (migratesWebPlugin && body['plugins'] is List) {
    final plugins = (body['plugins'] as List).where((plugin) {
      return plugin is! Map ||
          (plugin['id'] ?? '').toString().trim().toLowerCase() != 'web';
    }).toList();
    if (plugins.isEmpty) {
      body.remove('plugins');
    } else {
      body['plugins'] = plugins;
    }
  }
}

void _appendChatTool(Map<String, dynamic> body, Map<String, dynamic> tool) {
  final tools = <Map<String, dynamic>>[];
  final existing = body['tools'];
  if (existing is List) {
    for (final t in existing) {
      if (t is Map) tools.add(t.cast<String, dynamic>());
    }
  }
  final type = (tool['type'] ?? '').toString();
  final exists = tools.any((t) => (t['type'] ?? '').toString() == type);
  if (!exists) tools.add(tool);
  body['tools'] = tools;
  body['tool_choice'] ??= 'auto';
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

  if (BuiltInToolsHelper.isMimoProvider(config)) {
    body.remove('reasoning');
    if (!isReasoning) return;

    final effort = _isOff(thinkingBudget)
        ? 'none'
        : _openAIEffortForBudget(thinkingBudget, upstreamModelId);
    if (effort != 'auto') {
      body['reasoning'] = {'effort': effort};
    }
    return;
  }

  final host = Uri.tryParse(config.baseUrl)?.host.toLowerCase() ?? '';
  final isDeepSeek =
      host.contains('deepseek') ||
      config.id.toLowerCase().contains('deepseek') ||
      upstreamModelId.toLowerCase().contains('deepseek');
  if (isDeepSeek) {
    if (!isReasoning) {
      body.remove('reasoning');
    } else if (_isOff(thinkingBudget)) {
      body['reasoning'] = {'effort': 'none'};
    }
    return;
  }

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

bool _isKimiK25Model(String upstreamModelId) {
  return upstreamModelId.toLowerCase().contains('kimi-k2.5');
}

bool _isKimiK3Model(String upstreamModelId) {
  return RegExp(
    r'(^|[/_:@])kimi-k3(?:$|[-.:])',
    caseSensitive: false,
  ).hasMatch(upstreamModelId.trim());
}

bool _isKimiPreservedThinkingModel(String upstreamModelId) {
  final normalized = upstreamModelId.trim().toLowerCase();
  return _isKimiK3Model(normalized) ||
      RegExp(r'(^|[/_:@])kimi-k2\.7-code(?:$|[-.:])').hasMatch(normalized);
}

enum _ReasoningContentReplayPolicy { none, toolTurns, all }

bool _isRemoteHttpUrl(String source) {
  final normalized = source.trim().toLowerCase();
  return normalized.startsWith('http://') || normalized.startsWith('https://');
}

bool _isRemoteImageContentPart(dynamic part) {
  if (part is! Map) return false;
  final type = (part['type'] ?? '').toString().trim().toLowerCase();
  if (type != 'image_url' && type != 'input_image') return false;

  final imageUrl = part['image_url'];
  final rawUrl = imageUrl is Map ? imageUrl['url'] : imageUrl;
  return rawUrl is String && _isRemoteHttpUrl(rawUrl);
}

bool _isKimiOmitsSamplingParamsModel(String upstreamModelId) {
  final lower = upstreamModelId.toLowerCase();
  return lower.contains('kimi-k2.5') ||
      lower.contains('kimi-k2.7') ||
      _isKimiK3Model(lower);
}

bool _isKimiThinkingModel(String upstreamModelId) {
  final lower = upstreamModelId.toLowerCase();
  return lower.contains('kimi-k2-thinking') ||
      lower.contains('kimi-k2.5') ||
      lower.contains('kimi-k2.6') ||
      lower.contains('kimi-k2.7') ||
      _isKimiK3Model(lower);
}

void _removeMoonshotKimiUnsupportedSamplingParams(Map<String, dynamic> body) {
  body.remove('temperature');
  body.remove('top_p');
  body.remove('n');
  body.remove('presence_penalty');
  body.remove('frequency_penalty');
}

bool _isZhipuLikeProvider({
  required String providerId,
  required String host,
  required String upstreamModelId,
}) {
  final modelLower = upstreamModelId.toLowerCase();
  return providerId.contains('zhipu') ||
      providerId.contains('智谱') ||
      host.contains('open.bigmodel.cn') ||
      host.contains('bigmodel') ||
      host == 'api.z.ai' ||
      modelLower.startsWith('glm-');
}

void _normalizeMoonshotKimiChatBody(
  Map<String, dynamic> body, {
  required String upstreamModelId,
  required bool isReasoning,
  int? thinkingBudget,
}) {
  if (!_isKimiThinkingModel(upstreamModelId)) return;

  if (_isKimiK3Model(upstreamModelId)) {
    body.remove('thinking');
    _removeMoonshotKimiUnsupportedSamplingParams(body);
    if (!isReasoning) {
      body.remove('reasoning_effort');
      return;
    }
    final rawEffort = body['reasoning_effort'];
    if (rawEffort is! String || rawEffort.trim().isEmpty) {
      body.remove('reasoning_effort');
      return;
    }
    final effort = openAINormalizeReasoningEffort(rawEffort, upstreamModelId);
    if (effort == 'auto') {
      body.remove('reasoning_effort');
    } else {
      body['reasoning_effort'] = effort;
    }
    return;
  }

  body.remove('reasoning_effort');
  if (!isReasoning) {
    body.remove('thinking');
    return;
  }

  if (_isKimiK25Model(upstreamModelId)) {
    body['thinking'] = {
      'type': _isOff(thinkingBudget) ? 'disabled' : 'enabled',
    };
    _removeMoonshotKimiUnsupportedSamplingParams(body);
    return;
  }

  body.remove('thinking');
  if (_isKimiOmitsSamplingParamsModel(upstreamModelId)) {
    _removeMoonshotKimiUnsupportedSamplingParams(body);
  }
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

Map<String, dynamic> _buildAssistantToolCallMessage({
  required List<Map<String, dynamic>> calls,
  dynamic content,
  String? reasoningContent,
  dynamic reasoningDetails,
  bool includeEmptyReasoningContent = false,
}) {
  final normalizedContent = switch (content) {
    String value when value.isNotEmpty => value,
    List<dynamic> value when value.isNotEmpty => value,
    _ => '\n\n',
  };

  final msg = <String, dynamic>{
    'role': 'assistant',
    'content': normalizedContent,
    'tool_calls': calls,
  };
  if (reasoningContent != null &&
      (reasoningContent.isNotEmpty || includeEmptyReasoningContent)) {
    msg['reasoning_content'] = reasoningContent;
  }
  if (reasoningDetails is List && reasoningDetails.isNotEmpty) {
    msg['reasoning_details'] = reasoningDetails;
  }
  return msg;
}

String _openAIEffortForBudget(int? budget, String upstreamModelId) {
  final baseEffort = _effortForBudget(budget);
  var requestedEffort = baseEffort;
  if (baseEffort == 'high' && budget != null) {
    if (budget >= 128000 && openAISupportsMaxReasoning(upstreamModelId)) {
      requestedEffort = 'max';
    } else if (budget >= 64000) {
      requestedEffort = 'xhigh';
    }
  }
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
  // Source: https://developers.openai.com/api/docs/guides/latest-model
  // Only documented per-model compatibility rules are enforced here.
  return openAIAllowsSamplingParams(upstreamModelId, effort: effort);
}

void _sanitizeOpenAIGpt5SamplingParams(
  Map<String, dynamic> body,
  String upstreamModelId, {
  required String fallbackEffort,
  required bool isOpenRouter,
}) {
  // Must run on the final request body (after override merges), otherwise
  // we may keep/drop sampling params based on stale effort assumptions.
  final hasChatFunctionTools =
      body['messages'] is List &&
      body['tools'] is List &&
      (body['tools'] as List).isNotEmpty;
  if (hasChatFunctionTools &&
      openAIChatCompletionsToolsRequireNone(upstreamModelId)) {
    if (isOpenRouter) {
      final reasoning = body['reasoning'];
      final normalized = reasoning is Map
          ? Map<String, dynamic>.from(reasoning)
          : <String, dynamic>{};
      normalized
        ..remove('enabled')
        ..remove('max_tokens')
        ..['effort'] = 'none';
      body['reasoning'] = normalized;
      body.remove('reasoning_effort');
    } else {
      body['reasoning_effort'] = 'none';
    }
  }
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
  // Callers may pass a full URL or a bare hostname (e.g. `api.longcat.chat`).
  // `Uri.tryParse('api.longcat.chat')?.host` is '' (not null), so never rely on
  // `??` fallback alone — normalize via an explicit https:// prefix when needed.
  final raw = baseUrl.trim().toLowerCase();
  if (raw.isEmpty) return false;
  final parsed = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
  final host = (parsed?.host ?? '').toLowerCase();
  if (host.isNotEmpty) return host.contains('longcat');
  return raw.contains('longcat');
}

bool _shouldIncludeStreamingUsageOptions(String host) {
  if (_isLongCatHost(host)) {
    return false;
  }
  return !host.contains('mistral.ai') && !host.contains('openrouter');
}

bool _isClaudeModelId(String modelId) {
  final normalized = modelId.trim().toLowerCase();
  return normalized.contains('claude') || normalized.contains('anthropic/');
}

bool _shouldCacheClaudeSystemPrompt(
  ProviderConfig config,
  String upstreamModelId,
) {
  return config.claudePromptCachingEnabled == true &&
      BuiltInToolsHelper.isOpenRouterProvider(config) &&
      _isClaudeModelId(upstreamModelId);
}

void _applyOpenRouterClaudePromptCaching(
  Map<String, dynamic> body, {
  required ProviderConfig config,
  required String upstreamModelId,
}) {
  if (!_shouldCacheClaudeSystemPrompt(config, upstreamModelId)) return;
  body['cache_control'] = ProviderConfig.claudePromptCacheControl(
    config.claudePromptCachingTtl,
  );
}

void _maybeAddStreamingUsageOptions(
  Map<String, dynamic> body, {
  required bool stream,
  required ProviderConfig config,
  required String host,
}) {
  if (!stream || config.useResponseApi == true) return;
  if (_shouldIncludeStreamingUsageOptions(host)) {
    body['stream_options'] = {'include_usage': true};
  }
}

int _readOpenAIUsageInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

TokenUsage? _mergeOpenAICompatibleUsage(TokenUsage? current, dynamic rawUsage) {
  if (rawUsage is! Map) return current;

  final details =
      rawUsage['prompt_tokens_details'] ?? rawUsage['input_tokens_details'];
  final cachedTokens = details is Map
      ? _readOpenAIUsageInt(details['cached_tokens'])
      : 0;
  return (current ?? const TokenUsage()).merge(
    TokenUsage(
      promptTokens: _readOpenAIUsageInt(
        rawUsage['prompt_tokens'] ?? rawUsage['input_tokens'],
      ),
      completionTokens: _readOpenAIUsageInt(
        rawUsage['completion_tokens'] ?? rawUsage['output_tokens'],
      ),
      cachedTokens: cachedTokens,
    ),
  );
}

String _responsesReasoningText(dynamic rawOutput) {
  if (rawOutput is! List) return '';

  final buffer = StringBuffer();
  for (final item in rawOutput) {
    if (item is! Map || item['type'] != 'reasoning') continue;
    final content = item['content'];
    if (content is String) {
      buffer.write(content);
      continue;
    }
    if (content is! List) continue;
    for (final part in content) {
      if (part is String) {
        buffer.write(part);
      } else if (part is Map &&
          (part['type'] == 'reasoning_text' || part['type'] == 'text')) {
        buffer.write((part['text'] ?? part['content'] ?? '').toString());
      }
    }
  }
  return buffer.toString();
}

Future<List<Map<String, dynamic>>> _buildOpenAIChatCompletionMessages(
  List<Map<String, dynamic>> messages, {
  List<String>? userMediaPaths,
  required bool canImageInput,
  required bool allowRemoteImages,
  required _ReasoningContentReplayPolicy reasoningContentReplayPolicy,
  bool stripReasoningContent = false,
}) async {
  final out = <Map<String, dynamic>>[];
  // Assistant turns cannot carry image_url/video_url; stash for the last user
  // message (same pattern as Responses shouldAttachAssistantImage).
  // Use last *user* index — not array-tail — so tool follow-ups that append
  // assistant tool_calls / tool results still receive stashed assistant media.
  int lastUserIndex = -1;
  for (int i = messages.length - 1; i >= 0; i--) {
    if ((messages[i]['role'] ?? '').toString() == 'user') {
      lastUserIndex = i;
      break;
    }
  }
  final pendingAssistantMediaUrls = <String>[];
  final pendingAssistantVideoUrls = <String>{};
  final toolTurnIds = <int>{};
  final messageTurnIds = <int>[];
  var currentTurnId = -1;
  for (final message in messages) {
    final messageRole = (message['role'] ?? 'user').toString();
    if (messageRole == 'user') currentTurnId++;
    messageTurnIds.add(currentTurnId);
    final messageToolCalls = message['tool_calls'];
    if (messageRole == 'tool' ||
        (messageRole == 'assistant' &&
            messageToolCalls is List &&
            messageToolCalls.isNotEmpty)) {
      toolTurnIds.add(currentTurnId);
    }
  }
  for (int i = 0; i < messages.length; i++) {
    final m = messages[i];
    final originalContent = m['content'];
    final raw = originalContent is List
        ? ChatApiService._textFromContentParts(originalContent)
        : (originalContent ?? '').toString();
    final role = (m['role'] ?? 'user').toString();
    final isAssistant = role == 'assistant';
    final internalMediaRefs = parseInternalMediaRefs(
      m[multimodalInternalMediaPathsKey],
    );
    final outMsg = Map<String, dynamic>.from(m);
    outMsg.remove(multimodalInternalMediaPathsKey);
    outMsg.remove(multimodalInternalRevisionIdKey);
    outMsg['role'] = role;

    if (isAssistant) {
      final keepReasoningContent =
          !stripReasoningContent &&
          (reasoningContentReplayPolicy == _ReasoningContentReplayPolicy.all ||
              (reasoningContentReplayPolicy ==
                      _ReasoningContentReplayPolicy.toolTurns &&
                  toolTurnIds.contains(messageTurnIds[i])));
      if (!keepReasoningContent) {
        outMsg.remove('reasoning_content');
        outMsg.remove('reasoning');
      }
    }

    // Bare userImagePaths attach to the last *user* turn (not array-tail), so
    // tool follow-ups that append assistant/tool messages still keep them.
    final hasAttachedImages =
        canImageInput &&
        role == 'user' &&
        i == lastUserIndex &&
        (userMediaPaths?.isNotEmpty == true);
    final shouldAttachAssistantMedia =
        canImageInput &&
        role == 'user' &&
        i == lastUserIndex &&
        pendingAssistantMediaUrls.isNotEmpty;
    final hasInternalMedia = canImageInput && internalMediaRefs.isNotEmpty;

    if (originalContent is List) {
      dynamic content = canImageInput
          ? (allowRemoteImages
                ? originalContent
                : originalContent
                      .where((part) => !_isRemoteImageContentPart(part))
                      .toList(growable: false))
          : raw;
      // List-shaped content used to early-return before assistant-media /
      // userImagePaths attachment. Merge those onto the last user turn, and
      // still stash assistant media — including image_url/video_url already
      // embedded in the List with no structured sidecar refs.
      final listHasEmbeddedMedia =
          canImageInput &&
          content is List &&
          content.any((part) {
            if (part is! Map) return false;
            final type = (part['type'] ?? '').toString();
            return type == 'image_url' || type == 'video_url';
          });
      if (canImageInput &&
          (hasInternalMedia ||
              hasAttachedImages ||
              shouldAttachAssistantMedia ||
              (isAssistant && listHasEmbeddedMedia))) {
        final parts = <Map<String, dynamic>>[
          if (content is List)
            for (final part in content)
              if (part is Map)
                part.map((key, value) => MapEntry(key.toString(), value)),
        ];
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
          if (!allowRemoteImages && _isRemoteHttpUrl(url)) return;
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

        void stashOrAddImageUrl(String url) {
          if (url.isEmpty) return;
          if (!allowRemoteImages && _isRemoteHttpUrl(url)) return;
          if (isAssistant) {
            if (!pendingAssistantMediaUrls.contains(url)) {
              pendingAssistantMediaUrls.add(url);
            }
            return;
          }
          addImageUrl(url);
        }

        void stashOrAddVideoUrl(String url) {
          if (url.isEmpty) return;
          if (isAssistant) {
            if (!pendingAssistantMediaUrls.contains(url)) {
              pendingAssistantMediaUrls.add(url);
            }
            pendingAssistantVideoUrls.add(url);
            return;
          }
          addVideoUrl(url);
        }

        // Index existing List media; on assistant turns also stash them so the
        // role gate moves unsupported image_url/video_url onto the last user.
        for (final part in List<Map<String, dynamic>>.from(parts)) {
          final type = (part['type'] ?? '').toString();
          if (type == 'image_url') {
            final image = part['image_url'];
            final url = image is Map
                ? (image['url'] ?? '').toString()
                : image?.toString() ?? '';
            if (url.isNotEmpty) {
              seenImageUrls.add(url);
              seenSources.add(normalizeSrc(url));
              if (isAssistant) stashOrAddImageUrl(url);
            }
          } else if (type == 'video_url') {
            final video = part['video_url'];
            final url = video is Map
                ? (video['url'] ?? '').toString()
                : video?.toString() ?? '';
            if (url.isNotEmpty) {
              seenVideoUrls.add(url);
              seenSources.add(normalizeSrc(url));
              if (isAssistant) stashOrAddVideoUrl(url);
            }
          }
        }

        final supplementalRefs = _supplementalMediaRefs(
          internalRaw: m[multimodalInternalMediaPathsKey],
          userPaths: userMediaPaths,
          includeUserPaths: hasAttachedImages,
        );
        for (final mediaRef in supplementalRefs) {
          final mediaPath = mediaRef.uri;
          if (!allowRemoteImages && _isRemoteHttpUrl(mediaPath)) {
            final normalized = normalizeSrc(mediaPath);
            if (!seenSources.add(normalized)) continue;
            if (!isAssistant) {
              parts.add({'type': 'text', 'text': mediaPath});
            }
            continue;
          }
          final normalized = normalizeSrc(mediaPath);
          if (!seenSources.add(normalized)) continue;
          final bool isInlineUrl =
              _isRemoteHttpUrl(mediaPath) || mediaPath.startsWith('data:');
          final String mime = _mimeForInternalMediaRef(mediaRef);
          if (isAudioMime(mime)) continue;
          final bool isVideo = isVideoMime(mime);
          final String? dataUrl = isInlineUrl
              ? mediaPath
              : await _tryEncodeBase64DataUrl(
                  mediaPath,
                  explicitMime: mediaRef.mime,
                );
          if (dataUrl == null) continue;
          if (isVideo) {
            stashOrAddVideoUrl(dataUrl);
          } else {
            stashOrAddImageUrl(dataUrl);
          }
        }
        if (shouldAttachAssistantMedia) {
          for (final url in pendingAssistantMediaUrls) {
            if (pendingAssistantVideoUrls.contains(url)) {
              addVideoUrl(url);
            } else {
              addImageUrl(url);
            }
          }
        }
        if (isAssistant) {
          // Keep assistant List content image-free; media is stashed above.
          content = [
            for (final part in parts)
              if (part['type'] != 'image_url' && part['type'] != 'video_url')
                part,
          ];
          if (content.isEmpty) content = raw;
        } else {
          content = parts;
        }
      }
      outMsg['content'] = content;
      out.add(outMsg);
      continue;
    }

    if (role == 'system') {
      outMsg['content'] = raw;
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

    final hasMarkdownImages = raw.contains('![') && raw.contains('](');
    // Semantic media detection only - custom attachment markers are not
    // recognized. Attachments arrive via structured media-path keys /
    // userMediaPaths, plus Markdown ![](...).
    // Consume injected media refs for user and assistant history turns.

    if (!hasMarkdownImages &&
        !hasAttachedImages &&
        !hasInternalMedia &&
        !shouldAttachAssistantMedia) {
      outMsg['content'] = raw;
      out.add(outMsg);
      continue;
    }

    final parsed = await _parseTextAndImages(
      raw,
      allowRemoteImages: canImageInput && allowRemoteImages,
      allowLocalImages: canImageInput,
      allowDataImages: canImageInput,
      keepRemoteMarkdownText: true,
      keepDisallowedImageText: canImageInput,
    );
    if (!canImageInput) {
      outMsg['content'] = parsed.text;
      out.add(outMsg);
      continue;
    }

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
      if (!allowRemoteImages && _isRemoteHttpUrl(url)) return;
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

    void stashOrAddImageUrl(String url) {
      if (url.isEmpty) return;
      if (!allowRemoteImages && _isRemoteHttpUrl(url)) return;
      if (isAssistant) {
        if (!pendingAssistantMediaUrls.contains(url)) {
          pendingAssistantMediaUrls.add(url);
        }
        return;
      }
      addImageUrl(url);
    }

    void stashOrAddVideoUrl(String url) {
      if (url.isEmpty) return;
      if (isAssistant) {
        if (!pendingAssistantMediaUrls.contains(url)) {
          pendingAssistantMediaUrls.add(url);
        }
        pendingAssistantVideoUrls.add(url);
        return;
      }
      addVideoUrl(url);
    }

    if (parsed.text.isNotEmpty) {
      parts.add({'type': 'text', 'text': parsed.text});
    }
    for (final ref in parsed.images) {
      final normalized = normalizeSrc(ref.src);
      if (!seenSources.add(normalized)) continue;
      final String? url;
      if (ref.kind == 'data') {
        url = ref.src;
      } else if (ref.kind == 'path') {
        url = await _tryEncodeBase64DataUrl(ref.src);
        if (url == null) continue;
      } else {
        url = ref.src;
      }
      stashOrAddImageUrl(url);
    }
    final supplementalRefs = _supplementalMediaRefs(
      internalRaw: m[multimodalInternalMediaPathsKey],
      userPaths: userMediaPaths,
      includeUserPaths: hasAttachedImages,
    );
    for (final mediaRef in supplementalRefs) {
      final p = mediaRef.uri;
      if (!allowRemoteImages && _isRemoteHttpUrl(p)) {
        // Keep the remote reference visible as text when image fetch/embed
        // is disabled for this model (e.g. Kimi K3).
        final normalized = normalizeSrc(p);
        if (!seenSources.add(normalized)) continue;
        parts.add({'type': 'text', 'text': p});
        continue;
      }
      final normalized = normalizeSrc(p);
      if (!seenSources.add(normalized)) continue;
      final bool isInlineUrl = _isRemoteHttpUrl(p) || p.startsWith('data:');
      final String mime = _mimeForInternalMediaRef(mediaRef);
      if (isAudioMime(mime)) continue;
      final bool isVideo = isVideoMime(mime);
      final String? dataUrl = isInlineUrl
          ? p
          : await _tryEncodeBase64DataUrl(p, explicitMime: mediaRef.mime);
      if (dataUrl == null) continue;
      if (isVideo) {
        stashOrAddVideoUrl(dataUrl);
      } else {
        stashOrAddImageUrl(dataUrl);
      }
    }
    // Attach stashed assistant media to the last user message.
    if (shouldAttachAssistantMedia) {
      for (final url in pendingAssistantMediaUrls) {
        if (pendingAssistantVideoUrls.contains(url)) {
          addVideoUrl(url);
        } else {
          addImageUrl(url);
        }
      }
    }
    // Assistant content stays string or multimodal text-only parts.
    if (isAssistant) {
      if (parts.isEmpty) {
        outMsg['content'] = raw;
      } else if (parts.length == 1 && parts.first['type'] == 'text') {
        outMsg['content'] = parts.first['text'] ?? raw;
      } else {
        final textOnly = <Map<String, dynamic>>[
          for (final part in parts)
            if (part['type'] == 'text') part,
        ];
        outMsg['content'] = textOnly.isEmpty ? raw : textOnly;
      }
    } else {
      outMsg['content'] = parts.isEmpty ? raw : parts;
    }
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

/// Appends a trailing newline to [source] so that any partial line
/// remaining in the SSE buffer is flushed during the final split('\n').
Stream<String> _ensureTrailingNewline(Stream<String> source) async* {
  await for (final chunk in source) {
    yield chunk;
  }
  yield '\n';
}

/// Follow-up tool-call responses are consumed inside the SSE parser's
/// per-event catch, which tolerates malformed JSON. Convert their transport
/// failures into [HttpException] up front so that catch cannot swallow them
/// and let the no-[DONE] fallback persist truncated output as a completion.
Stream<String> _rethrowFollowUpStreamErrors(Stream<String> source) {
  return source.transform(
    StreamTransformer<String, String>.fromHandlers(
      handleError:
          (Object error, StackTrace stackTrace, EventSink<String> sink) {
            if (error is HttpException) {
              sink.addError(error, stackTrace);
            } else {
              sink.addError(
                HttpException('Follow-up stream failed: $error'),
                stackTrace,
              );
            }
          },
    ),
  );
}

/// Some providers (e.g. OpenRouter rate limits/moderation) report failures as
/// an in-band `{"error": ...}` frame on an otherwise 2xx stream. Surface those
/// as a stream error so truncated output is not persisted as a completion.
///
/// OpenRouter's documented mid-stream failure frame carries the top-level
/// `error` alongside a non-empty `choices` list whose entry has
/// `finish_reason: "error"`, so the presence of choices/candidates must not
/// mask a non-empty error payload. Healthy chunks either lack the `error` key
/// or carry a null/empty placeholder, which [_throwOnInBandStreamError]
/// ignores.
void _throwIfInBandStreamError(String data) {
  final mayCarryError =
      data.contains('"error"') ||
      data.contains('response.failed') ||
      data.contains('response.incomplete');
  if (!mayCarryError) return;
  Object? decoded;
  try {
    decoded = jsonDecode(data);
  } catch (_) {
    return;
  }
  if (decoded is! Map) return;
  final type = (decoded['type'] ?? '').toString();
  if (type == 'error') {
    // `event: error` frames: Anthropic-style ones nest the payload under
    // `error`, while the Responses API puts code/message on the frame itself
    // ({"type":"error","code":...,"message":...}).
    final nested = decoded['error'];
    if (nested is Map && nested.isNotEmpty) {
      _throwOnInBandStreamError(nested);
    }
    _throwOnInBandStreamError(decoded);
  }
  if (type == 'response.failed' || type == 'response.incomplete') {
    // Responses API terminal failure events nest the error under `response`.
    final response = decoded['response'];
    if (response is Map) {
      _throwOnInBandStreamError(response['error']);
      final details = response['incomplete_details'];
      if (details is Map && details.isNotEmpty) {
        final reason = (details['reason'] ?? '').toString().trim();
        throw HttpException(
          reason.isEmpty
              ? 'Provider error: response incomplete'
              : 'Provider error: response incomplete ($reason)',
        );
      }
    }
    // A failure event without a parseable payload still must not fall
    // through and be treated as a normal finish.
    throw HttpException('Provider error: $type');
  }
  _throwOnInBandStreamError(decoded['error']);
}

/// Throws when [error] carries a provider error payload; no-op for the null or
/// empty placeholders some providers emit on healthy chunks.
void _throwOnInBandStreamError(Object? error) {
  if (error is Map && error.isNotEmpty) {
    final message = (error['message'] ?? '').toString().trim();
    final code = (error['code'] ?? error['type'] ?? '').toString().trim();
    final detail = message.isNotEmpty ? message : jsonEncode(error);
    throw HttpException(
      code.isEmpty
          ? 'Provider error: $detail'
          : 'Provider error ($code): $detail',
    );
  }
  if (error is String && error.trim().isNotEmpty) {
    throw HttpException('Provider error: ${error.trim()}');
  }
}

class _OpenAIProviderInfo {
  final String host;
  final String providerId;
  final String upstreamModelId;

  const _OpenAIProviderInfo({
    required this.host,
    required this.providerId,
    required this.upstreamModelId,
  });

  bool get isZhipu => _isZhipuLikeProvider(
    providerId: providerId,
    host: host,
    upstreamModelId: upstreamModelId,
  );
  bool get isMimo =>
      host.contains('xiaomimimo') ||
      upstreamModelId.toLowerCase().startsWith('mimo-') ||
      upstreamModelId.toLowerCase().contains('/mimo-');
  bool get isSiliconFlow =>
      providerId.contains('siliconflow') || host.contains('siliconflow');
  bool get isAzureOpenAI => host.contains('openai.azure.com');
  bool get isOpenRouter =>
      providerId.contains('openrouter') || host.contains('openrouter.ai');
  bool get isDeepSeek =>
      host.contains('deepseek') ||
      upstreamModelId.toLowerCase().contains('deepseek');
  bool get isDashScope => host.contains('dashscope') || host.contains('aliyun');
  bool get isVolc =>
      host.contains('ark.cn-beijing.volces.com') ||
      host.contains('volc') ||
      host.contains('ark');
  bool get isIntern =>
      host.contains('intern-ai') ||
      host.contains('intern') ||
      host.contains('chat.intern-ai.org.cn');
  bool get isKimiThinkingModel => _isKimiThinkingModel(upstreamModelId);

  bool get needsReasoningEcho =>
      isDeepSeek || isMimo || isZhipu || isKimiThinkingModel;
  _ReasoningContentReplayPolicy get reasoningContentReplayPolicy {
    if (_isKimiPreservedThinkingModel(upstreamModelId)) {
      return _ReasoningContentReplayPolicy.all;
    }
    if (needsReasoningEcho) {
      return _ReasoningContentReplayPolicy.toolTurns;
    }
    return _ReasoningContentReplayPolicy.none;
  }

  String get completionTokensKey =>
      (isAzureOpenAI || isMimo) ? 'max_completion_tokens' : 'max_tokens';
}

void _applyVendorReasoningKnobs(
  Map<String, dynamic> body, {
  required _OpenAIProviderInfo info,
  required bool isReasoning,
  int? thinkingBudget,
}) {
  final off = _isOff(thinkingBudget);
  if (info.isOpenRouter) {
    if (isReasoning) {
      final support = openAIReasoningSupport(info.upstreamModelId);
      final requestedEffort = body['reasoning_effort'];
      if (support?.offFallback != null && requestedEffort is String) {
        body['reasoning'] = {'effort': requestedEffort};
      } else if (off) {
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
  } else if (info.isDashScope) {
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
  } else if (info.isZhipu || info.isMimo) {
    if (isReasoning) {
      body['thinking'] = {'type': off ? 'disabled' : 'enabled'};
    } else {
      body.remove('thinking');
    }
    body.remove('reasoning_effort');
  } else if (info.isVolc) {
    if (isReasoning) {
      body['thinking'] = {'type': off ? 'disabled' : 'enabled'};
    } else {
      body.remove('thinking');
    }
    body.remove('reasoning_effort');
  } else if (info.isIntern) {
    if (isReasoning) {
      body['thinking_mode'] = !off;
    } else {
      body.remove('thinking_mode');
    }
    body.remove('reasoning_effort');
  } else if (info.isSiliconFlow) {
    if (isReasoning) {
      if (off) {
        body['enable_thinking'] = false;
        body.remove('thinking_budget');
      } else {
        body.remove('enable_thinking');
        if (thinkingBudget != null && thinkingBudget > 0) {
          body['thinking_budget'] = thinkingBudget;
        } else {
          body.remove('thinking_budget');
        }
      }
    } else {
      body.remove('enable_thinking');
      body.remove('thinking_budget');
    }
    body.remove('reasoning_effort');
  } else if (info.isDeepSeek) {
    if (isReasoning) {
      body['thinking'] = {'type': off ? 'disabled' : 'enabled'};
    } else {
      body.remove('thinking');
      body.remove('reasoning_effort');
    }
  }
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
  ToolCallHandler? onToolCall,
  Map<String, String>? extraHeaders,
  Map<String, dynamic>? extraBody,
  bool stream = true,
}) async* {
  final upstreamModelId = _apiModelId(config, modelId);
  final url = _openAICompatibleUrl(config);
  // Claude models served through OpenAI-compatible proxies require signed
  // thinking blocks; unsigned reasoning echoes are stripped before sending.
  final isClaudeUpstream = upstreamModelId.toLowerCase().contains('claude');

  final effectiveInfo = _effectiveModelInfo(config, modelId);
  final isReasoning = effectiveInfo.abilities.contains(ModelAbility.reasoning);
  final wantsImageOutput = effectiveInfo.output.contains(Modality.image);
  final bool canImageInput = effectiveInfo.input.contains(Modality.image);
  final bool allowRemoteImages =
      canImageInput && !_isKimiK3Model(upstreamModelId);

  final effort = _openAIEffortForBudget(thinkingBudget, upstreamModelId);
  final info = _OpenAIProviderInfo(
    host: Uri.tryParse(config.baseUrl)?.host.toLowerCase() ?? '',
    providerId: config.id.toLowerCase(),
    upstreamModelId: upstreamModelId,
  );
  // OpenRouter documents delta-style `reasoning_details` chunks that must be
  // concatenated in order, so cumulative-snapshot detection is disabled for
  // it; other providers may resend the full array-so-far with each chunk.
  final reasoningDetailsAllowSnapshots =
      !BuiltInToolsHelper.isOpenRouterProvider(config);
  final bool needsReasoningEcho = info.needsReasoningEcho && isReasoning;
  void setMaxTokens(Map<String, dynamic> map) {
    if (maxTokens != null) map[info.completionTokensKey] = maxTokens;
  }

  // Kimi K3 Formula web-search: fetch tool decls, then fiber-execute calls.
  // Only names actually inserted after duplicate resolution are dispatched.
  final formulaToolNames = <String>{};
  List<Map<String, dynamic>> kimiFormulaTools = const <Map<String, dynamic>>[];
  final builtInSearchEnabled = _builtInTools(
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
  Future<String> resolveToolCall(
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
    // Prepare tools list for Responses path (may be augmented with built-ins).
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
          ? ChatApiService._textFromContentParts(originalContent)
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
      final hasMarkdownImages = raw.contains('![') && raw.contains('](');
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
        final parsed = await _parseTextAndImages(
          raw,
          allowRemoteImages: allowRemoteImages,
          allowLocalImages: canImageInput,
          allowDataImages: canImageInput,
          keepRemoteMarkdownText: true,
          keepDisallowedImageText: canImageInput,
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
          if (!allowRemoteImages && _isRemoteHttpUrl(url)) return;
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
            url = await _tryEncodeBase64DataUrl(ref.src);
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
        final supplementalRefs = _supplementalMediaRefs(
          internalRaw: m[multimodalInternalMediaPathsKey],
          userPaths: userImagePaths,
          includeUserPaths: hasAttachedImages,
        );
        for (final mediaRef in supplementalRefs) {
          final p = mediaRef.uri;
          final String mime = _mimeForInternalMediaRef(mediaRef);
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
          if (!allowRemoteImages && _isRemoteHttpUrl(p)) {
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
          final dataUrl = (_isRemoteHttpUrl(p) || p.startsWith('data:'))
              ? p
              : await _tryEncodeBase64DataUrl(p, explicitMime: mediaRef.mime);
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
      ...builtInPayload.body,
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
    // OpenAI-compatible native search can optionally expose source details.
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
    final mm = await _buildOpenAIChatCompletionMessages(
      messages,
      userMediaPaths: userImagePaths,
      canImageInput: canImageInput,
      allowRemoteImages: allowRemoteImages,
      reasoningContentReplayPolicy: info.reasoningContentReplayPolicy,
      stripReasoningContent: isClaudeUpstream,
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
        'tools': _cleanToolsForCompatibility(tools),
      if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
    };
    setMaxTokens(body);
  }

  // Vendor-specific reasoning knobs for chat-completions compatible hosts
  if (config.useResponseApi != true) {
    _applyVendorReasoningKnobs(
      body,
      info: info,
      isReasoning: isReasoning,
      thinkingBudget: thinkingBudget,
    );
    if (info.isKimiThinkingModel) {
      _normalizeMoonshotKimiChatBody(
        body,
        upstreamModelId: upstreamModelId,
        isReasoning: isReasoning,
        thinkingBudget: thinkingBudget,
      );
    }
  }

  final request = http.Request('POST', url);
  final headers = _customHeaders(
    config,
    modelId,
    baseHeaders: <String, String>{
      'Authorization': 'Bearer ${_apiKeyForRequest(config, modelId)}',
      'Content-Type': 'application/json',
      'Accept': stream ? 'text/event-stream' : 'application/json',
    },
    assistantHeaders: extraHeaders,
  );
  request.headers.addAll(headers);
  _maybeAddStreamingUsageOptions(
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
  _applyOpenRouterClaudePromptCaching(
    body,
    config: config,
    upstreamModelId: upstreamModelId,
  );

  // Merge custom body keys (override takes precedence)
  final extraBodyCfg = _customBody(config, modelId, assistantBody: extraBody);
  if (extraBodyCfg.isNotEmpty) {
    body.addAll(extraBodyCfg);
  }
  if (config.useResponseApi != true) {
    _applyChatCompletionsBuiltInTools(
      body,
      config: config,
      modelId: modelId,
      upstreamModelId: upstreamModelId,
    );
  }
  _sanitizeOpenAIGpt5SamplingParams(
    body,
    upstreamModelId,
    fallbackEffort: effort,
    isOpenRouter: info.isOpenRouter,
  );
  _normalizeMoonshotKimiChatBody(
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
    final txt = await response.stream.bytesToString();
    try {
      final obj = jsonDecode(txt);
      // Responses API non-stream
      if (config.useResponseApi == true) {
        String outText = '';
        final rawOutput = obj['output'] ?? obj['response']?['output'];
        final reasoningText = _responsesReasoningText(rawOutput);
        try {
          outText = (obj['output_text'] ?? '').toString();
        } catch (_) {}
        if (outText.isEmpty) {
          try {
            outText = (obj['response']?['output_text'] ?? '').toString();
          } catch (_) {}
        }
        final shouldReadOutputText = outText.isEmpty;
        try {
          final out = rawOutput as List?;
          if (out != null) {
            final buf = StringBuffer(outText);
            for (final it in out) {
              if (it is! Map) continue;
              if (_isResponsesImageGenerationType(it['type'])) {
                final mdImg = await _responsesImageGenerationMarkdown(it);
                if (mdImg.isNotEmpty) buf.write(mdImg);
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
        final usage = _mergeOpenAICompatibleUsage(
          null,
          obj['usage'] ?? obj['response']?['usage'],
        );
        yield ChatStreamChunk(
          content: outText,
          reasoning: reasoningText.isEmpty ? null : reasoningText,
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
        if (tcs.isNotEmpty && effectiveOnToolCall != null) {
          final calls = <Map<String, dynamic>>[];
          final callInfos = <ToolCallInfo>[];
          for (int i = 0; i < tcs.length; i++) {
            final t = (tcs[i] as Map).cast<String, dynamic>();
            final id = _effectiveToolCallId(t['id'], 'call', i);
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
            final res = await effectiveOnToolCall(
              c.name,
              c.arguments,
              toolCallId: c.id,
            );
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
          final headers2 = _customHeaders(
            config,
            modelId,
            baseHeaders: <String, String>{
              'Authorization': 'Bearer ${_apiKeyForRequest(config, modelId)}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            assistantHeaders: extraHeaders,
          );
          req.headers.addAll(headers2);
          final next = <Map<String, dynamic>>[];
          for (final m in messages) {
            next.add(_copyChatCompletionMessage(m));
          }
          final assistantToolCallMsg = _buildAssistantToolCallMessage(
            calls: calls,
            content: msg['content'],
            reasoningContent: needsReasoningEcho ? reasoningForTools : null,
            includeEmptyReasoningContent: needsReasoningEcho,
            reasoningDetails: reasoningDetailsForTools,
          );
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
          reqBody['messages'] = await _buildOpenAIChatCompletionMessages(
            next,
            userMediaPaths: userImagePaths,
            canImageInput: canImageInput,
            allowRemoteImages: allowRemoteImages,
            reasoningContentReplayPolicy: info.reasoningContentReplayPolicy,
            stripReasoningContent: isClaudeUpstream,
          );
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
          reasoningDetails: cmsg?['reasoning_details'],
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
  final reasoningDetailsBuffer = _ReasoningDetailsAccumulator(
    allowSnapshots: reasoningDetailsAllowSnapshots,
  );
  String assistantContentBuffer = '';

  // Track potential tool calls (OpenAI Chat Completions)
  final Map<int, Map<String, String>> toolAcc =
      <int, Map<String, String>>{}; // index -> {id,name,args}
  // Track potential tool calls (OpenAI Responses API)
  final Map<String, Map<String, String>> toolAccResp =
      <String, Map<String, String>>{}; // id/name -> {name,args}
  // Responses API: track by output_index to capture call_id reliably
  final Map<int, Map<String, String>> respToolCallsByIndex =
      <int, Map<String, String>>{}; // index -> {call_id,name,args}
  final Map<int, _ResponsesImageGenerationResult> responsesImagesByIndex =
      <int, _ResponsesImageGenerationResult>{};
  List<Map<String, dynamic>> lastResponseOutputItems =
      const <Map<String, dynamic>>[];
  String? finishReason;

  await for (final chunk in _ensureTrailingNewline(sse)) {
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
        if (effectiveOnToolCall != null && toolAcc.isNotEmpty) {
          final calls = <Map<String, dynamic>>[];
          final callInfos = <ToolCallInfo>[];
          final toolMsgs = <Map<String, dynamic>>[];
          toolAcc.forEach((idx, m) {
            final id = _effectiveToolCallId(m['id'], 'call', idx);
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
            final res = await effectiveOnToolCall(name, args, toolCallId: id);
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
          final assistantToolCallMsg = _buildAssistantToolCallMessage(
            calls: calls,
            content: assistantContentBuffer,
            reasoningContent: needsReasoningEcho ? reasoningBuffer : null,
            includeEmptyReasoningContent: needsReasoningEcho,
            reasoningDetails: reasoningDetailsBuffer.detailsOrNull,
          );
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
            final Map<String, dynamic> body2 = {
              'model': upstreamModelId,
              'messages': await _buildOpenAIChatCompletionMessages(
                currentMessages,
                userMediaPaths: userImagePaths,
                canImageInput: canImageInput,
                allowRemoteImages: allowRemoteImages,
                reasoningContentReplayPolicy: info.reasoningContentReplayPolicy,
                stripReasoningContent: isClaudeUpstream,
              ),
              'stream': true,
              if (temperature != null) 'temperature': temperature,
              if (topP != null) 'top_p': topP,
              if (isReasoning && effort != 'off' && effort != 'auto')
                'reasoning_effort': effort,
              if (tools != null && tools.isNotEmpty)
                'tools': _cleanToolsForCompatibility(tools),
              if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
            };
            setMaxTokens(body2);

            _applyVendorReasoningKnobs(
              body2,
              info: info,
              isReasoning: isReasoning,
              thinkingBudget: thinkingBudget,
            );

            // Ask for usage in streaming (when supported)
            _maybeAddStreamingUsageOptions(
              body2,
              stream: true,
              config: config,
              host: info.host,
            );

            // Apply custom body overrides
            if (extraBodyCfg.isNotEmpty) {
              body2.addAll(extraBodyCfg);
            }
            _applyChatCompletionsBuiltInTools(
              body2,
              config: config,
              modelId: modelId,
              upstreamModelId: upstreamModelId,
            );

            _sanitizeOpenAIGpt5SamplingParams(
              body2,
              upstreamModelId,
              fallbackEffort: effort,
              isOpenRouter: info.isOpenRouter,
            );
            _normalizeMoonshotKimiChatBody(
              body2,
              upstreamModelId: upstreamModelId,
              isReasoning: isReasoning,
              thinkingBudget: thinkingBudget,
            );

            final req2 = http.Request('POST', url);
            final headers2 = _customHeaders(
              config,
              modelId,
              baseHeaders: <String, String>{
                'Authorization': 'Bearer ${_apiKeyForRequest(config, modelId)}',
                'Content-Type': 'application/json',
                'Accept': 'text/event-stream',
              },
              assistantHeaders: extraHeaders,
            );
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
            final reasoningDetailsAccum = _ReasoningDetailsAccumulator(
              allowSnapshots: reasoningDetailsAllowSnapshots,
            );
            await for (final ch in _ensureTrailingNewline(s2)) {
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
                _throwIfInBandStreamError(d);
                try {
                  final o = jsonDecode(d);
                  if (o is Map) {
                    usage = _mergeOpenAICompatibleUsage(usage, o['usage']);
                    if (usage != null) totalTokens = usage.totalTokens;
                  }
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
                    final rd = delta?['reasoning_details'];
                    if (rd is List && rd.isNotEmpty) {
                      reasoningDetailsAccum.add(rd);
                    }
                    final rdMsg = message?['reasoning_details'];
                    if (rdMsg is List && rdMsg.isNotEmpty) {
                      reasoningDetailsAccum.add(rdMsg);
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
                final id = _effectiveToolCallId(m['id'], 'call', idx);
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
                final res = await effectiveOnToolCall(
                  name,
                  args,
                  toolCallId: id,
                );
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
              final nextAssistantToolCall = _buildAssistantToolCallMessage(
                calls: calls2,
                content: contentAccum,
                reasoningContent: needsReasoningEcho ? reasoningAccum : null,
                includeEmptyReasoningContent: needsReasoningEcho,
                reasoningDetails: reasoningDetailsAccum.detailsOrNull,
              );
              currentMessages = [
                ...currentMessages,
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
                reasoningDetails: reasoningDetailsAccum.detailsOrNull,
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
          reasoningDetails: reasoningDetailsBuffer.detailsOrNull,
          isDone: true,
          totalTokens: usage?.totalTokens ?? approxTotal,
          usage: usage,
        );
        return;
      }

      _throwIfInBandStreamError(data);
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
          } else if (type == 'response.reasoning_summary_text.delta' ||
              type == 'response.reasoning_text.delta') {
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
              } else if (item is Map &&
                  _isResponsesImageGenerationType(item['type'])) {
                responsesImagesByIndex[idx] = _ResponsesImageGenerationResult(
                  source: _responsesImageGenerationSource(item),
                  outputFormat:
                      (item['output_format'] ?? item['outputFormat'] ?? '')
                          .toString(),
                );
              }
            } catch (_) {}
          } else if (type == 'response.image_generation_call.partial_image') {
            try {
              final b64 = (json['partial_image_b64'] ?? '').toString();
              if (b64.isNotEmpty) {
                final idx = (json['output_index'] ?? 0) as int;
                responsesImagesByIndex[idx] = _ResponsesImageGenerationResult(
                  source: b64,
                  outputFormat: (json['output_format'] ?? '').toString(),
                );
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
              } else if (item is Map &&
                  _isResponsesImageGenerationType(item['type'])) {
                final source = _responsesImageGenerationSource(item);
                if (source.isNotEmpty) {
                  responsesImagesByIndex[idx] = _ResponsesImageGenerationResult(
                    source: source,
                    outputFormat:
                        (item['output_format'] ?? item['outputFormat'] ?? '')
                            .toString(),
                  );
                }
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
              usage = _mergeOpenAICompatibleUsage(usage, u);
              totalTokens = usage?.totalTokens ?? totalTokens;
            }
            // Extract web search citations from final output (Responses API)
            try {
              final output = json['response']?['output'];
              final items = <Map<String, dynamic>>[];
              final completedImageIndexes = <int>{};
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
                for (
                  int outputIndex = 0;
                  outputIndex < output.length;
                  outputIndex++
                ) {
                  final it = output[outputIndex];
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
                  } else if (_isResponsesImageGenerationType(it['type'])) {
                    final mdImg = await _responsesImageGenerationMarkdown(it);
                    if (mdImg.isNotEmpty) {
                      completedImageIndexes.add(outputIndex);
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
              if (responsesImagesByIndex.isNotEmpty) {
                final sortedIndexes = responsesImagesByIndex.keys.toList()
                  ..sort();
                for (final index in sortedIndexes) {
                  if (completedImageIndexes.contains(index)) continue;
                  final image = responsesImagesByIndex[index];
                  if (image == null || image.source.isEmpty) continue;
                  final mdImg = await _responsesImageGenerationMarkdown({
                    'result': image.source,
                    'output_format': image.outputFormat,
                  });
                  if (mdImg.isNotEmpty) {
                    yield ChatStreamChunk(
                      content: mdImg,
                      isDone: false,
                      totalTokens: totalTokens,
                      usage: usage,
                    );
                  }
                }
                responsesImagesByIndex.clear();
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
            if (effectiveOnToolCall != null && hasRespCalls) {
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
                  final id = _effectiveToolCallId(callId, 'call', idx);
                  callInfos.add(
                    ToolCallInfo(id: id, name: name, arguments: args),
                  );
                  msgs.add({'__id': id, '__name': name, '__args': args});
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
                  final id2 = _effectiveToolCallId(key, 'call', idx);
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
              final responseOutputItems = _withResponsesFunctionCallItems(
                lastResponseOutputItems,
                callInfos,
              );
              final resultsInfo = <ToolResultInfo>[];
              final followUpOutputs = <Map<String, dynamic>>[];
              for (final m in msgs) {
                final nm = m['__name'] as String;
                final id2 = m['__id'] as String;
                final args = (m['__args'] as Map<String, dynamic>);
                final res = await effectiveOnToolCall(
                  nm,
                  args,
                  toolCallId: id2,
                );
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
              if (responseOutputItems.isNotEmpty) {
                currentInput.addAll(responseOutputItems);
              }
              currentInput.addAll(followUpOutputs);

              // Iteratively request until the model stops issuing tool calls,
              // consistent with how Claude, Gemini and OpenAI Chat Completions
              // providers handle the tool-call loop (while-true until done).
              // Guard: break if the exact same tool-call set repeats 3 times
              // consecutively, which indicates the model is stuck in a loop.
              const int maxConsecutiveDupes = 3;
              String? lastToolSignature;
              int consecutiveDupeCount = 0;
              while (true) {
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
                final extraCfg = _customBody(
                  config,
                  modelId,
                  assistantBody: extraBody,
                );
                if (extraCfg.isNotEmpty) body2.addAll(extraCfg);
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
                  isOpenRouter: info.isOpenRouter,
                );

                final req2 = http.Request('POST', url);
                final headers2 = _customHeaders(
                  config,
                  modelId,
                  baseHeaders: <String, String>{
                    'Authorization':
                        'Bearer ${_apiKeyForRequest(config, modelId)}',
                    'Content-Type': 'application/json',
                    'Accept': 'text/event-stream',
                  },
                  assistantHeaders: extraHeaders,
                );
                req2.headers.addAll(headers2);
                req2.body = jsonEncode(body2);
                final http.StreamedResponse resp2;
                try {
                  resp2 = await client.send(req2);
                  if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
                    final errorBody = await resp2.stream.bytesToString();
                    throw HttpException('HTTP ${resp2.statusCode}: $errorBody');
                  }
                } on HttpException {
                  rethrow;
                } catch (e) {
                  // Keep as HttpException so the per-event catch below (which
                  // tolerates malformed JSON) cannot swallow this failure.
                  throw HttpException('Follow-up request failed: $e');
                }
                final s2 = _rethrowFollowUpStreamErrors(
                  resp2.stream.transform(utf8.decoder),
                );
                String buf2 = '';
                final Map<int, Map<String, String>> respCalls2 =
                    <int, Map<String, String>>{};
                List<Map<String, dynamic>> outItems2 =
                    const <Map<String, dynamic>>[];
                await for (final ch in _ensureTrailingNewline(s2)) {
                  buf2 += ch;
                  final lines2 = buf2.split('\n');
                  buf2 = lines2.last;
                  for (int j = 0; j < lines2.length - 1; j++) {
                    final l = lines2[j].trim();
                    if (l.isEmpty || !l.startsWith('data:')) continue;
                    final d = l.substring(5).trimLeft();
                    if (d == '[DONE]') continue;
                    _throwIfInBandStreamError(d);
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
                          usage = _mergeOpenAICompatibleUsage(usage, u2);
                          totalTokens = usage?.totalTokens ?? totalTokens;
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

                // Detect consecutive duplicate tool-call patterns
                final sorted2 = respCalls2.keys.toList()..sort();
                final sigParts = <String>[];
                for (final idx2 in sorted2) {
                  final m2 = respCalls2[idx2]!;
                  sigParts.add('${m2['name'] ?? ''}:${m2['args'] ?? ''}');
                }
                final currentSig = sigParts.join('|');
                if (currentSig == lastToolSignature) {
                  consecutiveDupeCount += 1;
                  if (consecutiveDupeCount >= maxConsecutiveDupes) {
                    // Break out of loop – model is stuck repeating the same calls
                    break;
                  }
                } else {
                  lastToolSignature = currentSig;
                  consecutiveDupeCount = 1;
                }

                // Execute next round of tool calls
                final callInfos2 = <ToolCallInfo>[];
                final msgs2 = <Map<String, dynamic>>[];
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
                  final id2 = _effectiveToolCallId(callId2, 'call', idx2);
                  callInfos2.add(
                    ToolCallInfo(id: id2, name: name2, arguments: args2),
                  );
                  msgs2.add({'__id': id2, '__name': name2, '__args': args2});
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
                final responseOutputItems2 = _withResponsesFunctionCallItems(
                  outItems2,
                  callInfos2,
                );
                final resultsInfo2 = <ToolResultInfo>[];
                final followUpOutputs2 = <Map<String, dynamic>>[];
                for (final m in msgs2) {
                  final nm = m['__name'] as String;
                  final id2 = m['__id'] as String;
                  final args2 = (m['__args'] as Map<String, dynamic>);
                  final res2 = await effectiveOnToolCall(
                    nm,
                    args2,
                    toolCallId: id2,
                  );
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
                if (responseOutputItems2.isNotEmpty) {
                  currentInput.addAll(responseOutputItems2);
                }
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
                usage = _mergeOpenAICompatibleUsage(usage, u);
                totalTokens = usage?.totalTokens ?? totalTokens;
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
              // Capture vendor reasoning details (may carry thinking
              // signatures) from any provider that sends them.
              final rdDelta = delta['reasoning_details'];
              if (rdDelta is List && rdDelta.isNotEmpty) {
                reasoningDetailsBuffer.add(rdDelta);
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

            if (message != null) {
              final rdMsg = message['reasoning_details'];
              if (rdMsg is List && rdMsg.isNotEmpty) {
                reasoningDetailsBuffer.add(rdMsg);
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
                  'id': _effectiveToolCallId(id, 'call', idx),
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
          usage = _mergeOpenAICompatibleUsage(usage, json['usage']);
          if (usage != null) totalTokens = usage.totalTokens;
        }

        if (content.isNotEmpty || (reasoning?.isNotEmpty ?? false)) {
          final approxTotal =
              approxPromptTokens + approxTokensFromChars(approxCompletionChars);
          if (content.isNotEmpty) {
            assistantContentBuffer += content;
          }
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
            effectiveOnToolCall != null) {
          // print('[ChatApi/XinLiu] Executing tools immediately (finishReason=tool_calls, toolAcc.size=${toolAcc.length})');
          // Some providers (like XinLiu) return tool_calls with finish_reason='tool_calls' but no [DONE]
          // Execute tools immediately in this case
          final calls = <Map<String, dynamic>>[];
          final callInfos = <ToolCallInfo>[];
          final toolMsgs = <Map<String, dynamic>>[];
          toolAcc.forEach((idx, m) {
            final id = _effectiveToolCallId(m['id'], 'call', idx);
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
            final res = await effectiveOnToolCall(name, args, toolCallId: id);
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
          final assistantToolCallMsg = _buildAssistantToolCallMessage(
            calls: calls,
            content: assistantContentBuffer,
            reasoningContent: needsReasoningEcho ? reasoningBuffer : null,
            includeEmptyReasoningContent: needsReasoningEcho,
            reasoningDetails: reasoningDetailsBuffer.detailsOrNull,
          );
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
            final Map<String, dynamic> body2 = {
              'model': upstreamModelId,
              'messages': await _buildOpenAIChatCompletionMessages(
                currentMessages,
                userMediaPaths: userImagePaths,
                canImageInput: canImageInput,
                allowRemoteImages: allowRemoteImages,
                reasoningContentReplayPolicy: info.reasoningContentReplayPolicy,
                stripReasoningContent: isClaudeUpstream,
              ),
              'stream': true,
              if (temperature != null) 'temperature': temperature,
              if (topP != null) 'top_p': topP,
              if (isReasoning && effort != 'off' && effort != 'auto')
                'reasoning_effort': effort,
              if (tools != null && tools.isNotEmpty)
                'tools': _cleanToolsForCompatibility(tools),
              if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
            };
            setMaxTokens(body2);
            _applyVendorReasoningKnobs(
              body2,
              info: info,
              isReasoning: isReasoning,
              thinkingBudget: thinkingBudget,
            );
            _maybeAddStreamingUsageOptions(
              body2,
              stream: true,
              config: config,
              host: info.host,
            );
            if (extraBodyCfg.isNotEmpty) {
              body2.addAll(extraBodyCfg);
            }
            _applyChatCompletionsBuiltInTools(
              body2,
              config: config,
              modelId: modelId,
              upstreamModelId: upstreamModelId,
            );
            _sanitizeOpenAIGpt5SamplingParams(
              body2,
              upstreamModelId,
              fallbackEffort: effort,
              isOpenRouter: info.isOpenRouter,
            );
            _normalizeMoonshotKimiChatBody(
              body2,
              upstreamModelId: upstreamModelId,
              isReasoning: isReasoning,
              thinkingBudget: thinkingBudget,
            );
            final req2 = http.Request('POST', url);
            final headers2 = _customHeaders(
              config,
              modelId,
              baseHeaders: <String, String>{
                'Authorization': 'Bearer ${_apiKeyForRequest(config, modelId)}',
                'Content-Type': 'application/json',
                'Accept': 'text/event-stream',
              },
              assistantHeaders: extraHeaders,
            );
            req2.headers.addAll(headers2);
            req2.body = jsonEncode(body2);
            final http.StreamedResponse resp2;
            try {
              resp2 = await client.send(req2);
              if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
                final errorBody = await resp2.stream.bytesToString();
                throw HttpException('HTTP ${resp2.statusCode}: $errorBody');
              }
            } on HttpException {
              rethrow;
            } catch (e) {
              // Keep as HttpException so the per-event catch below (which
              // tolerates malformed JSON) cannot swallow this failure.
              throw HttpException('Follow-up request failed: $e');
            }
            final s2 = _rethrowFollowUpStreamErrors(
              resp2.stream.transform(utf8.decoder),
            );
            String buf2 = '';
            final Map<int, Map<String, String>> toolAcc2 =
                <int, Map<String, String>>{};
            String? finishReason2;
            String contentAccum = '';
            String reasoningAccum = '';
            final reasoningDetailsAccum = _ReasoningDetailsAccumulator(
              allowSnapshots: reasoningDetailsAllowSnapshots,
            );
            await for (final ch in _ensureTrailingNewline(s2)) {
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
                _throwIfInBandStreamError(d);
                try {
                  final o = jsonDecode(d);
                  if (o is Map) {
                    usage = _mergeOpenAICompatibleUsage(usage, o['usage']);
                    if (usage != null) totalTokens = usage.totalTokens;
                  }
                  if (o is Map &&
                      o['choices'] is List &&
                      (o['choices'] as List).isNotEmpty) {
                    final c0 = (o['choices'] as List).first;
                    finishReason2 = c0['finish_reason'] as String?;
                    final delta = c0['delta'] as Map?;
                    final txt = _extractOpenAICompatibleDeltaText(delta);
                    final rc =
                        delta?['reasoning_content'] ?? delta?['reasoning'];
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
                    final rd = delta?['reasoning_details'];
                    if (rd is List && rd.isNotEmpty) {
                      reasoningDetailsAccum.add(rd);
                    }
                    final rdMsg = message?['reasoning_details'];
                    if (rdMsg is List && rdMsg.isNotEmpty) {
                      reasoningDetailsAccum.add(rdMsg);
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
                          'id': _effectiveToolCallId(id, 'call', idx),
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
                final id = _effectiveToolCallId(m['id'], 'call', idx);
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
                final res = await effectiveOnToolCall(
                  name,
                  args,
                  toolCallId: id,
                );
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
              final nextAssistantToolCall = _buildAssistantToolCallMessage(
                calls: calls2,
                content: contentAccum,
                reasoningContent: needsReasoningEcho ? reasoningAccum : null,
                includeEmptyReasoningContent: needsReasoningEcho,
                reasoningDetails: reasoningDetailsAccum.detailsOrNull,
              );
              currentMessages = [
                ...currentMessages,
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
                reasoningDetails: reasoningDetailsAccum.detailsOrNull,
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
            if (effectiveOnToolCall != null && toolAcc.isNotEmpty) {
              final calls = <Map<String, dynamic>>[];
              final callInfos = <ToolCallInfo>[];
              final toolMsgs = <Map<String, dynamic>>[];
              toolAcc.forEach((idx, m) {
                final id = _effectiveToolCallId(m['id'], 'call', idx);
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
                final res = await effectiveOnToolCall(
                  name,
                  args,
                  toolCallId: id,
                );
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
              final assistantToolCallMsg = _buildAssistantToolCallMessage(
                calls: calls,
                content: assistantContentBuffer,
                reasoningContent: needsReasoningEcho ? reasoningBuffer : null,
                includeEmptyReasoningContent: needsReasoningEcho,
                reasoningDetails: reasoningDetailsBuffer.detailsOrNull,
              );
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
                final Map<String, dynamic> body2 = {
                  'model': upstreamModelId,
                  'messages': await _buildOpenAIChatCompletionMessages(
                    currentMessages,
                    userMediaPaths: userImagePaths,
                    canImageInput: canImageInput,
                    allowRemoteImages: allowRemoteImages,
                    reasoningContentReplayPolicy:
                        info.reasoningContentReplayPolicy,
                    stripReasoningContent: isClaudeUpstream,
                  ),
                  'stream': true,
                  if (temperature != null) 'temperature': temperature,
                  if (topP != null) 'top_p': topP,
                  if (isReasoning && effort != 'off' && effort != 'auto')
                    'reasoning_effort': effort,
                  if (tools != null && tools.isNotEmpty)
                    'tools': _cleanToolsForCompatibility(tools),
                  if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
                };
                setMaxTokens(body2);
                _applyVendorReasoningKnobs(
                  body2,
                  info: info,
                  isReasoning: isReasoning,
                  thinkingBudget: thinkingBudget,
                );
                _maybeAddStreamingUsageOptions(
                  body2,
                  stream: true,
                  config: config,
                  host: info.host,
                );
                if (extraBodyCfg.isNotEmpty) {
                  body2.addAll(extraBodyCfg);
                }
                _applyChatCompletionsBuiltInTools(
                  body2,
                  config: config,
                  modelId: modelId,
                  upstreamModelId: upstreamModelId,
                );
                _sanitizeOpenAIGpt5SamplingParams(
                  body2,
                  upstreamModelId,
                  fallbackEffort: effort,
                  isOpenRouter: info.isOpenRouter,
                );
                _normalizeMoonshotKimiChatBody(
                  body2,
                  upstreamModelId: upstreamModelId,
                  isReasoning: isReasoning,
                  thinkingBudget: thinkingBudget,
                );
                final req2 = http.Request('POST', url);
                final headers2 = _customHeaders(
                  config,
                  modelId,
                  baseHeaders: <String, String>{
                    'Authorization':
                        'Bearer ${_apiKeyForRequest(config, modelId)}',
                    'Content-Type': 'application/json',
                    'Accept': 'text/event-stream',
                  },
                  assistantHeaders: extraHeaders,
                );
                req2.headers.addAll(headers2);
                req2.body = jsonEncode(body2);
                final http.StreamedResponse resp2;
                try {
                  resp2 = await client.send(req2);
                  if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
                    final errorBody = await resp2.stream.bytesToString();
                    throw HttpException('HTTP ${resp2.statusCode}: $errorBody');
                  }
                } on HttpException {
                  rethrow;
                } catch (e) {
                  // Keep as HttpException so the per-event catch below (which
                  // tolerates malformed JSON) cannot swallow this failure.
                  throw HttpException('Follow-up request failed: $e');
                }
                final s2 = _rethrowFollowUpStreamErrors(
                  resp2.stream.transform(utf8.decoder),
                );
                String buf2 = '';
                final Map<int, Map<String, String>> toolAcc2 =
                    <int, Map<String, String>>{};
                String? finishReason2;
                String contentAccum = '';
                String reasoningAccum = '';
                final reasoningDetailsAccum = _ReasoningDetailsAccumulator(
                  allowSnapshots: reasoningDetailsAllowSnapshots,
                );
                await for (final ch in _ensureTrailingNewline(s2)) {
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
                    _throwIfInBandStreamError(d);
                    try {
                      final o = jsonDecode(d);
                      if (o is Map) {
                        usage = _mergeOpenAICompatibleUsage(usage, o['usage']);
                        if (usage != null) totalTokens = usage.totalTokens;
                      }
                      if (o is Map &&
                          o['choices'] is List &&
                          (o['choices'] as List).isNotEmpty) {
                        final c0 = (o['choices'] as List).first;
                        finishReason2 = c0['finish_reason'] as String?;
                        final delta = c0['delta'] as Map?;
                        final txt = _extractOpenAICompatibleDeltaText(delta);
                        final rc =
                            delta?['reasoning_content'] ?? delta?['reasoning'];
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
                        final rd = delta?['reasoning_details'];
                        if (rd is List && rd.isNotEmpty) {
                          reasoningDetailsAccum.add(rd);
                        }
                        final rdMsg = message?['reasoning_details'];
                        if (rdMsg is List && rdMsg.isNotEmpty) {
                          reasoningDetailsAccum.add(rdMsg);
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
                              'id': _effectiveToolCallId(id, 'call', idx),
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
                    final id = _effectiveToolCallId(m['id'], 'call', idx);
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
                    final res = await effectiveOnToolCall(
                      name,
                      args,
                      toolCallId: id,
                    );
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
                  final nextAssistantToolCall = _buildAssistantToolCallMessage(
                    calls: calls2,
                    content: contentAccum,
                    reasoningContent: needsReasoningEcho
                        ? reasoningAccum
                        : null,
                    includeEmptyReasoningContent: needsReasoningEcho,
                    reasoningDetails: reasoningDetailsAccum.detailsOrNull,
                  );
                  currentMessages = [
                    ...currentMessages,
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
          } else if (info.isOpenRouter) {
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
      } on HttpException {
        // In-band error frames raised inside this block (follow-up tool-call
        // streams call _throwIfInBandStreamError in here) and failed follow-up
        // requests must surface as stream errors; swallowing them would let
        // the no-[DONE] fallback below persist truncated output as a normal
        // completion.
        rethrow;
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
    reasoningDetails: reasoningDetailsBuffer.detailsOrNull,
    isDone: true,
    totalTokens: approxTotal,
    usage: usage,
  );
}
