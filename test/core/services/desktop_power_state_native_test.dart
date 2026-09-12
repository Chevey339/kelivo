import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'macOS system notifications distinguish sleep from window inactivity',
    () async {
      final temp = await Directory.systemTemp.createTemp('kelivo_power_test_');
      addTearDown(() => temp.delete(recursive: true));
      final binary = '${temp.path}/power_test';
      final compile = await Process.run('xcrun', [
        'swiftc',
        'macos/Runner/DesktopSystemPowerState.swift',
        'test/native/desktop_power_state_test.swift',
        '-o',
        binary,
      ]);
      expect(
        compile.exitCode,
        0,
        reason: '${compile.stdout}\n${compile.stderr}',
      );
      final result = await Process.run(binary, const []);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
    skip: !Platform.isMacOS,
  );
}
