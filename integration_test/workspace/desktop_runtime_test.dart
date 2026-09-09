import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/services/workspace/desktop_process_runtime.dart';
import 'package:Kelivo/core/services/workspace/output_buffer.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final desktop = Platform.isMacOS || Platform.isLinux;

  late DesktopProcessRuntime runtime;
  late Directory hostRoot;
  late Directory sessionDir;
  late Directory skillsDir;
  late Directory outputsDir;

  setUp(() async {
    runtime = DesktopProcessRuntime();
    hostRoot = await Directory.systemTemp.createTemp('kelivo_macos_ws_');
    sessionDir = Directory(p.join(hostRoot.path, '_session'))..createSync();
    skillsDir = Directory(p.join(hostRoot.path, '_skills'))..createSync();
    outputsDir = Directory(p.join(sessionDir.path, 'outputs'))..createSync();
    Directory(p.join(sessionDir.path, 'attachments')).createSync();
  });

  tearDown(() async {
    if (await hostRoot.exists()) {
      await hostRoot.delete(recursive: true);
    }
  });

  testWidgets('desktop process runtime and workspace tools', (tester) async {
    if (!desktop) {
      markTestSkipped('DesktopProcessRuntime is macOS/Linux only');
      return;
    }

    await _statusReadyUnsandboxed(runtime);
    await _echoStdoutStderrExit(runtime, hostRoot);
    await _utf8RoundTrip(runtime, hostRoot);
    await _cwdAndEnv(runtime, hostRoot);
    await _timeoutKillsSleep(runtime, hostRoot);
    await _cancelKillsProcessTree(runtime, hostRoot);
    await _largeOutputOffload(runtime, hostRoot, outputsDir);
    await _toolsEndToEnd(
      runtime: runtime,
      hostRoot: hostRoot,
      sessionDir: sessionDir,
      skillsDir: skillsDir,
      outputsDir: outputsDir,
    );
    _systemTerminalFlags(runtime);
  });
}

Future<void> _statusReadyUnsandboxed(DesktopProcessRuntime runtime) async {
  final status = await runtime.status();
  expect(status.ready, isTrue);
  expect(status.sandboxed, isFalse);
  expect(status.engine, 'process');
  expect(status.reason, isNull);
}

Future<void> _echoStdoutStderrExit(
  DesktopProcessRuntime runtime,
  Directory cwd,
) async {
  final events = await _collect(
    runtime,
    _req(
      runId: 'echo-exit',
      command: 'echo hello; echo err 1>&2; exit 3',
      cwd: cwd.path,
    ),
  );
  expect(events.first, isA<CommandStarted>());
  expect(events.last, isA<CommandExited>());
  expect(utf8.decode(_stdout(events)), contains('hello'));
  expect(utf8.decode(_stderr(events)), contains('err'));
  final exit = _singleExit(events);
  expect(exit.exitCode, 3);
  expect(exit.timedOut, isFalse);
  expect(exit.cancelled, isFalse);
  final kinds = events.map((e) => e.runtimeType).toList();
  expect(kinds.first, CommandStarted);
  expect(kinds.last, CommandExited);
}

Future<void> _utf8RoundTrip(
  DesktopProcessRuntime runtime,
  Directory cwd,
) async {
  File(p.join(cwd.path, '中文名.txt')).writeAsStringSync('ok\n');
  final printfEvents = await _collect(
    runtime,
    _req(runId: 'printf-zh', command: r"printf '中文\n'", cwd: cwd.path),
  );
  final printfText = utf8.decode(_stdout(printfEvents));
  expect(printfText, contains('中文'));
  expect(printfText, isNot(contains('\uFFFD')));
  expect(_singleExit(printfEvents).exitCode, 0);

  final lsEvents = await _collect(
    runtime,
    _req(runId: 'ls-zh', command: 'ls', cwd: cwd.path),
  );
  final lsText = utf8.decode(_stdout(lsEvents));
  expect(lsText, contains('中文名.txt'));
  expect(lsText, isNot(contains('\uFFFD')));
}

Future<void> _cwdAndEnv(DesktopProcessRuntime runtime, Directory cwd) async {
  final pwdEvents = await _collect(
    runtime,
    _req(runId: 'pwd', command: 'pwd', cwd: cwd.path),
  );
  final printed = utf8.decode(_stdout(pwdEvents)).trim();
  expect(
    Directory(printed).resolveSymbolicLinksSync(),
    cwd.resolveSymbolicLinksSync(),
  );

  final envEvents = await _collect(
    runtime,
    _req(
      runId: 'env',
      command: r'echo $KELIVO_TEST',
      cwd: cwd.path,
      env: const <String, String>{'KELIVO_TEST': 'kelivo-macos-ok'},
    ),
  );
  expect(utf8.decode(_stdout(envEvents)), contains('kelivo-macos-ok'));
}

