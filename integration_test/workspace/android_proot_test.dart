import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/android_proot_runtime.dart';
import 'package:Kelivo/core/services/sandbox/environment_installer.dart';
import 'package:Kelivo/core/services/sandbox/mirror_service.dart';
import 'package:Kelivo/core/services/sandbox/mirror_speed_test.dart';
import 'package:Kelivo/core/services/sandbox/mobile_workspace_bootstrap.dart';
import 'package:Kelivo/core/services/sandbox/rootfs_source.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/workspace/terminal/terminal_session_manager.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

const _suiteTimeout = Timeout(Duration(minutes: 20));
const _replacementChar = '\uFFFD';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isAndroid) {
    testWidgets(
      'android proot suite is Android-only',
      (tester) async {},
      skip: true,
    );
    return;
  }

  late _Harness h;

  setUpAll(() async {
    h = await _Harness.open();
  });

  tearDownAll(() async {
    await h.dispose();
  });

  testWidgets('1 probe reports supported ABI and proot', (tester) async {
    await tester.pump();
    final probe = await h.channel.probe();
    _log(
      'PROBE supported=${probe.supported} abi=${probe.abi} '
      'proot=${probe.prootPath} loader=${probe.loaderPath} '
      'reason=${probe.reason}',
    );
    expect(
      probe.supported,
      isTrue,
      reason: probe.reason ?? 'probe unsupported',
    );
    expect(probe.abi, anyOf('armeabi-v7a', 'arm64-v8a', 'x86_64'));
    expect(probe.prootPath, isNotNull);
    expect(File(probe.prootPath!).existsSync(), isTrue);
  }, timeout: _suiteTimeout);

  testWidgets('2 freeSpace is greater than 1 GiB', (tester) async {
    await tester.pump();
    final envDir = await AppDirectories.getEnvironmentDirectory();
    final space = await h.channel.freeSpace(envDir.path);
    _log(
      'FREE_SPACE freeBytes=${space.freeBytes} totalBytes=${space.totalBytes} '
      '(${(space.freeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GiB free)',
    );
    expect(space.freeBytes, greaterThan(1024 * 1024 * 1024));
  }, timeout: _suiteTimeout);

  testWidgets('3 environment install reaches ready', (tester) async {
    await tester.pump();
    await h.ensureReady();
    expect(h.env.state.phase, EnvironmentPhase.ready);
    expect(
      File(p.join(h.installer.rootfsDir.path, kKelivoVersionFile)).existsSync(),
      isTrue,
    );
    _log(
      'INSTALL ready distro=${h.env.state.distro} version=${h.env.state.version} '
      'arch=${h.env.state.arch} mirror=${h.env.state.lastMirrorBase} '
      'seconds=${h.installSeconds} tarballBytes=${h.tarballBytes} '
      'alreadyInstalled=${h.alreadyInstalled}',
    );
  }, timeout: _suiteTimeout);

  testWidgets('4 runtime.status is ready and sandboxed', (tester) async {
    await tester.pump();
    expect(h.env.state.phase, EnvironmentPhase.ready);
    final status = await h.runtime.status();
    _log(
      'STATUS ready=${status.ready} sandboxed=${status.sandboxed} '
      'engine=${status.engine} reason=${status.reason}',
    );
    expect(status.ready, isTrue);
    expect(status.sandboxed, isTrue);
    expect(status.engine, 'proot');
  }, timeout: _suiteTimeout);

  testWidgets('5 run uname/os-release/id/HOME/pwd in workspace', (
    tester,
  ) async {
    await tester.pump();
    final result = await h.run(
      'uname -a; cat /etc/os-release | head -3; id; echo HOME=\$HOME; pwd',
    );
    _log(
      'UNAME exit=${result.exit.exitCode} stdout:\n${result.stdout}\n'
      'stderr:\n${result.stderr}',
    );
    expect(result.exit.exitCode, 0);
    expect(result.stdout.toLowerCase(), contains('ubuntu'));
    expect(result.stdout, contains('Linux'));
    expect(
      result.stdout.trim().split('\n').last,
      WorkspacePaths.guestWorkspace,
    );
  }, timeout: _suiteTimeout);

  testWidgets('6 UTF-8 printf/touch/ls has no U+FFFD', (tester) async {
    await tester.pump();
    final result = await h.run("printf '中文\\n'; touch 中文名.txt; ls");
    _log('UTF8 exit=${result.exit.exitCode} stdout:\n${result.stdout}');
    expect(result.exit.exitCode, 0);
    expect(result.stdout, contains('中文'));
    expect(result.stdout, contains('中文名.txt'));
    expect(result.stdout, isNot(contains(_replacementChar)));
    expect(result.stderr, isNot(contains(_replacementChar)));
  }, timeout: _suiteTimeout);

  testWidgets('7 stderr and exit 7', (tester) async {
    await tester.pump();
    final result = await h.run('echo out; echo err 1>&2; exit 7');
    _log(
      'STDERR exit=${result.exit.exitCode} stdout=${result.stdout} '
      'stderr=${result.stderr}',
    );
    expect(result.stdout, contains('out'));
    expect(result.stderr, contains('err'));
    expect(result.exit.exitCode, 7);
  }, timeout: _suiteTimeout);

  testWidgets('8 DNS and apt-get update (report-only on timeout)', (
    tester,
  ) async {
    await tester.pump();
    final result = await h.run(
      'getent hosts deb.debian.org || nslookup ubuntu.com; '
      'apt-get update 2>&1 | tail -3',
      timeout: const Duration(minutes: 5),
    );
    _log(
      'APT timedOut=${result.exit.timedOut} exit=${result.exit.exitCode} '
      'durationMs=${result.exit.duration.inMilliseconds} '
      'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
    );
    if (result.exit.timedOut) {
      _log('APT_RESULT timeout — not failing the suite');
      return;
    }
    final combined = '${result.stdout}\n${result.stderr}';
    final reached =
        combined.contains('Get:') ||
        combined.contains('Hit:') ||
        combined.contains('Ign:') ||
        combined.contains('Reading package lists') ||
        combined.contains('address');
    _log('APT_RESULT reachedMirror=$reached');
  }, timeout: _suiteTimeout);

  testWidgets('9 timeout kills sleep 30.123', (tester) async {
    await tester.pump();
    final sw = Stopwatch()..start();
    final slept = await h.run(
      'sleep 30.123',
      timeout: const Duration(seconds: 2),
    );
    sw.stop();
    _log(
      'TIMEOUT durationMs=${sw.elapsedMilliseconds} '
      'eventMs=${slept.exit.duration.inMilliseconds} '
      'timedOut=${slept.exit.timedOut} cancelled=${slept.exit.cancelled}',
    );
    expect(sw.elapsed, lessThan(const Duration(seconds: 6)));
    expect(slept.exit.timedOut, isTrue);

    final check = await h.run(
      r'''ps -ef | grep -v grep | grep '[s]leep 30.123' || echo gone''',
    );
    _log('TIMEOUT_PGREP stdout=${check.stdout} stderr=${check.stderr}');
    expect(check.stdout, contains('gone'));
  }, timeout: _suiteTimeout);

  testWidgets('10 cancel kills process tree', (tester) async {
    await tester.pump();
    const runId = 'cancel-40-5';
    final sw = Stopwatch()..start();
    final done = Completer<CommandExited>();
    final sub = h.runtime
        .run(
          CommandRequest(
            runId: runId,
            command: "sh -c 'sleep 40.5 & wait'",
            cwd: WorkspacePaths.guestWorkspace,
            timeout: const Duration(seconds: 60),
            env: _guestEnv,
            mounts: h.paths.mounts,
          ),
        )
        .listen((event) {
          if (event is CommandExited && !done.isCompleted) {
            done.complete(event);
          }
        });
    await Future<void>.delayed(const Duration(seconds: 1));
    await h.runtime.cancel(runId);
    final exit = await done.future.timeout(const Duration(seconds: 5));
    sw.stop();
    await sub.cancel();
    _log(
      'CANCEL durationMs=${sw.elapsedMilliseconds} cancelled=${exit.cancelled} '
      'exit=${exit.exitCode}',
    );
    expect(sw.elapsed, lessThanOrEqualTo(const Duration(seconds: 5)));
    expect(exit.cancelled, isTrue);

    final check = await h.run(
      r'''ps -ef | grep -v grep | grep '[s]leep 40.5' || echo gone''',
    );
    _log('CANCEL_PGREP stdout=${check.stdout}');
    expect(check.stdout, contains('gone'));
  }, timeout: _suiteTimeout);

  testWidgets('11 PTY echo, resize, stty size, exit', (tester) async {
    await tester.pump();
    final session = await h.runtime.openPty(
      mounts: h.paths.mounts,
      cwd: WorkspacePaths.guestWorkspace,
      env: kTerminalGuestEnv,
      cols: 80,
      rows: 24,
    );
    final buffer = StringBuffer();
    final sub = session.output.listen((chunk) {
      buffer.write(utf8.decode(chunk, allowMalformed: true));
    });

    await session.write(
      Uint8List.fromList(utf8.encode('echo PTY_OK_\$((6*7))\r')),
    );
    await _waitUntil(
      () => buffer.toString().contains('PTY_OK_42'),
      timeout: const Duration(seconds: 20),
      label: 'PTY_OK_42',
      dump: buffer,
    );
    _log('PTY_ECHO ${_stripAnsi(buffer.toString())}');

    await session.resize(100, 40);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await session.write(Uint8List.fromList(utf8.encode('stty size\r')));
    await _waitUntil(
      () => RegExp(r'\b40\s+100\b').hasMatch(_stripAnsi(buffer.toString())),
      timeout: const Duration(seconds: 15),
      label: 'stty 40 100',
      dump: buffer,
    );
    _log('PTY_STTY ${_stripAnsi(buffer.toString())}');

    await session.close();
    final code = await session.exitCode.timeout(const Duration(seconds: 10));
    await sub.cancel();
    _log('PTY_EXIT $code');
  }, timeout: _suiteTimeout);

  testWidgets(
    '12 WorkspaceToolsService sandboxed file + shell + escape',
    (tester) async {
      await tester.pump();
      final runtimeProvider = WorkspaceRuntimeProvider()..register(h.runtime);
      final tools = WorkspaceToolsService(runtimeProvider: runtimeProvider);
      final now = DateTime.now().toUtc();
      final ctx = WorkspaceToolContext(
        workspace: Workspace(
          id: 'verify-android',
          name: 'verify-android',
          kind: WorkspaceKind.managed,
          createdAt: now,
          updatedAt: now,
        ),
        binding: const WorkspaceBinding(workspaceId: 'verify-android'),
        paths: h.paths,
        sessionDir: h.sessionDir,
        outputsDir: Directory(p.join(h.sessionDir.path, 'outputs')),
        conversationId: 'verify-android-conv',
        runtimeStatus: await h.runtime.status(),
        runtimeRegistered: true,
      );

      Map<String, dynamic> jsonOf(Object? raw) {
        final decoded = jsonDecode(ClientToolResult.fromHandler(raw).content);
        return Map<String, dynamic>.from(decoded as Map);
      }

      final written = await tools.handle(ctx, 'write_file', {
        'path': '/workspace/note.txt',
        'content': 'hello world',
      }, toolCallId: 'write-1');
      final writtenBody = jsonOf(written);
      _log('WRITE $writtenBody');
      expect(writtenBody['ok'], isTrue);
      expect(writtenBody['path'], '/workspace/note.txt');

      final read = await tools.handle(ctx, 'read_file', {
        'path': '/workspace/note.txt',
      }, toolCallId: 'read-1');
      final readText = ClientToolResult.fromHandler(read).content;
      _log('READ $readText');
      expect(readText, contains('hello world'));

      final edited = await tools.handle(ctx, 'edit_file', {
        'path': '/workspace/note.txt',
        'old_string': 'hello',
        'new_string': 'howdy',
      }, toolCallId: 'edit-1');
      final editedBody = jsonOf(edited);
      final editedMeta = WorkspaceToolMetadata.fromJson(
        ClientToolResult.fromHandler(edited).metadata!,
      );
      _log(
        'EDIT body=$editedBody added=${editedMeta.added} '
        'removed=${editedMeta.removed} strategy=${editedMeta.strategy} '
        'diff=${editedMeta.diff}',
      );
      expect(editedBody['ok'], isTrue);
      expect(editedBody['replacements'], 1);
      expect(editedMeta.diff, isNotNull);

      final listing = ClientToolResult.fromHandler(
        await tools.handle(ctx, 'list_dir', {
          'path': '/workspace',
        }, toolCallId: 'list-1'),
      ).content;
      _log('LIST_DIR $listing');
      expect(listing, contains('note.txt'));

      final glob = ClientToolResult.fromHandler(
        await tools.handle(ctx, 'glob', {
          'pattern': '**/*.txt',
          'path': '/workspace',
        }, toolCallId: 'glob-1'),
      ).content;
      _log('GLOB $glob');
      expect(glob, contains('note.txt'));

      final grep = ClientToolResult.fromHandler(
        await tools.handle(ctx, 'grep', {
          'pattern': 'howdy',
          'path': '/workspace',
        }, toolCallId: 'grep-1'),
      ).content;
      _log('GREP $grep');
      expect(grep, contains('howdy'));

      final shell = await tools.handle(ctx, 'shell', {
        'command': 'pwd && cat /workspace/note.txt',
      }, toolCallId: 'shell-1');
      final shellBody = jsonOf(shell);
      _log('SHELL $shellBody');
      expect(shellBody['exit_code'], 0);
      expect(shellBody['stdout'], contains('/workspace'));
      expect(shellBody['stdout'], contains('howdy world'));

      final escape = await tools.handle(ctx, 'write_file', {
        'path': '../escape',
        'content': 'nope',
      }, toolCallId: 'escape-1');
      final escapeBody = jsonOf(escape);
      _log('ESCAPE $escapeBody');
      expect(escapeBody['error'], 'path_error');
    },
    timeout: _suiteTimeout,
  );

  group('mirror guest files', () {
    testWidgets('13 MirrorService detect/apply/restore pip', (tester) async {
      await tester.pump();
      await h.ensureReady();

      final probesByCategory = <MirrorCategory, List<MirrorProbe>>{};
      for (final category in [
        MirrorCategory.apt,
        MirrorCategory.pip,
        MirrorCategory.npm,
      ]) {
        final probes = await h.mirrors.detect(category);
        probesByCategory[category] = probes;
        for (final probe in probes) {
          _log(
            'MIRROR ${category.name} ${probe.uri} '
            'latencyMs=${probe.latency?.inMilliseconds} error=${probe.error}',
          );
        }
      }

      try {
        await _assertPipMirrorRoundTrip(
          h,
          probesByCategory[MirrorCategory.pip]!,
        );
        await _assertAptMirrorRoundTrip(
          h,
          probesByCategory[MirrorCategory.apt]!,
        );
      } finally {
        await h.mirrors.restoreOfficial(MirrorCategory.pip);
        await h.mirrors.restoreOfficial(MirrorCategory.apt);
      }
    }, timeout: _suiteTimeout);
  });

  testWidgets('14 cleanup verify-android workspace dir', (tester) async {
    await tester.pump();
    await h.cleanupWorkspace();
    expect(await h.workspaceDir.exists(), isFalse);
    _log(
      'CLEANUP removed ${h.workspaceDir.path}; environment left installed '
      'phase=${h.env.state.phase}',
    );
  }, timeout: _suiteTimeout);
}

