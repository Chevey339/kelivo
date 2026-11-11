import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/skills_binding.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import '../../../support/business_test_harness.dart';

class _Chats extends ChatService {
  Conversation? selected;
  @override
  Conversation? getConversation(String id) =>
      selected?.id == id ? selected : null;
}

void main() {
  testWidgets(
    'prompt injection preserves explicit overflow and conversation filtering',
    (tester) async {
      final ids = List.generate(25, (i) => 's${i.toString().padLeft(2, '0')}');
      final service = (await tester.runAsync(() async {
        final harness = await createBusinessTestHarness();
        final root = await Directory.systemTemp.createTemp(
          'genui-skill-prompt-',
        );
        final service = SkillsService(
          store: ExtensionEntityStore(harness.database),
          skillsDirectory: root,
        );
        addTearDown(() async {
          service.dispose();
          await root.delete(recursive: true);
        });
        await service.loaded;
        for (final id in ids) {
          await service.importFromText(
            '---\nname: $id\ndescription: Test $id\n---\n# $id\n',
          );
        }
        return service;
      }))!;
      late BuildContext context;
      await tester.pumpWidget(
        ChangeNotifierProvider<SkillsService>.value(
          value: service,
          child: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      final chats = _Chats();
      final builder = MessageBuilderService(
        chatService: chats,
        contextProvider: context,
      );
      final assistant = Assistant(id: 'a', name: 'A', skillIds: ids);
      final messages = <Map<String, dynamic>>[];
      await tester.runAsync(
        () => builder.injectSkillsPrompt(messages, assistant),
      );
      final text = jsonEncode(messages);
      for (final id in ids) {
        expect(text, contains('/skills/$id/SKILL.md'));
      }
      expect(text, contains('Additional explicitly selected skills'));
      chats.selected = Conversation(
        id: 'c',
        title: 'C',
        extras: const SkillsBinding(skillIds: ['s24']).applyTo({}),
      );
      final limited = <Map<String, dynamic>>[];
      await tester.runAsync(
        () =>
            builder.injectSkillsPrompt(limited, assistant, conversationId: 'c'),
      );
      expect(jsonEncode(limited), contains('/skills/s24/SKILL.md'));
      expect(jsonEncode(limited), isNot(contains('/skills/s00/SKILL.md')));
      await tester.runAsync(() => service.setEnabled('s24', false));
      final disabled = <Map<String, dynamic>>[];
      await tester.runAsync(
        () => builder.injectSkillsPrompt(
          disabled,
          assistant,
          conversationId: 'c',
        ),
      );
      expect(disabled, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