Future<void> _timeoutKillsSleep(
  DesktopProcessRuntime runtime,
  Directory cwd,
) async {
  const marker = '30.187654';
  final watch = Stopwatch()..start();
  final events = await _collect(
    runtime,
    _req(
      runId: 'timeout-sleep',
      command: 'sleep $marker',
      cwd: cwd.path,
      timeout: const Duration(seconds: 2),
    ),
    limit: const Duration(seconds: 12),
  );
  watch.stop();
  expect(
    watch.elapsed,
    lessThan(const Duration(seconds: 6)),
    reason: 'timeout should kill promptly, elapsed ${watch.elapsed}',
  );
  final exit = _singleExit(events);
  expect(exit.timedOut, isTrue);
  expect(exit.cancelled, isFalse);
  expect(exit.exitCode, anyOf(-1, isNonZero));
  await Future<void>.delayed(const Duration(milliseconds: 250));
  final leftover = await Process.run('pgrep', ['-f', '[s]leep $marker']);
  expect(
    leftover.exitCode,
    isNot(0),
    reason: 'sleep $marker still alive: ${leftover.stdout}',
  );
}

Future<void> _cancelKillsProcessTree(
  DesktopProcessRuntime runtime,
  Directory cwd,
) async {
  const marker = '40.513579';
  final request = _req(
    runId: 'cancel-tree',
    command: "sh -c 'sleep $marker & wait'",
    cwd: cwd.path,
    timeout: const Duration(seconds: 20),
  );
  final events = <CommandEvent>[];
  final done = Completer<void>();
  runtime.run(request).listen(events.add, onDone: done.complete);

  await _waitFor<CommandStarted>(events);
  await Future<void>.delayed(const Duration(seconds: 1));
  final watch = Stopwatch()..start();
  await runtime.cancel(request.runId);
  await done.future.timeout(const Duration(seconds: 5));
  watch.stop();
  expect(
    watch.elapsed,
    lessThan(const Duration(seconds: 5)),
    reason: 'cancel stream should complete promptly, elapsed ${watch.elapsed}',
  );
  final exit = _singleExit(events);
  expect(exit.cancelled, isTrue);
  expect(exit.timedOut, isFalse);
  await Future<void>.delayed(const Duration(milliseconds: 250));
  final leftover = await Process.run('pgrep', ['-f', '[s]leep $marker']);
  expect(
    leftover.exitCode,
    isNot(0),
    reason: 'sleep $marker still alive after cancel: ${leftover.stdout}',
  );
}

Future<void> _largeOutputOffload(
  DesktopProcessRuntime runtime,
  Directory cwd,
  Directory outputsDir,
) async {
  const n = 200000;
  final stdoutBuf = BoundedStreamBuffer();
  final fullStdout = BytesBuilder(copy: false);
  var stdoutBytes = 0;
  CommandExited? exit;
  await for (final event
      in runtime
          .run(
            _req(
              runId: 'seq-large',
              command: 'seq 1 $n',
              cwd: cwd.path,
              timeout: const Duration(seconds: 45),
            ),
          )
          .timeout(const Duration(seconds: 50))) {
    switch (event) {
      case CommandStarted():
        break;
      case CommandOutput(:final kind, :final bytes):
        if (kind == OutputStreamKind.stdout) {
          stdoutBytes += bytes.length;
          stdoutBuf.add(bytes);
          fullStdout.add(bytes);
        }
      case CommandExited():
        exit = event;
    }
  }
  expect(exit, isNotNull);
  expect(exit!.exitCode, 0);
  expect(stdoutBytes, _seqStdoutBytes(n));
  expect(stdoutBuf.truncated, isTrue);

  final offload = await ToolOutputOffloader.maybeOffload(
    toolCallId: 'seq-large',
    stdout: utf8.decode(fullStdout.takeBytes()),
    stderr: '',
    outputsDir: outputsDir,
  );
  expect(offload.offloadHostPath, isNotNull);
  final file = File(offload.offloadHostPath!);
  expect(file.existsSync(), isTrue);
  final preview = await file.readAsString();
  expect(preview, contains('=== stdout ==='));
  expect(preview, contains('200000'));
  expect(offload.modelText, contains('truncated'));
  expect(offload.modelText, contains('output_file'));
}

