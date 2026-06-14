import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../icons/lucide_adapter.dart' as lucide;
import '../../l10n/app_localizations.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/sync/sync_metadata.dart';
import '../../shared/widgets/ios_switch.dart';
import '../../theme/app_font_weights.dart';

class DesktopSyncPane extends StatefulWidget {
  const DesktopSyncPane({super.key});
  @override
  State<DesktopSyncPane> createState() => _DesktopSyncPaneState();
}

class _DesktopSyncPaneState extends State<DesktopSyncPane> {
  final _metadata = SyncMetadata();
  bool _initDone = false;
  late TextEditingController _deviceNameCtrl;
  late TextEditingController _intervalCtrl;

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  Future<void> _initAsync() async {
    await _metadata.init();
    if (!mounted) return;
    _deviceNameCtrl = TextEditingController(text: _metadata.deviceName);
    _intervalCtrl = TextEditingController(
      text: (_metadata.pullIntervalSeconds ~/ 60).toString(),
    );
    setState(() => _initDone = true);
  }

  @override
  void dispose() {
    _deviceNameCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final syncProvider = context.watch<SyncProvider>();
    final settings = context.watch<SettingsProvider>();

    if (!_initDone) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            l10n.syncTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 24),

          // Enable toggle
          _buildRow(
            context,
            label: l10n.syncEnable,
            trailing: IosSwitch(
              value: _metadata.enabled,
              onChanged: (val) {
                _metadata.enabled = val;
                syncProvider.setStatus(
                  val ? SyncStatus.idle : SyncStatus.disabled,
                );
                if (!val) syncProvider.setLastSyncAt(null);
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 16),

          // Status
          _buildRow(
            context,
            label: _statusLabel(l10n, syncProvider),
            trailing: _statusIndicator(syncProvider),
          ),
          const SizedBox(height: 8),

          // Last sync time
          if (syncProvider.lastSyncAt != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 12),
              child: Text(
                l10n.syncLastSyncAt(_formatTime(syncProvider.lastSyncAt!)),
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),

          // Error message
          if (syncProvider.lastError != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 12),
              child: Text(
                syncProvider.lastError!,
                style: TextStyle(fontSize: 13, color: cs.error),
              ),
            ),

          // Sync now button
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 20),
            child: FilledButton.tonalIcon(
              onPressed: _metadata.enabled
                  ? () => syncProvider.triggerSync()
                  : null,
              icon: const Icon(lucide.Lucide.RefreshCw, size: 18),
              label: Text(l10n.syncManualSync),
            ),
          ),

          const Divider(),
          const SizedBox(height: 16),

          // Backend selector
          Text(
            l10n.syncBackendLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _metadata.backendChoice,
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'webdav', child: Text('WebDAV')),
            ],
            onChanged: (val) {
              _metadata.backendChoice = val;
              setState(() {});
            },
          ),
          if (settings.webDavConfig.url.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.syncNeedBackend,
                style: TextStyle(fontSize: 13, color: cs.error),
              ),
            ),
          const SizedBox(height: 16),

          // Device name
          Text(
            l10n.syncDeviceName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 300,
            child: TextField(
              controller: _deviceNameCtrl,
              decoration: InputDecoration(
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (val) => _metadata.deviceName = val,
            ),
          ),
          const SizedBox(height: 16),

          // Pull interval
          Text(
            l10n.syncPullInterval,
            style: TextStyle(
              fontSize: 14,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _intervalCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (val) {
                final parsed = int.tryParse(val);
                if (parsed != null) {
                  _metadata.pullIntervalSeconds = parsed * 60;
                }
              },
            ),
          ),
          const SizedBox(height: 24),

          // Clear remote history
          TextButton.icon(
            onPressed: null,
            icon: const Icon(lucide.Lucide.Trash2, size: 18),
            label: Text(l10n.syncCleanHistory),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required String label,
    required Widget trailing,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: cs.onSurface),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _statusIndicator(SyncProvider p) {
    final color = switch (p.status) {
      SyncStatus.disabled => Colors.grey,
      SyncStatus.idle => Colors.green,
      SyncStatus.pushing || SyncStatus.pulling => Colors.blue,
      SyncStatus.enabling => Colors.orange,
      SyncStatus.error => Colors.red,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  String _statusLabel(AppLocalizations l10n, SyncProvider p) {
    return switch (p.status) {
      SyncStatus.disabled => l10n.syncStatusDisabled,
      SyncStatus.idle => l10n.syncStatusIdle,
      SyncStatus.pushing => l10n.syncStatusPushing,
      SyncStatus.pulling => l10n.syncStatusPulling,
      SyncStatus.enabling => l10n.syncStatusIdle,
      SyncStatus.error => l10n.syncStatusError,
    };
  }

  String _formatTime(DateTime dt) {
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
        '${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
