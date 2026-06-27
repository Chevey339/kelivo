import 'package:flutter/cupertino.dart';

/// Holds the state and actions for the workspace button in the AppBar.
class WorkspaceButtonConfig {
  final bool isEnabled;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onDisableWithConfirm;

  const WorkspaceButtonConfig({
    required this.isEnabled,
    required this.onPrimaryAction,
    this.onDisableWithConfirm,
  });
}
