import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../features/home/services/tool_approval_service.dart';
import '../../../utils/app_directories.dart';
import '../../../utils/mcp_structured_image.dart';
import '../api/tool_call_cancellation.dart';
import '../../models/workspace_binding.dart';
import '../../models/external_mount.dart';
import '../../models/environment_variable.dart';
import '../../providers/external_mounts_provider.dart';
import '../../providers/workspace_provider.dart';
import '../chat/chat_service.dart';
import 'conversation_files.dart';
import 'environment_output_redactor.dart';
import 'file_link_resolver.dart';
import 'host_file_tools.dart';
import 'output_buffer.dart';
import 'tool_run_registry.dart';
import 'workspace_paths.dart';
import 'workspace_runtime.dart';
import 'workspace_session_sync.dart';
import 'workspace_tool_context.dart';
import 'workspace_tool_metadata.dart';

export 'workspace_session_sync.dart' show AttachmentInfo, syncAttachments;
export 'workspace_tool_context.dart';
export 'workspace_tool_metadata.dart';

typedef ConversationExtrasUpdater =
    Future<void> Function(
      String conversationId,
      Map<String, dynamic> Function(Map<String, dynamic> extras) update,
    );

/// Per-generation workspace tool definitions, approval, and execution.
class WorkspaceToolsService {
  WorkspaceToolsService({
    ToolRunRegistry? registry,
    WorkspaceRuntimeProvider? runtimeProvider,
    this.updateConversationExtras,
    this.touchLastUsed,
    this.onSkillRead,
    this.onShellCompleted,
    this.isToolEnabled,
    this.loadEnvironment,
  }) : registry = registry ?? ToolRunRegistry(),
       runtimeProvider = runtimeProvider ?? WorkspaceRuntimeProvider();

  static const Set<String> toolNames = {
    'shell',
    'read_file',
    'write_file',
    'edit_file',
    'list_dir',
    'glob',
    'grep',
  };

  static const int _previewLimit = WorkspaceToolMetadata.previewMaxChars;
  static const int _changedFilesCap = 50;

  final ToolRunRegistry registry;
  final WorkspaceRuntimeProvider runtimeProvider;
  final ConversationExtrasUpdater? updateConversationExtras;
  final Future<void> Function(String workspaceId)? touchLastUsed;
  final Future<void> Function(String skillId)? onSkillRead;
  final Future<void> Function()? onShellCompleted;
  final bool Function(String workspaceId, String tool)? isToolEnabled;
  final Future<EnvironmentExecutionConfig> Function()? loadEnvironment;

  bool _enabled(WorkspaceToolContext ctx, String name) =>
      isToolEnabled?.call(ctx.workspace.id, name) ??
      ctx.workspace.isToolEnabled(name);

  static Future<WorkspaceToolContext?> resolve({
    required String? conversationId,
    required WorkspaceProvider workspaceProvider,
    required WorkspaceRuntimeProvider runtimeProvider,
    required ChatService chatService,
    ExternalMountsProvider? externalMounts,
  }) async {
    if (conversationId == null || conversationId.isEmpty) return null;
    try {
      await workspaceProvider.loaded;
    } catch (_) {}
    final conversation = chatService.getConversation(conversationId);
    if (conversation == null) return null;
    final binding = WorkspaceBinding.fromExtras(conversation.extras);
    if (!binding.isBound) return null;
    final workspace = workspaceProvider.byId(binding.workspaceId!);
    if (workspace == null) return null;

    late final String hostRoot;
    try {
      hostRoot = await workspaceProvider.hostRootFor(workspace);
    } catch (e) {
      debugPrint('Workspace host root unavailable: $e');
      return null;
    }

    final runtime = runtimeProvider.runtime;
    RuntimeStatus? status;
    if (runtime != null) {
      try {
        status = await runtime.status();
      } catch (e) {
        debugPrint('Workspace runtime status failed: $e');
      }
    }
    final sandboxed = runtime != null
        ? (status?.sandboxed ?? false)
        : (Platform.isAndroid || Platform.isIOS);

    final sessionDir = await AppDirectories.sessionDir(conversationId);
    final skillsDir = await AppDirectories.getSkillsDirectory();
    final paths = sandboxed
        ? WorkspacePaths.sandboxed(
            workspaceHostRoot: hostRoot,
            sessionHostDir: sessionDir.path,
            skillsHostDir: skillsDir.path,
            externalMounts: await externalMounts?.resolveMounts() ?? const [],
            loadExternalMounts: externalMounts?.resolveMounts,
          )
        : WorkspacePaths.native(
            workspaceHostRoot: hostRoot,
            sessionHostDir: sessionDir.path,
            skillsHostDir: skillsDir.path,
          );

    return WorkspaceToolContext(
      workspace: workspace,
      binding: binding,
      paths: paths,
      sessionDir: sessionDir,
      outputsDir: Directory(p.join(sessionDir.path, 'outputs')),
      conversationId: conversationId,
      runtimeStatus: status,
      runtimeRegistered: runtime != null,
    );
  }

  List<Map<String, dynamic>> buildToolDefinitions(WorkspaceToolContext ctx) {
    if (ctx.skillsOnly) {
      return [
        _fn(
          'read_file',
          [
            'Read a skill file as numbered lines. Use offset/limit to page through long files.',
            'Paths are limited to /skills/...',
          ],
          {
            'path': {
              'type': 'string',
              'description': 'Skill file path under /skills/...',
            },
            'offset': {
              'type': 'integer',
              'description': '1-based line number to start from.',
            },
            'limit': {
              'type': 'integer',
              'description': 'Maximum number of lines to return.',
            },
          },
          ['path'],
        ),
      ];
    }
    return definitions(
          vocab: _pathVocab(ctx.paths),
          outputHint: ctx.paths.sandboxed
              ? '${WorkspacePaths.guestChat}/outputs/<id>.txt'
              : '${ctx.paths.sessionHostDir}/outputs/<id>.txt',
        )
        .where(
          (definition) =>
              _enabled(ctx, (definition['function'] as Map)['name'] as String),
        )
        .toList();
  }

