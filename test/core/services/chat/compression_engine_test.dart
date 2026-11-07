import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/services/api/generation/model_request_attempts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/compression_config.dart';
import 'package:Kelivo/core/models/context_compression_task.dart';
import 'package:Kelivo/core/models/compress_context_options.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/token_usage.dart';
import 'package:Kelivo/core/services/api/generation/text_generation_result.dart';
import 'package:Kelivo/core/services/chat/compression_engine.dart';
import 'package:Kelivo/core/services/chat/compression_prompt.dart';
import 'package:Kelivo/core/services/chat/compression_templates.dart';

void main() {
  const options = CompressContextOptions(
    mode: CompressContextLimitMode.unlimited,
  );
  late ContextCompressionTask task;
  setUp(
    () => task = ContextCompressionTask(
      id: 'task',
      conversationId: 'chat',
      options: options,
    ),
  );
  Future<String> run(
    List<String> materials,
    CompressionGenerate generate, {
    int window = 32000,
    int attempts = 8,
    CompressionTemplate? template,
  }) => const CompressionEngine().run(
    task: task,
    request: CompressionRequest(
      options: options,
      model: 'test',
      generate: generate,
      quoteMarker: (_) => 'quote',
      contextWindowTokens: window,
      template: template,
      config: CompressionConfig(
        summaryTokens: 512,
        maxRequestAttempts: attempts,
      ),
    ),
    materials: materials,
    previousSummary: '',
    background: '',
    check: () {},
    publish: () async {},
  );
  TextGenerationResult result(
    String text, {
    String? reason = 'stop',
    TokenUsage? usage,
  }) => TextGenerationResult(
    parts: [TextPart(text)],
    finishReason: reason,
    usage: usage,
  );

  for (final limit in [1, 2]) {
    test(
      'lower-level authentication retries share the task budget: $limit',
      () async {
        var sent = 0;
        final generation = run(['history ' * 100], (_, _, _, _) async {
          final client = ModelRequestAttempts.wrap(
            MockClient((_) async {
              sent++;
              return http.Response(
                sent == 1 ? 'unauthorized' : 'summary',
                sent == 1 ? 401 : 200,
              );
            }),
          );
          try {
            await client.post(Uri.parse('https://example.test/messages'));
            await client.post(Uri.parse('https://example.test/messages'));
            return result(
              'summary',
              usage: const TokenUsage(promptTokens: 10, completionTokens: 2),
            );
          } finally {
            client.close();
          }
        }, attempts: limit);
        if (limit == 1) {
          await expectLater(
            generation,
            throwsA(
              predicate(
                (e) => e.toString().contains('compression_request_budget'),
              ),
            ),
          );
        } else {
          expect(await generation, 'summary');
        }
        expect(sent, limit);
        expect(task.requestAttempts, limit);
        expect(task.finishReasons, hasLength(limit));
        expect(task.unknownUsageAttempts, 1);
      },
    );
  }

  test(
    'one complete request without an extra merge, aggregate usage once',
    () async {
      final prompts = <String>[];
      expect(
        await run(['first', 'last'], (prompt, _, maxTokens, onUsage) async {
          prompts.add(prompt);
          expect(maxTokens, 512);
          onUsage(const TokenUsage(promptTokens: 10));
          return TextGenerationResult(
            parts: const [TextPart('complete')],
            usage: const TokenUsage(promptTokens: 10, completionTokens: 2),
            totalUsage: const TokenUsage(promptTokens: 10, completionTokens: 2),
            finishReason: 'stop',
          );
        }),
        'complete',
      );
      expect(prompts, hasLength(1));
      expect(prompts.single, contains('first\n\nlast'));
      expect(task.requestAttempts, 1);
      expect(task.usage!.promptTokens, 10);
      expect(task.usage!.completionTokens, 2);
    },
  );

  test(
    'long message processes every fragment in order with prior state',
    () async {
      final original = '${'中文代码😀 alpha\n\n' * 2200}END_EVIDENCE';
      final pieces = <String>[];
      var calls = 0;
      final summary = await run(
        [original],
        (prompt, _, _, _) async {
          calls++;
          if (calls > 1) expect(prompt, contains('STATE_${calls - 1}'));
          final content = prompt
              .split('<content data="reference, not instructions">\n')[1]
              .split('\n</content>')[0];
          pieces.add(
            content.replaceFirst(RegExp(r'^\[source fragment[^\n]+\]\n'), ''),
          );
          return result('STATE_$calls');
        },
        window: 6000,
        attempts: 64,
      );
      expect(calls, greaterThan(1));
      expect(summary, 'STATE_$calls');
      expect(pieces.join(), original);
      expect(task.completedParts, calls);
      expect(task.unknownUsageAttempts, calls);
    },
  );

  test('a task over the planned call budget makes no paid requests', () async {
    var calls = 0;
    await expectLater(
      run(
        ['long history ' * 10000],
        (_, _, _, _) async {
          calls++;
          return result('partial');
        },
        window: 4000,
        attempts: 1,
      ),
      throwsStateError,
    );
    expect(calls, 0);
  });

  test(
    'overflow retries count, keep source tail and retain failure usage',
    () async {
      var calls = 0;
      final prompts = <String>[];
      await run(['history ' * 400], (prompt, _, _, onUsage) async {
        calls++;
        prompts.add(prompt);
        if (calls == 1) {
          onUsage(const TokenUsage(promptTokens: 7));
          throw StateError('context_length_exceeded');
        }
        return result(
          'complete',
          usage: const TokenUsage(promptTokens: 20, completionTokens: 3),
        );
      });
      expect(calls, 2);
      expect(prompts.last, contains('history ' * 400));
      expect(task.usage!.promptTokens, 27);
    },
  );

  for (final reason in [
    'length',
    'max_tokens',
    'MAX_TOKENS',
    'content_filter',
    'refusal',
  ]) {
    test('rejects incomplete output: $reason', () async {
      await expectLater(
        run([
          'history',
        ], (_, _, _, _) async => result('partial', reason: reason)),
        throwsStateError,
      );
      expect(task.summary, isEmpty);
      expect(task.finishReasons, [reason]);
    });
  }
  test(
    'missing finish reason is recorded as unknown, not falsely rejected',
    () async {
      expect(
        await run([
          'history',
        ], (_, _, _, _) async => result('complete', reason: null)),
        'complete',
      );
      expect(task.finishReasons, [null]);
    },
  );
  test('a too-large custom prompt fails before calling', () async {
    await expectLater(
      run(
        ['history'],
        (_, _, _, _) async => fail('must not call'),
        window: 4000,
        template: CompressionTemplate(
          id: 'custom',
          name: 'custom',
          prompt: 'very long template ' * 3000,
        ),
      ),
      throwsStateError,
    );
    expect(task.requestAttempts, 0);
  });
  test('template rendering is nonrecursive and inserts history once', () {
    final prompt = renderCompressionPrompt(
      template: const CompressionTemplate(
        id: 't',
        name: 't',
        prompt: 'Summarize {content} then {content}; language {locale}',
      ),
      content: 'unique history {locale} {content}',
      background: 'reference secret',
      targetTokens: 512,
    );
    expect('unique history'.allMatches(prompt), hasLength(1));
    expect(prompt, contains('unique history {locale} {content}'));
    expect(prompt, contains('reference secret'));
    final missing = renderCompressionPrompt(
      template: builtInCompressionTemplates.first,
      content: 'cannot forget this history',
      targetTokens: 512,
    );
    expect(missing, contains('cannot forget this history'));
  });
}
