import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'linux_autostart.dart';

/// OS registration is authoritative; only the hidden-start preference is stored.
class DesktopStartupService {
  static const hiddenKey = 'desktop_autostart_hidden_v1';
  static const argument = '--autostart';
  static const _channel = MethodChannel('app.desktop_startup');
  static bool _pendingLaunch = false;

  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  static bool get deferWindow => _pendingLaunch;

  static Future<void> prepareLaunch(List<String> arguments) async {
    if (!isDesktop) return;
    _pendingLaunch = arguments.contains(argument);
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      try {
        _pendingLaunch =
            await _channel.invokeMethod<bool>('wasLaunchedAtLogin') ?? false;
      } catch (_) {
        _pendingLaunch = false;
      }
    }
  }

  /// Recovery screens and explicit window opening must remain visible.
  static void cancelDeferredLaunch() => _pendingLaunch = false;

  static bool finishLaunch({
    required bool hideToTray,
    required bool trayReady,
  }) {
    final show = _pendingLaunch && !(hideToTray && trayReady);
    _pendingLaunch = false;
    return show;
  }

  static LinuxAutostart _linux() {
    final environment = Platform.environment;
    final config = environment['XDG_CONFIG_HOME'];
    final home = environment['HOME'];
    if ((config == null || !p.isAbsolute(config)) && home == null) {
      throw StateError('No user configuration directory');
    }
    return LinuxAutostart(
      configDirectory: config != null && p.isAbsolute(config)
          ? config
          : p.join(home!, '.config'),
      executable: environment['APPIMAGE'] ?? Platform.resolvedExecutable,
    );
  }

  static Future<({bool supported, bool enabled})> readState() async {
    if (!isDesktop) return (supported: false, enabled: false);
    if (defaultTargetPlatform == TargetPlatform.linux) {
      return (supported: true, enabled: await _linux().isEnabled());
    }
    final state = await _channel.invokeMapMethod<String, dynamic>('getState');
    return (
      supported: state?['supported'] == true,
      enabled: state?['enabled'] == true,
    );
  }

  static Future<void> setEnabled(bool enabled) async {
    if (defaultTargetPlatform == TargetPlatform.linux) {
      await _linux().setEnabled(enabled);
    } else {
      await _channel.invokeMethod<void>('setEnabled', enabled);
    }
  }

  static Future<bool> hasTrayHost() async {
    if (defaultTargetPlatform != TargetPlatform.linux) return true;
    try {
      return await _channel.invokeMethod<bool>('hasTrayHost') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> readHidden() async =>
      (await SharedPreferences.getInstance()).getBool(hiddenKey) ?? false;

  static Future<void> setHidden(bool hidden) async {
    if (!await (await SharedPreferences.getInstance()).setBool(
      hiddenKey,
      hidden,
    )) {
      throw StateError('Could not save startup preference');
    }
  }
}
