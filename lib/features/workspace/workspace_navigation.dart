import 'package:flutter/material.dart';

import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

/// App-shell hooks for workspace screens.
///
/// Assign [onOpenEnvironmentPage], [onOpenTerminal], and
/// [onOpenWorkspaceFiles]. The [openEnvironmentPage] / [openTerminal] /
/// [openWorkspaceFiles] helpers call those hooks, or show a localized
/// snackbar when a hook is unset.
class WorkspaceNavigation {
  WorkspaceNavigation._();

  static void Function(BuildContext context)? onOpenEnvironmentPage;
  static void Function(BuildContext context, {String? command})? onOpenTerminal;
  static void Function(BuildContext context, {String? path})?
  onOpenWorkspaceFiles;

  static void openEnvironmentPage(BuildContext context) {
    final open = onOpenEnvironmentPage;
    if (open == null) {
      _unavailable(context);
      return;
    }
    open(context);
  }

  static void openTerminal(BuildContext context, {String? command}) {
    final open = onOpenTerminal;
    if (open == null) {
      _unavailable(context);
      return;
    }
    open(context, command: command);
  }

  static void openWorkspaceFiles(BuildContext context, {String? path}) {
    final open = onOpenWorkspaceFiles;
    if (open == null) {
      _unavailable(context);
      return;
    }
    open(context, path: path);
  }

  static void _unavailable(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showAppSnackBar(
      context,
      message: l10n?.workspaceToolNotAvailable ?? 'Not available',
      type: NotificationType.info,
    );
  }
}
