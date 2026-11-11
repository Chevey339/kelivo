import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/search/services/global_session_search_service.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';

String _fence(String body) => '```kelivo-ui\n${UiCatalog.header}\n$body\n```';
const _body = r'''$a: number = 7
root = Column(children=[input,metric,table])
input = Slider(label="Slope",bind=$a,min=0,max=20)
metric = Metric(label="Projected total",value=$a*2)
table = DataTable(data=[{"id":"row","name":"Original data"}],rowKey="id",columns=[{"key":"name","label":"Description"}])''';

/// Keep the service's real candidate reconciliation; only omit app startup.
class _SearchService extends ChatService {
  _SearchService(this.repo, {this.candidateMultiplier = 8});
  final int candidateMultiplier;
  final ChatDatabaseRepository repo;
  @override
  Future<List<ConversationSearchMatch>> searchConversationMatches({
    required List<String> tokens,
    int limit = 200,
    bool includeAllRevisions = false,
    String? conversationId,
    String? excludeConversationId,
    String? assistantId,
  }) => repo.searchConversationMatches(
    tokens: tokens,
    limit: limit,
    candidateMultiplier: candidateMultiplier,
    includeAllRevisions: includeAllRevisions,
    conversationId: conversationId,
    excludeConversationId: excludeConversationId,
    assistantId: assistantId,
  );
}

