import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/core/services/ios_background_generation.dart';

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

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    IosBackgroundGenerationService.instance.resetForTest();
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
    await service.update(detail: 'Streaming', tokenLabel: '12 tokens');
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
    await service.update(
      detail: 'Streaming',
      tokenLabel: '12 tokens',
      tokenCount: 12,
    );
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
