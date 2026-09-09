import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'iOS command and terminal contexts keep independent paths',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'kelivo_ios_filesystem_',
      );
      addTearDown(() => temp.delete(recursive: true));
      final binary = '${temp.path}/filesystem_test';
      final compile = await Process.run('xcrun', [
        '--sdk',
        'macosx',
        'clang',
        '-fobjc-arc',
        '-Wall',
        '-Wextra',
        '-Werror',
        '-framework',
        'Foundation',
        '-Iios/Runner/Workspace',
        'ios/Runner/Workspace/KelivoISHFilesystem.m',
        'test/native/ios_filesystem_test.m',
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
