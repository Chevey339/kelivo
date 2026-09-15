import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/model_spec/vendor_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderConfig _cfg({
  String id = 'Test',
  String name = 'Test',
  String baseUrl = 'https://api.openai.com/v1',
  ProviderKind? kind,
  bool? useResponseApi,
  OAuthProvider? oauth,
}) {
  return ProviderConfig(
    id: id,
    enabled: true,
    name: name,
    apiKey: '',
    baseUrl: baseUrl,
    providerType: kind,
    useResponseApi: useResponseApi,
    oauthProvider: oauth,
  );
}

void main() {
  group('VendorDefaults.forProvider', () {
    test('OpenAI protocol defaults', () {
      final openai = VendorDefaults.forProvider(_cfg());
      expect(openai.dialect, isNull);
      expect(openai.protocolDefault, ReasoningDialect.openaiReasoningEffort);
      expect(openai.maxTokensKey, 'max_tokens');
      expect(openai.sendStreamOptions, isTrue);

      final responses = VendorDefaults.forProvider(_cfg(useResponseApi: true));
      expect(
        responses.protocolDefault,
        ReasoningDialect.openaiResponsesReasoning,
      );

      final chatgpt = VendorDefaults.forProvider(
        _cfg(oauth: OAuthProvider.chatgpt),
      );
      expect(chatgpt.dialect, ReasoningDialect.openaiResponsesReasoning);
      expect(
        chatgpt.protocolDefault,
        ReasoningDialect.openaiResponsesReasoning,
      );
    });

    test('Claude and Google protocol defaults', () {
      final claude = VendorDefaults.forProvider(
        _cfg(
          id: 'Claude',
          kind: ProviderKind.claude,
          baseUrl: 'https://api.anthropic.com/v1',
        ),
      );
      expect(claude.protocolDefault, ReasoningDialect.anthropicBudget);
      expect(claude.dialect, isNull);

      final google = VendorDefaults.forProvider(
        _cfg(
          id: 'Gemini',
          kind: ProviderKind.google,
          baseUrl: 'https://generativelanguage.googleapis.com',
        ),
      );
      expect(google.protocolDefault, ReasoningDialect.geminiThinkingBudget);
    });

    test('host dialects', () {
      expect(
        VendorDefaults.forProvider(
          _cfg(id: 'OpenRouter', baseUrl: 'https://openrouter.ai/api/v1'),
        ).dialect,
        ReasoningDialect.openrouterReasoning,
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(
            id: 'DashScope',
            baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
          ),
        ).dialect,
        ReasoningDialect.qwenEnableThinking,
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(id: 'SiliconFlow', baseUrl: 'https://api.siliconflow.cn/v1'),
        ).dialect,
        ReasoningDialect.siliconflowEnableThinking,
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(id: 'Zhipu', baseUrl: 'https://open.bigmodel.cn/api/paas/v4'),
        ).dialect,
        ReasoningDialect.thinkingType,
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(id: 'ZAI', baseUrl: 'https://api.z.ai/api/paas/v4'),
        ).dialect,
        ReasoningDialect.thinkingType,
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(id: 'Volc', baseUrl: 'https://ark.cn-beijing.volces.com/api/v3'),
        ).dialect,
        ReasoningDialect.thinkingType,
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(id: 'DeepSeek', baseUrl: 'https://api.deepseek.com/v1'),
        ).dialect,
        ReasoningDialect.thinkingType,
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(id: 'Intern', baseUrl: 'https://chat.intern-ai.org.cn/v1'),
        ).dialect,
        ReasoningDialect.internThinkingMode,
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(id: 'Poolside', baseUrl: 'https://inference.poolside.ai/v1'),
        ).dialect,
        ReasoningDialect.chatTemplateKwargs,
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(id: 'MiMo', baseUrl: 'https://api.xiaomimimo.com/v1'),
        ).dialect,
        ReasoningDialect.thinkingType,
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(id: 'Moonshot', baseUrl: 'https://api.moonshot.cn/v1'),
        ).dialect,
        ReasoningDialect.kimiThinking,
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(id: 'Kimi', baseUrl: 'https://api.kimi.com/coding/v1'),
        ).dialect,
        ReasoningDialect.kimiThinking,
      );
    });

    test('Claude kind ignores OpenRouter host dialect', () {
      final defaults = VendorDefaults.forProvider(
        _cfg(
          id: 'OpenRouterAnthropic',
          kind: ProviderKind.claude,
          baseUrl: 'https://openrouter.ai/api/v1',
        ),
      );
      expect(defaults.dialect, isNull);
      expect(defaults.protocolDefault, ReasoningDialect.anthropicBudget);
    });

    test('Kimi Anthropic protocol uses a budget ladder', () {
      final byHost = VendorDefaults.forProvider(
        _cfg(
          id: 'Kimi',
          kind: ProviderKind.claude,
          baseUrl: 'https://api.kimi.com/coding/v1',
        ),
      );
      expect(byHost.dialect, ReasoningDialect.anthropicBudget);
      expect(byHost.levels, const [
        ReasoningLevel.low,
        ReasoningLevel.medium,
        ReasoningLevel.high,
      ]);
      expect(byHost.canDisable, isTrue);

      final byOauth = VendorDefaults.forProvider(
        _cfg(
          id: 'KimiOAuth',
          kind: ProviderKind.claude,
          baseUrl: 'https://example.com/v1',
          oauth: OAuthProvider.kimi,
        ),
      );
      expect(byOauth.dialect, ReasoningDialect.anthropicBudget);
      expect(byOauth.canDisable, isTrue);
    });

    test('DeepSeek Claude-compatible host overrides the ladder', () {
      final defaults = VendorDefaults.forProvider(
        _cfg(
          id: 'DeepSeek',
          name: 'DeepSeek',
          kind: ProviderKind.claude,
          baseUrl: 'https://api.deepseek.com/anthropic',
        ),
      );
      expect(defaults.dialect, ReasoningDialect.anthropicEffort);
      expect(defaults.levels, const [
        ReasoningLevel.low,
        ReasoningLevel.high,
        ReasoningLevel.max,
      ]);
      expect(defaults.canDisable, isFalse);
      expect(defaults.protocolDefault, ReasoningDialect.anthropicBudget);
      expect(defaults.replay, ReasoningReplayPolicy.toolTurns);
    });

    test('max tokens key and stream options', () {
      expect(
        VendorDefaults.forProvider(
          _cfg(baseUrl: 'https://my-resource.openai.azure.com/openai'),
        ).maxTokensKey,
        'max_completion_tokens',
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(id: 'MiMo', baseUrl: 'https://api.xiaomimimo.com/v1'),
        ).maxTokensKey,
        'max_completion_tokens',
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(baseUrl: 'https://api.longcat.chat/openai'),
        ).sendStreamOptions,
        isFalse,
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(baseUrl: 'https://api.mistral.ai/v1'),
        ).sendStreamOptions,
        isFalse,
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(id: 'OpenRouter', baseUrl: 'https://openrouter.ai/api/v1'),
        ).sendStreamOptions,
        isFalse,
      );
    });

    test('host-level replay', () {
      expect(
        VendorDefaults.forProvider(
          _cfg(baseUrl: 'https://inference.poolside.ai/v1'),
        ).replay,
        ReasoningReplayPolicy.all,
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(id: 'DeepSeek', baseUrl: 'https://api.deepseek.com/v1'),
        ).replay,
        ReasoningReplayPolicy.toolTurns,
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(id: 'Zhipu', baseUrl: 'https://open.bigmodel.cn/api/paas/v4'),
        ).replay,
        ReasoningReplayPolicy.toolTurns,
      );
      expect(
        VendorDefaults.forProvider(
          _cfg(id: 'MiMo', baseUrl: 'https://api.xiaomimimo.com/v1'),
        ).replay,
        ReasoningReplayPolicy.toolTurns,
      );
    });
  });
}