  /// Shared schemas for execution and the ungated description editor.
  static List<Map<String, dynamic>> definitions({
    List<String> vocab = const ['/workspace', '/chat', '/skills', '/tmp'],
    String outputHint = '/chat/outputs/<id>.txt',
  }) {
    return [
      _fn(
        'shell',
        [
          'Fresh non-interactive sh -lc per call; no cwd/env persists. Chain with &&.',
          'Use non-interactive flags (e.g. -y). Output is capped; long output is saved',
          'to $outputHint. Network is available on mobile sandboxes.',
        ],
        {
          'command': {
            'type': 'string',
            'description': 'Shell command to run with sh -lc.',
          },
          'cwd': {
            'type': 'string',
            'description':
                'Working directory in model path vocabulary (${vocab.join(', ')}).',
          },
          'timeout_seconds': {
            'type': 'integer',
            'description': 'Timeout in seconds (default 120, max 600).',
            'default': 120,
            'minimum': 1,
            'maximum': 600,
          },
        },
        ['command'],
      ),
      _fn(
        'read_file',
        [
          'Read a file as numbered lines. Use offset/limit to page through long files.',
          'Paths: ${vocab.join(', ')}.',
        ],
        {
          'path': {'type': 'string', 'description': 'File path to read.'},
          'offset': {
            'type': 'integer',
            'description': '1-based line number to start from.',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of lines to return.',
          },
        },
        ['path'],
      ),
      _fn(
        'write_file',
        [
          'Create or overwrite a file with the given content.',
          'Writable zones: workspace, chat, tmp. Skills are read-only.',
        ],
        {
          'path': {'type': 'string', 'description': 'File path to write.'},
          'content': {'type': 'string', 'description': 'Full file contents.'},
        },
        ['path', 'content'],
      ),
      _fn(
        'edit_file',
        [
          'Replace old_string with new_string. Matching is whitespace-tolerant',
          '(exact, then line-trimmed, then block-anchor). old_string must match a',
          'unique location unless replace_all is true. Read the file before editing.',
        ],
        {
          'path': {'type': 'string', 'description': 'File path to edit.'},
          'old_string': {
            'type': 'string',
            'description': 'Exact or whitespace-tolerant text to find.',
          },
          'new_string': {'type': 'string', 'description': 'Replacement text.'},
          'replace_all': {
            'type': 'boolean',
            'description':
                'Replace every match instead of requiring a unique one.',
          },
        },
        ['path', 'old_string', 'new_string'],
      ),
      _fn(
        'list_dir',
        [
          'List directory entries. Directories are suffixed with /; files include size.',
          'Default path is the current workspace cwd.',
        ],
        {
          'path': {'type': 'string', 'description': 'Directory to list.'},
          'depth': {
            'type': 'integer',
            'description': 'How many directory levels to walk (default 1).',
          },
        },
        const [],
      ),
      _fn(
        'glob',
        [
          'Find files whose relative paths match a glob pattern (e.g. **/*.dart).',
        ],
        {
          'pattern': {
            'type': 'string',
            'description': 'Glob pattern to match.',
          },
          'path': {
            'type': 'string',
            'description': 'Directory to search (default: workspace root).',
          },
        },
        ['pattern'],
      ),
      _fn(
        'grep',
        [
          'Search file contents with a regex (falls back to a literal if invalid).',
        ],
        {
          'pattern': {
            'type': 'string',
            'description': 'Regex or literal to find.',
          },
          'path': {
            'type': 'string',
            'description':
                'File or directory to search (default: workspace root).',
          },
          'ignore_case': {
            'type': 'boolean',
            'description': 'Case-insensitive search.',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum matches to return (default 100).',
          },
        },
        ['pattern'],
      ),
    ];
  }

  static String buildPromptFragment(
    WorkspaceToolContext ctx, {
    List<AttachmentInfo> attachments = const [],
    Iterable<String> environmentVariableNames = const [],
  }) {
    if (ctx.skillsOnly) return '';
    final paths = ctx.paths;
    final workspace = paths.sandboxed
        ? WorkspacePaths.guestWorkspace
        : paths.workspaceHostRoot;
    final chat = paths.sandboxed
        ? WorkspacePaths.guestChat
        : paths.sessionHostDir;
    final skills = paths.sandboxed
        ? WorkspacePaths.guestSkills
        : paths.skillsHostDir;
    final tmp = paths.sandboxed ? WorkspacePaths.guestTmp : paths.tmpHostRoot;
    final outputsHint = paths.sandboxed
        ? '${WorkspacePaths.guestChat}/outputs/<id>.txt'
        : '${paths.sessionHostDir}/outputs/<id>.txt';
    final attachDir = paths.sandboxed
        ? '${WorkspacePaths.guestChat}/attachments/'
        : '${paths.sessionHostDir}/attachments/';

    final buf = StringBuffer()
      ..writeln('<workspace>')
      ..writeln('Path zones:')
      ..writeln('- $workspace — project files (writable)')
      ..writeln('- $chat — this chat\'s attachments/ and outputs/ (writable)')
      ..writeln('- $skills — installed skills (read-only)');
    if (paths.sandboxed) {
      final source = defaultTargetPlatform == TargetPlatform.iOS
          ? "from iOS Files (e.g. an Obsidian vault, Downloads, another app's iCloud container)"
          : 'from Environment settings (on-device folders)';
      final readOnly = paths.externalMounts
          .where((mount) => mount.readOnly)
          .map((mount) => mount.guest)
          .join(', ');
      buf.writeln(
        '- ${ExternalMount.root}/<name>/ — user-mounted external folders '
        '$source, shared across workspaces. '
        'Names and availability vary: list ${ExternalMount.root}/ first for external/user files. '
        'File tools reject writes to read-only mounts; respect this in Shell too.'
        '${readOnly.isEmpty ? '' : ' Read-only: $readOnly.'}',
      );
    }
    buf
      ..writeln('- $tmp — scratch (writable, ephemeral)')
      ..writeln('cwd: ${ctx.cwd}')
      ..writeln(
        'Enabled tools: ${toolNames.where(ctx.workspace.isToolEnabled).join(', ')}',
      )
      ..writeln();
    if (ctx.workspace.isToolEnabled('shell')) {
      buf.writeln(
        'shell is one-shot: a fresh non-interactive sh -lc each call. '
        'No cd or env persists. Chain with &&. Use non-interactive flags (-y). '
        'Output is capped; long output is saved to $outputsHint.',
      );
      if (environmentVariableNames.isNotEmpty) {
        buf.writeln(
          'User-configured environment variables are already injected: '
          '${environmentVariableNames.join(', ')}. '
          r'Use $NAME references; do not print or attempt to discover their values.',
        );
      }
    }
    if (ctx.workspace.isToolEnabled('read_file') &&
        ctx.workspace.isToolEnabled('edit_file')) {
      if (ctx.workspace.isToolEnabled('write_file')) {
        buf.writeln(
          'Prefer read_file, edit_file, and write_file over cat/sed.',
        );
      }
      buf.writeln('Always read_file before editing.');
    }
    buf
      ..writeln()
      ..writeln(
        'Cite files as [name](kelivo://workspace/rel/path), outputs as '
        'kelivo://chat/outputs/x.txt, images as ![alt](kelivo://workspace/plot.png). '
        'Percent-encode each path segment (spaces, non-ASCII); raw UTF-8 is also accepted.',
      )
      ..writeln()
      ..writeln(_engineLine(ctx));
    if (attachments.isNotEmpty) {
      buf.writeln();
      buf.writeln('Attachments under $attachDir');
      for (final item in attachments) {
        buf.writeln('- ${item.name} (${item.size} bytes)');
      }
    }
    buf.write('</workspace>');
    return buf.toString();
  }

