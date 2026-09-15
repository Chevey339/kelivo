import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/reasoning_request.dart';

void main() {
  group('Assistant.reasoning', () {
    test('defaults to null and serializes as null', () {
      const assistant = Assistant(id: 'a', name: 'A');
      expect(assistant.reasoning, isNull);
      expect(assistant.toJson()['reasoning'], isNull);
      expect(Assistant.fromJson(assistant.toJson()).reasoning, isNull);
    });

    test(
      'round-trips a stored request and ignores old thinkingBudget ints',
      () {
        const request = ReasoningRequest(
          ReasoningLevel.xhigh,
          budgetTokens: 64000,
        );
        const assistant = Assistant(id: 'a', name: 'A', reasoning: request);
        final json = assistant.toJson();
        expect(json['reasoning'], {'level': 'xhigh', 'budgetTokens': 64000});
        expect(json.containsKey('thinkingBudget'), isFalse);

        final restored = Assistant.fromJson(json);
        expect(restored.reasoning, request);

        final fromLegacyInt = Assistant.fromJson({
          'id': 'a',
          'name': 'A',
          'thinkingBudget': 16000,
        });
        expect(fromLegacyInt.reasoning, isNull);
      },
    );

    test('copyWith can replace or clear reasoning', () {
      const assistant = Assistant(
        id: 'a',
        name: 'A',
        reasoning: ReasoningRequest(ReasoningLevel.low, budgetTokens: 1024),
      );
      expect(
        assistant.copyWith(reasoning: ReasoningRequest.off).reasoning,
        ReasoningRequest.off,
      );
      expect(assistant.copyWith(clearReasoning: true).reasoning, isNull);
    });
  });
}