Future<void> _toolsEndToEnd({
  required DesktopProcessRuntime runtime,
  required Directory hostRoot,
  required Directory sessionDir,
  required Directory skillsDir,
  required Directory outputsDir,
}) async {
  final status = await runtime.status();
  final paths = WorkspacePaths.native(
    workspaceHostRoot: hostRoot.path,
    sessionHostDir: sessionDir.path,
    skillsHostDir: skillsDir.path,
  );
  final ctx = WorkspaceToolContext(
    workspace: Workspace(
      id: 'ws-macos',
      name: 'macOS verify',
      kind: WorkspaceKind.managed,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
    binding: const WorkspaceBinding(workspaceId: 'ws-macos', allowAll: true),
    paths: paths,
    sessionDir: sessionDir,
    outputsDir: outputsDir,
    conversationId: 'conv-macos',
    runtimeStatus: status,
    runtimeRegistered: true,
  );
  final provider = WorkspaceRuntimeProvider()..register(runtime);
  final tools = WorkspaceToolsService(runtimeProvider: provider);
  final note = p.join(hostRoot.path, 'note.txt');

  final written = _jsonOf(
    await tools.handle(ctx, 'write_file', {
      'path': note,
      'content': 'hello world\n中文 needle\n',
    }, toolCallId: 'write-note'),
  );
  expect(written['ok'], isTrue);
  expect(File(note).readAsStringSync(), contains('hello world'));

  final read = _client(
    await tools.handle(ctx, 'read_file', {
      'path': note,
    }, toolCallId: 'read-note'),
  );
  expect(read.content, contains('hello world'));
  expect(read.content, contains('中文 needle'));

  final exact = await tools.handle(ctx, 'edit_file', {
    'path': note,
    'old_string': 'hello world',
    'new_string': 'howdy world',
  }, toolCallId: 'edit-exact');
  final exactBody = _jsonOf(exact);
  expect(exactBody['ok'], isTrue);
  expect(exactBody['strategy'], 'exact');
  expect(exactBody['added'], isNotNull);
  expect(exactBody['removed'], isNotNull);
  final exactMeta = _metaOf(exact);
  expect(exactMeta['diff'], isNotNull);
  expect(exactMeta['diff'].toString(), contains('+'));
  expect(exactMeta['diff'].toString(), contains('-'));
  expect(exactMeta['added'], exactBody['added']);
  expect(exactMeta['removed'], exactBody['removed']);
  expect(File(note).readAsStringSync(), contains('howdy world'));

  final indent = p.join(hostRoot.path, 'indent.txt');
  await tools.handle(ctx, 'write_file', {
    'path': indent,
    'content': 'void main() {\n    foo();\n    bar();\n}\n',
  }, toolCallId: 'write-indent');
  final trimmed = await tools.handle(ctx, 'edit_file', {
    'path': indent,
    'old_string': '  foo();\n  bar();',
    'new_string': '  foo();\n  baz();',
  }, toolCallId: 'edit-trim');
  final trimmedBody = _jsonOf(trimmed);
  expect(trimmedBody['ok'], isTrue);
  expect(trimmedBody['strategy'], 'line_trimmed');
  final trimmedMeta = _metaOf(trimmed);
  expect(trimmedMeta['diff'], isNotNull);
  expect(trimmedMeta['added'], isNotNull);
  expect(trimmedMeta['removed'], isNotNull);
  expect(File(indent).readAsStringSync(), contains('baz();'));

  final listing = _client(
    await tools.handle(ctx, 'list_dir', {
      'path': hostRoot.path,
    }, toolCallId: 'list-1'),
  ).content;
  expect(listing, contains('note.txt'));
  expect(listing, contains('indent.txt'));

  final glob = _client(
    await tools.handle(ctx, 'glob', {
      'pattern': '**/*.txt',
      'path': hostRoot.path,
    }, toolCallId: 'glob-1'),
  ).content;
  expect(glob, contains('note.txt'));
  expect(glob, contains('indent.txt'));

  final grep = _client(
    await tools.handle(ctx, 'grep', {
      'pattern': '中文',
      'path': hostRoot.path,
    }, toolCallId: 'grep-zh'),
  ).content;
  expect(grep, contains('中文'));
  expect(grep, contains('note.txt'));

  // A workspace under $TMPDIR makes a single `../outside.txt` land in the
  // writable tmp zone. Climb out of $TMPDIR (and use an absolute path) so the
  // native outside-write policy is actually exercised.
  final tmpLanding = ctx.paths.resolve('../outside.txt', cwd: ctx.cwd);
  final oneLevel = await tools.handle(ctx, 'write_file', {
    'path': '../outside.txt',
    'content': 'nope',
  }, toolCallId: 'write-outside-one');
  final oneLevelBody = _jsonOf(oneLevel);
  if (tmpLanding.zone == WorkspaceZone.tmp) {
    expect(oneLevelBody['ok'], isTrue);
    final leaked = File(tmpLanding.hostPath);
    if (leaked.existsSync()) leaked.deleteSync();
  } else {
    expect(
      oneLevelBody['error'],
      anyOf('path_error', 'path_outside', 'approval_denied'),
    );
  }

  final climb = p.relative(
    p.join(Directory.current.path, 'kelivo_macos_outside.txt'),
    from: hostRoot.path,
  );
  expect(climb, contains('..'));
  addTearDown(() {
    final leaked = File(
      p.join(Directory.current.path, 'kelivo_macos_outside.txt'),
    );
    if (leaked.existsSync()) leaked.deleteSync();
  });
  final escaped = _jsonOf(
    await tools.handle(ctx, 'write_file', {
      'path': climb,
      'content': 'nope',
    }, toolCallId: 'write-outside-climb'),
  );
  expect(
    escaped['error'],
    anyOf('path_error', 'path_outside', 'approval_denied'),
  );
  expect(
    File(
      p.join(Directory.current.path, 'kelivo_macos_outside.txt'),
    ).existsSync(),
    isFalse,
  );

  final absOutside = p.join(Directory.current.path, 'kelivo_macos_abs.txt');
  addTearDown(() {
    final leaked = File(absOutside);
    if (leaked.existsSync()) leaked.deleteSync();
  });
  final absDenied = _jsonOf(
    await tools.handle(ctx, 'write_file', {
      'path': absOutside,
      'content': 'nope',
    }, toolCallId: 'write-outside-abs'),
  );
  expect(absDenied['error'], 'approval_denied');
  expect(File(absOutside).existsSync(), isFalse);

  final deniedCtx = WorkspaceToolContext(
    workspace: ctx.workspace,
    binding: const WorkspaceBinding(workspaceId: 'ws-macos'),
    paths: ctx.paths,
    sessionDir: ctx.sessionDir,
    outputsDir: ctx.outputsDir,
    conversationId: ctx.conversationId,
    runtimeStatus: ctx.runtimeStatus,
    runtimeRegistered: true,
  );
  final needsApproval = _jsonOf(
    await tools.handle(deniedCtx, 'shell', {
      'command': 'printf ok',
    }, toolCallId: 'shell-deny'),
  );
  expect(needsApproval['error'], 'approval_denied');

  final allowed = _jsonOf(
    await tools.handle(ctx, 'shell', {
      'command': 'printf allow-all-ok',
    }, toolCallId: 'shell-allow'),
  );
  expect(allowed['stdout'], contains('allow-all-ok'));
  expect(allowed['exit_code'], 0);
}

void _systemTerminalFlags(DesktopProcessRuntime runtime) {
  expect(runtime.supportsSystemTerminal, isTrue);
  expect(runtime.supportsPty, isFalse);
}

CommandRequest _req({
  required String runId,
  required String command,
  required String cwd,
  Duration timeout = const Duration(seconds: 8),
  Map<String, String> env = const <String, String>{},
}) {
  return CommandRequest(
    runId: runId,
    command: command,
    cwd: cwd,
    timeout: timeout,
    env: env,
  );
}

Future<List<CommandEvent>> _collect(
  DesktopProcessRuntime runtime,
  CommandRequest request, {
  Duration limit = const Duration(seconds: 12),
}) {
  return runtime.run(request).toList().timeout(limit);
}

Uint8List _stdout(List<CommandEvent> events) =>
    _concat(events, OutputStreamKind.stdout);

Uint8List _stderr(List<CommandEvent> events) =>
    _concat(events, OutputStreamKind.stderr);

Uint8List _concat(List<CommandEvent> events, OutputStreamKind kind) {
  final builder = BytesBuilder(copy: false);
  for (final event in events.whereType<CommandOutput>()) {
    if (event.kind == kind) builder.add(event.bytes);
  }
  return builder.takeBytes();
}

CommandExited _singleExit(List<CommandEvent> events) {
  final exits = events.whereType<CommandExited>().toList();
  expect(exits, hasLength(1), reason: 'expected exactly one CommandExited');
  return exits.single;
}

int _seqStdoutBytes(int n) {
  var bytes = 0;
  for (var i = 1; i <= n; i++) {
    bytes += i.toString().length + 1;
  }
  return bytes;
}

Future<T> _waitFor<T extends CommandEvent>(List<CommandEvent> events) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(deadline)) {
    final match = events.whereType<T>();
    if (match.isNotEmpty) return match.first;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('did not observe $T in time');
}

ClientToolResult _client(Object? raw) => ClientToolResult.fromHandler(raw);

Map<String, dynamic> _jsonOf(Object? raw) {
  final decoded = jsonDecode(_client(raw).content);
  return Map<String, dynamic>.from(decoded as Map);
}

Map<String, dynamic> _metaOf(Object? raw) {
  final meta = _client(raw).metadata;
  expect(meta, isNotNull);
  final workspace = meta!['workspace'];
  expect(workspace, isA<Map>());
  return Map<String, dynamic>.from(workspace as Map);
}
