import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/widgets/ios_tactile.dart';
import '../../hermes/hermes_config.dart';

/// Shows details of a single Hermes backend and allows reconnect / delete.
class BackendDetailSheet extends StatelessWidget {
  final HermesBackendBox backend;
  final VoidCallback onReconnect;
  final VoidCallback onDelete;
  final VoidCallback onConnect;

  const BackendDetailSheet({
    super.key,
    required this.backend,
    required this.onReconnect,
    required this.onDelete,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withAlpha(100),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Backend name
          Text(backend.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          // Detail rows
          _DetailRow(label: l10n.backendDetailUrl, value: backend.url),
          _DetailRow(
            label: l10n.backendDetailAuthMode,
            value: _authModeLabel(l10n, backend.authMode),
          ),
          if (backend.profile != null)
            _DetailRow(
              label: l10n.addBackendProfileLabel,
              value: backend.profile!,
            ),
          if (backend.lastConnectedAt != null)
            _DetailRow(
              label: l10n.backendDetailLastConnected,
              value: _formatDate(backend.lastConnectedAt!),
            ),
          if (backend.lastError != null)
            _DetailRow(
              label: l10n.backendDetailLastError,
              value: backend.lastError!,
              isError: true,
            ),
          const SizedBox(height: 24),
          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                if (!backend.isActive)
                  _ActionButton(
                    label: 'Connect',
                    icon: Icons.link,
                    onTap: () {
                      onConnect();
                      Navigator.of(context).pop();
                    },
                    isPrimary: true,
                  ),
                _ActionButton(
                  label: l10n.backendDetailTestConnection,
                  icon: Icons.speed,
                  onTap: () {
                    Navigator.of(context).pop();
                    onReconnect();
                  },
                ),
                _ActionButton(
                  label: l10n.backendDetailDelete,
                  icon: Icons.delete_outline,
                  onTap: () => _confirmDelete(context, l10n),
                  isDestructive: true,
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }

  String _authModeLabel(AppLocalizations l10n, String mode) {
    switch (mode) {
      case 'gated':
        return l10n.backendDetailAuthModeGated;
      case 'loopback':
        return l10n.backendDetailAuthModeLoopback;
      default:
        return l10n.authModeAutoDetect;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _confirmDelete(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backendDetailDelete),
        content: Text(l10n.backendDetailDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.addBackendCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              onDelete();
            },
            child: Text(
              l10n.backendDetailDelete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isError;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isError ? Theme.of(context).colorScheme.error : null,
                fontFamily: isError ? null : 'monospace',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isDestructive;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IosCardPress(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14),
        baseColor: isPrimary
            ? Theme.of(context).colorScheme.primary
            : isDestructive
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isPrimary
                  ? Theme.of(context).colorScheme.onPrimary
                  : isDestructive
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary
                    ? Theme.of(context).colorScheme.onPrimary
                    : isDestructive
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
