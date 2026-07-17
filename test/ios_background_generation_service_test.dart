import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/ios_background_generation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app.ios_background_generation');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'getStatus':
              return <String, Object?>{
                'backgroundTaskActive': false,
                'liveActivityActive': false,
                'notificationsAuthorized': true,
                'liveActivitiesEnabled': true,
              };
            case 'start':
            case 'update':
            case 'finish':
            case 'cancel':
            case 'requestNotificationAuthorization':
            case 'openAppSettings':
            case 'openNotificationSettings':
              return true;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await IosBackgroundGenerationService.instance.resetForTest();
  });

  test('does nothing on non-iOS platforms', () async {
    await IosBackgroundGenerationService.instance.start(
      enabled: true,
      liveActivityEnabled: true,
      notificationsEnabled: true,
      refreshEnabled: true,
      title: 'Generating',
      detail: 'Assistant is replying',
      tokenLabel: '0 tokens',
    );

    if (!Platform.isIOS) {
      expect(calls, isEmpty);
    }
  });

  test('does nothing when the primary setting is disabled', () async {
    await IosBackgroundGenerationService.instance.start(
      enabled: false,
      liveActivityEnabled: true,
      notificationsEnabled: true,
      refreshEnabled: true,
      title: 'Generating',
      detail: 'Assistant is replying',
      tokenLabel: '0 tokens',
    );

    expect(calls, isEmpty);
  });

  test('disabled start prevents stale native session calls', () async {
    final service = IosBackgroundGenerationService.instance
      ..debugForceIosForTest = true;

    await service.start(
      enabled: true,
      liveActivityEnabled: true,
      notificationsEnabled: true,
      refreshEnabled: true,
      title: 'Generating',
      detail: 'Assistant is replying',
      tokenLabel: '0 tokens',
    );
    await service.finish(
      title: 'Complete',
      detail: 'Assistant reply is ready',
      success: true,
    );
    calls.clear();

    await service.start(
      enabled: false,
      liveActivityEnabled: true,
      notificationsEnabled: true,
      refreshEnabled: true,
      title: 'Generating',
      detail: 'Assistant is replying',
      tokenLabel: '0 tokens',
    );
    service.scheduleUpdate(detail: 'Streaming', tokenLabel: '12 tokens');
    await service.flushUpdates();
    await service.finish(
      title: 'Complete',
      detail: 'Assistant reply is ready',
      success: true,
    );
    await service.cancel(detail: 'Stopped');

    expect(calls, isEmpty);
  });

  test('sends live activity data without synthetic progress', () async {
    final service = IosBackgroundGenerationService.instance
      ..debugForceIosForTest = true;

    await service.start(
      enabled: true,
      liveActivityEnabled: true,
      notificationsEnabled: true,
      refreshEnabled: true,
      title: 'Generating',
      detail: 'Assistant is replying',
      tokenLabel: '0 tokens',
    );
    service.scheduleUpdate(
      detail: 'Streaming',
      tokenLabel: '12 tokens',
      tokenCount: 12,
    );
    await service.flushUpdates();
    await service.finish(
      title: 'Complete',
      detail: 'Assistant reply is ready',
      success: true,
    );

    expect(calls.map((call) => call.method), <String>[
      'requestNotificationAuthorization',
      'start',
      'update',
      'finish',
    ]);
    expect(calls[1].arguments, <String, Object?>{
      'liveActivityEnabled': true,
      'notificationsEnabled': true,
      'refreshEnabled': true,
      'title': 'Generating',
      'detail': 'Assistant is replying',
      'tokenCount': 0,
      'tokenLabel': '0 tokens',
    });
    expect(calls[2].arguments, <String, Object?>{
      'detail': 'Streaming',
      'tokenLabel': '12 tokens',
      'tokenCount': 12,
    });
  });

  test(
    'high-frequency updates do not await channel and keep latest pending',
    () async {
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'start') return true;
            if (call.method == 'update' && !firstStarted.isCompleted) {
              firstStarted.complete();
              await releaseFirst.future;
            }
            return true;
          });
      final service = IosBackgroundGenerationService.instance
        ..debugForceIosForTest = true
        ..updateMinimumIntervalForTest = Duration.zero;
      await service.start(
        enabled: true,
        liveActivityEnabled: true,
        notificationsEnabled: false,
        refreshEnabled: true,
        title: 'Generating',
        detail: 'Assistant is replying',
        tokenLabel: '0 tokens',
      );
      calls.clear();

      service.scheduleUpdate(
        detail: 'Streaming',
        tokenLabel: '1 token',
        tokenCount: 1,
      );
      await firstStarted.future;
      service
        ..scheduleUpdate(
          detail: 'Streaming',
          tokenLabel: '2 tokens',
          tokenCount: 2,
        )
        ..scheduleUpdate(
          detail: 'Streaming',
          tokenLabel: '3 tokens',
          tokenCount: 3,
        );

      expect(calls.where((call) => call.method == 'update'), hasLength(1));
      releaseFirst.complete();
      await service.flushUpdates();

      final updates = calls.where((call) => call.method == 'update').toList();
      expect(updates, hasLength(2));
      expect((updates.last.arguments as Map)['tokenCount'], 3);
    },
  );

  test(
    'finish waits for in-flight/latest update before terminal call',
    () async {
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'start') return true;
            if (call.method == 'update' && !firstStarted.isCompleted) {
              firstStarted.complete();
              await releaseFirst.future;
            }
            return true;
          });
      final service = IosBackgroundGenerationService.instance
        ..debugForceIosForTest = true
        ..updateMinimumIntervalForTest = Duration.zero;
      await service.start(
        enabled: true,
        liveActivityEnabled: true,
        notificationsEnabled: false,
        refreshEnabled: true,
        title: 'Generating',
        detail: 'Assistant is replying',
        tokenLabel: '0 tokens',
      );
      calls.clear();
      service.scheduleUpdate(
        detail: 'Streaming',
        tokenLabel: '1 token',
        tokenCount: 1,
      );
      await firstStarted.future;
      service.scheduleUpdate(
        detail: 'Streaming',
        tokenLabel: '9 tokens',
        tokenCount: 9,
      );

      final finishFuture = service.finish(
        title: 'Complete',
        detail: 'Ready',
        success: true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(calls.any((call) => call.method == 'finish'), isFalse);
      releaseFirst.complete();
      await finishFuture;

      expect(calls.map((call) => call.method), ['update', 'update', 'finish']);
      expect((calls[1].arguments as Map)['tokenCount'], 9);
    },
  );

  test(
    'scheduled update failure is observable and does not block finish',
    () async {
      final observed = Completer<Object>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'start' || call.method == 'finish') return true;
            if (call.method == 'update') {
              throw PlatformException(code: 'update_failed');
            }
            return true;
          });
      final service = IosBackgroundGenerationService.instance
        ..debugForceIosForTest = true
        ..updateMinimumIntervalForTest = Duration.zero;
      await service.start(
        enabled: true,
        liveActivityEnabled: true,
        notificationsEnabled: false,
        refreshEnabled: true,
        title: 'Generating',
        detail: 'Assistant is replying',
        tokenLabel: '0 tokens',
      );

      service.scheduleUpdate(
        detail: 'Streaming',
        tokenLabel: '1 token',
        tokenCount: 1,
        onError: (error, _) => observed.complete(error),
      );
      await service.finish(title: 'Complete', detail: 'Ready', success: true);

      expect(await observed.future, isA<PlatformException>());
      expect(calls.map((call) => call.method), ['start', 'update', 'finish']);
    },
  );

  test('production update start interval is 500ms', () {
    expect(
      IosBackgroundGenerationService.updateMinimumInterval,
      const Duration(milliseconds: 500),
    );
  });

  test('native update start times honor the production interval', () async {
    final starts = <DateTime>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'start') return true;
          if (call.method == 'update') starts.add(DateTime.now());
          return true;
        });
    final service = IosBackgroundGenerationService.instance
      ..debugForceIosForTest = true;
    await service.start(
      enabled: true,
      liveActivityEnabled: true,
      notificationsEnabled: false,
      refreshEnabled: true,
      title: 'Generating',
      detail: 'Assistant is replying',
      tokenLabel: '0 tokens',
    );

    service.scheduleUpdate(
      detail: 'Streaming',
      tokenLabel: '1 token',
      tokenCount: 1,
    );
    await Future<void>.delayed(Duration.zero);
    service.scheduleUpdate(
      detail: 'Streaming',
      tokenLabel: '2 tokens',
      tokenCount: 2,
    );
    await service.flushUpdates();

    expect(starts, hasLength(2));
    expect(
      starts.last.difference(starts.first),
      greaterThanOrEqualTo(
        IosBackgroundGenerationService.updateMinimumInterval,
      ),
    );
  });

  test('cancel clears an active native session', () async {
    final service = IosBackgroundGenerationService.instance
      ..debugForceIosForTest = true;

    await service.start(
      enabled: true,
      liveActivityEnabled: true,
      notificationsEnabled: false,
      refreshEnabled: true,
      title: 'Generating',
      detail: 'Assistant is replying',
      tokenLabel: '0 tokens',
    );
    await service.cancel(detail: 'Stopped');
    await service.finish(
      title: 'Complete',
      detail: 'Assistant reply is ready',
      success: true,
    );

    expect(calls.map((call) => call.method), <String>['start', 'cancel']);
  });

  test('cancel barrier prevents a late update after terminal call', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'start') return true;
          if (call.method == 'update' && !firstStarted.isCompleted) {
            firstStarted.complete();
            await releaseFirst.future;
          }
          return true;
        });
    final service = IosBackgroundGenerationService.instance
      ..debugForceIosForTest = true
      ..updateMinimumIntervalForTest = Duration.zero;
    await service.start(
      enabled: true,
      liveActivityEnabled: true,
      notificationsEnabled: false,
      refreshEnabled: true,
      title: 'Generating',
      detail: 'Assistant is replying',
      tokenLabel: '0 tokens',
    );
    calls.clear();
    service.scheduleUpdate(
      detail: 'Streaming',
      tokenLabel: '1 token',
      tokenCount: 1,
    );
    await firstStarted.future;
    service.scheduleUpdate(
      detail: 'Streaming',
      tokenLabel: '2 tokens',
      tokenCount: 2,
    );

    final cancelFuture = service.cancel(detail: 'Stopped');
    releaseFirst.complete();
    await cancelFuture;
    await Future<void>.delayed(Duration.zero);

    expect(calls.map((call) => call.method), ['update', 'update', 'cancel']);
  });

  test('reports native status maps with safe defaults', () async {
    final service = IosBackgroundGenerationService.instance
      ..debugForceIosForTest = true;

    final status = await service.getStatus();

    expect(status.backgroundTaskActive, isFalse);
    expect(status.liveActivityActive, isFalse);
    expect(status.notificationsAuthorized, isTrue);
    expect(status.liveActivitiesEnabled, isTrue);
  });

  test(
    'requests notification authorization and opens settings on iOS',
    () async {
      final service = IosBackgroundGenerationService.instance
        ..debugForceIosForTest = true;

      final granted = await service.requestNotificationAuthorization();
      final openedAppSettings = await service.openAppSettings();
      final openedNotificationSettings = await service
          .openNotificationSettings();

      expect(granted, isTrue);
      expect(openedAppSettings, isTrue);
      expect(openedNotificationSettings, isTrue);
      expect(calls.map((call) => call.method), <String>[
        'requestNotificationAuthorization',
        'openAppSettings',
        'openNotificationSettings',
      ]);
    },
  );
}
