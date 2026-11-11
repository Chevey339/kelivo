import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const build = 'ios/sandbox/ish/build-native';
  final libraries = [
    '$build/libish.a',
    '$build/libish_emu.a',
    '$build/libfakefs.a',
  ];
  test(
    'iOS guest memory admission refreshes expired host data without bypassing pressure',
    () async {
      final temp = await Directory.systemTemp.createTemp('kelivo_ios_memory_');
      addTearDown(() => temp.delete(recursive: true));
      final binary = '${temp.path}/memory_test';
      final compile = await Process.run('xcrun', [
        '--sdk',
        'macosx',
        'clang',
        '-std=gnu11',
        '-DGUEST_ARM64=1',
        '-DENGINE_ASBESTOS=1',
        '-DLOG_HANDLER_DPRINTF=1',
        '-Iios/sandbox/ish',
        'test/native/ios_memory_governor_test.c',
        ...libraries,
        '-lsqlite3',
        '-o',
        binary,
      ]);
      expect(
        compile.exitCode,
        0,
        reason: '${compile.stdout}\n${compile.stderr}',
      );
      final run = await Process.run(binary, const []);
      expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    },
    skip:
        !Platform.isMacOS || libraries.any((path) => !File(path).existsSync()),
  );
}
