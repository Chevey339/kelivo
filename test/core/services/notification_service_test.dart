import 'dart:io';

import 'package:Kelivo/core/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationService.shouldShowChatCompleted', () {
    test(
      'suppresses notification only for the visible current Android chat',
      () {
        expect(
          NotificationService.shouldShowChatCompleted(
            isAndroid: true,
            notifyModeEnabled: true,
            appInForeground: true,
            homeRouteVisible: true,
            isCurrentConversation: true,
          ),
          isFalse,
        );

        for (final state in [
          (
            appInForeground: false,
            homeRouteVisible: true,
            isCurrentConversation: true,
          ),
          (
            appInForeground: true,
            homeRouteVisible: false,
            isCurrentConversation: true,
          ),
          (
            appInForeground: true,
            homeRouteVisible: true,
            isCurrentConversation: false,
          ),
        ]) {
          expect(
            NotificationService.shouldShowChatCompleted(
              isAndroid: true,
              notifyModeEnabled: true,
              appInForeground: state.appInForeground,
              homeRouteVisible: state.homeRouteVisible,
              isCurrentConversation: state.isCurrentConversation,
            ),
            isTrue,
          );
        }
      },
    );

    test('requires Android and the notify background mode', () {
      expect(
        NotificationService.shouldShowChatCompleted(
          isAndroid: false,
          notifyModeEnabled: true,
          appInForeground: false,
          homeRouteVisible: false,
          isCurrentConversation: false,
        ),
        isFalse,
      );
      expect(
        NotificationService.shouldShowChatCompleted(
          isAndroid: true,
          notifyModeEnabled: false,
          appInForeground: false,
          homeRouteVisible: false,
          isCurrentConversation: false,
        ),
        isFalse,
      );
    });
  });

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
    'Android startup registers notification taps before reading the mode',
    () async {
      final source = await File('lib/main.dart').readAsString();
      final bindingIndex = source.indexOf(
        'WidgetsFlutterBinding.ensureInitialized();',
      );
      final initializationIndex = source.indexOf(
        'await NotificationService.ensureInitialized();',
      );
      final modeReadIndex = source.indexOf(
        'settings.androidBackgroundChatMode',
      );
      final permissionIndex = source.indexOf(
        'await NotificationService.ensureAndroidNotificationsPermission();',
      );

      expect(bindingIndex, greaterThanOrEqualTo(0));
      expect(initializationIndex, greaterThan(bindingIndex));
      expect(modeReadIndex, greaterThan(initializationIndex));
      expect(permissionIndex, greaterThan(modeReadIndex));
    },
  );
}