  Future<Object?> handle(
    WorkspaceToolContext ctx,
    String name,
    Map<String, dynamic> args, {
    required String toolCallId,
    ToolApprovalService? approvalService,
    String? conversationId,
  }) async {
    final environment =
        await loadEnvironment?.call() ?? EnvironmentExecutionConfig();
    final redactor = EnvironmentOutputRedactor(environment);
    final result = await _handle(
      ctx,
      name,
      args,
      toolCallId: toolCallId,
      approvalService: approvalService,
      conversationId: conversationId,
      environment: environment.variables,
    );
    return redactor.redact(ClientToolResult.fromHandler(result));
  }

  Future<Object?> _handle(
    WorkspaceToolContext ctx,
    String name,
    Map<String, dynamic> args, {
    required String toolCallId,
    ToolApprovalService? approvalService,
    String? conversationId,
    required Map<String, String> environment,
  }) async {
    if (ctx.skillsOnly && name != 'read_file') {
      return _errorResult(
        tool: name,
        error: 'skills_only',
        message: 'Only read_file is available without a workspace',
      );
    }
    if (!ctx.skillsOnly && !_enabled(ctx, name)) {
      return _errorResult(
        tool: name,
        error: 'tool_disabled',
        message: 'This tool is disabled for the workspace',
      );
    }
    try {
      ToolCallCancellation.current?.throwIfCancelled();
      await ctx.paths.refreshExternalMounts();
      ToolCallCancellation.current?.throwIfCancelled();
      switch (name) {
        case 'shell':
          return await _handleShell(
            ctx,
            args,
            toolCallId: toolCallId,
            approvalService: approvalService,
            conversationId: conversationId,
            environment: environment,
          );
        case 'read_file':
          return await _handleReadFile(ctx, args);
        case 'write_file':
          return await _handleWriteFile(
            ctx,
            args,
            toolCallId: toolCallId,
            approvalService: approvalService,
            conversationId: conversationId,
          );
        case 'edit_file':
          return await _handleEditFile(
            ctx,
            args,
            toolCallId: toolCallId,
            approvalService: approvalService,
            conversationId: conversationId,
          );
        case 'list_dir':
          return await _handleListDir(ctx, args);
        case 'glob':
          return await _handleGlob(ctx, args);
        case 'grep':
          return await _handleGrep(ctx, args);
        default:
          return _errorResult(
            tool: name,
            error: 'unknown_tool',
            message: 'Unknown workspace tool: $name',
          );
      }
    } catch (e) {
      return _errorResult(
        tool: name,
        error: 'tool_failed',
        message: e.toString(),
      );
    }
  }

  static String? linkFor(
    ResolvedPath resolved, {
    required WorkspacePaths paths,
  }) {
    switch (resolved.zone) {
      case WorkspaceZone.workspace:
        final rel = WorkspacePaths.relativeToHostRoot(
          paths.workspaceHostRoot,
          resolved.hostPath,
        );
        if (rel == null) return null;
        return 'kelivo://workspace/${KelivoLink.encodePath(rel)}';
      case WorkspaceZone.chat:
        final rel = WorkspacePaths.relativeToHostRoot(
          paths.sessionHostDir,
          resolved.hostPath,
        );
        if (rel == null) return null;
        if (rel == 'attachments' ||
            rel == 'outputs' ||
            rel.startsWith('attachments/') ||
            rel.startsWith('outputs/')) {
          return 'kelivo://chat/${KelivoLink.encodePath(rel)}';
        }
        return 'kelivo://session/${KelivoLink.encodePath(rel)}';
      case WorkspaceZone.skills:
        final rel = WorkspacePaths.relativeToHostRoot(
          paths.skillsHostDir,
          resolved.hostPath,
        );
        if (rel == null) return null;
        return 'kelivo://skills/${KelivoLink.encodePath(rel)}';
      case WorkspaceZone.tmp:
        final rel = WorkspacePaths.relativeToHostRoot(
          paths.tmpHostRoot,
          resolved.hostPath,
        );
        return rel == null
            ? null
            : 'kelivo://tmp/${KelivoLink.encodePath(rel)}';
      case WorkspaceZone.external:
        for (final mount in paths.externalMounts) {
          final rel = WorkspacePaths.relativeToHostRoot(
            mount.host,
            resolved.hostPath,
          );
          if (rel != null && mount.externalId != null) {
            return 'kelivo://mounts/${Uri.encodeComponent(mount.externalId!)}${rel.isEmpty ? '' : '/${KelivoLink.encodePath(rel)}'}';
          }
        }
        return null;
      case WorkspaceZone.outside:
        return null;
    }
  }

