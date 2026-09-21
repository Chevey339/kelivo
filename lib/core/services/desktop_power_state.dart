import 'package:flutter/services.dart';

/// A snapshot maintained by the native system sleep/wake observers.
/// Window focus, App Nap and Dart timer lateness do not change this state.
class DesktopPowerState {
  const DesktopPowerState({this.sleeping = false, this.lastWakeAt});

  final bool sleeping;
  final DateTime? lastWakeAt;

  static const channel = MethodChannel('app.desktop_power');

  static Future<DesktopPowerState> read() async {
    final value = (await channel.invokeMapMethod<String, Object?>('state'))!;
    final wake = value['lastWakeAt'] as int;
    return DesktopPowerState(
      sleeping: value['sleeping'] as bool,
      lastWakeAt: wake == 0 ? null : DateTime.fromMillisecondsSinceEpoch(wake),
    );
  }
}