const Map<String, String> _guestEnv = {
  'HOME': '/root',
  'LANG': 'C.UTF-8',
  'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
  'TERM': 'dumb',
  'DEBIAN_FRONTEND': 'noninteractive',
};

class _RunResult {
  const _RunResult({
    required this.stdout,
    required this.stderr,
    required this.exit,
  });

  final String stdout;
  final String stderr;
  final CommandExited exit;
}

class _Harness {
  _Harness({
    required this.channel,
    required this.env,
    required this.installer,
    required this.runtime,
    required this.mirrors,
    required this.workspaceDir,
    required this.sessionDir,
    required this.paths,
  });

  final WorkspaceChannel channel;
  final EnvironmentProvider env;
  final EnvironmentInstaller installer;
  final AndroidProotRuntime runtime;
  final MirrorService mirrors;
  final Directory workspaceDir;
  final Directory sessionDir;
  final WorkspacePaths paths;

  bool alreadyInstalled = false;
  double? installSeconds;
  int? tarballBytes;
  int _runSeq = 0;

  static Future<_Harness> open() async {
    final env = EnvironmentProvider(preferences: await _openPreferences());
    await env.loaded;
    final stack = await createMobileWorkspaceStack(env: env);
    if (stack == null) {
      throw StateError('createMobileWorkspaceStack returned null on Android');
    }
    try {
      await stack.channel.keepScreenOn(true);
    } catch (_) {}
    final installer = stack.manager as EnvironmentInstaller;
    final runtime = stack.runtime as AndroidProotRuntime;
    final workspaceDir = await AppDirectories.workspaceFilesDir(
      'verify-android',
    );
    final sessionDir = await AppDirectories.sessionDir('verify-android-conv');
    final skillsDir = await AppDirectories.getSkillsDirectory();
    final paths = WorkspacePaths.sandboxed(
      workspaceHostRoot: workspaceDir.path,
      sessionHostDir: sessionDir.path,
      skillsHostDir: skillsDir.path,
    );
    _log(
      'HARNESS workspace=${workspaceDir.path} session=${sessionDir.path} '
      'rootfs=${installer.rootfsDir.path} phase=${env.state.phase}',
    );
    return _Harness(
      channel: stack.channel,
      env: env,
      installer: installer,
      runtime: runtime,
      mirrors: stack.mirrors,
      workspaceDir: workspaceDir,
      sessionDir: sessionDir,
      paths: paths,
    );
  }

