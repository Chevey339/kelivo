import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/startup_failure_report.dart';
import '../../core/database/startup_recovery_service.dart';
import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';

export '../../core/database/startup_failure_report.dart'
    show
        StartupFailureReport,
        StartupFailureStage,
        restoreFailureDiagnosticCode;

/// A persistence-free shell used when the startup restore gate fails closed.
///
/// Its first job is evidence, not recovery: a fail-closed startup that cannot
/// explain itself leaves the user with nothing but a reset button, which is
/// exactly the action that destroys the evidence. So the screen shows the
/// unwrapped error, collects what the data directory looks like, writes both
/// to a log file, and only then offers actions — ordered from harmless to
/// irreversible.
/// Resolves the running build's version for the diagnostics card.
typedef StartupAppVersionLoader =
    Future<({String? version, String? build})> Function();

class RestoreFailureScreen extends StatefulWidget {
  const RestoreFailureScreen({
    super.key,
    required this.report,
    required this.restart,
    this.appDataDirectory,
    this.appVersionLoader,
  });

  final StartupFailureReport report;
  final Future<void> Function() restart;

  /// Overridable so widget tests do not have to wait on a platform channel.
  final StartupAppVersionLoader? appVersionLoader;

  /// When provided (and the failure is not a lease conflict), the screen
  /// offers file-level recovery actions so a fail-closed startup can never be
  /// a permanent lockout.
  final Directory? appDataDirectory;

  @override
  State<RestoreFailureScreen> createState() => _RestoreFailureScreenState();
}

class _RestoreFailureScreenState extends State<RestoreFailureScreen> {
  late StartupFailureReport _report = widget.report;
  bool _collectingDiagnostics = true;
  File? _savedReport;

  bool _restarting = false;
  bool _restartFailed = false;
  bool _copied = false;
  bool _recoveryBusy = false;
  bool _detailsExpanded = false;
  bool _dangerExpanded = false;
  String? _recoveryMessage;
  bool _recoveryMessageIsError = false;
  StartupIntegrityResult? _integrity;
  String? _integrityError;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  bool get _isLeaseUnavailable =>
      _report.diagnosticCode == 'RestoreBusinessLeaseUnavailable';

  bool get _busy => _restarting || _recoveryBusy;

  @override
  void initState() {
    super.initState();
    unawaitedCollect();
  }

  /// Fills the report in with everything that needs I/O, then persists it.
  /// Deliberately fire-and-forget: the screen is already useful without it.
  void unawaitedCollect() {
    () async {
      final loaded = await (widget.appVersionLoader ?? _loadAppVersion)();
      final version = loaded.version;
      final build = loaded.build;
      StartupFailureReport report = _report;
      try {
        final environment = await StartupFailureEnvironment.collect(
          appDataDirectory: widget.appDataDirectory,
          appVersion: version,
          buildNumber: build,
        );
        report = _report.withEnvironment(environment);
      } catch (_) {
        // Keep the error-only report rather than showing nothing.
      }
      File? saved;
      final directory = widget.appDataDirectory;
      if (directory != null) {
        saved = await StartupDiagnosticsService.writeFailureReport(
          appDataDirectory: directory,
          text: report.toText(),
        );
      }
      if (!mounted) return;
      setState(() {
        _report = report;
        _savedReport = saved;
        _collectingDiagnostics = false;
      });
    }();
  }

