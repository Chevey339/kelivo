import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'support/claude_test_api.dart';
import 'support/collect_generation.dart';

void main() {
  group('Claude thinking compatibility', () {
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

    test(
      'Opus 4.7 uses adaptive thinking with effort and strips sampling',
      () async {
        final body = await captureClaudeRequestBody(
          modelId: 'claude-opus-4-7',
          thinkingBudget: 16000,
          temperature: 0.7,
          topP: 0.8,
        );

        expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
        expect(body['output_config'], {'effort': 'medium'});
        expect(body.containsKey('temperature'), isFalse);
        expect(body.containsKey('top_p'), isFalse);
        expect(
          (body['thinking'] as Map<String, dynamic>).containsKey(
            'budget_tokens',
          ),
          isFalse,
        );
      },
    );

    test(
      'Opus 4.8 uses adaptive thinking with xhigh effort and strips sampling',
      () async {
        final body = await captureClaudeRequestBody(
          modelId: 'claude-opus-4-8',
          thinkingBudget: 64000,
          temperature: 0.7,
          topP: 0.8,
        );

        expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
        expect(body['output_config'], {'effort': 'xhigh'});
        expect(body.containsKey('temperature'), isFalse);
        expect(body.containsKey('top_p'), isFalse);
      },
    );

    test('Opus 4.8 maps max reasoning to max effort', () async {
      final body = await captureClaudeRequestBody(
        modelId: 'claude-opus-4.8',
        thinkingBudget: 128000,
      );

      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'max'});
    });

    test('Opus 5 uses summarized adaptive thinking and max effort', () async {
      final body = await captureClaudeRequestBody(
        modelId: 'claude-opus-5',
        thinkingBudget: 128000,
        temperature: 0.7,
        topP: 0.8,
      );

      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'max'});
      expect(body['max_tokens'], 128000);
      expect(body.containsKey('temperature'), isFalse);
      expect(body.containsKey('top_p'), isFalse);
    });

    test('Sonnet 5 can disable thinking but still rejects sampling', () async {
      final body = await captureClaudeRequestBody(
        modelId: 'claude-sonnet-5',
        thinkingBudget: 0,
        temperature: 0.7,
        topP: 0.8,
      );

      expect(body['thinking'], {'type': 'disabled'});
      expect(body.containsKey('output_config'), isFalse);
      expect(body['max_tokens'], 128000);
      expect(body.containsKey('temperature'), isFalse);
      expect(body.containsKey('top_p'), isFalse);
    });

    test('Fable 5 never sends unsupported disabled thinking', () async {
      final offBody = await captureClaudeRequestBody(
        modelId: 'claude-fable-5',
        thinkingBudget: 0,
        temperature: 0.7,
        topP: 0.8,
      );
      final mediumBody = await captureClaudeRequestBody(
        modelId: 'claude-fable-5',
        thinkingBudget: 16000,
      );

      expect(offBody.containsKey('thinking'), isFalse);
      expect(offBody.containsKey('output_config'), isFalse);
      expect(offBody.containsKey('temperature'), isFalse);
      expect(offBody.containsKey('top_p'), isFalse);
      expect(mediumBody['thinking'], {
        'type': 'adaptive',
        'display': 'summarized',
      });
      expect(mediumBody['output_config'], {'effort': 'medium'});
    });

    test('Fable 5 maps max reasoning to max effort', () async {
      final body = await captureClaudeRequestBody(
        modelId: 'claude-fable-5',
        thinkingBudget: 128000,
      );

      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'max'});
    });

    test(
      'Mythos 5 never sends disabled thinking and returns summaries',
      () async {
        final offBody = await captureClaudeRequestBody(
          modelId: 'claude-mythos-5',
          thinkingBudget: 0,
        );
        final maxBody = await captureClaudeRequestBody(
          modelId: 'claude-mythos-5',
          thinkingBudget: 128000,
        );

        expect(offBody.containsKey('thinking'), isFalse);
        expect(offBody.containsKey('output_config'), isFalse);
        expect(maxBody['thinking'], {
          'type': 'adaptive',
          'display': 'summarized',
        });
        expect(maxBody['output_config'], {'effort': 'max'});
        expect(maxBody['max_tokens'], 128000);
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
    });

    test(
      'Opus 4.7 off keeps sampling params and omits output config',
      () async {
        final body = await captureClaudeRequestBody(
          modelId: 'claude-opus-4-7',
          thinkingBudget: 0,
          temperature: 0.7,
          topP: 0.8,
        );

        expect(body['thinking'], {'type': 'disabled'});
        expect(body['temperature'], 0.7);
        expect(body['top_p'], 0.8);
        expect(body.containsKey('output_config'), isFalse);
      },
    );

    test('Sonnet 4.6 enabled budget now uses adaptive thinking', () async {
      final body = await captureClaudeRequestBody(
        modelId: 'claude-sonnet-4-6',
        thinkingBudget: 1024,
      );

      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'low'});
      expect(
        (body['thinking'] as Map<String, dynamic>).containsKey('budget_tokens'),
        isFalse,
      );
    });

    test('Sonnet 4.6 thinking omits temperature and invalid top_p', () async {
      final body = await captureClaudeRequestBody(
        modelId: 'claude-sonnet-4-6',
        thinkingBudget: 1024,
        temperature: 0.7,
        topP: 0.8,
      );

      expect(body.containsKey('temperature'), isFalse);
      expect(body.containsKey('top_p'), isFalse);
    });

    test('Sonnet 4.6 clamps large budget to max instead of xhigh', () async {
      final body = await captureClaudeRequestBody(
        modelId: 'claude-sonnet-4-6',
        thinkingBudget: 64000,
      );

      expect(body['output_config'], {'effort': 'max'});
    });

    test('Opus 4.7 allows xhigh for large but non-max budgets', () async {
      final body = await captureClaudeRequestBody(
        modelId: 'claude-opus-4-7',
        thinkingBudget: 64000,
      );

      expect(body['output_config'], {'effort': 'xhigh'});
    });

    test('generateText Claude path matches Opus 4.7 adaptive rules', () async {
      final body = await captureClaudeRequestBody(
        modelId: 'claude-opus-4-7',
        thinkingBudget: 16000,
        utilityCall: true,
      );

      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'medium'});
      expect(body['stream'], isFalse);
      expect(body.containsKey('temperature'), isFalse);
      expect(
        (body['thinking'] as Map<String, dynamic>).containsKey('budget_tokens'),
        isFalse,
      );
    });

    test(
      'generateText Claude path omits temperature when thinking is off',
      () async {
        final body = await captureClaudeRequestBody(
          modelId: 'claude-haiku-4-5',
          thinkingBudget: 0,
          utilityCall: true,
        );

        expect(body.containsKey('temperature'), isFalse);
      },
    );

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

    test('DeepSeek Claude-compatible auto thinking stays enabled', () async {
      final body = await captureClaudeRequestBody(
        modelId: 'deepseek-v4-pro',
        config: deepSeekClaudeConfig(),
        thinkingBudget: -1,
      );

      expect(body['thinking'], {'type': 'enabled'});
      expect(body.containsKey('output_config'), isFalse);
    });

    test('DeepSeek Claude-compatible explicit thinking uses effort', () async {
      final lowBody = await captureClaudeRequestBody(
        modelId: 'deepseek-v4-pro',
        config: deepSeekClaudeConfig(),
        thinkingBudget: 2000,
      );
      final mediumBody = await captureClaudeRequestBody(
        modelId: 'deepseek-v4-pro',
        config: deepSeekClaudeConfig(),
        thinkingBudget: 16000,
      );
      final xhighBody = await captureClaudeRequestBody(
        modelId: 'deepseek-v4-pro',
        config: deepSeekClaudeConfig(),
        thinkingBudget: 64000,
      );
      final maxBody = await captureClaudeRequestBody(
        modelId: 'deepseek-v4-pro',
        config: deepSeekClaudeConfig(),
        thinkingBudget: 128000,
      );

      expect(lowBody['thinking'], {'type': 'enabled'});
      expect(lowBody['output_config'], {'effort': 'low'});
      expect(mediumBody['thinking'], {'type': 'enabled'});
      expect(mediumBody['output_config'], {'effort': 'high'});
      expect(xhighBody['thinking'], {'type': 'enabled'});
      expect(xhighBody['output_config'], {'effort': 'high'});
      expect(maxBody['thinking'], {'type': 'enabled'});
      expect(maxBody['output_config'], {'effort': 'max'});
    });

    test('DeepSeek Claude-compatible off thinking stays disabled', () async {
      final body = await captureClaudeRequestBody(
        modelId: 'deepseek-v4-pro',
        config: deepSeekClaudeConfig(),
        thinkingBudget: 0,
        temperature: 0.7,
        topP: 0.8,
      );

      expect(body['thinking'], {'type': 'disabled'});
      expect(body.containsKey('output_config'), isFalse);
      expect(body['temperature'], 0.7);
      expect(body['top_p'], 0.8);
    });
  });
}
