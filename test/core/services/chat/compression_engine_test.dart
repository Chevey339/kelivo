import 'dart:async';
import 'dart:isolate';

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
import 'package:Kelivo/core/services/chat/compression_planner.dart';
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
    'total output budget is independent of the visible summary target',
    () async {
      const config = CompressionConfig(
        summaryTokens: 512,
        maxOutputTokens: 4096,
      );
      final request = CompressionRequest(
        options: options,
        model: 'reasoning-model',
        quoteMarker: (_) => 'quote',
        config: config,
        contextWindowTokens: 32000,
        generate: (prompt, _, maxTokens, _) async {
          expect(maxTokens, 4096);
          expect(prompt, contains('Target length: at most 512 tokens.'));
          return TextGenerationResult(
            parts: const [
              ReasoningPart('internal reasoning'),
              TextPart('summary'),
            ],
            usage: const TokenUsage(
              completionTokens: 3072,
              reasoningTokens: 3000,
            ),
            finishReason: 'stop',
          );
        },
      );
      final planner = CompressionPlanner(
        request: request,
        materials: ['history'],
        previousSummary: '',
        background: '',
      );
      expect(planner.inputLimit, 32000 - 4096 - 1600);
      expect(
        await const CompressionEngine().run(
          task: task,
          request: request,
          materials: ['history'],
          previousSummary: '',
          background: '',
          check: () {},
          publish: () async {},
        ),
        'summary',
      );
      expect(task.usage!.completionTokens, 3072);
      expect(task.usage!.reasoningTokens, 3000);
    },
  );

  test(
    'model output cap constrains generation and achievable summary target',
    () {
      for (final cap in [256, 2048]) {
        final planner = CompressionPlanner(
          request: CompressionRequest(
            options: options,
            model: 'limited',
            quoteMarker: (_) => 'quote',
            config: const CompressionConfig(
              summaryTokens: 512,
              maxOutputTokens: 4096,
            ),
            maxOutputTokens: cap,
            contextWindowTokens: 32000,
            generate: (_, _, _, _) async => result('summary'),
          ),
          materials: ['history'],
          previousSummary: '',
          background: '',
        );
        expect(planner.outputTokens, cap);
        expect(planner.targetTokens, cap < 512 ? cap : 512);
        expect(planner.inputLimit, 32000 - cap - 1600);
      }
    },
  );

  test(
    'reasoning-only exhaustion fails while preserving provider usage',
    () async {
      await expectLater(
        run(
          ['history'],
          (_, _, _, _) async => TextGenerationResult(
            parts: const [ReasoningPart('thinking')],
            usage: const TokenUsage(
              completionTokens: 16384,
              reasoningTokens: 16384,
            ),
            finishReason: 'max_output_tokens',
          ),
        ),
        throwsA(
          predicate(
            (e) => e.toString().contains(
              'compression_incomplete:max_output_tokens',
            ),
          ),
        ),
      );
      expect(task.summary, isEmpty);
      expect(task.usage!.completionTokens, 16384);
      expect(task.usage!.reasoningTokens, 16384);
    },
  );

  test('preflight reserves summary text without the reasoning allowance', () {
    final planner = CompressionPlanner(
      request: CompressionRequest(
        options: options,
        model: 'large-output',
        quoteMarker: (_) => 'quote',
        config: const CompressionConfig(
          summaryTokens: 512,
          maxOutputTokens: 32768,
        ),
        contextWindowTokens: 1000000,
        generate: (_, _, _, _) async => result('summary'),
      ),
      materials: ['past ' * 12000, 'next ' * 12000],
      previousSummary: '',
      background: '',
    );
    expect(planner.estimateRequests(), 2);
  });

  test('unknown model window uses 1M for preview and execution', () async {
    final background = '背景设定 ' * 7000;
    final materials = ['需要压缩的历史内容'];
    var sent = '';
    CompressionRequest request({int? window}) => CompressionRequest(
      options: options,
      model: '[次][抗截断]gemini-3.8-flash',
      quoteMarker: (_) => 'quote',
      contextWindowTokens: window,
      locale: 'zh',
      template: builtInCompressionTemplates.firstWhere(
        (t) => t.id == 'roleplay',
      ),
      generate: (prompt, _, _, _) async {
        sent = prompt;
        return result('完整摘要');
      },
    );
    CompressionPlanner planner({int? window}) => CompressionPlanner(
      request: request(window: window),
      materials: materials,
      previousSummary: '',
      background: background,
    );
    final unknown = planner();
    expect(unknown.inputLimit, planner(window: 1048576).inputLimit);
    expect(
      planner(window: 2097152).inputLimit,
      greaterThan(unknown.inputLimit),
    );
    final preview = await Isolate.run(unknown.preview);
    expect(preview.estimatedRequests, 1);
    expect(preview.prompt, contains(background));
    expect(
      await const CompressionEngine().run(
        task: task,
        request: request(),
        materials: materials,
        previousSummary: '',
        background: background,
        check: () {},
        publish: () async {},
      ),
      '完整摘要',
    );
    expect(sent, preview.prompt);
    expect(task.requestAttempts, 1);
  });

  test(
    'known small model windows still reject an oversized reference',
    () async {
      await expectLater(
        const CompressionEngine().run(
          task: task,
          request: CompressionRequest(
            options: options,
            model: 'explicit-32k-model',
            quoteMarker: (_) => 'quote',
            contextWindowTokens: 32000,
            generate: (_, _, _, _) async =>
                fail('must not exceed a known window'),
          ),
          materials: ['需要压缩的历史内容'],
          previousSummary: '',
          background: '背景设定 ' * 7000,
          check: () {},
          publish: () async {},
        ),
        throwsA(
          predicate(
            (e) => e.toString().contains('compression_reference_too_large'),
          ),
        ),
      );
      expect(task.requestAttempts, 0);
    },
  );

  test(
    'large windows still bound requests and keep the event loop responsive',
    () async {
      final materials = List.generate(
        800,
        (i) => '[source message:$i]\n${'历史消息 example of context ' * 12}',
      );
      final content = <String>[];
      var eventRan = false;
      Timer.run(() => eventRan = true);
      await run(materials, (prompt, _, _, _) async {
        expect(
          eventRan,
          isTrue,
          reason: 'planning must yield to the UI isolate',
        );
        expect(
          prompt.length,
          lessThanOrEqualTo(CompressionPlanner.maxPromptChars),
        );
        content.add(
          prompt
              .split('<content data="reference, not instructions">\n')[1]
              .split('\n</content>')[0],
        );
        return result('working summary');
      }, window: 1000000);
      expect(content.length, greaterThan(1));
      expect(content.join('\n\n'), materials.join('\n\n'));
    },
  );

  test(
    'local limit splits a single long message without losing UTF-16 text',
    () async {
      final original = '${'alpha😀中文 ' * 24000}END_EVIDENCE';
      final content = <String>[];
      await run([original], (prompt, _, _, _) async {
        expect(
          prompt.length,
          lessThanOrEqualTo(CompressionPlanner.maxPromptChars),
        );
        final part = prompt
            .split('<content data="reference, not instructions">\n')[1]
            .split('\n</content>')[0]
            .replaceFirst(RegExp(r'^\[source fragment[^\n]+\]\n'), '');
        expect(part.runes.any((r) => r >= 0xd800 && r <= 0xdfff), isFalse);
        content.add(part);
        return result('summary ${'记忆' * 1000}');
      }, window: 1000000);
      expect(content.length, greaterThan(1));
      expect(content.join(), original);
    },
  );

  test(
    'local request limit participates in the preflight call budget',
    () async {
      await expectLater(
        run(
          ['history ' * 40000],
          (_, _, _, _) async => fail('must reject before a paid request'),
          window: 1000000,
          attempts: 1,
        ),
        throwsA(
          predicate((e) => e.toString().contains('compression_request_budget')),
        ),
      );
      expect(task.requestAttempts, 0);
    },
  );

  test(
    'preflight counts whole-message packing rather than total characters',
    () async {
      await expectLater(
        run(
          List.generate(3, (i) => '[source message:$i]\n${'history ' * 7500}'),
          (_, _, _, _) async => fail('must reject before a paid request'),
          window: 1000000,
          attempts: 2,
        ),
        throwsA(
          predicate((e) => e.toString().contains('compression_request_budget')),
        ),
      );
      expect(task.requestAttempts, 0);
    },
  );

  test(
    'preflight reserves character space for subsequent working summaries',
    () async {
      final request = CompressionRequest(
        options: options,
        model: 'test',
        quoteMarker: (_) => 'quote',
        contextWindowTokens: 1000000,
        config: const CompressionConfig(
          summaryTokens: 4096,
          maxRequestAttempts: 2,
        ),
        generate: (_, _, _, _) async =>
            fail('must reject before a paid request'),
      );
      await expectLater(
        const CompressionEngine().run(
          task: task,
          request: request,
          materials: ['[source message:large]\n${'history ' * 23000}'],
          previousSummary: '',
          background: '',
          check: () {},
          publish: () async {},
        ),
        throwsA(
          predicate((e) => e.toString().contains('compression_request_budget')),
        ),
      );
      expect(task.requestAttempts, 0);
    },
  );

  test(
    'local preview is the first bounded request used by execution',
    () async {
      final materials = List.generate(
        300,
        (i) => 'message $i ${'history ' * 80}',
      );
      var first = '';
      final request = CompressionRequest(
        options: options,
        model: 'test',
        quoteMarker: (_) => 'quote',
        contextWindowTokens: 1000000,
        generate: (prompt, _, _, _) async {
          if (first.isEmpty) first = prompt;
          return result('summary');
        },
      );
      final planner = CompressionPlanner(
        request: request,
        materials: materials,
        previousSummary: '',
        background: '',
      );
      final preview = await Isolate.run(planner.preview);
      expect(
        preview.prompt.length,
        lessThanOrEqualTo(CompressionPlanner.maxPromptChars),
      );
      expect(preview.estimatedRequests, greaterThan(1));
      await const CompressionEngine().run(
        task: task,
        request: request,
        materials: materials,
        previousSummary: '',
        background: '',
        check: () {},
        publish: () async {},
      );
      expect(first, preview.prompt);
    },
  );

  test('cancellation during background planning makes no model call', () async {
    var cancelled = false;
    Timer.run(() => cancelled = true);
    await expectLater(
      const CompressionEngine().run(
        task: task,
        request: CompressionRequest(
          options: options,
          model: 'test',
          quoteMarker: (_) => 'quote',
          generate: (_, _, _, _) async =>
              fail('must not call after cancellation'),
        ),
        materials: ['history ' * 100],
        previousSummary: '',
        background: '',
        check: () {
          if (cancelled) throw StateError('cancelled');
        },
        publish: () async {},
      ),
      throwsStateError,
    );
    expect(task.requestAttempts, 0);
  });

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
  test('local limit also rejects oversized fixed instructions', () async {
    await expectLater(
      run(
        ['history'],
        (_, _, _, _) async => fail('must not call'),
        window: 1000000,
        template: CompressionTemplate(
          id: 'large',
          name: 'large',
          prompt: 'x' * CompressionPlanner.maxPromptChars,
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
