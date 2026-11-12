import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/search/services/global_session_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Chat extends ChatService {
  List<ConversationSearchMatch> matches = [];
  @override
  Future<List<ConversationSearchMatch>> searchConversationMatches({
    required List<String> tokens,
    int limit = 200,
    bool includeAllRevisions = false,
    String? conversationId,
    String? excludeConversationId,
    String? assistantId,
  }) async => matches;
}

ConversationSearchMatch match(
  String id,
  String body, {
  String title = 'Session',
  String conversation = 'c',
  String role = 'assistant',
  String? surface,
  int version = 0,
  int maxVersion = 0,
  Set<String> verified = const {},
}) => ConversationSearchMatch(
  conversationId: conversation,
  conversationTitle: title,
  updatedAt: DateTime(2026),
  versionSelections: const {},
  messageId: id,
  messageContent: body,
  searchableText: body,
  messageRole: role,
  groupId: id,
  version: version,
  maxVersion: maxVersion,
  matchedSurfaceKey: surface,
  verifiedTokens: verified,
);

void main() {
  late _Chat chat;
  setUp(() => chat = _Chat());
  tearDown(() => chat.dispose());
  Future<List<GlobalSessionSearchResult>> search(String query) =>
      GlobalSessionSearchService.search(chatService: chat, query: query);

  test(
    'tokens across different messages preserve score, first hit and context',
    () async {
      chat.matches = [
        match('before', 'context'),
        match('first', 'Alpha alpha'),
        match('second', 'OMEGA'),
      ];
      final result = (await search('alpha omega alpha')).single;
      expect(result.score, 50);
      expect(result.firstMatchedMessageId, 'first');
      expect(result.snippet, 'context  Alpha alpha  OMEGA');
      expect(result.titleMatched, isFalse);
      expect(await search('alpha absent'), isEmpty);
    },
  );

  test(
    'title-only hits use the first visible message as their jump target',
    () async {
      chat.matches = [match('m', 'ordinary body', title: 'ALPHA alpha')];
      final result = (await search('alpha')).single;
      expect(result.score, 60);
      expect(result.firstMatchedMessageId, 'm');
      expect(result.snippet, 'ALPHA alpha');
      expect(result.titleMatched, isTrue);
    },
  );

  test(
    'verified tokens, GenUI target and version visibility are preserved',
    () async {
      chat.matches = [
        match('hidden', 'alpha alpha', maxVersion: 1),
        match('tool', 'alpha', role: 'tool'),
        match(
          'visible',
          'Alpha in a card',
          surface: 'surface-1',
          verified: {'omega'},
        ),
      ];
      final result = (await search('alpha omega')).single;
      expect(result.score, 10);
      expect(result.firstMatchedMessageId, 'visible');
      expect(result.matchedSurfaceKey, 'surface-1');
      expect(result.snippet, 'Alpha in a card');
    },
  );

  test('normalization and ranking retain repeated-token weights', () async {
    chat.matches = [
      match('m1', 'alpha\n\t beta\r\n alpha', conversation: 'body'),
      match('m2', '', title: 'alpha beta', conversation: 'title'),
      match('m3', 'alpha', conversation: 'partial'),
    ];
    final results = await search('alpha beta alpha');
    expect(results.map((r) => r.conversationId), ['title', 'body']);
    expect(results.map((r) => r.score), [90, 50]);
    expect(results.last.snippet, 'alpha beta alpha');
  });

  test('tokens never cross the boundary between messages', () async {
    chat.matches = [match('a', 'hel'), match('b', 'lo')];
    expect(await search('hello'), isEmpty);
  });
}
