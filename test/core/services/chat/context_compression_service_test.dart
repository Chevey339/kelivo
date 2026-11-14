import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/models/native_compaction.dart';
import 'package:Kelivo/core/services/api/request_timeout.dart';
import 'package:Kelivo/features/chat/widgets/context_compression_status.dart';
import 'package:Kelivo/l10n/app_localizations_zh.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/generation/text_generation_result.dart';
import 'package:Kelivo/core/services/api/native_compaction_context.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_history.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_request.dart';
import 'package:Kelivo/l10n/app_localizations_en.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/models/compress_context_options.dart';
import 'package:Kelivo/core/models/compression_config.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/quote_ref.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/chat/context_compression_service.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getApplicationCachePath() async => '$path/cache';
  @override
  Future<String?> getTemporaryPath() async => '$path/tmp';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late ChatDatabaseRepository repo;
  late AppDatabase database;
  late ChatService chat;
  late String id;
  late ContextCompressionService compression;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('compression_jobs_');
    PathProviderPlatform.instance = _Paths(dir.path);
    final databaseFile = File('${dir.path}/chat.sqlite');
    database = AppDatabase.open(file: databaseFile);
    repo = ChatDatabaseRepository(database, databaseFile: databaseFile);
    await repo.ensureReady();
    chat = ChatService(existingRepository: repo);
    await chat.init();
    id = (await chat.createConversation(title: 'Original')).id;
    for (var i = 0; i < 8; i++) {
      await chat.addMessage(
        conversationId: id,
        role: 'user',
        content: 'user $i ${'history ' * 80}',
      );
      await chat.addMessage(
        conversationId: id,
        role: 'assistant',
        content: 'answer $i ${'answer ' * 80}',
      );
    }
    compression = chat.contextCompression;
    compression.estimateCandidate = (_, _, {bool? fixedContextStart}) async =>
        (usedTokens: 100, contextWindow: 4000);
  });
  tearDown(() async {
    await chat.close();
    await repo.close();
    await dir.delete(recursive: true);
  });
  CompressionRequest request(
    Future<String> Function(String, String) generate, {
    Future<String> Function(CompressionSelection)? loadReference,
    CompressContextOptions options = const CompressContextOptions(
      mode: CompressContextLimitMode.keepRecent,
      keepUserMessages: 6,
    ),
  }) => CompressionRequest(
    options: options,
    model: 'test',
    generate: (prompt, id, _, _) async =>
        TextGenerationResult(parts: [TextPart(await generate(prompt, id))]),
    quoteMarker: AppLocalizationsEn().selectionQuoteMarker,
    loadReference: loadReference,
  );
  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 500; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail(
      'compression did not reach expected state: ${compression.taskFor(id)?.phase}',
    );
  }

  Future<void> rejectCancellationWrites() => database.customStatement('''
    CREATE TRIGGER reject_cancel BEFORE UPDATE ON extension_entity_rows
    WHEN NEW.kind = 'contextCompressionTask'
      AND json_extract(NEW.payload, '\$.phase') = 'cancelled'
    BEGIN SELECT RAISE(FAIL, 'cancel write failed'); END
  ''');

  Future<void> rejectDismissalWrites() => database.customStatement('''
    CREATE TRIGGER reject_dismiss BEFORE UPDATE ON extension_entity_rows
    WHEN NEW.kind = 'contextCompressionTask'
      AND json_extract(NEW.payload, '\$.dismissed') = 1
    BEGIN SELECT RAISE(FAIL, 'dismiss write failed'); END
  ''');

  NativeCompactionPayload nativePayload(String value) =>
      NativeCompactionPayload(
        protocol: NativeCompactionProtocol.compact,
        scope: 'fixture',
        modelId: 'private-model',
        output: [
          {'type': 'compaction', 'id': value, 'encrypted_content': value},
          {'type': 'future_item', 'retain': true},
        ],
      );

  CompressionRequest nativeRequest(
    Future<NativeCompactionPayload> Function(CompressionSelection, String)
    compact, {
    bool newConversation = false,
    int keep = 1,
  }) => CompressionRequest(
    options: CompressContextOptions(
      mode: CompressContextLimitMode.keepRecent,
      keepUserMessages: keep,
      native: true,
      newConversation: newConversation,
    ),
    model: 'private-provider/private-model',
    quoteMarker: AppLocalizationsEn().selectionQuoteMarker,
    compactNative: compact,
  );

  for (final native in [false, true]) {
    test(
      'timeout is a retryable failure and preserves history: native=$native',
      () async {
        final before = await chat.loadContextSnapshot(id);
        const error = RequestTimeoutException(Duration(minutes: 10));
        await compression.start(
          id,
          native
              ? nativeRequest((_, _) async => throw error)
              : request((_, _) async => throw error),
        );
        await until(
          () => compression.taskFor(id)!.phase == CompressionPhase.failed,
        );
        final task = compression.taskFor(id)!;
        expect(task.phase, CompressionPhase.failed);
        expect(task.cancelRequested, isFalse);
        expect(task.active, isFalse);
        expect(task.error, error.toString());
        expect(
          compressionErrorLabel(AppLocalizationsZh(), task.error!),
          AppLocalizationsZh().compressionRequestTimedOut(10),
        );
        final after = await chat.loadContextSnapshot(id);
        expect(after.operations, isEmpty);
        expect(
          after.messages.map((m) => m.id),
          before.messages.map((m) => m.id),
        );
        expect(task.candidate, isNull);
        await compression.start(
          id,
          native
              ? nativeRequest((_, _) async => nativePayload('retry'))
              : request((_, _) async => 'short summary'),
        );
        await until(
          () => compression.taskFor(id)!.phase == CompressionPhase.completed,
        );
      },
    );

    for (final fails in [false, true]) {
      test(
        'finished tasks release source callbacks: native=$native failed=$fails',
        () async {
          final request = CompressionRequest(
            options: CompressContextOptions(
              mode: CompressContextLimitMode.keepRecent,
              keepUserMessages: 1,
              native: native,
            ),
            model: 'test',
            quoteMarker: AppLocalizationsEn().selectionQuoteMarker,
            loadReference: (_) async => 'current reference',
            generate: native
                ? null
                : (_, _, _, _) async {
                    if (fails) throw StateError('model failed');
                    return const TextGenerationResult(
                      parts: [TextPart('short summary')],
                    );
                  },
            compactNative: !native
                ? null
                : (_, _) async {
                    if (fails) throw StateError('model failed');
                    return nativePayload('completed');
                  },
          );
          await compression.start(id, request);
          final phase = fails
              ? CompressionPhase.failed
              : CompressionPhase.completed;
          await until(
            () =>
                compression.taskFor(id)!.phase == phase &&
                compression.taskFor(id)!.request == null,
          );
          expect(compression.taskFor(id)!.validateReferences, isNull);
        },
      );
    }
  }

  test(
    'review releases generation inputs and still applies the saved candidate',
    () async {
      await compression.start(
        id,
        request(
          (_, _) async => 'reviewed summary',
          options: const CompressContextOptions(
            mode: CompressContextLimitMode.keepRecent,
            keepUserMessages: 1,
            previewOnly: true,
          ),
          loadReference: (_) async => 'current reference',
        ),
      );
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.review,
      );
      // Let the run finish its final status write before inspecting cleanup.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final task = compression.taskFor(id)!;
      expect(task.request, isNull);
      expect(task.validateReferences, isNull);
      await compression.applyReviewed(id, task.summary);
      expect(task.phase, CompressionPhase.completed);
      expect(
        (await chat.loadContextOperations(id)).single.summary,
        'reviewed summary',
      );
    },
  );

  for (final phase in [
    CompressionPhase.completed,
    CompressionPhase.failed,
    CompressionPhase.interrupted,
  ]) {
    test(
      'dismissing $phase preserves its outcome without cancellation',
      () async {
        if (phase == CompressionPhase.interrupted) {
          compression.isConversationBusy = (_) => true;
        }
        await compression.start(
          id,
          request((_, _) async {
            if (phase == CompressionPhase.failed) {
              throw StateError('model failed');
            }
            return 'saved summary';
          }),
        );
        if (phase == CompressionPhase.interrupted) {
          await compression.restore();
        } else {
          await until(() => compression.taskFor(id)!.phase == phase);
        }
        final task = compression.taskFor(id)!;
        final before = await chat.loadContextSnapshot(id);
        final observed = <CompressionPhase?>[];
        void observe() => observed.add(compression.taskFor(id)?.phase);
        compression.addListener(observe);
        addTearDown(() => compression.removeListener(observe));

        await compression.dismiss(id);

        expect(task.phase, phase);
        expect(observed, [null]);
        expect(
          (await chat.loadContextSnapshot(id)).fingerprint,
          before.fingerprint,
        );
        final record = (await chat.readCompressionTaskRecords())[id]!;
        expect(record['phase'], phase.name);
        expect(record['dismissed'], isTrue);
        await compression.restore();
        expect(compression.taskFor(id), isNull);
      },
    );
  }

  test(
    'failed dismissal keeps the original status available for retry',
    () async {
      await compression.start(id, request((_, _) async => 'saved summary'));
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.completed,
      );
      final task = compression.taskFor(id)!;
      final observed = <CompressionPhase?>[];
      void observe() => observed.add(compression.taskFor(id)?.phase);
      compression.addListener(observe);
      addTearDown(() => compression.removeListener(observe));
      await rejectDismissalWrites();

      await expectLater(
        compression.dismiss(id),
        throwsA(
          predicate(
            (Object error) => error.toString().contains('dismiss write failed'),
          ),
        ),
      );

      expect(compression.taskFor(id), same(task));
      expect(task.phase, CompressionPhase.completed);
      expect(observed, isEmpty);
      expect(
        (await chat.readCompressionTaskRecords())[id]!['dismissed'],
        isNull,
      );
      await database.customStatement('DROP TRIGGER reject_dismiss');
      await compression.dismiss(id);
      expect(compression.taskFor(id), isNull);
      expect(observed, [null]);
      expect(
        (await chat.loadContextOperations(id, refresh: true)).single.revoked,
        isFalse,
      );
    },
  );

  test(
    'dismissing an old result preserves a replacement task and its record',
    () async {
      await compression.start(id, request((_, _) async => 'saved summary'));
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.completed,
      );
      final old = compression.taskFor(id)!;
      final dismiss = compression.dismiss(id);
      compression.isConversationBusy = (_) => true;
      await compression.start(id, request((_, _) async => 'next summary'));
      final replacement = compression.taskFor(id)!;
      await dismiss;
      expect(replacement.id, isNot(old.id));
      expect(compression.taskFor(id), same(replacement));
      expect(replacement.phase, CompressionPhase.waiting);
      final record = (await chat.readCompressionTaskRecords())[id]!;
      expect(record['id'], replacement.id);
      expect(record['dismissed'], isNull);
      await compression.restore();
      expect(compression.taskFor(id)!.id, replacement.id);
    },
  );

  for (final temporary in [false, true]) {
    test(
      'native regeneration after a retained edit replays only compacted history and the target: temporary=$temporary',
      () async {
        final conversation = temporary
            ? await chat.createDraftConversation(
                title: 'Five turns',
                temporary: true,
              )
            : await chat.createConversation(title: 'Five turns');
        id = conversation.id;
        chat.setCurrentConversation(id);
        for (final turn in ['A', 'B', 'C', 'D', 'E']) {
          for (final role in ['user', 'assistant']) {
            await chat.addMessage(
              conversationId: id,
              role: role,
              content: '$turn-1-$role',
            );
          }
        }
        final original = (await chat.loadContextSnapshot(id)).messages;
        final config = nativeResponsesConfig(
          ProviderConfig(
            id: 'fixture',
            name: 'Fixture',
            enabled: true,
            baseUrl: 'https://fixture.example/v1',
            apiKey: 'test',
          ),
        );
        final payload = NativeCompactionPayload(
          protocol: NativeCompactionProtocol.compact,
          scope: nativeCompactionScope(config),
          modelId: 'private-model',
          output: [
            {
              'type': 'compaction',
              'id': 'AB',
              'encrypted_content': 'opaque-AB',
            },
          ],
        );
        await compression.start(
          id,
          nativeRequest((selection, _) async {
            expect(selection.input.map((m) => m.content), [
              'A-1-user',
              'A-1-assistant',
              'B-1-user',
              'B-1-assistant',
            ]);
            expect(
              selection.retained.map((m) => m.id),
              original.skip(4).map((m) => m.id),
            );
            return payload;
          }, keep: 3),
        );
        await until(
          () => compression.taskFor(id)!.phase == CompressionPhase.completed,
        );
        final edited = await chat.appendMessageVersion(
          messageId: original[4].id,
          content: 'C-2-user',
        );
        final operation = (await chat.loadContextOperations(
          id,
          refresh: true,
        )).single;
        expect(operation.revoked, isFalse);
        expect(operation.anchorGroupId, ContextHistory.group(original[3]));
        expect(
          operation.appliedAfterGroupId,
          ContextHistory.group(original.last),
        );
        final history = await chat.loadEffectiveContextMessages(
          id,
          limit: 100,
          throughRevisionId: edited!.id,
        );
        expect(history.map((m) => m.id), [
          operation.summaryMessageId,
          edited.id,
        ]);
        expect(
          NativeCompactionPayload.forMessage(history.first)!.output,
          payload.output,
        );
        final body = await buildOpenAIResponsesBody(config, 'private-model', [
          for (final message in history)
            {
              'role': message.role,
              'content': message.content,
              if (NativeCompactionPayload.forMessage(message)
                  case final native?)
                nativeCompactionMessageKey: native.toJson(),
            },
        ]);
        final input = (body['input'] as List).cast<Map>();
        expect(
          input.where((item) => item['type'] == 'compaction'),
          hasLength(1),
        );
        final serialized = jsonEncode(input);
        expect(serialized, contains('C-2-user'));
        for (final excluded in [
          'A-1-assistant',
          'B-1-assistant',
          'C-1-',
          'D-1-',
          'E-1-',
        ]) {
          expect(serialized, isNot(contains(excluded)));
        }
      },
    );
  }

  test(
    'native history stays opaque while subsequent text compression reads originals',
    () async {
      final original = await chat.loadContextSnapshot(id);
      await compression.start(
        id,
        nativeRequest((selection, _) async {
          expect(selection.input, hasLength(14));
          expect(selection.retained, hasLength(2));
          expect(
            selection.input.any((m) => m.content.startsWith('user 7')),
            isFalse,
          );
          return nativePayload('opaque-one');
        }),
      );
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.completed,
      );
      final effective = await chat.loadSelectedContextMessages(id, limit: 100);
      expect(effective, hasLength(3));
      expect(effective.first.content, isEmpty);
      expect(
        NativeCompactionPayload.forMessage(effective.first)!.output,
        nativePayload('opaque-one').output,
      );
      expect(
        (await chat.loadContextSnapshot(id)).messages.map((m) => m.content),
        original.messages.map((m) => m.content),
      );
      var prompt = '';
      await compression.start(
        id,
        request(
          (input, _) async {
            prompt = input;
            return 'text summary';
          },
          options: const CompressContextOptions(
            mode: CompressContextLimitMode.keepRecent,
            keepUserMessages: 1,
            regenerateExisting: true,
          ),
        ),
      );
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.completed,
      );
      expect(prompt, contains('user 0'));
      expect(prompt, isNot(contains('opaque-one')));
      expect(
        (await chat.loadSelectedContextMessages(id, limit: 100)).first.content,
        contains('text summary'),
      );
    },
  );

  test(
    'native compression can replace an existing text-only summary prefix',
    () async {
      await compression.start(
        id,
        request(
          (_, _) async => 'earlier text summary',
          options: const CompressContextOptions(
            mode: CompressContextLimitMode.keepRecent,
            keepUserMessages: 1,
          ),
        ),
      );
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.completed,
      );
      await compression.start(
        id,
        nativeRequest((selection, _) async {
          expect(selection.input, hasLength(1));
          expect(
            selection.input.single.content,
            contains('earlier text summary'),
          );
          return nativePayload('converted');
        }),
      );
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.completed,
      );
      final messages = await chat.loadSelectedContextMessages(id, limit: 100);
      expect(
        NativeCompactionPayload.forMessage(messages.first)!.output,
        nativePayload('converted').output,
      );
      expect(messages, hasLength(3));
    },
  );

  test(
    'repeated native compression replays its prior state without the retained tail',
    () async {
      await compression.start(
        id,
        nativeRequest((_, _) async => nativePayload('first')),
      );
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.completed,
      );
      await chat.addMessage(
        conversationId: id,
        role: 'user',
        content: 'new tail',
      );
      await chat.addMessage(
        conversationId: id,
        role: 'assistant',
        content: 'new answer',
      );
      await compression.start(
        id,
        nativeRequest((selection, _) async {
          expect(
            NativeCompactionPayload.forMessage(selection.input.first)!.output,
            nativePayload('first').output,
          );
          expect(selection.input.any((m) => m.content == 'new tail'), isFalse);
          expect(selection.retained.map((m) => m.content), [
            'new tail',
            'new answer',
          ]);
          return nativePayload('second');
        }),
      );
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.completed,
      );
      final effective = await chat.loadSelectedContextMessages(id, limit: 100);
      expect(effective, hasLength(3));
      expect(
        NativeCompactionPayload.forMessage(effective.first)!.output,
        nativePayload('second').output,
      );
    },
  );

  test(
    'native cancellation and invalid results leave context untouched',
    () async {
      final source = await chat.loadContextSnapshot(id);
      final hold = Completer<NativeCompactionPayload>();
      var entered = false;
      await compression.start(
        id,
        nativeRequest((_, _) {
          entered = true;
          return hold.future;
        }),
      );
      await until(() => entered);
      await compression.cancel(id);
      hold.complete(nativePayload('late'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        (await chat.loadContextSnapshot(id)).fingerprint,
        source.fingerprint,
      );
      await compression.start(
        id,
        nativeRequest(
          (_, _) async => throw StateError('native_compaction_missing'),
        ),
      );
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.failed,
      );
      expect(
        (await chat.loadContextSnapshot(id)).fingerprint,
        source.fingerprint,
      );
    },
  );

  for (final keep in [0, 1, 3]) {
    test(
      'native new chat stores only the result and $keep complete turns',
      () async {
        final last = (await chat.loadContextSnapshot(id)).messages.last;
        final events = [
          {
            'id': 'tool-last',
            'name': 'lookup',
            'arguments': {'query': 'retained'},
            'content': 'TOOL_RESULT',
          },
        ];
        await chat.updateMessage(
          last.id,
          parts: [
            TextPart(last.content),
            ToolCallPart(jsonEncode(events.single)),
          ],
        );
        await chat.setToolEvents(last.id, events);
        await chat.setProviderArtifact(
          last.id,
          responsesTurnArtifactKind,
          'complete tool history',
        );
        final source = await chat.loadContextSnapshot(id);
        await compression.start(
          id,
          nativeRequest(
            (_, _) async => nativePayload('fork'),
            newConversation: true,
            keep: keep,
          ),
        );
        await until(
          () => compression.taskFor(id)!.phase == CompressionPhase.completed,
        );
        final target = compression.taskFor(id)!.resultConversationId!;
        final copy = await chat.loadContextSnapshot(target);
        final retained = keep == 0
            ? <ChatMessage>[]
            : source.messages.sublist(source.messages.length - keep * 2);
        expect(copy.messages, hasLength(1 + keep * 2));
        expect(
          copy.messages.skip(1).map((m) => m.content),
          retained.map((m) => m.content),
        );
        final imported = copy.operations.single;
        expect(imported.isImportedNative, isTrue);
        expect(imported.canUndo, isFalse);
        expect(imported.nativeSourceConversationId, id);
        expect(imported.nativePayload!.output, nativePayload('fork').output);
        expect(
          (await chat.loadSelectedContextMessages(target, limit: 100)),
          hasLength(1 + keep * 2),
        );
        if (keep > 0) {
          expect(chat.getToolEventsForMessage(copy.messages.last), events);
          expect(
            chat.getProviderArtifactForMessage(
              copy.messages.last,
              responsesTurnArtifactKind,
            ),
            'complete tool history',
          );
          expect(
            copy.messages.last.parts.map((p) => p.encodePayload()),
            source.messages.last.parts.map((p) => p.encodePayload()),
          );
        }
        await expectLater(
          chat.changeContextOperation(
            target,
            imported.id,
            includeDependents: true,
            expectedState: ContextHistory.operationsFingerprint(
              copy.operations,
            ),
          ),
          throwsA(
            predicate(
              (Object e) => e.toString().contains(
                'native_compaction_originals_unavailable',
              ),
            ),
          ),
        );
        expect(
          (await chat.loadContextSnapshot(target)).fingerprint,
          copy.fingerprint,
        );
        expect(
          (await chat.loadContextSnapshot(id)).fingerprint,
          source.fingerprint,
        );
        await chat.deleteConversation(id);
        expect(
          (await chat.loadSelectedContextMessages(target, limit: 100)),
          hasLength(1 + keep * 2),
        );
        expect(
          (await chat.loadContextOperations(
            target,
          )).single.nativePayload!.output,
          nativePayload('fork').output,
        );
      },
    );
  }

  test('native result cannot commit after its source was edited', () async {
    final hold = Completer<NativeCompactionPayload>();
    var entered = false;
    await compression.start(
      id,
      nativeRequest((_, _) {
        entered = true;
        return hold.future;
      }),
    );
    await until(() => entered);
    final source = (await chat.loadContextSnapshot(id)).messages.first;
    await chat.updateMessage(source.id, content: 'corrected source');
    hold.complete(nativePayload('stale'));
    await until(
      () => compression.taskFor(id)!.phase == CompressionPhase.failed,
    );
    expect(compression.taskFor(id)!.error, contains('context_changed'));
    expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
  });

  test(
    'imported native state rejects text rereads and supports undoing later native compression',
    () async {
      await compression.start(
        id,
        nativeRequest(
          (_, _) async => nativePayload('seed'),
          newConversation: true,
        ),
      );
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.completed,
      );
      final target = compression.taskFor(id)!.resultConversationId!;
      final initial = await chat.loadContextSnapshot(target);
      for (final source in [
        ContextHistorySource.effective,
        ContextHistorySource.original,
      ]) {
        var generated = false;
        await compression.start(
          target,
          request(
            (_, _) async {
              generated = true;
              return 'must not lose opaque history';
            },
            options: CompressContextOptions(
              mode: CompressContextLimitMode.unlimited,
              historySource: source,
            ),
          ),
        );
        await until(
          () => compression.taskFor(target)!.phase == CompressionPhase.failed,
        );
        expect(
          compression.taskFor(target)!.error,
          contains('native_compaction_originals_unavailable'),
        );
        expect(generated, isFalse);
        expect(
          (await chat.loadContextSnapshot(target)).fingerprint,
          initial.fingerprint,
        );
      }
      await compression.start(
        target,
        nativeRequest((selection, _) async {
          expect(
            NativeCompactionPayload.forMessage(selection.input.first)!.output,
            nativePayload('seed').output,
          );
          return nativePayload('recompressed');
        }, keep: 0),
      );
      await until(
        () => compression.taskFor(target)!.phase == CompressionPhase.completed,
      );
      final after = await chat.loadContextSnapshot(target);
      expect(after.operations.last.canUndo, isTrue);
      await chat.changeContextOperation(
        target,
        after.operations.last.id,
        includeDependents: true,
        expectedState: ContextHistory.operationsFingerprint(after.operations),
      );
      final restored = await chat.loadSelectedContextMessages(
        target,
        limit: 100,
      );
      expect(restored, hasLength(3));
      expect(
        NativeCompactionPayload.forMessage(restored.first)!.output,
        nativePayload('seed').output,
      );
    },
  );

  for (final newConversation in [false, true]) {
    for (final changeAtCommit in [false, true]) {
      test(
        'native reference changes fail without review: fork=$newConversation commit=$changeAtCommit',
        () async {
          final source = await chat.loadContextSnapshot(id);
          var reference = 'current rules';
          await compression.start(
            id,
            CompressionRequest(
              options: CompressContextOptions(
                mode: CompressContextLimitMode.keepRecent,
                keepUserMessages: 1,
                native: true,
                newConversation: newConversation,
              ),
              model: 'test',
              quoteMarker: AppLocalizationsEn().selectionQuoteMarker,
              loadReference: (_) async => reference,
              compactNative: (_, _) async {
                if (!changeAtCommit) reference = 'changed rules';
                return nativePayload('stale');
              },
              acceptCandidate: (_) async {
                if (changeAtCommit) reference = 'changed rules';
                return true;
              },
            ),
          );
          await until(() => !compression.taskFor(id)!.active);
          final task = compression.taskFor(id)!;
          expect(task.phase, CompressionPhase.failed);
          expect(task.error, contains('compression_reference_changed'));
          expect(task.resultConversationId, isNull);
          await compression.applyReviewed(id, 'Cannot approve opaque state');
          expect(
            (await chat.loadContextSnapshot(id)).fingerprint,
            source.fingerprint,
          );
          expect(chat.getAllConversations(), hasLength(1));
          // A failed native result must release the task for a fresh attempt.
          await compression.start(
            id,
            nativeRequest((_, _) async => nativePayload('fresh')),
          );
          await until(
            () => compression.taskFor(id)!.phase == CompressionPhase.completed,
          );
          expect(
            (await chat.loadContextOperations(id)).single.nativePayload!.output,
            nativePayload('fresh').output,
          );
        },
      );
    }
  }

  test(
    'native state reloads and copies only the retained tail without changing source undo',
    () async {
      final original = await chat.loadContextSnapshot(id);
      await compression.start(
        id,
        nativeRequest((_, _) async => nativePayload('persisted')),
      );
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.completed,
      );
      await chat.close();
      await repo.close();
      final file = File('${dir.path}/chat.sqlite');
      database = AppDatabase.open(file: file);
      repo = ChatDatabaseRepository(database, databaseFile: file);
      chat = ChatService(existingRepository: repo);
      await chat.init();
      compression = chat.contextCompression;
      final reloaded = await chat.loadContextSnapshot(id);
      expect(
        reloaded.operations.single.nativePayload!.output,
        nativePayload('persisted').output,
      );
      final continued = await chat.continueFromContextSummary(
        id,
        reloaded.operations.single.id,
      );
      final copy = await chat.loadContextSnapshot(continued.id);
      expect(continued.title, 'Original (1)');
      expect(copy.operations, hasLength(1));
      expect(
        copy.operations.single.nativePayload!.output,
        nativePayload('persisted').output,
      );
      expect(
        await chat.loadSelectedContextMessages(continued.id, limit: 100),
        hasLength(3),
      );
      expect(copy.messages, hasLength(3));
      expect(
        copy.messages.skip(1).map((m) => m.content),
        original.messages.skip(14).map((m) => m.content),
      );
      expect(copy.operations.single.isImportedNative, isTrue);
      final again = await chat.continueFromContextSummary(
        continued.id,
        copy.operations.single.id,
      );
      final againSnapshot = await chat.loadContextSnapshot(again.id);
      expect(again.title, 'Original (2)');
      expect(againSnapshot.messages, hasLength(3));
      expect(againSnapshot.operations.single.nativeSourceConversationId, id);
      await chat.changeContextOperation(
        id,
        reloaded.operations.single.id,
        includeDependents: true,
        expectedState: ContextHistory.operationsFingerprint(
          reloaded.operations,
        ),
      );
      expect(
        (await chat.loadSelectedContextMessages(
          id,
          limit: 100,
        )).map((m) => m.content),
        original.messages.map((m) => m.content),
      );
      await chat.close();
      await repo.close();
      database = AppDatabase.open(file: file);
      repo = ChatDatabaseRepository(database, databaseFile: file);
      chat = ChatService(existingRepository: repo);
      await chat.init();
      compression = chat.contextCompression;
      final restored = await chat.loadContextSnapshot(continued.id);
      expect(restored.operations.single.isImportedNative, isTrue);
      expect(
        restored.operations.single.nativePayload!.output,
        nativePayload('persisted').output,
      );
      expect(restored.messages, hasLength(3));
    },
  );

  test(
    'native temporary fork keeps only its retained tail and rejects undo',
    () async {
      final temporary = await chat.createDraftConversation(
        title: 'private',
        temporary: true,
      );
      await chat.createConversation(title: 'private (1)', activate: false);
      chat.setCurrentConversation(temporary.id);
      for (var i = 0; i < 3; i++) {
        await chat.addMessage(
          conversationId: temporary.id,
          role: 'user',
          content: 'secret $i',
        );
      }
      await compression.start(
        temporary.id,
        nativeRequest(
          (_, _) async => nativePayload('private'),
          newConversation: true,
        ),
      );
      await until(
        () =>
            compression.taskFor(temporary.id)!.phase ==
            CompressionPhase.completed,
      );
      final target = compression.taskFor(temporary.id)!.resultConversationId!;
      expect(chat.isTemporaryConversation(target), isTrue);
      expect(chat.getConversation(target)!.title, 'private (2)');
      final copy = await chat.loadContextSnapshot(target);
      expect(await repo.getConversation(target), isNull);
      expect(await repo.readContextOperations(target), isEmpty);
      expect(
        await chat.readCompressionTaskRecords(),
        isNot(contains(temporary.id)),
      );
      expect(
        await chat.loadSelectedContextMessages(target, limit: 100),
        hasLength(2),
      );
      expect(copy.messages, hasLength(2));
      expect(copy.messages.last.content, 'secret 2');
      expect(copy.operations.single.isImportedNative, isTrue);
      expect(
        copy.operations.single.nativePayload!.output,
        nativePayload('private').output,
      );
      await expectLater(
        chat.changeContextOperation(
          target,
          copy.operations.single.id,
          includeDependents: true,
          expectedState: ContextHistory.operationsFingerprint(copy.operations),
        ),
        throwsA(
          predicate(
            (Object e) => e.toString().contains(
              'native_compaction_originals_unavailable',
            ),
          ),
        ),
      );
      expect(
        (await chat.loadContextSnapshot(target)).fingerprint,
        copy.fingerprint,
      );
      expect(
        (await chat.loadContextSnapshot(
          temporary.id,
        )).messages.map((m) => m.content),
        ['secret 0', 'secret 1', 'secret 2'],
      );
      chat.setCurrentConversation(target);
      expect(chat.getConversation(temporary.id), isNull);
      final continued = await chat.loadSelectedContextMessages(
        target,
        limit: 100,
      );
      expect(continued, hasLength(2));
      expect(
        NativeCompactionPayload.forMessage(continued.first)!.output,
        nativePayload('private').output,
      );
      expect(continued.last.content, 'secret 2');
      expect(await repo.getConversation(target), isNull);
      expect(await repo.readContextOperations(target), isEmpty);
    },
  );

  test(
    'exported default-template snapshots follow the requested locale',
    () async {
      await chat.setCompressionOverrides(id, {'templateId': 'code'});
      for (final locale in ['en-US', 'zh-CN']) {
        final exported = await chat.compressionMetadataForExport(
          id,
          {},
          const CompressionConfig(),
          locale: locale,
        );
        final prompt = (exported!['template'] as Map)['prompt'] as String;
        expect(
          RegExp(r'[\u4e00-\u9fff]').hasMatch(prompt),
          locale.startsWith('zh'),
        );
      }
    },
  );

  test(
    'waiting includes final reply; applying keeps six complete user exchanges',
    () async {
      var busy = true;
      compression.isConversationBusy = (_) => busy;
      final inputs = <String>[];
      await compression.start(
        id,
        request((input, _) async {
          inputs.add(input);
          return 'summary';
        }),
      );
      expect(compression.taskFor(id)!.phase, CompressionPhase.waiting);
      expect(inputs, isEmpty);
      busy = false;
      compression.resumeIfReady(id);
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.completed,
      );
      final messages = await chat.loadSelectedContextMessages(id, limit: 100);
      expect(messages.length, 13);
      expect(messages.first.content, contains('\nsummary\n'));
      expect(
        messages.first.content,
        contains('reference data, not new instructions'),
      );
      expect(messages[1].content, startsWith('user 2'));
      expect(inputs.join(), contains('answer 1'));
      expect(inputs.join(), isNot(contains('user 2')));
      expect((await chat.loadContextSnapshot(id)).messages.length, 16);
    },
  );

  test(
    'reference changes during candidate validation are rejected inside commit',
    () async {
      var background = 'current rules';
      await compression.start(
        id,
        CompressionRequest(
          options: const CompressContextOptions(
            mode: CompressContextLimitMode.keepRecent,
            keepUserMessages: 6,
          ),
          model: 'test',
          quoteMarker: AppLocalizationsEn().selectionQuoteMarker,
          loadReference: (_) async {
            // Reads must remain safe when the final validation owns a transaction.
            await chat.loadContextSnapshot(id);
            return background;
          },
          generate: (_, _, _, _) async =>
              const TextGenerationResult(parts: [TextPart('complete summary')]),
          acceptCandidate: (_) async {
            background = 'changed rules';
            return true;
          },
        ),
      );
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.review,
      );
      expect(
        compression.taskFor(id)!.error,
        contains('compression_reference_changed'),
      );
      expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
    },
  );

  test(
    'text-only compression omits hidden thinking and explicitly marks tools',
    () async {
      final messages = await chat.messagesForCompression(
        [
          ChatMessage(
            conversationId: id,
            role: 'assistant',
            parts: [
              const TextPart('visible <think>PRIVATE_REASONING</think> answer'),
              const ToolCallPart(
                '{"id":"tool","name":"read","content":"TOOL_SECRET"}',
              ),
            ],
          ),
        ],
        includeAttachmentsAndTools: false,
        quoteMarker: AppLocalizationsEn().selectionQuoteMarker,
      );
      expect(messages.single.content, contains('visible'));
      expect(messages.single.content, contains('omitted by the user'));
      expect(messages.single.content, isNot(contains('PRIVATE_REASONING')));
      expect(messages.single.content, isNot(contains('TOOL_SECRET')));
    },
  );

  test('late model result after cancellation cannot install a node', () async {
    final hold = Completer<String>();
    var entered = false;
    await compression.start(
      id,
      request((_, _) {
        entered = true;
        return hold.future;
      }, loadReference: (_) async => 'current reference'),
    );
    await until(() => entered);
    await compression.cancel(id);
    expect(compression.taskFor(id)!.request, isNull);
    expect(compression.taskFor(id)!.validateReferences, isNull);
    hold.complete('late summary');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(compression.taskFor(id)!.phase, CompressionPhase.cancelled);
    expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
  });

  test('failed cancellation writes keep an inactive, retryable task', () async {
    final response = Completer<String>();
    await compression.start(id, request((_, _) => response.future));
    await until(
      () => compression.taskFor(id)!.phase == CompressionPhase.summarizing,
    );
    await rejectCancellationWrites();
    final failedWrite = throwsA(
      predicate(
        (Object error) => error.toString().contains('cancel write failed'),
      ),
    );
    await expectLater(compression.cancel(id), failedWrite);
    expect(compression.taskFor(id)!.phase, CompressionPhase.interrupted);
    expect(compression.blocksSending(id), isFalse);
    response.complete('late summary');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
    await rejectDismissalWrites();
    await expectLater(
      compression.dismiss(id),
      throwsA(
        predicate(
          (Object error) => error.toString().contains('dismiss write failed'),
        ),
      ),
    );
    expect(compression.taskFor(id)!.phase, CompressionPhase.interrupted);
    await database.customStatement('DROP TRIGGER reject_dismiss');
    await compression.dismiss(id);
    expect(compression.taskFor(id), isNull);
    await chat.close();
    await chat.init();
    expect(compression.taskFor(id), isNull);
  });

  test(
    'late review estimate cannot revive a cancellation whose write failed',
    () async {
      compression.estimateCandidate = (_, _, {bool? fixedContextStart}) async =>
          (usedTokens: 9000, contextWindow: 1000);
      await compression.start(id, request((_, _) async => 'summary'));
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.review,
      );
      await rejectCancellationWrites();
      final budget = Completer<CompressionBudget>();
      var entered = false;
      compression.estimateCandidate = (_, _, {bool? fixedContextStart}) {
        entered = true;
        return budget.future;
      };
      final applied = expectLater(
        compression.applyReviewed(id, 'edited summary'),
        throwsStateError,
      );
      await until(() => entered);
      await expectLater(
        compression.cancel(id),
        throwsA(
          predicate(
            (Object error) => error.toString().contains('cancel write failed'),
          ),
        ),
      );
      budget.complete((usedTokens: 100, contextWindow: 1000));
      await applied;
      expect(compression.taskFor(id)!.phase, CompressionPhase.interrupted);
      expect(compression.blocksSending(id), isFalse);
      expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
      await database.customStatement('DROP TRIGGER reject_cancel');
      await compression.dismiss(id);
      expect(compression.taskFor(id), isNull);
    },
  );

  test('source edits during generation reject the stale result', () async {
    final hold = Completer<String>();
    var entered = false;
    await compression.start(
      id,
      request((_, _) {
        entered = true;
        return hold.future;
      }),
    );
    await until(() => entered);
    final source = (await chat.loadContextSnapshot(id)).messages.first;
    await chat.updateMessage(source.id, content: 'corrected source');
    hold.complete('summary');
    await until(
      () => compression.taskFor(id)!.phase == CompressionPhase.failed,
    );
    expect(compression.taskFor(id)!.error, contains('context_changed'));
    expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
  });

  test(
    'cancel during budget check does not resurrect the review state',
    () async {
      final budget = Completer<CompressionBudget>();
      var entered = false;
      compression.estimateCandidate = (_, _, {bool? fixedContextStart}) {
        entered = true;
        return budget.future;
      };
      await compression.start(id, request((_, _) async => 'summary'));
      await until(() => entered);
      await compression.cancel(id);
      budget.complete((usedTokens: 9000, contextWindow: 1000));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(compression.taskFor(id)!.phase, CompressionPhase.cancelled);
      expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
    },
  );

  test(
    'oversized summary is editable review; double save applies only once',
    () async {
      compression.estimateCandidate = (_, _, {bool? fixedContextStart}) async =>
          (usedTokens: 9000, contextWindow: 1000);
      await compression.start(id, request((_, _) async => 'summary'));
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.review,
      );
      expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
      await expectLater(
        compression.applyReviewed(id, 'still too large'),
        throwsA(
          predicate(
            (Object error) =>
                error.toString().contains('context_budget_exceeded'),
          ),
        ),
      );
      expect(compression.taskFor(id)!.phase, CompressionPhase.review);
      expect(compression.taskFor(id)!.summary, 'still too large');
      expect(compression.taskFor(id)!.budget!.usedTokens, 9000);
      expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
      compression.estimateCandidate = (_, _, {bool? fixedContextStart}) async =>
          (usedTokens: 1000, contextWindow: 1000);
      await Future.wait([
        compression.applyReviewed(id, 'edited'),
        compression.applyReviewed(id, 'double click'),
      ]);
      expect(compression.taskFor(id)!.phase, CompressionPhase.completed);
      expect(compression.taskFor(id)!.error, isNull);
      expect(
        (await chat.loadContextOperations(id, refresh: true)).single.summary,
        'edited',
      );
    },
  );

  for (final restore in [false, true]) {
    test(
      'undo skips one turn unless its context is restored: restore=$restore',
      () async {
        await compression.start(id, request((_, _) async => 'summary'));
        await until(
          () => compression.taskFor(id)!.phase == CompressionPhase.completed,
        );
        final before = await chat.loadContextSnapshot(id);
        await chat.changeContextOperation(
          id,
          before.operations.single.id,
          includeDependents: true,
          expectedState: ContextHistory.operationsFingerprint(
            before.operations,
          ),
        );
        final undone = await chat.loadContextSnapshot(id);
        if (restore) {
          await chat.restoreContextOperations(
            id,
            before.operations,
            expectedFingerprint: undone.fingerprint,
          );
          expect(
            (await chat.loadContextSnapshot(id)).fingerprint,
            before.fingerprint,
          );
        } else {
          await expectLater(
            chat.restoreContextOperations(
              id,
              before.operations,
              expectedFingerprint: 'stale',
            ),
            throwsStateError,
          );
        }
        expect(compression.consumeAutomaticSkip(id), !restore);
        expect(compression.consumeAutomaticSkip(id), isFalse);
      },
    );
  }

  test(
    'clear requested during a reply blocks sends until the boundary is applied',
    () async {
      var busy = true;
      compression.isConversationBusy = (_) => busy;
      final clear = chat.clearConversationContext(id);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(compression.blocksSending(id), isTrue);
      expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
      busy = false;
      compression.resumeIfReady(id);
      await clear;
      expect(compression.blocksSending(id), isFalse);
      expect(await chat.loadSelectedContextMessages(id, limit: 100), isEmpty);
      expect(chat.getConversation(id)!.title, 'Original');
    },
  );

  test(
    'new-chat compression keeps source selection and original nodes unchanged',
    () async {
      final other = await chat.createConversation(title: 'Other');
      final source = await chat.loadContextSnapshot(id);
      await compression.start(
        id,
        request(
          (_, _) async => 'summary',
          options: const CompressContextOptions(
            mode: CompressContextLimitMode.keepRecent,
            keepUserMessages: 1,
            newConversation: true,
          ),
        ),
      );
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.completed,
      );
      expect(chat.currentConversationId, other.id);
      final result = compression.taskFor(id)!.resultConversationId!;
      expect((await chat.loadMessages(result)).length, 3);
      expect(
        (await chat.loadSelectedContextMessages(
          result,
          limit: 1,
        )).map((m) => m.content),
        [
          contains('\nsummary\n'),
          (await chat.loadMessages(result)).last.content,
        ],
      );
      expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
      final retained = (await chat.loadMessages(result)).last;
      await chat.updateMessage(retained.id, content: 'edited in the new chat');
      expect(
        (await chat.loadContextSnapshot(id)).fingerprint,
        source.fingerprint,
      );
    },
  );

  for (final mode in [
    CompressContextLimitMode.start,
    CompressContextLimitMode.recent,
  ]) {
    test(
      'reviewed character-window copy keeps unselected history for $mode',
      () async {
        final source = await chat.loadContextSnapshot(id);
        final options = CompressContextOptions(
          mode: mode,
          maxChars: 1,
          newConversation: true,
          previewOnly: true,
        );
        final selection = selectCompressionHistory(
          source.messages,
          source.operations,
          options,
        );
        expect(selection.retained, hasLength(15));
        await compression.start(
          id,
          request((_, _) async => 'summary', options: options),
        );
        await until(
          () => compression.taskFor(id)!.phase == CompressionPhase.review,
        );
        await compression.applyReviewed(id, 'approved summary');
        final target = compression.taskFor(id)!.resultConversationId!;
        final copied = await chat.loadMessages(target);
        expect(copied.first.content, contains('approved summary'));
        expect(
          copied.skip(1).map((m) => (m.role, m.content)),
          selection.retained.map((m) => (m.role, m.content)),
        );
        expect(
          (await chat.loadContextSnapshot(id)).fingerprint,
          source.fingerprint,
        );
      },
    );
  }

  test(
    'continuing from an installed summary leaves its compression task unchanged',
    () async {
      await compression.start(id, request((_, _) async => 'summary'));
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.completed,
      );
      final before = await chat.readCompressionTaskRecords();
      final operation = (await chat.loadContextOperations(id)).single;
      final created = await chat.continueFromContextSummary(id, operation.id);
      expect(created.id, isNot(id));
      expect(await chat.readCompressionTaskRecords(), before);
      expect(compression.taskFor(id)!.resultConversationId, isNull);
    },
  );

  test(
    'restore interrupted work exposes saved summary without starting a request',
    () async {
      var calls = 0;
      await chat.saveCompressionTaskRecord(id, {
        'id': 'interrupted',
        'options': const CompressContextOptions(
          mode: CompressContextLimitMode.unlimited,
        ).toJson(),
        'phase': 'summarizing',
        'summary': 'saved partial',
      });
      final recovered = ContextCompressionService(chat);
      await recovered.restore();
      expect(recovered.taskFor(id)!.phase, CompressionPhase.interrupted);
      expect(recovered.taskFor(id)!.summary, 'saved partial');
      expect(recovered.blocksSending(id), isFalse);
      expect(calls, 0);
      recovered.dispose();
    },
  );

  test(
    'attachment-only messages count toward N; tool output is complete text',
    () async {
      final source = await chat.addMessage(
        conversationId: id,
        role: 'user',
        parts: [const ImagePart(uri: 'image.png')],
      );
      expect(isCompressionUserMessage(source), isTrue);
      await repo.putMessagePrompt(
        revisionId: source.id,
        conversationId: id,
        payload: '',
        carriesMemorySnapshot: false,
      );
      final tool = await chat.addMessage(
        conversationId: id,
        role: 'assistant',
        parts: [
          ToolCallPart('{"name":"read_file","content":"${'a' * 10000}"}'),
        ],
      );
      final input = await chat.messagesForCompression([
        source,
        tool,
      ], quoteMarker: AppLocalizationsEn().selectionQuoteMarker);
      expect(input.first.content, contains('image content not summarized'));
      expect(input.last.content, contains('a' * 10000));
      expect(input.last.content, isNot(contains('truncated')));
    },
  );

  test(
    'compression preparation expands quote snapshots once with and without attachment prompts',
    () async {
      final quote = QuoteRef(
        id: 'q',
        messageId: 'missing',
        start: 0,
        end: 8,
        text: 'retained original',
        model: null,
        createdAt: DateTime(2026),
      );
      final message = await chat.addMessage(
        conversationId: id,
        role: 'user',
        content: 'Explain \uFFFC',
        quotes: [quote],
      );
      for (final include in [false, true]) {
        final input = await chat.messagesForCompression(
          [message],
          includeAttachmentsAndTools: include,
          quoteMarker: AppLocalizationsEn().selectionQuoteMarker,
        );
        final text = buildCompressRequestContents(
          input,
          const CompressContextOptions(
            mode: CompressContextLimitMode.unlimited,
          ),
          quoteMarker: AppLocalizationsEn().selectionQuoteMarker,
        ).join();
        expect('retained original'.allMatches(text), hasLength(1));
        expect(text, isNot(contains(quotePlaceholder)));
      }
    },
  );

  test('deleted owner never reappears when a response arrives late', () async {
    final hold = Completer<String>();
    var entered = false;
    await compression.start(
      id,
      request((_, _) {
        entered = true;
        return hold.future;
      }),
    );
    await until(() => entered);
    await chat.deleteConversation(id);
    hold.complete('late');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(compression.taskFor(id), isNull);
    expect(await repo.readCompressionTasks(), isEmpty);
    expect(chat.getConversation(id), isNull);
  });
  test(
    'shutdown cancels pending context changes without reporting them as applied',
    () async {
      compression.isConversationBusy = (_) => true;
      final outcomes = <bool>[];
      compression.onContextChangeFinished = (_, applied) =>
          outcomes.add(applied);
      final pending = chat.clearConversationContext(id);
      final rejected = expectLater(pending, throwsStateError);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await compression.cancelAll();
      await rejected;
      expect(outcomes, [false]);
      expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
    },
  );
  test(
    'graceful close restores interrupted work and rejects the late result',
    () async {
      final hold = Completer<String>();
      var entered = false;
      await compression.start(
        id,
        request((_, _) {
          entered = true;
          return hold.future;
        }),
      );
      await until(() => entered);
      await chat.close();
      await chat.init();
      expect(compression.taskFor(id)!.phase, CompressionPhase.interrupted);
      hold.complete('late summary');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(compression.taskFor(id)!.phase, CompressionPhase.interrupted);
      expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
    },
  );

  test(
    'overwriting the same source cancels the old compression before replacing rows',
    () async {
      final before = await chat.loadContextSnapshot(id);
      final source = chat.getConversation(id)!;
      final hold = Completer<String>();
      var entered = false;
      await compression.start(
        id,
        request((_, _) {
          entered = true;
          return hold.future;
        }),
      );
      await until(() => entered);
      await chat.replaceAllDataFromBackup(
        conversations: [source],
        messages: before.messages,
        toolEventsByMessageId: {},
        geminiSignaturesByMessageId: {},
      );
      hold.complete('late result against identical restored history');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(compression.taskFor(id), isNull);
      expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
    },
  );
  test(
    'in-turn safe point protects current user and streaming tool suffix',
    () async {
      final current = await chat.addMessage(
        conversationId: id,
        role: 'user',
        content: 'protected current question',
      );
      final streaming = await chat.addMessage(
        conversationId: id,
        role: 'assistant',
        content: 'active tools',
        isStreaming: true,
      );
      compression.isConversationBusy = (_) => true;
      // The complete native request callback, not the generic UI estimate,
      // owns admission at a safe point.
      compression.estimateCandidate = (_, _, {bool? fixedContextStart}) async =>
          (usedTokens: 99999, contextWindow: 4000);
      final task = await compression.runAtSafePoint(
        id,
        CompressionRequest(
          options: const CompressContextOptions(
            mode: CompressContextLimitMode.keepRecent,
            keepUserMessages: 1,
          ),
          model: 'test',
          beforeMessageId: current.id,
          automatic: true,
          acceptCandidate: (_) async => true,
          quoteMarker: (_) => 'quote',
          generate: (prompt, _, _, _) async {
            expect(prompt, isNot(contains('protected current question')));
            expect(prompt, isNot(contains('active tools')));
            await chat.updateMessage(
              streaming.id,
              content: 'tool results persisted at safe point',
            );
            return const TextGenerationResult(
              parts: [TextPart('handoff')],
              finishReason: 'stop',
            );
          },
        ),
      );
      expect(task.phase, CompressionPhase.completed);
      final effective = await chat.loadSelectedContextMessages(id, limit: 100);
      expect(
        effective.map((m) => m.id),
        containsAll([current.id, streaming.id]),
      );
      expect(effective.last.content, 'tool results persisted at safe point');
      expect(
        (await chat.loadContextOperations(id)).single.sourceGroups,
        isNot(contains(current.id)),
      );
    },
  );

  test(
    'cancellation acknowledged at apply boundary prevents the transaction',
    () async {
      void cancelOnApply() {
        if (compression.taskFor(id)?.phase == CompressionPhase.applying) {
          unawaited(compression.cancel(id));
        }
      }

      compression.addListener(cancelOnApply);
      await compression.start(id, request((_, _) async => 'summary'));
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.cancelled,
      );
      expect(await chat.loadContextOperations(id), isEmpty);
      compression.removeListener(cancelOnApply);
    },
  );

  test('trial produces a review candidate and no installed summary', () async {
    await compression.start(
      id,
      request(
        (_, _) async => 'summary',
        options: const CompressContextOptions(
          mode: CompressContextLimitMode.keepRecent,
          keepUserMessages: 2,
          previewOnly: true,
        ),
      ),
    );
    await until(
      () => compression.taskFor(id)!.phase == CompressionPhase.review,
    );
    expect(await chat.loadContextOperations(id), isEmpty);
    await compression.applyReviewed(id, 'edited candidate');
    expect(
      (await chat.loadContextOperations(id)).single.summary,
      'edited candidate',
    );
  });

  test(
    'temporary compression and new chat never persist messages, settings or jobs',
    () async {
      final temporary = await chat.createDraftConversation(
        title: 'temporary',
        temporary: true,
      );
      await chat.createConversation(title: 'temporary (1)', activate: false);
      for (var i = 0; i < 3; i++) {
        await chat.addMessage(
          conversationId: temporary.id,
          role: 'user',
          content: 'temporary secret $i ${'history ' * 100}',
        );
      }
      await chat.setCompressionOverrides(temporary.id, {
        'mode': 'auto',
        'templateId': 'research',
      });
      await compression.start(
        temporary.id,
        request(
          (_, _) async => 'temporary summary',
          options: const CompressContextOptions(
            mode: CompressContextLimitMode.keepRecent,
            keepUserMessages: 1,
            newConversation: true,
          ),
        ),
      );
      await until(
        () =>
            compression.taskFor(temporary.id)!.phase ==
            CompressionPhase.completed,
      );
      final target = compression.taskFor(temporary.id)!.resultConversationId!;
      expect(chat.isTemporaryConversation(target), isTrue);
      expect(chat.getConversation(target)!.title, 'temporary (2)');
      expect(await repo.getConversation(target), isNull);
      expect(await repo.compression.overrides(temporary.id), isEmpty);
      expect(await repo.compression.overrides(target), isEmpty);
      expect(
        await chat.compressionOverrides(target),
        containsPair('templateId', 'research'),
      );
      expect(
        await chat.readCompressionTaskRecords(),
        isNot(contains(temporary.id)),
      );
      expect((await chat.loadContextSnapshot(target)).messages.length, 2);
    },
  );
}
