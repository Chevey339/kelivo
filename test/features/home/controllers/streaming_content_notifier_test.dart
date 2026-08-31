import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/features/home/controllers/streaming_content_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StreamingContentData treats equal part values as equal', () {
    final a = StreamingContentData(
      content: 'hi',
      totalTokens: 1,
      parts: const [TextPart('hi'), ReasoningPart('plan')],
    );
    final b = StreamingContentData(
      content: 'hi',
      totalTokens: 1,
      parts: const [TextPart('hi'), ReasoningPart('plan')],
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('forceRebuild keeps streaming content splits', () {
    final notifier = StreamingContentNotifier();
    addTearDown(notifier.dispose);
    notifier.getNotifier('m1');
    notifier.updateContent(
      'm1',
      'hello world',
      4,
      parts: const [ReasoningPart('plan'), TextPart('hello world')],
      contentSplitOffsets: const [0, 6],
      reasoningCountAtSplit: const [1, 1],
      toolCountAtSplit: const [0, 1],
    );

    notifier.forceRebuild('m1');
    final data = notifier.getNotifier('m1').value;
    expect(data.uiVersion, 1);
    expect(data.content, 'hello world');
    expect(data.contentSplitOffsets, const [0, 6]);
    expect(data.reasoningCountAtSplit, const [1, 1]);
    expect(data.toolCountAtSplit, const [0, 1]);
    expect(data.parts, hasLength(2));
  });

  test('structure signature is not jsonDecoded on every read', () {
    debugToolIdentityDecodeCount = 0;
    final parts = <MessagePart>[
      const ReasoningPart('plan'),
      const TextPart('hello'),
      for (var i = 0; i < 30; i++)
        ToolCallPart(
          '{"id":"t$i","name":"read_file","arguments":{"path":"$i.dart"}}',
        ),
    ];
    final data = StreamingContentData(
      content: 'hello',
      totalTokens: 1,
      parts: parts,
    );
    expect(debugToolIdentityDecodeCount, 30);

    data.timelineStructureSignature;
    data.timelineStructureSignature;
    expect(debugToolIdentityDecodeCount, 30);

    final grown = data.copyWith(content: 'hello world', totalTokens: 2);
    expect(grown.timelineStructureSignature, data.timelineStructureSignature);
    expect(debugToolIdentityDecodeCount, 30);

    final sameStructure = data.copyWith(
      parts: [
        const ReasoningPart('plan changed'),
        const TextPart('hello grown'),
        for (var i = 0; i < 30; i++)
          ToolCallPart(
            '{"id":"t$i","name":"read_file","arguments":{"path":"$i.dart"}}',
          ),
      ],
    );
    expect(
      sameStructure.timelineStructureSignature,
      data.timelineStructureSignature,
    );
    expect(debugToolIdentityDecodeCount, 30);
  });

  test('growing image URI does not repeatedly fire height events', () async {
    final notifier = StreamingContentNotifier();
    addTearDown(notifier.dispose);
    notifier.getNotifier('img');
    final seen = <int>[];
    notifier.toolHeightEvents.addListener(() {
      final event = notifier.toolHeightEvents.value;
      if (event != null) seen.add(event.version);
    });

    notifier.updateContent(
      'img',
      '',
      0,
      parts: const [ImagePart(uri: 'data:image/png;base64,AA')],
    );
    await Future<void>.delayed(Duration.zero);
    expect(seen, hasLength(1));

    notifier.updateContent(
      'img',
      '',
      0,
      parts: const [ImagePart(uri: 'data:image/png;base64,AAAA')],
    );
    notifier.updateContent(
      'img',
      '',
      0,
      parts: const [ImagePart(uri: 'data:image/png;base64,AAAAAAAA')],
    );
    await Future<void>.delayed(Duration.zero);
    expect(seen, hasLength(1));
  });

  test('updateRetryStatus is restored onto a new notifier after clear', () {
    final notifier = StreamingContentNotifier();
    addTearDown(notifier.dispose);
    final status = RetryStatus(
      attempt: 1,
      maxRetries: 3,
      retryAt: DateTime(2026, 8, 30, 21),
    );
    notifier.updateRetryStatus('m1', status);
    expect(notifier.getNotifier('m1').value.retryStatus, status);
    notifier.clear();
    expect(notifier.hasNotifier('m1'), isFalse);
    notifier.updateRetryStatus('m1', status);
    expect(notifier.getNotifier('m1').value.retryStatus, status);
  });
}
