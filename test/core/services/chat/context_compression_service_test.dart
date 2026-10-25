import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/compress_context_options.dart';
import 'package:Kelivo/core/models/message_part.dart';
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
  late ChatService chat;
  late String id;
  late ContextCompressionService compression;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('compression_jobs_');
    PathProviderPlatform.instance = _Paths(dir.path);
    repo = ChatDatabaseRepository.open(file: File('${dir.path}/chat.sqlite'));
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
    compression.estimateCandidate = (_, _) async =>
        (usedTokens: 100, contextWindow: 4000);
  });
  tearDown(() async {
    await chat.close();
    await repo.close();
    await dir.delete(recursive: true);
  });
  CompressionRequest request(
    Future<String> Function(String, String) generate, {
    CompressContextOptions options = const CompressContextOptions(
      mode: CompressContextLimitMode.keepRecent,
      keepUserMessages: 6,
    ),
  }) => CompressionRequest(options: options, model: 'test', generate: generate);
  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 500; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail(
      'compression did not reach expected state: ${compression.taskFor(id)?.phase}',
    );
  }

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
      expect(messages.first.content, 'summary');
      expect(messages[1].content, startsWith('user 2'));
      expect(inputs.join(), contains('answer 1'));
      expect(inputs.join(), isNot(contains('user 2')));
      expect((await chat.loadContextSnapshot(id)).messages.length, 16);
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
      }),
    );
    await until(() => entered);
    await compression.cancel(id);
    hold.complete('late summary');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(compression.taskFor(id)!.phase, CompressionPhase.cancelled);
    expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
  });

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
      compression.estimateCandidate = (_, _) {
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
      compression.estimateCandidate = (_, _) async =>
          (usedTokens: 9000, contextWindow: 1000);
      await compression.start(id, request((_, _) async => 'summary'));
      await until(
        () => compression.taskFor(id)!.phase == CompressionPhase.review,
      );
      expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
      compression.estimateCandidate = (_, _) async =>
          (usedTokens: 500, contextWindow: 1000);
      await Future.wait([
        compression.applyReviewed(id, 'edited'),
        compression.applyReviewed(id, 'double click'),
      ]);
      expect(compression.taskFor(id)!.phase, CompressionPhase.completed);
      expect(
        (await chat.loadContextOperations(id, refresh: true)).single.summary,
        'edited',
      );
    },
  );

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
      expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
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
    'attachment-only messages count toward N; tool output is bounded text',
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
      final input = await chat.messagesForCompression([source, tool]);
      expect(input.first.content, contains('image content not summarized'));
      expect(input.last.content.length, lessThan(8200));
      expect(input.last.content, contains('truncated'));
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
}
