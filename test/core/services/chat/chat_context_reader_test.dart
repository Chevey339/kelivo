import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/compression_config.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/chat/chat_context_reader.dart';

void main() {
  ChatMessage message({
    int boundaries = 1,
    String call = 'call',
    String? text,
  }) => ChatMessage(
    id: 'answer',
    conversationId: 'chat',
    role: 'assistant',
    parts: [
      ToolCallPart(
        jsonEncode({
          'id': call,
          'name': 'read_file',
          'content': text ?? 'result ' * 400,
        }),
      ),
      for (var i = 0; i < boundaries; i++) const AssistantRoundEndPart(),
    ],
  );

  test(
    'a tool-call response boundary alone never offloads its unread result',
    () async {
      var visible = [message()];
      final reader = ChatContextReader(() async => visible);
      expect(await reader.replacements({}), isEmpty);
      expect(await reader.replacements({'call'}), contains('call'));
      visible = [message(boundaries: 2)];
      expect(await reader.replacements({}), contains('call'));
      visible = [
        message()..hydrateGenerationState(GenerationRunState.completed),
      ];
      expect(await reader.replacements({}), contains('call'));
      visible = [
        message()..hydrateGenerationState(GenerationRunState.cancelled),
      ];
      expect(await reader.replacements({}), isEmpty);
    },
  );

  test('reused call IDs leave both old and newest results intact', () async {
    final older = message().copyWith(id: 'older')
      ..hydrateGenerationState(GenerationRunState.completed);
    final latest = message().copyWith(id: 'latest');
    final reader = ChatContextReader(() async => [older, latest]);
    expect(await reader.replacements({'call'}), isEmpty);
  });

  test(
    'issued handles recheck selected history and tool identity on every read',
    () async {
      var visible = [message()];
      final reader = ChatContextReader(() async => visible);
      final source = contextTextReference('answer', 0, 'call');
      expect(await reader.read(source, 0), contains('unavailable'));
      await reader.replacements({'call'});
      expect(jsonDecode(await reader.read(source, 0))['call_id'], 'call');
      visible = [message(call: 'different-call')];
      expect(await reader.read(source, 0), contains('changed'));
      visible = [];
      expect(await reader.read(source, 0), contains('no longer visible'));
    },
  );

  test(
    'pagination reconstructs full Unicode result without splitting emoji',
    () async {
      final original = '${'a' * 5999}😀${'tail ' * 1800}';
      final reader = ChatContextReader(() async => [message(text: original)]);
      await reader.replacements({'call'});
      final source = contextTextReference('answer', 0, 'call');
      final reconstructed = StringBuffer();
      var offset = 0;
      do {
        final page = jsonDecode(await reader.read(source, offset)) as Map;
        final content = page['content'] as String;
        expect(content.length, lessThanOrEqualTo(6000));
        expect(utf8.decode(utf8.encode(content)), content);
        reconstructed.write(content);
        if (page['next_offset'] == null) break;
        offset = page['next_offset'] as int;
      } while (true);
      expect(reconstructed.toString(), original);
    },
  );
}
