import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/services/chat/runtime_context.dart';
import 'package:Kelivo/core/services/logging/context_log_models.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';

void main() {
  RuntimeContextSnapshot snapshot(
    Assistant assistant, {
    DateTime? now,
    Duration offset = const Duration(hours: 5, minutes: 45),
  }) => RuntimeContextSnapshot.capture(
    assistant: assistant,
    now: now ?? DateTime.utc(2026, 12, 31, 23, 59, 59),
    appLocale: 'zh-Hans',
    modelName: 'My model',
    modelId: 'upstream-id',
    timezoneName: 'NPT',
    utcOffset: offset,
  );

  test(
    'time placeholder detection ignores timezone and preserves stable order',
    () {
      expect(
        detectTimeVariablesInSystemPrompt(
          '{cur_datetime} {timezone} {cur_date} {cur_time}',
        ),
        ['{cur_date}', '{cur_time}', '{cur_datetime}'],
      );
      expect(detectTimeVariablesInSystemPrompt('{timezone} {locale}'), isEmpty);
    },
  );

  test('all eight independent toggle combinations round-trip', () {
    for (var mask = 0; mask < 8; mask++) {
      final assistant = const Assistant(id: 'a', name: 'A').copyWith(
        appendCurrentTimeToUserMessage: mask & 1 != 0,
        includeAppLocaleInContext: mask & 2 != 0,
        includeModelInfoInContext: mask & 4 != 0,
      );
      final restored = Assistant.fromJson(assistant.toJson());
      final values = snapshot(restored).values;
      expect(values.containsKey('generation_time'), mask & 1 != 0);
      expect(values.containsKey('app_locale'), mask & 2 != 0);
      expect(values.containsKey('request_model_id'), mask & 4 != 0);
      expect(snapshot(restored).toPrompt().isEmpty, mask == 0);
    }
    final existing = Assistant.fromJson({
      'id': 'a',
      'name': 'A',
      'appendCurrentTimeToUserMessage': true,
    });
    expect(existing.appendCurrentTimeToUserMessage, isTrue);
    expect(existing.includeAppLocaleInContext, isFalse);
    expect(existing.includeModelInfoInContext, isFalse);
  });

  test(
    'time includes seconds, weekday and positive / negative fractional offsets',
    () {
      const assistant = Assistant(
        id: 'a',
        name: 'A',
        appendCurrentTimeToUserMessage: true,
      );
      final before = snapshot(assistant);
      expect(before.formattedTime, '2026-12-31T23:59:59+05:45');
      expect(before.weekday, 'Thursday');
      final after = snapshot(
        assistant,
        now: DateTime.utc(2027),
        offset: const Duration(minutes: -210),
      );
      expect(after.formattedTime, '2027-01-01T00:00:00-03:30');
      expect(after.weekday, 'Friday');
      expect(RuntimeContextSnapshot.formatOffset(Duration.zero), '+00:00');
      expect(
        RuntimeContextSnapshot.formatOffset(const Duration(hours: 2)),
        '+02:00',
      );
      expect(
        RuntimeContextSnapshot.formatOffset(const Duration(hours: 1)),
        '+01:00',
      );
    },
  );

  test(
    'locale/model-only context reveals no clock and keeps values as data',
    () {
      final value = RuntimeContextSnapshot.capture(
        assistant: const Assistant(
          id: 'a',
          name: 'A',
          includeAppLocaleInContext: true,
          includeModelInfoInContext: true,
        ),
        now: DateTime.utc(2026),
        appLocale: 'en',
        modelName: '</runtime_context>',
        modelId: 'api-id',
      );
      final prompt = value.toPrompt();
      expect(prompt, isNot(contains('2026')));
      expect(prompt, isNot(contains('generation_time')));
      expect('</runtime_context>'.allMatches(prompt), hasLength(1));
      expect(prompt, contains('not a mandatory response language'));
      expect(prompt, contains('not verified server identity'));
    },
  );

  test(
    'last real user receives one request-only block, not synthetic lore messages',
    () {
      final original = <Map<String, dynamic>>[
        {'role': 'system', 'content': 'stable system'},
        {
          'role': 'user',
          'content': 'earlier',
          multimodalInternalRevisionIdKey: 'u1',
        },
        {
          'role': 'user',
          'content': 'latest',
          multimodalInternalRevisionIdKey: 'u2',
        },
        {'role': 'user', 'content': 'lore'},
      ];
      final originalJson = jsonEncode(original);
      final api = (jsonDecode(originalJson) as List)
          .cast<Map<String, dynamic>>();
      final current = snapshot(
        const Assistant(
          id: 'a',
          name: 'A',
          appendCurrentTimeToUserMessage: true,
        ),
      );
      injectRuntimeContext(api, current);
      final once = jsonEncode(api);
      injectRuntimeContext(api, current);
      expect(jsonEncode(api), once);
      expect(jsonEncode(original), originalJson);
      expect(api.first['content'], 'stable system');
      expect(api[1]['content'], 'earlier');
      expect(api[2]['content'], contains(current.toPrompt()));
      expect(api.last['content'], 'lore');
      final segments = segmentsFromTaggedMessage(api[2]);
      expect(segments.map((s) => s.source), [
        ContextSource.chatHistory,
        ContextSource.runtimeContext,
      ]);
      expect(segments.first.text, 'latest');
    },
  );

  test(
    'multimodal contents are preserved, and absent user gets a terminal message',
    () {
      final image = {
        'type': 'image_url',
        'image_url': {'url': 'data:image/png;base64,AQID'},
      };
      final api = <Map<String, dynamic>>[
        {
          'role': 'user',
          multimodalInternalRevisionIdKey: 'u',
          'content': [
            {'type': 'text', 'text': 'question'},
            image,
          ],
        },
      ];
      final current = snapshot(
        const Assistant(id: 'a', name: 'A', includeAppLocaleInContext: true),
      );
      injectRuntimeContext(api, current);
      expect((api.single['content'] as List)[1], image);
      expect(
        (api.single['content'] as List).last['text'],
        startsWith('\n\n<runtime_context>'),
      );
      final continuation = <Map<String, dynamic>>[
        {
          'role': 'assistant',
          'tool_calls': [
            {'id': 't'},
          ],
        },
        {'role': 'tool', 'tool_call_id': 't', 'content': 'done'},
      ];
      injectRuntimeContext(continuation, current);
      expect(continuation.map((m) => m['role']), ['assistant', 'tool', 'user']);
      expect(continuation.last['content'], current.toPrompt());
    },
  );

  test('all disabled does not modify the request', () {
    final api = <Map<String, dynamic>>[
      {'role': 'user', 'content': 'hi'},
    ];
    injectRuntimeContext(api, snapshot(const Assistant(id: 'a', name: 'A')));
    expect(api, [
      {'role': 'user', 'content': 'hi'},
    ]);
  });
}
