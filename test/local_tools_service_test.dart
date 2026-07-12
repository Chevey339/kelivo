import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/core/models/assistant.dart';
import 'package:Cuplivo/features/home/services/local_tools_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Assistant local tools', () {
    final localToolsAssistant = Assistant(
      id: 'a1',
      name: 'Assistant',
      localToolIds: [
        LocalToolNames.timeInfo,
        LocalToolNames.clipboard,
        LocalToolNames.textToSpeech,
        LocalToolNames.askUser,
      ],
    );

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('assistant defaults to no local tools', () {
      final assistant = Assistant(id: 'a1', name: 'Assistant');

      expect(assistant.localToolIds, isEmpty);
    });

    test('assistant defaults to web search disabled', () {
      final assistant = Assistant(id: 'a1', name: 'Assistant');

      expect(assistant.searchEnabled, isFalse);
    });

    test('assistant json keeps missing local tools disabled', () {
      final assistant = Assistant.fromJson(const {
        'id': 'a1',
        'name': 'Assistant',
      });

      expect(assistant.localToolIds, isEmpty);
    });

    test('assistant json keeps missing web search disabled', () {
      final assistant = Assistant.fromJson(const {
        'id': 'a1',
        'name': 'Assistant',
      });

      expect(assistant.searchEnabled, isFalse);
    });

    test('assistant json round trips enabled web search', () {
      final assistant = Assistant(
        id: 'a1',
        name: 'Assistant',
        searchEnabled: true,
      );

      final decoded = Assistant.fromJson(assistant.toJson());

      expect(decoded.searchEnabled, isTrue);
    });

    test('assistant json round trips enabled local tools', () {
      final assistant = Assistant(
        id: 'a1',
        name: 'Assistant',
        localToolIds: [LocalToolNames.timeInfo, LocalToolNames.clipboard],
      );

      final decoded = Assistant.fromJson(assistant.toJson());

      expect(decoded.localToolIds, const [
        LocalToolNames.timeInfo,
        LocalToolNames.clipboard,
      ]);
    });

    test(
      'builds enabled local tool definitions only when model supports tools',
      () {
        final disabled = LocalToolsService.buildToolDefinitions(
          assistant: Assistant(id: 'a2', name: 'Assistant'),
          supportsTools: true,
        );
        final unsupported = LocalToolsService.buildToolDefinitions(
          assistant: localToolsAssistant,
          supportsTools: false,
        );
        final enabled = LocalToolsService.buildToolDefinitions(
          assistant: localToolsAssistant,
          supportsTools: true,
        );

        expect(disabled, isEmpty);
        expect(unsupported, isEmpty);
        expect(enabled.map((tool) => tool['function']['name']), const [
          LocalToolNames.timeInfo,
          LocalToolNames.clipboard,
          LocalToolNames.textToSpeech,
          LocalToolNames.askUser,
        ]);
        expect(enabled.first['function']['parameters']['properties'], isEmpty);
        expect(
          enabled[1]['function']['parameters']['properties']['action']['enum'],
          const ['read', 'write'],
        );
        final ttsParameters = enabled[2]['function']['parameters'];
        expect(ttsParameters['required'], const ['text']);
        expect(ttsParameters['properties']['text']['type'], 'string');
        final askUserParameters = enabled[3]['function']['parameters'];
        expect(askUserParameters['required'], const ['questions']);
        final questionSchema =
            askUserParameters['properties']['questions']['items'];
        expect(questionSchema['required'], const ['id', 'question']);
        expect(questionSchema['properties']['type']['enum'], const [
          'single',
          'multi',
        ]);
        expect(
          questionSchema['properties']['options']['items']['type'],
          'string',
        );
      },
    );

    test('text to speech call starts playback and returns success', () async {
      final spokenTexts = <String>[];

      final result = await LocalToolsService.tryHandleToolCall(
        LocalToolNames.textToSpeech,
        const {'text': 'Read this aloud.'},
        localToolsAssistant,
        onSpeakText: (text) async {
          spokenTexts.add(text);
        },
      );

      expect(spokenTexts, const ['Read this aloud.']);
      expect(result, isNotNull);
      expect(jsonDecode(result!) as Map<String, dynamic>, {'success': true});
    });

    test('text to speech requires non-empty text', () async {
      expect(
        () => LocalToolsService.tryHandleToolCall(
          LocalToolNames.textToSpeech,
          const {},
          localToolsAssistant,
          onSpeakText: (_) async {},
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => LocalToolsService.tryHandleToolCall(
          LocalToolNames.textToSpeech,
          const {'text': '   '},
          localToolsAssistant,
          onSpeakText: (_) async {},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'time info call returns local date, weekday, time, timezone fields',
      () async {
        final result = await LocalToolsService.tryHandleToolCall(
          LocalToolNames.timeInfo,
          const {},
          localToolsAssistant,
        );

        expect(result, isNotNull);
        final payload = jsonDecode(result!) as Map<String, dynamic>;
        expect(payload['year'], isA<int>());
        expect(payload['month'], isA<int>());
        expect(payload['day'], isA<int>());
        expect(payload['weekday'], isA<String>());
        expect(payload['weekday_en'], isA<String>());
        expect(payload['weekday_index'], inInclusiveRange(1, 7));
        expect(payload['date'], isA<String>());
        expect(payload['time'], isA<String>());
        expect(payload['datetime'], isA<String>());
        expect(payload['timezone'], isA<String>());
        expect(payload['utc_offset'], isA<String>());
        expect(payload['timestamp_ms'], isA<int>());
      },
    );

    test(
      'clipboard read returns plain text from the device clipboard',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.getData') {
                return const <String, dynamic>{'text': 'clipboard text'};
              }
              fail('Unexpected platform call: ${call.method}');
            });

        final result = await LocalToolsService.tryHandleToolCall(
          LocalToolNames.clipboard,
          const {'action': 'read'},
          localToolsAssistant,
        );

        expect(result, isNotNull);
        expect(jsonDecode(result!) as Map<String, dynamic>, {
          'text': 'clipboard text',
        });
      },
    );

    test('clipboard write updates the device clipboard', () async {
      String? writtenText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              writtenText =
                  (call.arguments as Map<Object?, Object?>)['text'] as String?;
              return null;
            }
            fail('Unexpected platform call: ${call.method}');
          });

      final result = await LocalToolsService.tryHandleToolCall(
        LocalToolNames.clipboard,
        const {'action': 'write', 'text': 'next clipboard'},
        localToolsAssistant,
      );

      expect(writtenText, 'next clipboard');
      expect(result, isNotNull);
      expect(jsonDecode(result!) as Map<String, dynamic>, {
        'success': true,
        'text': 'next clipboard',
      });
    });

    test('clipboard write requires text', () async {
      expect(
        () => LocalToolsService.tryHandleToolCall(
          LocalToolNames.clipboard,
          const {'action': 'write'},
          localToolsAssistant,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('disabled or unknown local tool calls are not handled', () async {
      expect(
        await LocalToolsService.tryHandleToolCall(
          LocalToolNames.timeInfo,
          const {},
          Assistant(id: 'a1', name: 'Assistant'),
        ),
        isNull,
      );
      expect(
        await LocalToolsService.tryHandleToolCall(
          'unknown_local_tool',
          const {},
          localToolsAssistant,
        ),
        isNull,
      );
    });
  });
}
