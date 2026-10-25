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

  test('regeneration cannot see a summary created after its retained tail', () {
    final history = ['A', 'B', 'C', 'D'].map(message).toList();
    final summary = compact('S', ['A'], after: 'C');
    expect(
      text(ContextHistory.resolve(history, [summary], throughGroupId: 'B')),
      ['A', 'B'],
    );
    expect(
      text(ContextHistory.resolve(history, [summary], throughGroupId: 'D')),
      ['S', 'B', 'C', 'D'],
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