  Future<void> ensureReady() async {
    final versionFile = File(
      p.join(installer.rootfsDir.path, kKelivoVersionFile),
    );
    if (await versionFile.exists()) {
      alreadyInstalled = true;
      if (env.state.phase != EnvironmentPhase.ready) {
        final parsed = (await versionFile.readAsString()).trim().split(
          RegExp(r'\s+'),
        );
        await env.setState(
          EnvironmentState(
            phase: EnvironmentPhase.ready,
            distro: parsed.isNotEmpty ? parsed[0] : kUbuntuDistro,
            version: parsed.length > 1 ? parsed[1] : kUbuntuBaseVersion,
            arch: parsed.length > 2 ? parsed[2] : 'arm64',
            installedAt: DateTime.now().toUtc(),
            rootfsDir: installer.rootfsDir.path,
            lastMirrorBase: env.state.lastMirrorBase,
          ),
        );
      }
      await _recordTarballSize();
      _log(
        'INSTALL skipped; already on disk version=${env.state.version} '
        'mirror=${env.state.lastMirrorBase} tarballBytes=$tarballBytes',
      );
      return;
    }

    Future<void> once() async {
      var lastPrint = DateTime.fromMillisecondsSinceEpoch(0);
      EnvironmentPhase? lastPhase;
      await installer.install(
        onProgress: (state) {
          final now = DateTime.now();
          if (state.phase != lastPhase ||
              now.difference(lastPrint) >= const Duration(seconds: 3)) {
            lastPhase = state.phase;
            lastPrint = now;
            _log(
              'INSTALL ${state.phase.name} progress=${state.progress} '
              'bytes=${state.bytesDownloaded}/${state.bytesTotal} '
              'mirror=${state.lastMirrorBase}',
            );
          }
        },
      );
    }

    final sw = Stopwatch()..start();
    await once();
    if (env.state.phase == EnvironmentPhase.error &&
        env.state.errorMessage == EnvironmentError.network) {
      _log('INSTALL network error; retrying once');
      await once();
    }
    sw.stop();
    installSeconds = sw.elapsedMilliseconds / 1000.0;
    await _recordTarballSize();
    if (env.state.phase != EnvironmentPhase.ready) {
      throw TestFailure(
        'install did not reach ready: phase=${env.state.phase} '
        'error=${env.state.errorMessage} seconds=$installSeconds '
        'mirror=${env.state.lastMirrorBase}',
      );
    }
  }

