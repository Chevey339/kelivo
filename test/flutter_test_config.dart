import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Settings widgets query Linux startup registration while their fake clock
  // is active. Do not read the host's login item (or wait on real file IO).
  // LinuxAutostart's backend tests use temporary directories and retain real IO.
  IOOverrides.global = _HostAutostartOverrides();
  setUp(() {
    // Native login-item replies must also be hermetic inside the widget clock.
    // Backend tests can replace this default handler in their own setUp/body.
    TestDefaultBinaryMessenger messenger;
    try {
      messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    } on FlutterError {
      // Pure Dart tests must not initialize a Flutter binding merely for this
      // fixture, since doing so would also replace their real HTTP transport.
      return;
    }
    const channel = MethodChannel('app.desktop_startup');
    var enabled = false;
    Future<Object?> handler(MethodCall call) async {
      switch (call.method) {
        case 'getState':
          return {'supported': true, 'enabled': enabled};
        case 'setEnabled':
          enabled = call.arguments as bool;
          return null;
        case 'wasLaunchedAtLogin':
          return false;
        case 'hasTrayHost':
          return true;
        default:
          throw UnsupportedError(call.method);
      }
    }

    messenger.setMockMethodCallHandler(channel, handler);
    addTearDown(() {
      if (messenger.checkMockMessageHandler(channel.name, handler)) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
  });
  await testMain();
}

final class _HostAutostartOverrides extends IOOverrides {
  final String? _hostEntryPath = _resolveHostEntryPath();

  static String? _resolveHostEntryPath() {
    final configRoot = Platform.environment['XDG_CONFIG_HOME'];
    final userHome = Platform.environment['HOME'];
    final directory = configRoot != null && p.isAbsolute(configRoot)
        ? configRoot
        : userHome == null
        ? null
        : p.join(userHome, '.config');
    return directory == null
        ? null
        : p.normalize(p.join(directory, 'autostart', 'kelivo.desktop'));
  }

  @override
  File createFile(String path) => p.normalize(path) == _hostEntryPath
      ? _AbsentHostAutostartFile()
      : super.createFile(path);
}

final class _AbsentHostAutostartFile extends Fake implements File {
  @override
  Future<bool> exists() async => false;

  @override
  bool existsSync() => false;
}
