import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/message_part_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('snapshots are immutable and journal unions skipped updates', () {
    final builder = MessagePartSnapshotBuilder(arrivalOrdered: true);
    final source = <MessagePart>[const TextPart('a'), const ToolCallPart('{}')];
    final first = builder.update(source);
    source[0] = const TextPart('b');
    final second = builder.update(source, changed: {0});
    source[1] = const ToolCallPart('{"content":"done"}');
    final third = builder.update(source, changed: {1});
    expect(first[0], const TextPart('a'));
    expect(() => first[0] = const TextPart('no'), throwsUnsupportedError);
    expect(third.changesSince(first), {0, 1});
    expect(second.toolsRevision, first.toolsRevision);
    expect(third.toolsRevision, greaterThan(first.toolsRevision));
    expect(third.structureRevision, first.structureRevision);
    final message = ChatMessage(
      role: 'assistant',
      conversationId: 'c',
      parts: third,
    );
    expect(message.copyWith(totalTokens: 10).parts, same(third));
  });

  test('expired and unrelated journals request a full rebuild', () {
    final builder = MessagePartSnapshotBuilder();
    final first = builder.update(const [TextPart('0')]);
    var current = first;
    for (var i = 1; i < 100; i++) {
      current = builder.update([TextPart('$i')]);
    }
    expect(current.changesSince(first), isNull);
    expect(
      MessagePartSnapshotBuilder()
          .update(const [TextPart('x')])
          .changesSince(current),
      isNull,
    );
  });
}
