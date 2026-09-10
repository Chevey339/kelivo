import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/chat/prepared_context_store.dart';
import 'package:Kelivo/core/services/logging/context_logger.dart';

void main() {
  PreparedContextSnapshot snapshot(String id, int revision) =>
      PreparedContextSnapshot(
        generationId: '$id-$revision',
        context: ContextLogger.buildSnapshot(
          apiMessages: [
            {
              'role': 'user',
              'content': 'hello data:image/png;base64,AQIDBAUGBwgJCgsMDQ4PEA==',
            },
          ],
          conversationId: id,
          assistantName: 'A',
          provider: 'P',
          model: 'M',
          timestamp: DateTime.utc(2026).add(Duration(seconds: revision)),
        ),
        tools: [
          {
            'type': 'function',
            'function': {'name': 'read_file'},
          },
        ],
      );

  test('keeps one snapshot per conversation, evicts the oldest of eight', () {
    final store = PreparedContextStore();
    addTearDown(store.dispose);
    for (var i = 0; i < 8; i++) {
      store.record(snapshot('$i', i));
    }
    store.record(snapshot('0', 10));
    store.record(snapshot('8', 11));
    expect(store.forConversation('1'), isNull);
    expect(store.forConversation('0')?.generationId, '0-10');
    expect(store.forConversation('8')?.toolNames, ['read_file']);
    expect(store.forConversation('8')!.toolTokens, greaterThan(0));
    store.record(snapshot('0', 1));
    expect(store.forConversation('0')?.generationId, '0-10');
    store.remove('0');
    expect(store.forConversation('0'), isNull);
    expect(store.forConversation('8'), isNotNull);
    store.clear();
    expect(store.forConversation('8'), isNull);
  });

  test(
    'retains readable text but elides binary data without enabling logs',
    () {
      final before = ContextLogger.enabled;
      final value = snapshot('a', 1);
      final text = value.context.messages.single.segments.single.text;
      expect(text, contains('hello'));
      expect(text, isNot(contains('AQIDBAUGBwgJCgsMDQ4PEA==')));
      expect(ContextLogger.enabled, before);
    },
  );
  test('large typed binary JSON is elided without changing request data', () {
    final binary = 'A' * 5000;
    final content = jsonEncode({'mime_type': 'image/png', 'data': binary});
    final context = ContextLogger.buildSnapshot(
      apiMessages: [
        {'role': 'tool', 'content': content},
      ],
      conversationId: 'a',
      assistantName: 'A',
      provider: 'P',
      model: 'M',
    );
    expect(
      context.messages.single.segments.single.text,
      isNot(contains(binary)),
    );
    expect(content, contains(binary));
  });
}
