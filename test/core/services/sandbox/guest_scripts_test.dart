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
      'if [ -f /etc/apt/sources.list.d/ubuntu.sources ] && [ ! -f /etc/apt/sources.list.d/ubuntu.sources.bak ] && [ ! -f /etc/apt/sources.list.d/ubuntu.sources.kelivo-created ]; then\n'
      '  cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak\n'
      'fi\n'
      'if [ ! -f /etc/apt/sources.list.d/ubuntu.sources ]; then\n'
      '  touch /etc/apt/sources.list.d/ubuntu.sources.kelivo-created\n'
      'fi\n'
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
      'if [ -f /etc/apk/repositories ] && [ ! -f /etc/apk/repositories.bak ] && [ ! -f /etc/apk/repositories.kelivo-created ]; then\n'
      '  cp /etc/apk/repositories /etc/apk/repositories.bak\n'
      'fi\n'
      'if [ ! -f /etc/apk/repositories ]; then\n'
      '  touch /etc/apk/repositories.kelivo-created\n'
      'fi\n'
      "cat > /etc/apk/repositories <<'EOF'\n"
      'https://mirrors.tuna.tsinghua.edu.cn/alpine/latest-stable/main\n'
      'https://mirrors.tuna.tsinghua.edu.cn/alpine/latest-stable/community\n'
      'EOF\n',
    );
    expect(
      GuestScripts.applyPipMirror('https://pypi.tuna.tsinghua.edu.cn/simple'),
      'set -e\n'
      'mkdir -p "\$(dirname /etc/pip.conf)"\n'
      'if [ -f /etc/pip.conf ] && [ ! -f /etc/pip.conf.bak ] && [ ! -f /etc/pip.conf.kelivo-created ]; then\n'
      '  cp /etc/pip.conf /etc/pip.conf.bak\n'
      'fi\n'
      'if [ ! -f /etc/pip.conf ]; then\n'
      '  touch /etc/pip.conf.kelivo-created\n'
      'fi\n'
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
      'if [ -f /root/.npmrc ] && [ ! -f /root/.npmrc.bak ] && [ ! -f /root/.npmrc.kelivo-created ]; then\n'
      '  cp /root/.npmrc /root/.npmrc.bak\n'
      'fi\n'
      'if [ ! -f /root/.npmrc ]; then\n'
      '  touch /root/.npmrc.kelivo-created\n'
      'fi\n'
      "cat > /root/.npmrc <<'EOF'\n"
      'registry=https://registry.npmmirror.com\n'
      'EOF\n',
    );
  });

  test('apply twice preserves the .bak guard', () {
    final script = GuestScripts.applyPipMirror(
      'https://pypi.tuna.tsinghua.edu.cn/simple',
    );
    expect(
      script,
      contains(
        'if [ -f /etc/pip.conf ] && [ ! -f /etc/pip.conf.bak ] && [ ! -f /etc/pip.conf.kelivo-created ]; then',
      ),
    );
    expect(
      script,
      contains(
        'if [ ! -f /etc/pip.conf ]; then\n'
        '  touch /etc/pip.conf.kelivo-created\n',
      ),
    );
  });

  test('restore handles .bak, sentinel, and neither', () {
    expect(
      GuestScripts.restoreAptMirror(),
      'set -e\n'
      'if [ -f /etc/apt/sources.list.d/ubuntu.sources.bak ]; then\n'
      '  cat /etc/apt/sources.list.d/ubuntu.sources.bak > /etc/apt/sources.list.d/ubuntu.sources\n'
      '  rm -f /etc/apt/sources.list.d/ubuntu.sources.bak /etc/apt/sources.list.d/ubuntu.sources.kelivo-created\n'
      'elif [ -f /etc/apt/sources.list.d/ubuntu.sources.kelivo-created ]; then\n'
      '  rm -f /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.kelivo-created\n'
      'else\n'
      "cat > /etc/apt/sources.list.d/ubuntu.sources <<'EOF'\n"
      'Types: deb\n'
      'URIs: http://ports.ubuntu.com/ubuntu-ports/\n'
      'Suites: noble noble-updates noble-security\n'
      'Components: main universe\n'
      'Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n'
      'EOF\n'
      'fi\n',
    );
    expect(
      GuestScripts.restoreApkMirror(),
      contains('/etc/apk/repositories.bak'),
    );
    expect(
      GuestScripts.restoreApkMirror(),
      contains('/etc/apk/repositories.kelivo-created'),
    );
    expect(GuestScripts.restorePipMirror(), contains('/etc/pip.conf.bak'));
    expect(
      GuestScripts.restorePipMirror(),
      contains('/etc/pip.conf.kelivo-created'),
    );
    expect(GuestScripts.restoreNpmMirror(), contains('/root/.npmrc.bak'));
    expect(GuestScripts.restoreNpmMirror(), contains('elif [ -f'));
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

  test('apply twice then restore keeps original content', () async {
    final dir = Directory.systemTemp.createTempSync('kelivo_guest_scripts_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final path = '${dir.path}/pip.conf';
    File(path).writeAsStringSync('original\n');

    final apply = GuestScripts.writeFile(path: path, body: 'mirror\n');
    final restore = GuestScripts.restore(path);

    await _runSh(apply);
    expect(File(path).readAsStringSync(), 'mirror\n');
    expect(File('$path.bak').readAsStringSync(), 'original\n');

    await _runSh(apply);
    expect(File('$path.bak').readAsStringSync(), 'original\n');
    expect(File(path).readAsStringSync(), 'mirror\n');
    expect(File('$path.kelivo-created').existsSync(), isFalse);

    await _runSh(restore);
    expect(File(path).readAsStringSync(), 'original\n');
    expect(File('$path.bak').existsSync(), isFalse);
    expect(File('$path.kelivo-created').existsSync(), isFalse);
  });

  test('apply then restore on a missing file leaves no file', () async {
    final dir = Directory.systemTemp.createTempSync('kelivo_guest_scripts_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final path = '${dir.path}/nested/pip.conf';

    final apply = GuestScripts.writeFile(path: path, body: 'mirror\n');
    final restore = GuestScripts.restore(path);

    await _runSh(apply);
    expect(File(path).readAsStringSync(), 'mirror\n');
    expect(File('$path.kelivo-created').existsSync(), isTrue);
    expect(File('$path.bak').existsSync(), isFalse);

    await _runSh(restore);
    expect(File(path).existsSync(), isFalse);
    expect(File('$path.kelivo-created').existsSync(), isFalse);
    expect(File('$path.bak').existsSync(), isFalse);
  });

  test('restoreApkMirror without bak writes official repositories', () async {
    final dir = Directory.systemTemp.createTempSync('kelivo_guest_scripts_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final path = '${dir.path}/repositories';
    File(
      path,
    ).writeAsStringSync('https://mirrors.aliyun.com/alpine/v3.21/main\n');

    await _runSh(
      GuestScripts.restore(
        path,
        officialBody:
            'https://dl-cdn.alpinelinux.org/alpine/v3.21/main\n'
            'https://dl-cdn.alpinelinux.org/alpine/v3.21/community\n',
      ),
    );
    expect(
      File(path).readAsStringSync(),
      'https://dl-cdn.alpinelinux.org/alpine/v3.21/main\n'
      'https://dl-cdn.alpinelinux.org/alpine/v3.21/community\n',
    );
  });

  test('restore with neither bak nor sentinel is a no-op', () async {
    final dir = Directory.systemTemp.createTempSync('kelivo_guest_scripts_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final path = '${dir.path}/ubuntu.sources';
    File(path).writeAsStringSync('official\n');

    await _runSh(GuestScripts.restore(path));
    expect(File(path).readAsStringSync(), 'official\n');
  });
}

Future<void> _runSh(String script) async {
  final result = await Process.run('/bin/sh', ['-c', script]);
  expect(
    result.exitCode,
    0,
    reason: 'stderr: ${result.stderr}\nstdout: ${result.stdout}',
  );
}
