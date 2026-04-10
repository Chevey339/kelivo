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
}
