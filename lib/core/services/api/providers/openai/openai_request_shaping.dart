import 'dart:async';
import 'dart:io';

import '../../../../models/model_spec.dart';
import '../../../../models/token_usage.dart';
import '../../../../providers/settings_provider.dart';
import '../../../model_spec/vendor_defaults.dart';
import '../../builtin_tools.dart';
import '../../reasoning/reasoning_dialects.dart';

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

/// Single request-body hook: after extraBody merge, immediately before encode.
void applyOpenAIResolvedRequest(
  Map<String, dynamic> body, {
  required ModelSpec spec,
  required int? thinkingBudget,
  required ReasoningTransport transport,
}) {
  final request = ReasoningRequest(
    levelForLegacyBudget(thinkingBudget),
    budgetTokens: (thinkingBudget ?? 0) > 0 ? thinkingBudget : null,
  );
  applyReasoning(body, spec, request, transport: transport);
  applySamplingPolicy(
    body,
    spec,
    resolveReasoning(spec, request),
    transport: transport,
  );
}

void maybeAddStreamingUsageOptions(
  Map<String, dynamic> body, {
  required bool stream,
  required ProviderConfig config,
}) {
  if (!stream || config.useResponseApi == true) return;
  if (VendorDefaults.forProvider(config).sendStreamOptions) {
    body['stream_options'] = {'include_usage': true};
  }
}

bool isRemoteHttpUrl(String source) {
  final normalized = source.trim().toLowerCase();
  return normalized.startsWith('http://') || normalized.startsWith('https://');
}

/// K3 rejects remote image URLs (local/data still work). This is a K3 wire
/// constraint, not a Moonshot host rule — K2.x on the same host accepts
/// remotes. Guesser has no `allowRemoteImageUrls` field yet.
bool disallowsRemoteImageUrls(String modelId) {
  final id = modelId.trim().toLowerCase();
  if (id == 'k3' || id == 'k3-256k') return true;
  return RegExp(r'(^|[/_:@])kimi-k3(?:$|[-.:])').hasMatch(id);
}

bool _isClaudeModelId(String modelId) {
  final normalized = modelId.trim().toLowerCase();
  return normalized.contains('claude') || normalized.contains('anthropic/');
}

bool _shouldCacheClaudeSystemPrompt(
  ProviderConfig config,
  String upstreamModelId,
) {
  // OpenRouter `cache_control` is accepted only on Claude/Anthropic routes.
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
