import 'package:flutter/foundation.dart';

import '../../models/model_spec.dart';
import '../../models/provider_oauth.dart';
import '../../providers/settings_provider.dart';

/// Host / kind / oauth-derived defaults. Model-id defaults live in
/// [ModelDefaultsGuesser].
@immutable
class VendorDefaults {
  final ReasoningDialect? dialect;
  final List<ReasoningLevel>? levels;
  final bool? canDisable;
  final ReasoningDialect protocolDefault;
  final String maxTokensKey;
  final bool sendStreamOptions;
  final ReasoningReplayPolicy? replay;
  final ReasoningReplayField? replayField;

  const VendorDefaults({
    this.dialect,
    this.levels,
    this.canDisable,
    required this.protocolDefault,
    this.maxTokensKey = 'max_tokens',
    this.sendStreamOptions = true,
    this.replay,
    this.replayField,
  });

  static VendorDefaults forProvider(ProviderConfig cfg) {
    final host = _hostOf(cfg);
    final providerId = cfg.id.toLowerCase();
    final kind = ProviderConfig.classify(
      cfg.id,
      explicitType: cfg.providerType,
    );
    final protocolDefault = _protocolDefault(kind, cfg);
    final sendStreamOptions = _shouldSendStreamOptions(host, cfg.baseUrl);

    ReasoningDialect? dialect;
    List<ReasoningLevel>? levels;
    bool? canDisable;
    ReasoningReplayPolicy? replay;
    ReasoningReplayField? replayField;
    var maxTokensKey = 'max_tokens';

    final isAzure = host.contains('openai.azure.com');
    final isMimoHost = host.contains('xiaomimimo');
    if (isAzure || isMimoHost) {
      maxTokensKey = 'max_completion_tokens';
    }

    if (kind == ProviderKind.claude && ProviderConfig.isDeepSeekConfig(cfg)) {
      return VendorDefaults(
        dialect: ReasoningDialect.anthropicEffort,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.high,
          ReasoningLevel.max,
        ],
        canDisable: false,
        protocolDefault: protocolDefault,
        maxTokensKey: maxTokensKey,
        sendStreamOptions: sendStreamOptions,
        replay: ReasoningReplayPolicy.toolTurns,
        replayField: ReasoningReplayField.reasoningContent,
      );
    }

