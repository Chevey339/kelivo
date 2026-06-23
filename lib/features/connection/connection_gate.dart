import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/providers/hermes_gateway_provider.dart';
import '../../hermes/hermes_config.dart';
import '../../hermes/hermes_gateway.dart';
import '../../shared/widgets/ios_tactile.dart';
import '../backend/backend_list_page.dart';
import '../backend/add_backend_sheet.dart';

/// Shown at app startup when the Hermes backend is not yet connected.
///
/// States:
/// - **No backends**: prompts user to add a backend
/// - **Connecting**: shows progress indicator
/// - **Error**: shows error + retry button
///
/// Wraps the main app content — only shown when not ready.
class ConnectionGate extends StatelessWidget {
  final Widget child;

  const ConnectionGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<HermesGatewayProvider>(
      builder: (context, provider, _) {
        final state = provider.state;
        final backend = provider.currentBackend;

        // Connected — show the real app
        if (state == HermesConnectionState.ready) {
          return child;
        }

        // Still initializing (Hive box loading) — show a transient loading
        // gate and DO NOT touch `provider.config.backends`, which would throw
        // a red-screen `Bad state: HermesConfig not initialized` if init has
        // not yet completed (e.g. on first frame of cold start).
        if (state == HermesConnectionState.initializing) {
          return _ConnectingGate(l10n: l10n, backendUrl: '');
        }

        // No backends configured — show add-backend prompt
        if (provider.config.backends.isEmpty) {
          return _NoBackendGate(l10n: l10n, provider: provider);
        }

        // Connecting / authenticating — show connecting indicator
        if (state == HermesConnectionState.connecting ||
            state == HermesConnectionState.authenticating) {
          return _ConnectingGate(l10n: l10n, backendUrl: backend?.url ?? '');
        }

        // Error — show error with retry
        return _ErrorGate(l10n: l10n, backend: backend, provider: provider);
      },
    );
  }
}

class _NoBackendGate extends StatelessWidget {
  final AppLocalizations l10n;
  final HermesGatewayProvider provider;

  const _NoBackendGate({required this.l10n, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.connectionGateNoBackend,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.connectionGateNoBackendHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              IosCardPress(
                onTap: () => _showAddBackend(context),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                baseColor: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                child: Text(
                  l10n.backendAddButton,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddBackend(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddBackendSheet(
        onSaved: (name, url, token, profile, authMode) {
          provider.addBackend(
            name: name,
            url: url,
            token: token,
            profile: profile,
            authMode: authMode,
            connectImmediately: true,
          );
        },
      ),
    );
  }
}

class _ConnectingGate extends StatelessWidget {
  final AppLocalizations l10n;
  final String backendUrl;

  const _ConnectingGate({required this.l10n, required this.backendUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.connectionGateTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.connectionGateConnecting(backendUrl),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorGate extends StatelessWidget {
  final AppLocalizations l10n;
  final HermesBackendBox? backend;
  final HermesGatewayProvider provider;

  const _ErrorGate({
    required this.l10n,
    required this.backend,
    required this.provider,
  });

  String? get _friendlyMessage {
    switch (provider.lastErrorKind) {
      case HermesConnectionErrorKind.timeout:
        return l10n.connectionGateFailedTimeout;
      case HermesConnectionErrorKind.network:
        return l10n.connectionGateFailedNetwork;
      case HermesConnectionErrorKind.auth:
        return l10n.connectionGateFailedAuth;
      case HermesConnectionErrorKind.server:
        return l10n.connectionGateFailedServer;
      case HermesConnectionErrorKind.unknown:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.connectionGateFailed,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (_friendlyMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _friendlyMessage!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IosCardPress(
                    onTap: () {
                      if (backend != null) {
                        provider.connectBackend(backend!.id);
                      }
                    },
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    baseColor: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                    child: Text(
                      l10n.connectionGateRetry,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IosCardPress(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BackendListPage(),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    baseColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    child: Text(
                      l10n.connectionGateViewBackend,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