void main() {
  late AppDatabase db;
  late ChatDatabaseRepository repo;
  late _SearchService service;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ChatDatabaseRepository(db);
    service = _SearchService(repo);
    await repo.ensureReady();
    await repo.putConversation(Conversation(id: 'c', title: 'Orion Budget'));
  });
  tearDown(() async {
    service.dispose();
    await repo.close();
  });
  Future<void> complete(String id, {String conversation = 'c'}) async {
    var run = await repo.createGenerationRun(
      id: 'run-$id',
      conversationId: conversation,
      targetRevisionId: id,
      createdAt: DateTime.now(),
    );
    for (final state in [
      GenerationRunState.requesting,
      GenerationRunState.streaming,
      GenerationRunState.completed,
    ]) {
      run = await repo.transitionGenerationRun(
        id: run.id,
        expectedState: run.state,
        expectedStateRevision: run.stateRevision,
        nextState: state,
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<void> put(
    String id,
    String text, {
    String conversation = 'c',
    List<MessagePart>? parts,
    String? group,
    int version = 0,
    bool completed = true,
    String role = 'assistant',
  }) async {
    await repo.putMessage(
      ChatMessage(
        id: id,
        conversationId: conversation,
        role: role,
        content: text,
        parts: parts,
        groupId: group,
        version: version,
      ),
    );
    if (role == 'assistant' && completed) {
      await complete(id, conversation: conversation);
    }
  }

  Future<List<GlobalSessionSearchResult>> search(String query) =>
      GlobalSessionSearchService.search(chatService: service, query: query);

  test(
    'completion seals unseen initial computed values and global reconciliation uses them',
    () async {
      await put('r', 'Ordinary conclusion\n${_fence(_body)}');
      final stored = await db.select(db.genUiSurfaceStateRows).getSingle();
      expect(stored.searchText, contains('Projected total: 14'));
      final match = (await repo.searchConversationMatches(
        tokens: ['14'],
      )).single;
      expect(match.messageContent, isNot(contains('Projected total: 14')));
      expect(match.searchableText, contains('Projected total: 14'));
      expect(match.searchableText, isNot(contains('root =')));
      expect(match.matchedSurfaceKey, '0:0');
      final result = (await search('14')).single;
      expect(result.firstMatchedMessageId, 'r');
      expect(result.matchedSurfaceKey, '0:0');
      expect(result.snippet, contains('14'));
      expect(await search('rowKey'), isEmpty);
      expect(await repo.searchMiniMapMatches('c', 'rowKey'), isEmpty);
    },
  );
  test(
    'every token may match title, prose or separate surfaces before deduplication and LIMIT',
    () async {
      await put(
        'r',
        'Ordinary conclusion\n${_fence('root = Metric(label="Alpha",value=3*7)')}\n${_fence('root = Metric(label="Beta",value=4*7)')}',
      );
      for (final query in [
        'Orion 21',
        'conclusion 28',
        '21 28',
        'Orion conclusion 21 28',
      ]) {
        final result = await search(query);
        expect(result.map((r) => r.conversationId), ['c'], reason: query);
      }
      final results = await repo.searchConversationMatches(
        tokens: ['21', '28'],
        limit: 1,
        candidateMultiplier: 1,
      );
      expect(results.map((r) => r.messageId), ['r']);
    },
  );
  test(
    'CJK LIKE combines sources and escapes percent/underscore literally',
    () async {
      await put('r', '本月概览\n${_fence('root = Text(text="净利润增长50%_达标")')}');
      expect((await search('概览 净利润')).single.conversationId, 'c');
      expect((await search('净利润 50%_')).single.firstMatchedMessageId, 'r');
      expect(await search('净利润 51%_'), isEmpty);
      final mini = (await repo.searchMiniMapMatches('c', '净利润')).single;
      expect(mini.matchedSurfaceKey, '0:0');
      expect(mini.snippet, contains('净利润'));
      expect(mini.searchableText, isNot(contains('Text(text=')));
    },
  );
  test(
    'initial search survives changed inputs/view and a missing/corrupt cache without touching save time',
    () async {
      await put('r', _fence(_body));
      final controller = UiSurfaceController(
        owner: const UiSurfaceOwner(revisionId: 'r', surfaceKey: '0:0'),
      );
      controller.updateSource(
        '${UiCatalog.header}\n$_body\n',
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      addTearDown(controller.dispose);
      controller.setInputs({'a': 9}, token: controller.token);
      controller.setView('table', {
        'filter': 'Nothing',
        'pageSize': 20,
      }, token: controller.token);
      final lease = repo.genUiStates.attach(
        'c',
        controller.owner,
        controller.sourceHash!,
      )!;
      repo.genUiStates.accept(lease, controller.captureSnapshot());
      await repo.genUiStates.flush();
      final before = await db.select(db.genUiSurfaceStateRows).getSingle();
      expect(before.stateJson, contains('Nothing'));
      expect((await search('14')).single.firstMatchedMessageId, 'r');
      expect(await search('18'), isEmpty);
      await db
          .update(db.genUiSurfaceStateRows)
          .write(
            const GenUiSurfaceStateRowsCompanion(searchText: Value('poison')),
          );
      await db.customStatement('DROP TABLE gen_ui_surface_search');
      await repo.rebuildGenUiSearchIndex();
      final after = await db.select(db.genUiSurfaceStateRows).getSingle();
      expect(after.stateJson, before.stateJson);
      expect(after.updatedAt, before.updatedAt);
      expect(after.stateVersion, before.stateVersion);
      expect(after.searchText, contains('Projected total: 14'));
      expect(after.searchText, contains('Original data'));
      expect(await search('poison'), isEmpty);
      expect((await search('14')).single.firstMatchedMessageId, 'r');
    },
  );
  test(
    'restored rows without a cache are searchable before any widget is created',
    () async {
      await put('r', _fence(_body));
      await db.delete(db.genUiSurfaceStateRows).go();
      final match = (await search('14')).single;
      expect(match.firstMatchedMessageId, 'r');
      expect(await db.select(db.genUiSurfaceStateRows).get(), hasLength(1));
    },
  );
  test(
    'selected revision and scope filters precede final candidate limit',
    () async {
      await put(
        'v1',
        _fence('root = Metric(label="Older",value=3*7)'),
        group: 'slot',
        version: 1,
      );
      await put(
        'v2',
        _fence('root = Metric(label="Current",value=4*7)'),
        group: 'slot',
        version: 2,
      );
      expect(await search('21'), isEmpty);
      expect((await search('28')).single.firstMatchedMessageId, 'v2');
      expect(
        (await repo.searchConversationMatches(
          tokens: ['21'],
          includeAllRevisions: true,
        )).single.messageId,
        'v1',
      );
      expect(
        await repo.searchConversationMatches(
          tokens: ['28'],
          excludeConversationId: 'c',
          limit: 1,
          candidateMultiplier: 1,
        ),
        isEmpty,
      );
      await repo.putConversation(
        Conversation(id: 'other', title: 'Other', assistantId: 'someone'),
      );
      await put(
        'other-r',
        _fence('root = Metric(label="Elsewhere",value=4*7)'),
        conversation: 'other',
      );
      expect(
        (await repo.searchConversationMatches(
          tokens: ['28'],
          conversationId: 'c',
          limit: 1,
          candidateMultiplier: 1,
        )).single.messageId,
        'v2',
      );
      expect(
        (await repo.searchConversationMatches(
          tokens: ['28'],
          assistantId: 'wanted',
        )).map((r) => r.conversationId),
        ['c'],
      );
    },
  );
  test(
    'source mapping handles a split language tag, nontext boundaries and CRLF',
    () async {
      final source = _fence(_body).replaceAll('\n', '\r\n');
      await put(
        'r',
        '',
        parts: [
          const TextPart('```kelivo-'),
          TextPart(source.substring('```kelivo-'.length)),
        ],
      );
      await db.delete(db.genUiSurfaceStateRows).go();
      final match = (await search('14')).single;
      expect(match.matchedSurfaceKey, '0:0');
      expect(match.snippet, contains('14'));
    },
  );
  test(
    'user, nested and unproved UI never activate or invent computed data',
    () async {
      await put('user', _fence(_body), role: 'user');
      await put(
        'quote',
        _fence(_body).split('\n').map((l) => '> $l').join('\n'),
      );
      await put('unknown', _fence(_body), completed: false);
      expect(await search('14'), isEmpty);
      expect(await db.select(db.genUiSurfaceStateRows).get(), isEmpty);
    },
  );
  test(
    'table indexes bounded initial rows with an explicit omission notice',
    () async {
      final data = [
        for (var i = 0; i < 100; i++) {'id': 'row$i', 'name': 'value$i'},
      ];
      await put(
        'r',
        _fence(
          'root = DataTable(data=${jsonEncode(data)},rowKey="id",columns=[{"key":"name","label":"Description"}])',
        ),
      );
      final row = await db.select(db.genUiSurfaceStateRows).getSingle();
      expect(
        utf8.encode(row.searchText).length,
        lessThanOrEqualTo(UiBudgets.searchTextBytes),
      );
      expect(row.searchText, contains('not included in search'));
      expect((await search('value0')).single.firstMatchedMessageId, 'r');
      expect(await search('value99'), isEmpty);
    },
  );
  test('parent deletion leaves no derived FTS rows', () async {
    await put('r', _fence(_body));
    await search('14');
    await repo.deleteMessages(
      conversationId: 'c',
      messageIds: {'r'},
      versionSelectionChanges: const {},
    );
    expect(await db.select(db.genUiSurfaceStateRows).get(), isEmpty);
    expect(
      await db.customSelect('SELECT rowid FROM gen_ui_surface_search').get(),
      isEmpty,
    );
    expect(await search('14'), isEmpty);
  });
  test(
    'literal UI metadata-looking text remains visible while prose metadata stays hidden',
    () async {
      await put(
        'r',
        '<reasoning>PrivateNeedle</reasoning>\n${_fence('root = Text(text="<think>VisibleNeedle</think>")')}',
      );
      expect((await search('VisibleNeedle')).single.firstMatchedMessageId, 'r');
      expect(await search('PrivateNeedle'), isEmpty);
    },
  );
  test(
    'metadata-only visibility and streaming changes refresh an already initialized index',
    () async {
      await put(
        'r',
        '<think>\n\n${_fence('root = Metric(label="Visible result",value=3*7)')}\n\n</think>',
      );
      expect(await search('21'), isEmpty);
      await repo.updateMessageFields(
        'r',
        reasoningSegmentsJson: jsonEncode({
          'v': 2,
          'segments': [
            {'text': 'Provider reasoning'},
          ],
        }),
      );
      expect((await search('21')).single.firstMatchedMessageId, 'r');
      await repo.updateMessageFields('r', isStreaming: true);
      expect(await search('21'), isEmpty);
      await repo.updateMessageFields('r', isStreaming: false);
      expect((await search('21')).single.firstMatchedMessageId, 'r');
      await repo.updateMessageFields(
        'r',
        reasoningSegmentsJson: '{"v":2,"segments":[]}',
      );
      expect(await search('21'), isEmpty);
    },
  );
  test(
    'source-only hits never consume the final visible candidate limit',
    () async {
      // Cross a raw SQL page boundary as well as the final one-result boundary.
      for (var i = 0; i < 66; i++) {
        await put('dsl-$i', _fence('root = Metric(label="A",value=1)'));
      }
      await put('visible', _fence('root = Text(text="Metric")'));
      final matches = await repo.searchConversationMatches(
        tokens: ['Metric'],
        limit: 1,
        candidateMultiplier: 1,
      );
      expect(matches.single.messageId, 'visible');
      expect(matches.single.searchableText, 'Metric');
      expect((await search('Metric')).single.firstMatchedMessageId, 'visible');
    },
  );
  test(
    'a DSL-only candidate can still yield a genuine title-only result',
    () async {
      await repo.putConversation(Conversation(id: 'c', title: 'Metric'));
      await put('r', _fence('root = Metric(label="A",value=1)'));
      final match = (await repo.searchConversationMatches(
        tokens: ['Metric'],
        limit: 1,
        candidateMultiplier: 1,
      )).single;
      expect(match.messageId, isNull);
      expect(match.searchableText, isNull);
      expect((await search('Metric')).single.titleMatched, isTrue);
    },
  );
  test('251 query tokens do not exceed a compound SELECT ceiling', () async {
    final tokens = List.generate(251, (i) => 'term$i');
    await put('r', tokens.join(' '), role: 'user');
    final matches = await repo.searchConversationMatches(
      tokens: tokens,
      limit: 1,
      candidateMultiplier: 1,
    );
    expect(matches.single.messageId, 'r');
  });
  test(
    'real final checkpoint indexes only after durable completed evidence',
    () async {
      final message = ChatMessage(
        id: 'r',
        conversationId: 'c',
        role: 'assistant',
        isStreaming: true,
        content: _fence('root = Metric(label="Total",value=3*7)'),
      );
      await repo.putMessage(message);
      var run = await repo.createGenerationRun(
        id: 'run-r',
        conversationId: 'c',
        targetRevisionId: 'r',
        createdAt: DateTime.now(),
      );
      for (final state in [
        GenerationRunState.requesting,
        GenerationRunState.streaming,
      ]) {
        run = await repo.transitionGenerationRun(
          id: run.id,
          expectedState: run.state,
          expectedStateRevision: run.stateRevision,
          nextState: state,
          updatedAt: DateTime.now(),
        );
      }
      expect(await search('21'), isEmpty);
      await repo.finalizeGenerationRun(
        message: message.copyWith(isStreaming: false),
        toolEvents: const [],
        generationRunId: run.id,
        expectedState: run.state,
        expectedStateRevision: run.stateRevision,
        terminalState: GenerationRunState.completed,
      );
      expect((await search('21')).single.firstMatchedMessageId, 'r');
    },
  );
  test(
    'duplicating a never displayed completed message seals a searchable target',
    () async {
      await put('r', _fence('root = Metric(label="Total",value=3*7)'));
      final copy = (await repo.duplicateConversation('c'))!;
      final match = (await repo.searchConversationMatches(
        tokens: ['21'],
        conversationId: copy.id,
      )).single;
      expect(match.messageId, isNot('r'));
      expect(match.searchableText, contains('Total: 21'));
      expect(match.matchedSurfaceKey, '0:0');
    },
  );
  test(
    'bounded candidates retain new keyword evidence beyond duplicate early hits',
    () async {
      await put('a1', _fence('root = Text(text="Alpha")'));
      await put('a2', _fence('root = Text(text="Alpha")'));
      await put('b', _fence('root = Text(text="Beta")'));
      final matches = await repo.searchConversationMatches(
        tokens: ['Alpha', 'Beta'],
        limit: 2,
        candidateMultiplier: 1,
      );
      expect(matches.map((m) => m.messageId), ['a1', 'b']);
      expect(
        matches.every((m) => m.verifiedTokens.containsAll({'alpha', 'beta'})),
        isTrue,
      );
    },
  );
  test(
    'conversation evidence survives a cap smaller than its matching message count',
    () async {
      await put('plain', 'Alpha', role: 'user');
      await put('ui', _fence('root = Text(text="Beta")'));
      final limited = _SearchService(repo, candidateMultiplier: 1);
      addTearDown(limited.dispose);
      final matches = await GlobalSessionSearchService.search(
        chatService: limited,
        query: 'Alpha Beta',
        limit: 1,
      );
      expect(matches.single.conversationId, 'c');
      expect(matches.single.firstMatchedMessageId, 'plain');
      expect(matches.single.snippet, contains('Alpha'));
    },
  );
  test(
    'title-only fallback does not duplicate a later body hit and consume another conversation slot',
    () async {
      await repo.putConversation(
        Conversation(id: 'c', title: 'Metric', updatedAt: DateTime.utc(2026)),
      );
      await put('dsl', _fence('root = Metric(label="A",value=1)'));
      await put('visible', _fence('root = Text(text="Metric")'));
      await repo.putConversation(
        Conversation(id: 'd', title: 'Other', updatedAt: DateTime.utc(2020)),
      );
      await put(
        'other-r',
        _fence('root = Text(text="Metric")'),
        conversation: 'd',
      );
      final matches = await repo.searchConversationMatches(
        tokens: ['Metric'],
        limit: 2,
        candidateMultiplier: 1,
      );
      expect(matches.map((m) => m.messageId), ['visible', 'other-r']);
    },
  );
  test(
    'filtered early rows cannot skip the rest of a raw candidate page',
    () async {
      await repo.putConversation(
        Conversation(id: 'c', title: 'First', updatedAt: DateTime.utc(2026)),
      );
      await put('hidden', '<think>Metric</think>');
      await put('visible', _fence('root = Text(text="Metric")'));
      await repo.putConversation(
        Conversation(id: 'd', title: 'Second', updatedAt: DateTime.utc(2020)),
      );
      await put(
        'next',
        _fence('root = Text(text="Metric")'),
        conversation: 'd',
      );
      final matches = await repo.searchConversationMatches(
        tokens: ['Metric'],
        limit: 2,
        candidateMultiplier: 1,
      );
      expect(matches.map((m) => m.messageId), ['visible', 'next']);
    },
  );
  test(
    'minimap snippets never split an emoji at either projected boundary',
    () async {
      await put('r', _fence('root = Text(text="🙂🙂Target🙂🙂")'));
      final hit = (await repo.searchMiniMapMatches(
        'c',
        'Target',
        snippetRadius: 1,
        snippetLength: 7,
      )).single;
      expect(hit.snippet, 'Target');
      expect(hit.matchedSurfaceKey, '0:0');
    },
  );
}
