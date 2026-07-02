import 'package:flutter_test/flutter_test.dart';
import 'package:Cuplivo/core/models/chat_message.dart';
import 'package:Cuplivo/features/home/controllers/home_view_model.dart';

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
  });
}
