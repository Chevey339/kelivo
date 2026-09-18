import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final cli = File('ios/sandbox/build/ish').absolute;
  final archive = File('ios/sandbox/resources/alpine-rootfs.zip').absolute;
  test(
    'bundled iOS rootfs keeps release files and has a consistent apk world',
    () async {
      final root = await Directory.systemTemp.createTemp('kelivo_apk_test_');
      addTearDown(() => root.delete(recursive: true));
      final extract = await Process.run('unzip', [
        '-q',
        archive.path,
        '-d',
        root.path,
      ]);
      expect(extract.exitCode, 0, reason: '${extract.stderr}');

      Future<ProcessResult> run(String command) =>
          Process.run(cli.path, ['-f', root.path, '/bin/sh', '-c', command]);

      // A failed apk transaction must fail the rootfs build as well.
      expect((await run('exit 17')).exitCode, 17);
      final state = await run(r'''
set -eu
apk info --installed alpine-release musl bash coreutils libc-utils
apk info --who-owns /bin/bash /usr/bin/env /lib/ld-musl-aarch64.so.1
/bin/bash --noprofile --norc -c 'test -n "$BASH_VERSION"'
/bin/ls --version
/usr/bin/env --version
grep -qx alpine-release /etc/apk/world
test -s /etc/alpine-release
grep -qx 'ID=alpine' /etc/os-release
grep -qx 'ID=alpine' /usr/lib/os-release
apk --no-network --repositories-file /dev/null add --simulate musl
''');
      expect(state.exitCode, 0, reason: '${state.stdout}\n${state.stderr}');
      expect(state.stdout, isNot(contains('Purging')));
      expect(state.stdout, isNot(contains('Installing')));
      expect(state.stdout, contains('owned by bash-'));
      expect(state.stdout, contains('owned by musl-'));
    },
    skip: !Platform.isMacOS || !cli.existsSync() || !archive.existsSync(),
  );
}
