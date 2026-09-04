import 'dart:async';

import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/features/workspace/pages/workspaces_page.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_pane.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'package:flutter/material.dart';

/// Desktop settings pane: environment status plus the workspaces list.
class DesktopWorkspacePane extends StatelessWidget {
  const DesktopWorkspacePane({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final titleStyle = TextStyle(
      fontSize: 14,
      fontWeight: AppFontWeights.regular,
      color: cs.onSurface.withValues(alpha: 0.9),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(l10n.workspacesTitle, style: titleStyle),
                      ),
                      Tooltip(
                        message: l10n.workspaceMgmtNewWorkspace,
                        child: IosIconButton(
                          key: WorkspacesPane.createKey,
                          icon: Lucide.Plus,
                          size: 18,
                          semanticLabel: l10n.workspaceMgmtNewWorkspace,
                          onTap: () {
                            Haptics.light();
                            unawaited(showCreateWorkspaceFlow(context));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  title: l10n.workspaceEnvTitle,
                  child: const EnvironmentPane(
                    embedded: true,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  title: l10n.workspacesTitle,
                  child: const WorkspacesPane(showHeader: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: context.appColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          width: 0.5,
          color: isDark
              ? cs.onSurface.withValues(alpha: 0.06)
              : cs.outlineVariant.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: AppFontWeights.semibold,
                  color: cs.onSurface,
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
