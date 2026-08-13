import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:provider/provider.dart';

import '../../../core/models/backup.dart';
import '../../../core/providers/backup_provider.dart';
import '../../../core/services/backup/lan_sync_service.dart';
import '../../../desktop/window_title_bar.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../scan/pages/qr_scan_page.dart';
import '../backup_restart_dialog.dart';

class LanSyncPage extends StatefulWidget {
  const LanSyncPage({super.key});

  @override
  State<LanSyncPage> createState() => _LanSyncPageState();
}

class _LanSyncPageState extends State<LanSyncPage> {
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _pairingCodeController = TextEditingController();
  LanSyncShareSession? _session;
  StreamSubscription<int>? _transferSubscription;
  RestoreMode _restoreMode = RestoreMode.merge;
  bool _starting = false;
  bool _receiving = false;
  bool _pairing = false;
  int _receivedBytes = 0;
  int? _totalBytes;
  int _completedTransfers = 0;

  @override
  void dispose() {
    _transferSubscription?.cancel();
    final session = _session;
    _session = null;
    if (session != null) unawaited(session.close());
    _linkController.dispose();
    _pairingCodeController.dispose();
    super.dispose();
  }

  Future<void> _startShare() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final previous = _session;
      _session = null;
      await _transferSubscription?.cancel();
      if (previous != null) await previous.close();
      if (!mounted) return;

      final session = await context.read<BackupProvider>().startLanShare();
      if (!mounted) {
        await session.close();
        return;
      }
      _transferSubscription = session.transfers.listen((count) {
        if (mounted) setState(() => _completedTransfers = count);
      });
      setState(() {
        _session = session;
        _completedTransfers = 0;
      });
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: _errorMessage(AppLocalizations.of(context)!, error),
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stopShare() async {
    final session = _session;
    if (session == null) return;
    setState(() => _session = null);
    await _transferSubscription?.cancel();
    _transferSubscription = null;
    await session.close();
  }

