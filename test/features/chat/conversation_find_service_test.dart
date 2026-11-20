import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/assistant_regex.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/chat/models/conversation_find_candidate.dart';
import 'package:Kelivo/features/chat/services/conversation_find_service.dart';

void main() {
  ChatMessage message(
    String body, {
    String role = 'user',
    String? translation,
    List<MessagePart>? parts,
    String? reasoning,
  }) => ChatMessage(
    id: 'm',
    conversationId: 'c',
    role: role,
    content: body,
    parts: parts,
    translation: translation,
    reasoningText: reasoning,
  );
  Future<List<ConversationFindHit>> search(
    ChatMessage m,
    String q, {
    bool whole = false,
    bool matchCase = false,
    bool thinking = false,
    ConversationFindService service = const ConversationFindService(),
  }) async {
    final result = await service.search(
      Stream.value([ConversationFindCandidate(m)]),
      q,
      (matchCase: matchCase, wholeWord: whole, thinking: thinking),
    );
    return result['m'] ?? const [];
  }

  test(
    'full Unicode folding preserves original UTF-16 spans and scalar boundaries',
    () async {
      final m = message('🙂 Straße STRASSE ς σ ДОМ ﬃ 𐐀');
      final hits = await search(m, 'strasse');
      expect(hits.map((h) => h.range.slice(m.content)), ['Straße', 'STRASSE']);
      expect(await search(m, 'strasse', matchCase: true), isEmpty);
      expect(await search(m, 'Σ'), hasLength(2));
      expect(await search(m, 'дом'), hasLength(1));
      expect(await search(m, '𐐨'), hasLength(1));
      expect((await search(m, 'ffi')).single.range.length, 1);
      expect(await search(message('ß'), 's'), isEmpty);
      expect(await search(message('sß'), 'ss'), hasLength(1));
    },
  );
  test(
    'word boundaries use Unicode letters and marks; Han, kana, Hangul use substrings',
    () async {
      final m = message('cat catalog Ωcat cat1 cat_ cat\u0301. 猫猫 カタカナ 한글');
      expect(await search(m, 'cat', whole: true), hasLength(1));
      for (final q in ['猫', 'タ', '한']) {
        expect(await search(m, q, whole: true), await search(m, q));
      }
      expect(await search(m, '  '), isEmpty);
    },
  );
  test(
    'visual regex, sanitized Markdown and translation offsets match the renderer',
    () async {
      final assistant = Assistant(
        id: 'a',
        name: 'a',
        regexRules: const [
          AssistantRegex(
            id: 'r',
            name: 'r',
            pattern: 'xxx',
            replacement: 'word WORD',
            visualOnly: true,
            scopes: [AssistantRegexScope.assistant],
          ),
        ],
      );
      final service = ConversationFindService(assistant: assistant);
      final m = message(
        'xxx **bold** [label](https://hidden.invalid)',
        role: 'assistant',
        translation: 'xxx',
      );
      final hits = await search(m, 'word', service: service);
      expect(hits.map((h) => (h.part, h.range.start)), [
        (FindPart.body, 0),
        (FindPart.body, 5),
        (FindPart.translation, 0),
        (FindPart.translation, 5),
      ]);
      expect(await search(m, 'hidden.invalid', service: service), isEmpty);
      expect(await search(m, 'xxx', service: service), isEmpty);
      expect(
        (await search(message('🙂\ud800 tail'), '�')).single.range.start,
        2,
      );
      expect(
        await search(
          message('', role: 'assistant', translation: 'Loading translation'),
          'Loading',
          service: const ConversationFindService(
            translationPlaceholder: 'Loading translation',
          ),
        ),
        isEmpty,
      );
    },
  );
  test(
    'structured and inline reasoning enter the index once in displayed step order',
    () async {
      final m = message(
        '',
        role: 'assistant',
        reasoning: '\rprivate',
        parts: const [
          ReasoningPart('  \rprivate  '),
          TextPart('public'),
          ReasoningPart('private again'),
          ToolCallPart(
            '{"id":"t","name":"tool","arguments":{"q":"private"},"content":"private"}',
          ),
        ],
      );
      expect(await search(m, 'private'), isEmpty);
      final hits = await search(m, 'private', thinking: true);
      expect(hits.map((h) => h.part), [FindPart.reasoning, FindPart.reasoning]);
      expect(hits.map((h) => h.range.start), [0, 0]);
      expect(hits[0].block, isNot(hits[1].block));
      final inline = message('<think>private</think>public', role: 'assistant');
      expect(await search(inline, 'private'), isEmpty);
      expect(
        (await search(inline, 'private', thinking: true)).single.part,
        FindPart.reasoning,
      );
      final unfinished = message('<think>needle', role: 'assistant');
      expect(
        (await search(unfinished, 'needle', thinking: true)).single.part,
        FindPart.body,
      );
    },
  );
  test(
    'matches rendered inline phrases without joining list items or table cells',
    () async {
      final m = message(
        '- alpha\n- beta\n\n| gamma | delta |\n| --- | --- |\n| a | b |\n\nA **bright** star',
      );
      expect(await search(m, 'alphabeta'), isEmpty);
      expect(await search(m, 'gammadelta'), isEmpty);
      expect(await search(m, 'bright star'), hasLength(1));
    },
  );
  test(
    'uncached native and web cards search their labels, plain text searches the source',
    () async {
      const plain = ConversationFindService(assistantMarkdown: false);
      final native = message(
        '```kelivo-ui\n${UiCatalog.header}\nroot = Metric(label="Revenue",value=3*7)\n```',
        role: 'assistant',
      )..hydrateGenerationState(GenerationRunState.completed);
      expect((await search(native, 'Revenue')).single.part, FindPart.surface);
      expect((await search(native, '21')).single.surfaceKey, '0:0');
      expect(await search(native, 'root ='), isEmpty);
      expect(
        (await search(native, 'root =', service: plain)).single.part,
        FindPart.body,
      );
      expect(await search(native, '21', service: plain), isEmpty);
      final web = message(
        '```kelivo-web\n{"version":1,"title":"Report","summary":"Open charts"}\n<p>hidden-source</p>\n```',
        role: 'assistant',
      )..hydrateGenerationState(GenerationRunState.completed);
      expect((await search(web, 'charts')).single.surfaceKey, 'web:0:0');
      expect(await search(web, 'hidden-source'), isEmpty);
      expect(
        (await search(web, 'hidden-source', service: plain)).single.part,
        FindPart.body,
      );
      final overLimit = message(
        List.filled(4, web.content).join('\n\n'),
        role: 'assistant',
      );
      expect(
        (await search(overLimit, 'hidden-source')).single.part,
        FindPart.body,
      );
    },
  );
  test(
    'citation chips search their displayed index and keep ordinary literal code',
    () async {
      final m = message(
        '',
        role: 'assistant',
        parts: const [
          TextPart('See [cite:doc42], [cite:missing] and `[cite:literal]`.'),
          ToolCallPart(
            '{"name":"search_web","content":"{\\"items\\":[{\\"id\\":\\"doc42\\",\\"index\\":7}]}"}',
          ),
        ],
      );
      expect(
        (await search(m, '7')).single.range.slice(m.content),
        '[cite:doc42]',
      );
      expect(
        (await search(m, '?')).single.range.slice(m.content),
        '[cite:missing]',
      );
      expect(await search(m, 'doc42'), isEmpty);
      expect((await search(m, 'cite:')).single.range.slice(m.content), 'cite:');
    },
  );
  test('reference links resolve inside each displayed bubble document', () async {
    const split = ConversationFindService(splitAssistantParagraphs: true);
    final m = message(
      '[link][ref]\n\n[ref]: https://example.org',
      role: 'assistant',
    );
    expect(await search(m, 'ref'), isEmpty);
    expect(
      (await search(m, 'ref', service: split)).single.range.start,
      m.content.indexOf('ref'),
    );
    final withCard = message(
      '[link][ref]\n\n```kelivo-ui\n${UiCatalog.header}\nroot = Text(text="revenue")\n```\n\n[ref]: https://example.org',
      role: 'assistant',
    )..hydrateGenerationState(GenerationRunState.completed);
    expect(await search(withCard, 'ref'), isEmpty);
    expect((await search(withCard, 'revenue')).single.part, FindPart.surface);
  });
  test(
    'a visual regex that nests an original Web fence exposes its literal code',
    () async {
      final assistant = Assistant(
        id: 'a',
        name: 'a',
        regexRules: const [
          AssistantRegex(
            id: 'r',
            name: 'r',
            pattern: 'prefix',
            replacement: '```text',
            visualOnly: true,
            scopes: [AssistantRegexScope.assistant],
          ),
        ],
      );
      final m = message(
        'prefix\n\n```kelivo-web\n{"version":1,"title":"Report","summary":"Charts"}\n<p>visibleHTML</p>\n```',
        role: 'assistant',
      )..hydrateGenerationState(GenerationRunState.completed);
      final service = ConversationFindService(assistant: assistant);
      expect(
        (await search(m, 'visibleHTML', service: service)).single.part,
        FindPart.body,
      );
      expect(
        (await search(m, 'Report', service: service)).single.surfaceKey,
        isNull,
      );
    },
  );
  test('all frequent hits in a long row remain navigable', () async {
    final hits = await search(message('的' * 18000), '的');
    expect(hits, hasLength(18000));
    expect(hits.last.range.start, 17999);
  });

  test(
    'minimap previews count the whole message and highlight nearby hits',
    () async {
      const service = ConversationFindService();
      final user = ConversationFindCandidate(
        message('先说 **知豆**，再说知豆。${'前文' * 50}知豆。\n\n然后说知豆。'),
      );
      final assistant = ConversationFindCandidate(
        ChatMessage(
          id: 'reply',
          role: 'assistant',
          conversationId: 'c',
          content: '${'开头' * 110}\n\n然后提到 **知豆** 的价格。',
          translation: '译文也提到知豆。',
        ),
      );
      final batches = await service
          .searchPreviews(
            Stream.fromIterable([
              [user],
              [assistant],
            ]),
            '知豆',
          )
          .toList();
      expect(batches.map((batch) => batch.single.role), ['user', 'assistant']);
      final userPreview = batches.first.single;
      final assistantPreview = batches.last.single;
      expect(userPreview.matchCount, 4);
      expect(
        userPreview.segments
            .where((segment) => segment.highlighted)
            .map((segment) => segment.text),
        ['知豆', '知豆'],
      );
      expect(assistantPreview.matchCount, 2);
      expect(assistantPreview.before, '然后提到 ');
      expect(
        assistantPreview.segments.map((segment) => segment.text).join(),
        '知豆 的价格。',
      );
      final matches = await service.search(
        Stream.value([user, assistant]),
        '知豆',
        defaultFindOptions,
      );
      expect(userPreview.hit, matches['m']!.first);
      expect(userPreview.matchCount, matches['m']!.length);
      expect(assistantPreview.hit, matches['reply']!.first);
      expect(assistantPreview.matchCount, matches['reply']!.length);
    },
  );

  test(
    'cached rendered text follows edits and presentation settings',
    () async {
      const markdown = ConversationFindService();
      const plain = ConversationFindService(userMarkdown: false);
      final cache = ConversationFindCache();
      Future<List<ConversationFindHit>> query(
        ChatMessage row,
        String word, [
        ConversationFindService service = markdown,
      ]) async {
        final result = await service.search(
          Stream.value([ConversationFindCandidate(row)]),
          word,
          defaultFindOptions,
          cache: cache,
        );
        return result['m']!;
      }

      final first = message('**old** [label](https://hidden.invalid)');
      expect(await query(first, 'missing'), isEmpty);
      expect(await query(first, 'hidden.invalid'), isEmpty);
      expect(await query(first, 'old'), hasLength(1));
      expect(await query(first, 'hidden.invalid', plain), hasLength(1));
      final edited = message('**new**');
      expect(await query(edited, 'NEW', plain), hasLength(1));
      expect(await query(edited, 'old', plain), isEmpty);
    },
  );
}
