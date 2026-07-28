import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/features/home/controllers/home_view_model.dart';

ChatMessage _message(String id, int version) {
  return ChatMessage(
    id: id,
    role: 'assistant',
    content: 'message-$version',
    conversationId: 'conversation-1',
    groupId: 'group-1',
    version: version,
  );
}

void main() {
  group('HomeViewModel.computeNextVersionSelection', () {
    test('删除较早版本时会同步左移当前选中索引', () {
      final versions = <ChatMessage>[
        _message('v0', 0),
        _message('v1', 1),
        _message('v2', 2),
      ];

      final nextSelection = HomeViewModel.computeNextVersionSelection(
        versionsBefore: versions,
        deletedMessageIds: const {'v0'},
        oldSelection: 2,
      );

      expect(nextSelection, 1);
    });

    test('删除当前首个版本时会落到新的首个版本', () {
      final versions = <ChatMessage>[
        _message('v0', 0),
        _message('v1', 1),
        _message('v2', 2),
      ];

      final nextSelection = HomeViewModel.computeNextVersionSelection(
        versionsBefore: versions,
        deletedMessageIds: const {'v0'},
        oldSelection: 0,
      );

      expect(nextSelection, 0);
    });

    test('删除全部版本时会清空选中状态', () {
      final versions = <ChatMessage>[_message('v0', 0), _message('v1', 1)];

      final nextSelection = HomeViewModel.computeNextVersionSelection(
        versionsBefore: versions,
        deletedMessageIds: const {'v0', 'v1'},
        oldSelection: 1,
      );

      expect(nextSelection, isNull);
    });
  });

  group('HomeViewModel.buildBatchDeletePlan', () {
    test('删除本版本会按选中版本聚合并同步剩余版本选中索引', () {
      final versions = <ChatMessage>[
        _message('v0', 0),
        _message('v1', 1),
        _message('v2', 2),
        ChatMessage(
          id: 'user-1',
          role: 'user',
          content: 'user',
          conversationId: 'conversation-1',
        ),
      ];

      final plan = HomeViewModel.buildBatchDeletePlan(
        messages: versions,
        selectedMessageIds: const {'v0', 'v2', 'user-1'},
        versionSelections: const {'group-1': 2},
      );

      expect(plan.groups, hasLength(2));
      expect(plan.groups['group-1']!.deletedMessageIds, {'v0', 'v2'});
      expect(plan.nextVersionSelections['group-1'], 0);
      expect(plan.groups['user-1']!.deletedMessageIds, {'user-1'});
      expect(plan.nextVersionSelections.containsKey('user-1'), isFalse);
    });

    test('删除全部版本会扩展选中消息所在消息组的所有版本', () {
      final versions = <ChatMessage>[
        _message('v0', 0),
        _message('v1', 1),
        _message('v2', 2),
        ChatMessage(
          id: 'assistant-2',
          role: 'assistant',
          content: 'assistant',
          conversationId: 'conversation-1',
          groupId: 'assistant-2',
          version: 0,
        ),
      ];

      final plan = HomeViewModel.buildBatchDeletePlan(
        messages: versions,
        selectedMessageIds: const {'v1', 'assistant-2'},
        versionSelections: const {'group-1': 1},
        deleteAllVersions: true,
      );

      expect(plan.groups['group-1']!.deletedMessageIds, {'v0', 'v1', 'v2'});
      expect(plan.clearedVersionSelectionGroupIds, contains('group-1'));
      expect(plan.groups['assistant-2']!.deletedMessageIds, {'assistant-2'});
    });

    test('按选中组裁剪后的消息集合与全量集合产生相同的删除计划', () {
      final messages = <ChatMessage>[
        _message('v0', 0),
        _message('v1', 1),
        _message('v2', 2),
        ChatMessage(
          id: 'user-1',
          role: 'user',
          content: 'user',
          conversationId: 'conversation-1',
        ),
        // Untouched group with its own versions: present in the full load,
        // absent from the scoped load, irrelevant to the plan either way.
        ChatMessage(
          id: 'other-1',
          role: 'assistant',
          content: 'other',
          conversationId: 'conversation-1',
          groupId: 'other-1',
          version: 0,
        ),
        ChatMessage(
          id: 'other-1-v1',
          role: 'assistant',
          content: 'other v1',
          conversationId: 'conversation-1',
          groupId: 'other-1',
          version: 1,
        ),
      ];
      const selected = {'v0', 'v2', 'user-1'};
      const selections = {'group-1': 2};

      // Mirror the scoped load in deleteMessages: keep only the groups the
      // selected revisions belong to.
      final selectedGroups = messages
          .where((message) => selected.contains(message.id))
          .map((message) => message.groupId ?? message.id)
          .toSet();
      final scoped = messages
          .where(
            (message) => selectedGroups.contains(message.groupId ?? message.id),
          )
          .toList();

      for (final deleteAllVersions in [false, true]) {
        final full = HomeViewModel.buildBatchDeletePlan(
          messages: messages,
          selectedMessageIds: selected,
          versionSelections: selections,
          deleteAllVersions: deleteAllVersions,
        );
        final narrowed = HomeViewModel.buildBatchDeletePlan(
          messages: scoped,
          selectedMessageIds: selected,
          versionSelections: selections,
          deleteAllVersions: deleteAllVersions,
        );

        expect(narrowed.groups.keys, full.groups.keys);
        for (final entry in full.groups.entries) {
          final narrowedGroup = narrowed.groups[entry.key]!;
          expect(
            narrowedGroup.deletedMessageIds,
            entry.value.deletedMessageIds,
          );
          expect(
            narrowedGroup.versionsBefore.map((message) => message.id),
            entry.value.versionsBefore.map((message) => message.id),
          );
          expect(
            narrowedGroup.nextVersionSelection,
            entry.value.nextVersionSelection,
          );
        }
        expect(narrowed.nextVersionSelections, full.nextVersionSelections);
        expect(
          narrowed.clearedVersionSelectionGroupIds,
          full.clearedVersionSelectionGroupIds,
        );
      }
    });
  });
}
