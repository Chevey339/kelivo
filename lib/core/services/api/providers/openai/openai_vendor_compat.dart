import 'dart:async';
import 'dart:io';

import '../../../../models/token_usage.dart';
import '../../../../models/provider_oauth.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../utils/openai_model_compat.dart';
import '../../../../utils/kimi_model_compat.dart';
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

  if (config.oauthProvider == OAuthProvider.chatgpt) {
    if (isReasoning && isOff(thinkingBudget)) {
      body['reasoning'] = {'effort': 'none'};
    }
    return;
  }

  final poolsideInfo = OpenAIProviderInfo(
    host: Uri.tryParse(config.baseUrl)?.host.toLowerCase() ?? '',
    providerId: config.id.toLowerCase(),
    upstreamModelId: upstreamModelId,
  );
  if (poolsideInfo.usesPoolsideThinking && !poolsideInfo.isOpenRouter) {
    applyPoolsideThinkingKnob(
      body,
      isReasoning: isReasoning,
      thinkingBudget: thinkingBudget,
    );
    return;
  }

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
  if (isDashScopeThinkingOnlyModel(upstreamModelId)) {
    body.remove('enable_thinking');
    return;
  }
  body['enable_thinking'] = forceThinkingForQwen3Max || !isOff(thinkingBudget);
}

bool isDashScopeThinkingOnlyModel(String modelId) {
  final lower = modelId.trim().toLowerCase();
  if (lower.contains('qwen3.7-max-preview') ||
      lower.contains('qwen3.7-max-2026-05-17')) {
    return true;
  }
  if (RegExp(r'(^|[/_:@])qwq(?:$|[-.])').hasMatch(lower)) return true;
  if (RegExp(r'(^|[/_:@])deepseek-r1(?:$|[-.])').hasMatch(lower)) {
    return true;
  }
  if (lower.contains('kimi-k2.7-code') || lower.contains('kimi-k2-thinking')) {
    return true;
  }
  if (RegExp(r'(^|[/_:@])minimax-m2\.(?:1|5)(?:$|[-.])').hasMatch(lower)) {
    return true;
  }
  return lower.contains('-thinking');
}

bool _isKimiHybridThinkingModel(String upstreamModelId) {
  final lower = upstreamModelId.toLowerCase();
  return lower.contains('kimi-k2.5') || lower.contains('kimi-k2.6');
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
  required OpenAIProviderInfo info,
  int? thinkingBudget,
}) {
  if (info.isKimiCodingModel || info.isKimiCodeThinkingModel) {
    if (upstreamModelId.trim().toLowerCase() == 'k3-256k') {
      final messages = body['messages'];
      if (messages is List &&
          messages.whereType<Map>().any((message) {
            final content = message['content'];
            return content is List &&
                content.whereType<Map>().any(
                  (part) => part['type'] == 'video_url',
                );
          })) {
        throw UnsupportedError(
          'Kimi Code k3-256k does not support video input.',
        );
      }
    }
    _removeMoonshotKimiUnsupportedSamplingParams(body);
    // OAuth uses catalog-driven thinking.type/effort below. Keep its native
    // overrides intact instead of applying the API-key reasoning_effort rules.
    if (info.isKimiCodeThinkingModel) return;
    if (isKimiCodeHighSpeedModel(upstreamModelId)) {
      body.remove('reasoning_effort');
      body.remove('thinking');
      return;
    }
    if (!isReasoning) {
      body.remove('thinking');
      body.remove('reasoning_effort');
      return;
    }
    final rawEffort = body['reasoning_effort'];
    final effort = rawEffort is String && rawEffort.trim().isNotEmpty
        ? openAINormalizeReasoningEffort(rawEffort, upstreamModelId)
        : 'auto';
    final thinking = body['thinking'];
    final thinkingType = thinking is Map ? thinking['type'] : null;
    if (thinkingType == 'disabled' ||
        (effort == 'none' && thinkingType != 'enabled')) {
      body['thinking'] = {'type': 'disabled'};
      body.remove('reasoning_effort');
    } else {
      body.remove('thinking');
      if (effort == 'auto' || effort == 'none') {
        body.remove('reasoning_effort');
      } else {
        body['reasoning_effort'] = effort;
      }
    }
    return;
  }
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

  if (_isKimiHybridThinkingModel(upstreamModelId)) {
    body['thinking'] = {'type': isOff(thinkingBudget) ? 'disabled' : 'enabled'};
    if (upstreamModelId.toLowerCase().contains('kimi-k2.5')) {
      _removeMoonshotKimiUnsupportedSamplingParams(body);
    }
    return;
  }

  body.remove('thinking');
  if (_isKimiOmitsSamplingParamsModel(upstreamModelId)) {
    _removeMoonshotKimiUnsupportedSamplingParams(body);
  }
}

