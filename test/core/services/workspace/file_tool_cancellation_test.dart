import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/environment_variable.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/services/api/tool_call_cancellation.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';

void main() {
  for (final tool in ['write_file', 'edit_file']) {
    for (final stage in [
      'environment',
      'mounts',
      'write preparation',
      'approval',
    ]) {
      test('$tool cancelled during $stage preserves the file', () async {
        final temp = await Directory.systemTemp.createTemp(
          'kelivo-file-cancel-',
        );
        addTearDown(() => temp.delete(recursive: true));
        final entered = Completer<void>();
        final resume = Completer<void>();
        final cancelled = Completer<void>();
        final paths = _PausedPaths(temp.path, stage, entered, resume);
        await Directory(paths.workspaceHostRoot).create();
        final file = File(
          stage == 'approval'
              ? '${temp.path}/outside.txt'
              : '${paths.workspaceHostRoot}/owned.txt',
        );
        await file.writeAsString('original');
        final now = DateTime.utc(2026);
        final context = WorkspaceToolContext(
          workspace: Workspace(
            id: 'review',
            name: 'Review',
            kind: WorkspaceKind.managed,
            createdAt: now,
            updatedAt: now,
          ),
          binding: const WorkspaceBinding(workspaceId: 'review'),
          paths: paths,
          sessionDir: Directory(paths.sessionHostDir),
          outputsDir: Directory('${paths.sessionHostDir}/outputs'),
          conversationId: 'review-conversation',
        );
        final approvals = ToolApprovalService();
        addTearDown(approvals.dispose);
        if (stage == 'approval') {
          approvals.addListener(() {
            if (approvals.hasPending && !entered.isCompleted) {
              entered.complete();
            }
          });
        }
        final service = WorkspaceToolsService(
          loadEnvironment: () async {
            if (stage == 'environment') {
              entered.complete();
              await resume.future;
            }
            return EnvironmentExecutionConfig();
          },
        );
        final result =
            ToolCallCancellation(
              isCancelled: () => cancelled.isCompleted,
              cancelled: cancelled.future,
            ).run(
              () => service.handle(
                context,
                tool,
                {
                  'path': file.path,
                  if (tool == 'write_file') 'content': 'changed-after-stop',
                  if (tool == 'edit_file') ...{
                    'old_string': 'original',
                    'new_string': 'changed-after-stop',
                  },
                },
                toolCallId: 'review-tool',
                approvalService: approvals,
              ),
            );
        await entered.future.timeout(const Duration(seconds: 3));
        if (stage == 'approval') {
          approvals.approve(
            'review-tool',
            conversationId: context.conversationId,
          );
        }
        cancelled.complete();
        resume.complete();
        await result.timeout(const Duration(seconds: 3));
        expect(await file.readAsString(), 'original');
        expect(approvals.hasPending, isFalse);
      });
    }
  }
}

class _PausedPaths extends WorkspacePaths {
  _PausedPaths(String root, this.stage, this.entered, this.resume)
    : super.native(
        workspaceHostRoot: '$root/workspace',
        sessionHostDir: '$root/session',
        skillsHostDir: '$root/skills',
      );

  final String stage;
  final Completer<void> entered;
  final Completer<void> resume;
  var resolutions = 0;

  // Keep the outside-file fixture outside the writable scratch zone as well.
  @override
  String get tmpHostRoot => '$workspaceHostRoot/scratch';

  @override
  Future<void> refreshExternalMounts() async {
    if (stage == 'mounts' && !entered.isCompleted) {
      entered.complete();
      await resume.future;
    }
  }

  @override
  Future<ResolvedPath> resolveReal(String input, {required String cwd}) async {
    final resolved = await super.resolveReal(input, cwd: cwd);
    if (stage == 'write preparation' && ++resolutions == 2) {
      entered.complete();
      await resume.future;
    }
    return resolved;
  }
}
