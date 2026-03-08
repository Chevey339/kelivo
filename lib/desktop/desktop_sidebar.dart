import 'dart:async';
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
  /// Callback when a conversation is selected.
  /// The [closeDrawer] parameter is ignored on desktop (sidebar is always visible).
  final FutureOr<void> Function(String id, {bool closeDrawer})? onSelectConversation;
  /// Callback when a new conversation is requested.
  /// The [closeDrawer] parameter is ignored on desktop (sidebar is always visible).
  final FutureOr<void> Function({bool closeDrawer})? onNewConversation;
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
      onEnterGlobalSearch: () {},
      onExitGlobalSearch: () {},
      showBottomBar: false,
    );
  }
}