  static WorkspaceToolFile _fileFor(
    WorkspaceToolContext ctx,
    ResolvedPath resolved, {
    WorkspaceFileRole role = WorkspaceFileRole.referenced,
    bool isDirectory = false,
  }) => WorkspaceToolFile(
    path: resolved.modelPath,
    link: linkFor(resolved, paths: ctx.paths),
    isDirectory: isDirectory,
    role: role,
    temporary: resolved.zone == WorkspaceZone.tmp,
  );

  static Future<List<WorkspaceToolFile>> _referencedFiles(
    WorkspaceToolContext ctx,
    Iterable<String> paths,
  ) async {
    final files = <WorkspaceToolFile>[];
    final seen = <String>{};
    for (final path in paths.toSet()) {
      try {
        final resolved = await ctx.paths.resolveReal(path, cwd: ctx.cwd);
        final file = _fileFor(
          ctx,
          resolved,
          isDirectory: await FileSystemEntity.isDirectory(resolved.hostPath),
        );
        if (seen.add(file.identity)) files.add(file);
      } on PathResolutionException {
        files.add(WorkspaceToolFile(path: path));
      } on FileSystemException {
        files.add(WorkspaceToolFile(path: path));
      }
    }
    return files;
  }

  Future<Object?> _handleShell(
    WorkspaceToolContext ctx,
    Map<String, dynamic> args, {
    required String toolCallId,
    ToolApprovalService? approvalService,
    String? conversationId,
    required Map<String, String> environment,
  }) async {
    const tool = 'shell';
    final cancellation = ToolCallCancellation.current;
    cancellation?.throwIfCancelled();
    final command = _stringArg(args, 'command');
    if (command.isEmpty) {
      return _errorResult(
        tool: tool,
        error: 'invalid_arguments',
        message: 'command is required',
      );
    }

    final runtime = runtimeProvider.runtime;
    RuntimeStatus? status = ctx.runtimeStatus;
    if (runtime != null && status == null) {
      try {
        status = await runtime.status();
      } catch (_) {}
    }
    if (runtime == null || status == null || !status.ready) {
      return _errorResult(
        tool: tool,
        error: 'environment_not_ready',
        message: status?.reason ?? 'Sandbox environment is not ready',
        instruction:
            'tell the user to install/enable the sandbox environment in Settings → Workspace',
        meta: const WorkspaceToolMetadata(
          tool: tool,
          status: 'error',
          code: 'environment_not_ready',
        ),
      );
    }

    final sandboxed = status.sandboxed;
    final needsApproval =
        (ctx.workspace.shellNeedsApproval || !sandboxed) &&
        !ctx.binding.allowAll;
    final denied = await _maybeApprove(
      approvalService,
      needed: needsApproval,
      toolCallId: toolCallId,
      toolName: tool,
      args: args,
      conversationId: conversationId ?? ctx.conversationId,
    );
    if (denied != null) return denied;

    final timeoutSeconds = (_intArg(args, 'timeout_seconds') ?? 120).clamp(
      1,
      600,
    );
    final cwd = ctx.paths.normalizeCwd(
      _stringArg(args, 'cwd', fallback: ctx.cwd),
    );
    final env = <String, String>{
      if (!sandboxed) ...Platform.environment,
      'NO_COLOR': '1',
      'CI': 'true',
      'PAGER': 'cat',
      'TERM': 'dumb',
      'LANG': 'C.UTF-8',
      'HOME': sandboxed ? '/root' : (Platform.environment['HOME'] ?? ''),
      ...environment,
    };

    final runtimeRunId = const Uuid().v4();
    final run = registry.start(
      toolCallId,
      tool,
      command: command,
      conversationId: conversationId ?? ctx.conversationId,
      runtimeRunId: runtimeRunId,
    );
    final stdoutBuf = BoundedStreamBuffer();
    final stderrBuf = BoundedStreamBuffer();
    final before = await FileSnapshot.snapshot([
      Directory(ctx.paths.workspaceHostRoot),
      ctx.sessionDir,
    ]);

    CommandExited? exited;
    Object? executionError;
    var executing = false;
    try {
      cancellation?.throwIfCancelled();
      executing = true;
      unawaited(
        cancellation?.cancelled.then((_) async {
          if (executing) await runtime.cancel(runtimeRunId);
        }),
      );
      await for (final event in runtime.run(
        CommandRequest(
          runId: runtimeRunId,
          isCancelled: cancellation?.isCancelled,
          command: command,
          cwd: cwd,
          timeout: Duration(seconds: timeoutSeconds),
          env: env,
          mounts: ctx.paths.mounts,
        ),
      )) {
        switch (event) {
          case CommandStarted():
            break;
          case CommandOutput(:final kind, :final bytes):
            if (kind == OutputStreamKind.stdout) {
              stdoutBuf.add(bytes);
              run.appendStdout(bytes);
            } else {
              stderrBuf.add(bytes);
              run.appendStderr(bytes);
            }
          case CommandExited():
            exited = event;
        }
      }
    } catch (e) {
      executionError = e;
    } finally {
      executing = false;
      // A failed or cancelled command may still have installed/updated files.
      // Refresh observers without turning a refresh failure into a tool error.
      try {
        await onShellCompleted?.call();
      } catch (error) {
        debugPrint('Workspace post-command refresh failed: $error');
      }
    }

    final runStatus = executionError != null || exited == null
        ? ToolRunStatus.failed
        : exited.cancelled
        ? ToolRunStatus.cancelled
        : exited.timedOut
        ? ToolRunStatus.timedOut
        : exited.exitCode == 0
        ? ToolRunStatus.succeeded
        : ToolRunStatus.failed;
    run.complete(status: runStatus, exitCode: exited?.exitCode);

    final after = await FileSnapshot.snapshot([
      Directory(ctx.paths.workspaceHostRoot),
      ctx.sessionDir,
    ]);
    final changedHost = FileSnapshot.changedSince(before, after);
    final files = <WorkspaceToolFile>[];
    for (final hostPath in changedHost.take(_changedFilesCap)) {
      final modelPath = ctx.paths.toModelPath(hostPath);
      try {
        final resolved = await ctx.paths.resolveReal(modelPath, cwd: cwd);
        if (!await FileSystemEntity.isFile(resolved.hostPath)) continue;
        files.add(
          _fileFor(
            ctx,
            resolved,
            role: before.containsKey(hostPath)
                ? WorkspaceFileRole.modified
                : WorkspaceFileRole.created,
          ),
        );
      } on PathResolutionException {
        files.add(
          WorkspaceToolFile(path: modelPath, role: WorkspaceFileRole.modified),
        );
      } on FileSystemException {
        // A file removed again before collection is not a remaining output.
      }
    }
    final filesTruncated =
        changedHost.length > _changedFilesCap ||
        before.length >= FileSnapshot.defaultMaxEntries ||
        after.length >= FileSnapshot.defaultMaxEntries;

    if (executionError != null || exited == null) {
      return _errorResult(
        tool: tool,
        error: 'shell_failed',
        message:
            executionError?.toString() ?? 'Command ended without an exit event',
        meta: WorkspaceToolMetadata(
          tool: tool,
          status: 'error',
          code: 'shell_failed',
          command: command,
          stdoutPreview: stdoutBuf.text,
          stderrPreview: stderrBuf.text,
          files: files,
          filesTruncated: filesTruncated,
        ),
      );
    }

    final offload = await ToolOutputOffloader.maybeOffload(
      toolCallId: toolCallId,
      stdout: stdoutBuf.text,
      stderr: stderrBuf.text,
      outputsDir: ctx.outputsDir,
    );
    final payload = _shellPayload(offload.modelText);
    payload['exit_code'] = exited.exitCode;
    payload['duration_ms'] = exited.duration.inMilliseconds;
    payload['timed_out'] = exited.timedOut;
    payload['cancelled'] = exited.cancelled;
    payload['interrupted'] = exited.interrupted;
    if (stdoutBuf.truncated || stderrBuf.truncated) {
      payload['truncated'] = true;
    }
    if (files.isNotEmpty) {
      payload['changed_files'] = [for (final file in files) file.path];
    }
    if (filesTruncated) payload['changed_files_truncated'] = true;
    if (offload.offloadHostPath != null) {
      final outputFile = ctx.paths.toModelPath(offload.offloadHostPath!);
      payload['output_file'] = outputFile;
      payload['truncated'] = true;
      final resolved = await ctx.paths.resolveReal(outputFile, cwd: cwd);
      files.add(_fileFor(ctx, resolved, role: WorkspaceFileRole.log));
    }

    final metaStatus = exited.timedOut
        ? 'timeout'
        : exited.cancelled
        ? 'cancelled'
        : 'ok';
    final meta = WorkspaceToolMetadata(
      tool: tool,
      status: metaStatus,
      command: command,
      exitCode: exited.exitCode,
      durationMs: exited.duration.inMilliseconds,
      timedOut: exited.timedOut,
      cancelled: exited.cancelled,
      interrupted: exited.interrupted,
      stdoutPreview: utf16SafeCut(
        stdoutBuf.text,
        _previewLimit,
        keepTail: true,
      ),
      stderrPreview: utf16SafeCut(
        stderrBuf.text,
        _previewLimit,
        keepTail: true,
      ),
      files: files,
      filesTruncated: filesTruncated,
      truncated: payload['truncated'] == true,
    );
    await _markToolsUsed(
      ctx,
      conversationId: conversationId,
      status: metaStatus,
    );
    return ClientToolResult(jsonEncode(payload), metadata: meta.toJson());
  }