/// Kimi Code's OpenAI endpoint uses thinking.type/effort, not OpenAI's
/// reasoning_effort or Anthropic's budget_tokens. Use the discovered ladder,
/// including its lowest legal effort when thinking is mandatory (OMP policy).
void applyKimiCodeChatThinking(
  Map<String, dynamic> body, {
  required ProviderConfig config,
  required String modelId,
  required bool isReasoning,
  int? thinkingBudget,
}) {
  if (config.oauthProvider != OAuthProvider.kimi ||
      config.useResponseApi == true) {
    return;
  }
  final raw = config.modelOverrides[modelId];
  final metadata = raw is Map ? raw : const {};
  if (metadata['oauthProtocol'] != 'openai') return;
  final required = metadata['oauthThinkingRequired'] == true;
  final existing = body['thinking'];
  final thinking = existing is Map ? existing : const {};
  final requestedEffort = thinking['effort'];
  final off =
      thinking['type'] == 'disabled' ||
      (thinking['type'] != 'enabled' && isOff(thinkingBudget));
  body.remove('reasoning_effort');
  body.remove('reasoning');
  body.remove('output_config');
  if (!isReasoning && !required) {
    body.remove('thinking');
    return;
  }
  if (off && !required) {
    body['thinking'] = {'type': 'disabled'};
    return;
  }
  const order = ['minimal', 'low', 'medium', 'high', 'xhigh', 'max'];
  final advertised = metadata['oauthThinkingEfforts'];
  final levels = [
    for (final level in order)
      if (advertised is List && advertised.contains(level)) level,
  ];
  String? effort;
  if (levels.isNotEmpty) {
    if (off) {
      effort = levels.first;
    } else {
      final requested = requestedEffort is String
          ? requestedEffort
          : thinkingBudget != null && thinkingBudget >= 128000
          ? 'max'
          : thinkingBudget != null && thinkingBudget >= 64000
          ? 'xhigh'
          : effortForBudget(thinkingBudget);
      if (requested == 'auto') {
        final defaultEffort = metadata['oauthThinkingDefaultEffort'];
        if (defaultEffort is String && levels.contains(defaultEffort)) {
          effort = defaultEffort;
        }
      } else {
        final index = order.indexOf(requested);
        effort = levels.first;
        for (final level in levels) {
          if (order.indexOf(level) > index) break;
          effort = level;
        }
      }
    }
  }
  body['thinking'] = {
    'type': 'enabled',
    if (effort != null) 'effort': effort,
    if (thinking['keep'] == 'all') 'keep': 'all',
  };
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
  final bool isKimiCodeThinkingModel;

  const OpenAIProviderInfo({
    required this.host,
    required this.providerId,
    required this.upstreamModelId,
    this.isKimiCodeThinkingModel = false,
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

  bool get isPoolsideHost =>
      host == 'poolside.ai' ||
      host == 'inference.poolside.ai' ||
      host.endsWith('.poolside.ai');

  bool get usesPoolsideThinking => isLaguna || isPoolsideHost;

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
  bool get isKimiCodeK3Model =>
      isKimiCodingModel && isKimiCodeK3Alias(upstreamModelId);
  bool get isKimiCodingModel {
    if (isKimiForCodingModel(upstreamModelId) ||
        isKimiK28Model(upstreamModelId)) {
      return true;
    }
    // Coding uses short K3 aliases. Require provider identity so unrelated
    // models named k3 do not inherit Kimi's preserved-thinking contract.
    final isKimiProvider =
        host == 'api.kimi.com' ||
        host == 'api.moonshot.ai' ||
        host == 'api.moonshot.cn' ||
        providerId.contains('kimi') ||
        providerId.contains('moonshot');
    return isKimiProvider && isKimiCodeK3Alias(upstreamModelId);
  }

  bool get supportsGoogleOpenAIThoughtSignatures {
    final normalizedModelId = upstreamModelId.toLowerCase();
    final isGoogleApiHost =
        host == 'generativelanguage.googleapis.com' ||
        host.endsWith('aiplatform.googleapis.com');
    return isGoogleApiHost && normalizedModelId.contains('gemini');
  }

  bool get needsReasoningEcho =>
      usesPoolsideThinking ||
      isDeepSeek ||
      isMimo ||
      isZhipu ||
      isKimiCodingModel ||
      isKimiCodeThinkingModel ||
      isKimiThinkingModel;
  ReasoningContentReplayPolicy get reasoningContentReplayPolicy {
    if (usesPoolsideThinking ||
        isKimiCodingModel ||
        isKimiCodeThinkingModel ||
        _isKimiPreservedThinkingModel(upstreamModelId)) {
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

void applyPoolsideThinkingKnob(
  Map<String, dynamic> body, {
  required bool isReasoning,
  int? thinkingBudget,
}) {
  final enable = isReasoning && !isOff(thinkingBudget);
  final existing = body['chat_template_kwargs'];
  final kwargs = <String, dynamic>{
    if (existing is Map)
      ...existing.map((key, value) => MapEntry(key.toString(), value)),
  };
  kwargs.putIfAbsent('enable_thinking', () => enable);
  body['chat_template_kwargs'] = kwargs;
  body.remove('reasoning_effort');
  body.remove('reasoning');
}

void applyPoolsideThinkingIfNeeded(
  Map<String, dynamic> body, {
  required OpenAIProviderInfo info,
  required bool isReasoning,
  int? thinkingBudget,
}) {
  if (!info.usesPoolsideThinking || info.isOpenRouter) return;
  applyPoolsideThinkingKnob(
    body,
    isReasoning: isReasoning,
    thinkingBudget: thinkingBudget,
  );
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
  } else if (info.usesPoolsideThinking) {
    applyPoolsideThinkingKnob(
      body,
      isReasoning: isReasoning,
      thinkingBudget: thinkingBudget,
    );
  } else if (info.isDashScope) {
    if (isReasoning) {
      if (isDashScopeThinkingOnlyModel(info.upstreamModelId)) {
        body.remove('enable_thinking');
      } else {
        body['enable_thinking'] = !off;
      }
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
    if (isGlm53FamilyModel(info.upstreamModelId)) {
      // GLM-5.3 / 5.3-Flash always think. disabled returns 400; off maps to low.
      body['thinking'] = const <String, dynamic>{'type': 'enabled'};
      if (isReasoning) {
        final effort = openAIEffortForBudget(
          thinkingBudget,
          info.upstreamModelId,
        );
        if (effort == 'auto') {
          body.remove('reasoning_effort');
        } else {
          body['reasoning_effort'] = effort;
        }
      } else {
        body.remove('reasoning_effort');
      }
    } else if (isGlm52FamilyModel(info.upstreamModelId)) {
      if (isReasoning) {
        body['thinking'] = {'type': off ? 'disabled' : 'enabled'};
        if (off) {
          body.remove('reasoning_effort');
        } else {
          final effort = openAIEffortForBudget(
            thinkingBudget,
            info.upstreamModelId,
          );
          if (effort == 'auto') {
            body.remove('reasoning_effort');
          } else {
            body['reasoning_effort'] = effort;
          }
        }
      } else {
        body.remove('thinking');
        body.remove('reasoning_effort');
      }
    } else if (isReasoning) {
      body['thinking'] = {'type': off ? 'disabled' : 'enabled'};
      body.remove('reasoning_effort');
    } else {
      body.remove('thinking');
      body.remove('reasoning_effort');
    }
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