  Future<void> _recordTarballSize() async {
    tarballBytes = env.state.bytesTotal;
    final downloads = installer.downloadsDir;
    if (!await downloads.exists()) return;
    await for (final entity in downloads.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.contains('ubuntu-base') &&
          (name.endsWith('.tar.gz') || name.endsWith('.part'))) {
        tarballBytes = await entity.length();
        return;
      }
    }
  }

  Future<_RunResult> run(
    String command, {
    Duration timeout = const Duration(seconds: 60),
    String? cwd,
  }) async {
    final stdout = StringBuffer();
    final stderr = StringBuffer();
    CommandExited? exit;
    await for (final event in runtime.run(
      CommandRequest(
        runId: 'it-${++_runSeq}',
        command: command,
        cwd: cwd ?? WorkspacePaths.guestWorkspace,
        timeout: timeout,
        env: _guestEnv,
        mounts: paths.mounts,
      ),
    )) {
      switch (event) {
        case CommandStarted():
          break;
        case CommandOutput(:final kind, :final bytes):
          final text = utf8.decode(bytes, allowMalformed: true);
          if (kind == OutputStreamKind.stdout) {
            stdout.write(text);
          } else {
            stderr.write(text);
          }
        case CommandExited():
          exit = event;
      }
    }
    if (exit == null) {
      throw TestFailure('command produced no exit: $command');
    }
    return _RunResult(
      stdout: stdout.toString(),
      stderr: stderr.toString(),
      exit: exit,
    );
  }

  Future<void> cleanupWorkspace() async {
    final parent = workspaceDir.parent;
    if (await parent.exists()) {
      await parent.delete(recursive: true);
    }
    if (await sessionDir.exists()) {
      await sessionDir.delete(recursive: true);
    }
  }

  Future<void> dispose() async {
    try {
      await channel.keepScreenOn(false);
    } catch (_) {}
  }
}

