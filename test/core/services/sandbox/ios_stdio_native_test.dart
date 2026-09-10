import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'iOS stdin preserves early input and survives child exit',
    () async {
      final temp = await Directory.systemTemp.createTemp('kelivo_ios_stdio_');
      addTearDown(() => temp.delete(recursive: true));
      final binary = '${temp.path}/stdio_test';
      final compile = await Process.run('xcrun', [
        '--sdk',
        'macosx',
        'clang',
        '-Wall',
        '-Wextra',
        '-Werror',
        '-Iios/Runner/Workspace',
        'test/native/ios_stdio_test.c',
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
    skip: !Platform.isMacOS,
  );
}
