import 'package:Kelivo/core/services/sandbox/environment_dependencies.dart';
import 'package:Kelivo/core/services/sandbox/environment_installer.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/features/workspace/pages/external_mounts_page.dart';
import 'package:Kelivo/features/workspace/pages/environment_download_page.dart';
import 'package:Kelivo/features/workspace/pages/proot_options_page.dart';
import 'package:Kelivo/features/workspace/widgets/files/workspace_prompts.dart';
import 'package:Kelivo/features/workspace/pages/environment_variables_page.dart';
import 'environment_dependencies_section.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';
import 'package:Kelivo/core/services/sandbox/mirror_service.dart';
import 'package:Kelivo/core/services/sandbox/rootfs_disk_usage.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_chrome.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_dialogs.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_keys.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_labels.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/shared/utils/format_bytes.dart';
import 'package:Kelivo/shared/widgets/animated_progress_bar.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

/// Embeddable environment body for the Environment page and desktop settings.
class EnvironmentPane extends StatefulWidget {
  const EnvironmentPane({super.key, this.padding, this.embedded = false});

  static const installKey = EnvironmentPaneKeys.install;
  static const cancelKey = EnvironmentPaneKeys.cancel;
  static const retryKey = EnvironmentPaneKeys.retry;
  static const repairKey = EnvironmentPaneKeys.repair;
  static const resetKey = EnvironmentPaneKeys.reset;
  static const checkUpdateKey = EnvironmentPaneKeys.checkUpdate;
  static const updateKey = EnvironmentPaneKeys.update;
  static const downloadProgressKey = EnvironmentPaneKeys.downloadProgress;
  static const detectingMirrorsKey = EnvironmentPaneKeys.detectingMirrors;
  static const restartBannerKey = EnvironmentPaneKeys.restartBanner;
  static const nativeExplanationKey = EnvironmentPaneKeys.nativeExplanation;
  static const mirrorsSectionKey = EnvironmentPaneKeys.mirrorsSection;
  static const browseKey = EnvironmentPaneKeys.browse;
  static const detectAllKey = EnvironmentPaneKeys.detectAll;
  static const sizeRowKey = EnvironmentPaneKeys.sizeRow;
  static const pathRowKey = EnvironmentPaneKeys.pathRow;
  static const sizeTimeoutKey = EnvironmentPaneKeys.sizeTimeout;
  static const infoCopyKey = EnvironmentPaneKeys.infoCopy;

  static Key detectKey(MirrorCategory category) =>
      EnvironmentPaneKeys.detect(category);

  static Key useMirrorKey(MirrorCategory category) =>
      EnvironmentPaneKeys.useMirror(category);

  /// Tests replace this to avoid [path_provider] platform-channel hangs.
  @visibleForTesting
  static Future<int?> Function()? debugDiskUsage;

  /// Measurement budget. On timeout the size cell shows "—" instead of spinning.
  @visibleForTesting
  static Duration diskUsageTimeout = const Duration(seconds: 20);

  final EdgeInsetsGeometry? padding;
  final bool embedded;

  @override
  State<EnvironmentPane> createState() => _EnvironmentPaneState();
}

class _EnvironmentPaneState extends State<EnvironmentPane> {
  bool _busy = false;
  EnvironmentPhase? _lastDependenciesPhase;
  bool get _dependenciesBusy =>
      context.read<EnvironmentDependencies?>()?.busy ?? false;
  bool _checkedUpdate = false;
  int? _diskUsageBytes;
  String? _rootfsPath;
  bool _diskUsageTimedOut = false;
  bool _sizeLoading = false;
  bool _seededDisk = false;
  EnvironmentPhase? _lastDiskPhase;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final runtime = context.read<WorkspaceRuntimeProvider>();
      if (runtime.lastStatus == null) {
        unawaited(runtime.refresh());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final env = context.read<EnvironmentProvider>();
    if (!_seededDisk) {
      _seededDisk = true;
      _rootfsPath = env.state.rootfsDir;
      final cached = env.cachedDiskBytes;
      if (cached != null) {
        _diskUsageBytes = cached;
      }
    }
    _maybeRefreshDisk(env.state.phase);
  }

