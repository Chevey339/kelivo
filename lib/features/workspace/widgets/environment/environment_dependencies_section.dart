import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/environment_dependencies.dart';
import 'package:Kelivo/core/services/sandbox/mirror_service.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_chrome.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_dialogs.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_labels.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';

String _title(AppLocalizations l10n, EnvironmentDependency dependency) =>
    switch (dependency) {
      EnvironmentDependency.python => 'Python',
      EnvironmentDependency.node => 'Node.js',
      EnvironmentDependency.git => 'Git',
      EnvironmentDependency.ssh => 'SSH',
      EnvironmentDependency.network => l10n.workspaceEnvDependencyNetwork,
      EnvironmentDependency.archive => l10n.workspaceEnvDependencyArchive,
    };
String _detail(AppLocalizations l10n, EnvironmentDependency dependency) =>
    switch (dependency) {
      EnvironmentDependency.python => l10n.workspaceEnvDependencyPython,
      EnvironmentDependency.node => l10n.workspaceEnvDependencyNode,
      EnvironmentDependency.git => l10n.workspaceEnvDependencyGit,
      EnvironmentDependency.ssh => l10n.workspaceEnvDependencySsh,
      EnvironmentDependency.network => 'curl · wget',
      EnvironmentDependency.archive => 'zip · unzip',
    };
IconData _icon(EnvironmentDependency dependency) => switch (dependency) {
  EnvironmentDependency.python => Lucide.Code,
  EnvironmentDependency.node => Lucide.Boxes,
  EnvironmentDependency.git => LucideIcons.gitBranch,
  EnvironmentDependency.ssh => LucideIcons.key,
  EnvironmentDependency.network => Lucide.Globe,
  EnvironmentDependency.archive => LucideIcons.archive,
};
String _status(
  AppLocalizations l10n,
  EnvironmentDependencies service,
  EnvironmentDependency dependency,
) {
  if (service.installing == dependency) {
    return l10n.workspaceEnvDependencyInstalling;
  }
  return switch (service.status(dependency)) {
    DependencyStatus.installed => l10n.workspaceEnvDependencyInstalled,
    DependencyStatus.missing => l10n.workspaceEnvPhaseNotInstalled,
    DependencyStatus.unknown => l10n.workspaceEnvDependencyUnknown,
  };
}

String? _failure(AppLocalizations l10n, DependencyFailure? failure) =>
    switch (failure) {
      DependencyFailure.check => l10n.workspaceEnvDependencyCheckFailed,
      DependencyFailure.install => l10n.workspaceEnvDependencyInstallFailed,
      DependencyFailure.cancelled => l10n.workspaceEnvErrorCancelled,
      null => null,
    };

class EnvironmentDependenciesSection extends StatelessWidget {
  const EnvironmentDependenciesSection({
    super.key,
    required this.service,
    required this.enabled,
  });
  final EnvironmentDependencies service;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IosSectionHeader(text: l10n.workspaceEnvDependencies),
          SectionCard(
            children: [
              for (final dependency in EnvironmentDependency.values) ...[
                if (dependency.index > 0) const EnvironmentRowDivider(),
                IosNavRow(
                  key: ValueKey('environment-dependency-${dependency.name}'),
                  icon: _icon(dependency),
                  label: _title(l10n, dependency),
                  subtitle: _detail(l10n, dependency),
                  detailText: _status(l10n, service, dependency),
                  onTap:
                      enabled &&
                          (!service.busy || service.installing == dependency)
                      ? () => Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => EnvironmentDependencyPage(
                              service: service,
                              dependency: dependency,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
              const EnvironmentRowDivider(),
              IosNavRow(
                icon: Lucide.RefreshCw,
                label: service.busy && service.installing == null
                    ? l10n.workspaceEnvDependencyChecking
                    : l10n.workspaceEnvDependencyRefresh,
                trailing: service.busy && service.installing == null
                    ? const EnvironmentInlineSpinner(radius: 8)
                    : const SizedBox.shrink(),
                onTap: enabled && !service.busy
                    ? () => unawaited(service.refresh())
                    : null,
              ),
            ],
          ),
          IosSectionFooter(
            text: enabled
                ? l10n.workspaceEnvDependenciesDetail
                : l10n.workspaceEnvDependencyReadyFirst,
          ),
          if (_failure(l10n, service.failure) case final error?)
            IosSectionFooter(text: error),
        ],
      ),
    );
  }
}

class EnvironmentDependencyPage extends StatefulWidget {
  const EnvironmentDependencyPage({
    super.key,
    required this.service,
    required this.dependency,
  });
  final EnvironmentDependencies service;
  final EnvironmentDependency dependency;
  @override
  State<EnvironmentDependencyPage> createState() =>
      _EnvironmentDependencyPageState();
}

