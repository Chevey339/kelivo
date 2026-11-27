import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/builtin_tools.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderConfig _cfg({
  String baseUrl = 'https://api.deepseek.com',
  bool useResponseApi = true,
  List<String> builtInTools = const [BuiltInToolNames.search],
  String modelId = 'deepseek-flash',
}) {
  return ProviderConfig(
    id: 'DeepSeek',
    enabled: true,
    name: 'DeepSeek',
    apiKey: 'sk-test',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
    useResponseApi: useResponseApi,
    models: [modelId],
    modelOverrides: {
      modelId: {'builtInTools': builtInTools},
    },
  );
}

void main() {
  group('DeepSeek built-in tools', () {
    test('emits the documented server tool names for flash', () {
      final payload = BuiltInToolsHelper.buildResponsesTools(
        cfg: _cfg(),
        modelId: 'deepseek-flash',
        upstreamModelId: 'deepseek-flash',
      );
      final types = payload.tools.map((tool) => tool['type']).toList();
      expect(types, contains('deepseek_web_search'));
      // A plain `web_search` is ignored by DeepSeek instead of raising.
      expect(types, isNot(contains('web_search')));
    });

    test('keeps web_search for the v4-pro family', () {
      final payload = BuiltInToolsHelper.buildResponsesTools(
        cfg: _cfg(modelId: 'deepseek-v4-pro'),
        modelId: 'deepseek-v4-pro',
        upstreamModelId: 'deepseek-v4-pro',
      );
      final types = payload.tools.map((tool) => tool['type']).toList();
      expect(types, contains('web_search'));
      expect(types, isNot(contains('deepseek_web_search')));
    });

    test('does not rename tools on a relay that is merely called DeepSeek', () {
      final payload = BuiltInToolsHelper.buildResponsesTools(
        cfg: _cfg(baseUrl: 'https://relay.example.test/v1'),
        modelId: 'deepseek-flash',
        upstreamModelId: 'deepseek-flash',
      );
      final types = payload.tools.map((tool) => tool['type']).toList();
      expect(types, isNot(contains('deepseek_web_search')));
    });

    test('read link is declared on its own, without search', () {
      final payload = BuiltInToolsHelper.buildResponsesTools(
        cfg: _cfg(builtInTools: const [BuiltInToolNames.readUrl]),
        modelId: 'deepseek-flash',
        upstreamModelId: 'deepseek-flash',
      );
      expect(
        payload.tools.map((t) => t['type']),
        contains('deepseek_read_url'),
      );
      expect(payload.tools.length, 1);
    });

    test('read link stays enabled after saving model settings', () {
      final saved = BuiltInToolsHelper.replaceModelSettingsTools(
        cfg: _cfg(builtInTools: const []),
        current: const [],
        selected: const [BuiltInToolNames.readUrl],
        modelId: 'deepseek-flash',
      );
      expect(saved, contains(BuiltInToolNames.readUrl));
    });

    test('built-in search is supported outside Responses mode', () {
      expect(
        BuiltInToolsHelper.supportsBuiltInSearchForModel(
          cfg: _cfg(useResponseApi: false),
          modelId: 'deepseek-flash',
        ),
        isTrue,
      );
    });

    test('chat completions payload uses the same DeepSeek tool name', () {
      final payload = BuiltInToolsHelper.buildChatCompletionsTools(
        cfg: _cfg(),
        modelId: 'deepseek-flash',
        upstreamModelId: 'deepseek-flash',
      );
      expect(
        payload.tools.map((t) => t['type']),
        contains('deepseek_web_search'),
      );
    });

    test('V4 Pro Chat Completions drops search and stale Read Link', () {
      final cfg = _cfg(
        useResponseApi: false,
        modelId: 'deepseek-v4-pro',
        builtInTools: const [BuiltInToolNames.search, BuiltInToolNames.readUrl],
      );
      expect(
        BuiltInToolsHelper.buildChatCompletionsTools(
          cfg: cfg,
          modelId: 'deepseek-v4-pro',
          upstreamModelId: 'deepseek-v4-pro',
        ).tools,
        isEmpty,
      );
      expect(
        BuiltInToolsHelper.supportsBuiltInSearchForModel(
          cfg: cfg,
          modelId: 'deepseek-v4-pro',
        ),
        isFalse,
      );
      expect(
        BuiltInToolsHelper.modelSettingsToolNames(
          cfg,
          modelId: 'deepseek-v4-pro',
        ),
        isNot(contains(BuiltInToolNames.readUrl)),
      );
    });

    test('V4 Pro Responses preserves web_search but drops stale Read Link', () {
      final cfg = _cfg(
        modelId: 'deepseek-v4-pro',
        builtInTools: const [BuiltInToolNames.search, BuiltInToolNames.readUrl],
      );
      expect(
        BuiltInToolsHelper.buildResponsesTools(
          cfg: cfg,
          modelId: 'deepseek-v4-pro',
          upstreamModelId: 'deepseek-v4-pro',
        ).tools,
        [
          {'type': 'web_search'},
        ],
      );
    });
  });
}
