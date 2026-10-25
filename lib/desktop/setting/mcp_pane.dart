import 'package:flutter/material.dart';

import '../../features/mcp/widgets/mcp_management_view.dart';

class DesktopMcpPane extends StatelessWidget {
  const DesktopMcpPane({super.key});

  @override
  Widget build(BuildContext context) =>
      const McpManagementView(desktop: true, embedded: true);
}
