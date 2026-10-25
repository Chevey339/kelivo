import 'package:Kelivo/core/models/tool_permission_mode.dart';
import 'package:Kelivo/core/services/conversation_tool_permissions.dart';
import 'package:Kelivo/core/services/workspace/host_file_tools.dart';
import 'package:Kelivo/core/services/workspace/workspace_file_access.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';

/// Filesystem unit tests explicitly grant native access; policy tests use the service.
HostFileTools authorizedHostFileTools(WorkspacePaths paths) => HostFileTools(
  paths,
  access: WorkspaceFileAccess(
    paths: paths,
    arguments: const {},
    permission: ToolCallPermission(
      toolName: 'test',
      toolCallId: 'test',
      readState: () =>
          const ToolPermissionState(mode: ToolPermissionMode.fullAccess),
    ),
  ),
);
