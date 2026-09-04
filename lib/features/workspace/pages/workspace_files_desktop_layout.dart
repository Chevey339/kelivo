import 'package:Kelivo/features/workspace/pages/workspace_files_mobile_layout.dart';
import 'package:flutter/material.dart';

class WorkspaceFilesDesktopLayout extends StatelessWidget {
  const WorkspaceFilesDesktopLayout({
    super.key,
    required this.workspaceId,
    this.initialRelativePath,
  });

  final String workspaceId;
  final String? initialRelativePath;

  @override
  Widget build(BuildContext context) {
    return WorkspaceFilesScaffold(
      workspaceId: workspaceId,
      initialRelativePath: initialRelativePath,
      constrainWidth: true,
    );
  }
}
