import 'package:flutter/material.dart';
import 'package:Kelivo/features/workspace/pages/workspaces_page.dart';

/// Desktop settings use the same workspace manager as the chat entry point.
class DesktopWorkspacePane extends StatelessWidget {
  const DesktopWorkspacePane({super.key});

  @override
  Widget build(BuildContext context) => const WorkspacesPane();
}