  Future<Object?> _handleReadFile(
    WorkspaceToolContext ctx,
    Map<String, dynamic> args,
  ) async {
    const tool = 'read_file';
    final path = _stringArg(args, 'path');
    if (path.isEmpty) {
      return _errorResult(
        tool: tool,
        error: 'invalid_arguments',
        message: 'path is required',
      );
    }
    try {
      final resolved = await ctx.paths.resolveReal(path, cwd: ctx.cwd);
      if (ctx.skillsOnly && resolved.zone != WorkspaceZone.skills) {
        return _errorResult(
          tool: tool,
          error: 'path_outside_skills',
          message: 'read_file is limited to /skills in skills-only mode',
        );
      }
      final result = await HostFileTools(ctx.paths).readFile(
        path,
        offset: _intArg(args, 'offset'),
        limit: _intArg(args, 'limit'),
        cwd: ctx.cwd,
      );
      final meta = WorkspaceToolMetadata(
        tool: tool,
        status: 'ok',
        path: resolved.modelPath,
        files: [_fileFor(ctx, resolved)],
      );
      if (result.imageBytes != null) {
        final uri = resolved.hostPath;
        await _maybeNoteSkillRead(ctx, resolved);
        await _markToolsUsed(
          ctx,
          conversationId: ctx.conversationId,
          status: 'ok',
        );
        return ClientToolResult(
          '![](${encodeMarkdownImageDestination(uri)})',
          metadata: <String, dynamic>{
            ...meta.toJson(),
            kMcpResultMetadataKey: mcpResultMetadata([uri]),
          },
        );
      }
      if (result.binary) {
        await _maybeNoteSkillRead(ctx, resolved);
        await _markToolsUsed(
          ctx,
          conversationId: ctx.conversationId,
          status: 'ok',
        );
        return ClientToolResult(
          jsonEncode(<String, Object?>{
            'binary': true,
            'hex_preview': result.hexPreview ?? '',
          }),
          metadata: meta.toJson(),
        );
      }
      final text = result.text ?? '';
      final content = result.nextOffset == null
          ? text
          : '$text(more lines: use offset=${result.nextOffset})';
      await _maybeNoteSkillRead(ctx, resolved);
      await _markToolsUsed(
        ctx,
        conversationId: ctx.conversationId,
        status: 'ok',
      );
      return ClientToolResult(content, metadata: meta.toJson());
    } on HostFileException catch (e) {
      return _errorResult(tool: tool, error: 'read_failed', message: e.message);
    } on PathResolutionException catch (e) {
      if (ctx.skillsOnly) {
        return _errorResult(
          tool: tool,
          error: 'path_outside_skills',
          message: e.message,
        );
      }
      return _errorResult(tool: tool, error: 'path_error', message: e.message);
    }
  }

