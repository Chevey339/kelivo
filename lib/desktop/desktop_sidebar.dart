import 'package:flutter/material.dart';
import '../features/home/widgets/side_drawer.dart';

/// Desktop sidebar wrapper. Phase 1: reuse tablet embedded SideDrawer to ensure parity.
/// Later we can evolve this to a dedicated desktop-only sidebar with right-click menus.
class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.userName,
    required this.assistantName,
    this.onSelectConversation,
    this.onNewConversation,
    this.loadingConversationIds = const <String>{},
  });

  final String userName;
  final String assistantName;
  final void Function(String id)? onSelectConversation;
  final VoidCallback? onNewConversation;
  final Set<String> loadingConversationIds;

  @override
  Widget build(BuildContext context) {
    return SideDrawer(
      embedded: true,
      embeddedWidth: 300,
      userName: userName,
      assistantName: assistantName,
      onSelectConversation: onSelectConversation,
      onNewConversation: onNewConversation,
      loadingConversationIds: loadingConversationIds,
      showBottomBar: false,
    );
  }
}