  Future<void> _scanLink() async {
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScanPage()));
    if (result != null && mounted) {
      _linkController.text = result;
    }
  }

  Future<void> _pasteLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) _linkController.text = text;
  }

  Future<void> _pairByCode() async {
    if (_pairing || _receiving) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _pairing = true);
    try {
      final link = await LanSyncDiscovery.findByPairingCode(
        _pairingCodeController.text,
      );
      if (!mounted) return;
      _linkController.text = link;
      showAppSnackBar(
        context,
        message: l10n.lanSyncDeviceMatched,
        type: NotificationType.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: _errorMessage(l10n, error),
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _pairing = false);
    }
  }

  Future<void> _receive() async {
    final l10n = AppLocalizations.of(context)!;
    final link = _linkController.text.trim();
    if (link.isEmpty || _receiving) return;

    if (_restoreMode == RestoreMode.overwrite) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.lanSyncOverwriteConfirmTitle),
          content: Text(l10n.lanSyncOverwriteConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.backupPageCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.lanSyncContinue),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _receiving = true;
      _receivedBytes = 0;
      _totalBytes = null;
    });
    final provider = context.read<BackupProvider>();
    try {
      await provider.restoreFromLan(
        link,
        mode: _restoreMode,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _receivedBytes = received;
            _totalBytes = total;
          });
        },
      );
      if (!mounted) return;
      await showBackupRestartRequiredDialog(
        context,
        skippedConversations: provider.skippedConversations,
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: _errorMessage(l10n, error),
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _receiving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final page = Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Lucide.ArrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.lanSyncTitle),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _noticeCard(context, l10n),
                    const SizedBox(height: 12),
                    _sendCard(context, l10n, colors),
                    const SizedBox(height: 12),
                    _receiveCard(context, l10n, colors),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    // DesktopHomePage owns the normal Windows drag area, but this page is
    // pushed on the root Navigator and therefore covers that entire widget
    // tree. Supply a title bar for this full-screen route so moving and window
    // controls continue to work until the route is popped.
    if (Platform.isWindows) {
      return Column(
        children: [
          const WindowTitleBar(),
          Expanded(child: page),
        ],
      );
    }
    return page;
  }

  Widget _noticeCard(BuildContext context, AppLocalizations l10n) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Lucide.Shield, color: colors.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.lanSyncSecurityNotice,
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sendCard(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colors,
  ) {
    final session = _session;
    return _card(
      context,
      title: l10n.lanSyncSendTitle,
      subtitle: l10n.lanSyncSendDescription,
      icon: Lucide.Upload,
      child: session == null
          ? FilledButton.icon(
              onPressed: _starting ? null : _startShare,
              icon: _starting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Lucide.Network),
              label: Text(
                _starting ? l10n.lanSyncPreparing : l10n.lanSyncStartShare,
              ),
            )
          : Column(
              children: [
                Text(
                  l10n.lanSyncPairingCodeLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SelectableText(
                    session.pairingCode,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  session.broadcastAvailable
                      ? l10n.lanSyncPairingCodeSendHint
                      : l10n.lanSyncBroadcastUnavailable,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: session.broadcastAvailable
                        ? colors.onSurfaceVariant
                        : colors.error,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 226,
                  height: 226,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: PrettyQrView.data(
                    data: session.primaryUrl.toString(),
                    decoration: const PrettyQrDecoration(
                      shape: PrettyQrSmoothSymbol(roundFactor: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.lanSyncScanOnOtherDevice,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          session.primaryUrl.toString(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.lanSyncCopyLink,
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: session.primaryUrl.toString()),
                          );
                          if (!context.mounted) return;
                          showAppSnackBar(
                            context,
                            message: l10n.lanSyncLinkCopied,
                            type: NotificationType.success,
                          );
                        },
                        icon: const Icon(Lucide.Copy),
                      ),
                    ],
                  ),
                ),
                if (session.shareUrls.length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.lanSyncAlternateAddresses(
                      session.shareUrls.skip(1).map((e) => e.host).join(', '),
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _completedTransfers == 0
                            ? l10n.lanSyncWaiting
                            : l10n.lanSyncTransfersCompleted(
                                _completedTransfers,
                              ),
                        style: TextStyle(color: colors.primary),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _stopShare,
                      icon: const Icon(Lucide.CircleStop),
                      label: Text(l10n.lanSyncStopShare),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _receiveCard(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colors,
  ) {
    final canScan = Platform.isAndroid || Platform.isIOS;
    final total = _totalBytes;
    final progress = total != null && total > 0
        ? (_receivedBytes / total).clamp(0.0, 1.0)
        : null;
    return _card(
      context,
      title: l10n.lanSyncReceiveTitle,
      subtitle: l10n.lanSyncReceiveDescription,
      icon: Lucide.Download,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.lanSyncPairingCodeInputHint,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _pairingCodeController,
                  enabled: !_receiving && !_pairing,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onSubmitted: (_) => _pairByCode(),
                  decoration: InputDecoration(
                    labelText: l10n.lanSyncPairingCodeInputLabel,
                    hintText: '123456',
                    counterText: '',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _receiving || _pairing ? null : _pairByCode,
                  icon: _pairing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Lucide.Search),
                  label: Text(
                    _pairing
                        ? l10n.lanSyncSearchingDevice
                        : l10n.lanSyncFindDevice,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  l10n.lanSyncOrUseLink,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _linkController,
            enabled: !_receiving && !_pairing,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.lanSyncLinkLabel,
              hintText: 'http://192.168.1.2:12345/kelivo-sync/…',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: l10n.lanSyncPasteLink,
                onPressed: _receiving || _pairing ? null : _pasteLink,
                icon: const Icon(Lucide.Clipboard),
              ),
            ),
          ),
          if (canScan) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _receiving || _pairing ? null : _scanLink,
              icon: const Icon(Lucide.Camera),
              label: Text(l10n.lanSyncScanQr),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            l10n.lanSyncImportMode,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<RestoreMode>(
            segments: [
              ButtonSegment(
                value: RestoreMode.merge,
                label: Text(l10n.backupPageMergeMode),
                icon: const Icon(Lucide.GitFork),
              ),
              ButtonSegment(
                value: RestoreMode.overwrite,
                label: Text(l10n.backupPageOverwriteMode),
                icon: const Icon(Lucide.TriangleAlert),
              ),
            ],
            selected: {_restoreMode},
            onSelectionChanged: _receiving || _pairing
                ? null
                : (selection) => setState(() => _restoreMode = selection.first),
          ),
          const SizedBox(height: 8),
          Text(
            _restoreMode == RestoreMode.merge
                ? l10n.backupPageMergeModeDescription
                : l10n.backupPageOverwriteModeDescription,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (_receiving) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 6),
            Text(
              l10n.lanSyncReceivingProgress(
                _formatBytes(_receivedBytes),
                total == null ? '—' : _formatBytes(total),
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _receiving || _pairing ? null : _receive,
            icon: _receiving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Lucide.Download),
            label: Text(
              _receiving ? l10n.lanSyncReceiving : l10n.lanSyncReceiveAction,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String _errorMessage(AppLocalizations l10n, Object error) {
  if (error is! LanSyncException) return error.toString();
  return switch (error.code) {
    'noLocalAddress' => l10n.lanSyncErrorNoLocalAddress,
    'invalidLink' => l10n.lanSyncErrorInvalidLink,
    'nonLocalAddress' => l10n.lanSyncErrorNonLocalAddress,
    'timeout' => l10n.lanSyncErrorTimeout,
    'invalidPairingCode' => l10n.lanSyncErrorInvalidPairingCode,
    'pairingNotFound' => l10n.lanSyncErrorPairingNotFound,
    'pairingRateLimited' => l10n.lanSyncErrorPairingRateLimited,
    'discoveryUnavailable' ||
    'invalidPairingResponse' => l10n.lanSyncErrorDiscoveryUnavailable,
    'connectionFailed' ||
    'connectionRejected' => l10n.lanSyncErrorConnectionFailed,
    'archiveTooLarge' ||
    'incompleteDownload' ||
    'emptyArchive' => l10n.lanSyncErrorInvalidArchive,
    _ => error.toString(),
  };
}
