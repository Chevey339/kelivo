import 'package:Kelivo/core/services/api/providers/openai/chat_completions_api.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_vendor_compat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('skipImageParsing leaves markdown images as plain text', () async {
    const raw = 'see ![x](data:image/png;base64,abc) later';
    final messages = await buildOpenAIChatCompletionMessages(
      [
        <String, dynamic>{'role': 'user', 'content': raw},
      ],
      canImageInput: true,
      allowRemoteImages: true,
      reasoningContentReplayPolicy: ReasoningContentReplayPolicy.none,
      skipImageParsing: true,
    );

    expect(messages, hasLength(1));
    expect(messages.single['content'], raw);
    expect(messages.single['content'], isA<String>());
  });

  test('markdown images are extracted when parsing is enabled', () async {
    const raw = 'see ![x](data:image/png;base64,abc) later';
    final messages = await buildOpenAIChatCompletionMessages(
      [
        <String, dynamic>{'role': 'user', 'content': raw},
      ],
      canImageInput: true,
      allowRemoteImages: false,
      reasoningContentReplayPolicy: ReasoningContentReplayPolicy.none,
    );

    final content = messages.single['content'];
    expect(content, isA<List>());
    final parts = (content as List).cast<Map>();
    expect(parts.any((part) => part['type'] == 'image_url'), isTrue);
    expect(
      parts.where((part) => part['type'] == 'text').map((part) => part['text']),
      isNot(contains(contains('!['))),
    );
  });

  test(
    'skipImageParsing keeps remote markdown images out of image_url parts',
    () async {
      const raw = 'doc ![pic](https://example.invalid/pic.jpg) end';
      final messages = await buildOpenAIChatCompletionMessages(
        [
          <String, dynamic>{'role': 'user', 'content': raw},
        ],
        canImageInput: true,
        allowRemoteImages: true,
        reasoningContentReplayPolicy: ReasoningContentReplayPolicy.none,
        skipImageParsing: true,
      );

      expect(messages.single['content'], raw);
    },
  );
}
