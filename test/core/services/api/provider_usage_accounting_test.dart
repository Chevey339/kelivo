import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/token_usage.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/providers/claude_official.dart';
import 'package:Kelivo/core/services/api/providers/google_common.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_decoder.dart';
import 'package:Kelivo/core/services/api/providers/google/google_decoder.dart';
import 'package:Kelivo/core/services/api/providers/openai/chat_completions_decoder.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_decoder.dart';
import 'package:Kelivo/core/services/api/stream/sse_event.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/core/utils/model_cost.dart';
import 'package:Kelivo/features/home/services/context_assembly.dart';

void main() {
  SseEvent event(Map<String, dynamic> payload) =>
      SseEvent(data: jsonEncode(payload));
  final reply = ChatMessage(
    role: 'assistant',
    content: 'reply',
    reasoningText: 'thoughts',
    conversationId: 'c',
  );

  test('an empty usage object is missing data, not an explicit zero round', () {
    const previous = TokenUsage(
      promptTokens: 100,
      completionTokens: 20,
      reasoningTokens: 10,
    );
    final claude = ClaudeStreamDecoder(initialUsage: previous);
    claude.accept(
      event({
        'type': 'message_start',
        'message': {'usage': {}},
      }),
    );
    final google = GoogleStreamDecoder(initialUsage: previous);
    google.accept(event({'usageMetadata': {}}));
    final chat = ChatCompletionsStreamDecoder(initialUsage: previous);
    chat.accept(event({'usage': {}}));
    final responses = ResponsesStreamDecoder(initialUsage: previous);
    responses.accept(
      event({
        'type': 'response.completed',
        'response': {'usage': {}},
      }),
    );
    for (final current in [
      claude.usage,
      google.usage,
      chat.usage,
      responses.usage,
    ]) {
      expect(current, same(previous));
    }
    expect(const TokenUsage().hasReportedTokens, isFalse);
    expect(const TokenUsage(promptTokens: 0).hasReportedTokens, isTrue);
  });

  for (final transport in ['claude', 'vertex', 'gemini']) {
    test('$transport non-stream tool rounds replace prior usage', () async {
      final gemini = transport == 'gemini';
      final vertex = transport == 'vertex';
      var requests = 0;
      final client = MockClient((request) async {
        final first = requests++ == 0;
        final body = gemini
            ? {
                'candidates': [
                  {
                    'content': {
                      'role': 'model',
                      'parts': [
                        if (first)
                          {
                            'functionCall': {'name': 'lookup', 'args': {}},
                          }
                        else
                          {'text': 'done'},
                      ],
                    },
                    'finishReason': 'STOP',
                  },
                ],
                'usageMetadata': first
                    ? {
                        'promptTokenCount': 100,
                        'candidatesTokenCount': 20,
                        'thoughtsTokenCount': 500,
                        'totalTokenCount': 620,
                      }
                    : {
                        'promptTokenCount': 200,
                        'candidatesTokenCount': 30,
                        'thoughtsTokenCount': 0,
                        'totalTokenCount': 230,
                      },
              }
            : {
                'id': 'reply-$requests',
                'type': 'message',
                'role': 'assistant',
                'content': [
                  if (first)
                    {
                      'type': 'tool_use',
                      'id': 'call-1',
                      'name': 'lookup',
                      'input': {},
                    }
                  else
                    {'type': 'text', 'text': 'done'},
                ],
                'stop_reason': first ? 'tool_use' : 'end_turn',
                'usage': first
                    ? {
                        'input_tokens': 1000,
                        'output_tokens': 100,
                        'cache_creation_input_tokens': 3000,
                      }
                    : {
                        'input_tokens': 2000,
                        'output_tokens': 100,
                        'cache_read_input_tokens': 3000,
                        'cache_creation_input_tokens': 0,
                      },
              };
        return http.Response(jsonEncode(body), 200);
      });
      addTearDown(client.close);
      final config = ProviderConfig(
        id: 'Test',
        enabled: true,
        name: 'Test',
        apiKey: 'k',
        providerType: transport == 'claude'
            ? ProviderKind.claude
            : ProviderKind.google,
        baseUrl: vertex
            ? 'https://aiplatform.googleapis.com'
            : 'https://example.test',
        vertexAI: vertex,
        projectId: 'test-project',
        location: 'global',
      );
      const tools = [
        {
          'type': 'function',
          'function': {
            'name': 'lookup',
            'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
          },
        },
      ];
      Future<String> execute(
        String name,
        Map<String, dynamic> arguments, {
        String? toolCallId,
      }) async => 'ok';
      final send = transport == 'claude' ? sendClaudeStream : sendGoogleStream;
      final result = StreamChunkHandler.collect(
        await send(
          client,
          config,
          gemini ? 'gemini-2.5-flash' : 'claude-sonnet-4-5',
          const [
            {'role': 'user', 'content': 'look up'},
          ],
          tools: tools,
          onToolCall: execute,
          stream: false,
        ).toList(),
      );
      expect(requests, 2);
      expect(result.usage!.cacheWriteTokens, 0);
      expect(result.usage!.reasoningTokens, 0);
      expect(result.usage!.promptTokens, gemini ? 200 : 5000);
      expect(result.usage!.completionTokens, gemini ? 30 : 100);
      expect(result.totalUsage!.promptTokens, gemini ? 300 : 9000);
      expect(result.totalUsage!.completionTokens, gemini ? 550 : 200);
      expect(result.totalUsage!.reasoningTokens, gemini ? 500 : 0);
      expect(result.totalUsage!.cacheWriteTokens, gemini ? 0 : 3000);
    });
  }

  test(
    'Claude partial updates retain missing counters and new rounds clear zeros',
    () {
      final first = ClaudeStreamDecoder();
      first.accept(
        event({
          'type': 'message_start',
          'message': {
            'usage': {
              'input_tokens': 1000,
              'output_tokens': 100,
              'cache_creation_input_tokens': 3000,
            },
          },
        }),
      );
      first.accept(
        event({
          'type': 'message_delta',
          'usage': {'output_tokens': 120},
        }),
      );
      expect(first.usage!.promptTokens, 4000);
      expect(first.usage!.cacheWriteTokens, 3000);
      expect(first.usage!.totalTokens, 4120);

      final second = ClaudeStreamDecoder(initialUsage: first.usage);
      final handler = StreamChunkHandler()..handle(Usage(first.usage!));
      for (final chunk
          in second
              .accept(
                event({
                  'type': 'message_start',
                  'message': {
                    'usage': {
                      'input_tokens': 2000,
                      'output_tokens': 100,
                      'cache_read_input_tokens': 3000,
                      'cache_creation_input_tokens': 0,
                    },
                  },
                }),
              )
              .chunks) {
        handler.handle(chunk);
      }
      expect(handler.usage!.cacheWriteTokens, 0);
      expect(handler.usage!.promptTokens, 5000);
      expect(
        estimateModelCost(
          handler.usage!,
          const ModelPricing(
            input: 1,
            output: 2,
            cacheRead: 0.1,
            cacheWrite: 1.25,
          ),
        )!.amount,
        closeTo(0.0025, 1e-12),
      );

      second.accept(
        event({
          'type': 'message_delta',
          'usage': {
            'input_tokens': 0,
            'cache_read_input_tokens': 0,
            'output_tokens': 0,
          },
        }),
      );
      expect(second.usage!.promptTokens, 0);
      expect(second.usage!.completionTokens, 0);
      expect(second.usage!.totalTokens, 0);
    },
  );

  test(
    'Gemini partial metadata keeps thoughts but a later round can omit or zero them',
    () {
      final first = GoogleStreamDecoder();
      first.accept(
        event({
          'usageMetadata': {
            'promptTokenCount': 100,
            'thoughtsTokenCount': 500,
            'totalTokenCount': 600,
          },
        }),
      );
      first.accept(
        event({
          'usageMetadata': {'candidatesTokenCount': 20},
        }),
      );
      expect(first.usage!.completionTokens, 520);
      expect(first.usage!.totalTokens, 620);
      for (final includeZero in [false, true]) {
        final second = GoogleStreamDecoder(initialUsage: first.usage);
        final handler = StreamChunkHandler()..handle(Usage(first.usage!));
        for (final chunk
            in second
                .accept(
                  event({
                    'usageMetadata': {
                      'promptTokenCount': 200,
                      'candidatesTokenCount': 30,
                      if (includeZero) 'thoughtsTokenCount': 0,
                    },
                  }),
                )
                .chunks) {
          handler.handle(chunk);
        }
        expect(handler.usage!.reasoningTokens, 0);
        expect(handler.usage!.completionTokens, 30);
        expect(
          contextTokensAfterTurn(
            usage: handler.usage!,
            assistantMessage: reply,
            replay: ReasoningReplayPolicy.none,
          ),
          230,
        );
      }
      first.accept(
        event({
          'usageMetadata': {'thoughtsTokenCount': 0},
        }),
      );
      expect(first.usage!.reasoningTokens, 0);
      expect(first.usage!.completionTokens, 20);
      expect(first.usage!.totalTokens, 120);
    },
  );

  test(
    'OpenAI transports separate within-round patches from new-round snapshots',
    () {
      const previous = TokenUsage(
        promptTokens: 100,
        completionTokens: 520,
        reasoningTokens: 500,
        cachedTokens: 30,
      );
      for (final responses in [false, true]) {
        final decoder = responses
            ? ResponsesStreamDecoder(initialUsage: previous)
            : ChatCompletionsStreamDecoder(initialUsage: previous);
        Map<String, dynamic> payload(Map<String, dynamic> usage) => responses
            ? {
                'type': 'response.completed',
                'response': {'usage': usage},
              }
            : {'usage': usage};
        final handler = StreamChunkHandler()..handle(Usage(previous));
        for (final usage
            in responses
                ? [
                    {'input_tokens': 200, 'output_tokens': 0},
                  ]
                : [
                    {'prompt_tokens': 200, 'completion_tokens': 30},
                    {'completion_tokens': 0},
                  ]) {
          final chunks = responses
              ? (decoder as ResponsesStreamDecoder)
                    .accept(event(payload(usage)))
                    .chunks
              : (decoder as ChatCompletionsStreamDecoder)
                    .accept(event(payload(usage)))
                    .chunks;
          for (final chunk in chunks.whereType<Usage>()) {
            handler.handle(chunk);
          }
          if (!responses) {
            handler.handle(
              Usage((decoder as ChatCompletionsStreamDecoder).usage!),
            );
          }
        }
        expect(handler.usage!.promptTokens, 200);
        expect(handler.usage!.completionTokens, 0);
        expect(handler.usage!.reasoningTokens, 0);
        expect(handler.usage!.cachedTokens, 0);
        expect(handler.usage!.totalTokens, 200);
      }
    },
  );

  test('Claude cache reads and writes count once in context and cost', () {
    final usage = claudeUsageFromMap({
      'input_tokens': 1000,
      'output_tokens': 100,
      'cache_read_input_tokens': 2000,
      'cache_creation_input_tokens': 3000,
    });
    expect(usage.promptTokens, 6000);
    expect(usage.totalTokens, 6100);
    expect(
      contextTokensAfterTurn(
        usage: const TokenUsage().merge(usage),
        assistantMessage: reply,
        replay: ReasoningReplayPolicy.none,
      ),
      6100,
    );
    expect(
      estimateModelCost(
        usage,
        const ModelPricing(
          input: 1,
          output: 2,
          cacheRead: 0.1,
          cacheWrite: 1.25,
        ),
      )!.amount,
      closeTo(0.00515, 1e-12),
    );
  });

  test('a fully cached Claude prompt is still a nonzero context anchor', () {
    final usage = claudeUsageFromMap({
      'input_tokens': 0,
      'cache_read_input_tokens': 6000,
      'output_tokens': 100,
    });
    expect(usage.promptTokens, 6000);
    expect(usage.totalTokens, 6100);
  });

  test(
    'Gemini thoughts are billed but only count in context when replayed',
    () {
      final usage = const TokenUsage().merge(
        googleUsageFromMetadata({
          'promptTokenCount': 100,
          'candidatesTokenCount': 20,
          'thoughtsTokenCount': 500,
          'totalTokenCount': 620,
        }),
      );
      expect(usage.completionTokens, 520);
      expect(usage.totalTokens, 620);
      expect(
        estimateModelCost(
          usage,
          const ModelPricing(input: 0, output: 1),
        )!.amount,
        closeTo(0.00052, 1e-12),
      );
      for (final (replay, expected) in [
        (ReasoningReplayPolicy.none, 120),
        (ReasoningReplayPolicy.all, 620),
      ]) {
        expect(
          contextTokensAfterTurn(
            usage: usage,
            assistantMessage: reply,
            replay: replay,
          ),
          expected,
        );
      }
    },
  );
}
