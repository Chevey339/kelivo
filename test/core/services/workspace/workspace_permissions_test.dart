import 'package:Kelivo/core/services/workspace/network_path_check.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:Kelivo/core/models/tool_permission_mode.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import '../../../support/claude_test_api.dart' show FakePathProviderPlatform;

class DenyApproval extends ToolApprovalService {
  int calls = 0;
  @override
  Future<ToolApprovalResult> requestApproval({
    required String toolCallId,
    required String toolName,
    required Map<String, dynamic> arguments,
    String? conversationId,
    String? workspaceId,
    String? assistantId,
    String? requestedPath,
    String? realTarget,
  }) async {
    calls++;
    return ToolApprovalResult.denied();
  }
}

void main() {
  late Directory root, workspace, session, skills, outside;
  late PathProviderPlatform originalPaths;
  const marker = 'safe-test-marker';
  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo_permission_test_');
    workspace = Directory(p.join(root.path, 'workspace'))..createSync();
    session = Directory(p.join(root.path, 'session'))..createSync();
    skills = Directory(p.join(root.path, 'skills'))..createSync();
    outside = Directory(p.join(root.path, 'outside'))..createSync();
    File(p.join(outside.path, 'note.txt')).writeAsStringSync(marker);
    File(
      p.join(outside.path, 'image.png'),
    ).writeAsBytesSync(img.encodePng(img.Image(width: 2, height: 2)));
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProviderPlatform(root.path);
    SandboxPathResolver.debugSetDirs(docsDir: root.path);
  });
  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    SandboxPathResolver.debugSetDirs();
    await root.delete(recursive: true);
  });
  WorkspaceToolContext ctx({bool sandboxed = false, bool full = false}) =>
      WorkspaceToolContext(
        workspace: Workspace(
          id: 'w',
          name: 'w',
          kind: WorkspaceKind.managed,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        binding: const WorkspaceBinding(workspaceId: 'w'),
        permissionMode: full
            ? ToolPermissionMode.fullAccess
            : ToolPermissionMode.requestApproval,
        paths: sandboxed
            ? WorkspacePaths.sandboxed(
                workspaceHostRoot: workspace.path,
                sessionHostDir: session.path,
                skillsHostDir: skills.path,
              )
            : WorkspacePaths.native(
                workspaceHostRoot: workspace.path,
                sessionHostDir: session.path,
                skillsHostDir: skills.path,
              ),
        sessionDir: session,
        outputsDir: Directory(p.join(session.path, 'outputs')),
        conversationId: 'chat',
      );
  Map<String, dynamic> arguments(String tool, String base) => {
    'path': p.join(base, switch (tool) {
      'read_file' || 'write_file' || 'edit_file' => 'note.txt',
      'view_image' => 'image.png',
      _ => '',
    }),
    if (tool == 'glob') 'pattern': '*.txt',
    if (tool == 'grep') 'pattern': marker,
    if (tool == 'write_file') 'content': 'changed',
    if (tool == 'edit_file') ...{'old_string': marker, 'new_string': 'changed'},
  };
  for (final tool in [
    'read_file',
    'view_image',
    'write_file',
    'edit_file',
    'list_dir',
    'glob',
    'grep',
  ]) {
    test(
      '$tool requires native external approval; full access executes',
      () async {
        final approval = DenyApproval();
        addTearDown(approval.dispose);
        final service = WorkspaceToolsService();
        final result = ClientToolResult.fromHandler(
          await service.handle(
            ctx(),
            tool,
            arguments(tool, outside.path),
            toolCallId: 'deny',
            approvalService: approval,
          ),
        );
        expect(jsonDecode(result.content)['error'], 'approval_denied');
        expect(approval.calls, 1);
        expect(
          File(p.join(outside.path, 'note.txt')).readAsStringSync(),
          marker,
        );
        expect(result.metadata?.containsKey(kMcpResultMetadataKey), isFalse);
        final allowed = ClientToolResult.fromHandler(
          await service.handle(
            ctx(full: true),
            tool,
            arguments(tool, outside.path),
            toolCallId: 'full',
            approvalService: approval,
          ),
        );
        expect(WorkspaceToolMetadata.fromJson(allowed.metadata!).status, 'ok');
        expect(allowed.metadata!['toolPermission'], 'fullAccess');
        expect(approval.calls, 1);
      },
    );
    for (final full in [false, true]) {
      test(
        '$tool sandbox symlink outside remains denied (full=$full)',
        () async {
          Link(p.join(workspace.path, 'escape')).createSync(outside.path);
          final result = ClientToolResult.fromHandler(
            await WorkspaceToolsService().handle(
              ctx(sandboxed: true, full: full),
              tool,
              arguments(tool, '/workspace/escape'),
              toolCallId: 'sandbox',
            ),
          );
          expect(jsonDecode(result.content)['error'], 'path_outside');
          expect(
            File(p.join(outside.path, 'note.txt')).readAsStringSync(),
            marker,
          );
        },
      );
    }
  }
  test(
    'pending approval binds the real target, including a symlink swap',
    () async {
      final original = File(p.join(outside.path, 'note.txt'));
      final other = File(p.join(outside.path, 'other.txt'))
        ..writeAsStringSync('other');
      final link = Link(p.join(workspace.path, 'link.txt'))
        ..createSync(original.path);
      final approval = ToolApprovalService();
      addTearDown(approval.dispose);
      final future = WorkspaceToolsService().handle(
        ctx(),
        'read_file',
        {'path': link.path},
        toolCallId: 'link',
        approvalService: approval,
      );
      while (!approval.hasPending) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        approval.pendingRequests.single.realTarget,
        original.resolveSymbolicLinksSync(),
      );
      link.deleteSync();
      link.createSync(other.path);
      approval.approve('link', conversationId: 'chat');
      final result = ClientToolResult.fromHandler(await future);
      expect(jsonDecode(result.content)['error'], 'path_changed');
      expect(result.content, isNot(contains('other')));
    },
  );
  test('recursive directory scans do not follow descendant links', () async {
    Link(p.join(workspace.path, 'escape')).createSync(outside.path);
    final service = WorkspaceToolsService();
    for (final tool in ['list_dir', 'glob', 'grep']) {
      final args = arguments(tool, workspace.path)..['depth'] = 4;
      if (tool == 'glob') args['pattern'] = '**/*.txt';
      final result = ClientToolResult.fromHandler(
        await service.handle(ctx(), tool, args, toolCallId: tool),
      );
      expect(WorkspaceToolMetadata.fromJson(result.metadata!).status, 'ok');
      expect(result.content, isNot(contains('note.txt')));
      expect(result.content, isNot(contains(marker)));
    }
  });
  test(
    'image returned by read_file is a snapshot independent of the source',
    () async {
      final result = ClientToolResult.fromHandler(
        await WorkspaceToolsService().handle(ctx(full: true), 'read_file', {
          'path': p.join(outside.path, 'image.png'),
        }, toolCallId: 'image'),
      );
      expect(WorkspaceToolMetadata.fromJson(result.metadata!).status, 'ok');
      expect(result.content, isNot(contains(outside.path)));
      final uri = mcpResultImageUris(
        readMcpResultMetadata(result.metadata),
      ).single;
      File(p.join(outside.path, 'image.png')).deleteSync();
      final snapshot = File(SandboxPathResolver.resolveForIo(uri)!);
      expect(snapshot.existsSync(), isTrue);
      expect(img.decodeImage(snapshot.readAsBytesSync()), isNotNull);
    },
  );
  test(
    'network preflight inspects links without contacting the target',
    () async {
      expect(isNetworkPathSyntax(r'\\server\share\file'), isTrue);
      expect(isNetworkPathSyntax('/net/server/file'), isTrue);
      expect(
        await networkTargetForApproval(
          p.join(workspace.path, 'file.txt'),
          workspace.path,
        ),
        isNull,
      );
      final link = Link(p.join(workspace.path, 'network'));
      link.createSync('/net/kelivo-permission-test-not-a-real-host');
      expect(
        await networkTargetForApproval(
          p.join(link.path, 'file'),
          workspace.path,
        ),
        '/net/kelivo-permission-test-not-a-real-host/file',
      );
    },
    skip: Platform.isWindows,
  );

  test('network preflight rejects a target replaced during approval', () async {
    final link = Link(p.join(workspace.path, 'network.txt'))
      ..createSync('/net/kelivo-permission-test-not-a-real-host/file');
    final approvals = ToolApprovalService();
    addTearDown(approvals.dispose);
    final future = WorkspaceToolsService().handle(
      ctx(),
      'read_file',
      {'path': link.path},
      toolCallId: 'network',
      approvalService: approvals,
    );
    while (!approvals.hasPending) {
      await Future<void>.delayed(Duration.zero);
    }
    link.deleteSync();
    link.createSync(p.join(outside.path, 'note.txt'));
    approvals.approve('network', conversationId: 'chat');
    final result = ClientToolResult.fromHandler(await future);
    expect(jsonDecode(result.content)['error'], 'path_changed');
    expect(result.content, isNot(contains(marker)));
  }, skip: Platform.isWindows);

  for (final full in [false, true]) {
    for (final sandboxed in [false, true]) {
      test(
        'skills nested in a workspace stay read-only (full=$full sandboxed=$sandboxed)',
        () async {
          skills = Directory(p.join(workspace.path, 'skills'))..createSync();
          final original = File(p.join(skills.path, 'note.txt'))
            ..writeAsStringSync(marker);
          final result = ClientToolResult.fromHandler(
            await WorkspaceToolsService()
                .handle(ctx(full: full, sandboxed: sandboxed), 'write_file', {
                  'path': sandboxed
                      ? '/workspace/skills/note.txt'
                      : original.path,
                  'content': 'changed',
                }, toolCallId: 'skills'),
          );
          expect(jsonDecode(result.content)['error'], 'skills_readonly');
          expect(original.readAsStringSync(), marker);
        },
      );
    }
  }

  test(
    'system temp and sibling sessions are not implicitly authorized',
    () async {
      final paths = ctx().paths;
      expect(paths.tmpHostRoot, p.join(session.path, 'tmp'));
      final sibling = File(p.join(root.path, 'sibling.txt'))
        ..writeAsStringSync(marker);
      final result = ClientToolResult.fromHandler(
        await WorkspaceToolsService().handle(ctx(), 'read_file', {
          'path': sibling.path,
        }, toolCallId: 'sibling'),
      );
      expect(jsonDecode(result.content)['error'], 'approval_denied');
      Directory(paths.tmpHostRoot).createSync();
      final own = File(p.join(paths.tmpHostRoot, 'own.txt'))
        ..writeAsStringSync(marker);
      final allowed = ClientToolResult.fromHandler(
        await WorkspaceToolsService().handle(ctx(), 'read_file', {
          'path': own.path,
        }, toolCallId: 'own'),
      );
      expect(allowed.content, contains(marker));
    },
  );
}
