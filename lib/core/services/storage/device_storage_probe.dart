import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How much room is left on the volume holding the app's data.
///
/// Answers null wherever the platform does not tell us, and every caller
/// treats null as "proceed": a nearly-full device is worth avoiding, but
/// refusing to ever make a copy because the probe is unavailable would be a
/// worse failure than attempting one that fails cleanly.
final class DeviceStorageProbe {
  const DeviceStorageProbe._();

  static const MethodChannel _channel = MethodChannel('app.device_storage');

  /// Anything outside this range is a misread, not a measurement.
  static const _minimumPlausibleBytes = 0;
  static const _maximumPlausibleBytes = 1 << 50; // 1 PiB

  @visibleForTesting
  static Future<int?> Function()? debugOverride;

  /// Keeps [path] out of the platform's cloud backup.
  ///
  /// On iOS the app's data lives in Documents, which iCloud backs up whole.
  /// Local copies can run to several gigabytes and are reproducible from the
  /// live database, so including them would inflate -- and can outright break
  /// -- a user's iCloud backup for no protection they do not already have.
  /// Android needs nothing here: the manifest disables backup entirely.
  ///
  /// Best effort. A platform that cannot do it simply keeps backing the path
  /// up, which is wasteful but never harmful.
  static Future<void> excludeFromCloudBackup(String path) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _channel.invokeMethod<void>('excludeFromBackup', {'path': path});
    } catch (_) {}
  }

  static Future<int?> freeBytes() async {
    final override = debugOverride;
    if (override != null) return override();
    if (kIsWeb) return null;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      final value = await _channel.invokeMethod<Object?>('freeBytes');
      if (value is! int) return null;
      if (value <= _minimumPlausibleBytes) return null;
      if (value >= _maximumPlausibleBytes) return null;
      return value;
    } catch (_) {
      return null;
    }
  }
}
