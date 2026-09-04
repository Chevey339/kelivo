import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/conversation.dart';

void main() {
  group('Conversation chat suggestions compatibility', () {
    test('fromJson defaults missing suggestions to empty list', () {
      final conversation = Conversation.fromJson({
        'id': 'conversation-1',
        'title': 'Chat',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 2).toIso8601String(),
        'messageIds': <String>[],
      });

      expect(conversation.chatSuggestions, isEmpty);
    });

    test('toJson includes chat suggestions', () {
      final conversation = Conversation(
        id: 'conversation-2',
        title: 'Chat',
        chatSuggestions: const ['继续', '举例'],
      );

      expect(conversation.toJson()['chatSuggestions'], ['继续', '举例']);
    });
  });

  group('Conversation extras', () {
    test('defaults to an empty map and round-trips', () {
      final conversation = Conversation(
        id: 'conversation-3',
        title: 'Chat',
        extras: const {'workspace.id': 'ws-1'},
      );
      expect(Conversation(id: 'empty', title: 'Chat').extras, isEmpty);
      final decoded = Conversation.fromJson(conversation.toJson());
      expect(decoded.extras['workspace.id'], 'ws-1');
    });

    test('fromJson tolerates missing and malformed extras', () {
      final missing = Conversation.fromJson({
        'id': 'conversation-4',
        'title': 'Chat',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 2).toIso8601String(),
        'messageIds': <String>[],
      });
      expect(missing.extras, isEmpty);
      expect(Conversation.decodeExtras('{}'), isEmpty);
      expect(Conversation.decodeExtras('not-json'), isEmpty);
    });
  });
}
