import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_vendor_compat.dart';

OpenAIProviderInfo _info({
  String host = '',
  String providerId = 'poolside',
  String modelId = 'poolside/laguna-s-2.1',
}) {
  return OpenAIProviderInfo(
    host: host,
    providerId: providerId,
    upstreamModelId: modelId,
  );
}

void main() {
  group('Poolside Laguna thinking knobs', () {
    test('recognizes official Laguna ids and Poolside hosts', () {
      expect(_info(modelId: 'poolside/laguna-s-2.1').isLaguna, isTrue);
      expect(_info(modelId: 'poolside/laguna-xs-2.1').isLaguna, isTrue);
      expect(_info(modelId: 'laguna-s-2.1').isLaguna, isTrue);
      expect(
        _info(
          host: 'inference.poolside.ai',
          modelId: 'custom-id',
        ).isPoolsideHost,
        isTrue,
      );
      expect(
        _info(
          host: 'inference.poolside.ai',
          modelId: 'custom-id',
        ).usesPoolsideThinking,
        isTrue,
      );
      expect(
        _info(host: 'api.openai.com', modelId: 'gpt-5').usesPoolsideThinking,
        isFalse,
      );
    });

    test('always sends enable_thinking for Laguna', () {
      final enabled = <String, dynamic>{'reasoning_effort': 'high'};
      applyVendorReasoningKnobs(
        enabled,
        info: _info(),
        isReasoning: true,
        thinkingBudget: 128000,
      );
      expect(enabled['chat_template_kwargs'], {'enable_thinking': true});
      expect(enabled.containsKey('reasoning_effort'), isFalse);

      final disabled = <String, dynamic>{};
      applyVendorReasoningKnobs(
        disabled,
        info: _info(),
        isReasoning: true,
        thinkingBudget: 0,
      );
      expect(disabled['chat_template_kwargs'], {'enable_thinking': false});

      final unmarked = <String, dynamic>{};
      applyVendorReasoningKnobs(
        unmarked,
        info: _info(),
        isReasoning: false,
        thinkingBudget: 128000,
      );
      expect(unmarked['chat_template_kwargs'], {'enable_thinking': false});
    });

    test(
      'keeps extra chat_template_kwargs and fills missing enable_thinking',
      () {
        final body = <String, dynamic>{
          'chat_template_kwargs': {'foo': 'bar'},
        };
        applyPoolsideThinkingIfNeeded(
          body,
          info: _info(),
          isReasoning: true,
          thinkingBudget: 128000,
        );
        expect(body['chat_template_kwargs'], {
          'foo': 'bar',
          'enable_thinking': true,
        });

        final overridden = <String, dynamic>{
          'chat_template_kwargs': {'enable_thinking': false, 'foo': 'bar'},
        };
        applyPoolsideThinkingIfNeeded(
          overridden,
          info: _info(),
          isReasoning: true,
          thinkingBudget: 128000,
        );
        expect(overridden['chat_template_kwargs'], {
          'enable_thinking': false,
          'foo': 'bar',
        });
      },
    );

    test('Responses path uses chat_template_kwargs instead of reasoning', () {
      final body = <String, dynamic>{
        'reasoning': {'effort': 'high', 'summary': 'auto'},
      };
      applyCompatibleResponsesReasoning(
        body,
        config: ProviderConfig(
          id: 'Poolside',
          enabled: true,
          name: 'Poolside',
          apiKey: 'k',
          baseUrl: 'https://inference.poolside.ai/v1',
          providerType: ProviderKind.openai,
          useResponseApi: true,
        ),
        modelId: 'poolside/laguna-s-2.1',
        upstreamModelId: 'poolside/laguna-s-2.1',
        isReasoning: true,
        thinkingBudget: 128000,
      );
      expect(body['chat_template_kwargs'], {'enable_thinking': true});
      expect(body.containsKey('reasoning'), isFalse);
    });
  });
}
