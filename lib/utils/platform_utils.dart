import 'dart:io' show Platform, exit;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:restart_app/restart_app.dart';

abstract final class PlatformUtils {
  PlatformUtils._();

  static bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static bool get isDesktopTarget =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  static bool get isMobileTarget =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;


  static bool get isMacOS => Platform.isMacOS;

  static bool get isWindows => Platform.isWindows;

  static bool get isLinux => Platform.isLinux;

  static bool get isAndroid => Platform.isAndroid;

  static bool get isIOS => Platform.isIOS;

  static Future<void> restartApp() async {
    if (Platform.isAndroid) {
      await Restart.restartApp();
    } else {
      exit(0);
    }
  }
}
