import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/environment_variable.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/services/workspace/file_link_resolver.dart';
import 'package:Kelivo/core/services/workspace/tool_run_registry.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

import '../../../support/fake_workspace_runtime.dart';

class _RecordingApproval extends ToolApprovalService {
  int calls = 0;
  String? lastName;
  bool allow = true;
  String denyReason = 'nope';

  @override
  Future<ToolApprovalResult> requestApproval({
    required String toolCallId,
    required String toolName,
    required Map<String, dynamic> arguments,
    String? conversationId,
  }) async {
    calls++;
    lastName = toolName;
    if (allow) return ToolApprovalResult.approved();
    return ToolApprovalResult.denied(denyReason);
  }
}

class _SandboxedRuntime extends FakeWorkspaceRuntime {
  @override
  Future<RuntimeStatus> status() async {
    return const RuntimeStatus(ready: true, engine: 'fake', sandboxed: true);
  }
}

class _InterruptedWriter extends FakeWorkspaceRuntime {
  _InterruptedWriter(this.throwError);
  final bool throwError;
  @override
  Stream<CommandEvent> run(CommandRequest request) async* {
    yield const CommandStarted();
    File(p.join(request.cwd, 'partial.txt')).writeAsStringSync('saved');
    if (throwError) throw StateError('stream interrupted');
  }
}