  Future<Object?> _handleWriteFile(
    WorkspaceToolContext ctx,
    Map<String, dynamic> args, {
    required String toolCallId,
    ToolApprovalService? approvalService,
    String? conversationId,
  }) async {
    const tool = 'write_file';
    final path = _stringArg(args, 'path');
    if (path.isEmpty) {
      return _errorResult(
        tool: tool,
        error: 'invalid_arguments',
        message: 'path is required',
      );
    }
    final content = args.containsKey('content')
        ? args['content']?.toString() ?? ''
        : null;
    if (content == null) {
      return _errorResult(
        tool: tool,
        error: 'invalid_arguments',
        message: 'content is required',
      );
    }
    late final ResolvedPath resolved;
    try {
      resolved = await ctx.paths.resolveReal(path, cwd: ctx.cwd);
    } on PathResolutionException catch (e) {
      return _errorResult(tool: tool, error: 'path_error', message: e.message);
    }

    final denied = await _approveWrite(
      ctx,
      resolved,
      tool: tool,
      args: args,
      toolCallId: toolCallId,
      approvalService: approvalService,
      conversationId: conversationId,
    );
    if (denied != null) return denied;

    try {
      final result = await HostFileTools(
        ctx.paths,
        checkCancelled: ToolCallCancellation.current?.throwIfCancelled,
      ).writeFile(path, content, cwd: ctx.cwd);
      final link = linkFor(resolved, paths: ctx.paths);
      final body = <String, Object?>{
        'ok': true,
        'path': resolved.modelPath,
        'bytes': result.bytes,
        'created': result.created,
        if (link != null) 'link': link,
      };
      final meta = WorkspaceToolMetadata(
        tool: tool,
        status: 'ok',
        path: resolved.modelPath,
        files: [
          _fileFor(
            ctx,
            resolved,
            role: result.created
                ? WorkspaceFileRole.created
                : WorkspaceFileRole.modified,
          ),
        ],
        created: result.created,
        bytes: result.bytes,
      );
      await _markToolsUsed(ctx, conversationId: conversationId, status: 'ok');
      return ClientToolResult(jsonEncode(body), metadata: meta.toJson());
    } on HostFileException catch (e) {
      return _hostFileFailure(
        tool: tool,
        error: 'write_failed',
        message: e.message,
      );
    }
  }

  Future<Object?> _handleEditFile(
    WorkspaceToolContext ctx,
    Map<String, dynamic> args, {
    required String toolCallId,
    ToolApprovalService? approvalService,
    String? conversationId,
  }) async {
    const tool = 'edit_file';
    final path = _stringArg(args, 'path');
    if (path.isEmpty) {
      return _errorResult(
        tool: tool,
        error: 'invalid_arguments',
        message: 'path is required',
      );
    }
    if (!args.containsKey('old_string') || !args.containsKey('new_string')) {
      return _errorResult(
        tool: tool,
        error: 'invalid_arguments',
        message: 'old_string and new_string are required',
      );
    }
    late final ResolvedPath resolved;
    try {
      resolved = await ctx.paths.resolveReal(path, cwd: ctx.cwd);
    } on PathResolutionException catch (e) {
      return _errorResult(tool: tool, error: 'path_error', message: e.message);
    }

    final denied = await _approveWrite(
      ctx,
      resolved,
      tool: tool,
      args: args,
      toolCallId: toolCallId,
      approvalService: approvalService,
      conversationId: conversationId,
    );
    if (denied != null) return denied;

    try {
      final result =
          await HostFileTools(
            ctx.paths,
            checkCancelled: ToolCallCancellation.current?.throwIfCancelled,
          ).editFile(
            path,
            args['old_string']?.toString() ?? '',
            args['new_string']?.toString() ?? '',
            replaceAll: _boolArg(args, 'replace_all'),
            cwd: ctx.cwd,
          );
      final link = linkFor(resolved, paths: ctx.paths);
      final body = <String, Object?>{
        'ok': true,
        'path': resolved.modelPath,
        'replacements': result.replacements,
        'strategy': result.strategy,
        'added': result.diff.added,
        'removed': result.diff.removed,
        if (link != null) 'link': link,
      };
      final meta = WorkspaceToolMetadata(
        tool: tool,
        status: 'ok',
        path: resolved.modelPath,
        files: [
          _fileFor(
            ctx,
            resolved,
            role: result.changed
                ? WorkspaceFileRole.modified
                : WorkspaceFileRole.referenced,
          ),
        ],
        diff: result.diff.text,
        added: result.diff.added,
        removed: result.diff.removed,
        diffTruncated: result.diff.truncated,
        strategy: result.strategy,
      );
      await _markToolsUsed(ctx, conversationId: conversationId, status: 'ok');
      return ClientToolResult(jsonEncode(body), metadata: meta.toJson());
    } on HostFileException catch (e) {
      return _hostFileFailure(
        tool: tool,
        error: 'edit_failed',
        message: e.message,
      );
    }
  }

