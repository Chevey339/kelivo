import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'iOS native environment encoding keeps large values and rejects overflow',
    () async {
      final temp = await Directory.systemTemp.createTemp('kelivo_ios_env_');
      addTearDown(() => temp.delete(recursive: true));
      final binary = '${temp.path}/environment_test';
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
        'ios/Runner/Workspace/KelivoISHEnvironment.m',
        'test/native/ios_environment_test.m',
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

  for (final shell in ['/bin/bash', '/bin/sh']) {
    test(
      'iOS profile preserves configured variables with $shell',
      () async {
        final temp = await Directory.systemTemp.createTemp(
          'kelivo_ios_profile_',
        );
        addTearDown(() => temp.delete(recursive: true));
        final profiles = await Directory('${temp.path}/profile.d').create();
        await File(
          'ios/sandbox/overlay/etc/profile.d/kelivo.sh',
        ).copy('${profiles.path}/kelivo.sh');
        final profile = File('${temp.path}/profile');
        // Redirect only guest absolute paths into the isolated test root.
        await profile.writeAsString(
          (await File(
            'ios/sandbox/overlay/etc/profile',
          ).readAsString()).replaceAll('/etc/profile.d', profiles.path),
        );
        const command =
            r'. "$1"; printf "%s\n" "$PATH" "$HOME" "$LANG" "$TERM" "$HISTSIZE"';
        final result = await Process.run(
          shell,
          ['-c', command, 'profile-test', profile.path],
          environment: {
            'PATH': '/workspace/.venv/bin:/usr/bin:/bin',
            'HOME': '/workspace/home',
            'LANG': 'C',
            'TERM': 'vt100',
            'HISTSIZE': '2500',
          },
        );
        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(
          result.stdout,
          '/workspace/.venv/bin:/usr/bin:/bin\n/workspace/home\nC\nvt100\n2500\n',
        );
        final defaults = await Process.run(shell, [
          '-c',
          r'unset PATH HOME LANG TERM HISTSIZE; . "$1"; printf "%s\n" "$PATH" "$HOME" "$LANG" "$TERM" "$HISTSIZE"',
          'profile-test',
          profile.path,
        ]);
        expect(defaults.exitCode, 0, reason: '${defaults.stderr}');
        expect(
          defaults.stdout,
          '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n/root\nC.UTF-8\nxterm-256color\n1000\n',
        );
      },
      skip: !(Platform.isMacOS || Platform.isLinux),
    );
  }
}
