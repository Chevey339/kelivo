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

Future<({String uri, String mimeType})?> _saveResponsesImageGeneration(
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
    if (commaIndex < 0) return null;
    mime = _mimeFromDataUrl(imageBase64);
    imageBase64 = imageBase64.substring(commaIndex + 1);
  }
  final savedPath = await AppDirectories.saveBase64Image(mime, imageBase64);
  if (savedPath == null || savedPath.isEmpty) return null;
  return (uri: SandboxPathResolver.canonicalize(savedPath), mimeType: mime);
}

Future<String> _saveResponsesImageGenerationMarkdown(
  String imageData, {
  String? outputFormat,
}) async {
  final saved = await _saveResponsesImageGeneration(
    imageData,
    outputFormat: outputFormat,
  );
  if (saved == null) return '';
  return '\n![image](${saved.uri})\n';
}

void _logImageFallback({
  required String provider,
  required String model,
  required String reason,
}) {
  final message = 'provider=$provider model=$model reason=$reason';
  debugPrint('[ImageFallback] $message');
  FlutterLogger.log(message, tag: 'ImageFallback');
}

bool _isResponsesImageGenerationType(dynamic type) {
  return type == 'image_generation_call' ||
      type == 'openrouter:image_generation';
}

void _applyCompatibleBuiltInSearch(
  Map<String, dynamic> body, {
  required ProviderConfig config,
  required String modelId,
  required String upstreamModelId,
}) {
  final builtIns = _builtInTools(config, modelId);
  if (!builtIns.contains(BuiltInToolNames.search)) return;

  if (BuiltInToolsHelper.isOpenRouterProvider(config)) {
    if (config.useResponseApi == true) return;
    final plugins = <Map<String, dynamic>>[];
    final existingPlugins = body['plugins'];
    if (existingPlugins is List) {
      for (final plugin in existingPlugins) {
        if (plugin is Map) {
          plugins.add(plugin.cast<String, dynamic>());
        }
      }
    }
    final hasWebPlugin = plugins.any(
      (plugin) => (plugin['id'] ?? '').toString() == 'web',
    );
    if (!hasWebPlugin) {
      plugins.add({'id': 'web'});
    }
    body['plugins'] = plugins;
    return;
  }

  if (BuiltInToolsHelper.isGrokModel(upstreamModelId)) {
    body['search_parameters'] = {'mode': 'auto', 'return_citations': true};
    return;
  }

  if (config.useResponseApi == true) return;

  if (BuiltInToolsHelper.isDashScopeProvider(config)) {
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
    return;
  }

  // MiMo: native chat Completions `web_search` tool (+ optional web_search_usage).
  if (BuiltInToolsHelper.isMimoProvider(config) &&
      BuiltInToolsHelper.isMimoBuiltInSearchSupportedModel(upstreamModelId)) {
    _appendChatTool(body, {'type': 'web_search'});
    return;
  }

  // GLM / Zhipu: native chat web_search tool structure.
  if (BuiltInToolsHelper.isZhipuProvider(config) &&
      BuiltInToolsHelper.isGlmBuiltInSearchSupportedModel(upstreamModelId)) {
    _appendChatTool(body, {
      'type': 'web_search',
      'web_search': {'enable': true, 'search_result': true},
    });
    return;
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

Map<String, dynamic>? _openaiFirstChoice(Map<String, dynamic> obj) {
  try {
    final choices = obj['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      return (choices.first as Map).cast<String, dynamic>();
    }
  } catch (_) {}
  return null;
}

Map<String, dynamic>? _openaiFirstChoiceMessage(Map<String, dynamic> obj) {
  return (_openaiFirstChoice(obj)?['message'] as Map?)?.cast<String, dynamic>();
}

List<EmitToolCall> _openaiCallsFromCompletionMessage(
  Map<String, dynamic>? msg,
) {
  final tcs = (msg?['tool_calls'] as List?) ?? const <dynamic>[];
  final calls = <EmitToolCall>[];
  for (var i = 0; i < tcs.length; i++) {
    final raw = tcs[i];
    if (raw is! Map) continue;
    final t = raw.cast<String, dynamic>();
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
    calls.add(emitToolCall(id: id, name: name, arguments: args));
  }
  return calls;
}

TokenUsage? _openaiUsageFromObj(Map<String, dynamic> obj) {
  try {
    final u = obj['usage'];
    if (u is! Map) return null;
    final prompt = (u['prompt_tokens'] ?? 0) as int? ?? 0;
    final completion = (u['completion_tokens'] ?? 0) as int? ?? 0;
    final cached =
        (u['prompt_tokens_details']?['cached_tokens'] ?? 0) as int? ?? 0;
    return TokenUsage(
      promptTokens: prompt,
      completionTokens: completion,
      cachedTokens: cached,
      totalTokens: prompt + completion,
    );
  } catch (_) {
    return null;
  }
}

String? _openaiReasoningText(Map<String, dynamic>? message) {
  final raw = (message?['reasoning_content'] ?? message?['reasoning'])
      ?.toString();
  if (raw == null || raw.isEmpty) return null;
  return raw;
}

({String content, List<({String uri, String mimeType})> images})
_openaiVisibleOutputFromMessage(Map<String, dynamic>? cmsg) {
  var content = '';
  final images = <({String uri, String mimeType})>[];
  if (cmsg == null) return (content: content, images: images);
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
          final mime = mimeTypeFromImageUri(url) ?? 'image/png';
          images.add((
            uri: completeRenderableImageUri(url, mimeType: mime),
            mimeType: mime,
          ));
        }
      }
    }
    content = buf.toString();
  }
  return (content: content, images: images);
}

