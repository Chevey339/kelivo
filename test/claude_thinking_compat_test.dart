import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'support/claude_test_api.dart';
import 'support/collect_generation.dart';

void main() {
  group('Claude thinking compatibility', () {
    for (final vertex in [false, true]) {
      for (final model in [
        'claude-sonnet-4-5',
        'claude-haiku-4-5',
        'claude-sonnet-4-6',
      ]) {
        test(
          '$model thinking strips temperature and top_k (vertex=$vertex)',
          () async {
            final overrides = {
              model: {
                'body': [
                  {'key': 'temperature', 'value': '0.7'},
                  {'key': 'top_k', 'value': '40'},
                ],
              },
            };
            final body = await captureClaudeRequestBody(
              modelId: model,
              config: vertex
                  ? vertexClaudeConfig(modelOverrides: overrides)
                  : claudeConfig(modelOverrides: overrides),
              thinkingBudget: 2048,
              temperature: 0.7,
              topP: 0.96,
            );
            expect(
              (body['thinking'] as Map)['type'],
              isIn(['enabled', 'adaptive']),
            );
            expect(body.containsKey('temperature'), isFalse);
            expect(body.containsKey('top_k'), isFalse);
            expect(body['top_p'], 0.96);
          },
        );
      }
    }

    test(
      'prompt caching adds official Claude top-level cache control',
      () async {
        final body = await captureClaudeRequestBody(
          modelId: 'claude-sonnet-4-6',
          config: claudeConfig(claudePromptCachingEnabled: true),
          messages: const [
            {'role': 'system', 'content': 'Stable persona and long context.'},
            {'role': 'user', 'content': 'hello'},
          ],
        );

        expect(body['system'], 'Stable persona and long context.');
        expect(body['cache_control'], {'type': 'ephemeral'});
        expect((body['messages'] as List).cast<Map>().single['role'], 'user');
      },
    );

    test(
      'prompt caching can request official Claude one hour cache ttl',
      () async {
        final body = await captureClaudeRequestBody(
          modelId: 'claude-sonnet-4-6',
          config: claudeConfig(
            claudePromptCachingEnabled: true,
            claudePromptCachingTtl: '1h',
          ),
          messages: const [
            {'role': 'system', 'content': 'Stable persona and long context.'},
            {'role': 'user', 'content': 'hello'},
          ],
        );

        expect(body['cache_control'], {'type': 'ephemeral', 'ttl': '1h'});
      },
    );

    test('prompt caching ttl round trips through provider config json', () {
      final config = ProviderConfig(
        id: 'ClaudeCompatTest',
        enabled: true,
        name: 'ClaudeCompatTest',
        apiKey: 'test-key',
        baseUrl: 'https://api.anthropic.com/v1',
        providerType: ProviderKind.claude,
        claudePromptCachingEnabled: true,
        claudePromptCachingTtl: '1h',
      );

      final roundTripped = ProviderConfig.fromJson(config.toJson());

      expect(roundTripped.claudePromptCachingEnabled, isTrue);
      expect(roundTripped.claudePromptCachingTtl, '1h');
    });

    test(
      'prompt caching disabled omits official Claude cache control',
      () async {
        final body = await captureClaudeRequestBody(
          modelId: 'claude-sonnet-4-6',
          messages: const [
            {'role': 'system', 'content': 'Stable persona and long context.'},
            {'role': 'user', 'content': 'hello'},
          ],
        );

        expect(body['system'], 'Stable persona and long context.');
        expect(body.containsKey('cache_control'), isFalse);
      },
    );

    test('OpenRouter Anthropic format uses Claude messages path', () async {
      final (:bodies, :chunks, :paths) = await captureClaudeExchange(
        config: ProviderConfig(
          id: 'OpenRouterAnthropic',
          enabled: true,
          name: 'OpenRouter Anthropic',
          apiKey: 'test-key',
          baseUrl: relayBaseUrl,
          providerType: ProviderKind.claude,
        ),
        modelId: 'anthropic/claude-fable-5',
        thinkingBudget: 16000,
      );
      final requestBody = bodies.single;

      expect(chunks.isGenerationDone, isTrue);
      expect(paths.single, '/messages');
      expect(requestBody['thinking'], {
        'type': 'adaptive',
        'display': 'summarized',
      });
      expect(requestBody['output_config'], {'effort': 'medium'});
      expect(requestBody['max_tokens'], 128000);
    });

    test('generateText Claude path reads text after thinking block', () async {
      await captureClaudeRequestBody(
        modelId: 'deepseek-v4-pro',
        thinkingBudget: -1,
        utilityCall: true,
        replies: const [
          {
            'content': [
              {'type': 'thinking', 'thinking': '先思考。'},
              {'type': 'text', 'text': 'ok'},
            ],
          },
        ],
      );
    });

    for (final c in _claudeCases) {
      test(c.name, () async {
        final body = await captureClaudeRequestBody(
          modelId: c.modelId,
          config: c.config,
          thinkingBudget: c.thinkingBudget,
          temperature: c.temperature,
          topP: c.topP,
          utilityCall: c.utilityCall,
        );
        c.verify(body);
      });
    }
  });
}

