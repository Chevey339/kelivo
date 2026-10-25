import 'package:flutter/material.dart';

import '../../../shared/responsive/screen_type_helper.dart';
import '../widgets/mcp_management_view.dart';

class McpPage extends StatelessWidget {
  const McpPage({super.key});

  @override
  Widget build(BuildContext context) =>
      McpManagementView(desktop: ResponsiveHelper.isDesktop(context));
}
