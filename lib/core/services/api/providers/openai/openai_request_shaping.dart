import 'dart:async';
import 'dart:io';

import '../../../../models/model_spec.dart';
import '../../../../models/token_usage.dart';
import '../../../../providers/settings_provider.dart';
import '../../../model_spec/vendor_defaults.dart';
import '../../builtin_tools.dart';
import '../../reasoning/reasoning_dialects.dart';

/// Returns the resolved search query so client-tool rounds can reuse it.
Object? applyChatCompletionsBuiltInTools(
  Map<String, dynamic> body, {
  required ProviderConfig config,
  required String modelId,
  required String upstreamModelId,
  Iterable<String>? configuredTools,
  Object? searchQuery,
}) {
  Object? resolvedSearchQuery;
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
  if (BuiltInToolsHelper.isVercelProvider(config) &&
      payload.tools.any((tool) => tool['type'] == 'vercel:perplexity_search')) {
    // Image-tool results add synthetic user messages to follow-up requests.
    final query = searchQuery ?? _lastUserText(body['messages']);
    final tools = body['tools'] as List;
    for (var index = 0; index < tools.length; index++) {
      final rawTool = tools[index];
      if (rawTool is! Map || rawTool['type'] != 'vercel:perplexity_search') {
        continue;
      }
      final tool = Map<String, dynamic>.from(rawTool);
      final rawConfig = tool['config'];
      final searchConfig = rawConfig is Map
          ? Map<String, dynamic>.from(rawConfig)
          : <String, dynamic>{};
      final configuredQuery = searchConfig['query'];
      if (configuredQuery == null ||
          (configuredQuery is String && configuredQuery.trim().isEmpty)) {
        if (query is String && query.trim().isEmpty) {
          throw UnsupportedError(
            'Vercel Gateway web search requires user text or an explicit config.query.',
          );
        }
        searchConfig['query'] = query;
      }
      resolvedSearchQuery = searchConfig['query'];
      tool['config'] = searchConfig;
      tools[index] = tool;
    }
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
  return resolvedSearchQuery;
}

String _lastUserText(Object? messages) {
  if (messages is! List) return '';
  for (final message in messages.reversed) {
    if (message is! Map || message['role'] != 'user') continue;
    final content = message['content'];
    if (content is String) return content.trim();
    if (content is List) {
      return [
        for (final part in content.whereType<Map>())
          if (part['type'] == 'text' && part['text'] is String)
            part['text'] as String,
      ].join('\n').trim();
    }
    return '';
  }
  return '';
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
