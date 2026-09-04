import 'package:Kelivo/features/workspace/pages/workspaces_page.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:flutter/material.dart';

class WorkspacesDesktopLayout extends StatelessWidget {
  const WorkspacesDesktopLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: IosIconButton(
          icon: Lucide.ArrowLeft,
          color: cs.onSurface,
          size: 22,
          minSize: 44,
          tooltip: l10n.settingsPageBackButton,
          semanticLabel: l10n.settingsPageBackButton,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.workspacesTitle),
        actions: workspaceMgmtCreateActions(context),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: WorkspacesPane(showHeader: false),
          ),
        ),
      ),
    );
  }
}