    if (kind == ProviderKind.claude && _isKimiAnthropicProvider(cfg, host)) {
      return VendorDefaults(
        dialect: ReasoningDialect.anthropicBudget,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
        ],
        canDisable: true,
        protocolDefault: protocolDefault,
        maxTokensKey: maxTokensKey,
        sendStreamOptions: sendStreamOptions,
      );
    }

    // Anthropic Messages: model dialect comes from the guesser/catalog.
    // Host names like "OpenRouter" must not force Chat Completions dialects.
    if (kind == ProviderKind.claude) {
      return VendorDefaults(
        protocolDefault: protocolDefault,
        maxTokensKey: maxTokensKey,
        sendStreamOptions: sendStreamOptions,
      );
    }

    if (cfg.oauthProvider == OAuthProvider.chatgpt) {
      dialect = ReasoningDialect.openaiResponsesReasoning;
    } else if (providerId.contains('openrouter') ||
        host.contains('openrouter.ai')) {
      dialect = ReasoningDialect.openrouterReasoning;
    } else if (host.contains('dashscope') || host.contains('aliyun')) {
      dialect = ReasoningDialect.qwenEnableThinking;
    } else if (providerId.contains('siliconflow') ||
        host.contains('siliconflow')) {
      dialect = ReasoningDialect.siliconflowEnableThinking;
    } else if (host.contains('open.bigmodel.cn') ||
        host.contains('bigmodel') ||
        host == 'api.z.ai') {
      dialect = ReasoningDialect.thinkingType;
      replay = ReasoningReplayPolicy.toolTurns;
      replayField = ReasoningReplayField.reasoningContent;
    } else if (host.contains('ark.cn-beijing.volces.com') ||
        host.contains('volc') ||
        host.contains('ark')) {
      dialect = ReasoningDialect.thinkingType;
    } else if (host.contains('deepseek')) {
      dialect = ReasoningDialect.thinkingType;
      replay = ReasoningReplayPolicy.toolTurns;
      replayField = ReasoningReplayField.reasoningContent;
    } else if (host.contains('intern-ai') ||
        host.contains('intern') ||
        host.contains('chat.intern-ai.org.cn')) {
      dialect = ReasoningDialect.internThinkingMode;
    } else if (_isPoolsideHost(host)) {
      dialect = ReasoningDialect.chatTemplateKwargs;
      replay = ReasoningReplayPolicy.all;
      replayField = ReasoningReplayField.reasoningContent;
    } else if (isMimoHost) {
      dialect = ReasoningDialect.thinkingType;
      replay = ReasoningReplayPolicy.toolTurns;
      replayField = ReasoningReplayField.reasoningContent;
    } else if (host == 'api.kimi.com' ||
        host == 'api.moonshot.ai' ||
        host == 'api.moonshot.cn') {
      dialect = ReasoningDialect.kimiThinking;
    }

    return VendorDefaults(
      dialect: dialect,
      levels: levels,
      canDisable: canDisable,
      protocolDefault: protocolDefault,
      maxTokensKey: maxTokensKey,
      sendStreamOptions: sendStreamOptions,
      replay: replay,
      replayField: replayField,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is VendorDefaults &&
            runtimeType == other.runtimeType &&
            dialect == other.dialect &&
            listEquals(levels, other.levels) &&
            canDisable == other.canDisable &&
            protocolDefault == other.protocolDefault &&
            maxTokensKey == other.maxTokensKey &&
            sendStreamOptions == other.sendStreamOptions &&
            replay == other.replay &&
            replayField == other.replayField);
  }

  @override
  int get hashCode => Object.hash(
    dialect,
    levels == null ? null : Object.hashAll(levels!),
    canDisable,
    protocolDefault,
    maxTokensKey,
    sendStreamOptions,
    replay,
    replayField,
  );
}

String _hostOf(ProviderConfig cfg) {
  return Uri.tryParse(cfg.baseUrl.trim())?.host.toLowerCase() ?? '';
}

ReasoningDialect _protocolDefault(ProviderKind kind, ProviderConfig cfg) {
  switch (kind) {
    case ProviderKind.claude:
      return ReasoningDialect.anthropicBudget;
    case ProviderKind.google:
      return ReasoningDialect.geminiThinkingBudget;
    case ProviderKind.openai:
      if (cfg.useResponseApi == true ||
          cfg.oauthProvider == OAuthProvider.chatgpt) {
        return ReasoningDialect.openaiResponsesReasoning;
      }
      return ReasoningDialect.openaiReasoningEffort;
  }
}

bool _isKimiAnthropicProvider(ProviderConfig cfg, String host) {
  if (cfg.oauthProvider == OAuthProvider.kimi) return true;
  if (host == 'api.kimi.com') return true;
  final id = cfg.id.trim().toLowerCase();
  final name = cfg.name.trim().toLowerCase();
  return id.contains('kimi') || name.contains('kimi');
}

bool _isPoolsideHost(String host) {
  return host == 'poolside.ai' ||
      host == 'inference.poolside.ai' ||
      host.endsWith('.poolside.ai');
}

bool _isLongCatHost(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  final parsed = Uri.tryParse(
    normalized.contains('://') ? normalized : 'https://$normalized',
  );
  final host = (parsed?.host ?? '').toLowerCase();
  if (host.isNotEmpty) return host.contains('longcat');
  return normalized.contains('longcat');
}

bool _shouldSendStreamOptions(String host, String baseUrl) {
  if (_isLongCatHost(host) || _isLongCatHost(baseUrl)) return false;
  return !host.contains('mistral.ai') && !host.contains('openrouter');
}
