import 'package:flutter/material.dart';
import '../../browser/pages/browser_page.dart';
import '../desktop_side_panel_controller.dart';

/// Hosts the existing browser without its independent tab/title row.
class SidePanelBrowser extends StatefulWidget {
  const SidePanelBrowser({
    super.key,
    required this.controller,
    required this.onShowAllTabs,
  });
  final DesktopSidePanelController controller;
  final VoidCallback onShowAllTabs;
  @override
  State<SidePanelBrowser> createState() => SidePanelBrowserState();
}

class SidePanelBrowserState extends State<SidePanelBrowser> {
  final _page = GlobalKey<BrowserPageViewState>();
  void focusAddress() => _page.currentState?.focusAddress();
  void focusFind() => _page.currentState?.focusFind();
  bool escapeAddress() => _page.currentState?.escapePanelEditing() ?? false;
  void reload() => _page.currentState?.reloadPage();
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => BrowserPage(
      key: _page,
      service: widget.controller.browser,
      conversationId: widget.controller.conversationId,
      embedded: true,
      sidePanel: widget.controller,
      onShowAllTabs: widget.onShowAllTabs,
      onClose: widget.controller.close,
    ),
  );
}