List<EmitToolCall> _responsesCallsFromIndexMap(
  Map<int, Map<String, String>> byIndex,
) {
  final calls = <EmitToolCall>[];
  final sorted = byIndex.keys.toList()..sort();
  for (final idx in sorted) {
    final m = byIndex[idx]!;
    Map<String, dynamic> args;
    try {
      args = (jsonDecode(m['args'] ?? '{}') as Map).cast<String, dynamic>();
    } catch (_) {
      args = <String, dynamic>{};
    }
    calls.add(
      emitToolCall(
        id: _effectiveToolCallId(m['call_id'], 'call', idx),
        name: (m['name'] ?? '').toString(),
        arguments: args,
      ),
    );
  }
  return calls;
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

/// Follow-up tool-call responses are consumed inside the SSE parser's
/// per-event catch, which tolerates malformed JSON. Convert their transport
/// failures into [HttpException] up front so that catch cannot swallow them
/// and let the no-[DONE] fallback persist truncated output as a completion.
Stream<StreamChunk> _runOpenAIChatCompletionsToolFollowUps({
  required http.Client client,
  required ProviderConfig config,
  required String modelId,
  required String upstreamModelId,
  required Uri url,
  required _OpenAIProviderInfo info,
  required List<Map<String, dynamic>> messages,
  required Map<dynamic, dynamic> firstToolAcc,
  required String firstAssistantContent,
  required String firstReasoning,
  required dynamic firstReasoningDetails,
  required ToolCallHandler onToolCall,
  required List<String>? userImagePaths,
  required bool canImageInput,
  required bool allowRemoteImages,
  required bool isClaudeUpstream,
  required bool isReasoning,
  required String effort,
  required int? thinkingBudget,
  required double? temperature,
  required double? topP,
  required List<Map<String, dynamic>>? tools,
  required Map<String, dynamic> extraBodyCfg,
  required Map<String, String>? extraHeaders,
  required bool wantsImageOutput,
  required bool needsReasoningEcho,
  required bool reasoningDetailsAllowSnapshots,
  required void Function(Map<String, dynamic> body) applyMaxTokens,
  required TokenUsage? initialUsage,
  required int streamRound,
  required int approxPromptTokens,
  required int approxCompletionChars,
  required bool includeReasoningDetailsOnDone,
}) async* {
  var usage = initialUsage;
  var chars = approxCompletionChars;
  var round = streamRound;
  ChatCompletionsStreamDecoder? lastRound;
  var currentMessages = [
    for (final message in messages) _copyChatCompletionMessage(message),
  ];

  String assistantContent() =>
      lastRound?.assistantContent ?? firstAssistantContent;
  String reasoning() => lastRound?.reasoningEcho ?? firstReasoning;
  dynamic reasoningDetails() =>
      lastRound?.reasoningDetails ?? firstReasoningDetails;

  yield* runClientToolFollowUps(
    initialCalls: clientToolCallsFromChatAcc(firstToolAcc),
    onToolCall: onToolCall,
    append: (executed) {
      currentMessages = [
        ...currentMessages,
        _buildAssistantToolCallMessage(
          calls: openaiToolCallMaps([for (final item in executed) item.call]),
          content: assistantContent(),
          reasoningContent: needsReasoningEcho ? reasoning() : null,
          includeEmptyReasoningContent: needsReasoningEcho,
          reasoningDetails: reasoningDetails(),
        ),
        ...openaiToolResultMessages(executed),
      ];
    },
    sendFollowUp: () async* {
      final body2 = <String, dynamic>{
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
      applyMaxTokens(body2);
      _applyVendorReasoningKnobs(
        body2,
        info: info,
        isReasoning: isReasoning,
        thinkingBudget: thinkingBudget,
      );
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
        host: info.host,
      );
      if (extraBodyCfg.isNotEmpty) {
        body2.addAll(extraBodyCfg);
      }
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
      req2.headers.addAll(
        _customHeaders(
          config,
          modelId,
          baseHeaders: <String, String>{
            'Authorization': 'Bearer ${_apiKeyForRequest(config, modelId)}',
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
          },
          assistantHeaders: extraHeaders,
        ),
      );
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
        throw HttpException('Follow-up request failed: $e');
      }
      final s2 = _rethrowFollowUpStreamErrors(
        resp2.stream.transform(utf8.decoder),
      );
      final roundDecoder = ChatCompletionsStreamDecoder(
        wantsImageOutput: wantsImageOutput,
        needsReasoningEcho: needsReasoningEcho,
        allowReasoningSnapshots: reasoningDetailsAllowSnapshots,
        initialUsage: usage,
        sourceId: 'round-${round++}',
      );
      await for (final event in parseSseEventStrings(s2)) {
        final data = event.data;
        if (data == '[DONE]') continue;
        _throwIfInBandStreamError(data);
        try {
          for (final chunk in roundDecoder.accept(event).chunks) {
            yield chunk;
          }
        } catch (_) {}
      }
      usage = roundDecoder.usage ?? usage;
      chars = roundDecoder.approxCompletionChars;
      lastRound = roundDecoder;
    },
    takeCallsAfterRound: () {
      final decoder = lastRound;
      if (decoder == null) return const <EmitToolCall>[];
      if (decoder.finishReason == 'tool_calls' ||
          decoder.toolCalls.isNotEmpty) {
        return clientToolCallsFromChatAcc(decoder.toolCalls);
      }
      return const <EmitToolCall>[];
    },
    finish: () {
      final approxTotal = approxPromptTokens + (chars / 4).round();
      return emitDone(
        reasoningDetails: includeReasoningDetailsOnDone
            ? lastRound?.reasoningDetails ?? firstReasoningDetails
            : null,
        usage: usage,
        totalTokens: usage?.totalTokens ?? approxTotal,
      );
    },
    usageOf: () => usage,
  );
}

