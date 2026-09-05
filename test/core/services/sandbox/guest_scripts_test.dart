import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/sandbox/guest_scripts.dart';

void main() {
  test('applyAptMirror golden', () {
    expect(
      GuestScripts.applyAptMirror(
        'https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports',
        'arm64',
      ),
      'set -e\n'
      'mkdir -p "\$(dirname /etc/apt/sources.list.d/ubuntu.sources)"\n'
      "cat > /etc/apt/sources.list.d/ubuntu.sources <<'EOF'\n"
      'Types: deb\n'
      'URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports\n'
      'Suites: noble noble-updates noble-security\n'
      'Components: main universe\n'
      'Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n'
      'EOF\n',
    );
  });

  test('applyApkMirror / applyPipMirror / applyNpmMirror goldens', () {
    expect(
      GuestScripts.applyApkMirror(
        'https://mirrors.tuna.tsinghua.edu.cn/alpine',
        'latest-stable',
      ),
      'set -e\n'
      'mkdir -p "\$(dirname /etc/apk/repositories)"\n'
      "cat > /etc/apk/repositories <<'EOF'\n"
      'https://mirrors.tuna.tsinghua.edu.cn/alpine/latest-stable/main\n'
      'https://mirrors.tuna.tsinghua.edu.cn/alpine/latest-stable/community\n'
      'EOF\n',
    );
    expect(
      GuestScripts.applyPipMirror('https://pypi.tuna.tsinghua.edu.cn/simple'),
      'set -e\n'
      'mkdir -p "\$(dirname /etc/pip.conf)"\n'
      "cat > /etc/pip.conf <<'EOF'\n"
      '[global]\n'
      'index-url = https://pypi.tuna.tsinghua.edu.cn/simple\n'
      'trusted-host = pypi.tuna.tsinghua.edu.cn\n'
      'EOF\n',
    );
    expect(
      GuestScripts.applyNpmMirror('https://registry.npmmirror.com'),
      'set -e\n'
      'mkdir -p "\$(dirname /root/.npmrc)"\n'
      "cat > /root/.npmrc <<'EOF'\n"
      'registry=https://registry.npmmirror.com\n'
      'EOF\n',
    );
  });

  test('rejects command substitution and quotes', () {
    expect(
      () => GuestScripts.applyPipMirror(r'https://evil.example/$(whoami)'),
      throwsArgumentError,
    );
    expect(
      () => GuestScripts.applyNpmMirror("https://evil.example/foo';rm"),
      throwsArgumentError,
    );
    expect(
      () =>
          GuestScripts.applyAptMirror('https://evil.example/"quoted"', 'arm64'),
      throwsArgumentError,
    );
    expect(
      () => GuestScripts.applyApkMirror('ftp://example.com/alpine', 'v3.21'),
      throwsArgumentError,
    );
  });

  test(
    'source replacement writes official content even with an old backup',
    () async {
      final dir = await Directory.systemTemp.createTemp('kelivo_source_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/repositories';
      await File(path).writeAsString('https://old-mirror.test/\n');
      await File('$path.bak').writeAsString('https://another-mirror.test/\n');
      await _runSh(
        GuestScripts.writeFile(path: path, body: 'https://official.test/\n'),
      );
      expect(await File(path).readAsString(), 'https://official.test/\n');
      await _runSh(
        GuestScripts.writeFile(path: path, body: 'https://new-mirror.test/\n'),
      );
      expect(await File(path).readAsString(), 'https://new-mirror.test/\n');
    },
  );
}

Future<void> _runSh(String script) async {
  final result = await Process.run('/bin/sh', ['-c', script]);
  expect(
    result.exitCode,
    0,
    reason: 'stderr: ${result.stderr}\nstdout: ${result.stdout}',
  );
}
