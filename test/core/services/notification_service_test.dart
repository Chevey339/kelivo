import 'package:Kelivo/core/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'chat completion payload accepts only non-empty conversation targets',
    () {
      expect(
        NotificationService.conversationIdFromPayload(
          'chat-complete:conversation-1',
        ),
        'conversation-1',
      );
      expect(NotificationService.conversationIdFromPayload(null), isNull);
      expect(
        NotificationService.conversationIdFromPayload('conversation-1'),
        isNull,
      );
      expect(
        NotificationService.conversationIdFromPayload('chat-complete:   '),
        isNull,
      );
    },
  );

  test('notification IDs are stable and avoid foreground-service IDs', () {
    final first = NotificationService.notificationIdForConversation(
      'conversation-1',
    );
    expect(
      NotificationService.notificationIdForConversation('conversation-1'),
      first,
    );
    expect(
      NotificationService.notificationIdForConversation('conversation-2'),
      isNot(first),
    );
    expect(first, greaterThanOrEqualTo(10000));
  });

  test(
    'native cold and warm taps preserve their conversation target',
    () async {
      NotificationService.openConversation('cold');
      expect(NotificationService.takePendingConversationId(), 'cold');
      expect(NotificationService.takePendingConversationId(), isNull);
      final received = <String>[];
      final sub = NotificationService.conversationTaps.listen(received.add);
      NotificationService.openConversation('warm');
      await Future<void>.delayed(Duration.zero);
      expect(received, ['warm']);
      await sub.cancel();
    },
  );
}
