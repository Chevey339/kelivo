import '../../models/tool_permission_mode.dart';
import 'network_path_check.dart';
import 'package:path/path.dart' as p;
import '../conversation_tool_permissions.dart';
import '../api/tool_call_cancellation.dart';
import 'workspace_paths.dart';
import 'workspace_runtime.dart';

/// One call's approved target. Never shared across calls or conversations.
class WorkspaceFileAccess {
  WorkspaceFileAccess({
    required this.paths,
    required this.permission,
    required this.arguments,
    this.skillsOnly = false,
  });
  final WorkspacePaths paths;
  final ToolCallPermission permission;
  final Map<String, dynamic> arguments;
  final bool skillsOnly;
  final _targets = <String, String>{};

  Future<ResolvedPath> resolve(
    String path,
    String? cwd, {
    bool write = false,
  }) async {
    final state = permission.check();
    final networkTarget =
        !paths.sandboxed && state.mode != ToolPermissionMode.fullAccess
        ? await networkTargetForApproval(path, cwd ?? paths.modelRoot)
        : null;
    if (networkTarget != null) {
      await permission.authorize(
        needed: true,
        arguments: arguments,
        requestedPath: path,
        realTarget: networkTarget,
      );
      if (networkTarget !=
          await networkTargetForApproval(path, cwd ?? paths.modelRoot)) {
        throw const ToolPermissionException(
          'path_changed',
          'Network target changed while awaiting approval',
        );
      }
    }
    await paths.refreshExternalMounts();
    final lexical = paths.resolve(path, cwd: paths.normalizeCwd(cwd));
    final resolved = await paths.resolveReal(
      path,
      cwd: paths.normalizeCwd(cwd),
    );
    _checkZones(lexical, resolved, write);
    final previous = _targets[path];
    if (previous != null && !p.equals(previous, resolved.hostPath)) {
      throw const ToolPermissionException(
        'path_changed',
        'Target changed while awaiting approval',
      );
    }
    _targets[path] = resolved.hostPath;
    await permission.authorize(
      needed: resolved.zone == WorkspaceZone.outside,
      arguments: arguments,
      requestedPath: path,
      realTarget: resolved.modelPath,
    );
    await paths.refreshExternalMounts();
    final current = await paths.resolveReal(path, cwd: paths.normalizeCwd(cwd));
    if (!p.equals(current.hostPath, resolved.hostPath)) {
      throw const ToolPermissionException(
        'path_changed',
        'Target changed while awaiting approval',
      );
    }
    _checkZones(
      paths.resolve(path, cwd: paths.normalizeCwd(cwd)),
      current,
      write,
    );
    await permission.authorize(
      needed: current.zone == WorkspaceZone.outside,
      arguments: arguments,
      requestedPath: path,
      realTarget: current.modelPath,
    );
    permission.check();
    return current;
  }

  void _checkZones(ResolvedPath lexical, ResolvedPath real, bool write) {
    if (skillsOnly && real.zone != WorkspaceZone.skills) {
      throw const ToolPermissionException(
        'path_outside_skills',
        'read_file is limited to /skills',
      );
    }
    if (paths.sandboxed && real.zone == WorkspaceZone.outside) {
      throw const ToolPermissionException(
        'path_outside',
        'Target is outside the authorized area',
      );
    }
    if (write &&
        (paths.isReadOnlyPath(lexical.hostPath) ||
            paths.isReadOnlyPath(real.hostPath))) {
      throw const ToolPermissionException(
        'mount_readonly',
        'This external mount is read-only',
      );
    }
    if (write &&
        (lexical.zone == WorkspaceZone.skills ||
            real.zone == WorkspaceZone.skills)) {
      throw const ToolPermissionException(
        'skills_readonly',
        'The skills zone is read-only',
      );
    }
  }

  /// Scans never follow descendant links, even after approving an external root.
  Future<void> checkDescendant(String root, String path) async {
    ToolCallCancellation.current?.throwIfCancelled();
    final real = await WorkspacePaths.resolveHostPath(path);
    if (!p.equals(root, real) && !p.isWithin(root, real)) {
      throw const ToolPermissionException(
        'path_changed',
        'Directory entry moved outside the approved scan',
      );
    }
  }
}
