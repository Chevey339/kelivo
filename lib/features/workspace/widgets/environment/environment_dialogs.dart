import 'dart:async';

import 'package:flutter/material.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/mirror_service.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/pages/mirror_page.dart';
import 'package:Kelivo/features/workspace/pages/rootfs_browser_page.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_labels.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/shared/widgets/task_progress_dialog.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:provider/provider.dart';

abstract final class EnvironmentDialogKeys {
  static const resetConfirm = ValueKey<String>('workspace-env-reset-confirm');
  static const resetCancel = ValueKey<String>('workspace-env-reset-cancel');
}

Future<bool> confirmEnvironmentReset(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  final ok = await showAppDialog<bool>(
    context,
    maxWidth: 420,
    child: Builder(
      builder: (dialogContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.workspaceEnvResetConfirmTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: AppFontWeights.emphasis,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.workspaceEnvResetConfirmMessage,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              IosTileButton(
                key: EnvironmentDialogKeys.resetConfirm,
                icon: Lucide.Trash2,
                label: l10n.workspaceEnvReset,
                backgroundColor: cs.error,
                onTap: () => Navigator.of(dialogContext).pop(true),
              ),
              const SizedBox(height: 8),
              IosTileButton(
                key: EnvironmentDialogKeys.resetCancel,
                icon: Lucide.X,
                label: l10n.workspaceEnvCancel,
                onTap: () => Navigator.of(dialogContext).pop(false),
              ),
            ],
          ),
        );
      },
    ),
  );
  return ok == true;
}

Future<void> openMirrorPage(
  BuildContext context, {
  required MirrorCategory category,
}) {
  if (ResponsiveHelper.isDesktop(context)) {
    final l10n = AppLocalizations.of(context)!;
    final height = MediaQuery.sizeOf(context).height * 0.75;
    return showAppDialog<void>(
      context,
      maxWidth: 520,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            AppDialogHeader(title: workspaceEnvCategoryLabel(l10n, category)),
            Expanded(child: MirrorPageBody(category: category)),
          ],
        ),
      ),
    );
  }
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => MirrorPage(category: category)),
  );
}

Future<void> openRootfsBrowserPage(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const RootfsBrowserPage()),
  );
}

Future<void> runDetectFastMirrors({
  required BuildContext context,
  required MirrorService mirrors,
  required Set<MirrorCategory> categories,
}) async {
  final l10n = AppLocalizations.of(context)!;
  var fraction = 0.0;
  TaskProgressOutcome outcome = TaskProgressOutcome.running;
  String phase = l10n.workspaceEnvDetectingMirrors;
  Object? error;
  var cancelled = false;
  final cancelToken = MirrorCancelToken();

  void closeDialog(BuildContext dialogContext) {
    if (!dialogContext.mounted) return;
    Navigator.of(dialogContext).pop();
  }

  await showAppDialog<void>(
    context,
    dismissible: false,
    maxWidth: 420,
    child: _DetectProgressHost(
      title: l10n.workspaceEnvDetectFastMirrors,
      cancelLabel: l10n.workspaceEnvCancel,
      acknowledgeLabel: l10n.commonClose,
      run: (onUpdate) async {
        try {
          await mirrors.autoDetectAndApplyAll(
            categories: categories,
            cancelToken: cancelToken,
            onProgress: (progress) {
              fraction = progress.fraction.clamp(0.0, 1.0);
              phase = progress.phase == MirrorDetectPhase.applying
                  ? l10n.workspaceEnvApplyingMirror(
                      workspaceEnvCategoryLabel(l10n, progress.category),
                    )
                  : workspaceEnvCategoryLabel(l10n, progress.category);
              onUpdate();
            },
          );
          if (cancelled) return;
          outcome = TaskProgressOutcome.success;
          phase = l10n.workspaceEnvMirrorsTested;
        } on MirrorCancelledException {
          cancelled = true;
        } catch (e) {
          if (cancelled) return;
          error = e;
          outcome = TaskProgressOutcome.failure;
          phase = l10n.workspaceEnvMirrorsFailed;
        }
        onUpdate();
      },
      onCancel: (dialogContext) {
        cancelled = true;
        cancelToken.cancel();
        closeDialog(dialogContext);
      },
      snapshot: () => (fraction: fraction, phase: phase, outcome: outcome),
    ),
  );

  if (!context.mounted) return;
  if (cancelled) return;
  if (error != null) {
    showAppSnackBar(
      context,
      message: l10n.workspaceEnvMirrorsFailed,
      type: NotificationType.error,
    );
    return;
  }
  final env = context.read<EnvironmentProvider>();
  final parts = <String>[];
  for (final category in categories) {
    parts.add(
      '${workspaceEnvCategoryLabel(l10n, category)}: ${workspaceEnvSelectionLabel(l10n, env.mirrors[category], category: category)}',
    );
  }
  showAppSnackBar(
    context,
    message: parts.isEmpty ? l10n.workspaceEnvMirrorsTested : parts.join(' · '),
    type: NotificationType.success,
  );
}

class _DetectProgressHost extends StatefulWidget {
  const _DetectProgressHost({
    required this.title,
    required this.cancelLabel,
    required this.acknowledgeLabel,
    required this.run,
    required this.snapshot,
    required this.onCancel,
  });

  final String title;
  final String cancelLabel;
  final String acknowledgeLabel;
  final Future<void> Function(VoidCallback onUpdate) run;
  final ({double fraction, String phase, TaskProgressOutcome outcome})
  Function()
  snapshot;
  final void Function(BuildContext dialogContext) onCancel;

  @override
  State<_DetectProgressHost> createState() => _DetectProgressHostState();
}

class _DetectProgressHostState extends State<_DetectProgressHost> {
  @override
  void initState() {
    super.initState();
    unawaited(
      widget
          .run(() {
            if (mounted) setState(() {});
          })
          .then((_) {
            if (!mounted) return;
            if (widget.snapshot().outcome == TaskProgressOutcome.success) {
              Navigator.of(context).pop();
            }
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snapshot();
    return TaskProgressDialogCard(
      title: widget.title,
      phaseLabel: snap.phase,
      fraction: snap.fraction,
      phaseIcon: Lucide.Gauge,
      cancellable: snap.outcome == TaskProgressOutcome.running,
      cancelLabel: widget.cancelLabel,
      acknowledgeLabel: widget.acknowledgeLabel,
      outcome: snap.outcome,
      onCancel: () => widget.onCancel(context),
      onAcknowledge: () => Navigator.of(context).pop(),
    );
  }
}
