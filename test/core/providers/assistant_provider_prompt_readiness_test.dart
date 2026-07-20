import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/services/chat/prompt_transformer.dart';

import '../../support/business_preferences_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BusinessPreferencesTestHarness harness;
  late BusinessPreferencesTestSession session;

  setUp(() async {
    harness = await BusinessPreferencesTestHarness.create();
    session = await harness.open();
  });

  tearDown(() => harness.dispose());

  test(
    'restores prompt templates synchronously from the startup snapshot',
    () async {
      await session.preferences.setString(
        'assistants_v1',
        jsonEncode(const [
          {
            'id': 'assistant-with-prompts',
            'name': 'Prompt Assistant',
            'systemPrompt': 'Current: {cur_datetime}',
            'messageTemplate': '{{ date }} {{ time }} {{ message }}',
          },
        ]),
      );
      await session.preferences.setString(
        'current_assistant_id_v1',
        'assistant-with-prompts',
      );

      final provider = AssistantProvider(preferences: session.preferences);

      expect(provider.currentAssistantId, 'assistant-with-prompts');
      expect(
        provider.currentAssistant?.systemPrompt,
        'Current: {cur_datetime}',
      );
      expect(
        provider.currentAssistant?.messageTemplate,
        '{{ date }} {{ time }} {{ message }}',
      );
      expect(
        PromptTransformer.replacePlaceholders(
          provider.currentAssistant!.systemPrompt,
          const {'{cur_datetime}': '2026-07-19 09:30'},
        ),
        'Current: 2026-07-19 09:30',
      );
      expect(
        PromptTransformer.applyMessageTemplate(
          provider.currentAssistant!.messageTemplate,
          role: 'user',
          message: 'hello',
          now: DateTime(2026, 7, 19, 9, 30),
        ),
        '2026-07-19 09:30 hello',
      );
      await provider.loaded;
    },
  );

  test('ignores a non-string persisted current assistant id', () async {
    await session.preferences.setString(
      'assistants_v1',
      jsonEncode(const [
        {'id': 'assistant-a', 'name': 'Assistant A'},
      ]),
    );
    await session.preferences.setBool('current_assistant_id_v1', true);

    final provider = AssistantProvider(preferences: session.preferences);

    await expectLater(provider.loaded, completes);
    expect(provider.currentAssistantId, isNull);
    expect(provider.currentAssistant?.id, 'assistant-a');
  });
}
