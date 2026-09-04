import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/workspace/terminal/osc_1337.dart';
import 'package:Kelivo/features/workspace/terminal/terminal_session_manager.dart';
import 'package:Kelivo/theme/theme_factory.dart';

import 'fake_workspace_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  TerminalSessionManager managerWithLock(void Function(bool) onLock) {
    return TerminalSessionManager(
      setWakelock: (enable) async => onLock(enable),
    );
  }

  test('pipes PTY output into the terminal buffer', () async {
    final runtime = FakeWorkspaceRuntime();
    final manager = managerWithLock((_) {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });
    final session = await manager.open(
      runtime: runtime,
      mounts: const [],
      cwd: '/workspace',
    );
    runtime.lastPty!.emitString('hello from pty');
    await flush();
    expect(session.terminal.buffer.getText(), contains('hello from pty'));
  });

  test('forwards typed input bytes to the PTY', () async {
    final runtime = FakeWorkspaceRuntime();
    final manager = managerWithLock((_) {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });
    final session = await manager.open(
      runtime: runtime,
      mounts: const [],
      cwd: '/workspace',
    );
    session.terminal.textInput('abc');
    await flush();
    expect(runtime.lastPty!.writtenString, 'abc');
  });

  test('forwards resize to the PTY', () async {
    final runtime = FakeWorkspaceRuntime();
    final manager = managerWithLock((_) {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });
    final session = await manager.open(
      runtime: runtime,
      mounts: const [],
      cwd: '/workspace',
    );
    session.terminal.resize(40, 12);
    await flush();
    expect(runtime.lastPty!.resizes, contains((40, 12)));
  });

  test('marks the session exited and prints a dim exit line', () async {
    final runtime = FakeWorkspaceRuntime();
    final manager = managerWithLock((_) {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });
    final session = await manager.open(
      runtime: runtime,
      mounts: const [],
      cwd: '/workspace',
    );
    expect(session.isAlive, isTrue);
    runtime.lastPty!.completeExit(7);
    await flush();
    expect(session.exited, isTrue);
    expect(session.isAlive, isFalse);
    expect(session.exitCode, 7);
    expect(session.terminal.buffer.getText(), contains('[process exited 7]'));
  });

  test('intercepts OSC 1337 KelivoOpenURL and does not render it', () async {
    final runtime = FakeWorkspaceRuntime();
    final manager = managerWithLock((_) {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });
    final session = await manager.open(
      runtime: runtime,
      mounts: const [],
      cwd: '/workspace',
    );
    final urls = <Uri>[];
    session.openUrlRequests.listen(urls.add);

    runtime.lastPty!.emitString(
      'hello\x1b]1337;KelivoOpenURL=https://example.com/path\x07world',
    );
    await flush();

    final text = session.terminal.buffer.getText();
    expect(text, contains('hello'));
    expect(text, contains('world'));
    expect(text, isNot(contains('KelivoOpenURL')));
    expect(text, isNot(contains('example.com')));
    expect(urls, [Uri.parse('https://example.com/path')]);
  });

  test('intercepts OSC 1337 terminated with ST across chunks', () async {
    final runtime = FakeWorkspaceRuntime();
    final manager = managerWithLock((_) {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });
    final session = await manager.open(
      runtime: runtime,
      mounts: const [],
      cwd: '/workspace',
    );
    final urls = <Uri>[];
    session.openUrlRequests.listen(urls.add);

    runtime.lastPty!.emit(
      utf8.encode('\x1b]1337;KelivoOpenURL=kelivo://workspace/a.txt'),
    );
    runtime.lastPty!.emit(utf8.encode('\x1b\\visible'));
    await flush();

    final text = session.terminal.buffer.getText();
    expect(text, contains('visible'));
    expect(text, isNot(contains('KelivoOpenURL')));
    expect(urls, [Uri.parse('kelivo://workspace/a.txt')]);
  });

  test('writes initialCommand without a trailing newline', () async {
    final runtime = FakeWorkspaceRuntime();
    final manager = managerWithLock((_) {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });
    await manager.open(
      runtime: runtime,
      mounts: const [],
      cwd: '/workspace',
      initialCommand: 'ls -la',
    );
    await flush();
    expect(runtime.lastPty!.writtenString, 'ls -la');
    expect(runtime.lastPty!.writtenString.contains('\n'), isFalse);
    expect(runtime.lastPty!.writtenString.contains('\r'), isFalse);
  });

  test('toggles wakelock via the injected callback', () async {
    final locks = <bool>[];
    final runtime = FakeWorkspaceRuntime();
    final manager = managerWithLock(locks.add);
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });

    expect(locks, isEmpty);
    final first = await manager.open(
      runtime: runtime,
      mounts: const [],
      cwd: '/workspace',
    );
    expect(locks, [true]);

    await manager.open(runtime: runtime, mounts: const [], cwd: '/workspace');
    expect(locks, [true]);

    await manager.close(first.id);
    expect(locks, [true]);
    expect(manager.sessions, hasLength(1));

    await manager.closeAll();
    expect(locks, [true, false]);
    expect(manager.sessions, isEmpty);
  });

  test('Osc1337Interceptor holds incomplete sequences', () {
    final urls = <Uri>[];
    final interceptor = Osc1337Interceptor(onUrl: urls.add);
    final first = interceptor.process(
      utf8.encode('pre\x1b]1337;KelivoOpenURL=https://x'),
    );
    expect(utf8.decode(first), 'pre');
    expect(urls, isEmpty);
    final second = interceptor.process(utf8.encode('.y\x07post'));
    expect(utf8.decode(second), 'post');
    expect(urls, [Uri.parse('https://x.y')]);
  });

  test('decodes multi-byte UTF-8 split across PTY chunks', () async {
    final runtime = FakeWorkspaceRuntime();
    final manager = managerWithLock((_) {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });
    final session = await manager.open(
      runtime: runtime,
      mounts: const [],
      cwd: '/workspace',
    );
    // '中文' is e4 b8 ad e6 96 87 — split so no chunk is valid UTF-8 alone.
    runtime.lastPty!.emit([0xe4, 0xb8]);
    runtime.lastPty!.emit([0xad, 0xe6, 0x96]);
    runtime.lastPty!.emit([0x87]);
    await flush();
    final text = session.terminal.buffer.getText();
    expect(text, contains('中文'));
    expect(text, isNot(contains('\uFFFD')));
  });

  test('Osc1337Interceptor emits unterminated OSC once over the hold cap', () {
    final interceptor = Osc1337Interceptor(onUrl: (_) {});
    final out = <int>[];
    out.addAll(interceptor.process(utf8.encode('\x1b]')));
    const payload = 5000;
    var remaining = payload;
    while (remaining > 0) {
      final n = remaining > 1500 ? 1500 : remaining;
      out.addAll(interceptor.process(utf8.encode('A' * n)));
      remaining -= n;
    }
    expect(out.length, 2 + payload);
    final follow = interceptor.process(utf8.encode('z'));
    expect(utf8.decode(follow), 'z');
  });

  test(
    'Osc1337Interceptor still intercepts KelivoOpenURL after OSC give-up',
    () {
      final urls = <Uri>[];
      final interceptor = Osc1337Interceptor(onUrl: urls.add);
      interceptor.process(utf8.encode('\x1b]'));
      interceptor.process(utf8.encode('A' * 2500));
      interceptor.process(utf8.encode('A' * 2500));
      final filtered = interceptor.process(
        utf8.encode('\x1b]1337;KelivoOpenURL=kelivo://workspace/a.txt\x07'),
      );
      expect(utf8.decode(filtered), isNot(contains('KelivoOpenURL')));
      expect(urls, [Uri.parse('kelivo://workspace/a.txt')]);
    },
  );

  test('light terminal theme uses dark ink on a light surface', () {
    final light = buildLightTheme(null).colorScheme;
    final theme = buildTerminalViewTheme(light);
    expect(theme.foreground.computeLuminance(), lessThan(0.3));
    expect(
      theme.background.computeLuminance(),
      greaterThan(theme.foreground.computeLuminance()),
    );
    expect(
      theme.yellow.computeLuminance(),
      lessThan(const Color(0xFFE5E510).computeLuminance()),
    );
    expect(
      theme.cyan.computeLuminance(),
      lessThan(const Color(0xFF11A8CD).computeLuminance()),
    );
  });

  test('dark terminal theme keeps a light stock foreground', () {
    final dark = buildDarkTheme(null).colorScheme;
    final theme = buildTerminalViewTheme(dark);
    expect(theme.foreground.computeLuminance(), greaterThan(0.5));
  });

  test('uniqueTerminalSessionTitle reuses the lowest free number', () {
    expect(
      uniqueTerminalSessionTitle(requested: 'demo', existing: const []),
      'demo',
    );
    expect(
      uniqueTerminalSessionTitle(requested: 'demo', existing: const ['demo']),
      'demo 2',
    );
    expect(
      uniqueTerminalSessionTitle(
        requested: 'demo',
        existing: const ['demo', 'demo 3'],
      ),
      'demo 2',
    );
    expect(
      uniqueTerminalSessionTitle(
        requested: 'demo',
        existing: const ['custom', 'demo 2'],
      ),
      'demo',
    );
  });

  test(
    'open assigns unique default titles; rename keeps a custom name',
    () async {
      final runtime = FakeWorkspaceRuntime();
      final manager = managerWithLock((_) {});
      addTearDown(() async {
        await manager.closeAll();
        manager.dispose();
      });

      final first = await manager.open(
        runtime: runtime,
        mounts: const [],
        cwd: '/workspace',
        title: 'demo',
      );
      final second = await manager.open(
        runtime: runtime,
        mounts: const [],
        cwd: '/workspace',
        title: 'demo',
      );
      final third = await manager.open(
        runtime: runtime,
        mounts: const [],
        cwd: '/workspace',
        title: 'demo',
      );
      expect(first.title, 'demo');
      expect(second.title, 'demo 2');
      expect(third.title, 'demo 3');

      await manager.close(second.id);
      final reused = await manager.open(
        runtime: runtime,
        mounts: const [],
        cwd: '/workspace',
        title: 'demo',
      );
      expect(reused.title, 'demo 2');

      manager.rename(first.id, 'custom');
      expect(first.title, 'custom');
      final afterRename = await manager.open(
        runtime: runtime,
        mounts: const [],
        cwd: '/workspace',
        title: 'demo',
      );
      expect(afterRename.title, 'demo');
      expect(first.title, 'custom');
    },
  );

  test('Osc1337Interceptor holds trailing ESC across chunks', () {
    final urls = <Uri>[];
    final interceptor = Osc1337Interceptor(onUrl: urls.add);
    final first = interceptor.process(utf8.encode('pre\x1b'));
    expect(utf8.decode(first), 'pre');
    expect(urls, isEmpty);
    final second = interceptor.process(
      utf8.encode(']1337;KelivoOpenURL=kelivo://workspace/a.txt\x07post'),
    );
    expect(utf8.decode(second), 'post');
    expect(urls, [Uri.parse('kelivo://workspace/a.txt')]);
  });
}
