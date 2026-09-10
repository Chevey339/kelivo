import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/generation/generation_capabilities.dart';
import 'package:Kelivo/core/services/memory/memory_prompts.dart';

void main() {
  final clients = <Map<String, dynamic>>[
    {
      'type': 'function',
      'function': {'name': 'read_file'},
    },
  ];
  ProviderConfig config(
    ProviderKind kind, {
    String upstream = 'gemini-2.5-pro',
    List<String> native = const [],
    bool responses = false,
  }) => ProviderConfig(
    id: 'fixture',
    name: 'fixture',
    enabled: true,
    apiKey: '',
    baseUrl: kind == ProviderKind.claude
        ? 'https://api.anthropic.com/v1'
        : 'https://example.invalid/v1',
    providerType: kind,
    useResponseApi: responses,
    modelOverrides: {
      'alias': {'apiModelId': upstream, 'builtInTools': native},
    },
  );

  test(
    'Gemini 2 native tools displace clients, Gemini 3 coexists, aliases are respected',
    () {
      for (final upstream in ['gemini-2.5-pro', 'gemini-3.1-pro']) {
        final result = GenerationCapabilities.resolve(
          config: config(
            ProviderKind.google,
            upstream: upstream,
            native: ['search'],
          ),
          modelId: 'alias',
          clientTools: clients,
        );
        expect(result.nativeTools, ['google_search']);
        expect(result.allowsClientTools, upstream.contains('gemini-3'));
        expect(result.clientTools.isNotEmpty, upstream.contains('gemini-3'));
      }
      final plain = GenerationCapabilities.resolve(
        config: config(ProviderKind.google),
        modelId: 'alias',
        clientTools: clients,
      );
      expect(plain.clientTools, clients);
      expect(plain.nativeTools, isEmpty);
    },
  );

  test('Gemini 2 code execution wins over other native tools', () {
    final result = GenerationCapabilities.resolve(
      config: config(
        ProviderKind.google,
        native: ['search', 'code_execution', 'url_context'],
      ),
      modelId: 'alias',
      clientTools: clients,
    );
    expect(result.nativeTools, ['code_execution']);
    expect(result.clientTools, isEmpty);
  });

  test(
    'OpenAI Responses and Chat Completions share native builders with providers',
    () {
      for (final responses in [false, true]) {
        final result = GenerationCapabilities.resolve(
          config: config(
            ProviderKind.openai,
            upstream: 'gpt-4.1',
            native: ['code_interpreter'],
            responses: responses,
          ),
          modelId: 'alias',
          clientTools: clients,
        );
        expect(result.clientTools, clients);
        expect(result.nativeTools.contains('code_interpreter'), responses);
      }
    },
  );

  test('built-in memory rules describe only available operations', () {
    for (final lang in MemoryPromptLang.values) {
      final template = lang == MemoryPromptLang.zh
          ? MemoryPrompts.rulesZh
          : MemoryPrompts.rulesEn;
      final readOnly = MemoryPrompts.forAvailableTools(template, lang, {
        'memory_search_profile',
      });
      expect(readOnly, contains('<user_profile>'));
      expect(readOnly, contains('memory_search_profile'));
      for (final tool in ['memory_update', 'memory_edit', 'memory_delete']) {
        expect(RegExp(r'\b' + tool + r'\b').hasMatch(readOnly), isFalse);
      }
      expect(
        MemoryPrompts.forAvailableTools('my own rules', lang, {}),
        'my own rules',
      );
    }
  });
}
