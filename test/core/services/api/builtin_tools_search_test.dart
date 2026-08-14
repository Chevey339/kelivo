import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/builtin_tools.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderConfig _cfg({
  required String baseUrl,
  required bool useResponseApi,
  required String modelId,
}) {
  return ProviderConfig(
    id: 'Test',
    enabled: true,
    name: 'Test',
    apiKey: 'k',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
    useResponseApi: useResponseApi,
    modelOverrides: {
      modelId: {
        'builtInTools': [BuiltInToolNames.search],
      },
    },
  );
}

void main() {
  group('Built-in search tools', () {
    test('enables 3.7 max/plus and 3.8-max-preview only', () {
      expect(
        BuiltInToolsHelper.isDashScopeResponsesBuiltInSearchSupportedModel(
          'qwen3.7-plus',
        ),
        isTrue,
      );
      expect(
        BuiltInToolsHelper.isDashScopeResponsesBuiltInSearchSupportedModel(
          'qwen3.7-max',
        ),
        isTrue,
      );
      expect(
        BuiltInToolsHelper.isDashScopeResponsesBuiltInSearchSupportedModel(
          'qwen3.8-max-preview',
        ),
        isTrue,
      );
      expect(
        BuiltInToolsHelper.isDashScopeResponsesBuiltInSearchSupportedModel(
          'qwen3.8-max',
        ),
        isFalse,
      );
      expect(
        BuiltInToolsHelper.isDashScopeResponsesBuiltInSearchSupportedModel(
          'qwen3.7-flash',
        ),
        isFalse,
      );
    });

    test('supportsBuiltInSearchForModel routes Ark/MiMo/Zhipu/Kimi', () {
      final ark = _cfg(
        baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
        useResponseApi: true,
        modelId: 'doubao-seed-2.0-pro',
      );
      final mimo = _cfg(
        baseUrl: 'https://api.xiaomimimo.com/v1',
        useResponseApi: false,
        modelId: 'mimo-v2.5-pro',
      );
      final zhipu = _cfg(
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        useResponseApi: false,
        modelId: 'glm-5',
      );
      final kimi = _cfg(
        baseUrl: 'https://api.moonshot.cn/v1',
        useResponseApi: false,
        modelId: 'kimi-k3',
      );

      expect(
        BuiltInToolsHelper.supportsBuiltInSearchForModel(
          cfg: ark,
          modelId: 'doubao-seed-2.0-pro',
        ),
        isTrue,
      );
      expect(
        BuiltInToolsHelper.supportsBuiltInSearchForModel(
          cfg: mimo,
          modelId: 'mimo-v2.5-pro',
        ),
        isTrue,
      );
      expect(
        BuiltInToolsHelper.supportsBuiltInSearchForModel(
          cfg: zhipu,
          modelId: 'glm-5',
        ),
        isTrue,
      );
      expect(
        BuiltInToolsHelper.supportsBuiltInSearchForModel(
          cfg: kimi,
          modelId: 'kimi-k3',
        ),
        isTrue,
      );
    });

    test('Chat builder preserves provider-specific search formats', () {
      final grok = _cfg(
        baseUrl: 'https://api.x.ai/v1',
        useResponseApi: false,
        modelId: 'grok-4',
      );
      final dashScope = _cfg(
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        useResponseApi: false,
        modelId: 'qwen-max-latest',
      );
      final mimo = _cfg(
        baseUrl: 'https://api.xiaomimimo.com/v1',
        useResponseApi: false,
        modelId: 'mimo-v2.5-pro',
      );
      final zhipu = _cfg(
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        useResponseApi: false,
        modelId: 'glm-5',
      );

      expect(
        BuiltInToolsHelper.buildChatCompletionsTools(
          cfg: grok,
          modelId: 'grok-4',
          upstreamModelId: 'grok-4',
        ).body['search_parameters'],
        <String, dynamic>{'mode': 'auto', 'return_citations': true},
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
          modelId: 'glm-5',
          upstreamModelId: 'glm-5',
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
  });
}
