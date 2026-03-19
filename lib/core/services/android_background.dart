import 'dart:io' show Platform;
import 'package:flutter_background/flutter_background.dart';

/// Simple manager for enabling/disabling background execution on Android.
/// All calls are no-ops on non-Android platforms.
class AndroidBackgroundManager {
  static bool _initialized = false;

  /// Initialize the plugin once and request needed permissions.
  static Future<bool> ensureInitialized({
    String? notificationTitle,
    String? notificationText,
  }) async {
    if (!Platform.isAndroid) return false;
    if (_initialized) return true;
    try {
      final androidConfig = FlutterBackgroundAndroidConfig(
        notificationTitle: notificationTitle ?? 'Kelivo is running',
        notificationText:
            notificationText ?? 'Keeping chat generation alive in background',
        notificationImportance: AndroidNotificationImportance.normal,
        // Explicitly use app launcher icon from mipmap to avoid resource resolution issues
        notificationIcon: const AndroidResource(
          name: 'ic_launcher',
          defType: 'mipmap',
        ),
      );
      final ok = await FlutterBackground.initialize(
        androidConfig: androidConfig,
      );
      _initialized = ok;
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Enable/disable background execution. Requires [ensureInitialized] to have run.
  static Future<void> setEnabled(bool enable) async {
    if (!Platform.isAndroid) return;
    try {
      // Short-circuit if state already matches
      try {
        final current = FlutterBackground.isBackgroundExecutionEnabled;
        if (current == enable) return;
      } catch (_) {}

      if (enable) {
        if (!_initialized) {
          // Initialize only when enabling, since this may trigger permission dialogs
          await ensureInitialized();
        }
        await FlutterBackground.enableBackgroundExecution();
      } else {
        // Try to disable without forcing initialization to avoid permission prompts
        try {
          await FlutterBackground.disableBackgroundExecution();
        } catch (_) {}
      }
    } catch (_) {
      // ignore runtime errors; best effort only
    }
  }

  /// Convenience to query whether background execution is currently enabled.
  static Future<bool> isEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      return FlutterBackground.isBackgroundExecutionEnabled;
    } catch (_) {
      return false;
    }
  }
}
