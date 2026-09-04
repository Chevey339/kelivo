import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
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
  }) {
    final paths = sandboxed
        ? WorkspacePaths.sandboxed(
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
      workspace: workspace(shellNeedsApproval: shellNeedsApproval),
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
  }) {
    final provider = WorkspaceRuntimeProvider();
    if (registerRuntime && runtime != null) {
      provider.register(runtime);
    }
    return WorkspaceToolsService(
      registry: registry,
      runtimeProvider: provider,
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
        expect(metaOf(result).outputLink, isNotNull);
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

  group('metadata', () {
    test('fromJson(toJson) round trip', () {
      final original = WorkspaceToolMetadata(
        tool: 'shell',
        status: 'ok',
        code: 'x',
        path: '/workspace/a.txt',
        link: 'kelivo://workspace/a.txt',
        command: 'echo hi',
        exitCode: 0,
        durationMs: 12,
        timedOut: false,
        cancelled: false,
        interrupted: false,
        stdoutPreview: 'out',
        stderrPreview: 'err',
        outputLink: 'kelivo://chat/outputs/t.txt',
        changedFiles: const ['/workspace/a.txt'],
        changedLinks: const ['kelivo://workspace/a.txt'],
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
