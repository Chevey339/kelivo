import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/database/schema_migrations.dart';
import '../../core/services/backup/data_sync.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_semantic_colors.dart';

/// Outcome of checking a backup file's schema before restoring it.
enum ForwardCompatDecision {
  /// Nothing in the way — start the restore normally.
  proceed,

  /// The user chose not to import a backup from a newer version.
  cancelled,

  /// The backup declares it needs a newer build; restoring is not offered.
  unreadable,

  /// The backup comes from a newer version that made no promise, and the user
  /// chose to import it anyway.
  proceedUnverified,
}

/// Decides whether [file] may be restored, asking the user when the answer is
/// theirs to give.
///
/// For local files, which are readable before the restore starts. Remote
/// restores download first and ask through [forwardCompatibilityPrompt].
Future<ForwardCompatDecision> resolveForwardCompatibility(
  BuildContext context,
  File file,
) async {
  final compatibility = await DataSync.inspectBackupCompatibility(file);
  if (!context.mounted) return ForwardCompatDecision.cancelled;
  return decideForwardCompatibility(context, compatibility);
}

/// Builds the prompt DataSync's WebDAV and S3 restores use to put the same
/// question to the user once the archive has finished downloading.
///
/// The progress overlay is already up by then; a dialog stacks above it and
/// takes input normally.
ForwardCompatibilityPrompt forwardCompatibilityPrompt(BuildContext context) {
  return (compatibility) async {
    if (!context.mounted) return ForwardCompatibilityAnswer.refuse;
    final decision = await decideForwardCompatibility(context, compatibility);
    switch (decision) {
      case ForwardCompatDecision.proceed:
        return ForwardCompatibilityAnswer.proceed;
      case ForwardCompatDecision.proceedUnverified:
        return ForwardCompatibilityAnswer.proceedUnverified;
      case ForwardCompatDecision.cancelled:
        return ForwardCompatibilityAnswer.refuse;
      case ForwardCompatDecision.unreadable:
        // Refusing reports itself as a cancellation, so the reason has to be
        // shown from here.
        if (context.mounted) await _showUnreadableDialog(context);
        return ForwardCompatibilityAnswer.refuse;
    }
  };
}

/// Maps an already-inspected [compatibility] to a decision, asking the user
/// only when this build cannot answer on its own.
Future<ForwardCompatDecision> decideForwardCompatibility(
  BuildContext context,
  BackupCompatibility? compatibility,
) async {
  // No SQLite payload, or an unreadable manifest: let the restore itself report
  // the real problem.
  if (compatibility == null) return ForwardCompatDecision.proceed;

  switch (compatibility.verdict) {
    case BackupSchemaVerdict.current:
    case BackupSchemaVerdict.needsUpgrade:
    case BackupSchemaVerdict.forwardCompatible:
      return ForwardCompatDecision.proceed;

    case BackupSchemaVerdict.unreadable:
      return ForwardCompatDecision.unreadable;

    case BackupSchemaVerdict.forwardUndeclared:
      if (!context.mounted) return ForwardCompatDecision.cancelled;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final l10n = AppLocalizations.of(dialogContext)!;
          final colors = Theme.of(dialogContext).colorScheme;
          return AlertDialog(
            backgroundColor: dialogContext.overlaySurface,
            title: Text(l10n.backupPageForwardCompatTitle),
            content: SingleChildScrollView(
              child: Text(
                l10n.backupPageForwardCompatBody(
                  compatibility.schemaVersion,
                  AppDatabase.currentSchemaVersion,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.backupPageForwardCompatCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  l10n.backupPageForwardCompatContinue,
                  style: TextStyle(color: colors.error),
                ),
              ),
            ],
          );
        },
      );
      return confirmed == true
          ? ForwardCompatDecision.proceedUnverified
          : ForwardCompatDecision.cancelled;
  }
}

Future<void> _showUnreadableDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext)!;
      return AlertDialog(
        backgroundColor: dialogContext.overlaySurface,
        title: Text(l10n.backupPageForwardCompatTitle),
        content: SingleChildScrollView(
          child: Text(l10n.backupPageSchemaTooNewMessage),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.backupPageForwardCompatCancel),
          ),
        ],
      );
    },
  );
}
