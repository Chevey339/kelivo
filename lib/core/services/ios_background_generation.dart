import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class _IosBackgroundGenerationUpdate {
  const _IosBackgroundGenerationUpdate({
    required this.detail,
    required this.tokenLabel,
    required this.tokenCount,
    this.onError,
  });

  final String detail;
  final String tokenLabel;
  final int? tokenCount;
  final void Function(Object error, StackTrace stackTrace)? onError;
}

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
  bool _nativeGenerationActive = false;
  static const updateMinimumInterval = Duration(milliseconds: 500);
  Duration updateMinimumIntervalForTest = updateMinimumInterval;
  _IosBackgroundGenerationUpdate? _pendingUpdate;
  Future<void>? _updateDrainFuture;
  DateTime? _lastUpdateStartedAt;
  bool _terminalizing = false;

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
    await _resetUpdateQueue();
    if (!_isIos || !enabled) {
      _nativeGenerationActive = false;
      return;
    }
    if (notificationsEnabled) {
      await requestNotificationAuthorization();
    }
    final started = await _channel
        .invokeMethod<bool>('start', <String, Object?>{
          'liveActivityEnabled': liveActivityEnabled,
          'notificationsEnabled': notificationsEnabled,
          'refreshEnabled': refreshEnabled,
          'title': title,
          'detail': detail,
          'tokenCount': tokenCount,
          'tokenLabel': tokenLabel,
        });
    _nativeGenerationActive = started == true;
  }

  void scheduleUpdate({
    required String detail,
    required String tokenLabel,
    int? tokenCount,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    if (!_isIos || !_nativeGenerationActive || _terminalizing) return;
    _pendingUpdate = _IosBackgroundGenerationUpdate(
      detail: detail,
      tokenLabel: tokenLabel,
      tokenCount: tokenCount,
      onError: onError,
    );
    if (_updateDrainFuture != null) return;
    final drain = _drainUpdates();
    _updateDrainFuture = drain;
    unawaited(
      drain.whenComplete(() {
        if (identical(_updateDrainFuture, drain)) {
          _updateDrainFuture = null;
        }
      }),
    );
  }

  Future<void> flushUpdates() async {
    while (true) {
      final drain = _updateDrainFuture;
      if (drain == null) {
        if (_pendingUpdate == null) return;
        final nextDrain = _drainUpdates();
        _updateDrainFuture = nextDrain;
        continue;
      }
      await drain;
      if (identical(_updateDrainFuture, drain)) {
        _updateDrainFuture = null;
      }
      if (_pendingUpdate == null) return;
    }
  }

  Future<void> _drainUpdates() async {
    while (_pendingUpdate != null && _nativeGenerationActive) {
      final lastStartedAt = _lastUpdateStartedAt;
      if (lastStartedAt != null) {
        final remaining =
            updateMinimumIntervalForTest -
            DateTime.now().difference(lastStartedAt);
        if (remaining > Duration.zero) {
          await Future<void>.delayed(remaining);
        }
      }
      final update = _pendingUpdate;
      if (update == null || !_nativeGenerationActive) return;
      _pendingUpdate = null;
      _lastUpdateStartedAt = DateTime.now();
      try {
        await _channel.invokeMethod<bool>('update', <String, Object?>{
          'detail': update.detail,
          'tokenLabel': update.tokenLabel,
          if (update.tokenCount != null) 'tokenCount': update.tokenCount,
        });
      } catch (error, stackTrace) {
        final onError = update.onError;
        if (onError != null) {
          onError(error, stackTrace);
        } else {
          debugPrint('[IosBackgroundGeneration] update failed: $error');
          debugPrint('$stackTrace');
        }
      }
    }
  }

  Future<void> finish({
    required String title,
    required String detail,
    required bool success,
  }) async {
    if (!_isIos || !_nativeGenerationActive) return;
    _terminalizing = true;
    try {
      await flushUpdates();
      await _channel.invokeMethod<bool>('finish', <String, Object?>{
        'title': title,
        'detail': detail,
        'success': success,
      });
    } finally {
      _nativeGenerationActive = false;
      _clearUpdateQueue();
    }
  }

  Future<void> cancel({String? detail}) async {
    if (!_isIos || !_nativeGenerationActive) return;
    _terminalizing = true;
    try {
      await flushUpdates();
      await _channel.invokeMethod<bool>('cancel', <String, Object?>{
        if (detail != null) 'detail': detail,
      });
    } finally {
      _nativeGenerationActive = false;
      _clearUpdateQueue();
    }
  }

  Future<void> _resetUpdateQueue() async {
    _terminalizing = true;
    _pendingUpdate = null;
    await _updateDrainFuture;
    _clearUpdateQueue();
  }

  void _clearUpdateQueue() {
    _pendingUpdate = null;
    _updateDrainFuture = null;
    _lastUpdateStartedAt = null;
    _terminalizing = false;
  }

  Future<void> resetForTest() async {
    await _resetUpdateQueue();
    debugForceIosForTest = false;
    _nativeGenerationActive = false;
    updateMinimumIntervalForTest = updateMinimumInterval;
  }
}