class _EnvironmentDependencyPageState extends State<EnvironmentDependencyPage> {
  bool _detecting = false;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final env = context.watch<EnvironmentProvider>();
    final mirrors = context.watch<MirrorService?>();
    final service = widget.service;
    final dependency = widget.dependency;
    final categories = <MirrorCategory>{
      service.alpine ? MirrorCategory.apk : MirrorCategory.apt,
      if (dependency == EnvironmentDependency.python) MirrorCategory.pip,
      if (dependency == EnvironmentDependency.node) MirrorCategory.npm,
    };
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final enabled =
            env.state.phase == EnvironmentPhase.ready &&
            !service.busy &&
            !_detecting;
        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            leading: IosIconButton(
              icon: Lucide.ArrowLeft,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            title: Text(_title(l10n, dependency)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              SectionCard(
                children: [
                  IosNavRow(
                    icon: _icon(dependency),
                    label: _title(l10n, dependency),
                    subtitle: _detail(l10n, dependency),
                    trailing: Text(
                      _status(l10n, service, dependency),
                      style: TextStyle(fontSize: 12, color: cs.primary),
                    ),
                  ),
                ],
              ),
              IosSectionHeader(text: l10n.workspaceEnvDependencySources),
              SectionCard(
                children: [
                  for (final category in categories) ...[
                    if (category != categories.first)
                      const EnvironmentRowDivider(),
                    IosNavRow(
                      icon: Lucide.Package,
                      label: workspaceEnvCategoryLabel(l10n, category),
                      detailText: workspaceEnvSelectionLabel(
                        l10n,
                        env.mirrors[category],
                        category: category,
                      ),
                      onTap: enabled && mirrors != null
                          ? () => unawaited(
                              openMirrorPage(context, category: category),
                            )
                          : null,
                    ),
                  ],
                  const EnvironmentRowDivider(),
                  IosNavRow(
                    icon: Lucide.Gauge,
                    label: l10n.workspaceEnvDetectFastMirrors,
                    trailing: const SizedBox.shrink(),
                    onTap: enabled && mirrors != null
                        ? () async {
                            setState(() => _detecting = true);
                            try {
                              await runDetectFastMirrors(
                                context: context,
                                mirrors: mirrors,
                                categories: categories,
                              );
                            } finally {
                              if (mounted) setState(() => _detecting = false);
                            }
                          }
                        : null,
                  ),
                ],
              ),
              IosSectionFooter(text: l10n.workspaceEnvDependencySourcesDetail),
              if (_failure(
                    l10n,
                    service.lastAttempt == dependency ? service.failure : null,
                  )
                  case final error?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    error,
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                ),
              if (service.busy) ...[
                const EnvironmentInlineSpinner(radius: 10),
                const SizedBox(height: 12),
                IosTileButton(
                  icon: Lucide.X,
                  label: l10n.workspaceEnvCancel,
                  onTap: () => unawaited(service.cancel()),
                ),
              ] else if (service.status(dependency) !=
                  DependencyStatus.installed)
                IosTileButton(
                  key: const ValueKey('environment-dependency-install'),
                  icon: Lucide.Download,
                  label: service.failure == DependencyFailure.install
                      ? l10n.workspaceEnvRetry
                      : l10n.workspaceEnvInstall,
                  enabled: enabled,
                  backgroundColor: cs.primary,
                  onTap: () => unawaited(service.install(dependency)),
                ),
              if (service.log.isNotEmpty &&
                  service.lastAttempt == dependency) ...[
                IosSectionHeader(text: l10n.workspaceEnvDependencyLog),
                _InstallationLog(text: service.log),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _InstallationLog extends StatefulWidget {
  const _InstallationLog({required this.text});

  final String text;

  @override
  State<_InstallationLog> createState() => _InstallationLogState();
}

class _InstallationLogState extends State<_InstallationLog> {
  final _scrollController = ScrollController();
  bool _followTail = true;
  bool _scrollScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_trackPosition);
    _scrollToTail();
  }

  @override
  void didUpdateWidget(covariant _InstallationLog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) _scrollToTail();
  }

  void _trackPosition() {
    _followTail = _scrollController.position.extentAfter <= 24;
  }

  void _scrollToTail() {
    if (!_followTail || _scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted || !_followTail || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SectionCard(
      child: SizedBox(
        key: const ValueKey('environment-dependency-log'),
        height: 240,
        width: double.infinity,
        child: Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            primary: false,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              widget.text,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