  Future<Object?> _handleListDir(
    WorkspaceToolContext ctx,
    Map<String, dynamic> args,
  ) async {
    const tool = 'list_dir';
    final path = _stringArg(args, 'path', fallback: ctx.cwd);
    try {
      final result = await HostFileTools(
        ctx.paths,
      ).listDir(path, depth: _intArg(args, 'depth') ?? 1, cwd: ctx.cwd);
      final lines = <String>[
        for (final entry in result.entries)
          entry.isDirectory ? '${entry.path}/' : '${entry.path}  ${entry.size}',
      ];
      if (result.truncated) lines.add('... truncated');
      ResolvedPath? resolved;
      try {
        resolved = await ctx.paths.resolveReal(path, cwd: ctx.cwd);
      } catch (_) {}
      final meta = WorkspaceToolMetadata(
        tool: tool,
        status: 'ok',
        path: resolved?.modelPath,
        files: await _referencedFiles(ctx, [
          if (resolved != null) resolved.modelPath,
          for (final entry in result.entries) entry.path,
        ]),
        filesTruncated: result.truncated,
        count: result.entries.length,
        truncated: result.truncated,
      );
      await _markToolsUsed(
        ctx,
        conversationId: ctx.conversationId,
        status: 'ok',
      );
      return ClientToolResult(lines.join('\n'), metadata: meta.toJson());
    } on HostFileException catch (e) {
      return _errorResult(tool: tool, error: 'list_failed', message: e.message);
    } on PathResolutionException catch (e) {
      return _errorResult(tool: tool, error: 'path_error', message: e.message);
    }
  }

  Future<Object?> _handleGlob(
    WorkspaceToolContext ctx,
    Map<String, dynamic> args,
  ) async {
    const tool = 'glob';
    final pattern = _stringArg(args, 'pattern');
    if (pattern.isEmpty) {
      return _errorResult(
        tool: tool,
        error: 'invalid_arguments',
        message: 'pattern is required',
      );
    }
    try {
      final result = await HostFileTools(
        ctx.paths,
      ).glob(pattern, path: _optionalString(args, 'path'), cwd: ctx.cwd);
      final lines = List<String>.from(result.paths);
      if (result.truncated) lines.add('... truncated');
      final meta = WorkspaceToolMetadata(
        tool: tool,
        status: 'ok',
        files: await _referencedFiles(ctx, result.paths),
        filesTruncated: result.truncated,
        count: result.paths.length,
        truncated: result.truncated,
      );
      await _markToolsUsed(
        ctx,
        conversationId: ctx.conversationId,
        status: 'ok',
      );
      return ClientToolResult(lines.join('\n'), metadata: meta.toJson());
    } on HostFileException catch (e) {
      return _errorResult(tool: tool, error: 'glob_failed', message: e.message);
    } on PathResolutionException catch (e) {
      return _errorResult(tool: tool, error: 'path_error', message: e.message);
    }
  }

  Future<Object?> _handleGrep(
    WorkspaceToolContext ctx,
    Map<String, dynamic> args,
  ) async {
    const tool = 'grep';
    final pattern = _stringArg(args, 'pattern');
    if (pattern.isEmpty) {
      return _errorResult(
        tool: tool,
        error: 'invalid_arguments',
        message: 'pattern is required',
      );
    }
    try {
      final result = await HostFileTools(ctx.paths).grep(
        pattern,
        path: _optionalString(args, 'path'),
        cwd: ctx.cwd,
        ignoreCase: _boolArg(args, 'ignore_case'),
        limit: _intArg(args, 'limit') ?? HostFileTools.defaultGrepLimit,
      );
      final lines = [for (final match in result.matches) match.display];
      if (result.truncated) lines.add('... truncated');
      final meta = WorkspaceToolMetadata(
        tool: tool,
        status: 'ok',
        files: await _referencedFiles(
          ctx,
          result.matches.map((match) => match.path),
        ),
        filesTruncated: result.truncated,
        count: result.matches.length,
        truncated: result.truncated,
      );
      await _markToolsUsed(
        ctx,
        conversationId: ctx.conversationId,
        status: 'ok',
      );
      return ClientToolResult(lines.join('\n'), metadata: meta.toJson());
    } on HostFileException catch (e) {
      return _errorResult(tool: tool, error: 'grep_failed', message: e.message);
    } on PathResolutionException catch (e) {
      return _errorResult(tool: tool, error: 'path_error', message: e.message);
    }
  }

  Future<Object?> _approveWrite(
    WorkspaceToolContext ctx,
    ResolvedPath resolved, {
    required String tool,
    required Map<String, dynamic> args,
    required String toolCallId,
    ToolApprovalService? approvalService,
    String? conversationId,
  }) async {
    if (ctx.paths.isReadOnlyPath(resolved.hostPath)) {
      return _deniedResult(
        tool: tool,
        error: 'mount_readonly',
        message: 'This external mount is read-only',
        path: resolved.modelPath,
      );
    }
    if (resolved.zone == WorkspaceZone.skills) {
      return _deniedResult(
        tool: tool,
        error: 'skills_readonly',
        message: 'The skills zone is read-only',
        path: resolved.modelPath,
      );
    }
    if (resolved.zone == WorkspaceZone.outside) {
      if (ctx.paths.sandboxed) {
        return _deniedResult(
          tool: tool,
          error: 'path_outside',
          message: 'Writes outside the workspace are not allowed',
          path: resolved.modelPath,
        );
      }
      return _maybeApprove(
        approvalService,
        needed: true,
        toolCallId: toolCallId,
        toolName: tool,
        args: args,
        conversationId: conversationId ?? ctx.conversationId,
        path: resolved.modelPath,
      );
    }
    return null;
  }

  Future<Object?> _maybeApprove(
    ToolApprovalService? approvalService, {
    required bool needed,
    required String toolCallId,
    required String toolName,
    required Map<String, dynamic> args,
    String? conversationId,
    String? path,
  }) async {
    ToolCallCancellation.current?.throwIfCancelled();
    if (!needed) return null;
    if (approvalService == null) {
      return _deniedResult(
        tool: toolName,
        error: 'approval_denied',
        message: 'User denied the tool call',
        path: path,
      );
    }
    final id = toolCallId.trim().isEmpty
        ? '${toolName}_${DateTime.now().microsecondsSinceEpoch}'
        : toolCallId;
    final result = await approvalService.requestApproval(
      toolCallId: id,
      toolName: toolName,
      arguments: args,
      conversationId: conversationId,
    );
    if (result.approved) return null;
    return _deniedResult(
      tool: toolName,
      error: 'approval_denied',
      message: result.denyReason ?? 'User denied the tool call',
      path: path,
    );
  }