void main() {
  final canRunReal = Platform.isMacOS || Platform.isLinux;

  late Directory tmp;
  late Directory workspaceDir;
  late Directory sessionDir;
  late Directory skillsDir;
  late Map<String, Map<String, dynamic>> extrasById;
  late List<String> touched;
  late ToolRunRegistry registry;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kelivo_ws_tools_');
    workspaceDir = Directory(p.join(tmp.path, 'ws'))..createSync();
    sessionDir = Directory(p.join(tmp.path, 'session'))..createSync();
    Directory(p.join(sessionDir.path, 'attachments')).createSync();
    Directory(p.join(sessionDir.path, 'outputs')).createSync();
    skillsDir = Directory(p.join(tmp.path, 'skills'))..createSync();
    extrasById = <String, Map<String, dynamic>>{};
    touched = <String>[];
    registry = ToolRunRegistry();
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Workspace workspace({bool shellNeedsApproval = false}) {
    return Workspace(
      id: 'ws1',
      name: 'Test',
      kind: WorkspaceKind.managed,
      shellNeedsApproval: shellNeedsApproval,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  WorkspaceToolContext ctx({
    bool sandboxed = false,
    bool allowAll = true,
    bool toolsUsed = false,
    bool shellNeedsApproval = false,
    RuntimeStatus? status,
    bool runtimeRegistered = true,
    Set<String> disabledTools = const {},
    List<Mount> externalMounts = const [],
    Future<List<Mount>> Function()? loadExternalMounts,
  }) {
    final paths = sandboxed
        ? WorkspacePaths.sandboxed(
            externalMounts: externalMounts,
            loadExternalMounts: loadExternalMounts,
            workspaceHostRoot: workspaceDir.path,
            sessionHostDir: sessionDir.path,
            skillsHostDir: skillsDir.path,
          )
        : WorkspacePaths.native(
            workspaceHostRoot: workspaceDir.path,
            sessionHostDir: sessionDir.path,
            skillsHostDir: skillsDir.path,
          );
    return WorkspaceToolContext(
      workspace: workspace(
        shellNeedsApproval: shellNeedsApproval,
      ).copyWith(disabledTools: disabledTools),
      binding: WorkspaceBinding(
        workspaceId: 'ws1',
        toolsUsed: toolsUsed,
        allowAll: allowAll,
      ),
      paths: paths,
      sessionDir: sessionDir,
      outputsDir: Directory(p.join(sessionDir.path, 'outputs')),
      conversationId: 'conv-1',
      runtimeStatus:
          status ??
          RuntimeStatus(ready: true, engine: 'fake', sandboxed: sandboxed),
      runtimeRegistered: runtimeRegistered,
    );
  }

  WorkspaceToolsService service({
    WorkspaceRuntime? runtime,
    bool registerRuntime = true,
    Future<void> Function()? onShellCompleted,
    Future<EnvironmentExecutionConfig> Function()? loadEnvironment,
  }) {
    final provider = WorkspaceRuntimeProvider();
    if (registerRuntime && runtime != null) {
      provider.register(runtime);
    }
    return WorkspaceToolsService(
      registry: registry,
      runtimeProvider: provider,
      onShellCompleted: onShellCompleted,
      loadEnvironment: loadEnvironment,
      updateConversationExtras: (id, update) async {
        extrasById[id] = update(extrasById[id] ?? <String, dynamic>{});
      },
      touchLastUsed: (id) async => touched.add(id),
    );
  }

  ClientToolResult client(Object? raw) => ClientToolResult.fromHandler(raw);

  Map<String, dynamic> jsonOf(Object? raw) {
    final decoded = jsonDecode(client(raw).content);
    return Map<String, dynamic>.from(decoded as Map);
  }

  WorkspaceToolMetadata metaOf(Object? raw) {
    return WorkspaceToolMetadata.fromJson(client(raw).metadata!);
  }

  test(
    'environment injection uses raw values but shell and file results are private',
    () async {
      const secret = 'test-token-秘密-123';
      var config = EnvironmentExecutionConfig(variables: {'TOKEN': secret});
      final runtime = FakeWorkspaceRuntime(useRealProcess: true);
      final tools = service(
        runtime: runtime,
        loadEnvironment: () async => config,
      );
      final context = ctx();
      final raw = await tools.handle(context, 'shell', {
        'command':
            r'printf "%s" "$TOKEN"; printf "%s" "$TOKEN" >&2; printf "%s" "$TOKEN" > secret.txt; exit 1',
      }, toolCallId: 'env-shell');
      expect(runtime.requests.single.env['TOKEN'], secret);
      expect(runtime.requests.single.env['NO_COLOR'], '1');
      expect(client(raw).content, isNot(contains(secret)));
      expect(jsonOf(raw)['exit_code'], 1);
      expect(metaOf(raw).stdoutPreview, secret);
      expect(metaOf(raw).stderrPreview, secret);
      final read = await tools.handle(context, 'read_file', {
        'path': 'secret.txt',
      }, toolCallId: 'env-read');
      expect(client(read).content, contains('[REDACTED]'));
      expect(client(read).content, isNot(contains(secret)));
      expect(metaOf(read).stdoutPreview, contains(secret));
      config = EnvironmentExecutionConfig(
        variables: {'TOKEN': secret},
        privacyMode: false,
      );
      final unmasked = await tools.handle(context, 'shell', {
        'command': r'printf "%s" "$TOKEN"',
      }, toolCallId: 'env-off');
      expect(client(unmasked).content, contains(secret));
      config = EnvironmentExecutionConfig();
      await tools.handle(context, 'shell', {
        'command': 'true',
      }, toolCallId: 'env-removed');
      expect(runtime.requests.last.env.containsKey('TOKEN'), isFalse);
    },
    skip: !canRunReal,
  );

  test(
    'execution and redaction share a snapshot when settings change mid-command',
    () async {
      var config = EnvironmentExecutionConfig(
        variables: {'TOKEN': 'old-secret'},
      );
      final tools = service(
        runtime: FakeWorkspaceRuntime(useRealProcess: true),
        loadEnvironment: () async => config,
        onShellCompleted: () async {
          config = EnvironmentExecutionConfig(
            variables: {'TOKEN': 'new-secret'},
          );
        },
      );
      final output = await tools.handle(ctx(), 'shell', {
        'command': r'printf "%s" "$TOKEN"',
      }, toolCallId: 'snapshot');
      expect(client(output).content, isNot(contains('old-secret')));
      expect(metaOf(output).stdoutPreview, 'old-secret');
    },
    skip: !canRunReal,
  );

  test(
    'offloaded command output is redacted when the model reads it later',
    () async {
      const secret = 'long-output-secret-token';
      final stdout = List.filled(1600, '$secret\n').join();
      final runtime = FakeWorkspaceRuntime();
      runtime.enqueue('private-offload', [
        CommandOutput(
          OutputStreamKind.stdout,
          Uint8List.fromList(utf8.encode(stdout)),
        ),
        const CommandExited(
          exitCode: 0,
          timedOut: false,
          cancelled: false,
          interrupted: false,
          duration: Duration.zero,
        ),
      ]);
      final tools = service(
        runtime: runtime,
        loadEnvironment: () async =>
            EnvironmentExecutionConfig(variables: {'TOKEN': secret}),
      );
      final context = ctx();
      final result = await tools.handle(context, 'shell', {
        'command': 'produce-output',
      }, toolCallId: 'private-offload');
      final outputPath = jsonOf(result)['output_file'] as String;
      expect(client(result).content, isNot(contains(secret)));
      expect(await File(outputPath).readAsString(), contains(secret));
      final read = await tools.handle(context, 'read_file', {
        'path': outputPath,
        'limit': 10,
      }, toolCallId: 'read-private-offload');
      expect(client(read).content, contains('[REDACTED]'));
      expect(client(read).content, isNot(contains(secret)));
      expect(metaOf(read).stdoutPreview, contains(secret));
    },
  );

  test('workspace prompt lists names without including values', () {
    final prompt = WorkspaceToolsService.buildPromptFragment(
      ctx(),
      environmentVariableNames: ['API_KEY', 'BASE_URL'],
    );
    expect(prompt, contains('API_KEY, BASE_URL'));
    expect(prompt, contains(r'Use $NAME references'));
  });

  test('post-command refresh runs for every execution outcome', () async {
    final runtime = FakeWorkspaceRuntime();
    var refreshes = 0;
    final tools = service(
      runtime: runtime,
      onShellCompleted: () async {
        refreshes++;
      },
    );
    for (final status in [
      'ok',
      'failed',
      'cancelled',
      'timed_out',
      'no_exit',
    ]) {
      runtime.enqueue(status, [
        const CommandStarted(pid: 0),
        if (status != 'no_exit')
          CommandExited(
            exitCode: status == 'ok' ? 0 : 1,
            timedOut: status == 'timed_out',
            cancelled: status == 'cancelled',
            interrupted: false,
            duration: Duration.zero,
          ),
      ]);
      await tools.handle(ctx(), 'shell', {
        'command': 'install',
      }, toolCallId: status);
    }
    expect(refreshes, 5);
    await tools.handle(ctx(), 'read_file', {
      'path': 'missing',
    }, toolCallId: 'read');
    await tools.handle(ctx(), 'shell', {}, toolCallId: 'invalid');
    await tools.handle(ctx(disabledTools: {'shell'}), 'shell', {
      'command': 'install',
    }, toolCallId: 'disabled');
    await tools.handle(
      ctx(allowAll: false, shellNeedsApproval: true),
      'shell',
      {'command': 'install'},
      toolCallId: 'denied',
      approvalService: _RecordingApproval()..allow = false,
    );
    expect(refreshes, 5);
  });

  test('refresh failures do not change a successful command result', () async {
    final tools = service(
      runtime: FakeWorkspaceRuntime(),
      onShellCompleted: () async {
        throw const FileSystemException('unavailable');
      },
    );
    final result = await tools.handle(ctx(), 'shell', {
      'command': 'echo done',
    }, toolCallId: 'refresh-fails');
    expect(metaOf(result).status, 'ok');
    expect(jsonOf(result)['exit_code'], 0);
  });

  test(
    'disabled tools are omitted and rejected before any side effects',
    () async {
      final tools = service(
        runtime: FakeWorkspaceRuntime(useRealProcess: true),
      );
      final context = ctx(disabledTools: WorkspaceToolsService.toolNames);
      expect(tools.buildToolDefinitions(context), isEmpty);
      final approval = _RecordingApproval();
      final target = File(p.join(workspaceDir.path, 'untouched.txt'));
      await target.writeAsString('original');
      for (final name in WorkspaceToolsService.toolNames) {
        final result = await tools.handle(
          context,
          name,
          {
            'path': target.path,
            'command': 'exit 0',
            'content': 'changed',
            'old_string': 'original',
            'new_string': 'changed',
            'pattern': '*',
          },
          toolCallId: 'disabled-$name',
          approvalService: approval,
        );
        expect(jsonOf(result)['error'], 'tool_disabled', reason: name);
      }
      expect(await target.readAsString(), 'original');
      expect(approval.calls, 0);
      expect(extrasById, isEmpty);
      expect(touched, isEmpty);
      expect(
        WorkspaceToolsService.buildPromptFragment(context),
        isNot(contains('shell is one-shot')),
      );
    },
  );

  test(
    'execution rechecks current switches after definitions were built',
    () async {
      var enabled = true;
      final tools = WorkspaceToolsService(isToolEnabled: (_, _) => enabled);
      final context = ctx();
      expect(tools.buildToolDefinitions(context), hasLength(7));
      enabled = false;
      expect(
        jsonOf(
          await tools.handle(
            context,
            'list_dir',
            {},
            toolCallId: 'disabled-later',
          ),
        )['error'],
        'tool_disabled',
      );
      enabled = true;
      expect(
        metaOf(
          await tools.handle(
            context,
            'list_dir',
            {},
            toolCallId: 'enabled-again',
          ),
        ).status,
        'ok',
      );
    },
  );

  group('shell', () {
    test(
      'happy path prints stdout and exit 0',
      skip: canRunReal ? false : 'needs /bin/sh',
      () async {
        final tools = service(
          runtime: FakeWorkspaceRuntime(useRealProcess: true),
        );
        final result = await tools.handle(ctx(), 'shell', {
          'command': r"printf 'a\nb'",
        }, toolCallId: 'run-printf');
        final payload = jsonOf(result);
        expect(payload['stdout'], contains('a'));
        expect(payload['stdout'], contains('b'));
        expect(payload['exit_code'], 0);
        expect(payload['timed_out'], isFalse);
        expect(metaOf(result).status, 'ok');
      },
    );

    test(
      'non-zero exit code is reported',
      skip: canRunReal ? false : 'needs /bin/sh',
      () async {
        final tools = service(
          runtime: FakeWorkspaceRuntime(useRealProcess: true),
        );
        final payload = jsonOf(
          await tools.handle(ctx(), 'shell', {
            'command': 'exit 7',
          }, toolCallId: 'run-exit'),
        );
        expect(payload['exit_code'], 7);
      },
    );

    test(
      'timeout_seconds: 1 kills sleep 5',
      skip: canRunReal ? false : 'needs /bin/sh',
      () async {
        final tools = service(
          runtime: FakeWorkspaceRuntime(useRealProcess: true),
        );
        final result = await tools.handle(ctx(), 'shell', {
          'command': 'sleep 5',
          'timeout_seconds': 1,
        }, toolCallId: 'run-sleep');
        expect(jsonOf(result)['timed_out'], isTrue);
        expect(metaOf(result).status, 'timeout');
      },
    );

    test(
      'large output is offloaded',
      skip: canRunReal ? false : 'needs /bin/sh',
      () async {
        final tools = service(
          runtime: FakeWorkspaceRuntime(useRealProcess: true),
        );
        final result = await tools.handle(ctx(), 'shell', {
          'command': 'seq 1 20000',
        }, toolCallId: 'run-seq');
        final payload = jsonOf(result);
        expect(payload['truncated'], isTrue);
        expect(payload['output_file'], isNotNull);
        final offload = File(p.join(sessionDir.path, 'outputs', 'run-seq.txt'));
        expect(offload.existsSync(), isTrue);
        expect(
          metaOf(result).files
              .where((file) => file.role == WorkspaceFileRole.log)
              .single
              .link,
          isNotNull,
        );
      },
    );

    test(
      'changed_files lists the model path of a new workspace file',
      skip: canRunReal ? false : 'needs /bin/sh',
      () async {
        final tools = service(
          runtime: FakeWorkspaceRuntime(useRealProcess: true),
        );
        final context = ctx();
        final result = await tools.handle(context, 'shell', {
          'command': 'echo hi > new.txt',
        }, toolCallId: 'run-write');
        final payload = jsonOf(result);
        final changed = (payload['changed_files'] as List?)?.cast<String>();
        expect(changed, isNotNull);
        expect(changed, anyElement(contains('new.txt')));
        expect(File(p.join(workspaceDir.path, 'new.txt')).existsSync(), isTrue);
      },
    );

    test('environment_not_ready when runtime is null', () async {
      final tools = service(registerRuntime: false);
      final result = await tools.handle(
        ctx(runtimeRegistered: false, status: null),
        'shell',
        {'command': 'echo hi'},
        toolCallId: 'run-none',
      );
      final payload = jsonOf(result);
      expect(payload['error'], 'environment_not_ready');
      expect(payload['instruction'], contains('Settings → Workspace'));
      expect(metaOf(result).status, 'error');
      expect(metaOf(result).code, 'environment_not_ready');
    });
  });

  group('file tools', () {
    test(
      'external mounts appear in prompt and readonly beats allow-all',
      () async {
        final dir = Directory(p.join(tmp.path, 'external'))..createSync();
        final file = File(p.join(dir.path, 'note.txt'))
          ..writeAsStringSync('original');
        const guest = '/mounts/Notes';
        final context = ctx(
          sandboxed: true,
          externalMounts: [Mount(host: dir.path, guest: guest, readOnly: true)],
        );
        final prompt = WorkspaceToolsService.buildPromptFragment(context);
        expect(prompt, contains('/mounts/<name>/'));
        expect(
          prompt,
          contains('File tools reject writes to read-only mounts'),
        );
        expect(prompt, isNot(contains('<external_mounts>')));
        expect(prompt, contains('Read-only: $guest.'));
        expect(prompt, contains('respect this in Shell too'));
        final approval = _RecordingApproval();
        final result = await service().handle(
          context,
          'write_file',
          {'path': '$guest/note.txt', 'content': 'bad'},
          toolCallId: 'mount-write',
          approvalService: approval,
        );
        expect(metaOf(result).code, 'mount_readonly');
        expect(approval.calls, 0);
        expect(file.readAsStringSync(), 'original');
      },
    );

    test(
      'mount permission is rechecked before the actual file write',
      () async {
        final dir = Directory(p.join(tmp.path, 'external'))..createSync();
        final file = File(p.join(dir.path, 'note.txt'))
          ..writeAsStringSync('original');
        const guest = '/mounts/Notes';
        var resolves = 0;
        List<Mount> current() => [
          Mount(host: dir.path, guest: guest, readOnly: resolves > 1),
        ];
        final context = ctx(
          sandboxed: true,
          externalMounts: current(),
          loadExternalMounts: () async {
            resolves++;
            return current();
          },
        );
        final approval = _RecordingApproval();
        final result = await service().handle(
          context,
          'write_file',
          {'path': '$guest/note.txt', 'content': 'bad'},
          toolCallId: 'mount-write',
          approvalService: approval,
        );
        expect(approval.calls, 0);
        expect(metaOf(result).status, 'error');
        expect(file.readAsStringSync(), 'original');
      },
    );

    test('read_file numbers text and reports next offset', () async {
      File(p.join(workspaceDir.path, 'n.txt')).writeAsStringSync('a\nb\nc\n');
      final tools = service();
      final result = await tools.handle(ctx(), 'read_file', {
        'path': p.join(workspaceDir.path, 'n.txt'),
        'offset': 2,
        'limit': 1,
      }, toolCallId: 'read-1');
      final text = client(result).content;
      expect(text, contains('     2|b'));
      expect(text, contains('(more lines: use offset=3)'));
    });

    test('read_file binary returns hex preview', () async {
      File(
        p.join(workspaceDir.path, 'blob.bin'),
      ).writeAsBytesSync(Uint8List.fromList([0x00, 0x01, 0xFF]));
      final payload = jsonOf(
        await service().handle(ctx(), 'read_file', {
          'path': p.join(workspaceDir.path, 'blob.bin'),
        }, toolCallId: 'read-bin'),
      );
      expect(payload['binary'], isTrue);
      expect(payload['hex_preview'], contains('00'));
    });

    test('read_file image returns a structured image result', () async {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);
      File(p.join(workspaceDir.path, 'pic.png')).writeAsBytesSync(png);
      final result = client(
        await service().handle(ctx(), 'read_file', {
          'path': p.join(workspaceDir.path, 'pic.png'),
        }, toolCallId: 'read-img'),
      );
      expect(result.content, contains('![]('));
      expect(result.metadata, contains(kMcpResultMetadataKey));
    });

    test('write_file and edit_file content shapes', () async {
      final tools = service();
      final native = ctx();
      final target = p.join(workspaceDir.path, 'note.txt');
      final written = jsonOf(
        await tools.handle(native, 'write_file', {
          'path': target,
          'content': 'hello world',
        }, toolCallId: 'write-1'),
      );
      expect(written['ok'], isTrue);
      expect(written['bytes'], greaterThan(0));
      expect(written['created'], isTrue);
      expect(written['path'], endsWith('note.txt'));
      expect(written.containsKey('diff'), isFalse);

      final edited = await tools.handle(native, 'edit_file', {
        'path': target,
        'old_string': 'hello',
        'new_string': 'howdy',
      }, toolCallId: 'edit-1');
      final body = jsonOf(edited);
      expect(body['ok'], isTrue);
      expect(body['replacements'], 1);
      expect(body['strategy'], isNotEmpty);
      expect(body.containsKey('diff'), isFalse);
      expect(body['added'], isNotNull);
      expect(body['removed'], isNotNull);
      expect(metaOf(edited).diff, isNotNull);
      expect(File(target).readAsStringSync(), contains('howdy'));
    });

    test('edit failure message is passed through', () async {
      File(p.join(workspaceDir.path, 'x.txt')).writeAsStringSync('abc');
      final result = await service().handle(ctx(), 'edit_file', {
        'path': p.join(workspaceDir.path, 'x.txt'),
        'old_string': 'zzz',
        'new_string': 'yyy',
      }, toolCallId: 'edit-fail');
      final body = jsonOf(result);
      expect(body['error'], 'edit_failed');
      expect(body['message'], contains('old_string'));
    });

    test('list_dir / glob / grep listings', () async {
      Directory(p.join(workspaceDir.path, 'sub')).createSync();
      File(
        p.join(workspaceDir.path, 'sub', 'a.txt'),
      ).writeAsStringSync('needle');
      File(p.join(workspaceDir.path, 'b.md')).writeAsStringSync('hi');
      final tools = service();
      final native = ctx();

      final listing = client(
        await tools.handle(native, 'list_dir', {
          'path': workspaceDir.path,
        }, toolCallId: 'list-1'),
      ).content;
      expect(listing, contains('sub/'));
      expect(listing, contains('b.md'));

      final glob = client(
        await tools.handle(native, 'glob', {
          'pattern': '**/*.txt',
          'path': workspaceDir.path,
        }, toolCallId: 'glob-1'),
      ).content;
      expect(glob, contains('a.txt'));

      final grep = client(
        await tools.handle(native, 'grep', {
          'pattern': 'needle',
          'path': workspaceDir.path,
        }, toolCallId: 'grep-1'),
      ).content;
      expect(grep, contains('needle'));
    });

    test('skills write is denied', () async {
      final skillFile = p.join(skillsDir.path, 's1', 'SKILL.md');
      Directory(p.dirname(skillFile)).createSync(recursive: true);
      File(skillFile).writeAsStringSync('old');
      final result = await service().handle(
        ctx(sandboxed: true, allowAll: true),
        'write_file',
        {'path': '/skills/s1/SKILL.md', 'content': 'new'},
        toolCallId: 'skill-write',
      );
      expect(jsonOf(result)['error'], 'skills_readonly');
      expect(metaOf(result).status, 'denied');
      expect(File(skillFile).readAsStringSync(), 'old');
    });
  });

  group('approval', () {
    test('shell asks when shellNeedsApproval', () async {
      final approval = _RecordingApproval();
      final runtime = _SandboxedRuntime();
      final tools = service(runtime: runtime);
      await tools.handle(
        ctx(sandboxed: true, allowAll: false, shellNeedsApproval: true),
        'shell',
        {'command': 'printf ok'},
        toolCallId: 'appr-1',
        approvalService: approval,
      );
      expect(approval.calls, 1);
      expect(approval.lastName, 'shell');
    });

    test('shell skips approval when allowAll', () async {
      final approval = _RecordingApproval();
      final runtime = _SandboxedRuntime();
      final tools = service(runtime: runtime);
      await tools.handle(
        ctx(sandboxed: true, allowAll: true, shellNeedsApproval: true),
        'shell',
        {'command': 'printf ok'},
        toolCallId: 'appr-2',
        approvalService: approval,
      );
      expect(approval.calls, 0);
    });

    test(
      'native shell forces approval even without shellNeedsApproval',
      () async {
        final approval = _RecordingApproval();
        final tools = service(
          runtime: FakeWorkspaceRuntime(useRealProcess: canRunReal),
        );
        await tools.handle(
          ctx(sandboxed: false, allowAll: false, shellNeedsApproval: false),
          'shell',
          {'command': 'printf ok'},
          toolCallId: 'appr-3',
          approvalService: approval,
        );
        expect(approval.calls, 1);
      },
    );

    test(
      'native outside write forces approval regardless of allowAll',
      () async {
        final approval = _RecordingApproval()..allow = false;
        final outside = p.join(
          Directory.current.path,
          'kelivo_ws_outside_test.txt',
        );
        addTearDown(() {
          final file = File(outside);
          if (file.existsSync()) file.deleteSync();
        });
        final result = await service().handle(
          ctx(allowAll: true),
          'write_file',
          {'path': outside, 'content': 'nope'},
          toolCallId: 'appr-out',
          approvalService: approval,
        );
        expect(approval.calls, 1);
        expect(jsonOf(result)['error'], 'approval_denied');
        expect(jsonOf(result)['message'], 'nope');
        expect(File(outside).existsSync(), isFalse);
      },
    );
  });

  test(
    'file tools return the same reference and only mutations are produced',
    () async {
      final tools = service();
      final context = ctx(sandboxed: true);
      final fileName = Platform.isWindows ? 'report 报告.txt' : 'report:报告.txt';
      final path = '/workspace/$fileName';
      final write = metaOf(
        await tools.handle(context, 'write_file', {
          'path': path,
          'content': 'needle\nneedle',
        }, toolCallId: 'w'),
      );
      final read = metaOf(
        await tools.handle(context, 'read_file', {
          'path': path,
        }, toolCallId: 'r'),
      );
      final glob = metaOf(
        await tools.handle(context, 'glob', {
          'pattern': '*.txt',
        }, toolCallId: 'g'),
      );
      final grep = metaOf(
        await tools.handle(context, 'grep', {
          'pattern': 'needle',
        }, toolCallId: 's'),
      );
      final edit = metaOf(
        await tools.handle(context, 'edit_file', {
          'path': path,
          'old_string': 'needle',
          'new_string': 'updated',
          'replace_all': true,
        }, toolCallId: 'e'),
      );
      expect(
        write.files.single.link,
        Platform.isWindows
            ? 'kelivo://workspace/report%20%E6%8A%A5%E5%91%8A.txt'
            : 'kelivo://workspace/report%3A%E6%8A%A5%E5%91%8A.txt',
      );
      expect(
        KelivoLink.tryParse(write.files.single.link!)?.relativePath,
        fileName,
      );
      for (final result in [read, glob, grep, edit]) {
        expect(result.files.single.link, write.files.single.link);
        expect(result.files.single.path, path);
      }
      expect(grep.count, 2);
      expect(
        [
          read,
          glob,
          grep,
        ].expand((meta) => meta.files).any((f) => f.isProduced),
        isFalse,
      );
      expect(write.files.single.role, WorkspaceFileRole.created);
      expect(edit.files.single.role, WorkspaceFileRole.modified);
      final noop = metaOf(
        await tools.handle(context, 'edit_file', {
          'path': path,
          'old_string': 'updated',
          'new_string': 'updated',
          'replace_all': true,
        }, toolCallId: 'noop'),
      );
      expect(noop.files.single.isProduced, isFalse);
      final missing = metaOf(
        await tools.handle(context, 'read_file', {
          'path': '/workspace/missing',
        }, toolCallId: 'missing'),
      );
      expect(missing.files, isEmpty);
    },
  );

  test(
    'directory, session and external results carry usable identities',
    () async {
      final external = Directory(p.join(tmp.path, 'external'))..createSync();
      final context = ctx(
        sandboxed: true,
        externalMounts: [
          Mount(
            host: external.path,
            guest: '/mounts/Data',
            externalId: 'mount-1',
          ),
        ],
      );
      final tools = service();
      for (final path in ['/mounts/Data/a.txt', '/chat/note.txt']) {
        final result = metaOf(
          await tools.handle(context, 'write_file', {
            'path': path,
            'content': 'ok',
          }, toolCallId: path),
        );
        expect(result.files.single.isProduced, isTrue);
        expect(
          result.files.single.link,
          path.startsWith('/mounts')
              ? 'kelivo://mounts/mount-1/a.txt'
              : 'kelivo://session/note.txt',
        );
      }
      final listing = metaOf(
        await tools.handle(context, 'list_dir', {
          'path': '/mounts/Data',
        }, toolCallId: 'list'),
      );
      expect(listing.files.first.isDirectory, isTrue);
      expect(listing.files.first.link, 'kelivo://mounts/mount-1');
      expect(listing.files.last.link, 'kelivo://mounts/mount-1/a.txt');
      final glob = metaOf(
        await tools.handle(context, 'glob', {
          'path': '/mounts/Data',
          'pattern': '*.txt',
        }, toolCallId: 'glob'),
      );
      expect(glob.files.single.link, listing.files.last.link);
    },
  );

  test(
    'shell retains changes after failure and scans only workspace and session',
    skip: canRunReal ? false : 'needs /bin/sh',
    () async {
      final existing = File(p.join(workspaceDir.path, 'existing.txt'))
        ..writeAsStringSync('old');
      existing.setLastModifiedSync(DateTime.utc(2000));
      final tools = service(
        runtime: FakeWorkspaceRuntime(useRealProcess: true),
      );
      final result = metaOf(
        await tools.handle(ctx(), 'shell', {
          'command':
              'printf new > existing.txt; printf new > result.csv; printf session > ../session/note.txt; printf outside > ../outside.txt; exit 1',
        }, toolCallId: 'failed-with-output'),
      );
      expect(result.exitCode, 1);
      expect(result.files.map((f) => p.basename(f.path)).toSet(), {
        'existing.txt',
        'result.csv',
        'note.txt',
      });
      expect(result.files.every((f) => f.link != null && f.isProduced), isTrue);
      expect(
        result.files
            .firstWhere((f) => p.basename(f.path) == 'existing.txt')
            .role,
        WorkspaceFileRole.modified,
      );
      expect(
        result.files.firstWhere((f) => p.basename(f.path) == 'note.txt').link,
        'kelivo://session/note.txt',
      );
      final noChanges = metaOf(
        await tools.handle(ctx(), 'shell', {
          'command': 'cat result.csv',
        }, toolCallId: 'read-only-shell'),
      );
      expect(noChanges.files, isEmpty);
    },
  );

  test('newline-only edits remain produced files', () async {
    final tools = service();
    final context = ctx(sandboxed: true);
    for (final pair in [('hello', 'hello\n'), ('hello\r\n', 'hello\n')]) {
      final file = File(p.join(workspaceDir.path, 'newlines.txt'));
      await file.writeAsString(pair.$1);
      final result = metaOf(
        await tools.handle(context, 'edit_file', {
          'path': '/workspace/newlines.txt',
          'old_string': pair.$1,
          'new_string': pair.$2,
        }, toolCallId: 'newline'),
      );
      expect(result.status, 'ok');
      expect(result.added, 0);
      expect(result.removed, 0);
      expect(await file.readAsString(), pair.$2);
      expect(result.files.single.isProduced, isTrue);
    }
  });

  test(
    'native skill reads report the skill ID without path separators',
    () async {
      final skillFile = File(p.join(skillsDir.path, 'skill-id', 'SKILL.md'));
      await skillFile.parent.create();
      await skillFile.writeAsString('Skill instructions');
      final readIds = <String>[];
      final tools = WorkspaceToolsService(
        onSkillRead: (id) async {
          readIds.add(id);
        },
      );
      final result = metaOf(
        await tools.handle(ctx(), 'read_file', {
          'path': skillFile.path,
        }, toolCallId: 'read-skill'),
      );
      expect(result.status, 'ok');
      expect(readIds, ['skill-id']);
    },
  );

  test('runtime failures still report files already written', () async {
    for (final throwError in [true, false]) {
      final result = metaOf(
        await service(runtime: _InterruptedWriter(throwError)).handle(
          ctx(),
          'shell',
          {'command': 'write'},
          toolCallId: 'partial-$throwError',
        ),
      );
      expect(result.status, 'error');
      expect(result.files.single.link, 'kelivo://workspace/partial.txt');
      expect(result.files.single.isProduced, isTrue);
      File(p.join(workspaceDir.path, 'partial.txt')).deleteSync();
    }
  });

  group('metadata', () {
    test('fromJson(toJson) round trip', () {
      final original = WorkspaceToolMetadata(
        tool: 'shell',
        status: 'ok',
        code: 'x',
        path: '/workspace/a.txt',
        command: 'echo hi',
        exitCode: 0,
        durationMs: 12,
        timedOut: false,
        cancelled: false,
        interrupted: false,
        stdoutPreview: 'out',
        stderrPreview: 'err',
        files: const [
          WorkspaceToolFile(
            path: '/workspace/a.txt',
            link: 'kelivo://workspace/a.txt',
            role: WorkspaceFileRole.modified,
          ),
          WorkspaceToolFile(
            path: '/chat/outputs/t.txt',
            link: 'kelivo://chat/outputs/t.txt',
            role: WorkspaceFileRole.log,
          ),
        ],
        filesTruncated: true,
        diff: '@@',
        added: 1,
        removed: 2,
        diffTruncated: false,
        strategy: 'exact',
        created: true,
        bytes: 4,
        count: 3,
        truncated: false,
      );
      final round = WorkspaceToolMetadata.fromJson(original.toJson());
      expect(round.toJson(), original.toJson());
    });

    test('preview fields are capped at 4 KB and keep the tail', () {
      final long = 'H' * 100 + 'T' * 5000;
      final meta = WorkspaceToolMetadata(
        tool: 'shell',
        status: 'ok',
        stdoutPreview: long,
        stderrPreview: long,
      );
      final json = meta.toJson();
      final workspace = json['workspace'] as Map<String, dynamic>;
      final stdout = workspace['stdoutPreview'] as String;
      final stderr = workspace['stderrPreview'] as String;
      expect(stdout.length, lessThanOrEqualTo(4096));
      expect(stderr.length, lessThanOrEqualTo(4096));
      expect(stdout.endsWith('T' * 20), isTrue);
      final round = WorkspaceToolMetadata.fromJson(json);
      expect(round.stdoutPreview!.length, lessThanOrEqualTo(4096));
    });
  });

  group('mark tools used on first success', () {
    test('writes toolsUsed: true through the extras updater', () async {
      File(p.join(workspaceDir.path, 'a.txt')).writeAsStringSync('hi');
      extrasById['conv-1'] = WorkspaceBinding(
        workspaceId: 'ws1',
        toolsUsed: false,
        allowAll: true,
      ).applyTo(<String, dynamic>{});
      await service().handle(
        ctx(toolsUsed: false, allowAll: true),
        'read_file',
        {'path': p.join(workspaceDir.path, 'a.txt')},
        toolCallId: 'lock-1',
        conversationId: 'conv-1',
      );
      final binding = WorkspaceBinding.fromExtras(extrasById['conv-1']!);
      expect(binding.toolsUsed, isTrue);
      expect(touched, ['ws1']);
    });

    test('does not mark tools used on denial', () async {
      await service().handle(
        ctx(sandboxed: true, allowAll: true, toolsUsed: false),
        'write_file',
        {'path': '/skills/x.txt', 'content': 'no'},
        toolCallId: 'lock-deny',
        conversationId: 'conv-1',
      );
      expect(extrasById, isEmpty);
      expect(touched, isEmpty);
    });
  });
}
