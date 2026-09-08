import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';
import 'package:Kelivo/core/services/sandbox/ios_ish_runtime.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/host_file_tools.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isIOS) {
    test('iOS iSH workspace tests require iOS', () {}, skip: true);
    return;
  }

  late WorkspaceChannel channel;
  late IosIshRuntime runtime;
  late EnvironmentProvider env;
  late IosRootfsManager manager;
  late Directory workspaceHost;
  late Directory sessionHost;
  late Directory skillsHost;
  late List<Mount> mounts;
  var seq = 0;

  void iosTest(String name, WidgetTesterCallback body) {
    testWidgets(name, body, timeout: const Timeout(Duration(minutes: 15)));
  }

  setUpAll(() async {
    channel = WorkspaceChannel();
    runtime = IosIshRuntime(channel: channel);
    env = EnvironmentProvider(
      preferences: BusinessPreferences(
        BusinessRepository(AppDatabase(NativeDatabase.memory())),
      ),
    );
    await env.loaded;
    manager = IosRootfsManager(channel: channel, env: env);

    final tmp = await Directory.systemTemp.createTemp('kelivo_ios_ish_');
    workspaceHost = Directory(p.join(tmp.path, 'workspace'))..createSync();
    sessionHost = Directory(p.join(tmp.path, 'session'))..createSync();
    skillsHost = Directory(p.join(tmp.path, 'skills'))..createSync();
    mounts = WorkspacePaths.sandboxed(
      workspaceHostRoot: workspaceHost.path,
      sessionHostDir: sessionHost.path,
      skillsHostDir: skillsHost.path,
    ).mounts;
  });

  Future<_Run> runCmd(
    String command, {
    String cwd = WorkspacePaths.guestWorkspace,
    Duration timeout = const Duration(seconds: 60),
    List<Mount>? extraMounts,
  }) async {
    final runId = 'ios-ish-${++seq}';
    final stdout = StringBuffer();
    final stderr = StringBuffer();
    CommandExited? exit;
    await for (final event in runtime.run(
      CommandRequest(
        runId: runId,
        command: command,
        cwd: cwd,
        timeout: timeout,
        mounts: extraMounts ?? mounts,
      ),
    )) {
      switch (event) {
        case CommandOutput(:final kind, :final bytes):
          final text = utf8.decode(bytes, allowMalformed: true);
          if (kind == OutputStreamKind.stdout) {
            stdout.write(text);
          } else {
            stderr.write(text);
          }
        case CommandExited():
          exit = event;
        case CommandStarted():
          break;
      }
    }
    if (exit == null) {
      fail('command "$command" ended without an exit event');
    }
    return _Run(
      runId: runId,
      stdout: stdout.toString(),
      stderr: stderr.toString(),
      exit: exit,
    );
  }

  Future<Directory> installedRootfsDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'environment', 'alpine-rootfs'));
  }

  group('iOS iSH workspace', () {
    iosTest('cold boot restores external mounts before commands', (
      tester,
    ) async {
      final probe = await channel.probe();
      expect(
        probe.booted,
        isFalse,
        reason: 'Run this test in a fresh app process',
      );
      if (probe.installed != true) await manager.install();
      final external = await Directory.systemTemp.createTemp(
        'kelivo-cold-mount-',
      );
      await File(
        p.join(external.path, 'identity'),
      ).writeAsString('cold-mounted');
      final binds = [
        BindMount(
          host: external.path,
          guest: '/mounts/cold-start-test',
          readOnly: true,
        ),
      ];
      try {
        await channel.setExternalMounts(binds);
        await channel.setExternalMounts(binds);
        // Exercise both boot entry points in separate fresh app runs.
        if (!const bool.fromEnvironment('KELIVO_TEST_IMPLICIT_BOOT')) {
          await channel.boot();
        }
        final first = await runCmd('cat /mounts/cold-start-test/identity');
        expect(first.exit.exitCode, 0, reason: first.stderr);
        expect(first.stdout, 'cold-mounted');
        await channel.setExternalMounts(binds);
        final denied = await runCmd(
          'printf changed > /mounts/cold-start-test/identity',
        );
        expect(denied.exit.exitCode, isNot(0));
        expect(
          await File(p.join(external.path, 'identity')).readAsString(),
          'cold-mounted',
        );
      } finally {
        await channel.setExternalMounts([]);
        await external.delete(recursive: true);
      }
    });

    iosTest('independent command and PTY roots with shared tmp file tools', (
      tester,
    ) async {
      if ((await channel.probe()).installed != true) await manager.install();
      await channel.boot();
      final secondRoot = await Directory.systemTemp.createTemp(
        'kelivo_ish_second_',
      );
      final secondWorkspace = await Directory(
        p.join(secondRoot.path, 'workspace'),
      ).create();
      final secondChat = await Directory(
        p.join(secondRoot.path, 'chat'),
      ).create();
      final secondPaths = WorkspacePaths.sandboxed(
        workspaceHostRoot: secondWorkspace.path,
        sessionHostDir: secondChat.path,
        skillsHostDir: skillsHost.path,
      );
      await File(
        p.join(workspaceHost.path, 'identity'),
      ).writeAsString('workspace-a');
      await File(
        p.join(secondWorkspace.path, 'identity'),
      ).writeAsString('workspace-b');
      final firstReady = Completer<void>();
      // A real child process inherits A's context while B starts independently.
      final first = runtime
          .run(
            CommandRequest(
              runId: 'isolated-a',
              command:
                  "echo READY; (sleep 2; cat /workspace/identity > /chat/child.txt); pwd; cat identity",
              cwd: '/workspace',
              mounts: mounts,
            ),
          )
          .map((event) {
            if (event is CommandOutput &&
                utf8.decode(event.bytes).contains('READY') &&
                !firstReady.isCompleted) {
              firstReady.complete();
            }
            return event;
          })
          .toList();
      await firstReady.future.timeout(const Duration(seconds: 20));
      final a = await runtime.openPty(
        mounts: mounts,
        cwd: '/workspace',
        env: const {},
        cols: 80,
        rows: 24,
      );
      final b = await runtime.openPty(
        mounts: secondPaths.mounts,
        cwd: '/workspace',
        env: const {},
        cols: 80,
        rows: 24,
      );
      final aOutput = a.output.listen((_) {});
      final bOutput = b.output.listen((_) {});
      try {
        final second = await runCmd(
          'pwd; cat identity; printf workspace-b > /chat/child.txt',
          extraMounts: secondPaths.mounts,
        );
        expect(second.exit.exitCode, 0, reason: second.stderr);
        expect(second.stdout, contains('/workspace'));
        expect(second.stdout, contains('workspace-b'));
        final firstEvents = await first.timeout(const Duration(seconds: 20));
        expect(firstEvents.whereType<CommandExited>().single.exitCode, 0);
        final firstText = firstEvents
            .whereType<CommandOutput>()
            .map((event) => utf8.decode(event.bytes))
            .join();
        expect(firstText, contains('/workspace'));
        expect(firstText, contains('workspace-a'));
        expect(
          await File(p.join(sessionHost.path, 'child.txt')).readAsString(),
          'workspace-a',
        );
        expect(
          await File(p.join(secondChat.path, 'child.txt')).readAsString(),
          'workspace-b',
        );
        await a.write(utf8.encode('cat identity > /chat/pty.txt\r'));
        await b.write(utf8.encode('cat identity > /chat/pty.txt\r'));
        final aFile = File(p.join(sessionHost.path, 'pty.txt'));
        final bFile = File(p.join(secondChat.path, 'pty.txt'));
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (!await aFile.exists() || !await bFile.exists()) {
          if (DateTime.now().isAfter(deadline)) {
            fail('PTY output did not reach its own chat');
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(await aFile.readAsString(), 'workspace-a');
        expect(await bFile.readAsString(), 'workspace-b');
        final files = HostFileTools(secondPaths);
        final guestTmp = '/tmp/${p.basename(secondRoot.path)}/shared.txt';
        await files.writeFile(guestTmp, 'from-file-tool');
        final tmpResult = await runCmd(
          'cat $guestTmp; printf from-shell > $guestTmp',
          extraMounts: secondPaths.mounts,
        );
        expect(tmpResult.exit.exitCode, 0, reason: tmpResult.stderr);
        expect(tmpResult.stdout, contains('from-file-tool'));
        expect((await files.readFile(guestTmp)).text, contains('from-shell'));
      } finally {
        await a.close();
        await b.close();
        await Future.wait([
          a.exitCode,
          b.exitCode,
        ]).timeout(const Duration(seconds: 20));
        await aOutput.cancel();
        await bOutput.cancel();
        await secondRoot.delete(recursive: true);
      }
    });

    iosTest('1. probe reports installed / version / needsRestart', (
      tester,
    ) async {
      final probe = await channel.probe();
      // ignore: avoid_print
      print(
        'probe: supported=${probe.supported} engine=${probe.engine} '
        'installed=${probe.installed} booted=${probe.booted} '
        'needsRestart=${probe.needsRestart} rootfsVersion=${probe.rootfsVersion} '
        'bundledVersion=${probe.bundledVersion} reason=${probe.reason}',
      );
      expect(probe.supported, isTrue);
      expect(probe.engine, 'ish');
      expect(probe.installed, isNotNull);
      expect(probe.needsRestart, isNotNull);
      expect(probe.bundledVersion, isNotNull);
    });

    iosTest('2. install bundled zip to ready and persist fakefs markers', (
      tester,
    ) async {
      final before = await channel.probe();
      final sw = Stopwatch()..start();
      if (before.installed != true ||
          before.rootfsVersion != before.bundledVersion) {
        await manager.install();
      } else {
        await manager.install();
      }
      sw.stop();
      // ignore: avoid_print
      print('install elapsed: ${sw.elapsed}');
      expect(env.state.phase, EnvironmentPhase.ready);
      expect(env.state.distro, 'alpine');

      final rootfs = await installedRootfsDir();
      expect(
        File(p.join(rootfs.path, 'meta.db')).existsSync(),
        isTrue,
        reason: 'fakefs meta.db missing at ${rootfs.path}',
      );
      final versionMarker =
          File(p.join(rootfs.path, '.version')).existsSync() ||
          File(p.join(rootfs.path, 'VERSION')).existsSync();
      expect(versionMarker, isTrue, reason: 'VERSION/.version missing');
      final after = await channel.probe();
      expect(after.installed, isTrue);
      expect(after.rootfsVersion, after.bundledVersion);
    });

    iosTest('3. boot + run uname/alpine/id/home/pwd/ls with bind mounts', (
      tester,
    ) async {
      await channel.boot();
      final result = await runCmd(
        r'uname -a; cat /etc/alpine-release; id; echo $HOME; pwd; ls /',
      );
      // ignore: avoid_print
      print('boot-run stdout:\n${result.stdout}\nstderr:\n${result.stderr}');
      expect(result.exit.exitCode, 0);
      expect(result.stdout, contains('Linux'));
      expect(result.stdout.toLowerCase(), contains('aarch64'));
      expect(result.stdout, contains(RegExp(r'3\.21')));
      expect(result.stdout, contains('uid=0'));
      expect(result.stdout, contains('/root'));
      expect(result.stdout, contains(WorkspacePaths.guestWorkspace));
      final lines = result.stdout.split(RegExp(r'\r?\n'));
      expect(lines, contains(WorkspacePaths.guestWorkspace));
      expect(result.stdout, contains('workspace'));
      expect(result.stdout, contains('chat'));
      expect(result.stdout, contains('skills'));

      final detailedListing = await runCmd('ls -la /');
      // ignore: avoid_print
      print(
        'ls -la / stdout:\n${detailedListing.stdout}\nstderr:\n${detailedListing.stderr}',
      );
      expect(detailedListing.exit.exitCode, 0);
      expect(detailedListing.stdout, isNot(contains('Error relocating')));
      expect(detailedListing.stderr, isNot(contains('Error relocating')));

      final lsVersion = await runCmd('ls --version');
      // ignore: avoid_print
      print(
        'ls --version stdout:\n${lsVersion.stdout}\nstderr:\n${lsVersion.stderr}',
      );
      expect(lsVersion.exit.exitCode, 0);
      expect(lsVersion.stdout.toLowerCase(), contains('coreutils'));
      expect(lsVersion.stdout, isNot(contains('Error relocating')));
      expect(lsVersion.stderr, isNot(contains('Error relocating')));

      final rootListing = await runCmd('ls -a /');
      expect(rootListing.exit.exitCode, 0);
      final rootNames = rootListing.stdout
          .split(RegExp(r'\s+'))
          .where((name) => name.isNotEmpty)
          .toSet();
      const apkResidue = {
        'PKGINFO',
        '.PKGINFO',
        'post-install',
        '.post-install',
        'pre-install',
        '.pre-install',
        'post-upgrade',
        '.post-upgrade',
        'trigger',
        '.trigger',
      };
      expect(rootNames.intersection(apkResidue), isEmpty);
      expect(rootListing.stdout, isNot(contains('SIGN.RSA')));

      File(p.join(workspaceHost.path, 'host-ws.txt')).writeAsStringSync('ws');
      File(p.join(sessionHost.path, 'host-chat.txt')).writeAsStringSync('chat');
      File(p.join(skillsHost.path, 'host-skill.txt')).writeAsStringSync('sk');
      final mountsLs = await runCmd(
        'ls ${WorkspacePaths.guestWorkspace} ${WorkspacePaths.guestChat} ${WorkspacePaths.guestSkills}',
      );
      expect(mountsLs.exit.exitCode, 0);
      expect(mountsLs.stdout, contains('host-ws.txt'));
      expect(mountsLs.stdout, contains('host-chat.txt'));
      expect(mountsLs.stdout, contains('host-skill.txt'));
    });

    iosTest('3a. GNU cp overwrites files in rootfs and workspace', (
      tester,
    ) async {
      final result = await runCmd(r'''
set -e
cp --version
for base in /tmp /workspace; do
  dir=$(mktemp -d "$base/kelivo-cp-XXXXXX")
  printf 'new contents' > "$dir/src"
  printf 'old contents' > "$dir/dst"
  cp "$dir/src" "$dir/dst"
  test "$(cat "$dir/dst")" = 'new contents'
  rm -rf "$dir"
done
printf 'COPY_OK\n'
''');
      expect(result.exit.exitCode, 0, reason: result.stderr);
      expect(result.stdout, contains('GNU coreutils'));
      expect(result.stdout, contains('COPY_OK'));
    });

    iosTest('4. UTF-8 printf and filename have no U+FFFD', (tester) async {
      final result = await runCmd("printf '中文\\n'; touch 中文名.txt; ls");
      expect(result.exit.exitCode, 0);
      expect(result.stdout, contains('中文'));
      expect(result.stdout, contains('中文名.txt'));
      expect(result.stdout, isNot(contains('\uFFFD')));
      expect(result.stderr, isNot(contains('\uFFFD')));
    });

    iosTest('5. stderr and exit 7', (tester) async {
      final result = await runCmd('echo out; echo err 1>&2; exit 7');
      expect(result.exit.exitCode, 7);
      expect(result.stdout, contains('out'));
      expect(result.stderr, contains('err'));
    });

    iosTest('6. 20 sequential execs succeed', (tester) async {
      for (var i = 0; i < 20; i++) {
        final result = await runCmd('echo seq-$i && true');
        expect(result.exit.exitCode, 0, reason: 'seq $i failed');
        expect(result.stdout, contains('seq-$i'));
      }
    });

    iosTest('7. DNS + apk update', (tester) async {
      final result = await runCmd(
        'nslookup dl-cdn.alpinelinux.org || getent hosts dl-cdn.alpinelinux.org; '
        'apk update 2>&1 | tail -2',
        timeout: const Duration(minutes: 2),
      );
      // ignore: avoid_print
      print(
        'dns/apk exit=${result.exit.exitCode} timedOut=${result.exit.timedOut}\n'
        'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
      );
      expect(result.exit.timedOut, isFalse);
      expect(
        result.stdout + result.stderr,
        anyOf(contains('dl-cdn.alpinelinux.org'), contains('OK:')),
      );
    });

    iosTest('8. timeout kill of sleep 30.123', (tester) async {
      final sw = Stopwatch()..start();
      final result = await runCmd(
        'sleep 30.123',
        timeout: const Duration(seconds: 2),
      );
      sw.stop();
      // ignore: avoid_print
      print(
        'timeout elapsed=${sw.elapsed} timedOut=${result.exit.timedOut} '
        'cancelled=${result.exit.cancelled} interrupted=${result.exit.interrupted} '
        'exit=${result.exit.exitCode}',
      );
      expect(sw.elapsed <= const Duration(seconds: 6), isTrue);
      expect(result.exit.timedOut, isTrue);
      // Busybox `pgrep -f 30.123` also matches this checker `sh -c` line.
      // `[s]leep` avoids self-match. Brief wait for the SIGKILL follow-up.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final gone = await runCmd("ps | grep '[s]leep 30.123' || echo gone");
      // ignore: avoid_print
      print('timeout leftover:\n${gone.stdout}\n${gone.stderr}');
      expect(gone.stdout, contains('gone'));
    });

    iosTest('9. cancel sleep 40.5', (tester) async {
      final runId = 'ios-ish-cancel-${++seq}';
      final sw = Stopwatch()..start();
      final eventsFuture = runtime
          .run(
            CommandRequest(
              runId: runId,
              command: "sh -c 'sleep 40.5 & wait'",
              cwd: WorkspacePaths.guestWorkspace,
              timeout: const Duration(seconds: 60),
              mounts: mounts,
            ),
          )
          .toList();
      await Future<void>.delayed(const Duration(seconds: 1));
      await runtime.cancel(runId);
      final events = await eventsFuture;
      sw.stop();
      final exit = events.whereType<CommandExited>().single;
      // ignore: avoid_print
      print(
        'cancel elapsed=${sw.elapsed} cancelled=${exit.cancelled} '
        'interrupted=${exit.interrupted} exit=${exit.exitCode}',
      );
      expect(sw.elapsed <= const Duration(seconds: 5), isTrue);
      expect(exit.cancelled || exit.interrupted, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final gone = await runCmd("ps | grep '[s]leep 40.5' || echo gone");
      // ignore: avoid_print
      print('cancel leftover:\n${gone.stdout}\n${gone.stderr}');
      expect(gone.stdout, contains('gone'));
    });

    iosTest('10. PTY echo, resize, stty size, kill', (tester) async {
      final session = await runtime.openPty(
        mounts: mounts,
        cwd: WorkspacePaths.guestWorkspace,
        env: const <String, String>{},
        cols: 80,
        rows: 24,
      );
      final buf = StringBuffer();
      final sub = session.output.listen((chunk) {
        buf.write(utf8.decode(chunk, allowMalformed: true));
      });

      Future<void> waitFor(String needle, {Duration? limit}) async {
        final deadline = DateTime.now().add(
          limit ?? const Duration(seconds: 20),
        );
        while (!buf.toString().contains(needle)) {
          if (DateTime.now().isAfter(deadline)) {
            fail('PTY did not emit "$needle". so far:\n$buf');
          }
          await Future<void>.delayed(const Duration(milliseconds: 80));
        }
      }

      await Future<void>.delayed(const Duration(seconds: 2));
      await session.write(utf8.encode('echo PTY_OK_\$((6*7))\r'));
      await waitFor('PTY_OK_42');
      await session.resize(100, 40);
      await session.write(utf8.encode('stty size\r'));
      await waitFor('40 100');
      await session.close();
      final code = await session.exitCode.timeout(const Duration(seconds: 10));
      await sub.cancel();
      // ignore: avoid_print
      print('pty exit=$code output:\n$buf');
      expect(buf.toString(), contains('PTY_OK_42'));
      expect(buf.toString(), contains('40 100'));
    });

    iosTest(
      '11. WorkspaceToolsService sandboxed write/read/edit/list/glob/grep',
      (tester) async {
        final paths = WorkspacePaths.sandboxed(
          workspaceHostRoot: workspaceHost.path,
          sessionHostDir: sessionHost.path,
          skillsHostDir: skillsHost.path,
        );
        final ctx = WorkspaceToolContext(
          workspace: Workspace(
            id: 'ios-ish-ws',
            name: 'iSH verify',
            kind: WorkspaceKind.managed,
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
          binding: const WorkspaceBinding(
            workspaceId: 'ios-ish-ws',
            allowAll: true,
          ),
          paths: paths,
          sessionDir: sessionHost,
          outputsDir: Directory(p.join(sessionHost.path, 'outputs'))
            ..createSync(),
          conversationId: 'ios-ish-conv',
          runtimeStatus: const RuntimeStatus(
            ready: true,
            engine: 'ish',
            sandboxed: true,
          ),
          runtimeRegistered: true,
        );
        final tools = WorkspaceToolsService();

        Future<ClientToolResult> call(
          String name,
          Map<String, dynamic> args,
        ) async {
          return ClientToolResult.fromHandler(
            await tools.handle(ctx, name, args, toolCallId: 'tc-$name'),
          );
        }

        final write = await call('write_file', {
          'path': '/workspace/note.txt',
          'content': 'hello sandbox',
        });
        // ignore: avoid_print
        print('write_file => ${write.content} meta=${write.metadata}');
        expect(jsonDecode(write.content)['ok'], isTrue);

        final read = await call('read_file', {'path': '/workspace/note.txt'});
        expect(read.content, contains('hello sandbox'));

        final edit = await call('edit_file', {
          'path': '/workspace/note.txt',
          'old_string': 'hello sandbox',
          'new_string': 'hello edited',
        });
        final editJson = jsonDecode(edit.content) as Map<String, dynamic>;
        expect(editJson['ok'], isTrue);
        expect(editJson['replacements'], 1);
        final editMeta = edit.metadata?['workspace'];
        final diff = editMeta is Map ? editMeta['diff'] : null;
        expect(diff, isNotNull, reason: 'edit metadata=$editMeta');

        final listed = await call('list_dir', {'path': '/workspace'});
        expect(listed.content, contains('note.txt'));

        final glob = await call('glob', {
          'pattern': '*.txt',
          'path': '/workspace',
        });
        expect(glob.content, contains('note.txt'));

        final grep = await call('grep', {
          'pattern': 'edited',
          'path': '/workspace',
        });
        expect(grep.content, contains('edited'));

        final escape = await call('write_file', {
          'path': '../escape',
          'content': 'nope',
        });
        final escapeJson = jsonDecode(escape.content) as Map<String, dynamic>;
        expect(escapeJson['type'], 'tool_error');
        expect(escapeJson['error'], anyOf('path_error', 'path_outside'));
      },
    );

    iosTest('12. beginBackgroundTask / endBackgroundTask round trip', (
      tester,
    ) async {
      await channel.beginBackgroundTask();
      await channel.endBackgroundTask();
    });

    iosTest('13. reset leaves needsRestart and status not ready', (
      tester,
    ) async {
      await manager.reset();
      final probe = await channel.probe();
      final status = await runtime.status();
      // ignore: avoid_print
      print(
        'reset probe needsRestart=${probe.needsRestart} reason=${probe.reason} '
        'status ready=${status.ready} reason=${status.reason} '
        'env.phase=${env.state.phase}',
      );
      expect(probe.needsRestart, isTrue);
      expect(status.ready, isFalse);
      expect(status.reason, 'needs_restart');
      expect(env.state.phase, EnvironmentPhase.needsRestart);
    });
  });
}

class _Run {
  const _Run({
    required this.runId,
    required this.stdout,
    required this.stderr,
    required this.exit,
  });

  final String runId;
  final String stdout;
  final String stderr;
  final CommandExited exit;
}