  /// Bounded on purpose: this screen runs before the app is known to be
  /// healthy, and a plugin that never answers must not cost the user the whole
  /// report.
  static Future<({String? version, String? build})> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform().timeout(
        const Duration(seconds: 3),
      );
      return (version: info.version, build: info.buildNumber);
    } catch (_) {
      return (version: null, build: null);
    }
  }

  Future<void> _restart() async {
    if (_busy) return;
    setState(() {
      _restarting = true;
      _restartFailed = false;
    });
    try {
      await widget.restart();
    } catch (error, stackTrace) {
      _reportError(error, stackTrace, 'while restarting after restore failure');
      if (!mounted) return;
      setState(() {
        _restarting = false;
        _restartFailed = true;
      });
    }
  }

  Future<void> _copyReport() async {
    await Clipboard.setData(ClipboardData(text: _report.toText()));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  Future<void> _shareReport() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _recoveryBusy = true;
      _recoveryMessage = null;
    });
    try {
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
        RegExp(r'[:.]'),
        '-',
      );
      final file = File(
        '${Directory.systemTemp.path}/kelivo-startup-failure-$stamp.txt',
      );
      await file.writeAsString(_report.toText(), flush: true);
      if (_isDesktop) {
        final destination = await FilePicker.platform.getDirectoryPath();
        if (destination == null || destination.trim().isEmpty) {
          if (mounted) setState(() => _recoveryBusy = false);
          return;
        }
        final target = File(
          '$destination${Platform.pathSeparator}${_basename(file.path)}',
        );
        await file.copy(target.path);
        _finishRecovery(l10n.startupRecoveryReportSaved(target.path));
      } else {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], subject: _basename(file.path)),
        );
        _finishRecovery(l10n.startupRecoveryReportShared);
      }
    } catch (error) {
      _finishRecovery(l10n.startupRecoveryReportSaveFailed, isError: true);
    }
  }

  Future<void> _exportData() async {
    final directory = widget.appDataDirectory;
    if (directory == null || _busy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _recoveryBusy = true;
      _recoveryMessage = null;
    });
    try {
      if (_isDesktop) {
        final destination = await FilePicker.platform.getDirectoryPath();
        if (destination == null || destination.trim().isEmpty) {
          if (mounted) setState(() => _recoveryBusy = false);
          return;
        }
        final target = await StartupRecoveryService.exportDataCopy(
          appDataDirectory: directory,
          destinationParent: Directory(destination),
        );
        _finishRecovery(l10n.startupRecoveryExportSavedTo(target.path));
        return;
      }
      // Mobile has no folder to hand back, so the copy leaves as one archive
      // through the share sheet. The temporary file is removed either way.
      final archive = await StartupDiagnosticsService.createDataArchive(
        appDataDirectory: directory,
        workingDirectory: Directory(
          '${Directory.systemTemp.path}/kelivo-recovery',
        ),
      );
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(archive.path)],
            subject: _basename(archive.path),
          ),
        );
        _finishRecovery(l10n.startupRecoveryExportSucceeded);
      } finally {
        try {
          await archive.delete();
        } catch (_) {
          // A leftover temp archive is harmless; the OS clears it.
        }
      }
    } catch (error) {
      _finishRecovery(l10n.startupRecoveryExportFailed, isError: true);
    }
  }

  Future<void> _checkIntegrity() async {
    final directory = widget.appDataDirectory;
    if (directory == null || _busy) return;
    setState(() {
      _recoveryBusy = true;
      _recoveryMessage = null;
      _integrity = null;
      _integrityError = null;
    });
    try {
      final result = await StartupDiagnosticsService.checkIntegrity(
        appDataDirectory: directory,
      );
      if (!mounted) return;
      setState(() {
        _recoveryBusy = false;
        _integrity = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _recoveryBusy = false;
        _integrityError = '$error';
      });
    }
  }

  Future<void> _repairAndRestart() async {
    final directory = widget.appDataDirectory;
    if (directory == null || _busy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _recoveryBusy = true;
      _recoveryMessage = null;
      _restartFailed = false;
    });
    try {
      await StartupRecoveryService.repair(appDataDirectory: directory);
      await widget.restart();
      if (!mounted) return;
      setState(() {
        _recoveryBusy = false;
        _restartFailed = true;
      });
    } catch (error, stackTrace) {
      _reportError(error, stackTrace, 'while repairing after startup failure');
      _finishRecovery(l10n.startupRecoveryRepairFailed, isError: true);
    }
  }

  Future<void> _resetAndRestart() async {
    final directory = widget.appDataDirectory;
    if (directory == null || _busy) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ResetConfirmationDialog(l10n: l10n),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _recoveryBusy = true;
      _recoveryMessage = null;
      _restartFailed = false;
    });
    try {
      await StartupRecoveryService.reset(appDataDirectory: directory);
      await widget.restart();
      if (!mounted) return;
      setState(() {
        _recoveryBusy = false;
        _restartFailed = true;
      });
    } catch (error, stackTrace) {
      _reportError(error, stackTrace, 'while resetting after startup failure');
      _finishRecovery(l10n.startupRecoveryResetFailed, isError: true);
    }
  }

  void _finishRecovery(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _recoveryBusy = false;
      _recoveryMessage = message;
      _recoveryMessageIsError = isError;
    });
  }

  void _reportError(Object error, StackTrace stackTrace, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Kelivo restore',
        context: ErrorDescription(context),
      ),
    );
  }

  static String _basename(String path) =>
      path.split(Platform.pathSeparator).last.split('/').last;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final showRecoveryActions =
        widget.appDataDirectory != null && !_isLeaseUnavailable;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
              children: [
                _Header(
                  title: _isLeaseUnavailable
                      ? l10n.backupRestoreBusinessLeaseUnavailableTitle
                      : l10n.backupRestoreFailureTitle,
                  body: _isLeaseUnavailable
                      ? l10n.backupRestoreBusinessLeaseUnavailableContent
                      : l10n.backupRestoreFailureContent,
                ),
                const SizedBox(height: 24),
                _DiagnosticsCard(
                  report: _report,
                  collecting: _collectingDiagnostics,
                  savedReport: _savedReport,
                  expanded: _detailsExpanded,
                  copied: _copied,
                  busy: _busy,
                  onToggleExpanded: () =>
                      setState(() => _detailsExpanded = !_detailsExpanded),
                  onCopy: _copyReport,
                  onShare: _shareReport,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _restart,
                    icon: _restarting
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrimary,
                            ),
                          )
                        : const Icon(Lucide.RefreshCw, size: 18),
                    label: Text(l10n.backupRestoreFailureRestartButton),
                  ),
                ),
                if (_restartFailed) ...[
                  const SizedBox(height: 10),
                  _Notice(text: l10n.restartAppFailedMessage, isError: true),
                ],
                if (showRecoveryActions) ...[
                  const SizedBox(height: 24),
                  _Section(
                    icon: Lucide.HardDrive,
                    title: l10n.startupRecoverySectionDataTitle,
                    description: l10n.startupRecoverySectionDataBody,
                    children: [
                      _ActionTile(
                        icon: Lucide.Download,
                        label: l10n.startupRecoveryExportButton,
                        onPressed: _busy ? null : _exportData,
                        emphasized: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    icon: Lucide.Wrench,
                    title: l10n.startupRecoverySectionRepairTitle,
                    description: l10n.startupRecoverySectionRepairBody,
                    children: [
                      _ActionTile(
                        icon: Lucide.Activity,
                        label: l10n.startupRecoveryIntegrityButton,
                        onPressed: _busy ? null : _checkIntegrity,
                      ),
                      if (_integrity != null || _integrityError != null) ...[
                        const SizedBox(height: 10),
                        _IntegrityResultView(
                          result: _integrity,
                          error: _integrityError,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _ActionTile(
                        icon: Lucide.RotateCcw,
                        label: l10n.startupRecoveryRepairButton,
                        onPressed: _busy ? null : _repairAndRestart,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DangerZone(
                    expanded: _dangerExpanded,
                    busy: _busy,
                    onToggle: () =>
                        setState(() => _dangerExpanded = !_dangerExpanded),
                    onReset: _resetAndRestart,
                  ),
                ],
                if (_recoveryBusy) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.startupRecoveryBusy,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_recoveryMessage != null) ...[
                  const SizedBox(height: 16),
                  _Notice(
                    text: _recoveryMessage!,
                    isError: _recoveryMessageIsError,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Lucide.TriangleAlert,
            size: 26,
            color: colors.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// The part that was missing: what actually failed, in the user's hands.
class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({
    required this.report,
    required this.collecting,
    required this.savedReport,
    required this.expanded,
    required this.copied,
    required this.busy,
    required this.onToggleExpanded,
    required this.onCopy,
    required this.onShare,
  });

  final StartupFailureReport report;
  final bool collecting;
  final File? savedReport;
  final bool expanded;
  final bool copied;
  final bool busy;
  final VoidCallback onToggleExpanded;
  final Future<void> Function() onCopy;
  final Future<void> Function() onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final environment = report.environment;
    final monospace = textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
      height: 1.45,
      color: colors.onSurface,
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Lucide.FileText, size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                l10n.startupRecoveryWhatFailed,
                style: textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(report.summary, style: monospace),
          const SizedBox(height: 14),
          _FactRow(
            label: l10n.startupRecoveryStageLabel,
            value:
                switch (report.stage) {
                  StartupFailureStage.restoreGate =>
                    l10n.startupRecoveryStageRestore,
                  StartupFailureStage.databaseAdmission =>
                    l10n.startupRecoveryStageDatabase,
                } +
                (report.step == null ? '' : ' · ${report.step}'),
          ),
          _FactRow(
            label: l10n.startupRecoveryDiagnosticLabel,
            value: report.diagnosticCode,
            monospace: true,
          ),
          if (environment != null) ...[
            _FactRow(
              label: l10n.startupRecoverySchemaLabel,
              value: l10n.startupRecoverySchemaValue(
                environment.installedSchemaVersion?.toString() ??
                    l10n.startupRecoveryUnknownValue,
                environment.expectedSchemaVersion,
              ),
              highlight: environment.installedSchemaIsBehind,
            ),
            _FactRow(
              label: l10n.startupRecoveryAppVersionLabel,
              value:
                  '${environment.appVersion ?? l10n.startupRecoveryUnknownValue}'
                  '${environment.buildNumber == null ? '' : ' (${environment.buildNumber})'}'
                  ' · ${environment.platform}',
            ),
          ] else if (collecting)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.startupRecoveryCollecting,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: onToggleExpanded,
                icon: Icon(
                  expanded ? Lucide.ChevronDown : Lucide.ChevronRight,
                  size: 16,
                ),
                label: Text(
                  expanded
                      ? l10n.startupRecoveryHideDetails
                      : l10n.startupRecoveryShowDetails,
                ),
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Scrollbar(
                child: SingleChildScrollView(
                  primary: false,
                  child: SelectableText(report.toText(), style: monospace),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: onCopy,
                icon: Icon(copied ? Lucide.Check : Lucide.Copy, size: 16),
                label: Text(
                  copied
                      ? l10n.startupRecoveryReportCopied
                      : l10n.startupRecoveryCopyReport,
                ),
              ),
              TextButton.icon(
                onPressed: busy ? null : () => onShare(),
                icon: const Icon(Lucide.Share2, size: 16),
                label: Text(l10n.startupRecoveryShareReport),
              ),
            ],
          ),
          if (savedReport != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.startupRecoveryReportStored(savedReport!.path),
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.label,
    required this.value,
    this.monospace = false,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool monospace;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: textTheme.bodySmall?.copyWith(
                color: highlight ? colors.primary : colors.onSurface,
                fontWeight: highlight ? FontWeight.w600 : null,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.description,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                title,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: emphasized
          ? FilledButton.tonalIcon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.8),
                ),
              ),
              icon: Icon(icon, size: 18),
              label: Text(label),
            ),
    );
  }
}

class _IntegrityResultView extends StatelessWidget {
  const _IntegrityResultView({required this.result, required this.error});

  final StartupIntegrityResult? result;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final String text;
    final bool healthy;
    if (error != null) {
      text = l10n.startupRecoveryIntegrityFailed;
      healthy = false;
    } else if (result == null) {
      return const SizedBox.shrink();
    } else if (!result!.databasePresent) {
      text = l10n.startupRecoveryIntegrityMissing;
      healthy = false;
    } else if (result!.isHealthy) {
      text = l10n.startupRecoveryIntegrityHealthy;
      healthy = true;
    } else {
      text = l10n.startupRecoveryIntegrityDamaged(result!.describe());
      healthy = false;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        text,
        style: textTheme.bodySmall?.copyWith(
          color: healthy ? colors.primary : colors.error,
          height: 1.45,
        ),
      ),
    );
  }
}

