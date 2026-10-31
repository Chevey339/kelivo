import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/message_part_snapshot.dart';
import 'package:Kelivo/features/home/controllers/assistant_part_snapshots.dart';
import 'package:Kelivo/features/home/controllers/chat_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checkpoint and UI independently accumulate skipped source updates', () {
    final sourceBuilder = MessagePartSnapshotBuilder(arrivalOrdered: true);
    final snapshots = AssistantPartSnapshots();
    final source = <MessagePart>[
      const ToolCallPart('{"id":"a"}'),
      const TextPart('hello'),
    ];
    var parts = sourceBuilder.update(source);
    String transform(String text) => text;
    snapshots.update(parts, transform: transform);
    snapshots.update(parts, transform: transform, visibleText: 'hel');
    source[0] = const ToolCallPart('{"id":"a","content":"done"}');
    parts = sourceBuilder.update(source, changed: {0});
    snapshots.update(parts, transform: transform, visibleText: 'hell');
    source[1] = const TextPart('hello world');
    parts = sourceBuilder.update(source, changed: {1});
    snapshots.update(parts, transform: transform, visibleText: 'hello');
    final checkpoint = snapshots.update(parts, transform: transform);
    expect(checkpoint, source);
    expect(
      snapshots.update(parts, transform: transform, visibleText: 'hello world'),
      source,
    );
  });

  test(
    'clipped, appended and removed text matches the typewriter contract',
    () {
      final sourceBuilder = MessagePartSnapshotBuilder();
      final snapshots = AssistantPartSnapshots();
      final parts = <MessagePart>[
        const TextPart('first'),
        const ToolCallPart('{}'),
        const TextPart('second'),
      ];
      for (final visible in [
        '',
        'fi',
        'first',
        'firstsec',
        'firstsecond',
        'f',
      ]) {
        final source = sourceBuilder.update(parts);
        expect(
          snapshots.update(
            source,
            transform: (text) => text,
            visibleText: visible,
          ),
          ChatActions.assistantPartsForVisibleText(
            parts: source,
            visibleText: visible,
          ),
        );
      }
      parts.removeAt(0);
      expect(
        snapshots.update(
          sourceBuilder.update(parts),
          transform: (text) => text,
        ),
        parts,
      );
    },
  );

  test('transforms only changed text after thousands of completed tools', () {
    final sourceBuilder = MessagePartSnapshotBuilder();
    final snapshots = AssistantPartSnapshots();
    final parts = <MessagePart>[
      for (var i = 0; i < 1000; i++) ...[
        const ToolCallPart('{}'),
        TextPart('text $i'),
      ],
    ];
    var transforms = 0;
    String transform(String text) {
      transforms++;
      return text;
    }

    snapshots.update(sourceBuilder.update(parts), transform: transform);
    final before = transforms;
    parts[1999] = const TextPart('new tail');
    snapshots.update(
      sourceBuilder.update(parts, changed: {1999}),
      transform: transform,
    );
    expect(transforms - before, 1);
  });
}
