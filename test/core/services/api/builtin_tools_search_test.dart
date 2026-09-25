import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/builtin_tools.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderConfig _cfg({
  required String id,
  required String baseUrl,
  required ProviderKind kind,
  bool useResponseApi = false,
  String modelId = 'gpt-4o',
  List<String> builtInTools = const [BuiltInToolNames.search],
  OAuthProvider? oauthProvider,
  String? name,
}) {
  return ProviderConfig(
    id: id,
    enabled: true,
    name: name ?? id,
    apiKey: 'k',
    baseUrl: baseUrl,
    providerType: kind,
    useResponseApi: useResponseApi,
    oauthProvider: oauthProvider,
    modelOverrides: {
      modelId: {'builtInTools': builtInTools},
    },
  );
}

void main() {
  group('supportsBuiltInSearchForModel is provider-level', () {
    const cases =
        <
          ({
            String name,
            String id,
            String baseUrl,
            ProviderKind kind,
            bool useResponseApi,
            String modelId,
            OAuthProvider? oauth,
            String? providerName,
            bool expected,
          })
        >[
          (
            name: 'Google chat',
            id: 'Gemini',
            baseUrl: 'https://generativelanguage.googleapis.com',
            kind: ProviderKind.google,
            useResponseApi: false,
            modelId: 'gemini-3-flash',
            oauth: null,
            providerName: null,
            expected: true,
          ),
          (
            name: 'Google image model',
            id: 'Gemini',
            baseUrl: 'https://generativelanguage.googleapis.com',
            kind: ProviderKind.google,
            useResponseApi: false,
            modelId: 'dall-e-3',
            oauth: null,
            providerName: null,
            expected: false,
          ),
          (
            name: 'Claude official chat',
            id: 'Claude',
            baseUrl: 'https://api.anthropic.com',
            kind: ProviderKind.claude,
            useResponseApi: false,
            modelId: 'claude-sonnet-4-20250514',
            oauth: null,
            providerName: null,
            expected: true,
          ),
          (
            name: 'Claude relay chat',
            id: 'ClaudeRelay',
            baseUrl: 'https://relay.example.com/v1',
            kind: ProviderKind.claude,
            useResponseApi: false,
            modelId: 'claude-3-haiku-20240307',
            oauth: null,
            providerName: null,
            expected: true,
          ),
          (
            name: 'DeepSeek Claude-compatible chat',
            id: 'DeepSeek',
            baseUrl: 'https://api.deepseek.com/anthropic',
            kind: ProviderKind.claude,
            useResponseApi: false,
            modelId: 'deepseek-chat',
            oauth: null,
            providerName: null,
            expected: true,
          ),
          (
            name: 'OpenRouter chat',
            id: 'OpenRouter',
            baseUrl: 'https://openrouter.ai/api/v1',
            kind: ProviderKind.openai,
            useResponseApi: false,
            modelId: 'deepseek/deepseek-chat',
            oauth: null,
            providerName: null,
            expected: true,
          ),
          (
            name: 'Grok host chat',
            id: 'Custom',
            baseUrl: 'https://api.x.ai/v1',
            kind: ProviderKind.openai,
            useResponseApi: false,
            modelId: 'any-chat-model',
            oauth: null,
            providerName: null,
            expected: false,
          ),
          (
            name: 'Grok host Responses',
            id: 'Custom',
            baseUrl: 'https://api.x.ai/v1',
            kind: ProviderKind.openai,
            useResponseApi: true,
            modelId: 'any-chat-model',
            oauth: null,
            providerName: null,
            expected: true,
          ),
          (
            name: 'Grok OAuth chat',
            id: 'GrokOAuth',
            baseUrl: 'https://example.com/v1',
            kind: ProviderKind.openai,
            useResponseApi: false,
            modelId: 'any-chat-model',
            oauth: OAuthProvider.grok,
            providerName: null,
            expected: false,
          ),
          (
            name: 'DashScope chat completions',
            id: 'DashScope',
            baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
            kind: ProviderKind.openai,
            useResponseApi: false,
            modelId: 'qwen-max-latest',
            oauth: null,
            providerName: null,
            expected: true,
          ),
          (
            name: 'Ark chat',
            id: 'Ark',
            baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
            kind: ProviderKind.openai,
            useResponseApi: false,
            modelId: 'doubao-seed-2.0-pro',
            oauth: null,
            providerName: null,
            expected: true,
          ),
          (
            name: 'MiMo chat',
            id: 'MiMo',
            baseUrl: 'https://api.xiaomimimo.com/v1',
            kind: ProviderKind.openai,
            useResponseApi: false,
            modelId: 'mimo-v2.5-pro',
            oauth: null,
            providerName: null,
            expected: true,
          ),
          (
            name: 'Moonshot chat',
            id: 'Moonshot',
            baseUrl: 'https://api.moonshot.cn/v1',
            kind: ProviderKind.openai,
            useResponseApi: false,
            modelId: 'moonshot-v1-8k',
            oauth: null,
            providerName: null,
            expected: true,
          ),
          (
            name: 'Zhipu chat',
            id: 'Zhipu',
            baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
            kind: ProviderKind.openai,
            useResponseApi: false,
            modelId: 'glm-4',
            oauth: null,
            providerName: null,
            expected: true,
          ),
          (
            name: 'OpenAI Responses chat',
            id: 'OpenAI',
            baseUrl: 'https://api.openai.com/v1',
            kind: ProviderKind.openai,
            useResponseApi: true,
            modelId: 'gpt-4o',
            oauth: null,
            providerName: null,
            expected: true,
          ),
          (
            name: 'custom OpenAI Responses chat',
            id: 'CustomOpenAI',
            baseUrl: 'https://proxy.example/v1',
            kind: ProviderKind.openai,
            useResponseApi: true,
            modelId: 'deepseek-v4-pro',
            oauth: null,
            providerName: null,
            expected: true,
          ),
          (
            name: 'OpenAI Chat Completions',
            id: 'OpenAI',
            baseUrl: 'https://api.openai.com/v1',
            kind: ProviderKind.openai,
            useResponseApi: false,
            modelId: 'gpt-4o',
            oauth: null,
            providerName: null,
            expected: false,
          ),
          (
            name: 'OpenAI Responses image model',
            id: 'OpenAI',
            baseUrl: 'https://api.openai.com/v1',
            kind: ProviderKind.openai,
            useResponseApi: true,
            modelId: 'dall-e-3',
            oauth: null,
            providerName: null,
            expected: false,
          ),
        ];

    for (final c in cases) {
      test(c.name, () {
        final cfg = _cfg(
          id: c.id,
          baseUrl: c.baseUrl,
          kind: c.kind,
          useResponseApi: c.useResponseApi,
          modelId: c.modelId,
          oauthProvider: c.oauth,
          name: c.providerName,
        );
        expect(
          BuiltInToolsHelper.supportsBuiltInSearchForModel(
            cfg: cfg,
            modelId: c.modelId,
          ),
          c.expected,
        );
      });
    }
  });

  group('host wire shapes', () {
    test('Grok Chat builder omits retired live search parameters', () {
      final grok = _cfg(
        id: 'Grok',
        baseUrl: 'https://api.x.ai/v1',
        kind: ProviderKind.openai,
        modelId: 'any-chat-model',
      );
      final payload = BuiltInToolsHelper.buildChatCompletionsTools(
        cfg: grok,
        modelId: 'grok-4.5',
        upstreamModelId: 'grok-4.5',
      );
      expect(payload.tools, isEmpty);
      expect(payload.body, isEmpty);
    });

    test('Grok Responses builder sends web and X search tools', () {
      final grok = _cfg(
        id: 'Grok',
        baseUrl: 'https://api.x.ai/v1',
        kind: ProviderKind.openai,
        useResponseApi: true,
        modelId: 'grok-4.7',
      );
      final payload = BuiltInToolsHelper.buildResponsesTools(
        cfg: grok,
        modelId: 'grok-4.7',
        upstreamModelId: 'grok-4.7',
      );
      expect(payload.tools, [
        {'type': 'web_search'},
        {'type': 'x_search'},
      ]);
      expect(payload.body, isEmpty);
    });

    test('Chat builder preserves provider-specific search formats', () {
      final dashScope = _cfg(
        id: 'DashScope',
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        kind: ProviderKind.openai,
        modelId: 'qwen-max-latest',
      );
      final mimo = _cfg(
        id: 'MiMo',
        baseUrl: 'https://api.xiaomimimo.com/v1',
        kind: ProviderKind.openai,
        modelId: 'mimo-v2.5-pro',
      );
      final zhipu = _cfg(
        id: 'Zhipu',
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        kind: ProviderKind.openai,
        modelId: 'glm-4',
      );

      expect(
        BuiltInToolsHelper.buildChatCompletionsTools(
          cfg: dashScope,
          modelId: 'qwen-max-latest',
          upstreamModelId: 'qwen-max-latest',
        ).body['enable_search'],
        isTrue,
      );
      expect(
        BuiltInToolsHelper.buildChatCompletionsTools(
          cfg: mimo,
          modelId: 'mimo-v2.5-pro',
          upstreamModelId: 'mimo-v2.5-pro',
        ).tools,
        <Map<String, dynamic>>[
          <String, dynamic>{'type': 'web_search'},
        ],
      );
      expect(
        BuiltInToolsHelper.buildChatCompletionsTools(
          cfg: zhipu,
          modelId: 'glm-4',
          upstreamModelId: 'glm-4',
        ).tools,
        <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'web_search',
            'web_search': <String, dynamic>{
              'enable': true,
              'search_result': true,
            },
          },
        ],
      );
    });

    test('Responses uses web_search for OpenAI / DashScope / Ark', () {
      final openai = _cfg(
        id: 'OpenAI',
        baseUrl: 'https://api.openai.com/v1',
        kind: ProviderKind.openai,
        useResponseApi: true,
        modelId: 'any-chat-model',
      );
      final dashScope = _cfg(
        id: 'DashScope',
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        kind: ProviderKind.openai,
        useResponseApi: true,
        modelId: 'qwen-max-latest',
      );
      final ark = _cfg(
        id: 'Ark',
        baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
        kind: ProviderKind.openai,
        useResponseApi: true,
        modelId: 'doubao-seed-2.0-pro',
      );

      expect(
        BuiltInToolsHelper.buildResponsesTools(
          cfg: openai,
          modelId: 'any-chat-model',
          upstreamModelId: 'any-chat-model',
        ).tools.any((tool) => tool['type'] == 'web_search'),
        isTrue,
      );
      expect(
        BuiltInToolsHelper.buildResponsesTools(
          cfg: dashScope,
          modelId: 'qwen-max-latest',
          upstreamModelId: 'qwen-max-latest',
        ).tools,
        contains(
          predicate<Map<String, dynamic>>(
            (tool) => tool['type'] == 'web_search',
          ),
        ),
      );
      expect(
        BuiltInToolsHelper.buildResponsesTools(
          cfg: ark,
          modelId: 'doubao-seed-2.0-pro',
          upstreamModelId: 'doubao-seed-2.0-pro',
        ).tools,
        contains(
          predicate<Map<String, dynamic>>(
            (tool) => tool['type'] == 'web_search',
          ),
        ),
      );
    });
  });
}