Future<BusinessPreferences> _openPreferences() async {
  final appData = await AppDirectories.getAppDataDirectory();
  final appDb = File(p.join(appData.path, AppDatabase.databaseFileName));
  if (await appDb.exists()) {
    try {
      final prefs = BusinessPreferences(
        BusinessRepository(AppDatabase.open(file: appDb)),
      );
      await prefs.load();
      _log('PREFS opened existing ${appDb.path}');
      return prefs;
    } catch (error, stack) {
      _log('PREFS existing kelivo.db failed: $error\n$stack');
    }
  } else {
    _log('PREFS no ${appDb.path}; using isolated temp DB');
  }
  final isolated = File(
    p.join(
      Directory.systemTemp.path,
      'kelivo-android-proot-it-${DateTime.now().millisecondsSinceEpoch}.db',
    ),
  );
  final prefs = BusinessPreferences(
    BusinessRepository(AppDatabase.open(file: isolated)),
  );
  await prefs.load();
  return prefs;
}

Future<void> _waitUntil(
  bool Function() ready, {
  required Duration timeout,
  required String label,
  required StringBuffer dump,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
  throw TestFailure(
    'timed out waiting for $label; output:\n${_stripAnsi(dump.toString())}',
  );
}

String _stripAnsi(String raw) {
  return raw.replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '');
}