  Future<void> _loadDiskUsage({bool force = false}) async {
    if (_sizeLoading) return;
    if (force) {
      _diskUsageTimedOut = false;
    }
    _sizeLoading = true;
    try {
      final env = context.read<EnvironmentProvider>();
      final state = env.state;
      final override = EnvironmentPane.debugDiskUsage;

      String? displayPath = state.rootfsDir;
      String? usagePath;
      if (override == null) {
        try {
          usagePath = (await resolveRootfsUsageDir(
            rootfsDir: state.rootfsDir,
          ).timeout(const Duration(seconds: 2))).path;
        } catch (_) {}
      }
      if (displayPath == null || displayPath.isEmpty) {
        displayPath = usagePath;
      }
      if (mounted && displayPath != null && displayPath != _rootfsPath) {
        setState(() => _rootfsPath = displayPath);
      }

      final cached = env.cachedDiskBytesFor(usagePath ?? displayPath);
      if (mounted && cached != null && _diskUsageBytes == null) {
        setState(() {
          _diskUsageBytes = cached;
          _diskUsageTimedOut = false;
        });
      }

      try {
        final bytes = override != null
            ? await override()
            : await _computeDiskUsage().timeout(
                EnvironmentPane.diskUsageTimeout,
              );
        if (!mounted) return;
        if (bytes == null) {
          if (_diskUsageBytes == null) {
            setState(() => _diskUsageTimedOut = true);
          }
          return;
        }
        setState(() {
          _diskUsageBytes = bytes;
          _diskUsageTimedOut = false;
          if (displayPath != null) _rootfsPath = displayPath;
        });
        if (override == null) {
          unawaited(
            env.setCachedDiskUsage(
              bytes: bytes,
              root: usagePath ?? displayPath,
            ),
          );
        }
      } on TimeoutException {
        if (!mounted) return;
        if (_diskUsageBytes == null) {
          setState(() => _diskUsageTimedOut = true);
        }
      }
    } catch (_) {
      // path_provider is unavailable in some tests; keep the cached value.
      if (mounted && _diskUsageBytes == null) {
        setState(() => _diskUsageTimedOut = true);
      }
    } finally {
      _sizeLoading = false;
    }
  }

  Future<int> _computeDiskUsage() async {
    final rootfsDir = context.read<EnvironmentProvider>().state.rootfsDir;
    final dir = await resolveRootfsUsageDir(
      rootfsDir: rootfsDir,
    ).timeout(const Duration(seconds: 2));
    final sw = Stopwatch()..start();
    final bytes = await measureDirectorySize(dir);
    debugPrint(
      'workspace disk usage: $bytes bytes in ${sw.elapsedMilliseconds}ms '
      'path=${dir.path}',
    );
    return bytes;
  }

  void _maybeRefreshDisk(EnvironmentPhase phase) {
    if (_lastDiskPhase == phase) return;
    _lastDiskPhase = phase;
    if (phase == EnvironmentPhase.ready ||
        phase == EnvironmentPhase.notInstalled) {
      unawaited(_loadDiskUsage(force: true));
    }
  }

  Future<void> _refreshRuntime() async {
    if (!mounted) return;
    await context.read<WorkspaceRuntimeProvider>().refresh();
  }

