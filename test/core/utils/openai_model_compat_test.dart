import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/utils/openai_model_compat.dart';

void main() {
  group('GPT-5.6 reasoning compatibility', () {
    const modelIds = <String>[
      'gpt-5.6',
      'gpt-5.6-sol',
      'gpt-5.6-terra',
      'gpt-5.6-luna',
    ];

    for (final modelId in modelIds) {
      test('$modelId exposes every supported reasoning effort', () {
        final support = openAIReasoningSupport(modelId);

        expect(support?.supportedEfforts, const <String>[
          'none',
          'low',
          'medium',
          'high',
          'xhigh',
          'max',
        ]);
        expect(openAISupportsNoneReasoning(modelId), isTrue);
        expect(openAISupportsXhighReasoning(modelId), isTrue);
        expect(openAISupportsMaxReasoning(modelId), isTrue);
        expect(openAINormalizeReasoningEffort('off', modelId), 'none');
        expect(openAINormalizeReasoningEffort('xhigh', modelId), 'xhigh');
        expect(openAINormalizeReasoningEffort('max', modelId), 'max');
      });
    }

    test('older GPT-5 models keep their existing effort ceiling', () {
      expect(openAISupportsMaxReasoning('gpt-5.5'), isFalse);
      expect(openAINormalizeReasoningEffort('max', 'gpt-5.5'), 'xhigh');
      expect(openAINormalizeReasoningEffort('max', 'gpt-5'), 'high');
    });
  });
}