/// Reset stays reachable — a lockout must always have an exit — but it is
/// folded away and confirmed separately so it can never be the first thing a
/// confused user taps.
class _DangerZone extends StatelessWidget {
  const _DangerZone({
    required this.expanded,
    required this.busy,
    required this.onToggle,
    required this.onReset,
  });

  final bool expanded;
  final bool busy;
  final VoidCallback onToggle;
  final Future<void> Function() onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: onToggle,
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
            ),
            icon: Icon(
              expanded ? Lucide.ChevronDown : Lucide.ChevronRight,
              size: 16,
            ),
            label: Text(l10n.startupRecoveryDangerZone),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: colors.errorContainer.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.error.withValues(alpha: 0.35)),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.startupRecoveryDangerBody,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurface,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => onReset(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(
                        color: colors.error.withValues(alpha: 0.5),
                      ),
                    ),
                    icon: const Icon(Lucide.Trash2, size: 18),
                    label: Text(l10n.startupRecoveryResetButton),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ResetConfirmationDialog extends StatefulWidget {
  const _ResetConfirmationDialog({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_ResetConfirmationDialog> createState() =>
      _ResetConfirmationDialogState();
}

class _ResetConfirmationDialogState extends State<_ResetConfirmationDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l10n.startupRecoveryResetDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.startupRecoveryResetDialogContent),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _acknowledged,
            onChanged: (value) =>
                setState(() => _acknowledged = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.startupRecoveryResetAcknowledge),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.startupRecoveryResetDialogCancel),
        ),
        TextButton(
          onPressed: _acknowledged
              ? () => Navigator.of(context).pop(true)
              : null,
          child: Text(
            l10n.startupRecoveryResetDialogConfirm,
            style: TextStyle(
              color: _acknowledged ? colors.error : colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? colors.errorContainer.withValues(alpha: 0.3)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        text,
        style: textTheme.bodySmall?.copyWith(
          color: isError ? colors.error : colors.onSurfaceVariant,
          height: 1.45,
        ),
      ),
    );
  }
}
