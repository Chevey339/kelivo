import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../models/terminal_runtime_state.dart';
import '../services/terminal_native_bridge.dart';
import 'terminal_page.dart';

class TerminalManagementPage extends StatefulWidget {
  const TerminalManagementPage({super.key, TerminalNativeBridge? bridge})
    : _bridge = bridge;

  final TerminalNativeBridge? _bridge;

  @override
  State<TerminalManagementPage> createState() => _TerminalManagementPageState();
}

class _TerminalManagementPageState extends State<TerminalManagementPage> {
  static const _defaultManifestUrl =
      'https://cdn.psycheas.top/ios-alpine-arm64/stable.json';

  late final TerminalNativeBridge _bridge =
      widget._bridge ?? TerminalNativeBridge();
  late Future<TerminalRuntimeState> _statusFuture;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _statusFuture = _bridge.getRuntimeStatus();
  }

  void _refresh() {
    setState(() {
      _statusFuture = _bridge.getRuntimeStatus();
    });
  }

  Future<void> _installRuntime() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _installing = true);
    try {
      await _bridge.installRuntime(manifestUrl: _defaultManifestUrl);
      if (mounted) _refresh();
    } on TerminalNativeBridgeException catch (error) {
      if (!mounted) return;
      _showSnack(l10n.terminalManagementNativeActionFailed(error.code));
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  void _showUnavailable() {
    _showSnack(
      AppLocalizations.of(context)!.terminalManagementActionUnavailable,
    );
  }

  Future<void> _showDiagnosticLog() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final log = await _bridge.getDiagnosticLog();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final text = log.trim().isEmpty
              ? l10n.terminalManagementDiagnosticLogEmpty
              : log;
          return AlertDialog(
            title: Text(l10n.terminalManagementDiagnosticLogTitle),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: SelectableText(
                  text,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.terminalManagementDiagnosticLogClose),
              ),
              TextButton(
                onPressed: log.trim().isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: log));
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        _showSnack(l10n.chatMessageWidgetCopiedToClipboard);
                      },
                child: Text(l10n.terminalManagementDiagnosticLogCopy),
              ),
            ],
          );
        },
      );
    } on TerminalNativeBridgeException catch (error) {
      if (!mounted) return;
      _showSnack(l10n.terminalManagementNativeActionFailed(error.code));
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: IosIconButton(
            icon: Lucide.ArrowLeft,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.terminalManagementPageTitle),
        actions: [
          Tooltip(
            message: l10n.terminalManagementRefreshTooltip,
            child: IosIconButton(icon: Lucide.RefreshCw, onTap: _refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<TerminalRuntimeState>(
        future: _statusFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            final code = snapshot.error is TerminalNativeBridgeException
                ? (snapshot.error! as TerminalNativeBridgeException).code
                : 'unknown';
            return _LoadErrorView(
              message: l10n.terminalManagementStatusLoadFailed(code),
              onRetry: _refresh,
            );
          }

          final state = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                l10n.terminalManagementIntro,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                context,
                children: [
                  _StatusHeader(state: state),
                  _divider(context),
                  _InfoRow(
                    label: l10n.terminalManagementNativeRuntime,
                    value: _integrationStatusLabel(
                      l10n,
                      state.integrationStatus,
                    ),
                  ),
                  _InfoRow(
                    label: l10n.terminalManagementRuntimeId,
                    value:
                        state.runtimeId ?? l10n.terminalManagementNotAvailable,
                  ),
                  _InfoRow(
                    label: l10n.terminalManagementIntegrationReference,
                    value:
                        state.integrationReference ??
                        l10n.terminalManagementNotAvailable,
                  ),
                  _InfoRow(
                    label: l10n.terminalManagementRuntimeStatus,
                    value: _statusLabel(l10n, state.status),
                  ),
                  _InfoRow(
                    label: l10n.terminalManagementRuntimeVersion,
                    value: state.version ?? l10n.terminalManagementNotInstalled,
                  ),
                  _InfoRow(
                    label: l10n.terminalManagementPackageSource,
                    value:
                        state.packageSource ??
                        l10n.terminalManagementDefaultPackageSource,
                  ),
                  _InfoRow(
                    label: l10n.terminalManagementRootfsSize,
                    value: _formatBytes(state.rootfsBytes),
                  ),
                  _InfoRow(
                    label: l10n.terminalManagementHomeSize,
                    value: _formatBytes(state.homeBytes),
                  ),
                  _InfoRow(
                    label: l10n.terminalManagementCacheSize,
                    value: _formatBytes(state.cacheBytes),
                  ),
                  _InfoRow(
                    label: l10n.terminalManagementBackupSize,
                    value: _formatBytes(state.backupBytes),
                  ),
                  _InfoRow(
                    label: l10n.terminalManagementTotalSize,
                    value: _formatBytes(state.totalBytes),
                  ),
                  _InfoRow(
                    label: l10n.terminalManagementLastInstallTime,
                    value: _formatDate(context, state.lastInstallOrUpdateTime),
                  ),
                  _InfoRow(
                    label: l10n.terminalManagementLastError,
                    value: state.lastError ?? l10n.terminalManagementNoError,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionHeader(text: l10n.terminalManagementPrimaryActions),
              _sectionCard(
                context,
                children: [
                  _ActionRow(
                    icon: Lucide.Download,
                    label: _installing
                        ? l10n.terminalManagementInstalling
                        : l10n.terminalManagementInstallRuntime,
                    enabled: !_installing && state.canInstall,
                    onTap: _installRuntime,
                  ),
                  _divider(context),
                  _ActionRow(
                    icon: Lucide.Terminal,
                    label: l10n.terminalManagementOpenTerminal,
                    enabled: state.canOpenSession,
                    onTap: () async {
                      await _bridge.appendDiagnostic(
                        'TerminalManagementPage open terminal tapped',
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TerminalPage(bridge: _bridge),
                        ),
                      );
                    },
                  ),
                  _divider(context),
                  _ActionRow(
                    icon: Lucide.Folder,
                    label: l10n.terminalManagementBrowseFiles,
                    enabled: false,
                    onTap: _showUnavailable,
                  ),
                  _divider(context),
                  _ActionRow(
                    icon: Lucide.databaseBackup,
                    label: l10n.terminalManagementBackupData,
                    enabled: false,
                    onTap: _showUnavailable,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionHeader(text: l10n.terminalManagementDiagnostics),
              _sectionCard(
                context,
                children: [
                  _ActionRow(
                    icon: Lucide.FileText,
                    label: l10n.terminalManagementExportDiagnosticLog,
                    enabled: true,
                    onTap: _showDiagnosticLog,
                  ),
                  _divider(context),
                  _ActionRow(
                    icon: Lucide.Eraser,
                    label: l10n.terminalManagementClearInstallerCache,
                    enabled: false,
                    onTap: _showUnavailable,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatBytes(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(2)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  String _formatDate(BuildContext context, DateTime? date) {
    if (date == null) {
      return AppLocalizations.of(context)!.terminalManagementNever;
    }
    return DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).add_Hm().format(date.toLocal());
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.state});

  final TerminalRuntimeState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final color = _statusColor(cs, state.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(Lucide.Terminal, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.terminalManagementRuntimeStatus,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _statusLabel(l10n, state.status),
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(ColorScheme cs, TerminalRuntimeStatus status) {
    switch (status) {
      case TerminalRuntimeStatus.installed:
      case TerminalRuntimeStatus.updateAvailable:
        return cs.primary;
      case TerminalRuntimeStatus.installing:
        return cs.tertiary;
      case TerminalRuntimeStatus.failed:
      case TerminalRuntimeStatus.repairRequired:
        return cs.error;
      case TerminalRuntimeStatus.notInstalled:
        return cs.onSurface.withValues(alpha: 0.65);
    }
  }
}

String _statusLabel(AppLocalizations l10n, TerminalRuntimeStatus status) {
  switch (status) {
    case TerminalRuntimeStatus.notInstalled:
      return l10n.terminalStatusNotInstalled;
    case TerminalRuntimeStatus.installing:
      return l10n.terminalStatusInstalling;
    case TerminalRuntimeStatus.installed:
      return l10n.terminalStatusInstalled;
    case TerminalRuntimeStatus.updateAvailable:
      return l10n.terminalStatusUpdateAvailable;
    case TerminalRuntimeStatus.repairRequired:
      return l10n.terminalStatusRepairRequired;
    case TerminalRuntimeStatus.failed:
      return l10n.terminalStatusFailed;
  }
}

String _integrationStatusLabel(
  AppLocalizations l10n,
  TerminalRuntimeIntegrationStatus status,
) {
  switch (status) {
    case TerminalRuntimeIntegrationStatus.missingSource:
      return l10n.terminalIntegrationMissingSource;
    case TerminalRuntimeIntegrationStatus.missingBuildTools:
      return l10n.terminalIntegrationMissingBuildTools;
    case TerminalRuntimeIntegrationStatus.notLinked:
      return l10n.terminalIntegrationNotLinked;
    case TerminalRuntimeIntegrationStatus.linked:
      return l10n.terminalIntegrationLinked;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = enabled
        ? cs.onSurface.withValues(alpha: 0.92)
        : cs.onSurface.withValues(alpha: 0.35);
    return IosCardPress(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.zero,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(Lucide.ChevronRight, size: 16, color: color),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cs.onSurface.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Lucide.MessageCircleWarning, color: cs.error, size: 28),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(l10n.terminalManagementRetry),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _sectionCard(BuildContext context, {required List<Widget> children}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;
  return Container(
    decoration: BoxDecoration(
      color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: cs.outlineVariant.withValues(alpha: isDark ? 0.08 : 0.06),
        width: 0.6,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

Widget _divider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(
    height: 1,
    thickness: 0.6,
    indent: 12,
    endIndent: 12,
    color: cs.outlineVariant.withValues(alpha: 0.18),
  );
}
