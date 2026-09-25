import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/custom_request_merger.dart';
import 'package:Kelivo/core/services/model_override_payload_parser.dart';

void main() {
  group('CustomRequestMerger', () {
    test(
      'merges unique headers and applies model-provider-assistant priority',
      () {
        final provider = ModelOverridePayloadParser.customHeadersFromRows(
          const [
            {'name': 'x-level', 'value': 'provider'},
            {'name': 'X-Provider', 'value': 'provider-only'},
          ],
        );
        final model = ModelOverridePayloadParser.customHeadersFromRows(const [
          {'name': 'X-LEVEL', 'value': 'model'},
          {'name': 'X-Model', 'value': 'model-only'},
        ]);

        final merged = CustomRequestMerger.mergeHeaders(
          base: const {'Content-Type': 'application/json'},
          assistant: const {
            'X-Level': 'assistant',
            'X-Assistant': 'assistant-only',
          },
          provider: provider,
          model: model,
        );

        expect(merged['X-LEVEL'], 'model');
        expect(
          merged.keys.where((key) => key.toLowerCase() == 'x-level'),
          hasLength(1),
        );
        expect(merged['X-Assistant'], 'assistant-only');
        expect(merged['X-Provider'], 'provider-only');
        expect(merged['X-Model'], 'model-only');
        expect(merged['Content-Type'], 'application/json');
      },
    );

    test('uses the last case-insensitive header within one level', () {
      final provider = ModelOverridePayloadParser.customHeadersFromRows(const [
        {'name': 'X-Duplicate', 'value': 'first'},
        {'name': 'x-duplicate', 'value': 'last'},
      ]);

      final merged = CustomRequestMerger.mergeHeaders(provider: provider);

      expect(merged, {'x-duplicate': 'last'});
    });

    test('keeps the internal conversation header at final priority', () {
      final merged = CustomRequestMerger.mergeHeaders(
        assistant: const {'X-Conversation-Id': 'conversation-123'},
        provider: const {'x-conversation-id': 'provider'},
        model: const {'X-CONVERSATION-ID': 'model'},
      );

      expect(merged, {'X-Conversation-Id': 'conversation-123'});
    });

    test('deep merges body layers and parses configured string values', () {
      final merged = CustomRequestMerger.mergeBody(
        assistant: const {
          'shared': 'assistant',
          'assistantOnly': '3',
          'nested': {'assistant': true},
        },
        providerRows: const [
          {'key': 'shared', 'value': 'provider'},
          {'key': 'providerOnly', 'value': 'true'},
          {'key': 'nested', 'value': '{"provider":true}'},
        ],
        model: const {
          'shared': 'model',
          'nested': {'model': true},
          'nullable': null,
        },
      );

      expect(merged['shared'], 'model');
      expect(merged['assistantOnly'], 3);
      expect(merged['providerOnly'], isTrue);
      expect(merged['nested'], {
        'assistant': true,
        'provider': true,
        'model': true,
      });
      expect(merged, containsPair('nullable', null));
    });

    test('applyBody lets custom values win and keeps generated siblings', () {
      final body = <String, dynamic>{
        'generationConfig': {
          'maxOutputTokens': 8192,
          'thinkingConfig': {'thinkingBudget': 1024, 'includeThoughts': true},
        },
        'tools': [
          {'type': 'web_search'},
        ],
        'temperature': 0.2,
      };
      CustomRequestMerger.applyBody(body, {
        'generationConfig': {
          'responseMimeType': 'application/json',
          'thinkingConfig': {'thinkingBudget': 0},
        },
        'tools': <Object>[],
        'temperature': null,
      });

      expect(body['generationConfig'], {
        'maxOutputTokens': 8192,
        'thinkingConfig': {'thinkingBudget': 0},
        'responseMimeType': 'application/json',
      });
      expect(body['tools'], isEmpty);
      expect(body, containsPair('temperature', null));
    });

    test('applyBody replaces reasoning objects whole', () {
      final body = <String, dynamic>{
        'thinking': {'type': 'enabled', 'budget_tokens': 4096},
        'reasoning': {'effort': 'high'},
      };
      CustomRequestMerger.applyBody(body, {
        'thinking': {'type': 'disabled'},
        'reasoning': {'enabled': false},
      });

      expect(body['thinking'], {'type': 'disabled'});
      expect(body['reasoning'], {'enabled': false});
    });
  });
}