class _ClaudeCase {
  const _ClaudeCase({
    required this.name,
    required this.modelId,
    this.config,
    this.thinkingBudget,
    this.temperature,
    this.topP,
    this.utilityCall = false,
    required this.verify,
  });

  final String name;
  final String modelId;
  final ProviderConfig? config;
  final int? thinkingBudget;
  final double? temperature;
  final double? topP;
  final bool utilityCall;
  final void Function(Map<String, dynamic> body) verify;
}

ProviderConfig _kimiAnthropicConfig() {
  return ProviderConfig(
    id: 'KimiAnthropic',
    enabled: true,
    name: 'KimiAnthropic',
    apiKey: 'test-key',
    baseUrl: 'https://api.kimi.com/coding/v1',
    providerType: ProviderKind.claude,
  );
}

final _claudeCases = <_ClaudeCase>[
  _ClaudeCase(
    name: 'classic Claude auto omits the thinking key',
    modelId: 'claude-haiku-4-5',
    thinkingBudget: -1,
    verify: (body) {
      expect(body.containsKey('thinking'), isFalse);
      expect(body.containsKey('output_config'), isFalse);
      expect(body['max_tokens'], 64000);
    },
  ),
  _ClaudeCase(
    name: 'classic Claude off sends disabled thinking',
    modelId: 'claude-haiku-4-5',
    thinkingBudget: 0,
    temperature: 0.7,
    topP: 0.8,
    verify: (body) {
      expect(body['thinking'], {'type': 'disabled'});
      expect(body['temperature'], 0.7);
      expect(body['top_p'], 0.8);
    },
  ),
  _ClaudeCase(
    name: 'classic Claude explicit budget writes budget_tokens',
    modelId: 'claude-haiku-4-5',
    thinkingBudget: 2048,
    verify: (body) {
      expect(body['thinking'], {'type': 'enabled', 'budget_tokens': 2048});
      expect(body.containsKey('output_config'), isFalse);
    },
  ),
  _ClaudeCase(
    name: 'classic Claude drops top_p outside the enabled range',
    modelId: 'claude-haiku-4-5',
    thinkingBudget: 2048,
    topP: 0.8,
    verify: (body) {
      expect(body['thinking'], {'type': 'enabled', 'budget_tokens': 2048});
      expect(body.containsKey('top_p'), isFalse);
    },
  ),
  _ClaudeCase(
    name: 'Opus 4.7 adaptive medium strips sampling',
    modelId: 'claude-opus-4-7',
    thinkingBudget: 16000,
    temperature: 0.7,
    topP: 0.8,
    verify: (body) {
      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'medium'});
      expect(body.containsKey('temperature'), isFalse);
      expect(body.containsKey('top_p'), isFalse);
    },
  ),
  _ClaudeCase(
    name: 'Opus 4.7 off disables thinking and keeps sampling',
    modelId: 'claude-opus-4-7',
    thinkingBudget: 0,
    temperature: 0.7,
    topP: 0.8,
    verify: (body) {
      expect(body['thinking'], {'type': 'disabled'});
      expect(body.containsKey('output_config'), isFalse);
      expect(body['temperature'], 0.7);
      expect(body['top_p'], 0.8);
    },
  ),
  _ClaudeCase(
    name: 'Opus 4.8 auto writes only adaptive surface flags',
    modelId: 'claude-opus-4-8',
    thinkingBudget: -1,
    verify: (body) {
      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body.containsKey('output_config'), isFalse);
      expect(body['max_tokens'], 128000);
    },
  ),
  _ClaudeCase(
    name: 'Opus 4.8 xhigh and max map onto the effort ladder',
    modelId: 'claude-opus-4.8',
    thinkingBudget: 64000,
    verify: (body) {
      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'xhigh'});
    },
  ),
  _ClaudeCase(
    name: 'Opus 5 max effort and 128k default max_tokens',
    modelId: 'claude-opus-5',
    thinkingBudget: 128000,
    temperature: 0.7,
    topP: 0.8,
    verify: (body) {
      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'max'});
      expect(body['max_tokens'], 128000);
      expect(body.containsKey('temperature'), isFalse);
      expect(body.containsKey('top_p'), isFalse);
    },
  ),
  _ClaudeCase(
    name: 'Opus 5.5 max effort and 128k default max_tokens',
    modelId: 'claude-opus-5-5',
    thinkingBudget: 128000,
    temperature: 0.7,
    topP: 0.8,
    verify: (body) {
      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'max'});
      expect(body['max_tokens'], 128000);
      expect(body.containsKey('temperature'), isFalse);
      expect(body.containsKey('top_p'), isFalse);
    },
  ),
  _ClaudeCase(
    name: 'Sonnet 5 can disable thinking but still rejects sampling',
    modelId: 'claude-sonnet-5',
    thinkingBudget: 0,
    temperature: 0.7,
    topP: 0.8,
    verify: (body) {
      expect(body['thinking'], {'type': 'disabled'});
      expect(body.containsKey('output_config'), isFalse);
      expect(body['max_tokens'], 128000);
      expect(body.containsKey('temperature'), isFalse);
      expect(body.containsKey('top_p'), isFalse);
    },
  ),
  _ClaudeCase(
    name: 'Fable 5 off uses the lowest adaptive effort',
    modelId: 'claude-fable-5',
    thinkingBudget: 0,
    temperature: 0.7,
    topP: 0.8,
    verify: (body) {
      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'low'});
      expect(body.containsKey('temperature'), isFalse);
      expect(body.containsKey('top_p'), isFalse);
    },
  ),
  _ClaudeCase(
    name: 'Fable 5.1 maps the full adaptive ladder',
    modelId: 'claude-fable-5-1',
    thinkingBudget: 128000,
    verify: (body) {
      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'max'});
      expect(body['max_tokens'], 128000);
    },
  ),
  _ClaudeCase(
    name: 'Fable 5.1 auto writes adaptive thinking without effort',
    modelId: 'claude-fable-5-1',
    thinkingBudget: -1,
    verify: (body) {
      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body.containsKey('output_config'), isFalse);
    },
  ),
  _ClaudeCase(
    name: 'Mythos 5 cannot disable thinking',
    modelId: 'claude-mythos-5',
    thinkingBudget: 0,
    verify: (body) {
      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'low'});
      expect(body['max_tokens'], 128000);
    },
  ),
  _ClaudeCase(
    name: 'Sonnet 4.6 adaptive low and max clamp',
    modelId: 'claude-sonnet-4-6',
    thinkingBudget: 1024,
    verify: (body) {
      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'low'});
    },
  ),
  _ClaudeCase(
    name: 'Sonnet 4.6 clamps xhigh budget to nearest ladder level',
    modelId: 'claude-sonnet-4-6',
    thinkingBudget: 64000,
    verify: (body) {
      expect(body['output_config'], {'effort': 'high'});
    },
  ),
  _ClaudeCase(
    name: 'generateText adaptive path matches Opus 4.7',
    modelId: 'claude-opus-4-7',
    thinkingBudget: 16000,
    utilityCall: true,
    verify: (body) {
      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'medium'});
      expect(body['stream'], isFalse);
    },
  ),
  _ClaudeCase(
    name: 'DeepSeek Claude auto writes no thinking key',
    modelId: 'deepseek-v4-pro',
    config: deepSeekClaudeConfig(),
    thinkingBudget: -1,
    verify: (body) {
      expect(body.containsKey('thinking'), isFalse);
      expect(body.containsKey('output_config'), isFalse);
    },
  ),
  _ClaudeCase(
    name: 'DeepSeek Claude explicit effort uses the anthropicEffort ladder',
    modelId: 'deepseek-v4-pro',
    config: deepSeekClaudeConfig(),
    thinkingBudget: 2000,
    verify: (body) {
      expect(body['thinking'], {'type': 'enabled'});
      expect(body['output_config'], {'effort': 'low'});
    },
  ),
  _ClaudeCase(
    name: 'DeepSeek Claude medium clamps to nearest ladder level',
    modelId: 'deepseek-v4-pro',
    config: deepSeekClaudeConfig(),
    thinkingBudget: 16000,
    verify: (body) {
      expect(body['thinking'], {'type': 'enabled'});
      expect(body['output_config'], {'effort': 'low'});
    },
  ),
  _ClaudeCase(
    name: 'DeepSeek Claude off uses the lowest effort',
    modelId: 'deepseek-v4-pro',
    config: deepSeekClaudeConfig(),
    thinkingBudget: 0,
    temperature: 0.7,
    topP: 0.8,
    verify: (body) {
      expect(body['thinking'], {'type': 'enabled'});
      expect(body['output_config'], {'effort': 'low'});
    },
  ),
  _ClaudeCase(
    name: 'Kimi Anthropic uses budget dialect and 32k max_tokens',
    modelId: 'kimi-k2.5',
    config: _kimiAnthropicConfig(),
    thinkingBudget: 2048,
    verify: (body) {
      expect(body['thinking'], {'type': 'enabled', 'budget_tokens': 2048});
      expect(body.containsKey('output_config'), isFalse);
      expect(body['max_tokens'], 32000);
    },
  ),
  _ClaudeCase(
    name: 'Kimi Anthropic auto omits thinking',
    modelId: 'kimi-k2.5',
    config: _kimiAnthropicConfig(),
    thinkingBudget: -1,
    verify: (body) {
      expect(body.containsKey('thinking'), isFalse);
      expect(body['max_tokens'], 32000);
    },
  ),
  _ClaudeCase(
    name: 'Vertex Claude default max_tokens comes from the spec',
    modelId: 'claude-sonnet-4-6',
    config: vertexClaudeConfig(),
    thinkingBudget: 1024,
    verify: (body) {
      expect(body['max_tokens'], 128000);
      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'low'});
    },
  ),
  _ClaudeCase(
    name: 'Vertex dated classic Claude uses family max_tokens',
    modelId: 'claude-sonnet-4@20250514',
    config: vertexClaudeConfig(),
    thinkingBudget: -1,
    verify: (body) {
      expect(body['max_tokens'], 64000);
      expect(body.containsKey('thinking'), isFalse);
    },
  ),
  _ClaudeCase(
    name: 'Vertex Claude clamps budget_tokens below max_tokens',
    modelId: 'claude-haiku-4-5',
    config: vertexClaudeConfig(),
    thinkingBudget: 128000,
    verify: (body) {
      expect(body['max_tokens'], 64000);
      expect(body['thinking'], {'type': 'enabled', 'budget_tokens': 62976});
    },
  ),
];
