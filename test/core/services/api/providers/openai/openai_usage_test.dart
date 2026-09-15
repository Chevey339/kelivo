import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/api/providers/openai/openai_request_shaping.dart';

void main() {
  test('chat completions usage maps reasoning and cached tokens', () {
    final usage = tokenUsageFromOpenAICompatible({
      'prompt_tokens': 40,
      'completion_tokens': 12,
      'prompt_tokens_details': {'cached_tokens': 6},
      'completion_tokens_details': {'reasoning_tokens': 5},
    });

    expect(usage.promptTokens, 40);
    expect(usage.completionTokens, 12);
    expect(usage.cachedTokens, 6);
    expect(usage.reasoningTokens, 5);
    expect(usage.cacheWriteTokens, 0);
    expect(usage.totalTokens, 52);
  });

  test('responses usage maps reasoning and cached tokens', () {
    final usage = tokenUsageFromOpenAICompatible({
      'input_tokens': 80,
      'output_tokens': 20,
      'input_tokens_details': {'cached_tokens': 11},
      'output_tokens_details': {'reasoning_tokens': 9},
    });

    expect(usage.promptTokens, 80);
    expect(usage.completionTokens, 20);
    expect(usage.cachedTokens, 11);
    expect(usage.reasoningTokens, 9);
    expect(usage.cacheWriteTokens, 0);
    expect(usage.totalTokens, 100);
  });
}