void _log(String message) {
  // ignore: avoid_print
  print('VERIFY_ANDROID $message');
}

Uri _fastestMirror(
  List<MirrorProbe> probes, {
  required String label,
  bool Function(Uri uri)? prefer,
}) {
  final winner = probes.where((item) => item.latency != null).toList()
    ..sort((a, b) => a.latency!.compareTo(b.latency!));
  expect(winner, isNotEmpty, reason: 'no $label mirror responded');
  if (prefer != null) {
    for (final item in winner) {
      if (prefer(item.uri)) return item.uri;
    }
  }
  return winner.first.uri;
}

Future<String> _guestCat(_Harness h, String path) async {
  final result = await h.run('cat $path');
  _log('CAT $path exit=${result.exit.exitCode} stdout:\n${result.stdout}');
  return result.stdout;
}

Future<bool> _guestExists(_Harness h, String path) async {
  final result = await h.run('test -f $path && echo PRESENT || echo ABSENT');
  _log('TEST -f $path ${result.stdout.trim()}');
  return result.stdout.contains('PRESENT');
}

Future<void> _assertPipMirrorRoundTrip(
  _Harness h,
  List<MirrorProbe> probes,
) async {
  await h.mirrors.restoreOfficial(MirrorCategory.pip);
  if (await _guestExists(h, '/etc/pip.conf')) {
    final leftover = await _guestCat(h, '/etc/pip.conf');
    _log('PIP leftover without bak/sentinel; removing:\n$leftover');
    await h.run(
      'rm -f /etc/pip.conf /etc/pip.conf.bak /etc/pip.conf.kelivo-created',
    );
  }
  expect(
    await _guestExists(h, '/etc/pip.conf'),
    isFalse,
    reason: 'fresh rootfs should have no /etc/pip.conf before apply',
  );

  final pick = _fastestMirror(probes, label: 'pip');
  _log('PIP_APPLY $pick');
  await h.mirrors.apply(MirrorCategory.pip, pick);

  final applied = await _guestCat(h, '/etc/pip.conf');
  expect(applied, contains(pick.host), reason: 'applied pip.conf:\n$applied');
  expect(await _guestExists(h, '/etc/pip.conf.kelivo-created'), isTrue);
  expect(await _guestExists(h, '/etc/pip.conf.bak'), isFalse);
  expect(await _guestExists(h, '/root/.config/pip/pip.conf'), isFalse);
  expect(RegExp(r'index-url\s*=').allMatches(applied).length, 1);

  _log('PIP_APPLY_AGAIN $pick');
  await h.mirrors.apply(MirrorCategory.pip, pick);
  final again = await _guestCat(h, '/etc/pip.conf');
  expect(again, contains(pick.host), reason: 're-applied pip.conf:\n$again');
  expect(await _guestExists(h, '/etc/pip.conf.kelivo-created'), isTrue);
  expect(
    await _guestExists(h, '/etc/pip.conf.bak'),
    isFalse,
    reason: 'second apply must not back up our own pip.conf',
  );
  expect(await _guestExists(h, '/root/.config/pip/pip.conf'), isFalse);
  expect(RegExp(r'index-url\s*=').allMatches(again).length, 1);

  await h.mirrors.restoreOfficial(MirrorCategory.pip);
  expect(await _guestExists(h, '/etc/pip.conf'), isFalse);
  expect(await _guestExists(h, '/etc/pip.conf.kelivo-created'), isFalse);
  expect(await _guestExists(h, '/etc/pip.conf.bak'), isFalse);
}

