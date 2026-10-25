import 'package:Kelivo/core/services/api/native_input_attachments.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/services/api/providers/openai/chat_completions_api.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_tool_transcript.dart';
import 'package:flutter_test/flutter_test.dart';

const _extraContent = <String, dynamic>{
  'google': <String, dynamic>{'thought_signature': 'sig-create-memory'},
};

final _nativeInputs = NativeInputAttachments(
  config: ProviderConfig(
    id: 'test',
    enabled: true,
    name: 'test',
    apiKey: '',
    baseUrl: 'https://api.example.com/v1',
  ),
  spec: ModelSpec(id: 'test', displayName: 'test'),
  protocol: NativeInputProtocol.chatCompletions,
);

void main() {
  test('same-turn follow-up echoes extra_content from streamed tool acc', () {
    final calls = clientToolCallsFromChatAcc(<dynamic, dynamic>{
      0: <String, dynamic>{
        'id': 'call_mem',
        'name': 'create_memory',
        'args': '{"content":"note"}',
        'extra_content': _extraContent,
      },
    });

    expect(openaiToolCallMaps(calls).single['extra_content'], _extraContent);
  });

  test('same-turn follow-up echoes extra_content from a complete message', () {
    final calls = openaiCallsFromCompletionMessage(<String, dynamic>{
      'tool_calls': [
        <String, dynamic>{
          'id': 'call_mem',
          'type': 'function',
          'extra_content': _extraContent,
          'function': <String, dynamic>{
            'name': 'create_memory',
            'arguments': '{"content":"note"}',
          },
        },
      ],
    });

    expect(openaiToolCallMaps(calls).single['extra_content'], _extraContent);
  });

  test('copyChatCompletionMessage lifts extra_content from tool metadata', () {
    final copied = copyChatCompletionMessage(<String, dynamic>{
      'role': 'assistant',
      'content': '\n\n',
      'tool_calls': [
        <String, dynamic>{
          'id': 'call_mem',
          'type': 'function',
          'function': <String, dynamic>{
            'name': 'create_memory',
            'arguments': '{"content":"note"}',
          },
          'metadata': <String, dynamic>{
            'google': <String, dynamic>{'extra_content': _extraContent},
          },
        },
      ],
    });
    final toolCall = (copied['tool_calls'] as List).single as Map;

    expect(toolCall['extra_content'], _extraContent);
    expect(toolCall.containsKey('metadata'), isFalse);
  });

  test(
    'copyChatCompletionMessage keeps extra_content already on the tool call',
    () {
      final copied = copyChatCompletionMessage(<String, dynamic>{
        'role': 'assistant',
        'content': '\n\n',
        'tool_calls': [
          <String, dynamic>{
            'id': 'call_mem',
            'type': 'function',
            'extra_content': _extraContent,
            'function': <String, dynamic>{
              'name': 'create_memory',
              'arguments': '{}',
            },
          },
        ],
      });
      final toolCall = (copied['tool_calls'] as List).single as Map;

      expect(toolCall['extra_content'], _extraContent);
    },
  );

  test(
    'history replay puts extra_content on the Chat Completions wire',
    () async {
      final messages = await buildOpenAIChatCompletionMessages(
        [
          <String, dynamic>{'role': 'user', 'content': 'remember this'},
          <String, dynamic>{
            'role': 'assistant',
            'content': '\n\n',
            'tool_calls': [
              <String, dynamic>{
                'id': 'call_mem',
                'type': 'function',
                'function': <String, dynamic>{
                  'name': 'create_memory',
                  'arguments': '{"content":"note"}',
                },
                'metadata': <String, dynamic>{
                  'google': <String, dynamic>{'extra_content': _extraContent},
                },
              },
            ],
          },
          <String, dynamic>{
            'role': 'tool',
            'tool_call_id': 'call_mem',
            'name': 'create_memory',
            'content': '{"ok":true}',
            'metadata': <String, dynamic>{
              'google': <String, dynamic>{'extra_content': _extraContent},
            },
          },
          <String, dynamic>{
            'role': 'user',
            'content': 'what did you remember?',
          },
        ],
        nativeInputs: _nativeInputs,
        canImageInput: false,
        allowRemoteImages: false,
        reasoningReplay: ReasoningReplayPolicy.none,
      );

      final assistant = messages.firstWhere(
        (message) => message['tool_calls'] is List,
      );
      final toolCall = (assistant['tool_calls'] as List).single as Map;

      expect(toolCall['extra_content'], _extraContent);
      expect(toolCall.containsKey('metadata'), isFalse);
      expect(
        messages.every((message) => !message.containsKey('metadata')),
        isTrue,
      );
    },
  );

  test(
    'history replay keeps extra_content whenever a signature is present',
    () async {
      final messages = await buildOpenAIChatCompletionMessages(
        [
          <String, dynamic>{'role': 'user', 'content': 'remember this'},
          <String, dynamic>{
            'role': 'assistant',
            'content': '\n\n',
            'tool_calls': [
              <String, dynamic>{
                'id': 'call_mem',
                'type': 'function',
                'function': <String, dynamic>{
                  'name': 'create_memory',
                  'arguments': '{"content":"note"}',
                },
                'metadata': <String, dynamic>{
                  'google': <String, dynamic>{'extra_content': _extraContent},
                },
              },
            ],
          },
          <String, dynamic>{
            'role': 'tool',
            'tool_call_id': 'call_mem',
            'name': 'create_memory',
            'content': '{"ok":true}',
            'metadata': <String, dynamic>{
              'google': <String, dynamic>{'extra_content': _extraContent},
            },
          },
        ],
        nativeInputs: _nativeInputs,
        canImageInput: false,
        allowRemoteImages: false,
        reasoningReplay: ReasoningReplayPolicy.none,
      );

      final assistant = messages.firstWhere(
        (message) => message['tool_calls'] is List,
      );
      final toolCall = (assistant['tool_calls'] as List).single as Map;

      expect(toolCall['extra_content'], _extraContent);
      expect(
        messages.every((message) => !message.containsKey('metadata')),
        isTrue,
      );
    },
  );

  test('does not invent extra_content when the provider never sent one', () {
    final calls = openaiCallsFromCompletionMessage(<String, dynamic>{
      'tool_calls': [
        <String, dynamic>{
          'id': 'call_1',
          'type': 'function',
          'function': <String, dynamic>{'name': 'lookup', 'arguments': '{}'},
        },
      ],
    });
    expect(
      openaiToolCallMaps(calls).single.containsKey('extra_content'),
      isFalse,
    );

    final copied = copyChatCompletionMessage(<String, dynamic>{
      'role': 'assistant',
      'content': '\n\n',
      'tool_calls': [
        <String, dynamic>{
          'id': 'call_1',
          'type': 'function',
          'function': <String, dynamic>{'name': 'lookup', 'arguments': '{}'},
        },
      ],
    });
    expect(
      ((copied['tool_calls'] as List).single as Map).containsKey(
        'extra_content',
      ),
      isFalse,
    );
  });
}
