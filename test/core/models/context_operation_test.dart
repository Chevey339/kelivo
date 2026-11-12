import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/models/compress_context_options.dart';

void main() {
  ChatMessage message(String id) =>
      ChatMessage(id: id, role: 'user', content: id, conversationId: 'chat');
  ContextOperation compact(
    String id,
    List<String> groups, {
    List<String> dependencies = const [],
    String? after,
  }) => ContextOperation(
    id: id,
    kind: ContextOperationKind.compress,
    anchorGroupId: groups.last,
    appliedAfterGroupId: after ?? groups.last,
    sourceGroups: groups,
    dependencies: dependencies,
    createdAt: DateTime(2026),
    summary: id,
    originalSummary: id,
  );
  ContextOperation clear(String id, String anchor) => ContextOperation(
    id: id,
    kind: ContextOperationKind.clear,
    anchorGroupId: anchor,
    appliedAfterGroupId: anchor,
    sourceGroups: [anchor],
    dependencies: const [],
    createdAt: DateTime(2026),
  );
  List<String> text(List<ChatMessage> messages) =>
      messages.map((m) => m.content).toList();

  ContextOperation start(String anchor) => ContextOperation(
    id: 'start-$anchor',
    kind: ContextOperationKind.start,
    anchorGroupId: anchor,
    appliedAfterGroupId: anchor,
    sourceGroups: [anchor],
    dependencies: const [],
    createdAt: DateTime(2026),
  );

  test('metadata range and counts never decode opaque native payloads', () {
    final messages = ['A', 'B', 'C', 'D'].map(message).toList();
    // Deliberately not serializable: projection must only inspect native flags.
    final native = compact('native', ['A', 'B']).copyWith(
      compressionDetails: {
        'nativeCompaction': {'opaque': Object()},
        'nativeContextImported': true,
      },
    );
    final metadata = messages.map(ContextMessageMetadata.fromMessage).toList();
    final projected = ContextHistory.project(metadata, [native], limit: 1);
    expect(projected.map((m) => m.id), [native.summaryMessageId, 'D']);
    final range = selectCompressionRange(
      metadata,
      [native],
      const CompressContextOptions(
        mode: CompressContextLimitMode.keepRecent,
        keepUserMessages: 1,
        native: true,
      ),
    );
    expect(range.covered.map((m) => m.id), ['A', 'B', 'C']);
    expect(range.retained.map((m) => m.id), ['D']);
    final text = selectCompressionRange(metadata, [
      native,
    ], const CompressContextOptions(mode: CompressContextLimitMode.unlimited));
    expect(text.missingOriginals, isTrue);
  });

  for (final includeSummary in [false, true]) {
    test(
      'bounded compression expands only selected summary dependencies: $includeSummary',
      () {
        final history = ['HIDDEN', 'A', 'B', 'C', 'D'].map(message).toList();
        final previous = compact('previous', ['A', 'B']);
        final selection = selectCompressionHistory(
          history,
          [previous],
          const CompressContextOptions(
            mode: CompressContextLimitMode.keepRecent,
            keepUserMessages: 1,
          ),
          protectedMessageId: 'D',
          effectiveMessageIds: {
            'C',
            'D',
            if (includeSummary) previous.summaryMessageId,
          },
        );
        expect(
          text(selection.input),
          includeSummary ? ['previous', 'C'] : ['C'],
        );
        expect(
          text(selection.covered),
          includeSummary ? ['A', 'B', 'C'] : ['C'],
        );
        expect(selection.dependencies, includeSummary ? ['previous'] : isEmpty);
        expect(text(selection.retained), ['D']);
      },
    );
  }

  test(
    'fixed start is inclusive, overrides the window and follows the selected group',
    () {
      final history = ['A', 'B', 'C', 'D'].map(message).toList();
      final pin = start('B');
      expect(text(ContextHistory.resolve(history, [pin], limit: 1)), [
        'B',
        'C',
        'D',
      ]);
      expect(
        text(
          ContextHistory.resolve(history, [pin], throughGroupId: 'C', limit: 1),
        ),
        ['B', 'C'],
      );
      expect(
        ContextHistory.resolve(history, [pin], throughGroupId: 'A'),
        isEmpty,
      );
      final revised = [
        history.first,
        message('B-v2').copyWith(groupId: 'B'),
        ...history.skip(2),
      ];
      expect(text(ContextHistory.resolve(revised, [pin], limit: 1)), [
        'B-v2',
        'C',
        'D',
      ]);
      expect(
        text(
          ContextHistory.resolve(
            history,
            [pin],
            omitOperations: {pin.id},
            limit: 1,
          ),
        ),
        ['D'],
      );
      expect(
        ContextHistory.affectedOperations([pin], changedGroups: {'B'}),
        isEmpty,
      );
      expect(ContextHistory.affectedOperations([pin], removedGroups: {'B'}), {
        pin.id,
      });
      expect(ContextOperation.fromJson(pin.toJson()).isFixedStart, isTrue);
    },
  );

  test(
    'fixed start excludes earlier clear and summaries spanning its boundary',
    () {
      final history = ['A', 'B', 'C', 'D'].map(message).toList();
      final pin = start('B');
      expect(
        text(ContextHistory.resolve(history, [clear('old-clear', 'C'), pin])),
        ['B', 'C', 'D'],
      );
      expect(
        text(
          ContextHistory.resolve(history, [
            clear('clear', 'A'),
            compact('old', ['A', 'B']),
            pin,
          ]),
        ),
        ['B', 'C', 'D'],
      );
      expect(
        text(
          ContextHistory.resolve(history, [
            pin,
            compact('new', ['B', 'C']),
          ], limit: 1),
        ),
        ['new', 'D'],
      );
      expect(
        text(ContextHistory.resolve(history, [pin, clear('later', 'C')])),
        ['D'],
      );
      expect(
        text(
          ContextHistory.resolve(history, [
            pin.copyWith(revoked: true),
          ], limit: 2),
        ),
        ['C', 'D'],
      );
    },
  );

  test(
    'summaries authored under a fixed start are revoked with that start',
    () {
      final history = ['A', 'B', 'C', 'D', 'E', 'F'].map(message).toList();
      final original = compact('old', ['A', 'B', 'C', 'D']);
      final pin = start('C');
      var operations = ContextHistory.appendOperation([original], pin);
      operations = ContextHistory.appendOperation(
        operations,
        compact('new', ['C', 'D']),
      );
      expect(operations.last.dependencies, contains(pin.id));
      expect(
        text(
          ContextHistory.compressionInput(
            history,
            operations,
            source: ContextHistorySource.original,
            includeEditedSummaries: false,
          ),
        ),
        ['C', 'D', 'E', 'F'],
      );
      final selection = selectCompressionHistory(
        history,
        operations,
        const CompressContextOptions(
          mode: CompressContextLimitMode.keepRecent,
          keepUserMessages: 2,
          historySource: ContextHistorySource.original,
        ),
      );
      expect(text(selection.input), ['C', 'D']);

      expect(text(ContextHistory.resolve(history, operations)), [
        'new',
        'E',
        'F',
      ]);
      final affected = ContextHistory.affectedOperations(
        operations,
        operationIds: {pin.id},
      );
      final undone = [
        for (final op in operations)
          affected.contains(op.id) ? op.copyWith(revoked: true) : op,
      ];
      expect(text(ContextHistory.resolve(history, undone)), ['old', 'E', 'F']);
      final moved = ContextHistory.appendOperation(operations, start('E'));
      expect(moved.singleWhere((op) => op.id == 'new').revoked, isTrue);
      expect(text(ContextHistory.resolve(history, moved)), ['E', 'F']);
      expect(
        text(
          ContextHistory.resolve(history, [
            ...moved.take(moved.length - 1),
            moved.last.copyWith(revoked: true),
          ]),
        ),
        ['old', 'E', 'F'],
      );
    },
  );

  test(
    'successive undo restores the earlier summary and all later messages',
    () {
      final history = ['A', 'B', 'C'].map(message).toList();
      final s1 = compact('S1', ['A']);
      final s2 = compact('S2', ['A', 'B'], dependencies: ['S1']);
      expect(text(ContextHistory.resolve(history, [s1, s2])), ['S2', 'C']);
      expect(
        text(ContextHistory.resolve(history, [s1, s2.copyWith(revoked: true)])),
        ['S1', 'B', 'C'],
      );
      expect(
        text(
          ContextHistory.resolve(history, [
            s1.copyWith(revoked: true),
            s2.copyWith(revoked: true),
          ]),
        ),
        ['A', 'B', 'C'],
      );
      expect(history.map((m) => m.id), ['A', 'B', 'C']);
    },
  );

  test('clear undo preserves a later independent compressed range', () {
    final history = ['A', 'B', 'C'].map(message).toList();
    final reset = clear('clear', 'A');
    final summary = compact('S', ['B']);
    expect(text(ContextHistory.resolve(history, [reset, summary])), ['S', 'C']);
    expect(
      text(
        ContextHistory.resolve(history, [
          reset.copyWith(revoked: true),
          summary,
        ]),
      ),
      ['A', 'S', 'C'],
    );
  });

  test(
    'regeneration reuses summaries before the target throughout the retained tail',
    () {
      final history = ['A', 'B', 'C', 'D', 'E'].map(message).toList();
      final summary = compact('S', ['A', 'B'], after: 'E');
      for (final target in ['A', 'B']) {
        expect(
          text(
            ContextHistory.resolve(history, [summary], throughGroupId: target),
          ),
          target == 'A' ? ['A'] : ['A', 'B'],
        );
      }
      for (final target in ['C', 'D', 'E']) {
        expect(
          text(
            ContextHistory.resolve(history, [summary], throughGroupId: target),
          ),
          [
            'S',
            ...['C', 'D', 'E'].take(['C', 'D', 'E'].indexOf(target) + 1),
          ],
        );
      }
      expect(
        text(
          ContextHistory.resolve(
            history,
            [summary],
            throughGroupId: 'C',
            limit: 1,
          ),
        ),
        ['S', 'C'],
      );
    },
  );

  test(
    'regeneration selects only summaries whose covered ranges precede the target',
    () {
      final history = ['A', 'B', 'C', 'D', 'E'].map(message).toList();
      final first = compact('S1', ['A', 'B'], after: 'E');
      final second = compact(
        'S2',
        ['A', 'B', 'C'],
        dependencies: ['S1'],
        after: 'E',
      );
      expect(
        text(
          ContextHistory.resolve(
            history,
            [first, second],
            throughGroupId: 'C',
            endGroupId: 'D',
          ),
        ),
        ['S1', 'C', 'D'],
      );
      expect(
        text(
          ContextHistory.resolve(history, [first, second], throughGroupId: 'D'),
        ),
        ['S2', 'D'],
      );
      expect(
        text(
          ContextHistory.resolve(
            history,
            [first, second],
            throughGroupId: 'D',
            omitOperations: {'S1'},
          ),
        ),
        ['A', 'B', 'C', 'D'],
      );
      expect(
        text(
          ContextHistory.resolve(history, [
            first,
            compact('independent', ['D'], after: 'E'),
          ], throughGroupId: 'C'),
        ),
        ['S1', 'C'],
      );
    },
  );

  test(
    'regeneration retains a summary depending on the active fixed start',
    () {
      final history = ['A', 'B', 'C', 'D', 'E'].map(message).toList();
      final operations = ContextHistory.appendOperation([
        start('B'),
      ], compact('S', ['B', 'C'], after: 'E'));
      expect(
        text(ContextHistory.resolve(history, operations, throughGroupId: 'D')),
        ['S', 'D'],
      );
      expect(
        text(ContextHistory.resolve(history, operations, throughGroupId: 'C')),
        ['B', 'C'],
      );
    },
  );

  test('regeneration still applies clears only after their boundary', () {
    final history = ['A', 'B', 'C'].map(message).toList();
    final reset = clear('clear', 'B');
    expect(
      text(ContextHistory.resolve(history, [reset], throughGroupId: 'B')),
      ['A', 'B'],
    );
    expect(
      text(ContextHistory.resolve(history, [reset], throughGroupId: 'C')),
      ['C'],
    );
  });

  test('message window limits raw messages without evicting the summary', () {
    final history = ['A', 'B', 'C', 'D'].map(message).toList();
    expect(
      text(
        ContextHistory.resolve(history, [
          compact('S', ['A']),
        ], limit: 1),
      ),
      ['S', 'D'],
    );
  });

  test(
    'changing a source affects transitive summaries, not independent clears',
    () {
      final operations = [
        compact('S1', ['A']),
        compact('S2', ['A', 'B'], dependencies: ['S1']),
        clear('clear', 'C'),
        compact('S3', ['D']),
      ];
      expect(
        ContextHistory.affectedOperations(operations, changedGroups: {'A'}),
        {'S1', 'S2'},
      );
    },
  );

  test('original history expansion never crosses an active clear', () {
    final history = ['A', 'B', 'C', 'D'].map(message).toList();
    final operations = [
      compact('S0', ['A']),
      clear('clear', 'A'),
      compact('S1', ['B']),
      compact('S2', ['B', 'C'], dependencies: ['S1']),
    ];
    expect(
      text(
        ContextHistory.compressionInput(
          history,
          operations,
          source: ContextHistorySource.previous,
        ),
      ),
      ['S1', 'C', 'D'],
    );
    expect(
      text(
        ContextHistory.compressionInput(
          history,
          operations,
          source: ContextHistorySource.original,
        ),
      ),
      ['B', 'C', 'D'],
    );
  });

  test(
    'edited summaries are explicit optional supplements when reading originals',
    () {
      final history = ['A', 'B'].map(message).toList();
      final summary = compact('S', ['A']).copyWith(summary: 'manual decision');
      final expanded = ContextHistory.compressionInput(history, [
        summary,
      ], source: ContextHistorySource.original);
      expect(expanded.first.content, contains('manual decision'));
      expect(text(expanded.skip(1).toList()), ['A', 'B']);
      expect(
        text(
          ContextHistory.compressionInput(
            history,
            [summary],
            source: ContextHistorySource.original,
            includeEditedSummaries: false,
          ),
        ),
        ['A', 'B'],
      );
    },
  );

  test(
    'in-place content edits change the fingerprint even with the same revision id',
    () {
      final original = message('A');
      expect(
        ContextHistory.fingerprint([original], []),
        isNot(
          ContextHistory.fingerprint([
            original.copyWith(content: 'edited'),
          ], []),
        ),
      );
      expect(
        ContextHistory.fingerprint([original], []),
        ContextHistory.fingerprint([original.copyWith(totalTokens: 123)], []),
      );
    },
  );

  test(
    'missing live anchors fail closed instead of silently restoring history',
    () {
      expect(
        () => ContextHistory.resolve([message('B')], [clear('clear', 'A')]),
        throwsStateError,
      );
    },
  );

  test(
    'serialization and branch remapping preserve summary edits and dependencies',
    () {
      final s = compact(
        'S2',
        ['A', 'B'],
        dependencies: ['S1'],
      ).copyWith(summary: 'edited');
      final copy = ContextOperation.fromJson(s.toJson()).remap(
        groups: {'A': 'a', 'B': 'b'},
        operations: {'S1': 's1', 'S2': 's2'},
      );
      expect(copy.sourceGroups, ['a', 'b']);
      expect(copy.dependencies, ['s1']);
      expect(copy.isEdited, isTrue);
      expect(copy.summary, 'edited');
    },
  );
  test(
    'clear survives text or version changes but not deletion of its anchor group',
    () {
      final operations = [clear('reset', 'B')];
      expect(
        ContextHistory.affectedOperations(operations, changedGroups: {'B'}),
        isEmpty,
      );
      expect(
        ContextHistory.affectedOperations(
          operations,
          changedGroups: {'B'},
          removedGroups: {'B'},
        ),
        {'reset'},
      );
    },
  );

  test(
    'keep all raw user messages leaves a leading summary available for rereading',
    () {
      final history = ['A', 'B', 'C'].map(message).toList();
      final projected = ContextHistory.resolve(history, [
        compact('S', ['A']),
      ]);
      expect(text(selectKeepRecentMessages(projected, 6)), ['B', 'C']);
    },
  );
}