  Future<void> _install() async {
    final manager = context.read<EnvironmentManager?>();
    if (manager == null || _busy || _dependenciesBusy) return;
    setState(() => _busy = true);
    try {
      if (manager is EnvironmentInstaller) {
        final confirmed = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) =>
                EnvironmentDownloadPage(installer: manager, install: true),
          ),
        );
        if (confirmed != true || !mounted) return;
        if (await manager.rootfsDir.exists()) {
          if (!mounted) return;
          final l10n = AppLocalizations.of(context)!;
          final replace = await showWorkspaceConfirm(
            context: context,
            title: l10n.workspaceEnvReplaceSystem,
            message: l10n.workspaceEnvReplaceSystemHint,
            confirmLabel: l10n.workspaceEnvReplaceSystem,
            destructive: true,
          );
          if (!replace || !mounted) return;
        }
      }
      await manager.install();
      await _refreshRuntime();
      if (!mounted) return;
      if (manager is EnvironmentInstaller &&
          manager.env.state.phase == EnvironmentPhase.ready &&
          manager.env.state.errorMessage != null) {
        showAppSnackBar(
          context,
          message: workspaceEnvErrorMessage(
            AppLocalizations.of(context)!,
            manager.env.state.errorMessage,
          ),
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final manager = context.read<EnvironmentManager?>();
    if (manager == null) return;
    await manager.cancel();
  }

  Future<void> _repair() async {
    final manager = context.read<EnvironmentManager?>();
    if (manager == null || _busy || _dependenciesBusy) return;
    setState(() => _busy = true);
    try {
      await manager.repair();
      await _refreshRuntime();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final manager = context.read<EnvironmentManager?>();
    if (manager == null || _busy || _dependenciesBusy) return;
    final confirmed = await confirmEnvironmentReset(context);
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final env = context.read<EnvironmentProvider>();
    try {
      await manager.reset();
      unawaited(env.clearCachedDiskUsage());
      await _refreshRuntime();
      if (mounted) {
        setState(() {
          _diskUsageBytes = null;
          _diskUsageTimedOut = false;
        });
        unawaited(_loadDiskUsage(force: true));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkForUpdate() async {
    final manager = context.read<EnvironmentManager?>();
    if (manager == null || _busy || _dependenciesBusy) return;
    final available = context
        .read<EnvironmentProvider>()
        .state
        .availableVersion;
    if (available != null && available.isNotEmpty) {
      await _install();
      return;
    }
    setState(() => _busy = true);
    try {
      final found = await manager.checkForUpdate();
      if (!mounted) return;
      setState(() => _checkedUpdate = true);
      if (!found) {
        showAppSnackBar(
          context,
          message: AppLocalizations.of(context)!.workspaceEnvUpToDate,
          type: NotificationType.info,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: AppLocalizations.of(context)!.workspaceEnvPathCopied,
      type: NotificationType.success,
    );
  }

  Future<void> _detectAll() async {
    final mirrors = context.read<MirrorService?>();
    final manager = context.read<EnvironmentManager?>();
    if (mirrors == null || manager == null || _busy) return;
    await runDetectFastMirrors(
      context: context,
      mirrors: mirrors,
      categories: manager.mirrorCategories,
    );
  }

  @override
  Widget build(BuildContext context) {
    final environment = context.watch<EnvironmentProvider>();
    final dependencies = context.watch<EnvironmentDependencies?>();
    if (dependencies != null &&
        _lastDependenciesPhase != environment.state.phase) {
      _lastDependenciesPhase = environment.state.phase;
      if (environment.state.phase == EnvironmentPhase.ready) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(dependencies.refresh());
        });
      }
    }
    context.watch<WorkspaceRuntimeProvider>();
    context.watch<EnvironmentManager?>();
    context.watch<MirrorService?>();
    final padding = widget.padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 16);
    final children = workspaceEnvIsDesktopTarget()
        ? _nativeChildren()
        : _sandboxChildren();
    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
    }
    return ListView(padding: padding, children: children);
  }

  List<Widget> _nativeChildren() {
    final l10n = AppLocalizations.of(context)!;
    final shell = workspaceEnvNativeShellPath();
    return [
      _StatusCard(
        diskUsageBytes: null,
        rootfsPath: shell,
        desktopNative: true,
        onCopyPath: () => unawaited(_copyPath(shell)),
      ),
      KeyedSubtree(
        key: EnvironmentPane.nativeExplanationKey,
        child: IosSectionFooter(text: l10n.workspaceEnvNativeExplanation),
      ),
      IosSectionFooter(text: l10n.workspaceEnvNativeUnsandboxed),
      ..._variablesSection(),
    ];
  }

  List<Widget> _sandboxChildren() {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<EnvironmentProvider>().state;
    context.watch<WorkspaceRuntimeProvider>();
    final manager = context.watch<EnvironmentManager?>();
    final dependencies = context.watch<EnvironmentDependencies?>();
    final busy = _busy || (dependencies?.busy ?? false);
    final ready = state.phase == EnvironmentPhase.ready;
    final showBrowse = ready && !workspaceEnvIsDesktopTarget();
    final showExternalMounts = WorkspaceChannel.isSupportedPlatform;
    final showMirrors = ready && manager != null;
    final showActions =
        manager != null &&
        (ready ||
            state.phase == EnvironmentPhase.needsRestart ||
            state.phase == EnvironmentPhase.error);

    return [
      _StatusCard(
        diskUsageBytes: _diskUsageBytes,
        diskUsageTimedOut: _diskUsageTimedOut,
        rootfsPath: _rootfsPath,
        busy: busy,
        onInstall: () => unawaited(_install()),
        onCancel: () => unawaited(_cancel()),
        onRetry: () => unawaited(_install()),
        onCopyPath: _rootfsPath == null
            ? null
            : () => unawaited(_copyPath(_rootfsPath!)),
      ),
      if (showBrowse || showExternalMounts) ...[
        IosSectionHeader(text: l10n.workspaceEnvBrowseSection),
        SectionCard(
          children: [
            if (showBrowse)
              KeyedSubtree(
                key: EnvironmentPane.browseKey,
                child: IosNavRow(
                  icon: Lucide.HardDrive,
                  label: l10n.workspaceEnvBrowseFiles,
                  subtitle: l10n.workspaceEnvBrowseFilesDetail,
                  onTap: () => unawaited(openRootfsBrowserPage(context)),
                ),
              ),
            if (showBrowse && showExternalMounts) const IosRowDivider(),
            if (showExternalMounts)
              IosNavRow(
                icon: Lucide.FolderOpen,
                label: l10n.workspaceExternalMount,
                subtitle: l10n.workspaceExternalMountSubtitle,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ExternalMountsPage(),
                  ),
                ),
              ),
          ],
        ),
      ],
      if (showMirrors)
        _MirrorsSection(
          busy: busy,
          onDetectAll: () => unawaited(_detectAll()),
          onOpenCategory: (category) =>
              unawaited(openMirrorPage(context, category: category)),
        ),
      if (dependencies != null && dependencies.supportsPackages)
        EnvironmentDependenciesSection(
          service: dependencies,
          enabled: ready && !_busy,
        ),
      ..._variablesSection(),
      if (showActions) ...[
        IosSectionHeader(text: l10n.workspaceEnvActionsSection),
        SectionCard(
          children: [
            if (ready) ...[
              KeyedSubtree(
                key: EnvironmentPane.repairKey,
                child: IosNavRow(
                  icon: Lucide.Wrench,
                  label: l10n.workspaceEnvRepair,
                  subtitle: l10n.workspaceEnvRepairDetail,
                  trailing: const SizedBox.shrink(),
                  onTap: busy ? null : () => unawaited(_repair()),
                ),
              ),
              const IosRowDivider(),
              KeyedSubtree(
                key: EnvironmentPane.checkUpdateKey,
                child: KeyedSubtree(
                  key:
                      state.availableVersion != null &&
                          state.availableVersion!.isNotEmpty
                      ? EnvironmentPane.updateKey
                      : const ValueKey<String>('workspace-env-check-only'),
                  child: IosNavRow(
                    icon: Lucide.RotateCcw,
                    label: l10n.workspaceEnvCheckForUpdate,
                    subtitle: _updateDetail(l10n, state),
                    trailing: const SizedBox.shrink(),
                    onTap: busy ? null : () => unawaited(_checkForUpdate()),
                  ),
                ),
              ),
              const IosRowDivider(),
            ],
            KeyedSubtree(
              key: EnvironmentPane.resetKey,
              child: IosNavRow(
                icon: Lucide.Trash2,
                label: l10n.workspaceEnvReset,
                destructive: true,
                trailing: const SizedBox.shrink(),
                onTap: busy ? null : () => unawaited(_reset()),
              ),
            ),
          ],
        ),
      ],
      if (manager is EnvironmentInstaller) ...[
        IosSectionHeader(text: l10n.workspaceEnvSystemImage),
        SectionCard(
          children: [
            IosNavRow(
              key: const ValueKey('environment-download-source'),
              icon: Lucide.Download,
              label: ready
                  ? l10n.workspaceEnvReplaceSystem
                  : l10n.workspaceEnvSystemImage,
              subtitle: environmentDownloadSourceLabel(
                l10n,
                context.watch<EnvironmentProvider>().downloadSource,
              ),
              onTap: busy ? null : () => unawaited(_install()),
            ),
            const IosRowDivider(),
            IosNavRow(
              key: const ValueKey('environment-proot-options'),
              icon: Lucide.Terminal,
              label: l10n.workspaceEnvProotOptions,
              onTap: busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProotOptionsPage(),
                      ),
                    ),
            ),
          ],
        ),
      ],
      IosSectionFooter(text: l10n.workspaceEnvInfoBody),
    ];
  }

  List<Widget> _variablesSection() {
    final l10n = AppLocalizations.of(context)!;
    return [
      IosSectionHeader(text: l10n.workspaceEnvVariablesTitle),
      SectionCard(
        children: [
          IosNavRow(
            key: const ValueKey('environment-variables-entry'),
            icon: Lucide.KeyRound,
            label: l10n.workspaceEnvVariablesTitle,
            subtitle: l10n.workspaceEnvVariablesEntryDetail,
            onTap: () => openEnvironmentVariablesPage(context),
          ),
        ],
      ),
    ];
  }

  String? _updateDetail(AppLocalizations l10n, EnvironmentState state) {
    final available = state.availableVersion;
    if (available != null && available.isNotEmpty) {
      return l10n.workspaceEnvUpdateAvailableShort(available);
    }
    if (_checkedUpdate) return l10n.workspaceEnvUpdateCurrent;
    return null;
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    this.diskUsageBytes,
    this.diskUsageTimedOut = false,
    this.rootfsPath,
    this.desktopNative = false,
    this.busy = false,
    this.onInstall,
    this.onCancel,
    this.onRetry,
    this.onCopyPath,
  });

  final int? diskUsageBytes;
  final bool diskUsageTimedOut;
  final String? rootfsPath;
  final bool desktopNative;
  final bool busy;
  final VoidCallback? onInstall;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onCopyPath;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final env = context.watch<EnvironmentProvider>();
    final runtime = context.watch<WorkspaceRuntimeProvider>();
    final state = env.state;
    final status = runtime.lastStatus;
    final engine = workspaceEnvEngineLabel(
      l10n: l10n,
      state: state,
      status: status,
    );
    final icon = workspaceEnvEngineIcon(
      state: state,
      status: status,
      desktopNative: desktopNative,
    );

    final installing =
        state.phase == EnvironmentPhase.downloading ||
        state.phase == EnvironmentPhase.verifying ||
        state.phase == EnvironmentPhase.extracting ||
        state.phase == EnvironmentPhase.patching;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IosSectionHeader(text: l10n.workspaceEnvTitle, first: true),
        SectionCard(
          children: [
            IosNavRow(
              icon: icon,
              label: engine,
              subtitle: desktopNative
                  ? null
                  : workspaceEnvPhaseLabel(l10n, state.phase),
              trailing: const SizedBox.shrink(),
            ),
            if (desktopNative) ...[
              const IosRowDivider(),
              EnvironmentMetricRow(
                label: l10n.workspaceEnvPathLabel,
                onTap: onCopyPath,
                value: Text(
                  workspaceEnvMiddleTruncate(rootfsPath ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: cs.onSurface,
                  ),
                ),
              ),
            ] else if (state.phase == EnvironmentPhase.notInstalled)
              _NotInstalledBody(busy: busy, onInstall: onInstall)
            else if (installing)
              _InstallingBody(state: state, onCancel: onCancel)
            else if (state.phase == EnvironmentPhase.error)
              _ErrorBody(state: state, busy: busy, onRetry: onRetry)
            else if (state.phase == EnvironmentPhase.needsRestart)
              const _RestartBanner()
            else ...[
              const IosRowDivider(),
              EnvironmentMetricRow(
                label: l10n.workspaceEnvStatusLabel,
                value: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.workspaceEnvStatusInstalled,
                      style: TextStyle(fontSize: 14, color: cs.onSurface),
                    ),
                    const SizedBox(width: 6),
                    Icon(Lucide.Check, size: 16, color: colors.success),
                  ],
                ),
              ),
              const IosRowDivider(),
              KeyedSubtree(
                key: EnvironmentPane.sizeRowKey,
                child: EnvironmentMetricRow(
                  label: l10n.workspaceEnvSizeLabel,
                  value: _sizeValue(context, l10n, cs),
                ),
              ),
              if (useDesktopWorkspaceLayout(context) &&
                  rootfsPath != null &&
                  rootfsPath!.isNotEmpty) ...[
                const IosRowDivider(),
                KeyedSubtree(
                  key: EnvironmentPane.pathRowKey,
                  child: EnvironmentMetricRow(
                    label: l10n.workspaceEnvPathLabel,
                    onTap: onCopyPath,
                    value: Text(
                      workspaceEnvMiddleTruncate(rootfsPath!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
              if (state.installedAt != null) ...[
                const IosRowDivider(),
                EnvironmentMetricRow(
                  label: l10n.workspaceEnvInstalledAtLabel,
                  value: Text(
                    workspaceEnvRelativeTime(l10n, state.installedAt!),
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                  ),
                ),
              ],
              if (state.arch != null && state.arch!.isNotEmpty) ...[
                const IosRowDivider(),
                EnvironmentMetricRow(
                  label: l10n.workspaceEnvArchLabel,
                  value: Text(
                    state.version != null && state.version!.isNotEmpty
                        ? l10n.workspaceEnvArchVersion(
                            state.arch!,
                            workspaceEnvDisplayVersion(
                              state.version,
                              fallback: state.version!,
                            ),
                          )
                        : state.arch!,
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 8),
          ],
        ),
      ],
    );
  }

  Widget _sizeValue(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    if (diskUsageBytes != null) {
      return Text(
        formatBytes(diskUsageBytes!),
        style: TextStyle(fontSize: 14, color: cs.onSurface),
      );
    }
    if (diskUsageTimedOut) {
      return Tooltip(
        message: l10n.workspaceEnvSizeTimeout,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '—',
              key: EnvironmentPane.sizeTimeoutKey,
              style: TextStyle(fontSize: 14, color: cs.onSurface),
            ),
            Text(
              l10n.workspaceEnvSizeTimeout,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }
    return const EnvironmentInlineSpinner();
  }
}

class _NotInstalledBody extends StatelessWidget {
  const _NotInstalledBody({required this.busy, required this.onInstall});

  final bool busy;
  final VoidCallback? onInstall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.workspaceEnvInstallDescription,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: cs.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            defaultTargetPlatform == TargetPlatform.iOS
                ? l10n.workspaceEnvInstallSubtitleIos
                : l10n.workspaceEnvInstallSubtitleAndroid,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: EnvironmentPane.installKey,
            child: IosTileButton(
              icon: Lucide.Download,
              label: l10n.workspaceEnvInstallEnvironment,
              backgroundColor: cs.primary,
              enabled: !busy && onInstall != null,
              onTap: onInstall ?? () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallingBody extends StatelessWidget {
  const _InstallingBody({required this.state, required this.onCancel});

  final EnvironmentState state;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final phase = workspaceEnvPhaseLabel(l10n, state.phase);
    final downloaded = state.bytesDownloaded;
    final total = state.bytesTotal;
    final showBytes = downloaded != null && total != null && total > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedProgressBar(fraction: workspaceEnvProgressFraction(state)),
          const SizedBox(height: 8),
          Text(
            key: EnvironmentPane.downloadProgressKey,
            showBytes
                ? l10n.workspaceEnvDownloadLine(
                    formatBytes(downloaded),
                    formatBytes(total),
                    phase,
                  )
                : phase,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (state.phase == EnvironmentPhase.downloading &&
              onCancel != null) ...[
            const SizedBox(height: 12),
            KeyedSubtree(
              key: EnvironmentPane.cancelKey,
              child: IosTileButton(
                icon: Lucide.X,
                label: l10n.workspaceEnvCancel,
                onTap: onCancel!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.state,
    required this.busy,
    required this.onRetry,
  });

  final EnvironmentState state;
  final bool busy;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            workspaceEnvErrorMessage(l10n, state.errorMessage),
            style: TextStyle(fontSize: 14, height: 1.35, color: cs.error),
          ),
          if (workspaceEnvIsInsufficientDisk(state.errorMessage)) ...[
            const SizedBox(height: 8),
            Text(
              l10n.workspaceEnvErrorInsufficientDiskHint,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
          const SizedBox(height: 12),
          KeyedSubtree(
            key: EnvironmentPane.retryKey,
            child: IosTileButton(
              icon: Lucide.RotateCcw,
              label: l10n.workspaceEnvRetry,
              backgroundColor: cs.primary,
              enabled: !busy && onRetry != null,
              onTap: onRetry ?? () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _RestartBanner extends StatelessWidget {
  const _RestartBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Padding(
      key: EnvironmentPane.restartBannerKey,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Icon(Lucide.TriangleAlert, size: 18, color: colors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.workspaceEnvRestartDoneBanner,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFontWeights.medium,
                    color: colors.onWarningContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 180));
  }
}

class _MirrorsSection extends StatelessWidget {
  const _MirrorsSection({
    required this.busy,
    required this.onDetectAll,
    required this.onOpenCategory,
  });

  final bool busy;
  final VoidCallback onDetectAll;
  final ValueChanged<MirrorCategory> onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<EnvironmentManager?>();
    if (manager == null) return const SizedBox.shrink();
    final categories = manager.mirrorCategories.toList();
    final l10n = AppLocalizations.of(context)!;
    final env = context.watch<EnvironmentProvider>();

    return Column(
      key: EnvironmentPane.mirrorsSectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IosSectionHeader(text: l10n.workspaceEnvMirrorsSection),
        SectionCard(
          children: [
            KeyedSubtree(
              key: EnvironmentPane.detectAllKey,
              child: IosNavRow(
                icon: Lucide.Gauge,
                label: l10n.workspaceEnvDetectFastMirrors,
                trailing: const SizedBox.shrink(),
                onTap: busy ? null : onDetectAll,
              ),
            ),
            for (final category in categories) ...[
              const IosRowDivider(),
              KeyedSubtree(
                key: EnvironmentPane.detectKey(category),
                child: IosNavRow(
                  icon: _categoryIcon(category),
                  label: workspaceEnvCategoryLabel(l10n, category),
                  detailText: workspaceEnvSelectionLabel(
                    l10n,
                    env.mirrors[category],
                    category: category,
                  ),
                  onTap: busy ? null : () => onOpenCategory(category),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  IconData _categoryIcon(MirrorCategory category) {
    switch (category) {
      case MirrorCategory.apk:
      case MirrorCategory.apt:
        return Lucide.Package;
      case MirrorCategory.pip:
        return Lucide.Braces;
      case MirrorCategory.npm:
        return Lucide.Boxes;
    }
  }
}