Future<void> _assertAptMirrorRoundTrip(
  _Harness h,
  List<MirrorProbe> probes,
) async {
  await h.mirrors.restoreOfficial(MirrorCategory.apt);
  const sources = '/etc/apt/sources.list.d/ubuntu.sources';
  final original = await _guestCat(h, sources);
  expect(original.trim(), isNotEmpty, reason: '$sources missing before apply');

  final pick = _fastestMirror(
    probes,
    label: 'apt',
    prefer: (uri) => !uri.host.contains('ubuntu.com'),
  );
  _log('APT_APPLY $pick');
  await h.mirrors.apply(MirrorCategory.apt, pick);

  final applied = await _guestCat(h, sources);
  expect(applied, contains(pick.host), reason: 'applied sources:\n$applied');
  expect(await _guestExists(h, '$sources.bak'), isTrue);
  expect(await _guestExists(h, '$sources.kelivo-created'), isFalse);

  await h.mirrors.restoreOfficial(MirrorCategory.apt);
  expect(await _guestExists(h, '$sources.bak'), isFalse);
  expect(await _guestExists(h, '$sources.kelivo-created'), isFalse);
  final restored = await _guestCat(h, sources);
  expect(
    restored,
    original,
    reason: 'apt sources after restore:\n$restored\noriginal:\n$original',
  );
}
