import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/chat_message.dart';

void main() {
  group('ChatMessage request metadata', () {
    test('requestExtraBody decodes persisted JSON map', () {
      final message = ChatMessage(
        role: 'user',
        content: 'draw a cat',
        conversationId: 'conversation-1',
        requestExtraBodyJson:
            '{"quality":"high","size":"3840x2160","output_format":"png"}',
      );

      expect(message.requestExtraBody, {
        'quality': 'high',
        'size': '3840x2160',
        'output_format': 'png',
      });
    });

    test('toJson/fromJson preserves request routing metadata', () {
      final message = ChatMessage(
        id: 'message-1',
        role: 'user',
        content: 'draw a cat',
        conversationId: 'conversation-1',
        requestAllowImagesApiRouting: false,
        requestExtraBodyJson:
            '{"quality":"medium","output_format":"webp","n":2}',
      );

      final roundTrip = ChatMessage.fromJson(message.toJson());

      expect(roundTrip.requestAllowImagesApiRouting, isFalse);
      expect(roundTrip.requestExtraBody, {
        'quality': 'medium',
        'output_format': 'webp',
        'n': 2,
      });
    });
  });
}