  Future<void> _markToolsUsed(
    WorkspaceToolContext ctx, {
    String? conversationId,
    required String status,
  }) async {
    if (ctx.skillsOnly) return;
    if (status != 'ok') return;
    if (ctx.binding.toolsUsed) return;
    final id = conversationId ?? ctx.conversationId;
    if (id == null || id.isEmpty) return;
    try {
      await updateConversationExtras?.call(id, (extras) {
        final current = WorkspaceBinding.fromExtras(extras);
        if (current.workspaceId != ctx.binding.workspaceId) return extras;
        return WorkspaceBinding(
          workspaceId: current.workspaceId,
          cwd: current.cwd,
          toolsUsed: true,
          allowAll: current.allowAll,
        ).applyTo(extras);
      });
      await touchLastUsed?.call(ctx.workspace.id);
    } catch (e) {
      debugPrint('Failed to mark workspace tools used: $e');
    }
  }

  static ClientToolResult _errorResult({
    required String tool,
    required String error,
    required String message,
    String? instruction,
    WorkspaceToolMetadata? meta,
  }) {
    return ClientToolResult(
      jsonEncode(<String, Object?>{
        'type': 'tool_error',
        'error': error,
        'message': message,
        'tool': tool,
        if (instruction != null) 'instruction': instruction,
      }),
      metadata:
          (meta ??
                  WorkspaceToolMetadata(
                    tool: tool,
                    status: 'error',
                    code: error,
                  ))
              .toJson(),
    );
  }

  static ClientToolResult _deniedResult({
    required String tool,
    required String error,
    required String message,
    String? path,
  }) {
    return ClientToolResult(
      jsonEncode(<String, Object?>{
        'type': 'tool_error',
        'error': error,
        'message': message,
        'tool': tool,
      }),
      metadata: WorkspaceToolMetadata(
        tool: tool,
        status: 'denied',
        code: error,
        path: path,
      ).toJson(),
    );
  }

  static ClientToolResult _hostFileFailure({
    required String tool,
    required String error,
    required String message,
  }) {
    return ClientToolResult(
      jsonEncode(<String, Object?>{'error': error, 'message': message}),
      metadata: WorkspaceToolMetadata(
        tool: tool,
        status: 'error',
        code: error,
      ).toJson(),
    );
  }

  static Map<String, dynamic> _fn(
    String name,
    List<String> description,
    Map<String, dynamic> properties,
    List<String> required,
  ) {
    return <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': name,
        'description': description.join(' '),
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': properties,
          if (required.isNotEmpty) 'required': required,
        },
      },
    };
  }

  static List<String> _pathVocab(WorkspacePaths paths) {
    if (paths.sandboxed) {
      return [
        WorkspacePaths.guestWorkspace,
        WorkspacePaths.guestChat,
        WorkspacePaths.guestSkills,
        WorkspacePaths.guestTmp,
        ExternalMount.root,
      ];
    }
    return [
      paths.workspaceHostRoot,
      paths.sessionHostDir,
      paths.skillsHostDir,
      paths.tmpHostRoot,
    ];
  }

  static String _engineLine(WorkspaceToolContext ctx) {
    final status = ctx.runtimeStatus;
    if (!ctx.runtimeRegistered || status == null || !status.ready) {
      return 'Sandbox environment not installed — `shell` will fail until the user installs it';
    }
    switch (status.engine) {
      case 'proot':
        return 'Engine: Linux (PRoot); check /etc/os-release for distro';
      case 'ish':
        return 'Engine: Alpine (iSH)';
      case 'process':
      case 'fake':
        return 'Engine: native shell';
      default:
        return 'Engine: ${status.engine}';
    }
  }

  static Map<String, dynamic> _shellPayload(String modelText) {
    final jsonLine = modelText.split('\n').first;
    try {
      final decoded = jsonDecode(jsonLine);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{'stdout': modelText, 'stderr': ''};
  }

  Future<void> _maybeNoteSkillRead(
    WorkspaceToolContext ctx,
    ResolvedPath resolved,
  ) async {
    if (onSkillRead == null) return;
    if (resolved.zone != WorkspaceZone.skills) return;
    final base = p.basename(resolved.hostPath.replaceAll('\\', '/'));
    final modelBase = p.posix.basename(
      resolved.modelPath.replaceAll('\\', '/'),
    );
    // Windows path canonicalization lowercases SKILL.md along with its parents.
    if (base.toLowerCase() != 'skill.md' &&
        modelBase.toLowerCase() != 'skill.md') {
      return;
    }
    final skillId = _skillIdUnderSkillsRoot(ctx, resolved);
    if (skillId == null || skillId.isEmpty) return;
    try {
      await onSkillRead!(skillId);
    } catch (e) {
      debugPrint('onSkillRead failed: $e');
    }
  }

  static String? _skillIdUnderSkillsRoot(
    WorkspaceToolContext ctx,
    ResolvedPath resolved,
  ) {
    final model = resolved.modelPath.replaceAll('\\', '/');
    const prefix = '${WorkspacePaths.guestSkills}/';
    if (model.startsWith(prefix)) {
      final rel = model.substring(prefix.length);
      if (rel.isEmpty) return null;
      return rel.split('/').first;
    }
    final rel = WorkspacePaths.relativeToHostRoot(
      ctx.paths.skillsHostDir,
      resolved.hostPath,
    );
    if (rel != null && rel.isNotEmpty) {
      return rel.replaceAll('\\', '/').split('/').first;
    }
    try {
      final root = p.canonicalize(
        Directory(ctx.paths.skillsHostDir).resolveSymbolicLinksSync(),
      );
      final host = p.canonicalize(
        File(resolved.hostPath).resolveSymbolicLinksSync(),
      );
      if (p.isWithin(root, host)) {
        return p
            .relative(host, from: root)
            .replaceAll('\\', '/')
            .split('/')
            .first;
      }
    } catch (_) {}
    return null;
  }

  static String _stringArg(
    Map<String, dynamic> args,
    String key, {
    String fallback = '',
  }) {
    final value = args[key];
    if (value == null) return fallback;
    return value.toString();
  }

  static String? _optionalString(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static int? _intArg(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool _boolArg(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }
}
