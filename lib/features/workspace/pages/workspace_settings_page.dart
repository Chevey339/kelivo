import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/workspace/pages/workspaces_page.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_labels.dart';
import 'package:Kelivo/features/workspace/workspace_navigation.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

/// Mobile settings hub for workspaces and the sandbox environment.
class WorkspaceSettingsPage extends StatefulWidget {
  const WorkspaceSettingsPage({super.key});

  @override
  State<WorkspaceSettingsPage> createState() => _WorkspaceSettingsPageState();
}

class _WorkspaceSettingsPageState extends State<WorkspaceSettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final runtime = context.read<WorkspaceRuntimeProvider>();
      if (runtime.runtime == null) return;
      if (runtime.lastStatus == null) {
        unawaited(runtime.refresh());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context)) {
      return const WorkspacesPage();
    }
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final showEnv = !_envIsDesktopTarget();
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
        title: Text(l10n.settingsPageWorkspace),
        actions: workspaceMgmtCreateActions(context),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          if (showEnv) ...[
            IosSectionHeader(text: l10n.workspaceEnvTitle, first: true),
            const _EnvironmentNavRow(),
            const SizedBox(height: 12),
          ],
          IosSectionHeader(text: l10n.workspacesTitle, first: !showEnv),
          const WorkspacesPane(showHeader: false),
        ],
      ),
    );
  }
}

class _EnvironmentNavRow extends StatelessWidget {
  const _EnvironmentNavRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final env = context.watch<EnvironmentProvider>();
    final runtime = context.watch<WorkspaceRuntimeProvider>();
    final status = runtime.lastStatus;
    final phase = status?.ready == true
        ? EnvironmentPhase.ready
        : env.state.phase;
    final label = workspaceEnvEngineLabel(
      l10n: l10n,
      state: env.state,
      status: status,
    );
    return SectionCard(
      children: [
        IosNavRow(
          icon: _engineIcon(env.state, status),
          label: label,
          subtitle: _phaseLabel(l10n, phase),
          labelWeight: AppFontWeights.medium,
          onTap: () => WorkspaceNavigation.openEnvironmentPage(context),
        ),
      ],
    );
  }

  IconData _engineIcon(EnvironmentState state, RuntimeStatus? status) {
    if (_envIsDesktopTarget()) return Lucide.SquareTerminal;
    final engine = status?.engine;
    if (engine == 'proot' || state.distro == 'ubuntu') return Lucide.Package;
    if (engine == 'ish' || state.distro == 'alpine') return Lucide.Boxes;
    return Lucide.SquareTerminal;
  }
}

bool _envIsDesktopTarget() {
  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

String _phaseLabel(AppLocalizations l10n, EnvironmentPhase phase) {
  switch (phase) {
    case EnvironmentPhase.notInstalled:
      return l10n.workspaceEnvPhaseNotInstalled;
    case EnvironmentPhase.downloading:
      return l10n.workspaceEnvPhaseDownloading;
    case EnvironmentPhase.verifying:
      return l10n.workspaceEnvPhaseVerifying;
    case EnvironmentPhase.extracting:
      return l10n.workspaceEnvPhaseExtracting;
    case EnvironmentPhase.patching:
      return l10n.workspaceEnvPhasePatching;
    case EnvironmentPhase.ready:
      return l10n.workspaceEnvPhaseReady;
    case EnvironmentPhase.error:
      return l10n.workspaceEnvPhaseError;
    case EnvironmentPhase.needsRestart:
      return l10n.workspaceEnvPhaseNeedsRestart;
  }
}
