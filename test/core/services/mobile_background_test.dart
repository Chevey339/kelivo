import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/models/mobile_background_settings.dart';
import 'package:Kelivo/core/services/mobile_background.dart';
import 'package:Kelivo/core/services/notification_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.mobile_background');
  final calls = <MethodCall>[];
  final notifications = <Map<String, String?>>[];
  final order = <String>[];
  late MobileBackgroundCoordinator coordinator;
  late AppLocalizations l10n;
  Future<dynamic> Function(MethodCall)? intercept;

  setUp(() async {
    calls.clear();
    notifications.clear();
    order.clear();
    intercept = null;
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'sync') order.add('sync');
          if (intercept != null) return intercept!(call);
          return call.method == 'sync' || call.method == 'getStatus'
              ? <String, dynamic>{'notificationsAuthorized': false}
              : null;
        });
    coordinator = MobileBackgroundCoordinator(
      channel: channel,
      platform: TargetPlatform.android,
      notificationSender: ({required conversationId, title, body}) async {
        order.add('notification');
        notifications.add({'id': conversationId, 'title': title, 'body': body});
      },
    );
    await coordinator.configure(const MobileBackgroundSettings(), l10n);
  });

  tearDown(() async {
    await coordinator.flush();
    coordinator.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    NotificationService.takePendingConversationId();
  });

  List<Map<dynamic, dynamic>> snapshots() => calls
      .where((c) => c.method == 'sync')
      .map((c) => c.arguments as Map<dynamic, dynamic>)
      .toList();

  test(
    'equal appearance settings do not repeatedly sync native resources',
    () async {
      final settings = MobileBackgroundSettings(
        overlayAppearance: BackgroundOverlayAppearance.circle.copyWith(
          width: 80,
        ),
      );
      await coordinator.configure(settings, l10n);
      final count = snapshots().length;
      await coordinator.configure(
        MobileBackgroundSettings.fromJson(settings.toJson()),
        l10n,
      );
      expect(snapshots(), hasLength(count));
      await coordinator.configure(
        settings.copyWith(
          overlayAppearance: settings.overlayAppearance.copyWith(
            showTime: true,
          ),
        ),
        l10n,
      );
      expect(snapshots(), hasLength(count + 1));
    },
  );

  Future<void> start(
    String id, {
    String? conversationId,
    Future<void> Function()? cancel,
  }) => coordinator.start(
    id: id,
    conversationId: conversationId ?? 'chat-$id',
    title: 'Private $id',
    cancel: cancel ?? () async {},
  );

  test(
    'initialization and status never request permissions or enable features',
    () async {
      await coordinator.refreshStatus();
      await start('a');
      final settings = snapshots().last['settings'] as Map;
      expect(settings.values.whereType<bool>(), everyElement(isFalse));
      expect(calls.map((c) => c.method), isNot(contains('requestPermission')));
      await coordinator.finish('a', BackgroundTaskOutcome.completed);
      expect(notifications, isEmpty);
    },
  );

  test(
    'concurrent conversations end independently; stale updates cannot reopen a run',
    () async {
      await start('a');
      await start('b');
      await coordinator.finish('a', BackgroundTaskOutcome.completed);
      coordinator.update(
        'a',
        phase: BackgroundTaskPhase.generating,
        tokens: 999,
      );
      coordinator.update(
        'b',
        phase: BackgroundTaskPhase.tool,
        toolName: 'shell',
        tokens: 42,
      );
      await coordinator.flush();
      expect(coordinator.activeTaskIds, {'b'});
      final tasks = snapshots().last['tasks'] as List;
      expect(tasks, hasLength(1));
      expect(tasks.single['id'], 'b');
      expect(tasks.single['tokens'], 42);
      expect(tasks.single['detail'], contains('shell'));
      await coordinator.finish('b', BackgroundTaskOutcome.cancelled);
      expect(snapshots().last['tasks'], isEmpty);
    },
  );

  test(
    'burst updates coalesce and terminal payload preserves latest token count',
    () async {
      await start('a');
      final before = snapshots().length;
      for (var i = 0; i < 1000; i++) {
        coordinator.update(
          'a',
          phase: BackgroundTaskPhase.generating,
          tokens: i,
        );
      }
      await coordinator.finish('a', BackgroundTaskOutcome.completed);
      expect(snapshots().length, before + 1);
      expect((snapshots().last['terminal'] as Map)['tokens'], 999);
      await coordinator.finish('a', BackgroundTaskOutcome.completed);
      expect(snapshots().length, before + 1);
    },
  );

  test(
    'notification precedes resource release even with earlier queued updates',
    () async {
      await coordinator.configure(
        const MobileBackgroundSettings(notificationsEnabled: true),
        l10n,
      );
      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
      await start('a');
      final entered = Completer<void>();
      final release = Completer<void>();
      var blocked = false;
      intercept = (call) async {
        if (call.method == 'sync' && !blocked) {
          blocked = true;
          entered.complete();
          await release.future;
        }
        return <String, dynamic>{};
      };
      final first = coordinator.configure(
        const MobileBackgroundSettings(
          notificationsEnabled: true,
          overlayEnabled: true,
        ),
        l10n,
      );
      await entered.future;
      final second = coordinator.configure(
        const MobileBackgroundSettings(
          notificationsEnabled: true,
          overlayEnabled: true,
          liveUpdatesEnabled: true,
        ),
        l10n,
      );
      await Future<void>.delayed(Duration.zero);
      final finish = coordinator.finish('a', BackgroundTaskOutcome.completed);
      order.clear();
      release.complete();
      await Future.wait([first, second, finish]);
      expect(order, ['sync', 'notification', 'sync']);
      final last = snapshots();
      expect(last[last.length - 2]['tasks'], hasLength(1));
      expect(last.last['tasks'], isEmpty);
      expect(notifications, hasLength(1));
    },
  );

  test(
    'privacy redacts pending updates as well as completion notifications',
    () async {
      await start('secret');
      await coordinator.configure(
        const MobileBackgroundSettings(
          privacyMode: true,
          notificationsEnabled: true,
        ),
        l10n,
      );
      coordinator.update(
        'secret',
        phase: BackgroundTaskPhase.tool,
        toolName: 'secret-file.txt',
        tokens: 42,
      );
      await coordinator.flush();
      final serialized = jsonEncode(snapshots().last);
      expect(serialized, isNot(contains('Private secret')));
      expect(serialized, isNot(contains('secret-file.txt')));
      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
      await coordinator.finish('secret', BackgroundTaskOutcome.failed);
      expect(notifications.single['title'], l10n.backgroundTaskTitle);
      expect(notifications.single['body'], l10n.backgroundFailed);
      expect((snapshots().last['terminal'] as Map)['tokens'], 0);
    },
  );

  test(
    'only the visible foreground conversation suppresses task notifications',
    () async {
      await coordinator.configure(
        const MobileBackgroundSettings(notificationsEnabled: true),
        l10n,
      );
      coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
      coordinator.visibleConversation = () => 'visible';
      await start('a', conversationId: 'visible');
      await coordinator.finish('a', BackgroundTaskOutcome.completed);
      expect(notifications, isEmpty);
      await start('b', conversationId: 'other');
      await coordinator.finish('b', BackgroundTaskOutcome.failed);
      expect(notifications.single['id'], 'other');
      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
      await start('c', conversationId: 'visible');
      await coordinator.finish('c', BackgroundTaskOutcome.completed);
      await start('d');
      await coordinator.finish('d', BackgroundTaskOutcome.cancelled);
      expect(notifications.map((n) => n['id']), ['other', 'visible']);
    },
  );

  test(
    'native errors remain observable and do not block a later terminal update',
    () async {
      intercept = (_) async => throw PlatformException(code: 'start_failed');
      await start('a');
      expect(coordinator.lastError, contains('start_failed'));
      intercept = null;
      await coordinator.finish('a', BackgroundTaskOutcome.failed);
      expect(coordinator.activeTaskIds, isEmpty);
      expect((snapshots().last['terminal'] as Map)['outcome'], 'failed');
    },
  );

  test('permission dialogs cannot hold up task finalization', () async {
    final dialog = Completer<void>();
    intercept = (call) async {
      if (call.method == 'requestPermission') await dialog.future;
      return call.method == 'sync' ? <String, dynamic>{} : null;
    };
    await start('a');
    final permission = coordinator.requestPermission('notifications');
    await coordinator.finish('a', BackgroundTaskOutcome.cancelled);
    expect(coordinator.activeTaskIds, isEmpty);
    expect(dialog.isCompleted, isFalse);
    dialog.complete();
    await permission;
  });

  test(
    'an unpersisted failure releases resources without publishing a notification',
    () async {
      await coordinator.configure(
        const MobileBackgroundSettings(notificationsEnabled: true),
        l10n,
      );
      await start('a');
      await coordinator.finish(
        'a',
        BackgroundTaskOutcome.failed,
        resultPersisted: false,
      );
      expect(coordinator.activeTaskIds, isEmpty);
      expect(snapshots().last['tasks'], isEmpty);
      expect(notifications, isEmpty);
    },
  );

  test(
    'native interruption cancels only the identified live run and reports failure once',
    () async {
      await coordinator.configure(
        const MobileBackgroundSettings(notificationsEnabled: true),
        l10n,
      );
      var cancellations = 0;
      await start(
        'a',
        cancel: () async {
          cancellations++;
          await coordinator.finish('a', BackgroundTaskOutcome.cancelled);
        },
      );
      await start('b');
      final response = Completer<void>();
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('interrupted', {
                'ids': ['a', 'old-run'],
                'reason': 'foreground_service_timeout',
              }),
            ),
            (_) => response.complete(),
          );
      await response.future;
      await coordinator.flush();
      expect(cancellations, 1);
      expect(coordinator.activeTaskIds, {'b'});
      expect(notifications.single['body'], l10n.backgroundInterrupted);
      await coordinator.finish('b', BackgroundTaskOutcome.cancelled);
    },
  );
  test(
    'scheduled completion notifies once with the saved reply preview',
    () async {
      coordinator.didChangeAppLifecycleState(AppLifecycleState.detached);
      coordinator.visibleConversation = () => 'scheduled-chat';
      await coordinator.start(
        id: 'scheduled',
        conversationId: 'scheduled-chat',
        title: 'Morning brief',
        scheduled: true,
        cancel: () async {},
      );
      final reply = List.filled(205, '👨‍👩‍👧‍👦').join();
      await coordinator.finish(
        'scheduled',
        BackgroundTaskOutcome.completed,
        replyPreview: reply,
      );
      await coordinator.finish(
        'scheduled',
        BackgroundTaskOutcome.completed,
        replyPreview: reply,
      );
      expect(notifications, hasLength(1));
      expect(notifications.single['id'], 'scheduled-chat');
      expect(notifications.single['title'], 'Morning brief');
      expect(
        notifications.single['body'],
        List.filled(200, '👨‍👩‍👧‍👦').join(),
      );
      expect(
        order.indexOf('notification'),
        lessThan(order.lastIndexOf('sync')),
      );
      expect(coordinator.settings.notificationsEnabled, isFalse);
    },
  );

  test(
    'scheduled notifications respect privacy and persisted outcomes',
    () async {
      await coordinator.configure(
        const MobileBackgroundSettings(privacyMode: true),
        l10n,
      );
      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
      Future<void> schedule(String id) => coordinator.start(
        id: id,
        conversationId: 'secret-chat',
        title: 'Secret title',
        scheduled: true,
        cancel: () async {},
      );
      await schedule('success');
      await coordinator.finish(
        'success',
        BackgroundTaskOutcome.completed,
        replyPreview: 'Secret reply',
      );
      expect(notifications.single['title'], l10n.backgroundTaskTitle);
      expect(notifications.single['body'], l10n.backgroundCompleted);
      await schedule('unwritten');
      await coordinator.finish(
        'unwritten',
        BackgroundTaskOutcome.completed,
        resultPersisted: false,
        replyPreview: 'Not saved',
      );
      await schedule('cancelled');
      await coordinator.finish('cancelled', BackgroundTaskOutcome.cancelled);
      expect(notifications, hasLength(1));
    },
  );

  test(
    'opening the scheduled conversation suppresses its completion notification',
    () async {
      coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
      coordinator.visibleConversation = () => 'visible';
      await coordinator.start(
        id: 'viewed-task',
        conversationId: 'visible',
        title: 'Visible task',
        scheduled: true,
        cancel: () async {},
      );
      await coordinator.finish(
        'viewed-task',
        BackgroundTaskOutcome.completed,
        replyPreview: 'Already on screen',
      );
      expect(notifications, isEmpty);
    },
  );
}
