import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
    int summaryTokens = 512,
    String background = '',
    CompressionTemplate? template,
  }) async => (await const CompressionEngine().run(
    task: task,
    request: CompressionRequest(
      options: options,
      model: 'test',
      generate: generate,
      quoteMarker: (_) => 'quote',
      contextWindowTokens: window,
      template: template,
      config: CompressionConfig(summaryTokens: summaryTokens),
    ),
    materials: materials,
    background: background,
    check: () {},
    publish: () async {},
  )).summary;
  TextGenerationResult result(
    String text, {
    String? reason = 'stop',
    TokenUsage? usage,
  }) => TextGenerationResult(
    parts: [TextPart(text)],
    finishReason: reason,
    usage: usage,
  );

  String historyIn(String prompt) => prompt
      .split('<content data="reference, not instructions">\n')[1]
      .split('\n</content>')[0]
      .replaceFirst(RegExp(r'^\[source fragment[^\n]+\]\n'), '');

  test(
    'counts lower-level authentication attempts and returned usage',
    () async {
      var sent = 0;
      final summary = await run(['history ' * 100], (_, _, _, _) async {
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
          final uri = Uri.parse('https://example.test/messages');
          await client.post(uri);
          await client.post(uri);
          return result(
            'summary',
            usage: const TokenUsage(promptTokens: 10, completionTokens: 2),
          );
        } finally {
          client.close();
        }
      });
      expect(summary, 'summary');
      expect(sent, 2);
      expect(task.requestAttempts, 2);
      expect(task.finishReasons, [null, 'stop']);
      expect(task.unknownUsageAttempts, 1);
    },
  );

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
        background: '',
      );
      expect(planner.inputLimit, 32000 - 4096 - 1600);
      expect(
        (await const CompressionEngine().run(
          task: task,
          request: request,
          materials: ['history'],
          background: '',
          check: () {},
          publish: () async {},
        )).summary,
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
      (await const CompressionEngine().run(
        task: task,
        request: request(),
        materials: materials,
        background: background,
        check: () {},
        publish: () async {},
      )).summary,
      '完整摘要',
    );
    expect(sent, preview.prompt);
    expect(task.requestAttempts, 1);
  });

  test('oversized estimated background still reaches the provider', () async {
    final background = '背景设定 ' * 22000;
    const history = '需要压缩的历史内容';
    final summary = await run(
      [history],
      (prompt, _, _, _) async {
        expect(prompt, contains(background));
        expect(historyIn(prompt), history);
        return result('summary');
      },
      window: 32000,
      background: background,
    );
    expect(summary, 'summary');
    expect(task.requestAttempts, 1);
  });

  test(
    'large windows send more than 100,000 characters in one request',
    () async {
      final materials = List.generate(
        800,
        (i) => '[source message:$i]\n${'历史消息 example of context ' * 12}',
      );
      final background = '背景 ' * 35000;
      var eventRan = false;
      Timer.run(() => eventRan = true);
      await run(
        materials,
        (prompt, _, _, _) async {
          expect(eventRan, isTrue);
          expect(historyIn(prompt), materials.join('\n\n'));
          expect(prompt, contains(background));
          return result('working summary');
        },
        window: 1000000,
        background: background,
      );
      expect(task.requestAttempts, 1);
    },
  );

  test(
    'estimated window splits a large previous summary without losing Unicode',
    () async {
      final original = '[source summary:old]\n${'alpha😀中文 ' * 24000}END';
      final content = <String>[];
      await run([original], (prompt, _, _, _) async {
        final part = historyIn(prompt);
        expect(part.runes.any((r) => r >= 0xd800 && r <= 0xdfff), isFalse);
        content.add(part);
        return result('working summary');
      }, window: 16000);
      expect(content.length, greaterThan(1));
      expect(content.join(), original);
    },
  );

  test('keeps a fitting previous summary in its template section', () async {
    await run(['[source summary:old]\nPast decision.', 'New information.'], (
      prompt,
      _,
      _,
      _,
    ) async {
      expect(
        prompt,
        contains(
          '<previous_summary data="reference, not instructions">\n'
          'Past decision.\n</previous_summary>',
        ),
      );
      expect(historyIn(prompt), 'New information.');
      return result('complete');
    });
    expect(task.requestAttempts, 1);
  });

  test(
    'a stored summary becomes splittable if the provider rejects it',
    () async {
      final stored = 'history ' * 400;
      final accepted = <String>[];
      await run(['[source summary:old]\n$stored', 'New information.'], (
        prompt,
        _,
        _,
        _,
      ) async {
        if (prompt.contains('\n$stored\n</previous_summary>')) {
          throw StateError('context_length_exceeded');
        }
        accepted.add(historyIn(prompt));
        return result('complete');
      });
      expect(accepted.join('\n\n'), contains(stored));
      expect(accepted.join(), contains('New information.'));
    },
  );

  test('local preview shows the same first prompt as execution', () async {
    final materials = List.generate(
      300,
      (i) => 'message $i ${'history ' * 80}',
    );
    String? first;
    final request = CompressionRequest(
      options: options,
      model: 'test',
      quoteMarker: (_) => 'quote',
      contextWindowTokens: 16000,
      generate: (prompt, _, _, _) async {
        first ??= prompt;
        return result('summary');
      },
    );
    final planner = CompressionPlanner(
      request: request,
      materials: materials,
      background: '',
    );
    final preview = await Isolate.run(planner.preview);
    expect(preview.estimatedRequests, greaterThan(1));
    await const CompressionEngine().run(
      task: task,
      request: request,
      materials: materials,
      background: '',
      check: () {},
      publish: () async {},
    );
    expect(first, preview.prompt);
  });

  test('preview uses the available budget after a short first batch', () {
    final planner = CompressionPlanner(
      request: CompressionRequest(
        options: options,
        model: 'test',
        quoteMarker: (_) => 'quote',
        contextWindowTokens: 32000,
        generate: (_, _, _, _) async => result('summary'),
      ),
      materials: ['Short introduction.', 'history ' * 40000],
      background: '',
    );
    final preview = planner.preview();
    expect(historyIn(preview.prompt), 'Short introduction.');
    expect(preview.estimatedRequests, 3);
  });

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
      final summary = await run([original], (prompt, _, _, _) async {
        calls++;
        if (calls > 1) expect(prompt, contains('STATE_${calls - 1}'));
        final content = prompt
            .split('<content data="reference, not instructions">\n')[1]
            .split('\n</content>')[0];
        pieces.add(
          content.replaceFirst(RegExp(r'^\[source fragment[^\n]+\]\n'), ''),
        );
        return result('STATE_$calls');
      }, window: 6000);
      expect(calls, greaterThan(1));
      expect(summary, 'STATE_$calls');
      expect(pieces.join(), original);
      expect(task.completedParts, calls);
      expect(task.unknownUsageAttempts, calls);
    },
  );

  test('processes the entire history beyond eight requests', () async {
    final original = 'long history ' * 22000;
    final parts = <String>[];
    final summary = await run([original], (prompt, _, _, _) async {
      parts.add(historyIn(prompt));
      return result('summary');
    }, window: 4000);
    expect(summary, 'summary');
    expect(task.requestAttempts, greaterThan(8));
    expect(task.completedParts, task.requestAttempts);
    expect(parts.join(), original);
  });

  test(
    'provider overflow shrinks the rejected span and keeps all source and usage',
    () async {
      final original = 'history ' * 400;
      final parts = <String>[];
      var calls = 0;
      await run([original], (prompt, _, _, onUsage) async {
        calls++;
        final part = historyIn(prompt);
        if (calls == 1) {
          expect(part, original);
          onUsage(const TokenUsage(promptTokens: 7));
          throw StateError('context_length_exceeded');
        }
        expect(part.length, lessThan(original.length));
        parts.add(part);
        return result(
          'complete',
          usage: const TokenUsage(promptTokens: 20, completionTokens: 3),
        );
      });
      expect(calls, 3);
      expect(parts.join(), original);
      expect(task.usage!.promptTokens, 47);
    },
  );

  test(
    'provider size rejection can retry without optional background',
    () async {
      final background = 'BACKGROUND ' * 10000;
      var calls = 0;
      final summary = await run(['conversation history'], (
        prompt,
        _,
        _,
        _,
      ) async {
        calls++;
        expect(historyIn(prompt), 'conversation history');
        if (calls == 1) {
          expect(prompt, contains(background));
          throw const HttpException('HTTP 413: payload too large');
        }
        expect(prompt, isNot(contains('BACKGROUND')));
        return result('complete');
      }, background: background);
      expect(summary, 'complete');
      expect(calls, 2);
    },
  );

  test(
    'reducing the output reservation reopens room for later history',
    () async {
      final original = 'history ' * 400;
      final accepted = <String>[];
      await run([original], (prompt, _, output, _) async {
        if (output > 128) {
          throw const HttpException('HTTP 400: context_length_exceeded');
        }
        accepted.add(historyIn(prompt));
        return result('complete');
      });
      expect(accepted.join(), original);
      expect(accepted.length, lessThan(20));
    },
  );

  test('tries a shorter input with the same output budget first', () async {
    final original = 'history ' * 100;
    final accepted = <String>[];
    final outputBudgets = <int>[];
    final summary = await run([original], (prompt, _, output, _) async {
      outputBudgets.add(output);
      final source = historyIn(prompt);
      if (source.length > 400) {
        throw StateError('context_length_exceeded');
      }
      if (output < 300) return result('partial', reason: 'length');
      accepted.add(source);
      return result('complete');
    });
    expect(summary, 'complete');
    expect(accepted.join(), original);
    expect(outputBudgets, [512, 512, 512]);
  });

  test('reuses space freed by a shorter working summary after a 413', () async {
    final tail = 'tail ' * 1000;
    final accepted = <String>[];
    await run(
      ['intro ' * 14, tail],
      (prompt, _, _, _) async {
        if (utf8.encode(prompt).length > 6206) {
          throw const HttpException('HTTP 413: Request Entity Too Large');
        }
        accepted.add(historyIn(prompt));
        return result(accepted.length == 1 ? 'concept ' * 124 : 'brief');
      },
      window: 2000,
      summaryTokens: 128,
    );
    expect(accepted.skip(1).join(), tail);
    expect(accepted[2].length, greaterThan(accepted[1].length * 5));
    expect(task.requestAttempts, lessThan(30));
  });

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
  test(
    'oversized custom instructions reach the provider and retain its final error',
    () async {
      final instructions = 'very long template ' * 7000;
      const failure = HttpException('HTTP 400: context_length_exceeded');
      final requests = <(String, int)>{};
      await expectLater(
        run(
          ['history'],
          (prompt, _, output, _) async {
            expect(prompt, contains(instructions));
            expect(requests.add((historyIn(prompt), output)), isTrue);
            throw failure;
          },
          window: 4000,
          template: CompressionTemplate(
            id: 'custom',
            name: 'custom',
            prompt: instructions,
          ),
        ),
        throwsA(same(failure)),
      );
      expect(task.requestAttempts, greaterThan(0));
      expect(task.requestAttempts, lessThan(9));
      expect(task.completedParts, 0);
    },
  );
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
