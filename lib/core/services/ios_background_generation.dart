import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class IosBackgroundGenerationStatus {
  const IosBackgroundGenerationStatus({
    required this.backgroundTaskActive,
    required this.liveActivityActive,
    required this.notificationsAuthorized,
    required this.liveActivitiesEnabled,
  });

  factory IosBackgroundGenerationStatus.fromMap(Map<dynamic, dynamic>? map) {
    bool readBool(String key) => map?[key] == true;
    return IosBackgroundGenerationStatus(
      backgroundTaskActive: readBool('backgroundTaskActive'),
      liveActivityActive: readBool('liveActivityActive'),
      notificationsAuthorized: readBool('notificationsAuthorized'),
      liveActivitiesEnabled: readBool('liveActivitiesEnabled'),
    );
  }

  final bool backgroundTaskActive;
  final bool liveActivityActive;
  final bool notificationsAuthorized;
  final bool liveActivitiesEnabled;
}

class IosBackgroundGenerationService {
  IosBackgroundGenerationService._();

  static final IosBackgroundGenerationService instance =
      IosBackgroundGenerationService._();

  static const MethodChannel _channel = MethodChannel(
    'app.ios_background_generation',
  );

  bool debugForceIosForTest = false;

  bool get _isIos => debugForceIosForTest || Platform.isIOS;

  Future<IosBackgroundGenerationStatus> getStatus() async {
    if (!_isIos) {
      return const IosBackgroundGenerationStatus(
        backgroundTaskActive: false,
        liveActivityActive: false,
        notificationsAuthorized: false,
        liveActivitiesEnabled: false,
      );
    }
    final result = await _channel.invokeMethod<dynamic>('getStatus');
    return IosBackgroundGenerationStatus.fromMap(
      result as Map<dynamic, dynamic>?,
    );
  }

  Future<bool> requestNotificationAuthorization() async {
    if (!_isIos) return false;
    return await _channel.invokeMethod<bool>(
          'requestNotificationAuthorization',
        ) ??
        false;
  }

  Future<bool> openAppSettings() async {
    if (!_isIos) return false;
    return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
  }

  Future<bool> openNotificationSettings() async {
    if (!_isIos) return false;
    return await _channel.invokeMethod<bool>('openNotificationSettings') ??
        false;
  }

  Future<void> start({
    required bool enabled,
    required bool liveActivityEnabled,
    required bool notificationsEnabled,
    required bool refreshEnabled,
    required String title,
    required String detail,
    required String tokenLabel,
    int tokenCount = 0,
  }) async {
    if (!_isIos || !enabled) return;
    if (notificationsEnabled) {
      await requestNotificationAuthorization();
    }
    await _channel.invokeMethod<bool>('start', <String, Object?>{
      'liveActivityEnabled': liveActivityEnabled,
      'notificationsEnabled': notificationsEnabled,
      'refreshEnabled': refreshEnabled,
      'title': title,
      'detail': detail,
      'tokenCount': tokenCount,
      'tokenLabel': tokenLabel,
    });
  }

  Future<void> update({
    required String detail,
    required String tokenLabel,
    int? tokenCount,
  }) async {
    if (!_isIos) return;
    await _channel.invokeMethod<bool>('update', <String, Object?>{
      'detail': detail,
      'tokenLabel': tokenLabel,
      if (tokenCount != null) 'tokenCount': tokenCount,
    });
  }

  Future<void> finish({
    required String title,
    required String detail,
    required bool success,
  }) async {
    if (!_isIos) return;
    await _channel.invokeMethod<bool>('finish', <String, Object?>{
      'title': title,
      'detail': detail,
      'success': success,
    });
  }

  Future<void> cancel({String? detail}) async {
    if (!_isIos) return;
    await _channel.invokeMethod<bool>('cancel', <String, Object?>{
      if (detail != null) 'detail': detail,
    });
  }

  void resetForTest() {
    debugForceIosForTest = false;
  }
}
