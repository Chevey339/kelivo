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

/// Reasoning and sampling shaping; callers merge the custom body afterwards.
void applyOpenAIResolvedRequest(
  Map<String, dynamic> body, {
  required ModelSpec spec,
  required ReasoningRequest reasoning,
  required ReasoningTransport transport,
}) {
  applyReasoning(body, spec, reasoning, transport: transport);
  applySamplingPolicy(
    body,
    spec,
    resolveReasoning(spec, reasoning),
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

void applyOpenRouterClaudePromptCaching(
  Map<String, dynamic> body, {
  required ProviderConfig config,
  required ModelSpec spec,
}) {
  if (config.claudePromptCachingEnabled != true ||
      !BuiltInToolsHelper.isOpenRouterProvider(config) ||
      !spec.promptCacheControl) {
    return;
  }
  body['cache_control'] = ProviderConfig.claudePromptCacheControl(
    config.claudePromptCachingTtl,
  );
}

TokenUsage? openaiUsageFromObj(Map<String, dynamic> obj) {
  try {
    final u = obj['usage'];
    if (u is! Map) return null;
    final usage = tokenUsageFromOpenAICompatible(u);
    return usage.hasReportedTokens ? usage.asSnapshot() : null;
  } catch (_) {
    return null;
  }
}

int? _readOpenAIUsageInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

TokenUsage tokenUsageFromOpenAICompatible(Map rawUsage) {
  final inputDetails =
      rawUsage['prompt_tokens_details'] ?? rawUsage['input_tokens_details'];
  final outputDetails =
      rawUsage['completion_tokens_details'] ??
      rawUsage['output_tokens_details'];
  final prompt = _readOpenAIUsageInt(
    rawUsage['prompt_tokens'] ?? rawUsage['input_tokens'],
  );
  final completion = _readOpenAIUsageInt(
    rawUsage['completion_tokens'] ?? rawUsage['output_tokens'],
  );
  return TokenUsage(
    promptTokens: prompt,
    completionTokens: completion,
    cachedTokens: inputDetails is Map
        ? _readOpenAIUsageInt(inputDetails['cached_tokens'])
        : null,
    reasoningTokens: outputDetails is Map
        ? _readOpenAIUsageInt(outputDetails['reasoning_tokens'])
        : null,
    totalTokens: _readOpenAIUsageInt(rawUsage['total_tokens']),
  );
}

TokenUsage? mergeOpenAICompatibleUsage(TokenUsage? current, dynamic rawUsage) {
  if (rawUsage is! Map) return current;
  final update = tokenUsageFromOpenAICompatible(rawUsage);
  return update.hasReportedTokens
      ? (current ?? const TokenUsage()).merge(update)
      : current;
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