Stream<StreamChunk> _runOpenAIChatCompletionsNonStreamToolFollowUps({
  required http.Client client,
  required ProviderConfig config,
  required String modelId,
  required String upstreamModelId,
  required Uri url,
  required _OpenAIProviderInfo info,
  required List<Map<String, dynamic>> messages,
  required Map<String, dynamic> requestBody,
  required Map<String, dynamic> firstObj,
  required List<EmitToolCall> initialCalls,
  required ToolCallHandler onToolCall,
  required List<String>? userImagePaths,
  required bool canImageInput,
  required bool allowRemoteImages,
  required bool isClaudeUpstream,
  required bool needsReasoningEcho,
  required Map<String, String>? extraHeaders,
  required TokenUsage? initialUsage,
}) async* {
  var usage = initialUsage;
  var lastObj = firstObj;
  var currentMessages = [
    for (final message in messages) _copyChatCompletionMessage(message),
  ];

  yield* runClientToolFollowUps(
    initialCalls: initialCalls,
    onToolCall: onToolCall,
    emitCalls: true,
    append: (executed) {
      final msg =
          _openaiFirstChoiceMessage(lastObj) ?? const <String, dynamic>{};
      final reasoningForTools =
          (msg['reasoning_content'] ?? msg['reasoning'])?.toString() ?? '';
      currentMessages = [
        ...currentMessages,
        _buildAssistantToolCallMessage(
          calls: openaiToolCallMaps([for (final item in executed) item.call]),
          content: msg['content'],
          reasoningContent: needsReasoningEcho ? reasoningForTools : null,
          includeEmptyReasoningContent: needsReasoningEcho,
          reasoningDetails: msg['reasoning_details'],
        ),
        ...openaiToolResultMessages(executed),
      ];
    },
    sendFollowUp: () async* {
      final req = http.Request('POST', url);
      req.headers.addAll(
        _customHeaders(
          config,
          modelId,
          baseHeaders: <String, String>{
            'Authorization': 'Bearer ${_apiKeyForRequest(config, modelId)}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          assistantHeaders: extraHeaders,
        ),
      );
      final reqBody = Map<String, dynamic>.from(requestBody);
      reqBody['messages'] = await _buildOpenAIChatCompletionMessages(
        currentMessages,
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
      lastObj =
          jsonDecode(await _decodeUtf8Stream(resp2.stream))
              as Map<String, dynamic>;
      final roundUsage = _openaiUsageFromObj(lastObj);
      if (roundUsage != null) {
        usage = (usage ?? const TokenUsage()).merge(roundUsage);
      }
    },
    takeCallsAfterRound: () =>
        _openaiCallsFromCompletionMessage(_openaiFirstChoiceMessage(lastObj)),
    finish: () async* {
      final choice = _openaiFirstChoice(lastObj);
      if (choice == null) {
        yield* emitDone(
          content: (lastObj['output_text'] ?? '').toString(),
          usage: usage,
          totalTokens: usage?.totalTokens ?? 0,
        );
        return;
      }
      final visible = _openaiVisibleOutputFromMessage(
        (choice['message'] as Map?)?.cast<String, dynamic>(),
      );
      final lastMessage = _openaiFirstChoiceMessage(lastObj);
      yield* emitImages(visible.images);
      yield* emitDone(
        content: visible.content,
        reasoning: _openaiReasoningText(lastMessage),
        reasoningDetails: lastMessage?['reasoning_details'],
        usage: usage,
        totalTokens: usage?.totalTokens ?? 0,
        finishReason: (choice['finish_reason'] ?? '').toString().isEmpty
            ? null
            : choice['finish_reason'].toString(),
      );
    },
    usageOf: () => usage,
  );
}

Stream<StreamChunk> _runOpenAIResponsesToolFollowUps({
  required http.Client client,
  required ProviderConfig config,
  required String modelId,
  required String upstreamModelId,
  required Uri url,
  required _OpenAIProviderInfo info,
  required List<Map<String, dynamic>> initialInput,
  required List<Map<String, dynamic>> firstOutputItems,
  required List<EmitToolCall> initialCalls,
  required List<Map<String, dynamic>> responsesToolsSpec,
  required String responsesInstructions,
  required List<dynamic>? responsesIncludeParam,
  required ToolCallHandler onToolCall,
  required Map<String, String>? extraHeaders,
  required Map<String, dynamic>? extraBody,
  required double? temperature,
  required double? topP,
  required int? maxTokens,
  required bool isReasoning,
  required String effort,
  required int? thinkingBudget,
  required TokenUsage? initialUsage,
  required int streamRound,
  required int approxPromptTokens,
  required int approxCompletionChars,
}) async* {
  var usage = initialUsage;
  var chars = approxCompletionChars;
  var round = streamRound;
  var currentInput = <Map<String, dynamic>>[...initialInput];
  var outputItemsForAppend = firstOutputItems;
  var lastCalls = const <EmitToolCall>[];
  String? lastToolSignature;
  var consecutiveDupeCount = 0;

  yield* runClientToolFollowUps(
    initialCalls: initialCalls,
    onToolCall: onToolCall,
    append: (executed) {
      currentInput = [
        ...currentInput,
        ..._withResponsesFunctionCallItems(outputItemsForAppend, [
          for (final item in executed) item.call,
        ]),
        for (final item in executed)
          <String, dynamic>{
            'type': 'function_call_output',
            'call_id': item.call.id,
            'output': item.content,
          },
      ];
    },
    sendFollowUp: () async* {
      final body2 = <String, dynamic>{
        'model': upstreamModelId,
        'input': currentInput,
        'stream': true,
        if (responsesToolsSpec.isNotEmpty) 'tools': responsesToolsSpec,
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
        if (responsesIncludeParam != null) 'include': responsesIncludeParam,
      };
      _applyCompatibleResponsesReasoning(
        body2,
        config: config,
        modelId: modelId,
        upstreamModelId: upstreamModelId,
        isReasoning: isReasoning,
        thinkingBudget: thinkingBudget,
      );
      final extraCfg = _customBody(config, modelId, assistantBody: extraBody);
      if (extraCfg.isNotEmpty) body2.addAll(extraCfg);
      try {
        if (body2['tools'] is List) {
          final raw = (body2['tools'] as List).cast<dynamic>();
          body2['tools'] = _toResponsesToolsFormat(
            raw.map((e) => (e as Map).cast<String, dynamic>()).toList(),
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
      req2.headers.addAll(
        _customHeaders(
          config,
          modelId,
          baseHeaders: <String, String>{
            'Authorization': 'Bearer ${_apiKeyForRequest(config, modelId)}',
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
          },
          assistantHeaders: extraHeaders,
        ),
      );
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
        throw HttpException('Follow-up request failed: $e');
      }
      final s2 = _rethrowFollowUpStreamErrors(
        resp2.stream.transform(utf8.decoder),
      );
      final followUpDecoder = ResponsesStreamDecoder(
        initialUsage: usage,
        sourceId: 'round-${round++}',
      );
      await for (final event in parseSseEventStrings(s2)) {
        final d = event.data;
        if (d == '[DONE]') {
          followUpDecoder.accept(event);
          break;
        }
        _throwIfInBandStreamError(d);
        final decoded = followUpDecoder.accept(event);
        for (final chunk in decoded.chunks) {
          yield chunk;
        }
        if (decoded.completed) break;
      }
      usage = followUpDecoder.usage ?? usage;
      chars += followUpDecoder.approxCompletionChars;
      outputItemsForAppend = followUpDecoder.outputItems;
      final respCalls2 = <int, Map<String, String>>{
        for (final call in followUpDecoder.takeFunctionCalls())
          call.index: <String, String>{
            'call_id': call.callId,
            'name': call.name,
            'args': call.args,
          },
      };
      lastCalls = _responsesCallsFromIndexMap(respCalls2);
      if (lastCalls.isEmpty) return;
      final sorted2 = respCalls2.keys.toList()..sort();
      final currentSig = [
        for (final idx2 in sorted2)
          '${respCalls2[idx2]!['name'] ?? ''}:${respCalls2[idx2]!['args'] ?? ''}',
      ].join('|');
      if (currentSig == lastToolSignature) {
        consecutiveDupeCount += 1;
        if (consecutiveDupeCount >= 3) {
          lastCalls = const <EmitToolCall>[];
        }
      } else {
        lastToolSignature = currentSig;
        consecutiveDupeCount = 1;
      }
    },
    takeCallsAfterRound: () => lastCalls,
    finish: () {
      final approxTotal = approxPromptTokens + (chars / 4).round();
      return emitDone(
        usage: usage,
        totalTokens: usage?.totalTokens ?? approxTotal,
      );
    },
    usageOf: () => usage,
  );
}

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

Stream<StreamChunk> _sendOpenAIStream(
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
      if (BuiltInToolsHelper.isArkProvider(config)) {
        return BuiltInToolsHelper.isDoubaoResponsesBuiltInSearchSupportedModel(
          id,
        );
      }
      return false;
    }

    if (isResponsesWebSearchSupported(upstreamModelId)) {
      if (builtIns.contains(BuiltInToolNames.search)) {
        if (BuiltInToolsHelper.isDashScopeProvider(config) ||
            BuiltInToolsHelper.isArkProvider(config)) {
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
  _applyCompatibleBuiltInSearch(
    body,
    config: config,
    modelId: modelId,
    upstreamModelId: upstreamModelId,
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
    final txt = await _decodeUtf8Stream(response.stream);
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
        final images = <({String uri, String mimeType})>[];
        try {
          final out = rawOutput as List?;
          if (out != null) {
            final buf = StringBuffer(outText);
            for (final it in out) {
              if (it is! Map) continue;
              if (_isResponsesImageGenerationType(it['type'])) {
                final b64 = (it['result'] ?? '').toString();
                if (b64.isNotEmpty) {
                  final saved = await _saveResponsesImageGeneration(
                    b64,
                    outputFormat: (it['output_format'] ?? '').toString(),
                  );
                  if (saved != null) images.add(saved);
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
        final usage = _mergeOpenAICompatibleUsage(
          null,
          obj['usage'] ?? obj['response']?['usage'],
        );
        yield* emitImages(images);
        yield* emitDone(
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
      final firstUsage = _openaiUsageFromObj(lastObj);
      final firstChoice = _openaiFirstChoice(lastObj);
      if (firstChoice == null) {
        yield* emitDone(
          content: (lastObj['output_text'] ?? '').toString(),
          usage: firstUsage,
          totalTokens: firstUsage?.totalTokens ?? 0,
          finishReason: (lastObj['finish_reason'] ?? '').toString().isEmpty
              ? null
              : lastObj['finish_reason'].toString(),
        );
        return;
      }
      final firstCalls = _openaiCallsFromCompletionMessage(
        (firstChoice['message'] as Map?)?.cast<String, dynamic>(),
      );
      if (firstCalls.isNotEmpty && effectiveOnToolCall != null) {
        yield* _runOpenAIChatCompletionsNonStreamToolFollowUps(
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
          isClaudeUpstream: isClaudeUpstream,
          needsReasoningEcho: needsReasoningEcho,
          extraHeaders: extraHeaders,
          initialUsage: firstUsage,
        );
        return;
      }
      final visible = _openaiVisibleOutputFromMessage(
        (firstChoice['message'] as Map?)?.cast<String, dynamic>(),
      );
      final firstMessage = _openaiFirstChoiceMessage(lastObj);
      yield* emitImages(visible.images);
      yield* emitDone(
        content: visible.content,
        reasoning: _openaiReasoningText(firstMessage),
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

  await for (final event in parseSseEventStrings(sse)) {
    final data = event.data;
    if (data == '[DONE]') {
      // If model streamed tool_calls but didn't include finish_reason on prior chunks,
      // execute tool flow now and start follow-up request.
      if (effectiveOnToolCall != null && toolAcc.isNotEmpty) {
        yield* _runOpenAIChatCompletionsToolFollowUps(
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
              chatDecoder?.reasoningDetails ??
              reasoningDetailsBuffer.detailsOrNull,
          onToolCall: effectiveOnToolCall,
          userImagePaths: userImagePaths,
          canImageInput: canImageInput,
          allowRemoteImages: allowRemoteImages,
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
        reasoningDetails:
            chatDecoder?.reasoningDetails ??
            reasoningDetailsBuffer.detailsOrNull,
        usage: usage,
        totalTokens: usage?.totalTokens ?? approxTotal,
      );
      return;
    }

    _throwIfInBandStreamError(data);
    try {
      if (config.useResponseApi == true) {
        final decoder = responsesDecoder!;
        final decoded = decoder.accept(event);
        for (final chunk in decoded.chunks) {
          yield chunk;
        }
        if (!decoded.completed) continue;

        usage = decoder.usage ?? usage;
        totalTokens = usage?.totalTokens ?? totalTokens;
        approxCompletionChars = decoder.approxCompletionChars;
        lastResponseOutputItems = decoder.outputItems;
        respToolCallsByIndex
          ..clear()
          ..addAll({
            for (final call in decoder.takeFunctionCalls())
              call.index: <String, String>{
                'call_id': call.callId,
                'name': call.name,
                'args': call.args,
              },
          });
        if (!decoder.emittedImageEvents) {
          var fallbackCount = 0;
          for (final image in decoder.takeImages()) {
            if (image.base64.isEmpty) continue;
            final mdImg = await _saveResponsesImageGenerationMarkdown(
              image.base64,
              outputFormat: image.outputFormat,
            );
            if (mdImg.isEmpty) continue;
            fallbackCount++;
            yield* emitDelta(
              content: mdImg,
              usage: usage,
              totalTokens: totalTokens,
            );
          }
          if (fallbackCount > 0) {
            _logImageFallback(
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
              ? _responsesCallsFromIndexMap(respToolCallsByIndex)
              : [
                  for (final entry
                      in toolAccResp.entries.toList().asMap().entries)
                    emitToolCall(
                      id: _effectiveToolCallId(
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
          yield* _runOpenAIResponsesToolFollowUps(
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
        yield* _runOpenAIChatCompletionsToolFollowUps(
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
          yield* _runOpenAIChatCompletionsToolFollowUps(
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
      // streams call _throwIfInBandStreamError in here) and failed follow-up
      // requests must surface as stream errors; swallowing them would let
      // the no-[DONE] fallback below persist truncated output as a normal
      // completion.
      rethrow;
    } catch (e) {
      // Skip malformed JSON
    }
  }

  // Fallback: provider closed SSE without sending [DONE]
  final approxTotal =
      usage?.totalTokens ??
      (approxPromptTokens + approxTokensFromChars(approxCompletionChars));
  yield* emitDone(
    reasoningDetails:
        chatDecoder?.reasoningDetails ?? reasoningDetailsBuffer.detailsOrNull,
    usage: usage,
    totalTokens: approxTotal,
  );
}
