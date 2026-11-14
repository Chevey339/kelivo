import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/carried_original.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/compress_context_options.dart';
import 'package:Kelivo/core/models/compression_config.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/native_compaction.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/request_history_context.dart';
import 'package:Kelivo/core/services/api/request_token_estimate.dart';

void main() {
  ChatMessage message(String id, {String? text, List<MessagePart>? parts}) =>
      ChatMessage(
        id: id,
        role: id.endsWith('u') ? 'user' : 'assistant',
        content: parts == null ? text ?? id : null,
        parts: parts,
        conversationId: 'chat',
      );
  List<ChatMessage> rounds(String letters) => [
    for (final l in letters.split('')) ...[message('${l}u'), message('${l}a')],
  ];
  CompressionSelection range(
    List<ChatMessage> messages, {
    List<ContextOperation> operations = const [],
    int keep = 3,
  }) => selectCompressionHistory(
    messages,
    operations,
    CompressContextOptions(
      mode: CompressContextLimitMode.keepRecent,
      keepUserMessages: keep,
    ),
  );
  CarrySelection choose(
    List<ChatMessage> messages, {
    List<ContextOperation> operations = const [],
    int keep = 3,
    int count = 1,
    bool all = false,
    int? budget,
    Set<String> excluded = const {},
    Set<String> replies = const {},
    bool earlier = false,
  }) => selectCarriedOriginals(
    messages: messages,
    operations: operations,
    selection: range(messages, operations: operations, keep: keep),
    setting: CarrySetting(
      mode: all ? CarryMode.all : CarryMode.count,
      count: count,
    ),
    fromSummaries: earlier,
    excluded: excluded,
    replies: replies,
    budgetTokens: budget,
    count: (i) => countCarriedTokens(i, ProviderKind.openai),
  );
  ContextOperation operation(
    String id,
    List<ChatMessage> source,
    CarrySelection carry, {
    List<ContextOperation> operations = const [],
    int keep = 3,
  }) {
    final selection = range(source, operations: operations, keep: keep);
    return ContextOperation(
      id: id,
      kind: ContextOperationKind.compress,
      anchorGroupId: selection.covered.last.id,
      appliedAfterGroupId: source.last.id,
      sourceGroups: selection.covered.map((m) => m.id).toList(),
      dependencies: selection.dependencies,
      createdAt: DateTime.now(),
      summary: 'summary-$id',
      originalSummary: 'summary-$id',
    ).withCarried(carry.freeze(const CarrySetting(mode: CarryMode.count)));
  }

  test('settings and single-use choices round-trip independently', () {
    expect(CompressionConfig.fromJson({}).carryOriginals.mode, CarryMode.unset);
    expect(
      CompressionConfig.fromJson({}).nativeCarryOriginals.mode,
      CarryMode.unset,
    );
    for (final count in [0, 10001]) {
      expect(
        () => CompressionConfig.fromJson({
          'carryOriginals': {'mode': 'count', 'count': count},
        }),
        throwsFormatException,
      );
    }
    const opts = CompressContextOptions(
      mode: CompressContextLimitMode.unlimited,
      carry: CarrySetting(mode: CarryMode.count, count: 2),
      carryReplies: ['Bu'],
      carryExcluded: ['Au'],
      carryFromSummaries: true,
    );
    expect(
      CompressContextOptions.fromJson(opts.toJson()).toJson(),
      opts.toJson(),
    );
  });
  test('T2-T4 covered users only; exclusions do not backfill', () {
    final m = rounds('ABCDE');
    expect(choose(m).items.map((i) => i.text), ['Bu']);
    expect(choose(m, count: 5).rows.map((r) => r.item.text), ['Bu', 'Au']);
    final excluded = choose(m, count: 2, excluded: {'Bu'});
    expect(excluded.items.map((i) => i.text), ['Au']);
    expect(excluded.rows.first.selected, false);
  });
  test(
    'text boundary uses remaining budget; media boundary is not backfilled',
    () {
      final m = [
        message('Au', text: 'head ${'word ' * 2000}tail'),
        message('Aa'),
        ...rounds('BCDE'),
      ];
      final budget =
          countCarriedTokens(carriedFromMessage(m[2]), ProviderKind.openai) +
          110;
      final selected = choose(m, all: true, budget: budget);
      expect(selected.items.first.truncated, true);
      expect(
        selected.items.first.text,
        allOf(startsWith('head'), endsWith('tail'), contains('[…truncated…]')),
      );
      expect(selected.totalTokens, lessThanOrEqualTo(budget));
      final media = [
        message(
          'Au',
          parts: [
            const TextPart('text'),
            const ImagePart(uri: '/image.png'),
          ],
        ),
        ...m.skip(1),
      ];
      final stopped = choose(media, all: true, budget: budget);
      expect(stopped.items.map((i) => i.text), ['Bu']);
      expect(stopped.notFit, 1);
    },
  );
  test('count never truncates, unknown windows are unrestricted', () {
    final m = rounds('ABCDE');
    final one = choose(m).totalTokens;
    final over = choose(m, count: 3, budget: one);
    expect(over.overBudget, true);
    expect(over.fitCount, 1);
    expect(over.items.any((i) => i.truncated), false);
    expect(choose(m, count: 100).overBudget, false);
    expect(
      choose(m, count: 2, excluded: {'Au', 'Bu'}, budget: -1).overBudget,
      false,
    );
  });
  test('M1 M2 D1 D2 edited carried copies survive second compression once', () {
    final m = rounds('ABCDEFG');
    var first = operation('one', m, choose(m, keep: 5), keep: 5);
    first = first.withCarried(
      first.carried!.withItems([
        first.carried!.items.single.copyWith(editedText: 'B edited'),
      ]),
    );
    final selected = choose(m, operations: [first], keep: 2, count: 10);
    expect(selected.items.map((i) => i.text), ['B edited', 'Cu', 'Du', 'Eu']);
    expect(selected.items.first.fromOperationId, 'one');
    final all = choose(
      m,
      operations: [first],
      keep: 2,
      count: 10,
      earlier: true,
    );
    expect(all.items.map((i) => i.text), ['Au', 'B edited', 'Cu', 'Du', 'Eu']);
    final second = operation('two', m, all, operations: [first], keep: 2);
    final request = ContextHistory.resolve(m, [first, second]);
    expect(request.map((m) => m.content), [
      'Au',
      'B edited',
      'Cu',
      'Du',
      'Eu',
      'summary-two',
      'Fu',
      'Fa',
      'Gu',
      'Ga',
    ]);
    expect(countUserMessages(request), 2);
    expect(
      ContextHistory.resolve(m, [
        first,
        second.copyWith(revoked: true),
      ]).where((m) => isCarriedMessageId(m.id)).map((m) => m.content),
      ['B edited'],
    );
  });
  test(
    'inherited preview never restores excluded files or counts deleted images',
    () {
      final m = rounds('ABCDE');
      m[2] = message(
        'Bu',
        parts: [
          const TextPart('body'),
          const FilePart(uri: '/tmp/notes.pdf', name: 'Notes.pdf'),
        ],
      );
      var first = operation('one', m, choose(m));
      first = first.withCarried(
        first.carried!.withItems([
          carriedFromMessage(m[2], includeAttachments: false),
        ]),
      );
      final withoutFile = choose(m, operations: [first]).rows.single;
      expect(withoutFile.fileNames, isEmpty);
      expect(withoutFile.attachmentCount, 0);

      m[2] = message(
        'Bu',
        parts: [
          const TextPart('caption'),
          const ImagePart(uri: '/tmp/photo.png'),
        ],
      );
      final image = operation('image', m, choose(m));
      final deleted = m.where((m) => m.id != 'Bu').toList();
      final row = choose(deleted, operations: [image]).rows.single;
      expect(row.attachmentCount, 0);
      expect(row.imageUris, isEmpty);
      expect(row.item.imageHandles, isEmpty);
      final copied = selectCarriedOriginals(
        messages: m,
        operations: [],
        selection: range(m),
        setting: const CarrySetting(mode: CarryMode.count, count: 1),
        fromSummaries: false,
        excluded: {},
        replies: {},
        budgetTokens: null,
        count: (i) => countCarriedTokens(i, ProviderKind.openai),
        newConversation: true,
      );
      expect(copied.rows.single.hadAttachments, true);
      expect(copied.items.single.imageHandles, isEmpty);
    },
  );
  test(
    'deleted and copied originals keep frozen order and never carry the summary row',
    () {
      final m = rounds('ABCDE');
      final first = operation('one', m, choose(m, count: 10));
      final deleted = m.where((m) => m.id != 'Au').toList();
      expect(
        choose(deleted, operations: [first], count: 1).items.single.text,
        'Bu',
      );
      expect(
        choose(
          deleted,
          operations: [first],
          all: true,
        ).items.map((i) => i.text),
        ['Au', 'Bu'],
      );
      final anchor = message('copyu', text: 'copied summary');
      final copied = first.copiedTo(
        anchor,
        keepUserMessages: 3,
        sourceConversationId: 'source',
      );
      final subset = [anchor, ...rounds('CDE')];
      expect(
        choose(
          subset,
          operations: [copied],
          all: true,
          earlier: true,
        ).items.map((i) => i.text),
        ['Au', 'Bu'],
      );
      expect(choose(subset, operations: [copied]).items.single.text, 'Bu');
    },
  );
  test(
    'legacy Codex copied window retains both users without local revisions',
    () {
      final anchor = message('copyu', text: 'legacy summary');
      final op = ContextOperation.forCopiedSummary(
        anchor,
        keepUserMessages: 3,
        compressionDetails: {
          'nativeContextImported': true,
          'nativeCompaction': NativeCompactionPayload(
            protocol: NativeCompactionProtocol.codex,
            scope: 's',
            modelId: 'm',
            output: [
              textWire('user', 'old'),
              textWire('user', 'new'),
              {'type': 'compaction', 'encrypted_content': 'data'},
            ],
          ).toJson(),
        },
      );
      final sub = [anchor, ...rounds('CDE')];
      final chosen = choose(sub, operations: [op], all: true, earlier: true);
      expect(chosen.items.map((i) => i.text), ['old', 'new']);
      expect(chosen.items.map((i) => i.sourceMessageId), [
        'legacy-native:copyu:0',
        'legacy-native:copyu:1',
      ]);
      expect(chosen.items.every((i) => i.wire == null), true);
    },
  );
  test(
    'legacy templates and frozen prompts retain the local source identity',
    () {
      final m = rounds('ABCDE');
      final first = operation(
        'legacy',
        m,
        choose(m, count: 2),
      ).withCarried(null);
      final op = first.copyWith(
        compressionDetails: {
          'sourceRevisionIds': m.take(4).map((m) => m.id).toList(),
          'nativeCompaction': NativeCompactionPayload(
            protocol: NativeCompactionProtocol.codex,
            scope: 's',
            modelId: 'm',
            output: [
              textWire('user', 'RULES Au'),
              textWire('user', 'you wrote Bu'),
              {'type': 'compaction', 'encrypted_content': 'x'},
            ],
          ).toJson(),
        },
      );
      expect(op.legacyUserSources(m), {0: 'Au', 1: 'Bu'});
      expect(
        op.legacyUserSources(
          m.where((m) => m.role == 'user').toList(),
          availableRevisionIds: m.map((m) => m.id).toSet(),
        ),
        {0: 'Au', 1: 'Bu'},
      );
      expect(
        choose(
          m,
          operations: [op],
          all: true,
          earlier: true,
        ).items.map((i) => i.sourceMessageId),
        ['Au', 'Bu'],
      );
      expect(
        op.legacyUserSources(
          m.where((m) => m.id != 'Au').toList(),
          frozenPrompts: {'Bu': 'you wrote Bu'},
        ),
        {0: 'legacy-native:legacy:0', 1: 'Bu'},
      );
    },
  );
  test(
    'a legacy truncated boundary maps to its source when bringing back originals',
    () {
      final m = rounds('ABCDE');
      m[0] = message('Au', text: 'head long original body tail');
      final first = operation(
        'legacy',
        m,
        choose(m, count: 2),
      ).withCarried(null);
      final op = first.copyWith(
        compressionDetails: {
          'nativeCompaction': NativeCompactionPayload(
            protocol: NativeCompactionProtocol.codex,
            scope: 's',
            modelId: 'm',
            output: [
              textWire('user', 'head\n[…truncated…]\ntail'),
              textWire('user', 'Bu'),
              {'type': 'compaction', 'encrypted_content': 'x'},
            ],
          ).toJson(),
        },
      );
      final chosen = choose(m, operations: [op], all: true, earlier: true);
      expect(chosen.items.map((i) => i.sourceMessageId), ['Au', 'Bu']);
    },
  );
  test(
    'explicit native carry removes file and audio bytes while retaining image and frozen text',
    () {
      final wire = {
        'role': 'user',
        'content': [
          {'type': 'input_text', 'text': 'processed input'},
          {'type': 'input_file', 'file_data': 'pdf bytes'},
          {'type': 'input_audio', 'data': 'audio'},
          {'type': 'input_image', 'image_url': 'image'},
        ],
      };
      expect(explicitCarriedWire(wire, 'exact original')['content'], [
        {'type': 'input_text', 'text': 'exact original'},
        {'type': 'input_image', 'image_url': 'image'},
      ]);
      expect((wire['content'] as List).length, 4);
    },
  );
  test(
    'summary without attachments clears inherited native wire and extracted file text',
    () {
      final m = rounds('ABCDE');
      final item = carriedFromMessage(m[2]).copyWith(
        text: 'file body and words',
        textWithoutAttachments: 'words',
        wire: textWire('user', 'file body and words', images: ['handle']),
        imageHandles: ['handle'],
        hasAttachments: true,
      );
      final op = operation('one', m, CarrySelection(items: [item]));
      final chosen = selectCarriedOriginals(
        messages: m,
        operations: [op],
        selection: range(m, operations: [op]),
        setting: const CarrySetting(mode: CarryMode.all),
        fromSummaries: false,
        excluded: {},
        replies: {},
        budgetTokens: null,
        count: (i) => countCarriedTokens(i, ProviderKind.openai),
        includeAttachments: false,
      );
      expect(chosen.items.single.text, 'words');
      expect(chosen.items.single.wire, isNull);
      expect(chosen.items.single.imageHandles, isEmpty);
    },
  );
  test('replies are text-only, atomic in all-mode, and excluded with user', () {
    final m = rounds('ABCDE');
    m[3] = message(
      'Ba',
      parts: [
        const ReasoningPart('secret'),
        const TextPart('answer'),
        const ToolCallPart('{}'),
        const ImagePart(uri: '/ignored.png'),
      ],
    );
    final selected = choose(m, replies: {'Bu'});
    expect(selected.items.single.reply!.text, 'answer');
    final op = operation('reply', m, selected);
    expect(ContextHistory.resolve(m, [op]).take(3).map((m) => m.content), [
      'Bu',
      'answer',
      'summary-reply',
    ]);
    final budget = choose(m).totalTokens;
    expect(choose(m, replies: {'Bu'}, budget: budget).overBudget, true);
    final all = choose(m, all: true, replies: {'Bu'}, budget: budget);
    expect(all.items, isEmpty);
    expect(all.notFit, 2);
    expect(all.rows.single.replyDoesNotFit, true);
    expect(all.rows.single.availableReply!.text, 'answer');
    expect(choose(m, excluded: {'Bu'}, replies: {'Bu'}).items, isEmpty);
    final tail = selectCompressionHistory(
      m,
      [],
      const CompressContextOptions(
        mode: CompressContextLimitMode.start,
        maxChars: 6,
      ),
    );
    final split = selectCarriedOriginals(
      messages: m,
      operations: [],
      selection: tail,
      setting: const CarrySetting(mode: CarryMode.count),
      fromSummaries: false,
      excluded: {},
      replies: {'Bu'},
      budgetTokens: null,
      count: (i) => countCarriedTokens(i, ProviderKind.openai),
    );
    expect(split.rows.first.replyInRetained, true);
    expect(split.items.last.reply, isNull);
  });
  test(
    'limit and original-history expansion keep carried with its summary',
    () {
      final m = rounds('ABCDE');
      final op = operation('one', m, choose(m));
      final projected = ContextHistory.resolve(m, [op], limit: 1);
      expect(projected.map((m) => m.content), ['Bu', 'summary-one', 'Ea']);
      final expanded = ContextHistory.compressionInput(m, [
        op,
      ], source: ContextHistorySource.original);
      expect(expanded.any((m) => isCarriedMessageId(m.id)), false);
      final deleted = m.where((m) => m.id != 'Bu').toList();
      expect(ContextHistory.resolve(deleted, [op]).first.content, 'Bu');
    },
  );
  test(
    'wire preservation, edited text replacement, metadata-free estimation',
    () {
      final wire = {
        'type': 'message',
        'role': 'user',
        'content': [
          {'type': 'input_text', 'text': 'old', 'extra': 'keep'},
          {'type': 'input_image', 'image_url': 'https://example.com/img.png'},
        ],
      };
      final item = carriedFromMessage(message('Au')).copyWith(wire: wire);
      expect(jsonEncode(item.wireItem), jsonEncode(wire));
      final edited = item.copyWith(editedText: 'new').wireItem;
      expect((edited['content'] as List).first, {
        'type': 'input_text',
        'text': 'new',
      });
      expect((edited['content'] as List).last, (wire['content'] as List).last);
      final plain = {
        'input': [wire],
      };
      final marked = {
        'input': [
          {...wire, carriedWireKey: true, historySourceKey: 'id'},
        ],
      };
      expect(
        estimateRequestInput(marked, ProviderKind.openai),
        estimateRequestInput(plain, ProviderKind.openai),
      );
    },
  );
}
