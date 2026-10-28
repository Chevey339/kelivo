import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/conversation_mcp_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assistant = Assistant(
    id: 'assistant',
    name: 'Assistant',
    mcpServerIds: ['default'],
  );

  test(
    'assistant MCP customization defaults off and survives serialization',
    () {
      expect(assistant.allowConversationMcp, isFalse);
      expect(
        Assistant.fromJson({'id': 'a', 'name': 'A'}).allowConversationMcp,
        isFalse,
      );
      final enabled = assistant.copyWith(allowConversationMcp: true);
      expect(Assistant.fromJson(enabled.toJson()).allowConversationMcp, isTrue);
      expect(enabled.copyWith(name: 'Renamed').allowConversationMcp, isTrue);
      expect(
        enabled.copyWith(allowConversationMcp: false).allowConversationMcp,
        isFalse,
      );
    },
  );

  test(
    'explicit empty selection is distinct from inheritance and respects the gate',
    () {
      final inherited = Conversation(
        title: 'Inherited',
        assistantId: assistant.id,
      );
      final custom = inherited.copyWith(
        mcpServerIds: ['custom'],
        extras: const {ConversationMcpSettings.overrideKey: true},
      );
      final empty = custom.copyWith(mcpServerIds: []);
      final enabled = assistant.copyWith(allowConversationMcp: true);

      expect(ConversationMcpSettings.effectiveServerIds(assistant, custom), [
        'default',
      ]);
      expect(ConversationMcpSettings.effectiveServerIds(enabled, inherited), [
        'default',
      ]);
      expect(ConversationMcpSettings.effectiveServerIds(enabled, custom), [
        'custom',
      ]);
      expect(
        ConversationMcpSettings.effectiveServerIds(enabled, empty),
        isEmpty,
      );
      expect(ConversationMcpSettings.effectiveServerIds(assistant, empty), [
        'default',
      ]);
      expect(ConversationMcpSettings.effectiveServerIds(enabled, null), [
        'default',
      ]);
      expect(ConversationMcpSettings.effectiveServerIds(null, custom), isEmpty);
    },
  );
  for (final owner in <String?>[null, 'deleted-assistant']) {
    test('resolved assistant applies overrides for original owner $owner', () {
      final enabled = assistant.copyWith(allowConversationMcp: true);
      final conversation = Conversation(
        title: 'Recovered',
        assistantId: owner,
        extras: const {ConversationMcpSettings.overrideKey: true},
      );
      expect(
        ConversationMcpSettings.effectiveServerIds(enabled, conversation),
        isEmpty,
      );
      expect(
        ConversationMcpSettings.effectiveServerIds(
          enabled,
          conversation.copyWith(mcpServerIds: ['custom']),
        ),
        ['custom'],
      );
      expect(
        ConversationMcpSettings.effectiveServerIds(assistant, conversation),
        ['default'],
      );
    });
  }
}
