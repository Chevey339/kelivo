import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/features/workspace/pages/workspace_files_desktop_layout.dart';
import 'package:Kelivo/features/workspace/pages/workspace_files_mobile_layout.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorkspaceFilesPage extends StatelessWidget {
  const WorkspaceFilesPage({
    super.key,
    required this.workspaceId,
    this.initialRelativePath,
  });

  final String workspaceId;
  final String? initialRelativePath;

  static Future<void> open(
    BuildContext context, {
    required String workspaceId,
    String? initialRelativePath,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WorkspaceFilesPage(
          workspaceId: workspaceId,
          initialRelativePath: initialRelativePath,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context)) {
      return WorkspaceFilesDesktopLayout(
        workspaceId: workspaceId,
        initialRelativePath: initialRelativePath,
      );
    }
    return WorkspaceFilesMobileLayout(
      workspaceId: workspaceId,
      initialRelativePath: initialRelativePath,
    );
  }
}

class WorkspaceKindBadge extends StatelessWidget {
  const WorkspaceKindBadge({super.key, required this.kind});

  final WorkspaceKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final label = kind == WorkspaceKind.linked
        ? l10n.workspaceFilesKindLinked
        : l10n.workspaceFilesKindManaged;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: AppFontWeights.semibold,
          color: cs.primary,
        ),
      ),
    );
  }
}

class WorkspaceFilesTitle extends StatelessWidget {
  const WorkspaceFilesTitle({super.key, required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = DefaultTextStyle.of(context).style;
        final painter = TextPainter(
          text: TextSpan(text: workspace.name, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        const badgeReserve = 96.0;
        final maxWidth = constraints.maxWidth;
        final showBadge =
            !maxWidth.isFinite || maxWidth >= painter.width + badgeReserve;
        painter.dispose();
        return Row(
          children: [
            Flexible(
              child: Text(
                workspace.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showBadge) ...[
              const SizedBox(width: 8),
              WorkspaceKindBadge(kind: workspace.kind),
            ],
          ],
        );
      },
    );
  }
}

Workspace? workspaceOrNull(BuildContext context, String workspaceId) {
  return context.watch<WorkspaceProvider>().byId(workspaceId);
}
