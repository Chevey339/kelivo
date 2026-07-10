import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'ios_tactile.dart';

/// Persistence-free shell shown while a terminal restore awaits verification
/// from a new process. Business providers must not exist behind this screen.
class RestoreColdRestartScreen extends StatefulWidget {
  const RestoreColdRestartScreen({super.key, required this.restart});

  final Future<void> Function() restart;

  @override
  State<RestoreColdRestartScreen> createState() =>
      _RestoreColdRestartScreenState();
}

class _RestoreColdRestartScreenState extends State<RestoreColdRestartScreen> {
  bool _restarting = false;
  bool _restartFailed = false;

  Future<void> _restart() async {
    if (_restarting) return;
    setState(() {
      _restarting = true;
      _restartFailed = false;
    });
    try {
      await widget.restart();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Kelivo restore',
          context: ErrorDescription('while restarting for restore readback'),
        ),
      );
      if (!mounted) return;
      setState(() {
        _restarting = false;
        _restartFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.restart_alt_rounded,
                        size: 36,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.backupRestoreColdRestartTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.backupRestoreColdRestartContent,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (_restartFailed) ...[
                        const SizedBox(height: 12),
                        Text(
                          l10n.restartAppFailedMessage,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: colors.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: IosCardPress(
                          onTap: _restarting ? null : _restart,
                          haptics: false,
                          baseColor: _restarting
                              ? colors.surfaceContainerHighest
                              : colors.primary,
                          borderRadius: BorderRadius.circular(14),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          child: Text(
                            l10n.backupRestoreColdRestartButton,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: _restarting
                                      ? colors.onSurfaceVariant
                                      : colors.onPrimary,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
