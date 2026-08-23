import 'dart:async';
import 'dart:io';

import '../../../../models/token_usage.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../utils/openai_model_compat.dart';
import '../../builtin_tools.dart';
import '../../chat_api_helpers.dart';

void applyChatCompletionsBuiltInTools(
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
  // OpenRouter server-side web search replaces the legacy `web` plugin;
  // keeping both would double-charge for grounding.
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

void applyCompatibleResponsesReasoning(
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

    final effort = isOff(thinkingBudget)
        ? 'none'
        : openAIEffortForBudget(thinkingBudget, upstreamModelId);
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
    } else if (isOff(thinkingBudget)) {
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

  final builtInSearchEnabled = builtInTools(
    config,
    modelId,
  ).contains(BuiltInToolNames.search);
  final forceThinkingForQwen3Max =
      builtInSearchEnabled &&
      upstreamModelId.toLowerCase().startsWith('qwen3-max');
  body['enable_thinking'] = forceThinkingForQwen3Max || !isOff(thinkingBudget);
}

bool _isKimiK25Model(String upstreamModelId) {
  return upstreamModelId.toLowerCase().contains('kimi-k2.5');
}

bool isKimiK3Model(String upstreamModelId) {
  return RegExp(
    r'(^|[/_:@])kimi-k3(?:$|[-.:])',
    caseSensitive: false,
  ).hasMatch(upstreamModelId.trim());
}

bool _isKimiPreservedThinkingModel(String upstreamModelId) {
  final normalized = upstreamModelId.trim().toLowerCase();
  return isKimiK3Model(normalized) ||
      RegExp(r'(^|[/_:@])kimi-k2\.7-code(?:$|[-.:])').hasMatch(normalized);
}

enum ReasoningContentReplayPolicy { none, toolTurns, all }

bool isRemoteHttpUrl(String source) {
  final normalized = source.trim().toLowerCase();
  return normalized.startsWith('http://') || normalized.startsWith('https://');
}

bool _isKimiOmitsSamplingParamsModel(String upstreamModelId) {
  final lower = upstreamModelId.toLowerCase();
  return lower.contains('kimi-k2.5') ||
      lower.contains('kimi-k2.7') ||
      isKimiK3Model(lower);
}

bool _isKimiThinkingModel(String upstreamModelId) {
  final lower = upstreamModelId.toLowerCase();
  return lower.contains('kimi-k2-thinking') ||
      lower.contains('kimi-k2.5') ||
      lower.contains('kimi-k2.6') ||
      lower.contains('kimi-k2.7') ||
      isKimiK3Model(lower);
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

void normalizeMoonshotKimiChatBody(
  Map<String, dynamic> body, {
  required String upstreamModelId,
  required bool isReasoning,
  int? thinkingBudget,
}) {
  if (!_isKimiThinkingModel(upstreamModelId)) return;

  if (isKimiK3Model(upstreamModelId)) {
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
    body['thinking'] = {'type': isOff(thinkingBudget) ? 'disabled' : 'enabled'};
    _removeMoonshotKimiUnsupportedSamplingParams(body);
    return;
  }

  body.remove('thinking');
  if (_isKimiOmitsSamplingParamsModel(upstreamModelId)) {
    _removeMoonshotKimiUnsupportedSamplingParams(body);
  }
}

TokenUsage? openaiUsageFromObj(Map<String, dynamic> obj) {
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

String openAIEffortForBudget(int? budget, String upstreamModelId) {
  final baseEffort = effortForBudget(budget);
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

void sanitizeOpenAIGpt5SamplingParams(
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

bool isLongCatHost(String baseUrl) {
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

bool shouldIncludeStreamingUsageOptions(String host) {
  if (isLongCatHost(host)) {
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

void applyOpenRouterClaudePromptCaching(
  Map<String, dynamic> body, {
  required ProviderConfig config,
  required String upstreamModelId,
}) {
  if (!_shouldCacheClaudeSystemPrompt(config, upstreamModelId)) return;
  body['cache_control'] = ProviderConfig.claudePromptCacheControl(
    config.claudePromptCachingTtl,
  );
}

void maybeAddStreamingUsageOptions(
  Map<String, dynamic> body, {
  required bool stream,
  required ProviderConfig config,
  required String host,
}) {
  if (!stream || config.useResponseApi == true) return;
  if (shouldIncludeStreamingUsageOptions(host)) {
    body['stream_options'] = {'include_usage': true};
  }
}

int _readOpenAIUsageInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

TokenUsage? mergeOpenAICompatibleUsage(TokenUsage? current, dynamic rawUsage) {
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

Stream<String> rethrowFollowUpStreamErrors(Stream<String> source) {
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
class OpenAIProviderInfo {
  final String host;
  final String providerId;
  final String upstreamModelId;

  const OpenAIProviderInfo({
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
  bool get isLaguna {
    final id = upstreamModelId.toLowerCase();
    return id.startsWith('laguna-') || id.contains('/laguna-');
  }
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
  bool get supportsGoogleOpenAIThoughtSignatures {
    final normalizedModelId = upstreamModelId.toLowerCase();
    final isGoogleApiHost =
        host == 'generativelanguage.googleapis.com' ||
        host.endsWith('aiplatform.googleapis.com');
    return isGoogleApiHost && normalizedModelId.contains('gemini');
  }

  bool get needsReasoningEcho =>
      isLaguna || isDeepSeek || isMimo || isZhipu || isKimiThinkingModel;
  ReasoningContentReplayPolicy get reasoningContentReplayPolicy {
    if (isLaguna || _isKimiPreservedThinkingModel(upstreamModelId)) {
      return ReasoningContentReplayPolicy.all;
    }
    if (needsReasoningEcho) {
      return ReasoningContentReplayPolicy.toolTurns;
    }
    return ReasoningContentReplayPolicy.none;
  }

  String get completionTokensKey =>
      (isAzureOpenAI || isMimo) ? 'max_completion_tokens' : 'max_tokens';
}

void applyVendorReasoningKnobs(
  Map<String, dynamic> body, {
  required OpenAIProviderInfo info,
  required bool isReasoning,
  int? thinkingBudget,
}) {
  final off = isOff(thinkingBudget);
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
  } else if (info.isLaguna) {
    if (isReasoning) {
      body['chat_template_kwargs'] = {
        'enable_thinking': !off,
      };
    } else {
      body.remove('chat_template_kwargs');
    }
    body.remove('reasoning_effort');
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
