import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Linux window decorations are a local preference, like window geometry.
class LinuxWindowService {
  static const hideTitleBarKey = 'linux_hide_title_bar_v1';

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  static Future<void> setTitleBarHidden(bool hidden) async {
    if (!isSupported) return;
    await windowManager.setTitleBarStyle(
      hidden ? TitleBarStyle.hidden : TitleBarStyle.normal,
    );
  }
}
